class LaunchUI {
  String shipName = "";
  boolean inputFocused = false;
  boolean showLaunchPopup = false;
  LaunchStatusPanels panels;

  LaunchUI() {
    panels = new LaunchStatusPanels();
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
    panels.drawShipStatus(launchController);
    panels.drawTargetPanel(launchController, solarSystem.planets);
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
      // Click outside popup -> close
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
    if (launchController.canSelectTarget() && panels.isTargetRow(mx, my, launchController, solarSystem.planets)) {
      int idx = panels.getTargetIndex(mx, my, launchController, solarSystem.planets);
      if (idx >= 0) {
        launchController.selectTarget(solarSystem.planets.get(idx));
        return;
      }
    }

    // Transfer button
    if (panels.isTransferButton(mx, my, launchController)) {
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
