class HUD {
  LaunchUI launchUI;

  CelestialBody selectedBody;
  long lastPanelClickTime;
  CelestialBody lastPanelClickBody;
  static final int PANEL_DOUBLE_CLICK_MS = 300;

  HUD() {
    launchUI = new LaunchUI();
    selectedBody = null;
    lastPanelClickTime = 0;
    lastPanelClickBody = null;
  }

  void draw(CameraController cam, double simTime, double timeWarp,
            double[] WARP_LEVELS, String[] WARP_LABELS,
            int warpIndex, List<CelestialBody> planets, CelestialBody sun) {
    drawInfoPanel(cam, simTime, timeWarp, WARP_LABELS, warpIndex);
    drawCelestialPanel(cam, planets, sun);
    drawViewModeIndicator();
    launchUI.draw();

    if (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget != null) {
      drawShipViewOverlay(cam.followTarget);
    }

    if (timeWarp == 0) {
      drawPauseIndicator();
    }
  }

  void drawInfoPanel(CameraController cam, double simTime, double timeWarp,
                     String[] WARP_LABELS, int warpIndex) {
    noStroke();
    fill(0, 0, 0, 160);
    rect(10, 10, 420, 185, 8);

    fill(220);
    textSize(21);
    textAlign(LEFT, TOP);
    text("Spacecraft Launch Simulator", 20, 18);

    textSize(16);
    fill(180);
    double simDays = simTime / DAY_S;
    double simYears = simDays / 365.25;
    text(String.format("Time: %.1f days (%.2f years)", simDays, simYears), 20, 46);

    String warpStr = formatWarp(timeWarp, WARP_LABELS, warpIndex);
    fill(100, 200, 100);
    textSize(15);
    text("Time Warp: " + warpStr, 20, 72);

    double auPerPixel = 1.0 / (AU_KM * cam.scale);
    fill(180);
    text(String.format("Zoom: %.4f AU/px", auPerPixel), 20, 94);

    fill(140);
    textSize(12);
    text("[Space] Pause  [Q/E] Warp  [V] View  [F] Snap Focus", 20, 120);
    text("[O] Orbits  [L] Labels  [T] Trails", 20, 142);
    text("Drag to Pan  Scroll to Zoom  Double-click to focus", 20, 164);
  }

  void drawViewModeIndicator() {
    noStroke();
    fill(0, 0, 0, 160);
    rect(width - 130, 10, 120, 35, 8);

    fill(200);
    textSize(14);
    textAlign(LEFT, CENTER);
    String modeText = (camera.getMode() == ViewMode.MAP_VIEW) ? "MAP VIEW" : "SHIP VIEW";
    text(modeText + " [V]", width - 120, 28);
  }

  void drawCelestialPanel(CameraController cam, List<CelestialBody> planets, CelestialBody sun) {
    int px = 10;
    int py = 230;
    int pw = 230;
    int rowH = 22;
    int headerH = 38;
    int bodyCount = 1 + planets.size();
    int rowsH = bodyCount * rowH;
    int sepY = py + headerH + rowsH + 4;
    int footerH = 30;
    int ph = headerH + rowsH + 8 + footerH;

    CelestialBody focusBody = cam.focusBody;
    Spacecraft focusShip = cam.focusShip;

    noStroke();
    fill(0, 0, 0, 150);
    rect(px, py, pw, ph, 8);

    // Header
    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Bodies", px + 10, py + 10);

    // Body rows
    int rowY = py + headerH;
    drawBodyRow(px, rowY, pw, rowH, sun, focusBody, selectedBody);
    rowY += rowH;
    for (int i = 0; i < planets.size(); i++) {
      CelestialBody p = planets.get(i);
      drawBodyRow(px, rowY, pw, rowH, p, focusBody, selectedBody);
      rowY += rowH;
    }

    // Separator
    stroke(100, 100, 120, 100);
    strokeWeight(1);
    line(px + 10, sepY, px + pw - 10, sepY);
    noStroke();

    // Footer: focus info + Snap button
    int footerY = sepY + 6;

    if (focusBody != null && focusBody.a != 0) {
      fill(focusBody.col);
      textSize(12);
      textAlign(LEFT, CENTER);
      text("Focusing: " + focusBody.name, px + 12, footerY + 12);
    } else if (focusShip != null) {
      fill(255, 200, 50);
      textSize(12);
      textAlign(LEFT, CENTER);
      text("Focusing: " + focusShip.name, px + 12, footerY + 12);
    }

    // Snap button (always visible)
    int btnX = px + pw - 64;
    int btnY = footerY + 2;
    int btnW = 50;
    int btnH = 20;
    boolean hover = mouseX >= btnX && mouseX <= btnX + btnW &&
                    mouseY >= btnY && mouseY <= btnY + btnH;
    fill(hover ? color(80, 160, 220) : color(50, 120, 180));
    rect(btnX, btnY, btnW, btnH, 4);
    fill(255);
    textSize(11);
    textAlign(CENTER, CENTER);
    text("Snap", btnX + btnW / 2, btnY + btnH / 2);
  }

  void drawBodyRow(int px, int y, int pw, int rowH, CelestialBody body,
                   CelestialBody focusBody, CelestialBody selected) {
    boolean isFocused = (focusBody == body);
    boolean isSelected = (selected == body);
    boolean hover = mouseX >= px && mouseX <= px + pw &&
                    mouseY >= y && mouseY <= y + rowH;

    // Row highlight
    if (isFocused) {
      fill(255, 220, 100, 40);
      noStroke();
      rect(px + 4, y + 1, pw - 8, rowH - 2, 3);
    } else if (isSelected) {
      fill(255, 255, 255, 25);
      noStroke();
      rect(px + 4, y + 1, pw - 8, rowH - 2, 3);
    } else if (hover) {
      fill(255, 255, 255, 12);
      noStroke();
      rect(px + 4, y + 1, pw - 8, rowH - 2, 3);
    }

    // Color dot
    fill(body.col);
    noStroke();
    ellipse(px + 16, y + rowH / 2, 7, 7);

    // Name
    if (isFocused) {
      fill(255, 220, 100);
    } else if (isSelected) {
      fill(240);
    } else {
      fill(200);
    }
    textSize(13);
    textAlign(LEFT, CENTER);
    text(body.name, px + 30, y + rowH / 2);

    // Focus button on right side when selected and not already focused
    if (isSelected && !isFocused) {
      int btnX = px + pw - 54;
      int btnW = 44;
      int btnH = 16;
      int btnCY = y + rowH / 2;
      boolean btnHover = mouseX >= btnX && mouseX <= btnX + btnW &&
                         mouseY >= btnCY - btnH / 2 && mouseY <= btnCY + btnH / 2;
      fill(btnHover ? color(80, 160, 220) : color(50, 120, 180));
      noStroke();
      rect(btnX, btnCY - btnH / 2, btnW, btnH, 3);
      fill(255);
      textSize(10);
      textAlign(CENTER, CENTER);
      text("Focus", btnX + btnW / 2, btnCY);
    } else if (isFocused) {
      // Focused indicator
      fill(255, 220, 100, 150);
      noStroke();
      int cx = px + pw - 14;
      int cy = y + rowH / 2;
      ellipse(cx, cy, 8, 8);
    }
  }

  boolean handleClick(float mx, float my, CelestialBody sun,
                      List<CelestialBody> planets, CameraController cam) {
    int px = 10;
    int py = 230;
    int pw = 230;
    int rowH = 22;
    int headerH = 38;
    int bodyCount = 1 + planets.size();
    int rowsH = bodyCount * rowH;
    int sepY = py + headerH + rowsH + 4;
    int footerH = 30;
    int ph = headerH + rowsH + 8 + footerH;

    if (mx < px || mx > px + pw || my < py || my > py + ph) return false;

    // Check focus button on the currently selected row (must check before row click)
    if (selectedBody != null && selectedBody != cam.focusBody) {
      int selIdx = -1;
      if (selectedBody == sun) selIdx = 0;
      else selIdx = planets.indexOf(selectedBody) + 1;
      if (selIdx >= 0) {
        int btnRowY = py + headerH + selIdx * rowH;
        int btnX = px + pw - 54;
        int btnW = 44;
        int btnH = 16;
        int btnCY = btnRowY + rowH / 2;
        if (mx >= btnX && mx <= btnX + btnW &&
            my >= btnCY - btnH / 2 && my <= btnCY + btnH / 2) {
          CelestialBody toFocus = selectedBody;
          selectedBody = null;
          cam.focusOn(toFocus);
          return true;
        }
      }
    }

    // Check body rows
    int rowY = py + headerH;
    CelestialBody clickedBody = null;
    if (my >= rowY && my < rowY + rowH && mx >= px && mx <= px + pw) {
      clickedBody = sun;
    }
    rowY += rowH;
    for (int i = 0; i < planets.size(); i++) {
      if (my >= rowY && my < rowY + rowH && mx >= px && mx <= px + pw) {
        clickedBody = planets.get(i);
        break;
      }
      rowY += rowH;
    }

    if (clickedBody != null) {
      long now = millis();
      if (clickedBody == lastPanelClickBody &&
          now - lastPanelClickTime < PANEL_DOUBLE_CLICK_MS) {
        // Double-click — focus immediately
        selectedBody = null;
        lastPanelClickTime = 0;
        lastPanelClickBody = null;
        cam.focusOn(clickedBody);
        return true;
      }
      // Single click — select
      selectedBody = clickedBody;
      lastPanelClickTime = now;
      lastPanelClickBody = clickedBody;
      return true;
    }

    // Check Snap button
    int footerY = sepY + 6;
    int btnX = px + pw - 64;
    int btnY = footerY + 2;
    int btnW = 50;
    int btnH = 20;
    if (mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH) {
      selectedBody = null;
      doSnap(cam);
      return true;
    }

    // Click on panel but not on interactive element — deselect
    selectedBody = null;
    return false;
  }

  void doSnap(CameraController cam) {
    if (cam.focusShip != null) {
      if (Math.abs(cam.targetOffsetX) > 0.01 || Math.abs(cam.targetOffsetY) > 0.01) {
        cam.targetOffsetX = 0;
        cam.targetOffsetY = 0;
      }
    } else if (cam.focusBody != null && cam.focusBody.a != 0) {
      if (Math.abs(cam.targetOffsetX) > 0.01 || Math.abs(cam.targetOffsetY) > 0.01) {
        cam.targetOffsetX = 0;
        cam.targetOffsetY = 0;
      } else {
        cam.targetScale = height / (4.0 * cam.focusBody.radius);
      }
    } else {
      if (Math.abs(cam.targetOffsetX) > 0.01 || Math.abs(cam.targetOffsetY) > 0.01) {
        cam.targetOffsetX = 0;
        cam.targetOffsetY = 0;
      } else {
        cam.targetScale = (width * 0.15) / AU_KM;
      }
    }
  }

  void drawPauseIndicator() {
    fill(255, 80, 80);
    textSize(30);
    textAlign(CENTER, CENTER);
    text("PAUSED", width / 2, height - 60);
  }

  void drawShipViewOverlay(Spacecraft ship) {
    int rightX = width - 220;
    drawSpeedIndicator(ship, rightX, 60);
    drawEngineIndicator(ship, rightX, 107);

    if (ship.earthRelative) {
      drawOrbitData(ship, rightX, 150);
    } else {
      drawHeliocentricData(ship, rightX, 150);
    }

    // Ship name at bottom center
    fill(0, 0, 0, 100);
    noStroke();
    rect(width / 2 - 80, height - 40, 160, 30, 5);
    fill(red(ship.col), green(ship.col), blue(ship.col), 220);
    textSize(14);
    textAlign(CENTER, CENTER);
    text(ship.name, width / 2, height - 25);
  }

  void drawSpeedIndicator(Spacecraft ship, int x, int y) {
    double speed;
    if (ship.earthRelative) {
      speed = Math.sqrt(ship.earthRelVel[0] * ship.earthRelVel[0]
                      + ship.earthRelVel[1] * ship.earthRelVel[1]);
    } else {
      double nuFwd = ship.currentNu + 0.01;
      double[] posFwd = orbitalToCartesian(ship.a, ship.e, ship.i, ship.omega, ship.w, nuFwd);
      speed = Math.sqrt((posFwd[0] - ship.px) * (posFwd[0] - ship.px)
                      + (posFwd[1] - ship.py) * (posFwd[1] - ship.py)) / 0.01;
    }

    fill(0, 0, 0, 110);
    noStroke();
    rect(x, y, 155, 42, 5);

    fill(200);
    textSize(11);
    textAlign(LEFT, TOP);
    text("SPEED", x + 8, y + 4);
    fill(100, 220, 100);
    textSize(15);
    text(String.format("%.2f km/s", speed), x + 8, y + 20);
  }

  void drawEngineIndicator(Spacecraft ship, int x, int y) {
    fill(0, 0, 0, 110);
    noStroke();
    rect(x, y, 155, 35, 5);

    if (ship.thrustActive) {
      fill(255, 160, 40);
      textSize(13);
      textAlign(LEFT, CENTER);
      text("ENGINE: BURNING", x + 8, y + 17);
      // Small flame icon
      float flameX = x + 135;
      float flameY = y + 17;
      fill(255, 200, 50, 180);
      triangle(flameX, flameY - 6, flameX, flameY + 6, flameX + 10, flameY);
      fill(255, 140, 30, 120);
      triangle(flameX, flameY - 4, flameX, flameY + 4, flameX + 14, flameY);
    } else {
      fill(120);
      textSize(13);
      textAlign(LEFT, CENTER);
      text("ENGINE: OFF", x + 8, y + 17);
    }
  }

  void drawOrbitData(Spacecraft ship, int x, int y) {
    fill(0, 0, 0, 110);
    noStroke();
    rect(x, y, 155, 50, 5);

    fill(200);
    textSize(11);
    textAlign(LEFT, TOP);
    text("ORBIT DATA", x + 8, y + 4);

    fill(160);
    textSize(10);
    if (ship.state == ShipState.LAUNCHING) {
      double apo = ship.computeApoapsis();
      text(String.format("Apoapsis:  %.0f km", apo), x + 8, y + 20);
      text(String.format("Altitude:  %.0f km", ship.launchAltitude), x + 8, y + 34);
    } else if (ship.state == ShipState.CIRCULARIZING) {
      double peri = ship.computePerigee();
      double targetPeri = MissionPlanner.LEO_ALTITUDE_KM;
      text(String.format("Perigee: %.0f / %.0f km", peri, targetPeri), x + 8, y + 20);
      double progress = Math.min(100, Math.max(0, (int)(peri / targetPeri * 100)));
      text(String.format("Progress: %d%%", progress), x + 8, y + 34);
    } else if (ship.state == ShipState.ORBIT) {
      text(String.format("Altitude:  %.0f km", ship.launchAltitude), x + 8, y + 20);
      text("Orbit:  Circular LEO", x + 8, y + 34);
    } else {
      text(String.format("Altitude:  %.0f km", ship.launchAltitude), x + 8, y + 20);
    }
  }

  void drawHeliocentricData(Spacecraft ship, int x, int y) {
    fill(0, 0, 0, 110);
    noStroke();
    rect(x, y, 155, 50, 5);

    fill(200);
    textSize(11);
    textAlign(LEFT, TOP);
    text("ORBIT DATA", x + 8, y + 4);

    double distFromSun = Math.sqrt(ship.px * ship.px + ship.py * ship.py);
    double distAU = distFromSun / AU_KM;

    fill(160);
    textSize(10);
    text(String.format("Sun dist: %.3f AU", distAU), x + 8, y + 20);
    text(String.format("State: %s", ship.state.toString()), x + 8, y + 34);
  }

}

String formatWarp(double w, String[] WARP_LABELS, int warpIndex) {
  if (w == 0) return "Paused";
  if (warpIndex >= 0 && warpIndex < WARP_LABELS.length) {
    return WARP_LABELS[warpIndex];
  }
  return String.format("%.0f x", w);
}
