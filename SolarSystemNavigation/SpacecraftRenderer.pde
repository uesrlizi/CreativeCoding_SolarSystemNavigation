class SpacecraftRenderer {

  void draw(Spacecraft ship, CameraController cam) {
    double[] sp = cam.worldToScreen(ship.px, ship.py);

    if (Double.isNaN(sp[0]) || Double.isNaN(sp[1]) || Double.isNaN(cam.scale)) return;

    boolean isShipView = (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget == ship);
    float drawExtent = isShipView ? (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale * 0.7) : 24;
    if (sp[0] + drawExtent < -50 || sp[0] - drawExtent > width + 50 ||
        sp[1] + drawExtent < -50 || sp[1] - drawExtent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);

    float angle = calculateOrientation(ship, cam);
    if (Float.isNaN(angle) || Float.isInfinite(angle)) {
      angle = 0;
    }
    rotate(angle);

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
      text("Spacecraft", (float)sp[0] + 16, (float)sp[1]);
    }
  }

  // ============================================================
  //  MAP-VIEW ICON — clean geometric chevron
  // ============================================================

  void drawMapIcon(Spacecraft ship, CameraController cam) {
    float s = 9.0;  // icon half-size

    noStroke();

    // Directional chevron (points in +X = forward), centered at origin
    float chevronTip = s * 0.8;
    float chevronBack = s * -0.8;
    float chevronWing = s * 0.9;
    fill(red(ship.col), green(ship.col), blue(ship.col), 200);
    beginShape();
    vertex(chevronTip, 0);
    vertex(chevronBack, -chevronWing);
    vertex(chevronBack + s * 0.3, 0);
    vertex(chevronBack, chevronWing);
    endShape(CLOSE);

    // Center highlight
    fill(255, 255, 255, 140);
    ellipse(0, 0, s * 0.35, s * 0.35);
  }

  // ============================================================
  //  SHIP-VIEW MODEL — detailed multi-stage launch vehicle
  //  Local coords: +X = nose, -X = tail, Y = lateral
  //  Origin = ship center (geometric midpoint)
  // ============================================================

  void drawShipViewModel(Spacecraft ship, float bl) {
    // Origin at geometric center (local X=0.06); engines at X=-0.45 → pad at Y=-0.10
    translate(-bl * 0.06, 0);

    noStroke();

    if (ship.thrustActive) drawExhaustPlumes(ship, bl);

    drawEngineNozzles(bl);
    drawEngineSection(bl);
    drawStage1Body(ship, bl);
    drawGridFins(bl);
    drawInterstage(bl);
    drawStage2Body(ship, bl);
    drawFairing(ship, bl);
    drawBodyPanelLines(bl);
    drawNavLights(ship, bl);
  }

  // --- Glow halo ---

  void drawShipGlow(Spacecraft ship, float bl) {
    float cx = bl * 0.06;
    for (int g = 3; g >= 1; g--) {
      float rx = bl * 0.55 + g * bl * 0.08;
      float ry = bl * 0.14 + g * bl * 0.06;
      fill(red(ship.col), green(ship.col), blue(ship.col), 12 / g);
      ellipse(cx, 0, rx * 2, ry * 2);
    }
  }

  // --- Engine nozzles (5 nozzles, quincunx pattern) ---

  void drawEngineNozzles(float bl) {
    float nxBase = -bl * 0.32;   // nozzle throat X
    float nxTip  = -bl * 0.45;   // nozzle exit X
    float nrBase = bl * 0.016;   // throat radius
    float nrTip  = bl * 0.030;   // exit radius
    float spacing = bl * 0.026;  // lateral spacing from centerline

    float[][] offsets = {
      {0, 0},                                    // center
      {0,  spacing}, {0, -spacing},              // top/bottom
      {0,  spacing * 1.7}, {0, -spacing * 1.7}   // outer
    };

    for (int i = 0; i < 5; i++) {
      float ox = 0, oy = offsets[i][1];

      // Nozzle bell
      fill(60, 58, 62);
      beginShape();
      vertex(nxBase, oy - nrBase);
      vertex(nxBase, oy + nrBase);
      vertex(nxTip,  oy + nrTip);
      vertex(nxTip,  oy - nrTip);
      endShape(CLOSE);

      // Nozzle interior (dark)
      fill(20, 18, 22);
      ellipse(nxTip, oy, nrTip * 1.6, nrTip * 1.8);

      // Nozzle rim highlight
      stroke(100, 98, 105);
      strokeWeight(max(0.4, bl * 0.005));
      line(nxTip, oy - nrTip, nxTip, oy + nrTip);
      noStroke();
    }

    // Nozzle support structure
    fill(70, 68, 72);
    rect(nxBase - bl * 0.005, -bl * 0.04, bl * 0.01, bl * 0.08, 1);
  }

  // --- Engine section / thrust structure ---

  void drawEngineSection(float bl) {
    float esX1 = -bl * 0.32;
    float esX2 = -bl * 0.25;
    float esR = bl * 0.064;

    // Main engine compartment
    fill(55, 53, 58);
    beginShape();
    vertex(esX1, -esR);
    vertex(esX2, -esR * 0.88);
    vertex(esX2,  esR * 0.88);
    vertex(esX1,  esR);
    endShape(CLOSE);

    // Engine section highlight
    fill(70, 68, 73);
    beginShape();
    vertex(esX1 + bl * 0.01, -esR * 0.6);
    vertex(esX2, -esR * 0.45);
    vertex(esX2,  esR * 0.45);
    vertex(esX1 + bl * 0.01,  esR * 0.6);
    endShape(CLOSE);

    // Thermal blanket texture lines
    stroke(48, 46, 50, 100);
    strokeWeight(max(0.3, bl * 0.003));
    for (int i = 0; i < 4; i++) {
      float ly = -esR * 0.7 + i * esR * 0.45;
      line(esX1 + bl * 0.01, ly, esX2 - bl * 0.01, ly);
    }
    noStroke();

    // Base heat shield ring
    fill(80, 75, 70);
    rect(esX2 - bl * 0.008, -esR * 0.92, bl * 0.016, esR * 1.84, 1);
  }

  // --- Stage 1 body ---

  void drawStage1Body(Spacecraft ship, float bl) {
    float s1X1 = -bl * 0.25;
    float s1X2 =  bl * 0.05;
    float s1R = bl * 0.068;

    // Main cylinder
    fill(215, 212, 208);
    rect(s1X1, -s1R, s1X2 - s1X1, s1R * 2);

    // Body shading — darker toward edges
    fill(185, 182, 178);
    rect(s1X1,  s1R * 0.55, s1X2 - s1X1, s1R * 0.45);
    fill(195, 192, 188);
    rect(s1X1, -s1R, s1X2 - s1X1, s1R * 0.15);

    // Accent band (ship color)
    float bandCX = -bl * 0.08;
    float bandW = bl * 0.03;
    fill(red(ship.col), green(ship.col), blue(ship.col), 180);
    rect(bandCX - bandW * 0.5, -s1R, bandW, s1R * 2);

    // Dark stripe
    fill(60, 58, 55);
    rect(bandCX - bandW * 1.15, -s1R, bandW * 0.3, s1R * 2);

    // USA / mission marking (simplified as colored block)
    fill(red(ship.col) * 0.6, green(ship.col) * 0.6, blue(ship.col) * 0.6);
    rect(-bl * 0.15, -s1R * 0.2, bl * 0.04, s1R * 0.4, 1);
  }

  // --- Grid fins (4, deployed) ---

  void drawGridFins(float bl) {
    float finCX = bl * 0.04;
    float finR = bl * 0.075;
    float finW = bl * 0.036;
    float finH = bl * 0.055;

    for (int side = -1; side <= 1; side += 2) {
      float fy = finR * side;

      // Fin base bracket
      fill(70, 68, 65);
      rect(finCX - bl * 0.01, fy - bl * 0.006 * side, bl * 0.02, bl * 0.012 * side);

      // Fin body
      fill(80, 78, 75);
      beginShape();
      vertex(finCX - finW * 0.3, fy);
      vertex(finCX - finW * 0.5, fy + finH * side);
      vertex(finCX + finW * 0.5, fy + finH * side);
      vertex(finCX + finW * 0.3, fy);
      endShape(CLOSE);

      // Grid pattern (horizontal lines)
      stroke(110, 108, 105, 120);
      strokeWeight(max(0.2, bl * 0.002));
      for (int g = 1; g <= 4; g++) {
        float gy = fy + (finH * side * g / 5.0);
        float gx1 = finCX - finW * 0.45 + abs(g - 2.5) * finW * 0.1;
        float gx2 = finCX + finW * 0.45 - abs(g - 2.5) * finW * 0.1;
        line(gx1, gy, gx2, gy);
      }
      // Vertical grid lines
      for (int g = 0; g <= 3; g++) {
        float gx = finCX - finW * 0.3 + g * finW * 0.2;
        line(gx, fy + finH * side * 0.1, gx, fy + finH * side * 0.9);
      }
      noStroke();
    }
  }

  // --- Interstage adapter ---

  void drawInterstage(float bl) {
    float isX1 = bl * 0.05;
    float isX2 = bl * 0.11;
    float isR1 = bl * 0.068;  // stage 1 radius
    float isR2 = bl * 0.057;  // stage 2 radius

    // Tapered interstage
    fill(100, 95, 90);
    beginShape();
    vertex(isX1, -isR1);
    vertex(isX2, -isR2);
    vertex(isX2,  isR2);
    vertex(isX1,  isR1);
    endShape(CLOSE);

    // Highlight
    fill(115, 110, 105);
    beginShape();
    vertex(isX1 + bl * 0.005, -isR1 * 0.5);
    vertex(isX2, -isR2 * 0.35);
    vertex(isX2,  isR2 * 0.35);
    vertex(isX1 + bl * 0.005,  isR1 * 0.5);
    endShape(CLOSE);

    // Separation ring (upper)
    fill(130, 125, 118);
    rect(isX2 - bl * 0.004, -isR2 * 1.02, bl * 0.008, isR2 * 2.04);
  }

  // --- Stage 2 body ---

  void drawStage2Body(Spacecraft ship, float bl) {
    float s2X1 = bl * 0.11;
    float s2X2 = bl * 0.32;
    float s2R = bl * 0.055;

    // Main cylinder
    fill(220, 217, 213);
    rect(s2X1, -s2R, s2X2 - s2X1, s2R * 2);

    // Shading
    fill(195, 192, 188);
    rect(s2X1,  s2R * 0.5, s2X2 - s2X1, s2R * 0.5);
    fill(200, 197, 193);
    rect(s2X1, -s2R, s2X2 - s2X1, s2R * 0.18);

    // Accent stripe
    float bandCX = bl * 0.22;
    float bandW = bl * 0.018;
    fill(red(ship.col), green(ship.col), blue(ship.col), 160);
    rect(bandCX - bandW * 0.5, -s2R, bandW, s2R * 2);

    // Dark tech band
    fill(55, 52, 48);
    rect(bandCX + bandW, -s2R, bandW * 0.3, s2R * 2);
  }

  // --- Payload fairing ---

  void drawFairing(Spacecraft ship, float bl) {
    float fBaseX = bl * 0.32;
    float fTipX  = bl * 0.57;
    float fBaseR = bl * 0.058;
    float fLen = fTipX - fBaseX;
    int steps = 24;

    // Precompute ogive profile points
    float[] ox = new float[steps + 1];
    float[] or_ = new float[steps + 1];
    for (int i = 0; i <= steps; i++) {
      float t = i / (float)steps;
      ox[i] = fBaseX + t * fLen;
      or_[i] = fBaseR * (float)Math.sqrt(1.0 - t * t);
    }

    // Ogive fairing body
    fill(225, 222, 218);
    beginShape();
    for (int i = 0; i <= steps; i++) vertex(ox[i], -or_[i]);
    vertex(fTipX, 0);
    for (int i = steps; i >= 0; i--) vertex(ox[i], or_[i]);
    endShape(CLOSE);

    // Fairing highlight (upper half shading)
    fill(240, 237, 233, 100);
    beginShape();
    for (int i = 0; i <= steps; i++) vertex(ox[i], -or_[i] * 0.55);
    vertex(fTipX, 0);
    endShape(CLOSE);

    // Fairing base ring
    fill(180, 175, 168);
    rect(fBaseX - bl * 0.005, -fBaseR * 1.04, bl * 0.01, fBaseR * 2.08, 1);

    // Fairing separation line (where fairing splits to release payload)
    stroke(170, 165, 158, 120);
    strokeWeight(max(0.3, bl * 0.002));
    float sepT = 0.55;
    float sepX = fBaseX + fLen * sepT;
    float sepR = fBaseR * (float)Math.sqrt(1.0 - sepT * sepT);
    line(sepX, -sepR, sepX, sepR);
    noStroke();

    // Mission patch / logo
    float logoT = 0.30;
    float logoX = fBaseX + fLen * logoT;
    float logoR = fBaseR * (float)Math.sqrt(1.0 - logoT * logoT) * 0.5;
    fill(red(ship.col), green(ship.col), blue(ship.col), 120);
    ellipse(logoX, 0, logoR * 1.8, logoR * 2.2);
    fill(red(ship.col), green(ship.col), blue(ship.col), 200);
    ellipse(logoX, 0, logoR * 0.8, logoR * 1.0);
  }

  // --- Body panel lines (vertical and circumferential) ---

  void drawBodyPanelLines(float bl) {
    stroke(170, 165, 158, 60);
    strokeWeight(max(0.2, bl * 0.0015));

    float s1R = bl * 0.068;
    float s2R = bl * 0.055;

    // Vertical lines on stage 1
    for (int i = -2; i <= 2; i++) {
      if (i == 0) continue;
      float ly = i * s1R * 0.3;
      line(-bl * 0.24, ly, bl * 0.04, ly);
    }

    // Vertical lines on stage 2
    for (int i = -2; i <= 2; i++) {
      if (i == 0) continue;
      float ly = i * s2R * 0.3;
      line(bl * 0.12, ly, bl * 0.31, ly);
    }

    // Circumferential ring frames on stage 1
    float[] ringXs = {-bl * 0.2, -bl * 0.13, -bl * 0.04, bl * 0.01};
    for (float rx : ringXs) {
      line(rx, -s1R, rx, s1R);
    }

    // Circumferential rings on stage 2
    float[] ringXs2 = {bl * 0.16, bl * 0.26};
    for (float rx : ringXs2) {
      line(rx, -s2R, rx, s2R);
    }

    noStroke();
  }

  // --- Navigation / position lights ---

  void drawNavLights(Spacecraft ship, float bl) {
    noStroke();

    // Green nav light on stage 1 (right = +Y)
    fill(0, 255, 100, 200);
    ellipse(-bl * 0.1,  bl * 0.069, bl * 0.01, bl * 0.008);

    // Red nav light on stage 1 (left = -Y)
    fill(255, 60, 40, 200);
    ellipse(-bl * 0.1, -bl * 0.069, bl * 0.01, bl * 0.008);

    // White strobe on fairing
    fill(255, 255, 240, 180);
    ellipse(bl * 0.38, 0, bl * 0.008, bl * 0.008);
  }

  // --- Exhaust plumes (5 engines) ---

  void drawExhaustPlumes(Spacecraft ship, float bl) {
    float[] offsetsY = {0, bl * 0.026, -bl * 0.026, bl * 0.044, -bl * 0.044};
    float oscPhase = millis() / 1000.0 * 28.0;

    for (int e = 0; e < 5; e++) {
      float oy = offsetsY[e];
      float baseX = -bl * 0.45;  // nozzle exit
      float osc = (float)Math.sin(oscPhase + e * 1.3) * bl * 0.06;
      float plumeR = (e == 0) ? bl * 0.028 : bl * 0.018;  // center engine larger

      noStroke();

      // Outer plume
      float outLen = bl * 0.55 + osc;
      fill(255, 100, 20, 60);
      beginShape();
      vertex(baseX, oy - plumeR * 0.6);
      vertex(baseX, oy + plumeR * 0.6);
      vertex(baseX - outLen * 0.7, oy + plumeR * 0.9);
      vertex(baseX - outLen, oy + plumeR * 0.3);
      vertex(baseX - outLen, oy - plumeR * 0.3);
      vertex(baseX - outLen * 0.7, oy - plumeR * 0.9);
      endShape(CLOSE);

      // Mid plume
      float midLen = bl * 0.38 + osc * 0.7;
      fill(255, 170, 25, 120);
      beginShape();
      vertex(baseX, oy - plumeR * 0.45);
      vertex(baseX, oy + plumeR * 0.45);
      vertex(baseX - midLen * 0.6, oy + plumeR * 0.65);
      vertex(baseX - midLen, oy + plumeR * 0.2);
      vertex(baseX - midLen, oy - plumeR * 0.2);
      vertex(baseX - midLen * 0.6, oy - plumeR * 0.65);
      endShape(CLOSE);

      // Inner bright core
      float inLen = bl * 0.22 + osc * 0.4;
      fill(255, 240, 160, 200);
      beginShape();
      vertex(baseX, oy - plumeR * 0.25);
      vertex(baseX, oy + plumeR * 0.25);
      vertex(baseX - inLen * 0.5, oy + plumeR * 0.35);
      vertex(baseX - inLen, oy + plumeR * 0.1);
      vertex(baseX - inLen, oy - plumeR * 0.1);
      vertex(baseX - inLen * 0.5, oy - plumeR * 0.35);
      endShape(CLOSE);

      // Mach diamonds
      if (bl > 8) {
        fill(255, 220, 160, 100);
        for (int m = 0; m < 3; m++) {
          float mx = baseX - bl * 0.08 - m * bl * 0.1 + osc * 0.2 * (m + 1);
          float mw = plumeR * 0.8 - m * plumeR * 0.15;
          float mh = plumeR * 0.35 - m * plumeR * 0.06;
          ellipse(mx, oy, mw, mh);
        }
      }
    }

    // Combined glow
    fill(255, 180, 60, 25);
    ellipse(-bl * 0.50, 0, bl * 0.3, bl * 0.12);
  }

  // ============================================================
  //  Orientation calculation
  // ============================================================

  float calculateOrientation(Spacecraft ship, CameraController cam) {
    float worldAngle;

    if (ship.earthRelative) {
      if (ship.state == ShipState.IDLE ||
          ship.state == ShipState.COUNTDOWN ||
          ship.state == ShipState.IGNITION) {
        worldAngle = (float)(ship.earthOrbitAngle);
      } else if (ship.state == ShipState.LAUNCHING && ship.thrustActive) {
        double rx = ship.earthRelPos[0], ry = ship.earthRelPos[1];
        double burnTime = timeManager.simTime - ship.launchStartTime;
        worldAngle = (float)ship.getAscentThrustAngle(rx, ry, burnTime);
      } else if (ship.state == ShipState.CIRCULARIZING) {
        double rx = ship.earthRelPos[0], ry = ship.earthRelPos[1];
        double vx = ship.earthRelVel[0], vy = ship.earthRelVel[1];
        double[] peg = ship.getPEGGuidance(rx, ry, vx, vy);
        worldAngle = (float)peg[1];
      } else {
        worldAngle = (float)(ship.earthOrbitAngle + PI / 2.0);
      }
    } else {
      double nuForward = ship.currentNu + 0.01;
      double[] posForward = orbitalToCartesian(ship.a, ship.e, ship.i, ship.omega, ship.w, nuForward);
      double vx = posForward[0] - ship.px;
      double vy = posForward[1] - ship.py;
      worldAngle = (float)Math.atan2(vy, vx);
    }

    // In ship view, the worldToScreen transform rotates the coordinate system:
    //   screen X = tangential, screen Y = -radial (up = away from Earth)
    // Convert world-space angle to view-space angle
    boolean isShipView = (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget == ship);
    if (isShipView && ship.earthRelative) {
      return worldAngle - (float)cam.shipViewAngle - HALF_PI;
    }
    return worldAngle;
  }
}
