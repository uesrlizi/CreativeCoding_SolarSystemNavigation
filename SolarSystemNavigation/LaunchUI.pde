class LaunchUI {
  LaunchStatusPanels panels;

  LaunchUI() {
    panels = new LaunchStatusPanels();
  }

  // ============================================================
  //  Main draw
  // ============================================================
  void draw() {
    drawLaunchPanel();
    panels.drawShipStatus(launchController);
    panels.drawTargetPanel(launchController, solarSystem.planets);
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
    textSize(16 * uiScale);
    textAlign(LEFT, TOP);
    text("Launch Control", panelX + 10, panelY + 10);

    ShipState st = launchController.getState();

    if (st == ShipState.IDLE) {
      fill(180);
      textSize(12 * uiScale);
      text("Spacecraft on Launch Pad", panelX + 10, panelY + 38);
      drawButton("Launch  [L]", panelX + 10, panelY + 55, 140, 35, true);
    } else if (st == ShipState.COUNTDOWN) {
      Spacecraft ship = launchController.getCurrentShip();
      if (ship != null) {
        double remaining = Spacecraft.COUNTDOWN_DURATION
            - (timeManager.simTime - ship.countdownStartTime);
        int sec = (int)Math.ceil(Math.max(0, remaining));
        fill(255, 200, 50);
        textSize(28 * uiScale);
        textAlign(CENTER, CENTER);
        text("T - " + sec, panelX + panelW / 2, panelY + panelH / 2);
      }
    } else if (st == ShipState.IGNITION) {
      float pulse = (float)(Math.sin(millis() / 1000.0 * 18.0) * 0.3 + 0.7);
      fill(255, 100 * pulse, 20 * pulse);
      textSize(22 * uiScale);
      textAlign(CENTER, CENTER);
      text("IGNITION!", panelX + panelW / 2, panelY + panelH / 2);
    } else {
      Spacecraft ship = launchController.getCurrentShip();
      if (ship != null) {
        fill(100, 200, 100);
        textSize(13 * uiScale);
        text("Ship: Spacecraft", panelX + 10, panelY + 35);
        fill(180);
        textSize(11 * uiScale);
        text(launchController.getStatusText(), panelX + 10, panelY + 55);
      }
    }
  }

  // ============================================================
  //  Draw helpers
  // ============================================================
  void drawButton(String label, int x, int y, int w, int h, boolean enabled) {
    if (enabled) {
      fill(45, 130, 45);
    } else {
      fill(70, 70, 70);
    }
    noStroke();
    rect(x, y, w, h, 6);

    fill(enabled ? 255 : 140);
    textSize(14 * uiScale);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  // ============================================================
  //  Hit testing
  // ============================================================
  boolean isLaunchButton(int mx, int my) {
    if (!launchController.canLaunch()) return false;
    int bx = 20;
    int by = height - 130 + 55;
    return mx >= bx && mx <= bx + 140 && my >= by && my <= by + 35;
  }

  // ============================================================
  //  Click handling
  // ============================================================
  void handleClick(int mx, int my) {
    // Launch button (IDLE state only)
    if (isLaunchButton(mx, my)) {
      launchController.startLaunch();
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
}
