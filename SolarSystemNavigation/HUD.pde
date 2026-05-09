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
    rect(10, 10, 420, 290, 8);

    fill(220);
    textSize(21);
    textAlign(LEFT, TOP);
    text("Spacecraft Launch Simulator", 20, 18);

    textSize(17);
    fill(180);
    double simDays = simTime / DAY_S;
    double simYears = simDays / 365.25;
    text(String.format("Time: %.1f days (%.2f years)", simDays, simYears), 20, 48);

    String warpStr = formatWarp(timeWarp);
    fill(100, 200, 100);
    text("Time warp: " + warpStr, 20, 72);

    fill(180);
    text("[Q/E] Adjust speed  [Space] Pause", 20, 96);

    double auPerPixel = 1.0 / (AU_KM * cam.scale);
    text(String.format("Zoom: %.4f AU/px", auPerPixel), 20, 120);

    fill(140);
    textSize(15);
    text("[O] Orbits [L] Labels [T] Trails [R] Reset", 20, 144);
    text("[1-8] Focus planet [0] Focus Sun", 20, 168);
    text("[V] View Mode [F] Follow Ship", 20, 192);
    text("Drag to pan, Scroll to zoom", 20, 216);
  }

  void drawViewModeIndicator() {
    noStroke();
    fill(0, 0, 0, 160);
    rect(width - 130, 10, 120, 35, 8);

    fill(200);
    textSize(14);
    textAlign(LEFT, CENTER);
    String modeText = (camera.mode == ViewMode.MAP_VIEW) ? "MAP VIEW" : "SHIP VIEW";
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
