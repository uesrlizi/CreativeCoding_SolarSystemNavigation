// ========== SPACECRAFT RENDERER ==========

class SpacecraftRenderer {

  void draw(Spacecraft ship, CameraController cam) {
    double[] sp = cam.worldToScreen(ship.worldX, ship.worldY);

    if (Double.isNaN(sp[0]) || Double.isNaN(sp[1]) || Double.isInfinite(cam.scale)) return;

    boolean isShipView = (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget == ship);
    float drawExtent = isShipView ? (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale * 0.7) : 24;
    if (sp[0] + drawExtent < -50 || sp[0] - drawExtent > width + 50 ||
        sp[1] + drawExtent < -50 || sp[1] - drawExtent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);

    float worldAngle = (float)ship.attitude.angle;
    if (isShipView && ship.referenceBody != null) {
      worldAngle = worldAngle - (float)cam.shipViewAngle - HALF_PI;
    }
    if (Float.isNaN(worldAngle) || Float.isInfinite(worldAngle)) {
      worldAngle = 0;
    }
    rotate(worldAngle);

    if (isShipView) {
      float bodyLen = (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale);
      drawShipViewModel(ship, bodyLen);
    } else {
      drawMapIcon(ship, cam);
    }

    popMatrix();

    if (showLabels && !isShipView) {
      fill(red(ship.col), green(ship.col), blue(ship.col), 220);
      textSize(15 * uiScale);
      textAlign(LEFT, CENTER);
      text(ship.name, (float)sp[0] + 16, (float)sp[1]);
    }
  }

  void drawMapIcon(Spacecraft ship, CameraController cam) {
    float s = 9.0f;

    noStroke();

    float chevronTip = s * 0.8f;
    float chevronBack = s * -0.8f;
    float chevronWing = s * 0.9f;
    fill(red(ship.col), green(ship.col), blue(ship.col), 200);
    beginShape();
    vertex(chevronTip, 0);
    vertex(chevronBack, -chevronWing);
    vertex(chevronBack + s * 0.3f, 0);
    vertex(chevronBack, chevronWing);
    endShape(CLOSE);

    fill(255, 255, 255, 140);
    ellipse(0, 0, s * 0.35f, s * 0.35f);
  }

  void drawShipViewModel(Spacecraft ship, float bl) {
    translate(-bl * 0.06f, 0);

    noStroke();

    if (ship.autoControl.targetThrottle > 0.01f) drawExhaustPlumes(ship, bl);
    drawEngineNozzles(bl);
    drawEngineSection(bl);
    drawStage1Body(ship, bl);
    drawGridFins(bl);
    drawInterstage(bl);
    drawStage2Body(ship, bl);
    drawFairing(ship, bl);
    drawBodyPanelLines(bl);
    drawRCSThrusters(ship, bl);
    drawNavLights(ship, bl);
  }

  void drawEngineNozzles(float bl) {
    float nxBase = -bl * 0.32f;
    float nxTip = -bl * 0.45f;
    float nrBase = bl * 0.016f;
    float nrTip = bl * 0.03f;
    float spacing = bl * 0.026f;

    float[][] offsets = {
      {0, 0},
      {0, spacing}, {0, -spacing},
      {0, spacing * 1.7f}, {0, -spacing * 1.7f}
    };

    for (int i = 0; i < 5; i++) {
      float oy = offsets[i][1];

      fill(60, 58, 62);
      beginShape();
      vertex(nxBase, oy - nrBase);
      vertex(nxBase, oy + nrBase);
      vertex(nxTip, oy + nrTip);
      vertex(nxTip, oy - nrTip);
      endShape(CLOSE);

      fill(20, 18, 22);
      ellipse(nxTip, oy, nrTip * 1.6f, nrTip * 1.8f);

      stroke(100, 98, 105);
      strokeWeight(max(0.4f, bl * 0.005f));
      line(nxTip, oy - nrTip, nxTip, oy + nrTip);
      noStroke();
    }

    fill(70, 68, 72);
    rect(nxBase - bl * 0.005f, -bl * 0.04f, bl * 0.01f, bl * 0.08f, 1);
  }

  void drawEngineSection(float bl) {
    float esX1 = -bl * 0.32f;
    float esX2 = -bl * 0.25f;
    float esR = bl * 0.064f;

    fill(55, 53, 58);
    beginShape();
    vertex(esX1, -esR);
    vertex(esX2, -esR * 0.88f);
    vertex(esX2, esR * 0.88f);
    vertex(esX1, esR);
    endShape(CLOSE);

    fill(70, 68, 73);
    beginShape();
    vertex(esX1 + bl * 0.01f, -esR * 0.6f);
    vertex(esX2, -esR * 0.45f);
    vertex(esX2, esR * 0.45f);
    vertex(esX1 + bl * 0.01f, esR * 0.6f);
    endShape(CLOSE);

    stroke(48, 46, 50, 100);
    strokeWeight(max(0.3f, bl * 0.003f));
    for (int i = 0; i < 4; i++) {
      float ly = -esR * 0.7f + i * esR * 0.45f;
      line(esX1 + bl * 0.01f, ly, esX2 - bl * 0.01f, ly);
    }
    noStroke();

    fill(80, 75, 70);
    rect(esX2 - bl * 0.008f, -esR * 0.92f, bl * 0.016f, esR * 1.84f, 1);
  }

  void drawStage1Body(Spacecraft ship, float bl) {
    float s1X1 = -bl * 0.25f;
    float s1X2 = bl * 0.05f;
    float s1R = bl * 0.068f;

    fill(215, 212, 208);
    rect(s1X1, -s1R, s1X2 - s1X1, s1R * 2);

    fill(185, 182, 178);
    rect(s1X1, s1R * 0.55f, s1X2 - s1X1, s1R * 0.45f);
    fill(195, 192, 188);
    rect(s1X1, -s1R, s1X2 - s1X1, s1R * 0.15f);

    float bandCX = -bl * 0.08f;
    float bandW = bl * 0.03f;
    fill(red(ship.col), green(ship.col), blue(ship.col), 180);
    rect(bandCX - bandW * 0.5f, -s1R, bandW, s1R * 2);

    fill(60, 58, 55);
    rect(bandCX - bandW * 1.15f, -s1R, bandW * 0.3f, s1R * 2);

    fill(red(ship.col) * 0.6f, green(ship.col) * 0.6f, blue(ship.col) * 0.6f);
    rect(-bl * 0.15f, -s1R * 0.2f, bl * 0.04f, s1R * 0.4f, 1);
  }

  void drawGridFins(float bl) {
    float finCX = bl * 0.04f;
    float finR = bl * 0.075f;
    float finW = bl * 0.036f;
    float finH = bl * 0.055f;

    for (int side = -1; side <= 1; side += 2) {
      float fy = finR * side;

      fill(70, 68, 65);
      rect(finCX - bl * 0.01f, fy - bl * 0.006f * side, bl * 0.02f, bl * 0.012f * side);

      fill(80, 78, 75);
      beginShape();
      vertex(finCX - finW * 0.3f, fy);
      vertex(finCX - finW * 0.5f, fy + finH * side);
      vertex(finCX + finW * 0.5f, fy + finH * side);
      vertex(finCX + finW * 0.3f, fy);
      endShape(CLOSE);

      stroke(110, 108, 105, 120);
      strokeWeight(max(0.2f, bl * 0.002f));
      for (int g = 1; g <= 4; g++) {
        float gy = fy + (finH * side * g / 5.0f);
        float gx1 = finCX - finW * 0.45f + abs(g - 2.5f) * finW * 0.1f;
        float gx2 = finCX + finW * 0.45f - abs(g - 2.5f) * finW * 0.1f;
        line(gx1, gy, gx2, gy);
      }
      for (int g = 0; g <= 3; g++) {
        float gx = finCX - finW * 0.3f + g * finW * 0.2f;
        line(gx, fy + finH * side * 0.1f, gx, fy + finH * side * 0.9f);
      }
      noStroke();
    }
  }

  void drawInterstage(float bl) {
    float isX1 = bl * 0.05f;
    float isX2 = bl * 0.11f;
    float isR1 = bl * 0.068f;
    float isR2 = bl * 0.057f;

    fill(100, 95, 90);
    beginShape();
    vertex(isX1, -isR1);
    vertex(isX2, -isR2);
    vertex(isX2, isR2);
    vertex(isX1, isR1);
    endShape(CLOSE);

    fill(115, 110, 105);
    beginShape();
    vertex(isX1 + bl * 0.005f, -isR1 * 0.5f);
    vertex(isX2, -isR2 * 0.35f);
    vertex(isX2, isR2 * 0.35f);
    vertex(isX1 + bl * 0.005f, isR1 * 0.5f);
    endShape(CLOSE);

    fill(130, 125, 118);
    rect(isX2 - bl * 0.004f, -isR2 * 1.02f, bl * 0.008f, isR2 * 2.04f);
  }

  void drawStage2Body(Spacecraft ship, float bl) {
    float s2X1 = bl * 0.11f;
    float s2X2 = bl * 0.32f;
    float s2R = bl * 0.057f;

    fill(220, 217, 213);
    rect(s2X1, -s2R, s2X2 - s2X1, s2R * 2);

    fill(195, 192, 188);
    rect(s2X1, s2R * 0.5f, s2X2 - s2X1, s2R * 0.5f);
    fill(200, 197, 193);
    rect(s2X1, -s2R, s2X2 - s2X1, s2R * 0.18f);

    float bandCX = bl * 0.22f;
    float bandW = bl * 0.018f;
    fill(red(ship.col), green(ship.col), blue(ship.col), 160);
    rect(bandCX - bandW * 0.5f, -s2R, bandW, s2R * 2);

    fill(55, 52, 48);
    rect(bandCX + bandW, -s2R, bandW * 0.3f, s2R * 2);
  }

  void drawFairing(Spacecraft ship, float bl) {
    float fBaseX = bl * 0.32f;
    float fTipX = bl * 0.57f;
    float fBaseR = bl * 0.058f;
    float fLen = fTipX - fBaseX;
    int steps = 24;

    float[] ox = new float[steps + 1];
    float[] or = new float[steps + 1];
    for (int i = 0; i <= steps; i++) {
      float t = i / (float)steps;
      ox[i] = fBaseX + t * fLen;
      or[i] = fBaseR * (float)Math.sqrt(1.0 - t * t);
    }

    fill(225, 222, 218);
    beginShape();
    for (int i = 0; i <= steps; i++) vertex(ox[i], -or[i]);
    vertex(fTipX, 0);
    for (int i = steps; i >= 0; i--) vertex(ox[i], or[i]);
    endShape(CLOSE);

    fill(240, 237, 233, 100);
    beginShape();
    for (int i = 0; i <= steps; i++) vertex(ox[i], -or[i] * 0.55f);
    vertex(fTipX, 0);
    endShape(CLOSE);

    fill(180, 175, 168);
    rect(fBaseX - bl * 0.005f, -fBaseR * 1.04f, bl * 0.01f, fBaseR * 2.08f, 1);

    stroke(170, 165, 158, 120);
    strokeWeight(max(0.3f, bl * 0.002f));
    float sepT = 0.55f;
    float sepX = fBaseX + fLen * sepT;
    float sepR = fBaseR * (float)Math.sqrt(1.0 - sepT * sepT);
    line(sepX, -sepR, sepX, sepR);
    noStroke();

    float logoT = 0.3f;
    float logoX = fBaseX + fLen * logoT;
    float logoR = fBaseR * (float)Math.sqrt(1.0 - logoT * logoT) * 0.5f;
    fill(red(ship.col), green(ship.col), blue(ship.col), 120);
    ellipse(logoX, 0, logoR * 1.8f, logoR * 2.2f);
    fill(red(ship.col), green(ship.col), blue(ship.col), 200);
    ellipse(logoX, 0, logoR * 0.8f, logoR * 1.0f);
  }

  void drawBodyPanelLines(float bl) {
    stroke(170, 165, 158, 60);
    strokeWeight(max(0.2f, bl * 0.0015f));

    float s1R = bl * 0.068f;
    float s2R = bl * 0.057f;

    for (int i = -2; i <= 2; i++) {
      if (i == 0) continue;
      float ly = i * s1R * 0.3f;
      line(-bl * 0.24f, ly, bl * 0.04f, ly);
    }

    for (int i = -2; i <= 2; i++) {
      if (i == 0) continue;
      float ly = i * s2R * 0.3f;
      line(bl * 0.12f, ly, bl * 0.31f, ly);
    }

    float[] ringXs = {-bl * 0.2f, -bl * 0.13f, -bl * 0.04f, bl * 0.01f};
    for (float rx : ringXs) {
      line(rx, -s1R, rx, s1R);
    }

    float[] ringXs2 = {bl * 0.16f, bl * 0.26f};
    for (float rx : ringXs2) {
      line(rx, -s2R, rx, s2R);
    }

    noStroke();
  }

  void drawNavLights(Spacecraft ship, float bl) {
    noStroke();

    fill(0, 255, 100, 200);
    ellipse(-bl * 0.1f, bl * 0.069f, bl * 0.01f, bl * 0.008f);

    fill(255, 60, 40, 200);
    ellipse(-bl * 0.1f, -bl * 0.069f, bl * 0.01f, bl * 0.008f);

    fill(255, 255, 240, 180);
    ellipse(bl * 0.38f, 0, bl * 0.008f, bl * 0.008f);
  }

  // ========== 引擎火焰 ==========
  void drawExhaustPlumes(Spacecraft ship, float bl) {
    float[] offsetsY = {0, bl * 0.026f, -bl * 0.026f, bl * 0.044f, -bl * 0.044f};
    float oscPhase = millis() / 1000.0f * 28.0f;

    for (int e = 0; e < 5; e++) {
      float oy = offsetsY[e];
      float baseX = -bl * 0.45f;
      float osc = (float)Math.sin(oscPhase + e * 1.3f) * bl * 0.06f;
      float plumeR = (e == 0) ? bl * 0.028f : bl * 0.018f;

      noStroke();

      // Outer plume
      float outLen = bl * 0.55f + osc;
      fill(255, 100, 20, 60);
      beginShape();
      vertex(baseX, oy - plumeR * 0.6f);
      vertex(baseX, oy + plumeR * 0.6f);
      vertex(baseX - outLen * 0.7f, oy + plumeR * 0.9f);
      vertex(baseX - outLen, oy + plumeR * 0.3f);
      vertex(baseX - outLen, oy - plumeR * 0.3f);
      vertex(baseX - outLen * 0.7f, oy - plumeR * 0.9f);
      endShape(CLOSE);

      // Mid plume
      float midLen = bl * 0.38f + osc * 0.7f;
      fill(255, 170, 25, 120);
      beginShape();
      vertex(baseX, oy - plumeR * 0.45f);
      vertex(baseX, oy + plumeR * 0.45f);
      vertex(baseX - midLen * 0.6f, oy + plumeR * 0.65f);
      vertex(baseX - midLen, oy + plumeR * 0.2f);
      vertex(baseX - midLen, oy - plumeR * 0.2f);
      vertex(baseX - midLen * 0.6f, oy - plumeR * 0.65f);
      endShape(CLOSE);

      // Inner bright core
      float inLen = bl * 0.22f + osc * 0.4f;
      fill(255, 240, 160, 200);
      beginShape();
      vertex(baseX, oy - plumeR * 0.25f);
      vertex(baseX, oy + plumeR * 0.25f);
      vertex(baseX - inLen * 0.5f, oy + plumeR * 0.35f);
      vertex(baseX - inLen, oy + plumeR * 0.1f);
      vertex(baseX - inLen, oy - plumeR * 0.1f);
      vertex(baseX - inLen * 0.5f, oy - plumeR * 0.35f);
      endShape(CLOSE);

      // Mach diamonds
      if (bl > 8) {
        fill(255, 220, 160, 100);
        for (int m = 0; m < 3; m++) {
          float mx = baseX - bl * 0.08f - m * bl * 0.1f + osc * 0.2f * (m + 1);
          float mw = plumeR * 0.8f - m * plumeR * 0.15f;
          float mh = plumeR * 0.35f - m * plumeR * 0.06f;
          ellipse(mx, oy, mw, mh);
        }
      }
    }

    // Combined glow
    fill(255, 180, 60, 25);
    ellipse(-bl * 0.5f, 0, bl * 0.3f, bl * 0.12f);
  }

  // ========== RCS推进器 ==========
  void drawRCSThrusters(Spacecraft ship, float bl) {
    // RCS nozzle positions
    float fwdX = bl * 0.42f;
    float fwdR = bl * 0.052f;
    float aftX = -bl * 0.2f;
    float aftR = bl * 0.069f;

    // Nozzle housings (always visible)
    noStroke();
    fill(90, 88, 92);
    float hw = bl * 0.01f;
    float hh = bl * 0.005f;
    rect(fwdX - hw * 0.5f, -fwdR - hh * 0.5f, hw, hh, 1);
    rect(fwdX - hw * 0.5f, fwdR - hh * 0.5f, hw, hh, 1);
    rect(aftX - hw * 0.5f, -aftR - hh * 0.5f, hw, hh, 1);
    rect(aftX - hw * 0.5f, aftR - hh * 0.5f, hw, hh, 1);

    // Thruster nozzle dots
    fill(30, 28, 32);
    float nd = bl * 0.004f;
    ellipse(fwdX, -fwdR, nd, nd);
    ellipse(fwdX, fwdR, nd, nd);
    ellipse(aftX, -aftR, nd, nd);
    ellipse(aftX, aftR, nd, nd);

    // Plumes (only when turning)
    double accel = ship.angularAcceleration;
    double vel = Math.abs(ship.angularVelocity);
    double activity = Math.abs(accel) / Spacecraft.MAX_ANGULAR_ACCEL + vel / Spacecraft.MAX_ANGULAR_VELOCITY;
    if (activity < 0.0005) return;

    float thrustLevel = (float)Math.min(1.0, activity);
    float time = millis() / 1000.0f;

    // Pulsed jet logic
    float pulseFreq = 2.0f + thrustLevel * 15.0f;
    float pulseDuty = 0.15f + thrustLevel * 0.75f;

    float cycle = time * pulseFreq;
    float cycleFraction = cycle - (float)Math.floor(cycle);
    boolean isFiring = cycleFraction < pulseDuty;

    if (!isFiring) return;
    float oscPhase = time * 35.0f;

    // Firing pair depends on acceleration direction
    if (accel > 0) {
      // CW: forward-top + aft-bottom
      drawRCSPlume(bl, fwdX, -fwdR, -1, 1.0f, oscPhase);
      drawRCSPlume(bl, aftX, aftR, 1, 1.0f, oscPhase + 0.9f);
    } else {
      // CCW: forward-bottom + aft-top
      drawRCSPlume(bl, fwdX, fwdR, 1, 1.0f, oscPhase);
      drawRCSPlume(bl, aftX, -aftR, -1, 1.0f, oscPhase + 0.9f);
    }
  }

  void drawRCSPlume(float bl, float originX, float originY, int dirSign, float level, float phase) {
    noStroke();
    float plumeLen = bl * 0.05f;
    float plumeW = bl * 0.008f;
    float osc = (float)Math.sin(phase) * plumeLen * 0.2f;

    // Outer fringe
    fill(180, 210, 255, 50);
    beginShape();
    vertex(originX, originY);
    vertex(originX + plumeW * 0.3f, originY + dirSign * plumeW * 0.5f);
    vertex(originX + plumeW * 0.1f, originY + dirSign * (plumeLen + osc));
    vertex(originX - plumeW * 0.1f, originY + dirSign * (plumeLen + osc));
    vertex(originX - plumeW * 0.3f, originY + dirSign * plumeW * 0.5f);
    endShape(CLOSE);

    // Mid plume
    fill(200, 225, 255, 100);
    beginShape();
    vertex(originX, originY);
    vertex(originX + plumeW * 0.15f, originY + dirSign * plumeW * 0.3f);
    vertex(originX + plumeW * 0.05f, originY + dirSign * (plumeLen * 0.7f + osc));
    vertex(originX - plumeW * 0.05f, originY + dirSign * (plumeLen * 0.7f + osc));
    vertex(originX - plumeW * 0.15f, originY + dirSign * plumeW * 0.3f);
    endShape(CLOSE);

    // Inner bright core
    fill(230, 240, 255, 160);
    beginShape();
    vertex(originX, originY);
    vertex(originX + plumeW * 0.06f, originY + dirSign * plumeW * 0.1f);
    vertex(originX, originY + dirSign * (plumeLen * 0.45f + osc * 0.6f));
    vertex(originX - plumeW * 0.06f, originY + dirSign * plumeW * 0.1f);
    endShape(CLOSE);

    // Bright spot at nozzle exit
    fill(255, 255, 255, 200);
    ellipse(originX, originY, plumeW * 0.8f, plumeW * 0.5f);
  }

  void drawTrajectory(Spacecraft ship, Trajectory trajectory, CameraController cam) {
    if (trajectory == null || trajectory.segments.size() == 0) return;
    if (ship.referenceBody == null) return;

    float scale = uiScale;
    pushStyle();

    CelestialBody body = ship.referenceBody;

    // 1. 画轨道段（椭圆）
    if (showTrajectory) {
      noFill();
      stroke(red(ship.col), green(ship.col), blue(ship.col), 100);
      strokeWeight(1.2f * scale);

      for (OrbitSegment seg : trajectory.segments) {
        if (seg.mode == PhysicsMode.ON_RAILS && seg.orbit != null) {
          // 直接画椭圆
          beginShape();
          int steps = 200;
          for (int j = 0; j <= steps; j++) {
            double nu = 2.0 * PI * j / steps;
            double[] pos = orbitalToCartesian2D(seg.orbit.a, seg.orbit.e, seg.orbit.w, nu);
            double worldX = body.px + pos[0];
            double worldY = body.py + pos[1];
            double[] sp = cam.worldToScreen(worldX, worldY);
            vertex((float)sp[0], (float)sp[1]);
          }
          endShape(CLOSE);
        }
      }
    }

    // 2. 画事件（AP/PE）- 只在显示轨迹时才显示
    if (showTrajectory && (showApoapsis || showPeriapsis)) {
      float markerSize = 6 * scale;

      for (TrajectoryEvent event : trajectory.events) {
        if ((event.type.equals("apoapsis") && showApoapsis) ||
            (event.type.equals("periapsis") && showPeriapsis)) {
          double worldX = body.px + event.position.x;
          double worldY = body.py + event.position.y;
          double[] sp = cam.worldToScreen(worldX, worldY);

          if (event.type.equals("apoapsis")) {
            fill(255, 150, 100, 200);
          } else {
            fill(100, 200, 255, 200);
          }
          noStroke();
          ellipse((float)sp[0], (float)sp[1], markerSize, markerSize);

          if (showLabels) {
            fill(255, 230);
            textSize(11 * scale);
            textAlign(LEFT, CENTER);
            String label = event.type.equals("apoapsis") ? "AP" : "PE";
            text(label, (float)sp[0] + markerSize + 3, (float)sp[1]);
          }
        }
      }
    }

    popStyle();
  }
}
