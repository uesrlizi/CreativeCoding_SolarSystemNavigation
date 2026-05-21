// ========== ORBIT DISPLAY ==========

class OrbitDrawerContent implements DrawerContent {
  OrbitDisplay orbitDisplay;
  Spacecraft currentCraft;
  double currentSimTime;

  OrbitDrawerContent() {
    orbitDisplay = new OrbitDisplay();
  }

  public void updateContent(float drawerX, float drawerY, float drawerW) {
    orbitDisplay.update(drawerX, drawerY, drawerW);
  }

  public void drawContent(float drawX, float drawY, float drawW, float drawH) {
    orbitDisplay.draw(currentCraft, currentSimTime, drawX, drawY, drawW, drawH);
  }

  public boolean handleContentClick(float mx, float my, float contentX, float contentY, float contentW) {
    return false;
  }

  public String getContentTooltip() {
    return null;
  }

  public float[] getContentTooltipSource() {
    return null;
  }

  public float getContentHeight() {
    return orbitDisplay.getContentHeight();
  }

  public boolean shouldBeVisible() {
    return true;
  }

  void setSpacecraft(Spacecraft craft, double simTime) {
    this.currentCraft = craft;
    this.currentSimTime = simTime;
  }
}

class OrbitDisplay {
  float panelX, panelY, panelW, panelH;
  float margin;
  float rowH;
  float contentHeight;

  OrbitDisplay() {
    float scale = uiScale;
    panelW = 220 * scale;
    margin = 12 * scale;
    rowH = 20 * scale;
    contentHeight = 260 * scale;
  }

  void update() {
    // 保留旧接口，用于兼容
  }

  void update(float drawerX, float drawerY, float drawerW) {
    float scale = uiScale;
    panelW = drawerW;
    margin = 12 * scale;
    rowH = 20 * scale;
    contentHeight = 260 * scale;
  }

  float getContentHeight() {
    float scale = uiScale;
    return 260 * scale - 36 * scale;  // 减去标题和分隔线的高度
  }

  void draw(Spacecraft craft, double simTime) {
    // 保留旧接口
  }

  void draw(Spacecraft craft, double simTime, float drawX, float drawY, float drawW, float drawH) {
    if (craft == null) return;

    pushStyle();
    float scale = uiScale;

    // Panel background
    noStroke();
    fill(10, 15, 30, 200);
    rect(drawX, drawY, drawW, drawH, 8 * scale);

    float lineY = drawY + margin;
    float labelW = 100 * scale;
    float valueX = drawX + drawW - margin;

    // Info text style
    textSize(12 * scale);

    // Reference body
    if (craft.referenceBody != null) {
      drawInfoLine("Orbiting:", craft.referenceBody.name, lineY, labelW, valueX, drawX, margin);
      lineY += rowH;
    }

    if (craft.orbit != null) {
      Orbit orbit = craft.orbit;

      // Apoapsis
      double apoAlt = orbit.getApoapsisAltitude();
      drawInfoLine("Apoapsis:", formatDistance(apoAlt), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;

      // Periapsis
      double periAlt = orbit.getPeriapsisAltitude();
      drawInfoLine("Periapsis:", formatDistance(periAlt), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;

      // Time to Apoapsis
      double timeToApo = orbit.getTimeToApoapsis(simTime);
      drawInfoLine("T to Apo:", formatTime(timeToApo), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;

      // Time to Periapsis
      double timeToPeri = orbit.getTimeToPeriapsis(simTime);
      drawInfoLine("T to Peri:", formatTime(timeToPeri), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;

      // Period
      drawInfoLine("Orbit Period:", formatTime(orbit.period), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;

      // Semi-major axis
      drawInfoLine("Semi-major:", formatDistance(orbit.a), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;

      // Eccentricity
      drawInfoLine("Eccentricity:", String.format("%.4f", orbit.e), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;

      // True anomaly
      double trueAnomalyDeg = Math.toDegrees(orbit.getTrueAnomalyAtTime(simTime));
      trueAnomalyDeg = (trueAnomalyDeg + 360) % 360;
      drawInfoLine("True Anomaly:", String.format("%.1f°", trueAnomalyDeg), lineY, labelW, valueX, drawX, margin);
      lineY += rowH;
    }

    // Current velocity
    double velMag = craft.stateVector.velocity.magnitude();
    drawInfoLine("Speed:", String.format("%.3f km/s", velMag), lineY, labelW, valueX, drawX, margin);
    lineY += rowH;

    // Physics mode
    drawInfoLine("Mode:", craft.physicsMode.toString(), lineY, labelW, valueX, drawX, margin);

    popStyle();
  }

  void drawInfoLine(String label, String value, float y, float labelW, float valueX, float panelX, float margin) {
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
