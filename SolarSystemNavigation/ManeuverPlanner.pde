class ManeuverPlanner {
  boolean visible = false;
  ArrayList<OrbitalManeuver> maneuvers;
  int selectedIndex = -1;

  ManeuverPlanner() {
    maneuvers = new ArrayList<OrbitalManeuver>();
  }

  void toggle() {
    visible = !visible;
  }

  void addManeuver(OrbitalManeuver m) {
    maneuvers.add(m);
    selectedIndex = maneuvers.size() - 1;
  }

  void clearManeuvers() {
    maneuvers.clear();
    selectedIndex = -1;
  }

  OrbitalManeuver popNext() {
    if (maneuvers.isEmpty()) return null;
    selectedIndex = -1;
    return maneuvers.remove(0);
  }

  OrbitalManeuver getNext() {
    if (maneuvers.isEmpty()) return null;
    return maneuvers.get(0);
  }

  void executeNext(Spacecraft ship) {
    OrbitalManeuver m = popNext();
    if (m == null || ship == null) return;

    double[] dv = m.calculateDeltaVVVector(ship.velocity, m.deltaV);
    ship.applyDeltaV(dv);
  }

  void draw(Spacecraft ship, CelestialBody body) {
    if (!visible) return;

    int panelX = width - 280;
    int panelY = height - 400;
    int panelW = 270;
    int panelH = 370;

    noStroke();
    fill(0, 0, 0, 200);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Orbit Maneuvers [M]", panelX + 10, panelY + 10);

    fill(150);
    textSize(12);
    text("Click to add maneuver:", panelX + 15, panelY + 35);

    int rowY = panelY + 55;
    String[] maneuverNames = {"Circularize", "Raise Orbit", "Lower Orbit", "Escape Burn"};
    int[] keys = {'1', '2', '3', '4'};

    for (int i = 0; i < 4; i++) {
      boolean canAdd = ship != null && ship.phase == ShipPhase.IN_ORBIT;
      fill(canAdd ? color(150) : color(80));
      textSize(13);
      text("[" + (char)keys[i] + "] " + maneuverNames[i], panelX + 15, rowY + i * 28);
    }

    fill(100);
    textSize(11);
    text("Orbital Info:", panelX + 15, rowY + 120);

    if (ship != null && ship.phase == ShipPhase.IN_ORBIT) {
      double r = Math.sqrt(ship.position[0]*ship.position[0] + ship.position[1]*ship.position[1]);
      double v = ship.speed();
      double vCirc = Math.sqrt(body.gm / r);
      double dvNeeded = vCirc - v;

      double[] elements = physics.orbitalElements(ship.position, ship.velocity, body.gm);
      double a = elements[0];
      double e = elements[1];
      double apogee = (a * (1 + e) - body.radius * 1000) / 1000;
      double perigee = (a * (1 - e) - body.radius * 1000) / 1000;

      fill(150);
      textSize(11);
      text(String.format("Current Orbit: %.0f x %.0f km", apogee, perigee), panelX + 15, rowY + 140);
      text(String.format("Circ DV: %.0f m/s", dvNeeded), panelX + 15, rowY + 156);
    }

    if (!maneuvers.isEmpty()) {
      fill(100, 150, 100);
      textSize(13);
      text("Planned Maneuvers:", panelX + 15, rowY + 185);

      for (int i = 0; i < maneuvers.size(); i++) {
        OrbitalManeuver m = maneuvers.get(i);
        fill(i == selectedIndex ? color(100, 200, 100) : color(150));
        text((i + 1) + ". " + m.name + " (" + String.format("%.0f", m.deltaV) + " m/s)", panelX + 15, rowY + 205 + i * 22);
      }

      fill(100, 200, 100);
      textSize(13);
      text("[X] Execute Next", panelX + 15, rowY + 300);
      text("[C] Clear All", panelX + 15, rowY + 320);
    }
  }

  boolean isClickInPanel(int mx, int my) {
    return visible && mx >= width - 280 && mx <= width - 10 && my >= height - 400 && my <= height - 30;
  }

  void handleClick(int mx, int my, Spacecraft ship, CelestialBody body) {
    if (!isClickInPanel(mx, my) || ship == null) return;

    int panelX = width - 280;
    int panelY = height - 400;
    int rowY = panelY + 55;

    for (int i = 0; i < 4; i++) {
      int y1 = rowY + i * 28;
      int y2 = y1 + 25;
      if (mx >= panelX + 10 && mx <= panelX + 260 && my >= y1 && my <= y2) {
        if (ship.phase == ShipPhase.IN_ORBIT) {
          switch(i) {
            case 0:
              double r = Math.sqrt(ship.position[0]*ship.position[0] + ship.position[1]*ship.position[1]);
              double v = ship.speed();
              double vCirc = Math.sqrt(body.gm / r);
              addManeuver(new OrbitalManeuver("Circularize", vCirc - v, new double[]{0, 1, 0}, ManeuverType.CIRCULARIZE));
              break;
            case 1:
              addManeuver(OrbitalManeuver.raiseApogee(100));
              break;
            case 2:
              addManeuver(OrbitalManeuver.lowerApogee(100));
              break;
            case 3:
              addManeuver(OrbitalManeuver.escape(body));
              break;
          }
        }
        return;
      }
    }
  }

  void handleKey(char k, Spacecraft ship, CelestialBody body) {
    if (!visible) return;
    if (ship == null || ship.phase != ShipPhase.IN_ORBIT) return;

    if (k == '1') {
      double r = Math.sqrt(ship.position[0]*ship.position[0] + ship.position[1]*ship.position[1]);
      double v = ship.speed();
      double vCirc = Math.sqrt(body.gm / r);
      addManeuver(new OrbitalManeuver("Circularize", vCirc - v, new double[]{0, 1, 0}, ManeuverType.CIRCULARIZE));
    }
    if (k == '2') {
      addManeuver(OrbitalManeuver.raiseApogee(100));
    }
    if (k == '3') {
      addManeuver(OrbitalManeuver.lowerApogee(100));
    }
    if (k == '4') {
      addManeuver(OrbitalManeuver.escape(body));
    }
    if (k == 'x' || k == 'X') {
      executeNext(ship);
    }
    if (k == 'c' || k == 'C') {
      clearManeuvers();
    }
  }
}
