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
           int warpIndex, List<CelestialBody> planets, CelestialBody sun) {
    timePanel.draw(timeManager);
    navPanel.draw(cam, sun, planets);

    if (timeWarp == 0) {
      pushStyle();
      fill(255, 80, 80);
      textSize(30 * uiScale);
      textAlign(CENTER, CENTER);
      text("PAUSED", width / 2, height - 60);
      popStyle();
    }

    tooltip.draw();
  }

  boolean handleMousePressed(float mx, float my, CameraController cam,
                             CelestialBody sun, List<CelestialBody> planets) {
    if (navPanel.handleClick(mx, my, cam, sun, planets)) {
      return true;
    }
    if (timePanel.handleClick()) {
      return true;
    }
    return false;
  }
}
