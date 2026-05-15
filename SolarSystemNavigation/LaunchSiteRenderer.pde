class LaunchSiteRenderer {

  void draw(LaunchSite site, CameraController cam, Spacecraft ship) {
    if (cam.getMode() != ViewMode.SHIP_VIEW) return;

    double[] sp = cam.worldToScreen(site.px, site.py);
    if (Double.isNaN(sp[0]) || Double.isNaN(sp[1])) return;

    float bl = (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale);
    float extent = bl * 3.0;
    if (sp[0] + extent < -50 || sp[0] - extent > width + 50 ||
        sp[1] + extent < -50 || sp[1] - extent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);
    rotate((float)(site.baseAngle + HALF_PI));

    drawLaunchComplex(bl, ship);

    popMatrix();
  }

  // ========== COORDINATE SYSTEM (after rotate) ==========
  // +X = tangential (along Earth surface, horizontal)
  // +Y = toward Earth center (down)
  // -Y = radial outward (up, ship nose direction)
  // Origin = launch site world position = Earth surface
  // Complex elevated above ground; ship sits on pad
  // groundY  = 0         — Earth surface
  // padSurfY = -bl*0.10  — pad surface (ship engine level after elevation)

  // ========== MAIN COMPLEX ==========

  void drawLaunchComplex(float bl, Spacecraft ship) {
    float bw = bl * 0.068;           // ship half-width (stage 1 radius)
    float groundY = 0;               // Earth surface
    float padSurfY = -bl * 0.10;     // pad surface, elevated above ground

    noStroke();

    drawTerrain(bl, groundY);
    drawAccessRoad(bl, groundY, padSurfY);
    drawFlameTrench(bl, padSurfY);
    drawConcretePad(bl, padSurfY, groundY);
    drawPadSurfaceDetails(bl, padSurfY);
    drawServiceTower(bl, bw, groundY);
    drawUmbilicalArms(bl, bw, groundY);
    drawHoldDownArms(bl, bw, padSurfY);
    drawLightningSystem(bl, groundY);
    drawSupportBuildings(bl, groundY, ship.col);
    drawExhaustDuct(bl, padSurfY);
  }

  // ========== TERRAIN ==========

  void drawTerrain(float bl, float groundY) {
    float groundW = bl * 2.2;

    // Main ground fill — extends from just above surface down into earth
    fill(42, 36, 27);
    beginShape();
    vertex(-groundW * 0.7, groundY + bl * 0.30);
    vertex(-groundW * 0.55, groundY - bl * 0.02);
    vertex(-groundW * 0.12, groundY - bl * 0.04);
    vertex( groundW * 0.12, groundY - bl * 0.04);
    vertex( groundW * 0.55, groundY - bl * 0.02);
    vertex( groundW * 0.7, groundY + bl * 0.30);
    endShape(CLOSE);

    // Ground strata / texture
    fill(50, 42, 32);
    for (int i = 0; i < 8; i++) {
      float gx = -bl * 1.5 + i * bl * 0.38;
      rect(gx, groundY + bl * 0.01 + i * bl * 0.01, bl * 0.8, bl * 0.013, 2);
    }

    // Grass/scrub
    fill(55, 48, 28);
    for (int i = 0; i < 10; i++) {
      float gx = -bl * 1.5 + i * bl * 0.32;
      float gy = groundY + bl * 0.05 + (i % 3) * bl * 0.02;
      ellipse(gx, gy, bl * 0.18, bl * 0.05);
    }

    // Dark earth around structures
    fill(35, 28, 20);
    rect(-bl * 1.05, groundY - bl * 0.03, bl * 2.1, bl * 0.03, 3);

    // Gravel berm
    fill(90, 82, 70);
    ellipse(0, groundY + bl * 0.12, bl * 0.7, bl * 0.06);
  }

  // ========== ACCESS ROAD ==========

  void drawAccessRoad(float bl, float groundY, float padSurfY) {
    float roadX = -bl * 1.3;
    float roadW = bl * 0.15;

    // Road surface from ground level
    fill(95, 90, 82);
    beginShape();
    vertex(roadX - roadW * 0.3, groundY + bl * 0.10);
    vertex(roadX + roadW * 0.1, groundY + bl * 0.02);
    vertex(roadX + roadW * 0.3, groundY - bl * 0.01);
    vertex(roadX - roadW * 0.4, groundY + bl * 0.07);
    endShape(CLOSE);

    // Road shoulder
    fill(80, 75, 68);
    beginShape();
    vertex(roadX - roadW * 0.35, groundY + bl * 0.09);
    vertex(roadX - roadW * 0.25, groundY + bl * 0.10);
    vertex(roadX + roadW * 0.3, groundY + bl * 0.01);
    vertex(roadX + roadW * 0.15, groundY - bl * 0.01);
    endShape(CLOSE);

    // Center dashes
    fill(130, 127, 118);
    for (int i = 0; i < 4; i++) {
      float rx = -bl * 1.2 + i * bl * 0.15;
      float ry = groundY + bl * 0.03 + i * bl * 0.018;
      rect(rx, ry, bl * 0.05, bl * 0.005, 1);
    }
  }

  // ========== CONCRETE LAUNCH PAD ==========

  void drawConcretePad(float bl, float padSurfY, float groundY) {
    float padHalfW = bl * 1.05;
    float padThick = bl * 0.09;       // pad sits on ground, extends up
    float padBot = padSurfY + padThick; // padSurfY is top, padBot = groundY

    // Main pad block
    fill(148, 142, 132);
    rect(-padHalfW, padSurfY, padHalfW * 2, padThick);

    // Bottom shadow
    fill(108, 102, 93);
    rect(-padHalfW, padBot - padThick * 0.22, padHalfW * 2, padThick * 0.22);

    // Top surface highlight
    fill(178, 173, 163);
    rect(-padHalfW * 0.93, padSurfY - padThick * 0.06, padHalfW * 1.86, padThick * 0.13);

    // Left bevel
    fill(122, 116, 106);
    rect(-padHalfW, padSurfY, padThick * 0.4, padThick);

    // Right bevel
    fill(118, 112, 102);
    rect(padHalfW - padThick * 0.4, padSurfY, padThick * 0.4, padThick);

    // Top surface grit texture
    fill(155, 148, 138, 60);
    for (int i = 0; i < 12; i++) {
      float dx = -padHalfW * 0.8 + (i * 1.7 + (i * i) * 0.3) % (padHalfW * 1.6);
      float dy = padSurfY + (i * 0.7 + 3) % (padThick * 0.5);
      ellipse(dx, dy, bl * 0.008, bl * 0.004);
    }

    // Support pillars underneath (going into ground)
    float pillarW = bl * 0.08;
    float pillarH = bl * 0.06;
    fill(112, 105, 95);
    for (int i = -3; i <= 3; i++) {
      if (i == 0) continue;
      float px = i * bl * 0.28;
      rect(px - pillarW * 0.5, padBot, pillarW, pillarH, 2);
    }
  }

  // ========== PAD SURFACE DETAILS ==========

  void drawPadSurfaceDetails(float bl, float padSurfY) {
    float padHalfW = bl * 1.05;

    // Expansion joint grid
    stroke(122, 116, 106, 100);
    strokeWeight(max(0.5, bl * 0.004));
    for (int i = -3; i <= 3; i++) {
      float lx = i * bl * 0.3;
      if (abs(lx) > padHalfW * 0.95) continue;
      line(lx, padSurfY - bl * 0.003, lx, padSurfY + bl * 0.03);
    }
    for (int i = 0; i < 3; i++) {
      float ly = padSurfY + bl * 0.012 + i * bl * 0.02;
      line(-padHalfW * 0.93, ly, padHalfW * 0.93, ly);
    }
    noStroke();

    // Center alignment marker
    fill(155, 50, 35, 160);
    rect(-bl * 0.03, padSurfY - bl * 0.02, bl * 0.06, bl * 0.05, 2);
    fill(200, 200, 190, 180);
    rect(-bl * 0.005, padSurfY - bl * 0.015, bl * 0.01, bl * 0.04, 1);
    rect(-bl * 0.025, padSurfY + bl * 0.002, bl * 0.05, bl * 0.008, 1);

    // Hold-down post markings
    fill(100, 93, 83, 100);
    for (int sx = -1; sx <= 1; sx += 2) {
      for (int sy = -1; sy <= 1; sy += 2) {
        rect(sx * bl * 0.06 - bl * 0.015, padSurfY - bl * 0.002,
             bl * 0.03, bl * 0.01, 1);
      }
    }
  }

  // ========== FLAME TRENCH ==========

  void drawFlameTrench(float bl, float padSurfY) {
    float trenchHalfW = bl * 0.24;
    float trenchDepth = bl * 0.19;
    float trenchBot = padSurfY + trenchDepth;

    // Main trench void (starts at pad surface, goes down into ground)
    fill(22, 18, 15);
    rect(-trenchHalfW, padSurfY, trenchHalfW * 2, trenchDepth);

    // Deeper interior
    fill(15, 12, 10);
    rect(-trenchHalfW * 0.6, padSurfY + trenchDepth * 0.08, trenchHalfW * 1.2, trenchDepth * 0.7);

    // Flame deflector wedge
    fill(42, 37, 32);
    beginShape();
    vertex(-trenchHalfW * 0.7, trenchBot);
    vertex( trenchHalfW * 0.3, padSurfY + trenchDepth * 0.2);
    vertex( trenchHalfW * 0.6, trenchBot);
    endShape(CLOSE);
    fill(55, 48, 42);
    beginShape();
    vertex(-trenchHalfW * 0.5, trenchBot);
    vertex( trenchHalfW * 0.1, padSurfY + trenchDepth * 0.3);
    vertex( trenchHalfW * 0.4, trenchBot);
    endShape(CLOSE);

    // Trench edge concrete coping
    fill(158, 152, 142);
    rect(-trenchHalfW - bl * 0.018, padSurfY - bl * 0.004, bl * 0.036, bl * 0.012, 2);
    rect( trenchHalfW - bl * 0.018, padSurfY - bl * 0.004, bl * 0.036, bl * 0.012, 2);

    // Scorch marks
    fill(50, 43, 36, 70);
    ellipse(-bl * 0.03, padSurfY, bl * 0.55, bl * 0.018);
    ellipse( bl * 0.05, padSurfY, bl * 0.40, bl * 0.014);
  }

  // ========== EXHAUST DUCT ==========

  void drawExhaustDuct(float bl, float padSurfY) {
    float ductTop = padSurfY + bl * 0.12;
    float ductBot = padSurfY + bl * 0.24;
    float ductHalfW = bl * 0.16;

    fill(28, 24, 20);
    rect(-ductHalfW, ductTop, ductHalfW * 2, ductBot - ductTop);

    fill(18, 15, 12);
    beginShape();
    vertex( ductHalfW * 0.6, ductTop + bl * 0.01);
    vertex( ductHalfW * 1.1, ductTop + bl * 0.04);
    vertex( ductHalfW * 1.1, ductBot - bl * 0.04);
    vertex( ductHalfW * 0.6, ductBot - bl * 0.01);
    endShape(CLOSE);

    fill(140, 134, 124);
    rect(ductHalfW - bl * 0.01, ductTop, bl * 0.018, ductBot - ductTop);
  }

  // ========== SERVICE / UMBILICAL TOWER ==========

  void drawServiceTower(float bl, float bw, float groundY) {
    float towerBaseY = groundY;                      // sits on ground
    float towerTopY = groundY - bl * 1.15;           // tall enough above fairing
    float towerCX = bl * 0.13;
    float towerHalfW = bl * 0.05;
    float towerLeft = towerCX - towerHalfW;
    float towerRight = towerCX + towerHalfW;

    // --- Main columns ---
    float colW = bl * 0.024;
    fill(92, 87, 79);
    rect(towerLeft, towerTopY, colW, towerBaseY - towerTopY);
    rect(towerRight - colW, towerTopY, colW, towerBaseY - towerTopY);

    // Column highlights
    fill(108, 103, 94);
    rect(towerLeft, towerTopY, colW * 0.35, towerBaseY - towerTopY);
    rect(towerRight - colW * 0.35, towerTopY, colW * 0.35, towerBaseY - towerTopY);

    // --- X-bracing lattice ---
    int bracePanels = 10;
    float panelH = (towerBaseY - towerTopY) / bracePanels;
    stroke(88, 83, 74);
    strokeWeight(max(0.5, bl * 0.006));
    for (int i = 0; i < bracePanels; i++) {
      float py = towerTopY + i * panelH;
      float npy = py + panelH;
      line(towerLeft + colW, py, towerRight - colW, npy);
      line(towerRight - colW, py, towerLeft + colW, npy);
      line(towerLeft + colW, py + panelH * 0.5, towerRight - colW, py + panelH * 0.5);
    }
    noStroke();

    // --- Elevator shaft ---
    float shaftX = towerCX - bl * 0.009;
    float shaftW = bl * 0.018;
    fill(72, 67, 60);
    rect(shaftX, towerTopY + bl * 0.02, shaftW, towerBaseY - towerTopY - bl * 0.02);

    // --- Platform decks ---
    int numDecks = 6;
    for (int i = 0; i < numDecks; i++) {
      float dY = towerTopY + bl * 0.06 + i * bl * 0.18;
      float dHalfW = bl * 0.14 - i * bl * 0.007;
      fill(108, 103, 94);
      rect(towerLeft - dHalfW * 0.35, dY, towerRight - towerLeft + dHalfW * 0.7, bl * 0.015, 2);
      fill(125, 120, 110);
      rect(towerLeft - dHalfW * 0.3, dY - bl * 0.002, towerRight - towerLeft + dHalfW * 0.6, bl * 0.005, 1);
      // Railing
      stroke(128, 123, 113);
      strokeWeight(max(0.3, bl * 0.003));
      float railY = dY - bl * 0.02;
      line(towerLeft - dHalfW * 0.3, railY, towerRight + dHalfW * 0.3, railY);
      for (int r = -2; r <= 2; r++) {
        float rx = towerCX + r * dHalfW * 0.25;
        line(rx, railY, rx, dY);
      }
      noStroke();
    }

    // --- Tower top ---
    fill(138, 133, 123);
    rect(towerCX - bl * 0.005, towerTopY - bl * 0.05, bl * 0.01, bl * 0.05);
    fill(185, 175, 55);
    ellipse(towerCX, towerTopY - bl * 0.05, bl * 0.018, bl * 0.018);
    // Antenna
    fill(100, 95, 85);
    rect(towerCX - bl * 0.025, towerTopY - bl * 0.03, bl * 0.05, bl * 0.006, 1);
    rect(towerCX + bl * 0.015, towerTopY - bl * 0.035, bl * 0.008, bl * 0.02, 1);

    // --- Tower base footings ---
    fill(98, 91, 81);
    float footingW = bl * 0.045;
    float footingH = bl * 0.03;
    rect(towerLeft - bl * 0.006, towerBaseY, footingW, footingH, 2);
    rect(towerRight - footingW + bl * 0.006, towerBaseY, footingW, footingH, 2);
  }

  // ========== UMBILICAL / SWING ARMS ==========

  void drawUmbilicalArms(float bl, float bw, float groundY) {
    float towerCX = bl * 0.13;
    float towerLeft = towerCX - bl * 0.05;
    float towerTopY = groundY - bl * 1.15;
    float shipCL = 0;

    int numArms = 4;
    float[] armHeights = {
      towerTopY + bl * 0.22,   // fairing level
      towerTopY + bl * 0.42,   // stage 2
      towerTopY + bl * 0.62,   // interstage
      towerTopY + bl * 0.80    // stage 1 upper
    };

    for (int i = 0; i < numArms; i++) {
      float armY = armHeights[i];
      float armBaseX = towerLeft + bl * 0.005;
      float armLen = abs(shipCL - armBaseX);
      float armThick = bl * 0.015 - i * bl * 0.002;

      fill(82, 76, 68);
      rect(armBaseX, armY, -armLen, armThick, 2);
      fill(98, 92, 82);
      rect(armBaseX - armLen * 0.08, armY - armThick * 0.15, -armLen * 0.84, armThick * 0.35, 1);

      // Hinge block
      fill(66, 60, 54);
      float hingeW = bl * 0.02;
      rect(armBaseX - hingeW * 0.5, armY - armThick * 0.2, hingeW, armThick * 1.4, 2);

      // Umbilical connector
      float tipX = armBaseX - armLen;
      fill(72, 65, 57);
      rect(tipX - bl * 0.007, armY - armThick * 0.35, bl * 0.01, armThick * 1.7, 2);

      // Service pipe
      stroke(108, 98, 78, 170);
      strokeWeight(max(0.4, bl * 0.005));
      line(armBaseX - bl * 0.01, armY + armThick * 0.35, tipX + bl * 0.007, armY + armThick * 0.35);
      noStroke();
    }

    // Tail service mast (fueling at stage 1 base, near ground)
    float tsmX = bl * 0.06;
    float tsmBaseY = groundY;
    float tsmTopY = groundY - bl * 0.22;
    fill(88, 81, 72);
    rect(tsmX - bl * 0.01, tsmTopY, bl * 0.022, tsmBaseY - tsmTopY);

    // Flexible cryo hose
    stroke(100, 90, 70, 170);
    strokeWeight(max(0.5, bl * 0.007));
    noFill();
    float hoseStartX = tsmX + bl * 0.006;
    float hoseStartY = tsmTopY + bl * 0.01;
    float hoseEndY = groundY - bl * 0.06;
    bezier(hoseStartX, hoseStartY,
           tsmX - bl * 0.04, hoseStartY - bl * 0.05,
           -bw * 0.5, hoseEndY,
           -bw * 0.3, hoseEndY);
    noStroke();
  }

  // ========== HOLD-DOWN ARMS (on pad surface) ==========

  void drawHoldDownArms(float bl, float bw, float padSurfY) {
    int armCount = 4;
    for (int i = 0; i < armCount; i++) {
      float side = (i < 2) ? -1 : 1;
      float hx = side * bw * 1.5 * (1 + (i % 2) * 0.25);

      // Base block on pad
      fill(98, 91, 81);
      rect(hx - bl * 0.018, padSurfY - bl * 0.01, bl * 0.036, bl * 0.03, 2);

      // Vertical arm
      fill(82, 76, 66);
      rect(hx - bl * 0.009, padSurfY - bl * 0.04, bl * 0.018, bl * 0.05, 1);

      // Clamp
      fill(112, 102, 90);
      rect(hx - bl * 0.013, padSurfY - bl * 0.045, bl * 0.026, bl * 0.012, 1);
      fill(140, 128, 110);
      ellipse(hx, padSurfY - bl * 0.04, bl * 0.01, bl * 0.008);
    }
  }

  // ========== LIGHTNING PROTECTION SYSTEM ==========

  void drawLightningSystem(float bl, float groundY) {
    float padHalfW = bl * 1.05;
    float mastBaseY = groundY;           // masts rooted in ground
    float mastTopY = groundY - bl * 1.30;  // taller than ship nose at -bl*1.11

    float[][] mastXPos = {
      { -padHalfW * 0.82 },
      {  padHalfW * 0.82 }
    };

    for (float[] mxArr : mastXPos) {
      float mx = mxArr[0];
      float baseW = bl * 0.020;
      float topW = bl * 0.008;

      fill(118, 113, 103);
      beginShape();
      vertex(mx - baseW * 0.5, mastBaseY);
      vertex(mx + baseW * 0.5, mastBaseY);
      vertex(mx + topW * 0.5, mastTopY);
      vertex(mx - topW * 0.5, mastTopY);
      endShape(CLOSE);

      fill(135, 130, 120);
      beginShape();
      vertex(mx - baseW * 0.15, mastBaseY);
      vertex(mx + baseW * 0.15, mastBaseY);
      vertex(mx + topW * 0.15, mastTopY);
      vertex(mx - topW * 0.15, mastTopY);
      endShape(CLOSE);

      fill(98, 91, 81);
      rect(mx - bl * 0.025, mastBaseY - bl * 0.003, bl * 0.05, bl * 0.028, 2);

      // Insulator rings
      fill(180, 170, 100);
      for (int r = 0; r < 4; r++) {
        float ry = lerp(mastBaseY, mastTopY, 0.1 + r * 0.25);
        float rw = baseW * (1.2 - r * 0.2);
        ellipse(mx, ry, rw * 2.8, rw * 1.2);
      }

      fill(185, 175, 55);
      ellipse(mx, mastTopY, bl * 0.016, bl * 0.016);
    }

    // Catenary wire
    stroke(78, 73, 63);
    strokeWeight(max(0.3, bl * 0.004));
    float m1X = mastXPos[0][0];
    float m2X = mastXPos[1][0];
    float sag = bl * 0.08;
    noFill();
    bezier(m1X + bl * 0.006, mastTopY,
           m1X + bl * 0.4, mastTopY + sag,
           m2X - bl * 0.4, mastTopY + sag,
           m2X - bl * 0.006, mastTopY);
    noStroke();

    // Ground cables
    stroke(68, 63, 53);
    strokeWeight(max(0.3, bl * 0.003));
    for (float[] mxArr : mastXPos) {
      float mx = mxArr[0];
      float gEndY = groundY + bl * 0.14;
      line(mx + bl * 0.012, mastBaseY, mx + bl * 0.07, gEndY);
      fill(100, 93, 83);
      ellipse(mx + bl * 0.07, gEndY, bl * 0.018, bl * 0.012);
    }
    noStroke();
  }

  // ========== SUPPORT BUILDINGS ==========

  void drawSupportBuildings(float bl, float groundY, color shipCol) {
    float padHalfW = bl * 1.05;

    // --- Blockhouse (left) ---
    float bhCX = -padHalfW - bl * 0.22;
    float bhW = bl * 0.26;
    float bhH = bl * 0.14;
    float bhBaseY = groundY;

    fill(128, 123, 113);
    rect(bhCX - bhW * 0.5, bhBaseY - bhH, bhW, bhH, 3);
    fill(118, 113, 103);
    beginShape();
    vertex(bhCX - bhW * 0.55, bhBaseY - bhH);
    vertex(bhCX + bhW * 0.55, bhBaseY - bhH);
    vertex(bhCX + bhW * 0.45, bhBaseY - bhH - bl * 0.018);
    vertex(bhCX - bhW * 0.45, bhBaseY - bhH - bl * 0.018);
    endShape(CLOSE);
    fill(22, 18, 15);
    rect(bhCX - bl * 0.025, bhBaseY - bhH + bl * 0.03, bl * 0.05, bl * 0.012, 1);
    fill(58, 52, 45);
    rect(bhCX - bl * 0.018, bhBaseY - bl * 0.03, bl * 0.036, bl * 0.05, 1);

    // --- Equipment building (right) ---
    float ebCX = padHalfW + bl * 0.12;
    float ebW = bl * 0.20;
    float ebH = bl * 0.10;
    float ebBaseY = groundY;

    fill(138, 133, 123);
    rect(ebCX - ebW * 0.5, ebBaseY - ebH, ebW, ebH, 2);
    fill(128, 123, 113);
    rect(ebCX - ebW * 0.53, ebBaseY - ebH - bl * 0.007, ebW * 1.06, bl * 0.015, 1);
    fill(98, 91, 81);
    rect(ebCX + bl * 0.03, ebBaseY - ebH - bl * 0.026, bl * 0.014, bl * 0.022);
    fill(62, 56, 48);
    rect(ebCX - bl * 0.012, ebBaseY - bl * 0.022, bl * 0.026, bl * 0.036, 1);
    fill(60, 80, 110, 150);
    rect(ebCX - bl * 0.04, ebBaseY - ebH + bl * 0.025, bl * 0.025, bl * 0.022, 1);

    // --- Fuel storage tank (right) ---
    float tkCX = padHalfW + bl * 0.42;
    float tkR = bl * 0.055;
    float tkCY = groundY - bl * 0.10;
    fill(148, 143, 133);
    ellipse(tkCX, tkCY, tkR * 2, tkR * 2);
    fill(168, 163, 153, 120);
    ellipse(tkCX - tkR * 0.2, tkCY - tkR * 0.2, tkR * 0.8, tkR * 0.7);
    fill(100, 93, 83);
    rect(tkCX - tkR * 0.85, tkCY + tkR * 0.4, tkR * 0.25, groundY - tkCY - tkR * 0.4);
    rect(tkCX + tkR * 0.6, tkCY + tkR * 0.4, tkR * 0.25, groundY - tkCY - tkR * 0.4);
    fill(88, 81, 72);
    rect(tkCX - bl * 0.004, tkCY + tkR + bl * 0.01, bl * 0.008, groundY - tkCY - tkR);
    fill(red(shipCol) * 0.6, green(shipCol) * 0.6, blue(shipCol) * 0.6, 130);
    ellipse(tkCX, tkCY, tkR * 1.6, tkR * 0.4);

    // --- Water tower (left) ---
    float wtCX = -padHalfW - bl * 0.50;
    float wtTankW = bl * 0.08;
    float wtTankH = bl * 0.06;
    float wtLegH = bl * 0.32;
    float wtTankCY = groundY - wtLegH - wtTankH * 0.5;

    fill(103, 96, 86);
    float legSpread = bl * 0.05;
    rect(wtCX - legSpread, groundY - wtLegH, bl * 0.015, wtLegH);
    rect(wtCX + legSpread, groundY - wtLegH, bl * 0.015, wtLegH);
    stroke(98, 91, 81);
    strokeWeight(max(0.3, bl * 0.003));
    line(wtCX - legSpread + bl * 0.007, groundY - wtLegH * 0.35,
         wtCX + legSpread - bl * 0.007, groundY - wtLegH * 0.65);
    line(wtCX - legSpread + bl * 0.007, groundY - wtLegH * 0.65,
         wtCX + legSpread - bl * 0.007, groundY - wtLegH * 0.35);
    noStroke();

    fill(155, 150, 142);
    rect(wtCX - wtTankW * 0.5, wtTankCY - wtTankH * 0.5, wtTankW, wtTankH, 2);
    fill(145, 140, 132);
    arc(wtCX, wtTankCY - wtTankH * 0.5, wtTankW, wtTankH * 0.5, 0, PI, PIE);
    fill(100, 140, 180, 100);
    rect(wtCX - wtTankW * 0.4, wtTankCY - wtTankH * 0.1, wtTankW * 0.8, wtTankH * 0.5, 1);
    fill(88, 81, 72);
    rect(wtCX - bl * 0.005, wtTankCY + wtTankH * 0.5, bl * 0.01, groundY - wtTankCY - wtTankH * 0.5);
    fill(120, 110, 90);
    rect(wtCX - bl * 0.008, groundY - bl * 0.06, bl * 0.016, bl * 0.02, 1);
  }
}
