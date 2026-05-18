// ========== HUD ==========

class HUD {
  TimeControlPanel timePanel;
  NavigationFocusPanel navPanel;
  Tooltip tooltip;
  String activeTooltipText;
  float tooltipSourceX, tooltipSourceY, tooltipSourceW, tooltipSourceH;

  HUD() {
    timePanel = new TimeControlPanel();
    navPanel = new NavigationFocusPanel();
    tooltip = new Tooltip();
    activeTooltipText = null;
  }

  void update() {
    timePanel.update();
    navPanel.update();

    activeTooltipText = null;

    ArrayList<Button> timeButtons = timePanel.getAllButtons();
    for (Button b : timeButtons) {
      if (b.shouldShowTooltip()) {
        activeTooltipText = b.getTooltipText();
        tooltipSourceX = b.x;
        tooltipSourceY = b.y;
        tooltipSourceW = b.w;
        tooltipSourceH = b.h;
        break;
      }
    }

    if (activeTooltipText == null) {
      String navTip = navPanel.getHoveredTooltipText();
      if (navTip != null) {
        activeTooltipText = navTip;
        tooltipSourceX = navPanel.panelX;
        tooltipSourceY = navPanel.panelY;
        tooltipSourceW = navPanel.panelW;
        tooltipSourceH = navPanel.panelH;
      }
    }

    if (activeTooltipText != null) {
      tooltip.show(activeTooltipText, "", tooltipSourceX, tooltipSourceY,
                  tooltipSourceW, tooltipSourceH);
    } else {
      tooltip.hide();
    }
  }

  void draw(CameraController cam, double simTime, double timeWarp,
           double[] WARP_LEVELS, String[] WARP_LABELS,
           int warpIndex, List<CelestialBody> planets, CelestialBody sun, List<Spacecraft> ships) {
    timePanel.draw(timeManager);
    navPanel.draw(cam, sun, planets, ships);

    if (timeWarp == 0) {
      pushStyle();
      fill(255, 80, 80);
      textSize(30 * uiScale);
      textAlign(CENTER, CENTER);
      text("PAUSED", width / 2, height - 60);
      popStyle();
    }

    // 显示聚焦的航天器信息
    if (cam.focusShip != null) {
      drawSpacecraftInfo(cam.focusShip);
    } else if (cam.mode == ViewMode.SHIP_VIEW && cam.followTarget != null) {
      drawSpacecraftInfo(cam.followTarget);
    }

    tooltip.draw();
  }

  void drawSpacecraftInfo(Spacecraft craft) {
    float panelX = width - 320 * uiScale;
    float panelY = 120 * uiScale;
    float panelW = 300 * uiScale;
    float panelH = 180 * uiScale;

    // Panel background
    noStroke();
    fill(10, 15, 30, 200);
    rect(panelX, panelY, panelW, panelH, 8 * uiScale);

    // Title
    fill(255, 200, 100);
    textSize(18 * uiScale);
    textAlign(LEFT, TOP);
    text(craft.name, panelX + 15 * uiScale, panelY + 12 * uiScale);

    // Divider
    stroke(100, 120, 180, 100);
    strokeWeight(1 * uiScale);
    line(panelX + 15 * uiScale, panelY + 42 * uiScale, panelX + panelW - 15 * uiScale, panelY + 42 * uiScale);
    noStroke();

    // Info
    fill(220, 230, 240);
    textSize(13 * uiScale);
    float lineY = panelY + 55 * uiScale;
    float lineSpacing = 20 * uiScale;

    if (craft.currentCentralBody != null) {
      text("Orbiting: " + craft.currentCentralBody.name, panelX + 15 * uiScale, lineY);
      lineY += lineSpacing;
    }

    if (craft.a > 0) {
      // Apoapsis and Periapsis
      double apoapsis = craft.a * (1 + craft.e) - EARTH_RADIUS_KM;
      double periapsis = craft.a * (1 - craft.e) - EARTH_RADIUS_KM;
      text(String.format("Apoapsis: %,d km", (int)apoapsis), panelX + 15 * uiScale, lineY);
      lineY += lineSpacing;
      text(String.format("Periapsis: %,d km", (int)periapsis), panelX + 15 * uiScale, lineY);
      lineY += lineSpacing;
      // Period
      double periodHours = craft.period / 3600.0;
      text(String.format("Orbit Period: %.1f h", periodHours), panelX + 15 * uiScale, lineY);
      lineY += lineSpacing;
    }

    // Velocity
    double velMag = Math.sqrt(craft.vel[0]*craft.vel[0] + craft.vel[1]*craft.vel[1] + craft.vel[2]*craft.vel[2]);
    text(String.format("Speed: %.1f km/s", velMag), panelX + 15 * uiScale, lineY);
    lineY += lineSpacing;

    // Physics mode
    text("Mode: On-rails", panelX + 15 * uiScale, lineY);
  }

  boolean handleMousePressed(float mx, float my, CameraController cam,
                             CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {
    if (navPanel.handleClick(mx, my, cam, sun, planets, ships)) {
      return true;
    }
    if (timePanel.handleClick()) {
      return true;
    }
    return false;
  }
}
