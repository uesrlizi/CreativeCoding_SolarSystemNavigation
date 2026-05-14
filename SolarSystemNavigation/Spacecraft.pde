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
  static final double ASCENT_APO_MARGIN = 15.0;  // km overshoot — finite circ burn decays apoapsis
  static final double FIXED_SUBSTEP = 1.0;       // max seconds per physics sub-step
  static final double CIRC_ECC_TOLERANCE = 0.0005;  // eccentricity threshold for circular orbit
  static final double SHIP_LENGTH_KM = 0.05;     // 50 m rocket
  static final double SHIP_WIDTH_KM = 0.014;     // 14 m diameter

  Spacecraft(String name, double a, double e, double i,
    double omega, double w, double M0, double period, color col) {
    this.name = name;
    this.a = a; this.e = e; this.i = i;
    this.omega = omega; this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = period;
    this.col = col;
    this.trailColor = col;
    this.state = ShipState.IDLE;
    this.launchStartTime = 0;
    this.transferStartTime = 0;
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
      while (remainingDt > 0) {
        double step = Math.min(remainingDt, FIXED_SUBSTEP);

        double rx = earthRelPos[0], ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);

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

            if (burnTime < VERTICAL_RISE_TIME) {
              // Phase 1: pure vertical — thrust along radial
              thrustDirX = rx / r;
              thrustDirY = ry / r;
            } else {
              // Phase 2: altitude-based pitch program
              // Pitch angle from vertical f(alt) = (alt/targetAlt)^exp * maxPitch
              // Rocket tilts progressively as it gains altitude, ensuring
              // sufficient tangential velocity at engine cutoff
              double alt = r - MissionPlanner.EARTH_RADIUS_KM;
              double altFrac = Math.max(0.0, Math.min(1.0, alt / MissionPlanner.LEO_ALTITUDE_KM));
              double pitchAngle = Math.pow(altFrac, PITCH_EXPONENT) * MAX_PITCH_RAD;
              double radX = rx / r, radY = ry / r;
              double tanX = -ry / r, tanY = rx / r;
              thrustDirX = radX * Math.cos(pitchAngle) + tanX * Math.sin(pitchAngle);
              thrustDirY = radY * Math.cos(pitchAngle) + tanY * Math.sin(pitchAngle);
            }

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

            double ascentTarget = MissionPlanner.LEO_ALTITUDE_KM + ASCENT_APO_MARGIN;

            if (apoFull >= ascentTarget) {
              // Will cross target — find the fraction of thrust needed
              double gVx = preVx + ax * step;
              double gVy = preVy + ay * step;
              double gRx = preRx + gVx * step;
              double gRy = preRy + gVy * step;
              double apoGrav = computeApoapsisAt(gRx, gRy, gVx, gVy);

              double f = 0.0;
              if (apoFull > apoGrav && apoGrav < ascentTarget) {
                f = (ascentTarget - apoGrav) / (apoFull - apoGrav);
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
            // Circularization: steer to match local circular orbit velocity.
            // Δv = v_circ(r) * tangent - v_current.  Thrust aligns with Δv.
            // At apoapsis Δv is pure tangential; elsewhere it corrects
            // radial velocity so the burn doesn't raise/lower apoapsis.
            double vx = earthRelVel[0], vy = earthRelVel[1];
            double vCirc = Math.sqrt(MissionPlanner.GM_EARTH / r);
            double tanX = -ry / r, tanY = rx / r;
            double dvx = vCirc * tanX - vx;
            double dvy = vCirc * tanY - vy;
            double dv = Math.sqrt(dvx * dvx + dvy * dvy);
            if (dv > 0.0001) {
              ax += THRUST_ACCEL * dvx / dv;
              ay += THRUST_ACCEL * dvy / dv;
            }
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
              state = ShipState.CIRCULARIZING;
              thrustActive = true;
            }
          }
        } else if (state == ShipState.CIRCULARIZING) {
          circBurnDuration -= step;
          double periAlt = computePerigee();
          if (periAlt >= MissionPlanner.LEO_ALTITUDE_KM - 1.0 || circBurnDuration <= 0) {
            finalizeOrbitInsertion();
            remainingDt = 0;
          }
        }
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

  // Compute apoapsis altitude (km) from current Earth-relative state
  double computeApoapsis() {
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double vx = earthRelVel[0], vy = earthRelVel[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double GM = MissionPlanner.GM_EARTH;

    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return Double.MAX_VALUE;  // escaping

    double a = -GM / (2.0 * energy);           // semi-major axis
    double h = rx * vy - ry * vx;              // angular momentum (z)
    double e = Math.sqrt(Math.max(0.0, 1.0 - h * h / (GM * a)));  // eccentricity

    return a * (1.0 + e) - MissionPlanner.EARTH_RADIUS_KM;
  }

  // Same as computeApoapsis() but using explicit position/velocity values
  double computeApoapsisAt(double rx, double ry, double vx, double vy) {
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double GM = MissionPlanner.GM_EARTH;

    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return Double.MAX_VALUE;

    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    double e = Math.sqrt(Math.max(0.0, 1.0 - h * h / (GM * a)));

    return a * (1.0 + e) - MissionPlanner.EARTH_RADIUS_KM;
  }

  double computeEccentricity() {
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double vx = earthRelVel[0], vy = earthRelVel[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double GM = MissionPlanner.GM_EARTH;

    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return Double.MAX_VALUE;

    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    return Math.sqrt(Math.max(0.0, 1.0 - h * h / (GM * a)));
  }

  double computePerigee() {
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double vx = earthRelVel[0], vy = earthRelVel[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double GM = MissionPlanner.GM_EARTH;

    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return Double.MAX_VALUE;

    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    double e = Math.sqrt(Math.max(0.0, 1.0 - h * h / (GM * a)));
    return a * (1.0 - e) - MissionPlanner.EARTH_RADIUS_KM;
  }

  // Time in seconds until the spacecraft reaches apoapsis on its current
  // osculating Kepler orbit. Returns -1 if already past apoapsis, or a large
  // value if the orbit is near-circular (no well-defined apoapsis).
  double timeToApoapsis() {
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double vx = earthRelVel[0], vy = earthRelVel[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double GM = MissionPlanner.GM_EARTH;

    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return -1;  // hyperbolic, should not happen

    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    double e2 = 1.0 - h * h / (GM * a);
    if (e2 < 0) e2 = 0;
    double e = Math.sqrt(e2);
    if (e < 0.0001) return Double.MAX_VALUE;  // near-circular

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
    double n = Math.sqrt(GM / (a * a * a));

    // M = pi at apoapsis
    if (M < PI) return (PI - M) / n;
    return -1;  // already past apoapsis
  }

  void finalizeOrbitInsertion() {
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
  }

  void draw(CameraController cam) {
    if (showTrails) {
      drawOrbitHighlight(cam);
    }

    double[] sp = cam.worldToScreen(px, py);

    boolean isShipView = (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget == this);
    float drawExtent = isShipView ? (float)(SHIP_LENGTH_KM * cam.scale * 0.55) : 20;
    if (sp[0] + drawExtent < -50 || sp[0] - drawExtent > width + 50 ||
        sp[1] + drawExtent < -50 || sp[1] - drawExtent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);

    float angle = calculateOrientation(cam);
    rotate(angle);

    if (isShipView) {
      float bodyLen = (float)(SHIP_LENGTH_KM * cam.scale);
      drawShipViewModel(bodyLen);
    } else {
      drawSpacecraftGraphic();
    }

    popMatrix();

    if (showLabels) {
      fill(red(col), green(col), blue(col), 220);
      textSize(15);
      textAlign(LEFT, CENTER);
      float labelOffset = isShipView ? (float)(SHIP_LENGTH_KM * cam.scale * 0.55) + 8 : 15;
      text(name, (float)sp[0] + labelOffset, (float)sp[1]);
    }
  }

  void drawSpacecraftGraphic() {
    float bodyLen = 10.0;
    float bodyWid = 5.0;

    noStroke();

    for (int g = 3; g >= 1; g--) {
      fill(red(col), green(col), blue(col), 30 / g);
      ellipse(0, 0, 18 + g * 4, 18 + g * 4);
    }

    fill(red(col) * 0.7, green(col) * 0.7, blue(col) * 0.7);
    beginShape();
    vertex(bodyLen * 0.6, 0);
    vertex(-bodyLen * 0.2, -bodyWid * 0.5);
    vertex(-bodyLen * 0.5, -bodyWid * 0.3);
    vertex(-bodyLen * 0.5, bodyWid * 0.3);
    vertex(-bodyLen * 0.2, bodyWid * 0.5);
    endShape(CLOSE);

    fill(col);
    beginShape();
    vertex(bodyLen * 0.5, 0);
    vertex(-bodyLen * 0.3, -bodyWid * 0.4);
    vertex(-bodyLen * 0.5, -bodyWid * 0.25);
    vertex(-bodyLen * 0.5, bodyWid * 0.25);
    vertex(-bodyLen * 0.3, bodyWid * 0.4);
    endShape(CLOSE);

    pushMatrix();
    rotate(radians(35));
    fill(red(col) * 0.8, green(col) * 0.8, blue(col) * 0.8);
    beginShape();
    vertex(0, 0);
    vertex(-bodyLen * 0.3, -2);
    vertex(-bodyLen * 0.8, -1.5);
    vertex(-bodyLen * 0.9, 0);
    endShape(CLOSE);
    popMatrix();

    pushMatrix();
    rotate(radians(-35));
    fill(red(col) * 0.8, green(col) * 0.8, blue(col) * 0.8);
    beginShape();
    vertex(0, 0);
    vertex(-bodyLen * 0.3, 2);
    vertex(-bodyLen * 0.8, 1.5);
    vertex(-bodyLen * 0.9, 0);
    endShape(CLOSE);
    popMatrix();

    if (thrustActive) {
      fill(255, 140, 30, 150);
      triangle(-bodyLen * 0.5, -2, -bodyLen * 0.5, 2, -bodyLen * 0.5 - 10, 0);

      fill(255, 200, 50, 200);
      triangle(-bodyLen * 0.5, -1.5, -bodyLen * 0.5, 1.5, -bodyLen * 0.5 - 7, 0);

      fill(255, 255, 200, 230);
      triangle(-bodyLen * 0.5, -0.8, -bodyLen * 0.5, 0.8, -bodyLen * 0.5 - 4, 0);
    }
  }

  void drawOrbitHighlight(CameraController cam) {
    if (earthRelative) {
      drawEarthRelOrbitHighlight(cam);
      return;
    }

    double arcLength = 0.3;
    int steps = 60;

    noFill();
    stroke(trailColor);
    strokeWeight(2.5);
    beginShape();

    for (int j = 0; j <= steps; j++) {
      double nu = currentNu - arcLength + (arcLength * j / steps);
      double[] pos = orbitalToCartesian(a, e, i, omega, w, nu);
      double[] sp = cam.worldToScreen(pos[0], pos[1]);
      vertex((float)sp[0], (float)sp[1]);
    }

    endShape();
  }

  void drawEarthRelOrbitHighlight(CameraController cam) {
    if (earthRef == null) return;

    if (state == ShipState.LAUNCHING || state == ShipState.CIRCULARIZING) {
      double[] ke = cartesianToKepler(
        new double[]{earthRelPos[0], earthRelPos[1], 0},
        new double[]{earthRelVel[0], earthRelVel[1], 0},
        MissionPlanner.GM_EARTH);
      double ea = ke[0];
      double ee = ke[1];
      double ei = ke[2];
      double eOmega = ke[3];
      double ew = ke[4];
      double eNu = Math.toRadians(ke[5]);

      // Convert current nu to eccentric anomaly E for uniform spatial sampling
      double cosNu = Math.cos(eNu);
      double sinNu = Math.sin(eNu);
      double denom = 1.0 + ee * cosNu;
      double cosE = (ee + cosNu) / denom;
      double sinE = Math.sqrt(1.0 - ee * ee) * sinNu / denom;
      double curE = Math.atan2(sinE, cosE);

      double eArc = 1.0;       // arc in E space (rad)
      int steps = 200;
      double rEarth = MissionPlanner.EARTH_RADIUS_KM;

      // Sample uniformly in E, convert to nu for orbitalToCartesian
      double[][] pts = new double[steps + 1][2];
      boolean[] above = new boolean[steps + 1];
      for (int j = 0; j <= steps; j++) {
        double E = curE - eArc + (2.0 * eArc * j / steps);
        double nu = trueAnomaly(E, ee);
        double[] pos = orbitalToCartesian(ea, ee, ei, eOmega, ew, nu);
        pts[j][0] = pos[0];
        pts[j][1] = pos[1];
        above[j] = Math.sqrt(pos[0] * pos[0] + pos[1] * pos[1]) >= rEarth;
      }

      noFill();
      stroke(trailColor);
      strokeWeight(2.5);

      // Draw segments with proper surface intersection
      boolean inShape = false;
      if (above[0]) {
        beginShape();
        inShape = true;
        double[] sp = cam.worldToScreen(
          earthRef.px + pts[0][0], earthRef.py + pts[0][1]);
        vertex((float)sp[0], (float)sp[1]);
      }

      for (int j = 1; j <= steps; j++) {
        if (above[j - 1] && above[j]) {
          // Both above: continue
          double[] sp = cam.worldToScreen(
            earthRef.px + pts[j][0], earthRef.py + pts[j][1]);
          vertex((float)sp[0], (float)sp[1]);
        } else if (above[j - 1] && !above[j]) {
          // Entering surface: draw intersection, end shape
          double[] isect = sphereIntersect(pts[j - 1], pts[j], rEarth);
          if (isect != null) {
            double[] sp = cam.worldToScreen(
              earthRef.px + isect[0], earthRef.py + isect[1]);
            vertex((float)sp[0], (float)sp[1]);
          }
          endShape();
          inShape = false;
        } else if (!above[j - 1] && above[j]) {
          // Emerging from surface: start shape at intersection, continue
          double[] isect = sphereIntersect(pts[j - 1], pts[j], rEarth);
          beginShape();
          inShape = true;
          if (isect != null) {
            double[] sp = cam.worldToScreen(
              earthRef.px + isect[0], earthRef.py + isect[1]);
            vertex((float)sp[0], (float)sp[1]);
          }
          double[] sp = cam.worldToScreen(
            earthRef.px + pts[j][0], earthRef.py + pts[j][1]);
          vertex((float)sp[0], (float)sp[1]);
        }
        // both below: nothing
      }

      if (inShape) {
        endShape();
      }
      return;
    }

    // ORBIT state: circular LEO arc (behind only)
    double centerX = earthRef.px;
    double centerY = earthRef.py;
    double radius = MissionPlanner.LEO_RADIUS_KM;
    double currentAngle = earthOrbitAngle;
    double arcLength = 0.6;
    int steps = 60;

    noFill();
    stroke(trailColor);
    strokeWeight(2.5);
    beginShape();
    for (int j = 0; j <= steps; j++) {
      double a = currentAngle - arcLength + (arcLength * j / steps);
      double[] sp = cam.worldToScreen(
        centerX + radius * Math.cos(a),
        centerY + radius * Math.sin(a));
      vertex((float)sp[0], (float)sp[1]);
    }
    endShape();
  }

  // Intersection of segment P->Q with circle radius R centered at origin.
  // Returns the (x,y) of the intersection in [0,1] range, or null.
  double[] sphereIntersect(double[] P, double[] Q, double R) {
    double dx = Q[0] - P[0];
    double dy = Q[1] - P[1];
    double a = dx * dx + dy * dy;
    if (a < 1e-20) return null;
    double b = 2.0 * (P[0] * dx + P[1] * dy);
    double c = (P[0] * P[0] + P[1] * P[1]) - R * R;
    double disc = b * b - 4.0 * a * c;
    if (disc < 0) return null;

    double sqrtDisc = Math.sqrt(disc);
    double t0 = (-b - sqrtDisc) / (2.0 * a);
    double t1 = (-b + sqrtDisc) / (2.0 * a);

    double t = (t0 >= 0.0 && t0 <= 1.0) ? t0 : t1;
    if (t < 0.0 || t > 1.0) return null;

    return new double[]{P[0] + t * dx, P[1] + t * dy};
  }

  float calculateOrientation(CameraController cam) {
    if (earthRelative) {
      if (state == ShipState.LAUNCHING && thrustActive) {
        // Point in thrust direction during powered ascent
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);
        double burnTime = timeManager.simTime - launchStartTime;

        if (burnTime < VERTICAL_RISE_TIME) {
          return (float)Math.atan2(ry, rx);
        } else {
          double alt = r - MissionPlanner.EARTH_RADIUS_KM;
          double altFrac = Math.max(0.0, Math.min(1.0, alt / MissionPlanner.LEO_ALTITUDE_KM));
          double pitchAngle = Math.pow(altFrac, PITCH_EXPONENT) * MAX_PITCH_RAD;
          double radX = rx / r, radY = ry / r;
          double tanX = -ry / r, tanY = rx / r;
          double thrX = radX * Math.cos(pitchAngle) + tanX * Math.sin(pitchAngle);
          double thrY = radY * Math.cos(pitchAngle) + tanY * Math.sin(pitchAngle);
          return (float)Math.atan2(thrY, thrX);
        }
      } else if (state == ShipState.CIRCULARIZING) {
        // Point along Δv vector = v_circ*tangent - v_current
        double vx = earthRelVel[0], vy = earthRelVel[1];
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);
        double vCirc = Math.sqrt(MissionPlanner.GM_EARTH / r);
        double tanX = -ry / r, tanY = rx / r;
        double dvx = vCirc * tanX - vx;
        double dvy = vCirc * tanY - vy;
        return (float)Math.atan2(dvy, dvx);
      } else {
        // Coasting or in orbit — maintain orbit-relative orientation
        return (float)(earthOrbitAngle + PI / 2.0);
      }
    }

    double nuForward = currentNu + 0.01;
    double[] posForward = orbitalToCartesian(a, e, i, omega, w, nuForward);

    double vx = posForward[0] - px;
    double vy = posForward[1] - py;

    return (float)Math.atan2(vy, vx);
  }

  void drawShipViewModel(float bodyLen) {
    float bodyWid = bodyLen * 0.28;
    float nozzleLen = bodyLen * 0.12;

    noStroke();

    // Glow halo
    float glowR = bodyLen * 0.8;
    for (int g = 3; g >= 1; g--) {
      float r = glowR + g * bodyLen * 0.12;
      fill(red(col), green(col), blue(col), 20 / g);
      ellipse(0, 0, r, r);
    }

    // Engine exhaust (only when thrusting)
    if (thrustActive) {
      drawShipViewExhaust(bodyLen, nozzleLen);
    }

    // Engine nozzle
    float nx1 = -bodyLen * 0.46;
    float nx2 = -bodyLen * 0.46 - nozzleLen;
    float ny1 = bodyWid * 0.25;
    float ny2 = bodyWid * 0.38;
    fill(70, 70, 75);
    beginShape();
    vertex(nx1, -ny1);
    vertex(nx1, ny1);
    vertex(nx2, ny2);
    vertex(nx2, -ny2);
    endShape(CLOSE);
    // Nozzle rim
    stroke(140, 140, 145);
    strokeWeight(max(0.5, bodyLen * 0.024));
    line(nx2, -ny2, nx2, ny2);
    noStroke();

    // Fins
    drawShipViewFin(bodyLen, bodyWid, 1);
    drawShipViewFin(bodyLen, bodyWid, -1);

    // Main body - tapered
    fill(red(col) * 0.85, green(col) * 0.85, blue(col) * 0.85);
    beginShape();
    vertex(bodyLen * 0.55, 0);
    vertex(bodyLen * 0.4, -bodyWid * 0.2);
    vertex(bodyLen * 0.3, -bodyWid * 0.42);
    vertex(bodyLen * 0.08, -bodyWid * 0.5);
    vertex(-bodyLen * 0.38, -bodyWid * 0.48);
    vertex(-bodyLen * 0.46, -bodyWid * 0.25);
    vertex(-bodyLen * 0.46, bodyWid * 0.25);
    vertex(-bodyLen * 0.38, bodyWid * 0.48);
    vertex(bodyLen * 0.08, bodyWid * 0.5);
    vertex(bodyLen * 0.3, bodyWid * 0.42);
    vertex(bodyLen * 0.4, bodyWid * 0.2);
    endShape(CLOSE);

    // Body highlight
    fill(red(col), green(col), blue(col), 80);
    beginShape();
    vertex(bodyLen * 0.4, -bodyWid * 0.08);
    vertex(bodyLen * 0.25, -bodyWid * 0.3);
    vertex(bodyLen * 0.05, -bodyWid * 0.38);
    vertex(-bodyLen * 0.35, -bodyWid * 0.35);
    vertex(-bodyLen * 0.35, -bodyWid * 0.08);
    vertex(bodyLen * 0.05, -bodyWid * 0.15);
    vertex(bodyLen * 0.35, -bodyWid * 0.05);
    endShape(CLOSE);

    // Cockpit window
    float winW = bodyLen * 0.14;
    float winH = bodyLen * 0.18;
    fill(100, 180, 255, 200);
    ellipse(bodyLen * 0.35, 0, winW, winH);
    if (bodyLen > 15) {
      fill(160, 215, 255, 120);
      ellipse(bodyLen * 0.35, -winH * 0.17, winW * 0.5, winH * 0.55);
    }

    // Body stripe
    fill(red(col) * 0.6, green(col) * 0.6, blue(col) * 0.6);
    rect(-bodyLen * 0.05, -bodyWid * 0.48, bodyWid * 0.4, bodyWid * 0.96, max(1.0, bodyLen * 0.06));
  }

  void drawShipViewFin(float bodyLen, float bodyWid, float side) {
    float bx = bodyLen * 0.15;
    float by = bodyWid * 0.5 * side;
    float finLen = bodyLen * 0.32;
    float finWid = bodyLen * 0.24;

    fill(red(col) * 0.75, green(col) * 0.75, blue(col) * 0.75);
    beginShape();
    vertex(bx, by);
    vertex(bx - bodyLen * 0.12, by + finWid * side);
    vertex(bx - bodyLen * 0.2, by + finWid * 1.2 * side);
    vertex(bx - finLen, by + finWid * 0.9 * side);
    vertex(bx - finLen * 0.8, by + finWid * 0.5 * side);
    endShape(CLOSE);
  }

  void drawShipViewExhaust(float bodyLen, float nozzleLen) {
    float baseX = -bodyLen * 0.46 - nozzleLen;
    float oscScale = bodyLen * 0.1;
    float flameOsc = (float)Math.sin(frameCount * 0.4) * oscScale;

    noStroke();
    // Outer flame
    float outLen = bodyLen * 0.84 + flameOsc;
    fill(255, 120, 25, 100);
    beginShape();
    vertex(baseX, -bodyLen * 0.08);
    vertex(baseX, bodyLen * 0.08);
    vertex(baseX - outLen * 0.6, bodyLen * 0.12);
    vertex(baseX - outLen, bodyLen * 0.04);
    vertex(baseX - outLen, -bodyLen * 0.04);
    vertex(baseX - outLen * 0.6, -bodyLen * 0.12);
    endShape(CLOSE);

    // Middle flame
    float midLen = bodyLen * 0.56 + flameOsc * 0.7;
    fill(255, 185, 30, 170);
    beginShape();
    vertex(baseX, -bodyLen * 0.06);
    vertex(baseX, bodyLen * 0.06);
    vertex(baseX - midLen * 0.5, bodyLen * 0.09);
    vertex(baseX - midLen, bodyLen * 0.03);
    vertex(baseX - midLen, -bodyLen * 0.03);
    vertex(baseX - midLen * 0.5, -bodyLen * 0.09);
    endShape(CLOSE);

    // Inner flame
    float inLen = bodyLen * 0.32 + flameOsc * 0.4;
    fill(255, 250, 180, 220);
    beginShape();
    vertex(baseX, -bodyLen * 0.036);
    vertex(baseX, bodyLen * 0.036);
    vertex(baseX - inLen * 0.4, bodyLen * 0.05);
    vertex(baseX - inLen, bodyLen * 0.02);
    vertex(baseX - inLen, -bodyLen * 0.02);
    vertex(baseX - inLen * 0.4, -bodyLen * 0.05);
    endShape(CLOSE);

    // Mach diamonds
    if (bodyLen > 10) {
      fill(255, 220, 180, 140);
      for (int i = 0; i < 3; i++) {
        float mx = baseX - bodyLen * 0.16 - i * bodyLen * 0.2 + flameOsc * 0.3 * (i + 1);
        float mw = bodyLen * 0.07 - i * bodyLen * 0.012;
        float mh = bodyLen * 0.024 - i * bodyLen * 0.004;
        ellipse(mx, 0, mw, mh);
      }
    }
  }
}
