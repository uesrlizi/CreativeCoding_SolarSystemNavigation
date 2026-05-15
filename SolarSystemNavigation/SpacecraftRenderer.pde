class SpacecraftRenderer {

  void draw(Spacecraft ship, CameraController cam) {
    double[] sp = cam.worldToScreen(ship.px, ship.py);

    if (Double.isNaN(sp[0]) || Double.isNaN(sp[1]) || Double.isNaN(cam.scale)) return;

    boolean isShipView = (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget == ship);
    float drawExtent = isShipView ? (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale * 0.55) : 20;
    if (sp[0] + drawExtent < -50 || sp[0] - drawExtent > width + 50 ||
        sp[1] + drawExtent < -50 || sp[1] - drawExtent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);

    float angle = calculateOrientation(ship, cam);
    if (Float.isNaN(angle) || Float.isInfinite(angle)) {
      dbgLog("RENDERER NaN angle, state=" + ship.state + " — using 0");
      angle = 0;
    }
    rotate(angle);

    if (isShipView) {
      float bodyLen = (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale);
      drawShipViewModel(ship, bodyLen);
    } else {
      drawSpacecraftGraphic(ship);
    }

    popMatrix();

    if (showLabels) {
      fill(red(ship.col), green(ship.col), blue(ship.col), 220);
      textSize(15 * uiScale);
      textAlign(LEFT, CENTER);
      float labelOffset = isShipView ? (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale * 0.55) + 8 : 15;
      text("Spacecraft", (float)sp[0] + labelOffset, (float)sp[1]);
    }
  }

  void drawSpacecraftGraphic(Spacecraft ship) {
    float bodyLen = 10.0;
    float bodyWid = 5.0;

    noStroke();

    for (int g = 3; g >= 1; g--) {
      fill(red(ship.col), green(ship.col), blue(ship.col), 30 / g);
      ellipse(0, 0, 18 + g * 4, 18 + g * 4);
    }

    fill(red(ship.col) * 0.7, green(ship.col) * 0.7, blue(ship.col) * 0.7);
    beginShape();
    vertex(bodyLen * 0.6, 0);
    vertex(-bodyLen * 0.2, -bodyWid * 0.5);
    vertex(-bodyLen * 0.5, -bodyWid * 0.3);
    vertex(-bodyLen * 0.5, bodyWid * 0.3);
    vertex(-bodyLen * 0.2, bodyWid * 0.5);
    endShape(CLOSE);

    fill(ship.col);
    beginShape();
    vertex(bodyLen * 0.5, 0);
    vertex(-bodyLen * 0.3, -bodyWid * 0.4);
    vertex(-bodyLen * 0.5, -bodyWid * 0.25);
    vertex(-bodyLen * 0.5, bodyWid * 0.25);
    vertex(-bodyLen * 0.3, bodyWid * 0.4);
    endShape(CLOSE);

    pushMatrix();
    rotate(radians(35));
    fill(red(ship.col) * 0.8, green(ship.col) * 0.8, blue(ship.col) * 0.8);
    beginShape();
    vertex(0, 0);
    vertex(-bodyLen * 0.3, -2);
    vertex(-bodyLen * 0.8, -1.5);
    vertex(-bodyLen * 0.9, 0);
    endShape(CLOSE);
    popMatrix();

    pushMatrix();
    rotate(radians(-35));
    fill(red(ship.col) * 0.8, green(ship.col) * 0.8, blue(ship.col) * 0.8);
    beginShape();
    vertex(0, 0);
    vertex(-bodyLen * 0.3, 2);
    vertex(-bodyLen * 0.8, 1.5);
    vertex(-bodyLen * 0.9, 0);
    endShape(CLOSE);
    popMatrix();

    if (ship.thrustActive) {
      fill(255, 140, 30, 150);
      triangle(-bodyLen * 0.5, -2, -bodyLen * 0.5, 2, -bodyLen * 0.5 - 10, 0);

      fill(255, 200, 50, 200);
      triangle(-bodyLen * 0.5, -1.5, -bodyLen * 0.5, 1.5, -bodyLen * 0.5 - 7, 0);

      fill(255, 255, 200, 230);
      triangle(-bodyLen * 0.5, -0.8, -bodyLen * 0.5, 0.8, -bodyLen * 0.5 - 4, 0);
    }
  }

  float calculateOrientation(Spacecraft ship, CameraController cam) {
    if (ship.earthRelative) {
      if (ship.state == ShipState.IDLE ||
          ship.state == ShipState.COUNTDOWN ||
          ship.state == ShipState.IGNITION) {
        return (float)(ship.earthOrbitAngle);
      } else if (ship.state == ShipState.LAUNCHING && ship.thrustActive) {
        double rx = ship.earthRelPos[0], ry = ship.earthRelPos[1];
        double burnTime = timeManager.simTime - ship.launchStartTime;
        return (float)ship.getAscentThrustAngle(rx, ry, burnTime);
      } else if (ship.state == ShipState.CIRCULARIZING) {
        double rx = ship.earthRelPos[0], ry = ship.earthRelPos[1];
        double vx = ship.earthRelVel[0], vy = ship.earthRelVel[1];
        double[] peg = ship.getPEGGuidance(rx, ry, vx, vy);
        return (float)peg[1];
      } else {
        return (float)(ship.earthOrbitAngle + PI / 2.0);
      }
    }

    double nuForward = ship.currentNu + 0.01;
    double[] posForward = orbitalToCartesian(ship.a, ship.e, ship.i, ship.omega, ship.w, nuForward);

    double vx = posForward[0] - ship.px;
    double vy = posForward[1] - ship.py;

    return (float)Math.atan2(vy, vx);
  }

  void drawShipViewModel(Spacecraft ship, float bodyLen) {
    float bodyWid = bodyLen * 0.28;
    float nozzleLen = bodyLen * 0.12;

    noStroke();

    // Glow halo
    float glowR = bodyLen * 0.8;
    for (int g = 3; g >= 1; g--) {
      float r = glowR + g * bodyLen * 0.12;
      fill(red(ship.col), green(ship.col), blue(ship.col), 20 / g);
      ellipse(0, 0, r, r);
    }

    if (ship.thrustActive) {
      drawShipViewExhaust(ship, bodyLen, nozzleLen);
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
    stroke(140, 140, 145);
    strokeWeight(max(0.5, bodyLen * 0.024));
    line(nx2, -ny2, nx2, ny2);
    noStroke();

    drawShipViewFin(ship, bodyLen, bodyWid, 1);
    drawShipViewFin(ship, bodyLen, bodyWid, -1);

    // Main body - tapered
    fill(red(ship.col) * 0.85, green(ship.col) * 0.85, blue(ship.col) * 0.85);
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
    fill(red(ship.col), green(ship.col), blue(ship.col), 80);
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
    fill(red(ship.col) * 0.6, green(ship.col) * 0.6, blue(ship.col) * 0.6);
    rect(-bodyLen * 0.05, -bodyWid * 0.48, bodyWid * 0.4, bodyWid * 0.96, max(1.0, bodyLen * 0.06));

    // Launch base
    drawLaunchBase(ship, bodyLen, bodyWid);
  }

  void drawLaunchBase(Spacecraft ship, float bodyLen, float bodyWid) {
    if (ship.state == ShipState.IDLE ||
        ship.state == ShipState.COUNTDOWN ||
        ship.state == ShipState.IGNITION ||
        (ship.state == ShipState.LAUNCHING && ship.launchAltitude < 2.0)) {

      float alpha = 255;
      if (ship.state == ShipState.LAUNCHING) {
        alpha = map((float)ship.launchAltitude, 0, 2.0, 255, 30);
        if (alpha < 0) alpha = 0;
      }

      float padTopX = -bodyLen * 0.46;     // just below engine nozzle base
      float padW = bodyLen * 1.6;           // wider than ship
      float padH = bodyLen * 0.06;          // thin platform slab
      float towerBaseX = padTopX;
      float towerTopX = -bodyLen * 0.45;    // tower reaches up near mid-body
      float towerY = bodyWid * 0.65;        // horizontal offset to right side
      float towerThick = bodyLen * 0.05;

      // --- Launch pad platform ---
      fill(110, 105, 100, alpha);
      noStroke();
      rect(-padW / 2, padTopX, padW, padH);

      // Pad surface highlight stripe
      fill(135, 130, 125, alpha);
      rect(-padW * 0.4, padTopX - padH * 0.35, padW * 0.8, padH * 0.35);

      // --- Tower / gantry structure ---
      fill(85, 82, 78, alpha);
      rect(towerY, towerTopX, towerThick, towerBaseX - towerTopX);

      // Cross-braces along tower
      fill(72, 68, 64, alpha);
      int numBraces = 4;
      for (int i = 0; i < numBraces; i++) {
        float bx = towerTopX + (towerBaseX - towerTopX) * (i + 0.5f) / numBraces;
        float braceW = bodyLen * 0.22;
        rect(towerY - braceW / 2 + towerThick / 2, bx, braceW, bodyLen * 0.016);
      }

      // --- Umbilical / service arm ---
      float armX = towerTopX + bodyLen * 0.10;
      fill(78, 74, 70, alpha);
      rect(bodyWid * 0.18, armX, towerY - bodyWid * 0.18, bodyLen * 0.026);

      // --- Ground strip ---
      fill(55, 42, 32, alpha * 0.7);
      rect(-padW * 0.9, padTopX + padH, padW * 1.8, bodyLen * 0.025);
    }
  }

  void drawShipViewFin(Spacecraft ship, float bodyLen, float bodyWid, float side) {
    float bx = bodyLen * 0.15;
    float by = bodyWid * 0.5 * side;
    float finLen = bodyLen * 0.32;
    float finWid = bodyLen * 0.24;

    fill(red(ship.col) * 0.75, green(ship.col) * 0.75, blue(ship.col) * 0.75);
    beginShape();
    vertex(bx, by);
    vertex(bx - bodyLen * 0.12, by + finWid * side);
    vertex(bx - bodyLen * 0.2, by + finWid * 1.2 * side);
    vertex(bx - finLen, by + finWid * 0.9 * side);
    vertex(bx - finLen * 0.8, by + finWid * 0.5 * side);
    endShape(CLOSE);
  }

  void drawShipViewExhaust(Spacecraft ship, float bodyLen, float nozzleLen) {
    float baseX = -bodyLen * 0.46 - nozzleLen;
    float oscScale = bodyLen * 0.1;
    float flameOsc = (float)Math.sin(millis() / 1000.0 * 24.0) * oscScale;

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
