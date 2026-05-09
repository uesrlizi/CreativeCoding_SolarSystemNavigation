class HUD {
  LaunchUI launchUI;

  HUD() {
    launchUI = new LaunchUI();
  }

  void draw(CameraController cam, double simTime, double timeWarp, String statusText) {
    drawInfoPanel(cam, simTime, timeWarp, statusText);
    drawViewModeIndicator();
    launchUI.draw();
    if (timeWarp == 0) {
      drawPauseIndicator();
    }
  }

  void drawInfoPanel(CameraController cam, double simTime, double timeWarp, String statusText) {
    noStroke();
    fill(0, 0, 0, 160);
    rect(10, 10, 380, 120, 8);

    fill(220);
    textSize(21);
    textAlign(LEFT, TOP);
    text("Spacecraft Flight Simulator", 20, 18);

    fill(180);
    textSize(16);
    text("Time: " + timeManager.getTimeDisplay(), 20, 48);

    fill(100, 200, 100);
    text("Speed: " + timeManager.getWarpDisplay(), 20, 72);

    fill(150);
    textSize(13);
    text("[Q/E] Speed  [Space] Pause  [L] Launch  [M] Maneuver  [V] View", 20, 96);
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

  void drawPauseIndicator() {
    fill(255, 80, 80);
    textSize(30);
    textAlign(CENTER, CENTER);
    text("PAUSED", width / 2, height - 60);
  }
}
