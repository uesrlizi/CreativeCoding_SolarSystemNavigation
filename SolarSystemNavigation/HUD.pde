class HUD {
  LaunchUI launchUI;

  HUD() {
    launchUI = new LaunchUI();
  }

  void draw(CameraController cam, double simTime, double timeWarp,
            double[] WARP_LEVELS, List<CelestialBody> planets) {
    drawInfoPanel(cam, simTime, timeWarp, WARP_LEVELS);
    drawViewModeIndicator();
    launchUI.draw();
    if (timeWarp == 0) {
      drawPauseIndicator();
    }
  }

  void drawInfoPanel(CameraController cam, double simTime, double timeWarp, double[] WARP_LEVELS) {
    noStroke();
    fill(0, 0, 0, 160);
    rect(10, 10, 420, 150, 8);

    fill(220);
    textSize(21);
    textAlign(LEFT, TOP);
    text("Spacecraft Launch Simulator", 20, 18);

    textSize(17);
    fill(180);
    text("Time: " + timeManager.getTimeDisplay(), 20, 48);

    fill(100, 200, 100);
    text("Speed: " + timeManager.getWarpDisplay(), 20, 72);

    fill(140);
    textSize(14);
    text("[Q/E] Adjust speed  [Space] Pause", 20, 96);
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

  void drawPlanetList(List<CelestialBody> planets) {
    fill(0, 0, 0, 140);
    rect(width - 260, 10, 250, 35 + planets.size() * 27, 8);
    fill(200);
    textSize(17);
    textAlign(LEFT, TOP);
    text("Planets [1-8 Focus]", width - 250, 18);
    for (int idx = 0; idx < planets.size(); idx++) {
      CelestialBody p = planets.get(idx);
      fill(p.col);
      text((idx + 1) + ". " + p.name, width - 250, 45 + idx * 27);
    }
  }

  void drawPauseIndicator() {
    fill(255, 80, 80);
    textSize(30);
    textAlign(CENTER, CENTER);
    text("PAUSED", width / 2, height - 60);
  }
}

String formatWarp(double w) {
  if (w == 0) return "Paused";
  if (w >= 1e6) return String.format("%.0e x", w);
  if (w >= 1000) return String.format("%.0f x", w);
  if (w >= 1) return String.format("%.0f x", w);
  return String.format("%.1f x", w);
}
