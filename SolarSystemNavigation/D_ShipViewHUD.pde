class ShipViewHUD {
  void draw(Spacecraft ship) {
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
