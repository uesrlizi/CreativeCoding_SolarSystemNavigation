class Spacecraft {
  String name;
  double a, e, i, omega, w, M0, period;
  color col;
  color trailColor;

  double px, py, pz;
  double currentNu;

  ShipState state;
  double launchStartTime;
  double transferStartTime;
  double countdownStartTime;
  double ignitionStartTime;
  static final double COUNTDOWN_DURATION = 10.0;
  static final double IGNITION_DURATION = 2.0;

  // Earth-relative tracking
  boolean earthRelative;
  CelestialBody earthRef;
  double launchPadAngle;
  double launchAltitude;
  double earthOrbitAngle;
  double orbitStartTime;
  double[] earthRelPos;
  double[] earthRelVel;

  // Physics-based launch
  double lastUpdateTime;
  boolean thrustActive;                          // true during powered ascent
  double circBurnDuration;                       // pre-computed circularization burn (seconds)
  static final double THRUST_ACCEL = 0.025;      // km/s^2 (~2.5g)
  static final double VERTICAL_RISE_TIME = 10.0; // seconds, pure vertical before pitch program
  static final double MAX_PITCH_RAD = 1.4835298641951802;  // 85 degrees to rad, max pitch from vertical
  static final double PITCH_EXPONENT = 0.7;      // shape: higher = stays vertical longer
  static final double FIXED_SUBSTEP = 1.0;       // max seconds per physics sub-step
  static final double CIRC_ECC_TOLERANCE = 0.0005;  // eccentricity threshold for circular orbit
  static final double PEG_K_ALT  = 0.02;             // rad/km altitude correction gain
  static final double PEG_K_VRAD = 2.0;              // rad/(km/s) radial-velocity damping
  static final double PEG_MAX_PITCH = 1.2;           // ~69 deg max pitch from tangential
  static final double SHIP_LENGTH_KM = 0.05;         // 50 m rocket
  static final double SHIP_WIDTH_KM = 0.014;     // 14 m diameter

  Spacecraft(double a, double e, double i,
    double omega, double w, double M0, double period, color col) {
    this.name = "Spacecraft";
    this.a = a; this.e = e; this.i = i;
    this.omega = omega; this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = period;
    this.col = col;
    this.trailColor = col;
    this.state = ShipState.IDLE;
    this.launchStartTime = 0;
    this.transferStartTime = 0;
    this.countdownStartTime = 0;
    this.ignitionStartTime = 0;
    this.earthRelative = false;
    this.earthRef = null;
    this.launchPadAngle = 0;
    this.launchAltitude = 0;
    this.earthOrbitAngle = 0;
    this.orbitStartTime = 0;
    this.earthRelPos = new double[]{0, 0, 0};
    this.earthRelVel = new double[]{0, 0, 0};
  }

  void update(double t) {
    if (earthRelative && earthRef != null) {
      updateEarthRelative(t);
    } else {
      updateHeliocentric(t);
    }
  }

  void updateHeliocentric(double t) {
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    if (M < 0) M += 2.0 * PI;
    double E = solveKepler(M, e);
    currentNu = trueAnomaly(E, e);
    double[] pos = orbitalToCartesian(a, e, i, omega, w, currentNu);
    px = pos[0]; py = pos[1]; pz = pos[2];
  }

  void updateEarthRelative(double t) {
    double earthX = earthRef.px;
    double earthY = earthRef.py;

    if (state == ShipState.LAUNCHING || state == ShipState.CIRCULARIZING) {
      double dt = t - lastUpdateTime;
      if (dt <= 0) dt = 1.0 / 60.0;
      if (dt > 3600) dt = 3600;
      lastUpdateTime = t;

      double currentT = t - dt;
      double remainingDt = dt;
      int maxIter = 10000;
      while (remainingDt > 0 && maxIter-- > 0) {
        double step = Math.min(remainingDt, FIXED_SUBSTEP);

        double rx = earthRelPos[0], ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);
        if (r < MissionPlanner.EARTH_RADIUS_KM * 0.5) {
          // Ship crashed or in degenerate state — abort
          dbgLog("PHYSICS ABORT: r=" + r + " too low, state=" + state);
          remainingDt = 0;
          break;
        }

        // Gravity
        double gMag = MissionPlanner.GM_EARTH / (r * r);
        double ax = -gMag * rx / r;
        double ay = -gMag * ry / r;

        // Thrust
        boolean ascentStepApplied = false;
        if (thrustActive) {
          if (state == ShipState.LAUNCHING) {
            // === Active Pitch Ascent ===
            // Phase 1 (0-VERTICAL_RISE_TIME): pure vertical
            // Phase 2 (after): altitude-based pitch — tilts as altitude increases
            double burnTime = currentT - launchStartTime;
            double thrustDirX, thrustDirY;
            double thrustAngle = getAscentThrustAngle(rx, ry, burnTime);
            thrustDirX = Math.cos(thrustAngle);
            thrustDirY = Math.sin(thrustAngle);

            double thrustAx = THRUST_ACCEL * thrustDirX;
            double thrustAy = THRUST_ACCEL * thrustDirY;

            // Save pre-step state
            double preRx = earthRelPos[0], preRy = earthRelPos[1];
            double preVx = earthRelVel[0], preVy = earthRelVel[1];

            // Compute post-step state with full thrust (tentative) and check apoapsis
            double tmpVx = preVx + (ax + thrustAx) * step;
            double tmpVy = preVy + (ay + thrustAy) * step;
            double tmpRx = preRx + tmpVx * step;
            double tmpRy = preRy + tmpVy * step;

            double apoFull = computeApoapsisAt(tmpRx, tmpRy, tmpVx, tmpVy);

            if (apoFull >= MissionPlanner.LEO_ALTITUDE_KM) {
              // Will cross target — find the fraction of thrust needed
              double gVx = preVx + ax * step;
              double gVy = preVy + ay * step;
              double gRx = preRx + gVx * step;
              double gRy = preRy + gVy * step;
              double apoGrav = computeApoapsisAt(gRx, gRy, gVx, gVy);

              double f = 0.0;
              if (apoFull > apoGrav && apoGrav < MissionPlanner.LEO_ALTITUDE_KM) {
                f = (MissionPlanner.LEO_ALTITUDE_KM - apoGrav) / (apoFull - apoGrav);
                f = Math.max(0.0, Math.min(1.0, f));
              }

              earthRelVel[0] = preVx + (ax + thrustAx * f) * step;
              earthRelVel[1] = preVy + (ay + thrustAy * f) * step;
              earthRelPos[0] = preRx + earthRelVel[0] * step;
              earthRelPos[1] = preRy + earthRelVel[1] * step;

              thrustActive = false;
            } else {
              // No overshoot yet — apply full thrust step
              earthRelVel[0] = tmpVx;
              earthRelVel[1] = tmpVy;
              earthRelPos[0] = tmpRx;
              earthRelPos[1] = tmpRy;
            }
            ascentStepApplied = true;

          } else {
            // PEG-inspired fixed-target circularization guidance
            double vx = earthRelVel[0], vy = earthRelVel[1];
            double[] peg = getPEGGuidance(rx, ry, vx, vy);
            double thrX = THRUST_ACCEL * Math.cos(peg[1]);
            double thrY = THRUST_ACCEL * Math.sin(peg[1]);
            if (Double.isNaN(thrX) || Double.isNaN(thrY)) {
              dbgLog("PEG NaN thrust — aborting circularization");
              finalizeOrbitInsertion();
              remainingDt = 0;
              break;
            }
            ax += thrX;
            ay += thrY;
          }
        }

        // Semi-implicit Euler (skipped if ascent already applied above)
        if (!ascentStepApplied) {
          earthRelVel[0] += ax * step;
          earthRelVel[1] += ay * step;
          earthRelPos[0] += earthRelVel[0] * step;
          earthRelPos[1] += earthRelVel[1] * step;
        }

        currentT += step;
        remainingDt -= step;

        // === Per-sub-step guidance ===
        double rxNew = earthRelPos[0], ryNew = earthRelPos[1];
        double rNew = Math.sqrt(rxNew * rxNew + ryNew * ryNew);
        double altNew = rNew - MissionPlanner.EARTH_RADIUS_KM;

        if (state == ShipState.LAUNCHING) {
          if (!thrustActive) {
            // Compute circularization parameters from osculating orbit.
            // The burn must be CENTERED on apoapsis: start before it,
            // finish after it. This prevents the spacecraft from
            // descending while burning.
            double vx = earthRelVel[0], vy = earthRelVel[1];
            double v2 = vx * vx + vy * vy;
            double energy = v2 / 2.0 - MissionPlanner.GM_EARTH / rNew;
            double timeToApo = timeToApoapsis();
            boolean startBurn = false;

            if (energy < 0) {
              double a = -MissionPlanner.GM_EARTH / (2.0 * energy);
              double h = rxNew * vy - ryNew * vx;
              double e2 = 1.0 - h * h / (MissionPlanner.GM_EARTH * a);
              double e = Math.sqrt(Math.max(0.0, e2));
              double rApo = a * (1.0 + e);
              double vApo = Math.sqrt(MissionPlanner.GM_EARTH * (2.0 / rApo - 1.0 / a));
              double vCirc = Math.sqrt(MissionPlanner.GM_EARTH / rApo);
              double dv = vCirc - vApo;          // Δv needed at apoapsis
              double burnTime = Math.max(0.0, dv / THRUST_ACCEL);
              double startOffset = burnTime / 2.0;  // center burn on apoapsis

              if (timeToApo < 0 || e < 0.001) {
                startBurn = true;  // past apoapsis or near-circular
                circBurnDuration = Math.max(burnTime, 0.5);
              } else if (timeToApo <= startOffset) {
                startBurn = true;  // within centering window
                circBurnDuration = burnTime;
              }
            } else {
              // Hyperbolic (shouldn't happen) — start burn as safety
              startBurn = true;
              circBurnDuration = 5.0;
            }

            if (startBurn) {
              dbgLog("CIRC START: state->CIRCULARIZING, burnDuration=" + circBurnDuration
                + " timeToApo=" + timeToApo);
              state = ShipState.CIRCULARIZING;
              thrustActive = true;
            }
          }
        } else if (state == ShipState.CIRCULARIZING) {
          circBurnDuration -= step;
          double periAlt = computePerigee();
          if (periAlt >= MissionPlanner.LEO_ALTITUDE_KM - 1.0 || circBurnDuration <= 0) {
            dbgLog("CIRC DONE: finalizing orbit insertion");
            finalizeOrbitInsertion();
            remainingDt = 0;
          }
        }
      }

      if (remainingDt > 0) {
        dbgLog("PHYSICS MAXITER EXHAUSTED! remainingDt=" + remainingDt
          + " state=" + state + " maxIter=" + maxIter);
      }

      // Update derived values (finalizeOrbitInsertion sets these for ORBIT state)
      if (state != ShipState.ORBIT) {
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);
        launchAltitude = r - MissionPlanner.EARTH_RADIUS_KM;
        earthOrbitAngle = Math.atan2(ry, rx);
      }

    } else if (state == ShipState.ORBIT) {
      double orbitElapsed = t - orbitStartTime;
      double angVel = Math.sqrt(MissionPlanner.GM_EARTH
                     / Math.pow(MissionPlanner.LEO_RADIUS_KM, 3));
      earthOrbitAngle = launchPadAngle + angVel * orbitElapsed;
      launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;
      earthRelPos[0] = MissionPlanner.LEO_RADIUS_KM * Math.cos(earthOrbitAngle);
      earthRelPos[1] = MissionPlanner.LEO_RADIUS_KM * Math.sin(earthOrbitAngle);
      earthRelPos[2] = 0;
      earthRelVel[0] = -MissionPlanner.LEO_RADIUS_KM * angVel * Math.sin(earthOrbitAngle);
      earthRelVel[1] =  MissionPlanner.LEO_RADIUS_KM * angVel * Math.cos(earthOrbitAngle);
      earthRelVel[2] = 0;
    }

    px = earthX + earthRelPos[0];
    py = earthY + earthRelPos[1];
    pz = 0;
  }

  // Shared osculating orbital parameters: returns [a (km), e, h (km^2/s), energy]
  private double[] getOsculatingOrbitalParams() {
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double vx = earthRelVel[0], vy = earthRelVel[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double GM = MissionPlanner.GM_EARTH;
    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return new double[]{Double.MAX_VALUE, Double.MAX_VALUE, 0, energy};
    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    double e2 = 1.0 - h * h / (GM * a);
    double e = Math.sqrt(Math.max(0.0, e2));
    return new double[]{a, e, h, energy};
  }

  private double[] getOsculatingOrbitalParams(double rx, double ry, double vx, double vy) {
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double GM = MissionPlanner.GM_EARTH;
    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return new double[]{Double.MAX_VALUE, Double.MAX_VALUE, 0, energy};
    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    double e2 = 1.0 - h * h / (GM * a);
    double e = Math.sqrt(Math.max(0.0, e2));
    return new double[]{a, e, h, energy};
  }

  // Compute thrust direction angle (radians) for powered ascent pitch program
  double getAscentThrustAngle(double rx, double ry, double burnTime) {
    double r = Math.sqrt(rx * rx + ry * ry);
    if (r < 1.0) return 0;
    if (burnTime < VERTICAL_RISE_TIME) {
      return Math.atan2(ry, rx);
    }
    double alt = r - MissionPlanner.EARTH_RADIUS_KM;
    double altFrac = Math.max(0.0, Math.min(1.0, alt / MissionPlanner.LEO_ALTITUDE_KM));
    double pitchAngle = Math.pow(altFrac, PITCH_EXPONENT) * MAX_PITCH_RAD;
    double radX = rx / r, radY = ry / r;
    double tanX = -ry / r, tanY = rx / r;
    double thrX = radX * Math.cos(pitchAngle) + tanX * Math.sin(pitchAngle);
    double thrY = radY * Math.cos(pitchAngle) + tanY * Math.sin(pitchAngle);
    return Math.atan2(thrY, thrX);
  }

  // Compute PEG guidance pitch offset [rad] and thrust angle [rad]
  double[] getPEGGuidance(double rx, double ry, double vx, double vy) {
    double r = Math.sqrt(rx * rx + ry * ry);
    if (r < 1.0) {
      dbgLog("PEG r too small: " + r);
      return new double[]{0, 0};  // safe fallback
    }
    double vRad  = (rx * vx + ry * vy) / r;
    double altError = r - MissionPlanner.LEO_RADIUS_KM;
    double pitchOffset = -PEG_K_ALT * altError - PEG_K_VRAD * vRad;
    if (pitchOffset >  PEG_MAX_PITCH) pitchOffset =  PEG_MAX_PITCH;
    if (pitchOffset < -PEG_MAX_PITCH) pitchOffset = -PEG_MAX_PITCH;
    double tanX = -ry / r, tanY = rx / r;
    double radX = rx / r, radY = ry / r;
    double cosP = Math.cos(pitchOffset);
    double sinP = Math.sin(pitchOffset);
    double thrX = tanX * cosP + radX * sinP;
    double thrY = tanY * cosP + radY * sinP;
    return new double[]{pitchOffset, Math.atan2(thrY, thrX)};
  }

  double computeApoapsis() {
    double[] p = getOsculatingOrbitalParams();
    if (p[0] >= Double.MAX_VALUE / 2) return Double.MAX_VALUE;
    return p[0] * (1.0 + p[1]) - MissionPlanner.EARTH_RADIUS_KM;
  }

  double computeApoapsisAt(double rx, double ry, double vx, double vy) {
    double[] p = getOsculatingOrbitalParams(rx, ry, vx, vy);
    if (p[0] >= Double.MAX_VALUE / 2) return Double.MAX_VALUE;
    return p[0] * (1.0 + p[1]) - MissionPlanner.EARTH_RADIUS_KM;
  }

  double computeEccentricity() {
    double[] p = getOsculatingOrbitalParams();
    return p[1];
  }

  double computePerigee() {
    double[] p = getOsculatingOrbitalParams();
    if (p[0] >= Double.MAX_VALUE / 2) return Double.MAX_VALUE;
    return p[0] * (1.0 - p[1]) - MissionPlanner.EARTH_RADIUS_KM;
  }

  // Time in seconds until the spacecraft reaches apoapsis on its current
  // osculating Kepler orbit. Returns -1 if already past apoapsis, or a large
  // value if the orbit is near-circular (no well-defined apoapsis).
  double timeToApoapsis() {
    double[] p = getOsculatingOrbitalParams();
    if (p[3] >= 0) return -1;                     // hyperbolic
    double a = p[0], e = p[1];
    if (e < 0.0001) return Double.MAX_VALUE;       // near-circular

    double rx = earthRelPos[0], ry = earthRelPos[1];
    double vx = earthRelVel[0], vy = earthRelVel[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    // True anomaly
    double radX = rx / r, radY = ry / r;
    double v_r = vx * radX + vy * radY;
    double cosNu = (a * (1.0 - e * e) / r - 1.0) / e;
    cosNu = Math.max(-1.0, Math.min(1.0, cosNu));
    double nu = Math.acos(cosNu);
    if (v_r < 0) nu = 2.0 * PI - nu;

    // Eccentric anomaly
    double cosE = (e + Math.cos(nu)) / (1.0 + e * Math.cos(nu));
    double sinE = Math.sqrt(1.0 - e * e) * Math.sin(nu) / (1.0 + e * Math.cos(nu));
    double E = Math.atan2(sinE, cosE);
    if (E < 0) E += 2.0 * PI;

    // Mean anomaly and mean motion
    double M = E - e * Math.sin(E);
    double n = Math.sqrt(MissionPlanner.GM_EARTH / (a * a * a));

    // M = pi at apoapsis
    if (M < PI) return (PI - M) / n;
    return -1;  // already past apoapsis
  }

  void finalizeOrbitInsertion() {
    dbgLog("finalizeOrbitInsertion start");
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double radX = rx / r, radY = ry / r;
    double tanX = -ry / r, tanY = rx / r;

    double circSpeed = Math.sqrt(MissionPlanner.GM_EARTH / MissionPlanner.LEO_RADIUS_KM);

    // Pure tangential velocity at circular orbit speed
    earthRelVel[0] = tanX * circSpeed;
    earthRelVel[1] = tanY * circSpeed;
    earthRelVel[2] = 0;

    // Snap position to exact LEO radius (preserve angle)
    earthRelPos[0] = MissionPlanner.LEO_RADIUS_KM * radX;
    earthRelPos[1] = MissionPlanner.LEO_RADIUS_KM * radY;
    earthRelPos[2] = 0;

    launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;
    launchPadAngle = Math.atan2(earthRelPos[1], earthRelPos[0]);
    earthOrbitAngle = launchPadAngle;
    orbitStartTime = timeManager.simTime;
    state = ShipState.ORBIT;
    dbgLog("finalizeOrbitInsertion done, state=ORBIT");
  }

}
