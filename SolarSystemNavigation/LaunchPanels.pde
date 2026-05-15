class LaunchStatusPanels {

  void drawShipStatus(LaunchController ctrl) {
    Spacecraft ship = ctrl.getCurrentShip();
    if (ship == null) return;

    int panelX = width - 280;
    int panelY = 55;
    int panelW = 270;
    int panelH = 100;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(100, 200, 100);
    textSize(15 * uiScale);
    textAlign(LEFT, TOP);
    text("Spacecraft", panelX + 10, panelY + 8);

    fill(180);
    textSize(13 * uiScale);
    ShipState st = ctrl.getState();

    if (st == ShipState.IDLE) {
      text("Status: Ready on launch pad", panelX + 10, panelY + 28);
      text("Altitude: 0 km   Speed: 0.00 km/s", panelX + 10, panelY + 46);
    } else if (st == ShipState.COUNTDOWN) {
      double remaining = Spacecraft.COUNTDOWN_DURATION
          - (timeManager.simTime - ship.countdownStartTime);
      int sec = (int)Math.ceil(Math.max(0, remaining));
      fill(255, 200, 50);
      textSize(18 * uiScale);
      text("Countdown: T - " + sec + "s", panelX + 10, panelY + 30);
      fill(180);
      textSize(13 * uiScale);
      text("Altitude: 0 km   Speed: 0.00 km/s", panelX + 10, panelY + 50);
    } else if (st == ShipState.IGNITION) {
      fill(255, 140, 30);
      textSize(16 * uiScale);
      text("ENGINE IGNITION - Hold-down", panelX + 10, panelY + 28);
      fill(180);
      textSize(13 * uiScale);
      text("Altitude: 0 km   Speed: 0.00 km/s", panelX + 10, panelY + 50);
    } else if (st == ShipState.LAUNCHING) {
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
        fill(40, 60, 80);
        noStroke();
        rect(panelX + 10, panelY + 64, panelW - 20, 12, 4);
        fill(180);
        textSize(11 * uiScale);
        textAlign(CENTER, CENTER);
        text("Coasting to apoapsis...", panelX + panelW / 2, panelY + 70);
      }
    } else if (st == ShipState.CIRCULARIZING) {
      double speed = Math.sqrt(ship.earthRelVel[0] * ship.earthRelVel[0]
                             + ship.earthRelVel[1] * ship.earthRelVel[1]);
      double periAlt = ship.computePerigee();
      double circSpeed = Math.sqrt(MissionPlanner.GM_EARTH / MissionPlanner.LEO_RADIUS_KM);

      text(String.format("Altitude: %.0f km   Speed: %.2f km/s", ship.launchAltitude, speed),
           panelX + 10, panelY + 28);
      text(String.format("Perigee: %.0f / %.0f km   Target v: %.2f km/s",
           periAlt, MissionPlanner.LEO_ALTITUDE_KM, circSpeed),
           panelX + 10, panelY + 46);

      double periProgress = Math.min(1.0, Math.max(0.0,
                            periAlt / MissionPlanner.LEO_ALTITUDE_KM));
      drawProgressBar(panelX + 10, panelY + 64, panelW - 20, 12, periProgress,
                      "Circularizing: " + (int)(periProgress * 100) + "%");
    } else if (ship.earthRelative) {
      text(String.format("LEO Orbit: %.0f km altitude", ship.launchAltitude),
           panelX + 10, panelY + 30);
    } else {
      double au = ship.a / AU_KM;
      text(String.format("Heliocentric Orbit: %.3f AU", au),
           panelX + 10, panelY + 30);
      if (st == ShipState.TRANSFER && ctrl.transferOrbitParams != null) {
        double elapsed = timeManager.simTime - ctrl.transferStartTime;
        double total = ctrl.planner.calculateTransferTime(
                         ctrl.transferOrbitParams[0], GM_SUN);
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
    textSize(11 * uiScale);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  void drawTargetPanel(LaunchController ctrl, List<CelestialBody> planets) {
    ShipState st = ctrl.getState();
    if (st != ShipState.ORBIT && st != ShipState.TRANSFER) return;

    int panelX = width - 280;
    int panelY = 170;
    int panelW = 270;
    int panelH = 300;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16 * uiScale);
    textAlign(LEFT, TOP);
    text("Mission Target", panelX + 10, panelY + 10);

    CelestialBody earth = ctrl.getEarth();
    int rowY = panelY + 40;
    int rowSpacing = 28;

    for (int idx = 0; idx < planets.size(); idx++) {
      CelestialBody p = planets.get(idx);
      if (p == earth) continue;

      int rY = rowY;
      rowY += rowSpacing;

      boolean isSelected = (ctrl.getSelectedTarget() == p);
      if (isSelected) {
        fill(50, 80, 50, 200);
        noStroke();
        rect(panelX + 8, rY - 2, panelW - 16, 28, 4);
      }

      fill(p.col);
      textSize(14 * uiScale);
      textAlign(LEFT, CENTER);
      text((idx + 1) + ". " + p.name, panelX + 18, rY + 12);

      if (isSelected) {
        fill(100, 200, 100);
        textSize(11 * uiScale);
        text("Selected", panelX + 160, rY + 12);
      }
    }

    boolean canTransfer = ctrl.canTransfer();
    String btnLabel = canTransfer ? "Transfer  [T]" : "Select a target";
    drawButton(btnLabel, panelX + 10, panelY + panelH - 45, 140, 32, canTransfer);
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
    textSize(14 * uiScale);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  // --- Hit testing for target panel ---

  boolean isTargetRow(int mx, int my, LaunchController ctrl, List<CelestialBody> planets) {
    int panelX = width - 280;
    int panelY = 170;
    CelestialBody earth = ctrl.getEarth();
    int targetCount = 0;
    for (CelestialBody p : planets) {
      if (p != earth) targetCount++;
    }
    int listBottom = panelY + 40 + targetCount * 28;
    return mx >= panelX && mx <= panelX + 270 && my >= panelY + 40 && my <= listBottom;
  }

  int getTargetIndex(int mx, int my, LaunchController ctrl, List<CelestialBody> planets) {
    int panelX = width - 280;
    int panelY = 170;
    CelestialBody earth = ctrl.getEarth();
    int displayIdx = (my - (panelY + 40)) / 28;
    int actualIdx = 0;
    int count = 0;
    for (int i = 0; i < planets.size(); i++) {
      if (planets.get(i) == earth) continue;
      if (count == displayIdx) { actualIdx = i; break; }
      count++;
    }
    return (count == displayIdx) ? actualIdx : -1;
  }

  boolean isTransferButton(int mx, int my, LaunchController ctrl) {
    if (!ctrl.canTransfer()) return false;
    int panelX = width - 280;
    int panelH = 300;
    int panelY = 170;
    int bx = panelX + 10;
    int by = panelY + panelH - 45;
    return mx >= bx && mx <= bx + 140 && my >= by && my <= by + 32;
  }
}
