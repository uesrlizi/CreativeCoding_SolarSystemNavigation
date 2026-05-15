// ============================================================
//  HUD 总控
// ============================================================
class HUD {
  TimeControlPanel timePanel;
  NavigationFocusPanel navPanel;
  ViewToggleButton viewToggle;
  ShipStatusPanel shipPanel;
  Tooltip tooltip;
  String activeTooltipText;
  float tooltipSourceX, tooltipSourceY, tooltipSourceW, tooltipSourceH;

  HUD() {
    timePanel = new TimeControlPanel();
    navPanel = new NavigationFocusPanel();
    viewToggle = new ViewToggleButton();
    shipPanel = new ShipStatusPanel();
    tooltip = new Tooltip();
    activeTooltipText = null;
  }

  void update() {
    timePanel.update();
    navPanel.update();
    viewToggle.update();
    shipPanel.update();

    // 检查所有按钮，看谁需要 tooltip
    activeTooltipText = null;

    // 时间面板按钮
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

    // 导航面板 hover
    if (activeTooltipText == null) {
      String navTip = navPanel.getHoveredTooltipText();
      if (navTip != null) {
        activeTooltipText = navTip;
        // 用面板位置
        tooltipSourceX = navPanel.panelX;
        tooltipSourceY = navPanel.panelY;
        tooltipSourceW = navPanel.panelW;
        tooltipSourceH = navPanel.panelH;
      }
    }

    // 视图切换按钮
    if (activeTooltipText == null) {
      String viewTip = viewToggle.getHoveredTooltipText();
      if (viewTip != null) {
        activeTooltipText = viewTip;
        tooltipSourceX = viewToggle.getX();
        tooltipSourceY = viewToggle.getY();
        tooltipSourceW = viewToggle.getW();
        tooltipSourceH = viewToggle.getH();
      }
    }

    // 飞船状态面板
    if (activeTooltipText == null) {
      String shipTip = shipPanel.getHoveredTooltipText();
      if (shipTip != null) {
        activeTooltipText = shipTip;
        ArrayList<Button> shipButtons = shipPanel.getAllButtons();
        if (shipButtons.size() > 0) {
          Button b = shipButtons.get(0);
          tooltipSourceX = b.x;
          tooltipSourceY = b.y;
          tooltipSourceW = b.w;
          tooltipSourceH = b.h;
        } else {
          tooltipSourceX = shipPanel.panelX;
          tooltipSourceY = shipPanel.panelY;
          tooltipSourceW = shipPanel.panelW;
          tooltipSourceH = shipPanel.panelH;
        }
      }
    }

    // 更新 tooltip
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
    // 绘制四个面板
    timePanel.draw(timeManager);
    navPanel.draw(cam, sun, planets, solarSystem.ships);
    viewToggle.draw();

    Spacecraft ship = launchController.getCurrentShip();
    CelestialBody earth = launchController.getEarth();
    if (ship != null) {
      shipPanel.draw(launchController, ship, earth, planets);
    }

    // 暂停指示器（全屏居中下方）
    if (timeWarp == 0) {
      pushStyle();
      fill(255, 80, 80);
      textSize(30 * uiScale);
      textAlign(CENTER, CENTER);
      text("PAUSED", width / 2, height - 60);
      popStyle();
    }

    // Tooltip（在最上层）
    tooltip.draw();
  }

  boolean handleMousePressed(float mx, float my, CameraController cam,
                             CelestialBody sun, List<CelestialBody> planets) {
    // 点击优先级：上层面板优先
    Spacecraft ship = launchController.getCurrentShip();
    if (ship != null && shipPanel.handleClick(mx, my, launchController, planets)) {
      return true;
    }
    if (navPanel.handleClick(mx, my, cam, sun, planets, solarSystem.ships)) {
      return true;
    }
    if (viewToggle.handleClick(cam)) {
      return true;
    }
    if (timePanel.handleClick()) {
      return true;
    }
    return false;
  }
}
