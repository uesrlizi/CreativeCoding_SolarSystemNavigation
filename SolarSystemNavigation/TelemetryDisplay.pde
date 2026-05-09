class TelemetryDisplay {
  void draw(Spacecraft ship, CelestialBody body) {
    if (ship == null) return;

    int panelX = width - 280;
    int panelY = 170;
    int panelW = 270;
    int panelH = 200;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(14);
    textAlign(LEFT, TOP);
    text("Telemetry - " + ship.name, panelX + 10, panelY + 10);

    double r = Math.sqrt(ship.position[0]*ship.position[0] + ship.position[1]*ship.position[1] + ship.position[2]*ship.position[2]);
    double v = ship.speed();
    double alt = (r - body.radius * 1000) / 1000;
    double period = 2 * PI * Math.sqrt(r * r * r / body.gm);

    double[] elements = physics.orbitalElements(ship.position, ship.velocity, body.gm);
    double a = elements[0];
    double e = elements[1];
    double apogee = a * (1 + e) - body.radius * 1000;
    double perigee = a * (1 - e) - body.radius * 1000;

    fill(150);
    textSize(12);
    int y = panelY + 35;

    color phaseColor = color(100, 200, 100);
    fill(phaseColor);
    String phaseStr = "ON GROUND";
    if (ship.phase == ShipPhase.POWERED_ASCENT) phaseStr = "ASCENT";
    else if (ship.phase == ShipPhase.IN_ORBIT) phaseStr = "IN ORBIT";
    else if (ship.phase == ShipPhase.TRANSFER) phaseStr = "TRANSFER";
    text("Phase: " + phaseStr, panelX + 15, y); y += 22;

    fill(150);
    text(String.format("Altitude: %.1f km", alt), panelX + 15, y); y += 18;
    text(String.format("Velocity: %.1f m/s", v), panelX + 15, y); y += 18;
    text(String.format("Period: %.1f min", period / 60), panelX + 15, y); y += 18;

    if (ship.phase == ShipPhase.IN_ORBIT) {
      text(String.format("Apogee: %.0f km", apogee / 1000), panelX + 15, y); y += 18;
      text(String.format("Perigee: %.0f km", Math.max(0, perigee / 1000)), panelX + 15, y); y += 18;
    }

    fill(100, 200, 100);
    text(String.format("Fuel: %.0f%%", ship.fuel / 500.0 * 100), panelX + 15, y);
  }
}
