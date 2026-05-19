// ========== ORBIT DISPLAY ==========

class OrbitDisplay {
  float panelX, panelY, panelW, panelH;
  float margin;
  float rowH;

  OrbitDisplay() {
    float scale = uiScale;
    panelW = 220 * scale;
    panelH = 260 * scale;
    margin = 12 * scale;
    rowH = 20 * scale;
    panelX = width - panelW - margin * 2;
    panelY = 120 * scale;
  }

  void update() {
    float scale = uiScale;
    panelW = 220 * scale;
    panelH = 260 * scale;
    margin = 12 * scale;
    rowH = 20 * scale;
    panelX = margin;
    panelY = height - panelH - margin;
  }

  void draw(Spacecraft craft, double simTime) {
    if (craft == null) return;

    pushStyle();
    float scale = uiScale;

    // Panel background
    noStroke();
    fill(10, 15, 30, 200);
    rect(panelX, panelY, panelW, panelH, 8 * scale);

    // Title
    fill(255, 200, 100);
    textSize(16 * scale);
    textAlign(LEFT, TOP);
    text(craft.name, panelX + margin, panelY + margin);

    // Divider
    stroke(100, 120, 180, 100);
    strokeWeight(1 * scale);
    line(panelX + margin, panelY + margin + 26 * scale, panelX + panelW - margin, panelY + margin + 26 * scale);
    noStroke();

    float lineY = panelY + margin + 36 * scale;
    float labelW = 100 * scale;
    float valueX = panelX + panelW - margin;

    // Info text style
    textSize(12 * scale);

    // Reference body
    if (craft.referenceBody != null) {
      drawInfoLine("Orbiting:", craft.referenceBody.name, lineY, labelW, valueX);
      lineY += rowH;
    }

    if (craft.orbit != null) {
      Orbit orbit = craft.orbit;

      // Apoapsis
      double apoAlt = orbit.getApoapsisAltitude();
      drawInfoLine("Apoapsis:", formatDistance(apoAlt), lineY, labelW, valueX);
      lineY += rowH;

      // Periapsis
      double periAlt = orbit.getPeriapsisAltitude();
      drawInfoLine("Periapsis:", formatDistance(periAlt), lineY, labelW, valueX);
      lineY += rowH;

      // Time to Apoapsis
      double timeToApo = orbit.getTimeToApoapsis(simTime);
      drawInfoLine("T to Apo:", formatTime(timeToApo), lineY, labelW, valueX);
      lineY += rowH;

      // Time to Periapsis
      double timeToPeri = orbit.getTimeToPeriapsis(simTime);
      drawInfoLine("T to Peri:", formatTime(timeToPeri), lineY, labelW, valueX);
      lineY += rowH;

      // Period
      drawInfoLine("Orbit Period:", formatTime(orbit.period), lineY, labelW, valueX);
      lineY += rowH;

      // Semi-major axis
      drawInfoLine("Semi-major:", formatDistance(orbit.a), lineY, labelW, valueX);
      lineY += rowH;

      // Eccentricity
      drawInfoLine("Eccentricity:", String.format("%.4f", orbit.e), lineY, labelW, valueX);
      lineY += rowH;

      // True anomaly
      double trueAnomalyDeg = Math.toDegrees(orbit.getTrueAnomalyAtTime(simTime));
      trueAnomalyDeg = (trueAnomalyDeg + 360) % 360;
      drawInfoLine("True Anomaly:", String.format("%.1f°", trueAnomalyDeg), lineY, labelW, valueX);
      lineY += rowH;
    }

    // Current velocity
    double velMag = craft.stateVector.velocity.magnitude();
    drawInfoLine("Speed:", String.format("%.3f km/s", velMag), lineY, labelW, valueX);
    lineY += rowH;

    // Physics mode
    drawInfoLine("Mode:", craft.physicsMode.toString(), lineY, labelW, valueX);

    popStyle();
  }

  void drawInfoLine(String label, String value, float y, float labelW, float valueX) {
    fill(150, 160, 180);
    textAlign(LEFT, TOP);
    text(label, panelX + margin, y);
    fill(220, 230, 240);
    textAlign(RIGHT, TOP);
    text(value, valueX, y);
  }

  String formatDistance(double km) {
    if (Math.abs(km) >= 1e9) {
      return String.format("%.2f Gm", km / 1e9);
    } else if (Math.abs(km) >= 1e6) {
      return String.format("%.2f Mm", km / 1e6);
    } else if (Math.abs(km) >= 1000) {
      return String.format("%.1f Mm", km / 1000);
    } else {
      return String.format("%,d km", (int)km);
    }
  }

  String formatTime(double seconds) {
    if (seconds < 60) {
      return String.format("%.1f s", seconds);
    } else if (seconds < 3600) {
      return String.format("%.1f min", seconds / 60);
    } else if (seconds < 86400) {
      return String.format("%.2f h", seconds / 3600);
    } else {
      return String.format("%.2f days", seconds / 86400);
    }
  }
}
