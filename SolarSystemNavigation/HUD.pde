class HUD {
  LaunchUI launchUI;

  HUD() {
    launchUI = new LaunchUI();
  }

  void draw(CameraController cam, double simTime, double timeWarp,
            double[] WARP_LEVELS, String[] WARP_LABELS,
            int warpIndex, List<CelestialBody> planets) {
    drawInfoPanel(cam, simTime, timeWarp, WARP_LABELS, warpIndex);
    drawPlanetList(planets);
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
    rect(10, 10, 420, 240, 8);

    fill(220);
    textSize(21);
    textAlign(LEFT, TOP);
    text("Spacecraft Launch Simulator", 20, 18);

    textSize(17);
    fill(180);
    double simDays = simTime / DAY_S;
    double simYears = simDays / 365.25;
    text(String.format("Time: %.1f days (%.2f years)", simDays, simYears), 20, 48);

    String warpStr = formatWarp(timeWarp, WARP_LABELS, warpIndex);
    fill(100, 200, 100);
    text("Time Warp: " + warpStr, 20, 72);

    double auPerPixel = 1.0 / (AU_KM * cam.scale);
    text(String.format("Zoom: %.4f AU/px", auPerPixel), 20, 96);

    String focusName = cam.getFocusName();
    if (focusName != null) {
      fill(255, 200, 50);
      textSize(15);
      text("Focus: " + focusName, 20, 118);
    }

    fill(140);
    textSize(13);
    text("[Space] Pause    [Q/E] Warp Speed    [R] Reset View", 20, 125);
    text("[O] Orbits    [L] Labels    [T] Trails", 20, 148);
    text("[1-8] Focus Planet    [0] Sun    [V] View Mode", 20, 171);
    text("[F] Follow Ship    Drag to Pan    Scroll to Zoom", 20, 194);
    text("Double-click object to focus", 20, 217);
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
    int px = 10;
    int py = 225;
    int pw = 200;
    int ph = 38 + planets.size() * 27;

    noStroke();
    fill(0, 0, 0, 140);
    rect(px, py, pw, ph, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Planets  [1-8]", px + 10, py + 8);

    for (int idx = 0; idx < planets.size(); idx++) {
      CelestialBody p = planets.get(idx);
      fill(p.col);
      textSize(13);
      text((idx + 1) + ". " + p.name, px + 10, py + 35 + idx * 27);
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
