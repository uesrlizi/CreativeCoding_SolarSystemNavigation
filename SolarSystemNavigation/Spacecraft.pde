// ============================================================
//  Spacecraft — refactored to be a state container + scheduler
//  Physics, guidance, and orbit propagation delegated to new classes
// ============================================================

class Spacecraft {
  // Basic identity
  String name;
  color col;
  color trailColor;

  // Orbital elements (for heliocentric Keplerian propagation)
  double a, e, i, omega, w, M0, period;
  double px, py, pz;
  double currentNu;

  // Reference frame
  ReferenceFrame frame;

  // Earth-relative tracking (preserved for backward compatibility)
  boolean earthRelative;
  CelestialBody earthRef;
  double launchPadAngle;
  double launchAltitude;
  double earthOrbitAngle;
  double orbitStartTime;
  double[] earthRelPos;
  double[] earthRelVel;

  // Mission state
  ShipState state;
  double launchStartTime;
  double transferStartTime;
  double countdownStartTime;
  double ignitionStartTime;

  // Thrust/burn tracking
  boolean thrustActive;
  double circBurnDuration;
  double tmiTargetDV = 0;
  double tmiAccumulatedDV = 0;
  double toiTargetDV = 0;
  double toiAccumulatedDV = 0;

  // Last physics update time
  double lastUpdateTime;

  // Display-only angular dynamics (cosmetic only)
  double displayAngle;
  double angularVelocity;
  double angularAcceleration;
  static final double MAX_ANGULAR_VELOCITY = 3.0;
  static final double MAX_ANGULAR_ACCEL = 8.0;
  static final double ANGLE_KP = 10.0;
  static final double ANGLE_KD = 6.0;
  static final double COUNTDOWN_DURATION = 10.0;
  static final double IGNITION_DURATION = 2.0;
  static final double SHIP_LENGTH_KM = 0.08;
  static final double SHIP_WIDTH_KM = 0.006;

  // External systems (instance fields)
  OrbitPropagator orbitPropagator;
  FlightComputer flightComputer;
  PhysicsEngine physicsEngine;
  AtmosphereModel atmosphereModel;
  MissionPlanner planner;

  // ==============================================================
  //  Constructor
  // ==============================================================

  Spacecraft(double a, double e, double i,
      double omega, double w, double M0, double period, color col) {
    this.name = "Spacecraft";
    this.a = a; this.e = e; this.i = i;
    this.omega = omega; this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = period;
    this.col = col;
    this.trailColor = col;

    // Initialize external systems
    this.orbitPropagator = new OrbitPropagator();
    this.flightComputer = new FlightComputer();
    this.physicsEngine = new PhysicsEngine();
    this.atmosphereModel = new AtmosphereModel();
    this.planner = new MissionPlanner();

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

    this.displayAngle = 0;
    this.angularVelocity = 0;
    this.angularAcceleration = 0;
  }

  // ==============================================================
  //  Main update dispatcher — heart of the new architecture
  //  Decides whether to use PhysicsEngine or OrbitPropagator
  // ==============================================================

  void update(double t) {
    double simDt = t - lastUpdateTime;
    if (simDt <= 0) simDt = 1.0 / 60.0;
    if (simDt > 3600) simDt = 3600; // max 1 hour to prevent skipping too much
    lastUpdateTime = t;

    if (earthRelative && earthRef != null) {
      updateBodyRelative(t, simDt);
    } else {
      updateHeliocentric(t, simDt);
    }

    // Update display angle — use small substeps for stability even with large simDt
    double targetAngle = computeTargetWorldAngle();
    double remainingDt = simDt;
    double maxSubStep = 1.0 / 60.0;
    while (remainingDt > 0) {
      double dt = Math.min(remainingDt, maxSubStep);
      updateDisplayAngle(targetAngle, dt);
      remainingDt -= dt;
    }
  }

  // ==============================================================
  //  Body-relative mode (Earth orbit)
  // ==============================================================

  void updateBodyRelative(double t, double simDt) {
    if (state == ShipState.LAUNCHING || state == ShipState.CIRCULARIZING) {
      // === Physics-based ascent with guidance state machine ===
      double currentT = t - simDt;
      double remainingDt = simDt;

      while (remainingDt > 0) {
        double step = Math.min(remainingDt, PhysicsEngine.FIXED_SUBSTEP);

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
            double burnTime = currentT - launchStartTime;
            double thrustAngle = flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
            double thrustDirX = Math.cos(thrustAngle);
            double thrustDirY = Math.sin(thrustAngle);

            double thrustAx = FlightComputer.THRUST_ACCEL * thrustDirX;
            double thrustAy = FlightComputer.THRUST_ACCEL * thrustDirY;

            // Save pre-step state
            double preRx = earthRelPos[0], preRy = earthRelPos[1];
            double preVx = earthRelVel[0], preVy = earthRelVel[1];

            // Compute post-step state with full thrust (tentative) and check apoapsis
            double tmpVx = preVx + (ax + thrustAx) * step;
            double tmpVy = preVy + (ay + thrustAy) * step;
            double tmpRx = preRx + tmpVx * step;
            double tmpRy = preRy + tmpVy * step;

            double apoFull = flightComputer.apoapsisAltitude(tmpRx, tmpRy, tmpVx, tmpVy, MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

            if (apoFull >= MissionPlanner.LEO_ALTITUDE_KM) {
              // Will cross target — find the fraction of thrust needed
              double gVx = preVx + ax * step;
              double gVy = preVy + ay * step;
              double gRx = preRx + gVx * step;
              double gRy = preRy + gVy * step;
              double apoGrav = flightComputer.apoapsisAltitude(gRx, gRy, gVx, gVy, MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

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

          } else if (state == ShipState.CIRCULARIZING) {
            // PEG-inspired fixed-target circularization guidance
            double vx = earthRelVel[0], vy = earthRelVel[1];
            double[] peg = flightComputer.pegGuidance(rx, ry, vx, vy, MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);
            double thrX = FlightComputer.THRUST_ACCEL * Math.cos(peg[1]);
            double thrY = FlightComputer.THRUST_ACCEL * Math.sin(peg[1]);
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

        // Drag (atmosphere)
        if (atmosphereModel != null && earthRef != null) {
          double[] dragAccel = new double[2];
          atmosphereModel.dragAcceleration(earthRelPos, earthRelVel, earthRef, dragAccel);
          ax += dragAccel[0];
          ay += dragAccel[1];
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
            double timeToApo = flightComputer.timeToApoapsis(rx, ry, vx, vy, MissionPlanner.GM_EARTH);
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
              double burnTime = Math.max(0.0, dv / FlightComputer.THRUST_ACCEL);
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
          double periAlt = flightComputer.perigeeAltitude(rxNew, ryNew, earthRelVel[0], earthRelVel[1], MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);
          if (periAlt >= MissionPlanner.LEO_ALTITUDE_KM - 1.0 || circBurnDuration <= 0) {
            dbgLog("CIRC DONE: finalizing orbit insertion");
            finalizeOrbitInsertion();
            remainingDt = 0;
          }
        }
      }

      // Update derived values (finalizeOrbitInsertion sets these for ORBIT state)
      if (state != ShipState.ORBIT) {
        updateDerivedValues();
      }

    } else if (state == ShipState.TMI_BURN) {
      // === TMI Burn - Prograde thrust to escape Earth ===
      double currentT = t - simDt;
      double remainingDt = simDt;

      while (remainingDt > 0) {
        double step = Math.min(remainingDt, PhysicsEngine.FIXED_SUBSTEP);

        double rx = earthRelPos[0], ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);

        // Gravity
        double gMag = MissionPlanner.GM_EARTH / (r * r);
        double ax = -gMag * rx / r;
        double ay = -gMag * ry / r;

        // Thrust (prograde tangential)
        if (thrustActive) {
          double[] thrustDir = flightComputer.tangentialThrustDirection(rx, ry, true);
          double thrustAx = FlightComputer.THRUST_ACCEL * thrustDir[0];
          double thrustAy = FlightComputer.THRUST_ACCEL * thrustDir[1];
          ax += thrustAx;
          ay += thrustAy;

          // Accumulate ΔV
          double dvThisStep = FlightComputer.THRUST_ACCEL * step;
          tmiAccumulatedDV += dvThisStep;

          // Check burn completion
          if (tmiAccumulatedDV >= tmiTargetDV) {
            thrustActive = false;
          }
        }

        // Semi-implicit Euler integration
        earthRelVel[0] += ax * step;
        earthRelVel[1] += ay * step;
        earthRelPos[0] += earthRelVel[0] * step;
        earthRelPos[1] += earthRelVel[1] * step;

        currentT += step;
        remainingDt -= step;
      }

      updateDerivedValues();

    } else if (state == ShipState.TOI_BURN) {
      // === TOI Burn - Retrograde thrust to brake into orbit ===
      double currentT = t - simDt;
      double remainingDt = simDt;

      // Get target GM
      double GM_target = MissionPlanner.GM_EARTH;
      if (earthRef != null) {
        GM_target = planner.getTargetGM(earthRef);
      }

      while (remainingDt > 0) {
        double step = Math.min(remainingDt, PhysicsEngine.FIXED_SUBSTEP);

        double rx = earthRelPos[0], ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);

        // Gravity (target body)
        double gMag = GM_target / (r * r);
        double ax = -gMag * rx / r;
        double ay = -gMag * ry / r;

        // Thrust (retrograde - opposite to velocity)
        if (thrustActive) {
          double[] thrustDir = flightComputer.tangentialThrustDirection(earthRelVel, false);
          double thrustAx = FlightComputer.THRUST_ACCEL * thrustDir[0];
          double thrustAy = FlightComputer.THRUST_ACCEL * thrustDir[1];
          ax += thrustAx;
          ay += thrustAy;

          // Accumulate ΔV
          double dvThisStep = FlightComputer.THRUST_ACCEL * step;
          toiAccumulatedDV += dvThisStep;

          // Check burn completion
          if (toiAccumulatedDV >= toiTargetDV) {
            thrustActive = false;
          }
        }

        // Semi-implicit Euler integration
        earthRelVel[0] += ax * step;
        earthRelVel[1] += ay * step;
        earthRelPos[0] += earthRelVel[0] * step;
        earthRelPos[1] += earthRelVel[1] * step;

        currentT += step;
        remainingDt -= step;
      }

      updateDerivedValues();

    } else if (state == ShipState.ORBIT || state == ShipState.WAITING_FOR_WINDOW) {
      // === Analytic circular orbit around Earth ===
      double orbitElapsed = t - orbitStartTime;
      double angVel = Math.sqrt(MissionPlanner.GM_EARTH / Math.pow(MissionPlanner.LEO_RADIUS_KM, 3));
      earthOrbitAngle = launchPadAngle + angVel * orbitElapsed;
      orbitPropagator.propagateCircularOrbit(
        earthRelPos, earthRelVel,
        earthRef, earthOrbitAngle,
        MissionPlanner.LEO_RADIUS_KM,
        MissionPlanner.GM_EARTH);
      launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;

    } else if (state == ShipState.CAPTURED) {
      // === Analytic circular orbit around target body ===
      double GM_target = planner.getTargetGM(earthRef);
      double orbitRadius = earthRef.radius * 10.0;
      double orbitElapsed = t - orbitStartTime;
      double angVel = Math.sqrt(GM_target / Math.pow(orbitRadius, 3));
      earthOrbitAngle = launchPadAngle + angVel * orbitElapsed;

      orbitPropagator.propagateCircularOrbit(
        earthRelPos, earthRelVel,
        earthRef, earthOrbitAngle,
        orbitRadius,
        GM_target);

      launchAltitude = orbitRadius - earthRef.radius;
      updateDerivedValues();
    }

    // Update world position
    px = earthRef.px + earthRelPos[0];
    py = earthRef.py + earthRelPos[1];
    pz = 0;
  }

  // ==============================================================
  //  Heliocentric mode (interplanetary transfer)
  // ==============================================================

  void updateHeliocentric(double t, double simDt) {
    boolean needsPhysics = thrustActive || state == ShipState.APPROACHING_TARGET || state == ShipState.TOI_BURN;

    if (needsPhysics && earthRelative == false) {
      // TODO: full heliocentric physics not needed yet
      orbitPropagator.propagateHeliocentric(this, t);
    } else {
      orbitPropagator.propagateHeliocentric(this, t);
    }
  }

  // ==============================================================
  //  Helper: update derived values after physics
  // ==============================================================

  void updateDerivedValues() {
    if (earthRelPos != null) {
      double rx = earthRelPos[0], ry = earthRelPos[1];
      double r = Math.sqrt(rx * rx + ry * ry);
      launchAltitude = r - MissionPlanner.EARTH_RADIUS_KM;
      earthOrbitAngle = Math.atan2(ry, rx);
    }
  }

  // ==============================================================
  //  Finalize orbit insertion — clean transition to stable orbit
  // ==============================================================

  void finalizeOrbitInsertion() {
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double radX = rx / r, radY = ry / r;
    double tanX = -ry / r, tanY = rx / r;

    double circSpeed = Math.sqrt(MissionPlanner.GM_EARTH / MissionPlanner.LEO_RADIUS_KM);
    earthRelVel[0] = tanX * circSpeed;
    earthRelVel[1] = tanY * circSpeed;
    earthRelVel[2] = 0;

    earthRelPos[0] = MissionPlanner.LEO_RADIUS_KM * radX;
    earthRelPos[1] = MissionPlanner.LEO_RADIUS_KM * radY;
    earthRelPos[2] = 0;

    launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;
    launchPadAngle = Math.atan2(earthRelPos[1], earthRelPos[0]);
    earthOrbitAngle = launchPadAngle;
    orbitStartTime = lastUpdateTime;
    thrustActive = false;
    state = ShipState.ORBIT;
  }

  // ==============================================================
  //  Target display angle — copied verbatim from old code
  // ==============================================================

  double computeTargetWorldAngle() {
    if (earthRelative && earthRef != null) {
      if (state == ShipState.IDLE ||
          state == ShipState.COUNTDOWN ||
          state == ShipState.IGNITION) {
        return earthOrbitAngle;
      } else if (state == ShipState.LAUNCHING && thrustActive) {
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double burnTime = (timeManager != null ? timeManager.simTime : 0) - launchStartTime;
        return flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
      } else if (state == ShipState.CIRCULARIZING && thrustActive) {
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double vx = earthRelVel[0], vy = earthRelVel[1];
        double[] peg = flightComputer.pegGuidance(rx, ry, vx, vy, MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);
        return peg[1];
      } else if (state == ShipState.TMI_BURN && thrustActive) {
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double[] thrustDir = flightComputer.tangentialThrustDirection(rx, ry, true);
        return Math.atan2(thrustDir[1], thrustDir[0]);
      } else if (state == ShipState.TOI_BURN && thrustActive) {
        double[] thrustDir = flightComputer.tangentialThrustDirection(earthRelVel, false);
        return Math.atan2(thrustDir[1], thrustDir[0]);
      } else {
        return earthOrbitAngle + PI / 2.0;
      }
    } else {
      double nuForward = currentNu + 0.01;
      double[] posForward = orbitalToCartesian(a, e, i, omega, w, nuForward);
      double vx = posForward[0] - px;
      double vy = posForward[1] - py;
      return Math.atan2(vy, vx);
    }
  }

  // ==============================================================
  //  Display angle update — copied verbatim from old code
  // ==============================================================

  void updateDisplayAngle(double targetAngle, double dt) {
    if (dt <= 0 || dt > 0.5) return;
    double error = angleDifference(targetAngle, displayAngle);
    double desiredAccel = error * ANGLE_KP - angularVelocity * ANGLE_KD;
    angularAcceleration = clamp(desiredAccel, -MAX_ANGULAR_ACCEL, MAX_ANGULAR_ACCEL);
    angularVelocity += angularAcceleration * dt;
    angularVelocity = clamp(angularVelocity, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY);
    displayAngle += angularVelocity * dt;
    displayAngle = normalizeAngle(displayAngle);
  }

  // ==============================================================
  //  Math helpers — preserved from old code
  // ==============================================================

  double clamp(double v, double min, double max) {
    return Math.max(min, Math.min(max, v));
  }

  double normalizeAngle(double a) {
    return ((a % (2.0 * PI)) + 2.0 * PI) % (2.0 * PI);
  }

  double angleDifference(double target, double current) {
    return ((target - current + 3.0 * PI) % (2.0 * PI)) - PI;
  }

  // ==============================================================
  //  Backward compatibility: old method signatures preserved
  // ==============================================================

  double[] getOsculatingOrbitalParams() {
    return flightComputer.osculatingParams(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.GM_EARTH);
  }

  double computeApoapsis() {
    return flightComputer.apoapsisAltitude(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.EARTH_RADIUS_KM,
      MissionPlanner.GM_EARTH);
  }

  double computePerigee() {
    return flightComputer.perigeeAltitude(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.EARTH_RADIUS_KM,
      MissionPlanner.GM_EARTH);
  }

  double timeToApoapsis() {
    return flightComputer.timeToApoapsis(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.GM_EARTH);
  }
}

// ==============================================================
//  SpacecraftForceModel — concrete ForceModel implementation
//  Computes gravity + thrust + drag
// ==============================================================

class SpacecraftForceModel extends ForceModel {
  Spacecraft ship;
  double[] tempDrag = new double[2];

  SpacecraftForceModel(Spacecraft ship) {
    this.ship = ship;
  }

  void computeForce(double[] pos, double[] vel, double[] accelOut) {
    computeForce(pos, vel, accelOut, ship.thrustActive);
  }

  void computeForce(double[] pos, double[] vel, double[] accelOut, boolean useThrust) {
    double rx = pos[0], ry = pos[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    double GM = MissionPlanner.GM_EARTH;
    if (ship.frame != null) GM = ship.frame.gm();

    // Gravity
    double gMag = GM / (r * r);
    double gravX = -gMag * rx / r;
    double gravY = -gMag * ry / r;

    accelOut[0] = gravX;
    accelOut[1] = gravY;

    // Thrust
    if (useThrust) {
      double[] thrustDir = getThrustDirection(pos, vel);
      accelOut[0] += FlightComputer.THRUST_ACCEL * thrustDir[0];
      accelOut[1] += FlightComputer.THRUST_ACCEL * thrustDir[1];
    }

    // Drag
    if (ship.frame != null && ship.earthRef != null) {
      ship.atmosphereModel.dragAcceleration(pos, vel, ship.earthRef, tempDrag);
      accelOut[0] += tempDrag[0];
      accelOut[1] += tempDrag[1];
    }
  }

  double[] getThrustDirection(double[] pos, double[] vel) {
    double rx = pos[0], ry = pos[1];
    double vx = vel[0], vy = vel[1];

    if (ship.state == ShipState.LAUNCHING) {
      double burnTime = (timeManager != null ? timeManager.simTime : 0) - ship.launchStartTime;
      double angle = ship.flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
      return new double[]{Math.cos(angle), Math.sin(angle)};
    } else if (ship.state == ShipState.CIRCULARIZING) {
      double[] peg = ship.flightComputer.pegGuidance(rx, ry, vx, vy, MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);
      return new double[]{Math.cos(peg[1]), Math.sin(peg[1])};
    } else if (ship.state == ShipState.TMI_BURN) {
      return ship.flightComputer.tangentialThrustDirection(rx, ry, true);
    } else if (ship.state == ShipState.TOI_BURN) {
      return ship.flightComputer.tangentialThrustDirection(vel, true);
    }
    // Default: thrust in velocity direction
    double v = Math.sqrt(vx * vx + vy * vy);
    if (v < 0.001) return new double[]{1, 0};
    return new double[]{vx / v, vy / v};
  }

  double bodyRadius() {
    if (ship.frame != null) return ship.frame.bodyRadius();
    if (ship.earthRef != null) return ship.earthRef.radius;
    return MissionPlanner.EARTH_RADIUS_KM;
  }

  boolean thrustActive() {
    return ship.thrustActive;
  }
}
