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
  static final double THRUST_ACCEL = 0.025;      // km/s^2 (~2.5g)
  static final double MAX_PITCH = PI / 2.0 * 0.94; // ~84.6°
  static final double PITCH_START_TIME = 30.0;   // seconds, vertical-only phase
  static final double PITCH_RAMP_TIME = 220.0;   // seconds, pitch transition
  static final double FIXED_SUBSTEP = 1.0;       // max seconds per physics sub-step
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

    if (state == ShipState.LAUNCHING) {
      double dt = t - lastUpdateTime;
      if (dt <= 0) dt = 1.0 / 60.0;
      if (dt > 3600) dt = 3600;
      lastUpdateTime = t;

      // Sub-stepping with per-step time tracking
      double currentT = t - dt;  // simTime at start of this frame
      double remainingDt = dt;
      while (remainingDt > 0) {
        double step = Math.min(remainingDt, FIXED_SUBSTEP);

        double rx = earthRelPos[0];
        double ry = earthRelPos[1];
        double r = Math.sqrt(rx * rx + ry * ry);

        // Gravity
        double gMag = MissionPlanner.GM_EARTH / (r * r);
        double ax = -gMag * rx / r;
        double ay = -gMag * ry / r;

        // Thrust (if still burning)
        if (thrustActive) {
          double burnTime = currentT - launchStartTime;
          double pitch;
          if (burnTime < PITCH_START_TIME) {
            pitch = 0;  // vertical
          } else if (burnTime < PITCH_START_TIME + PITCH_RAMP_TIME) {
            pitch = MAX_PITCH * (burnTime - PITCH_START_TIME) / PITCH_RAMP_TIME;
          } else {
            pitch = MAX_PITCH;
          }

          double radX = rx / r, radY = ry / r;
          double tanX = -ry / r, tanY = rx / r;
          double cosP = Math.cos(pitch);
          double sinP = Math.sin(pitch);
          ax += THRUST_ACCEL * (radX * cosP + tanX * sinP);
          ay += THRUST_ACCEL * (radY * cosP + tanY * sinP);
        }

        // Semi-implicit Euler
        earthRelVel[0] += ax * step;
        earthRelVel[1] += ay * step;
        earthRelPos[0] += earthRelVel[0] * step;
        earthRelPos[1] += earthRelVel[1] * step;

        currentT += step;
        remainingDt -= step;
      }

      // Update derived values
      double rx = earthRelPos[0], ry = earthRelPos[1];
      double r = Math.sqrt(rx * rx + ry * ry);
      launchAltitude = r - MissionPlanner.EARTH_RADIUS_KM;
      earthOrbitAngle = Math.atan2(ry, rx);

      // Guidance: check apoapsis and handle coast/circularize
      if (thrustActive) {
        double apoAlt = computeApoapsis();
        if (apoAlt >= MissionPlanner.LEO_ALTITUDE_KM) {
          thrustActive = false;  // apoapsis reached target — cut engine
        }
      } else {
        // Coasting — check if at apoapsis
        double vx = earthRelVel[0], vy = earthRelVel[1];
        double radX = rx / r, radY = ry / r;
        double radialVel = vx * radX + vy * radY;
        if (Math.abs(radialVel) < 0.01 && launchAltitude >= 390.0) {
          finalizeOrbitInsertion();
        }
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
      if (state == ShipState.LAUNCHING) return; // No trail during ascent
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
    double centerX = earthRef.px;
    double centerY = earthRef.py;
    double radius = MissionPlanner.LEO_RADIUS_KM;
    double currentAngle = earthOrbitAngle;

    double arcLength = 0.6;
    int steps = 40;

    noFill();
    stroke(trailColor);
    strokeWeight(1.5);
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

  float calculateOrientation(CameraController cam) {
    if (earthRelative) {
      if (state == ShipState.LAUNCHING) {
        // Point in velocity direction during ascent
        return (float)Math.atan2(earthRelVel[1], earthRelVel[0]);
      } else {
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
