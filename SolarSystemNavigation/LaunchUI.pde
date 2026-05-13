class LaunchUI {
  String shipName = "";
  boolean inputFocused = false;
  boolean showLaunchPopup = false;

  LaunchUI() {
  }

  boolean isPopupOpen() {
    return showLaunchPopup;
  }

  void openPopup() {
    showLaunchPopup = true;
    shipName = "";
    inputFocused = true;
  }

  void closePopup() {
    showLaunchPopup = false;
    inputFocused = false;
    shipName = "";
  }

  // ============================================================
  //  Main draw
  // ============================================================
  void draw() {
    drawLaunchPanel();
    drawShipStatus();
    drawTargetPanel();
    if (showLaunchPopup) {
      drawLaunchPopup();
    }
  }

  // ============================================================
  //  Bottom-left: launch control panel
  // ============================================================
  void drawLaunchPanel() {
    int panelX = 10;
    int panelY = height - 130;
    int panelW = 210;
    int panelH = 120;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Launch Control", panelX + 10, panelY + 10);

    fill(180);
    textSize(12);

    if (launchController.canLaunch()) {
      text("No active spacecraft", panelX + 10, panelY + 38);
      drawButton("+ New Ship  [L]", panelX + 10, panelY + 55, 140, 35, true);
    } else {
      Spacecraft ship = launchController.getCurrentShip();
      if (ship != null) {
        fill(100, 200, 100);
        textSize(13);
        text("Ship: " + ship.name, panelX + 10, panelY + 35);
        fill(180);
        textSize(11);
        text(launchController.getStatusText(), panelX + 10, panelY + 55);
      }
    }
  }

  // ============================================================
  //  Right side: ship status
  // ============================================================
  void drawShipStatus() {
    if (launchController.getCurrentShip() == null) return;

    int panelX = width - 280;
    int panelY = 55;
    int panelW = 270;
    int panelH = 100;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    Spacecraft ship = launchController.getCurrentShip();
    fill(100, 200, 100);
    textSize(15);
    textAlign(LEFT, TOP);
    text("Spacecraft: " + ship.name, panelX + 10, panelY + 8);

    fill(180);
    textSize(13);
    ShipState st = launchController.getState();

    if (st == ShipState.LAUNCHING) {
      double speed = Math.sqrt(ship.earthRelVel[0] * ship.earthRelVel[0]
                             + ship.earthRelVel[1] * ship.earthRelVel[1]);
      double apoAlt = ship.computeApoapsis();
      String apoStr = (apoAlt > 1e6) ? "escaping" : String.format("%.0f km", apoAlt);

      text(String.format("Altitude: %.0f km   Speed: %.2f km/s", ship.launchAltitude, speed),
           panelX + 10, panelY + 28);
      text(String.format("Apoapsis: %s / %.0f km", apoStr, MissionPlanner.LEO_ALTITUDE_KM),
           panelX + 10, panelY + 46);

      if (ship.thrustActive) {
        double progress = Math.min(1.0, apoAlt / MissionPlanner.LEO_ALTITUDE_KM);
        drawProgressBar(panelX + 10, panelY + 64, panelW - 20, 12, progress,
                        "Burning: " + (int)(progress * 100) + "%");
      } else {
        // Coasting — show a different style bar
        fill(40, 60, 80);
        noStroke();
        rect(panelX + 10, panelY + 64, panelW - 20, 12, 4);
        fill(180);
        textSize(11);
        textAlign(CENTER, CENTER);
        text("Coasting to apoapsis...", panelX + panelW / 2, panelY + 70);
      }
    } else if (ship.earthRelative) {
      text(String.format("LEO Orbit: %.0f km altitude", ship.launchAltitude),
           panelX + 10, panelY + 30);
    } else {
      double au = ship.a / AU_KM;
      text(String.format("Heliocentric Orbit: %.3f AU", au),
           panelX + 10, panelY + 30);
      // Transfer progress bar when in TRANSFER
      if (st == ShipState.TRANSFER && launchController.transferOrbitParams != null) {
        double elapsed = timeManager.simTime - launchController.transferStartTime;
        double total = launchController.planner.calculateTransferTime(
                         launchController.transferOrbitParams[0], GM_SUN);
        double progress = Math.min(1.0, elapsed / Math.max(1.0, total));
        drawProgressBar(panelX + 10, panelY + 52, panelW - 20, 10, progress,
                        "Transfer: " + (int)(progress * 100) + "%");
      }
    }
  }

  void drawProgressBar(int x, int y, int w, int h, double progress, String label) {
    fill(30, 30, 30);
    noStroke();
    rect(x, y, w, h, 4);

    fill(80, 180, 80);
    rect(x, y, (float)(w * Math.min(1.0, Math.max(0.0, progress))), h, 4);

    fill(220);
    textSize(11);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  // ============================================================
  //  Right side: mission target panel
  // ============================================================
  void drawTargetPanel() {
    ShipState st = launchController.getState();
    if (st != ShipState.ORBIT && st != ShipState.TRANSFER) return;

    int panelX = width - 280;
    int panelY = 170;
    int panelW = 270;
    int panelH = 300;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Mission Target", panelX + 10, panelY + 10);

    List<CelestialBody> planets = solarSystem.planets;
    CelestialBody earth = launchController.getEarth();
    int rowY = panelY + 40;
    int rowSpacing = 28;

    for (int idx = 0; idx < planets.size(); idx++) {
      CelestialBody p = planets.get(idx);
      // Skip Earth as a target
      if (p == earth) continue;

      int rY = rowY;
      rowY += rowSpacing;

      boolean isSelected = (launchController.getSelectedTarget() == p);
      if (isSelected) {
        fill(50, 80, 50, 200);
        noStroke();
        rect(panelX + 8, rY - 2, panelW - 16, 28, 4);
      }

      fill(p.col);
      textSize(14);
      textAlign(LEFT, CENTER);
      text((idx + 1) + ". " + p.name, panelX + 18, rY + 12);

      if (isSelected) {
        fill(100, 200, 100);
        textSize(11);
        text("Selected", panelX + 160, rY + 12);
      }
    }

    // Transfer button
    boolean canTransfer = launchController.canTransfer();
    String btnLabel = canTransfer ? "Transfer  [T]" : "Select a target";
    drawButton(btnLabel, panelX + 10, panelY + panelH - 45, 140, 32, canTransfer);
  }

  // ============================================================
  //  Modal popup: create spacecraft
  // ============================================================
  void drawLaunchPopup() {
    // Full-screen overlay
    fill(0, 0, 0, 160);
    noStroke();
    rect(0, 0, width, height);

    int popupW = 340;
    int popupH = 200;
    int px = width / 2 - popupW / 2;
    int py = height / 2 - popupH / 2;

    // Dialog background
    fill(25, 25, 45);
    stroke(80, 80, 120);
    strokeWeight(2);
    rect(px, py, popupW, popupH, 10);

    // Title bar
    noStroke();
    fill(40, 40, 60);
    rect(px, py, popupW, 36, 10, 10, 0, 0);

    fill(220);
    textSize(17);
    textAlign(CENTER, CENTER);
    text("Create Spacecraft", px + popupW / 2, py + 18);

    // Name label
    fill(180);
    textSize(14);
    textAlign(LEFT, CENTER);
    text("Ship Name:", px + 25, py + 65);

    // Text input
    drawTextInput(px + 120, py + 50, 180, 30);

    // Buttons
    boolean canLaunch = shipName.length() > 0;
    drawButton("Launch", px + 30, py + 110, 100, 36, canLaunch);
    drawButton("Cancel  [Esc]", px + popupW - 140, py + 110, 110, 36, true);

    // Hint
    fill(120);
    textSize(11);
    textAlign(CENTER, TOP);
    text("Press Enter to launch, Esc to cancel", px + popupW / 2, py + 155);
  }

  // ============================================================
  //  Draw helpers
  // ============================================================
  void drawTextInput(int x, int y, int w, int h) {
    stroke(inputFocused ? color(100, 180, 100) : color(80, 80, 100));
    strokeWeight(1);
    fill(15, 15, 25);
    rect(x, y, w, h, 4);

    fill(inputFocused ? 255 : 180);
    noStroke();
    textSize(14);
    textAlign(LEFT, CENTER);
    String display = shipName;
    if (inputFocused && (frameCount / 30) % 2 == 0) {
      display += "|";
    }
    text(display.length() > 0 ? display : "Enter name...", x + 8, y + h / 2);
  }

  void drawButton(String label, int x, int y, int w, int h, boolean enabled) {
    if (enabled) {
      fill(45, 130, 45);
    } else {
      fill(70, 70, 70);
    }
    noStroke();
    rect(x, y, w, h, 6);

    fill(enabled ? 255 : 140);
    textSize(14);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  // ============================================================
  //  Hit testing
  // ============================================================
  boolean isNewShipButton(int mx, int my) {
    if (!launchController.canLaunch()) return false;
    int bx = 20;
    int by = height - 130 + 55;
    return mx >= bx && mx <= bx + 140 && my >= by && my <= by + 35;
  }

  boolean isTargetRow(int mx, int my) {
    int panelX = width - 280;
    int panelY = 170;
    // Count non-Earth planets to see if click is within the list
    CelestialBody earth = launchController.getEarth();
    int targetCount = 0;
    for (CelestialBody p : solarSystem.planets) {
      if (p != earth) targetCount++;
    }
    int listBottom = panelY + 40 + targetCount * 28;
    return mx >= panelX && mx <= panelX + 270 && my >= panelY + 40 && my <= listBottom;
  }

  int getTargetIndex(int mx, int my) {
    int panelX = width - 280;
    int panelY = 170;
    CelestialBody earth = launchController.getEarth();
    int displayIdx = (my - (panelY + 40)) / 28;
    // Map display index back to actual planet index
    int actualIdx = 0;
    int count = 0;
    for (int i = 0; i < solarSystem.planets.size(); i++) {
      if (solarSystem.planets.get(i) == earth) continue;
      if (count == displayIdx) { actualIdx = i; break; }
      count++;
    }
    return (count == displayIdx) ? actualIdx : -1;
  }

  boolean isTransferButton(int mx, int my) {
    if (!launchController.canTransfer()) return false;
    int panelX = width - 280;
    int panelH = 300;
    int panelY = 170;
    int bx = panelX + 10;
    int by = panelY + panelH - 45;
    return mx >= bx && mx <= bx + 140 && my >= by && my <= by + 32;
  }

  boolean isLaunchPopupButton(int mx, int my) {
    if (!showLaunchPopup) return false;
    int popupW = 340;
    int px = width / 2 - popupW / 2;
    int py = height / 2 - 100;
    return mx >= px + 30 && mx <= px + 130 && my >= py + 110 && my <= py + 146;
  }

  boolean isCancelPopupButton(int mx, int my) {
    if (!showLaunchPopup) return false;
    int popupW = 340;
    int px = width / 2 - popupW / 2;
    int py = height / 2 - 100;
    return mx >= px + popupW - 140 && mx <= px + popupW - 30 && my >= py + 110 && my <= py + 146;
  }

  boolean isPopupTextInput(int mx, int my) {
    if (!showLaunchPopup) return false;
    int popupW = 340;
    int px = width / 2 - popupW / 2;
    int py = height / 2 - 100;
    return mx >= px + 120 && mx <= px + 300 && my >= py + 50 && my <= py + 80;
  }

  // ============================================================
  //  Click handling
  // ============================================================
  void handleClick(int mx, int my) {
    // Popup buttons take priority
    if (showLaunchPopup) {
      if (isLaunchPopupButton(mx, my) && shipName.length() > 0) {
        launchController.startLaunch(shipName);
        closePopup();
        return;
      }
      if (isCancelPopupButton(mx, my)) {
        closePopup();
        return;
      }
      if (isPopupTextInput(mx, my)) {
        inputFocused = true;
        return;
      }
      // Click outside popup → close
      int popupW = 340;
      int popupH = 200;
      int px = width / 2 - popupW / 2;
      int py = height / 2 - popupH / 2;
      if (mx < px || mx > px + popupW || my < py || my > py + popupH) {
        closePopup();
      }
      return;
    }

    // New ship button
    if (isNewShipButton(mx, my)) {
      openPopup();
      return;
    }

    // Target selection
    if (launchController.canSelectTarget() && isTargetRow(mx, my)) {
      int idx = getTargetIndex(mx, my);
      if (idx >= 0) {
        launchController.selectTarget(solarSystem.planets.get(idx));
        return;
      }
    }

    // Transfer button
    if (isTransferButton(mx, my)) {
      launchController.initiateTransfer();
    }
  }

  // ============================================================
  //  Keyboard handling (only when popup is open)
  // ============================================================
  void keyPressed(char keyChar) {
    if (!showLaunchPopup) return;

    if (keyChar == BACKSPACE) {
      if (shipName.length() > 0) {
        shipName = shipName.substring(0, shipName.length() - 1);
      }
    } else if (keyChar == ENTER || keyChar == RETURN) {
      if (shipName.length() > 0) {
        launchController.startLaunch(shipName);
        closePopup();
      }
    } else if (keyChar == ESC) {
      closePopup();
    } else if (keyChar >= 32 && keyChar <= 126) {
      if (shipName.length() < 20) {
        shipName += keyChar;
      }
    }
  }
}
