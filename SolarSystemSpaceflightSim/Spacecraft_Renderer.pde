// ========== SPACECRAFT RENDERER ==========

class SpacecraftRenderer {

  void draw(Spacecraft ship, CameraController cam) {
    double[] sp = cam.worldToScreen(ship.px, ship.py);

    if (Double.isNaN(sp[0]) || Double.isNaN(sp[1]) || Double.isInfinite(cam.scale)) return;

    boolean isShipView = (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget == ship);
    float drawExtent = isShipView ? (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale * 0.7) : 24;
    if (sp[0] + drawExtent < -50 || sp[0] - drawExtent > width + 50 ||
        sp[1] + drawExtent < -50 || sp[1] - drawExtent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);

    float worldAngle = (float)ship.displayAngle;
    if (isShipView && ship.earthRelative) {
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
}
