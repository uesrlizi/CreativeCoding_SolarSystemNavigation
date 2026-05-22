// ========== NAVIGATION DRAWER CONTENT ==========
class NavigationDrawerContent implements DrawerContent {
  NavigationFocusPanel panel;
  float currentDrawerX = 0;  // 保存抽屉当前X位置
  float currentDrawerY = 0;  // 保存抽屉当前Y位置
  float currentDrawerW = 0;  // 保存抽屉当前宽度

  NavigationDrawerContent() {
    panel = new NavigationFocusPanel();
  }

  public void updateContent(float drawerX, float drawerY, float drawerW) {
    // 更新时直接使用传入的抽屉位置，确保悬停检测坐标正确
    this.currentDrawerX = drawerX;
    this.currentDrawerY = drawerY;
    this.currentDrawerW = drawerW;

    float originalX = panel.panelX;
    float originalY = panel.panelY;
    float originalW = panel.panelW;
    panel.panelX = drawerX;
    panel.panelY = drawerY;
    panel.panelW = drawerW;
    panel.update();
    panel.panelX = originalX;
    panel.panelY = originalY;
    panel.panelW = originalW;
  }

  public void drawContent(float drawX, float drawY, float drawW, float drawH) {
    // 保存抽屉位置供 update 使用
    currentDrawerX = drawX;
    currentDrawerY = drawY;
    currentDrawerW = drawW;

    float originalX = panel.panelX;
    float originalY = panel.panelY;
    float originalW = panel.panelW;
    panel.panelX = drawX;
    panel.panelY = drawY;
    panel.panelW = drawW;  // 使用抽屉提供的宽度
    panel.draw(camera, solarSystem.sun, solarSystem.planets, solarSystem.ships);
    panel.panelX = originalX;
    panel.panelY = originalY;
    panel.panelW = originalW;
  }

  public boolean handleContentClick(float mx, float my, float contentX, float contentY, float contentW) {
    float originalX = panel.panelX;
    float originalY = panel.panelY;
    float originalW = panel.panelW;
    panel.panelX = contentX;
    panel.panelY = contentY;
    panel.panelW = contentW;  // 使用传入的抽屉宽度
    boolean result = panel.handleClick(mx, my, camera, solarSystem.sun, solarSystem.planets, solarSystem.ships);
    panel.panelX = originalX;
    panel.panelY = originalY;
    panel.panelW = originalW;
    return result;
  }

  public String getContentTooltip() {
    return panel.getHoveredTooltipText();
  }

  public float[] getContentTooltipSource() {
    // 确保返回的坐标是抽屉位置
    float[] original = panel.getTooltipSource();
    if (original != null && original.length == 4 && currentDrawerX != 0) {
      return new float[]{currentDrawerX, original[1], original[2], original[3]};
    }
    return original;
  }

  public float getContentHeight() {
    return panel.getPanelHeight();
  }

  public boolean shouldBeVisible() {
    return camera.getMode() == ViewMode.MAP_VIEW;
  }
}

// ========== HUD ==========

class HUD {
  TimeControlPanel timePanel;
  DrawerPanel navDrawer;
  DrawerPanel taskDrawer;
  DrawerPanel educationDrawer;
  DrawerPanel orbitDrawer;
  OrbitDrawerContent orbitContent;
  MissionStatus missionStatus;
  HeadingIndicator headingIndicator;
  OrbitalMinimap orbitalMinimap;
  Tooltip tooltip;
  String activeTooltipText;
  float tooltipSourceX, tooltipSourceY, tooltipSourceW, tooltipSourceH;

  ViewToggleButton viewToggleButton;
  TrajectoryIconButton trajIcon;
  ApsisIconButton apsisIcon;
  SOIIconButton soiIcon;
  OrbitIconButton orbitIcon;

  HUD() {
    viewToggleButton = new ViewToggleButton();
    timePanel = new TimeControlPanel();

    NavigationDrawerContent navContent = new NavigationDrawerContent();
    navDrawer = new DrawerPanel(
      DRAWER_LEFT,
      260,  // 与导航面板宽度一致
      40,
      navContent,
      "NAVIGATION"
    );
    navDrawer.expanded = true;

    TaskMenu taskMenu = new TaskMenu();
    taskMenu.refreshAvailablePresets();
    taskDrawer = new DrawerPanel(
      DRAWER_RIGHT,
      290,  // 与任务面板宽度一致
      40,
      taskMenu,
      "MISSIONS"
    );
    taskDrawer.expanded = true;

    // 科普提示面板
    EducationPanel educationPanel = new EducationPanel();
    educationDrawer = new DrawerPanel(
      DRAWER_RIGHT,
      290,  // 与任务面板宽度一致
      40,
      educationPanel,
      "GUIDE",
      380  // 垂直偏移，在任务面板下方
    );
    educationDrawer.expanded = false;  // 默认折叠

    orbitContent = new OrbitDrawerContent();
    orbitDrawer = new DrawerPanel(
      DRAWER_LEFT,
      220,  // 轨道信息面板宽度
      40,
      orbitContent,
      "ORBIT",
      550  // 垂直偏移，在导航抽屉下方
    );
    orbitDrawer.expanded = false;  // 默认折叠

    missionStatus = new MissionStatus();
    headingIndicator = new HeadingIndicator();
    orbitalMinimap = new OrbitalMinimap();
    tooltip = new Tooltip();
    activeTooltipText = null;

    createIcons();
  }

  void createIcons() {
    float scale = uiScale;
    float iconSize = 36 * scale;
    float gap = 8 * scale;
    float y = 10 * scale;

    // Position will be updated dynamically based on viewToggleButton
    trajIcon = new TrajectoryIconButton(0, y, iconSize);
    trajIcon.toggled = showTrajectory;

    apsisIcon = new ApsisIconButton(0, y, iconSize);
    apsisIcon.toggled = showApoapsis; // Use apoapsis as the toggle for both

    orbitIcon = new OrbitIconButton(0, y, iconSize);
    orbitIcon.toggled = showOrbits;

    soiIcon = new SOIIconButton(0, y, iconSize);
    soiIcon.toggled = showSOI;
  }

  void updateIconPositions() {
    float scale = uiScale;
    float iconSize = 36 * scale;
    float gap = 8 * scale;
    float y = 10 * scale;

    // Calculate position relative to viewToggleButton
    float viewToggleX = width - 175 * scale - 10 * scale;

    // Order from right to left: apsis, traj, orbit, soi
    float currentX = viewToggleX - iconSize - gap;
    apsisIcon.updatePosition(currentX, y);
    currentX -= iconSize + gap;
    trajIcon.updatePosition(currentX, y);
    currentX -= iconSize + gap;
    orbitIcon.updatePosition(currentX, y);
    currentX -= iconSize + gap;
    soiIcon.updatePosition(currentX, y);
  }

  void update() {
    viewToggleButton.update();
    timePanel.update();
    navDrawer.update();
    taskDrawer.update();
    educationDrawer.update();
    orbitDrawer.update();
    missionStatus.update();
    headingIndicator.update();
    orbitalMinimap.update();

    updateIconPositions();

    trajIcon.update(mouseX, mouseY, mousePressed);
    apsisIcon.update(mouseX, mouseY, mousePressed);
    orbitIcon.update(mouseX, mouseY, mousePressed);
    soiIcon.update(mouseX, mouseY, mousePressed);

    activeTooltipText = null;

    // Check view toggle button first (highest priority since it's top-right)
    if (activeTooltipText == null) {
      String viewToggleTip = viewToggleButton.getHoveredTooltipText();
      if (viewToggleTip != null) {
        activeTooltipText = viewToggleTip;
        tooltipSourceX = viewToggleButton.getX();
        tooltipSourceY = viewToggleButton.getY();
        tooltipSourceW = viewToggleButton.getW();
        tooltipSourceH = viewToggleButton.getH();
      }
    }

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
      String navToggleTip = navDrawer.getToggleButtonTooltip();
      if (navToggleTip != null) {
        activeTooltipText = navToggleTip;
        tooltipSourceX = navDrawer.toggleBtnX;
        tooltipSourceY = navDrawer.toggleBtnY;
        tooltipSourceW = navDrawer.toggleBtnWidth;
        tooltipSourceH = navDrawer.toggleBtnHeight;
      }
    }

    if (activeTooltipText == null && navDrawer.expanded) {
      String navTip = navDrawer.getContentTooltip();
      if (navTip != null) {
        activeTooltipText = navTip;
        float[] source = navDrawer.getContentTooltipSource();
        if (source != null && source.length == 4) {
          tooltipSourceX = source[0];
          tooltipSourceY = source[1];
          tooltipSourceW = source[2];
          tooltipSourceH = source[3];
        }
      }
    }

    if (activeTooltipText == null) {
      String taskToggleTip = taskDrawer.getToggleButtonTooltip();
      if (taskToggleTip != null) {
        activeTooltipText = taskToggleTip;
        tooltipSourceX = taskDrawer.toggleBtnX;
        tooltipSourceY = taskDrawer.toggleBtnY;
        tooltipSourceW = taskDrawer.toggleBtnWidth;
        tooltipSourceH = taskDrawer.toggleBtnHeight;
      }
    }

    if (activeTooltipText == null && taskDrawer.expanded) {
      String taskTip = taskDrawer.getContentTooltip();
      if (taskTip != null) {
        activeTooltipText = taskTip;
        float[] source = taskDrawer.getContentTooltipSource();
        if (source != null && source.length == 4) {
          tooltipSourceX = source[0];
          tooltipSourceY = source[1];
          tooltipSourceW = source[2];
          tooltipSourceH = source[3];
        }
      }
    }

    if (activeTooltipText == null) {
      String eduToggleTip = educationDrawer.getToggleButtonTooltip();
      if (eduToggleTip != null) {
        activeTooltipText = eduToggleTip;
        tooltipSourceX = educationDrawer.toggleBtnX;
        tooltipSourceY = educationDrawer.toggleBtnY;
        tooltipSourceW = educationDrawer.toggleBtnWidth;
        tooltipSourceH = educationDrawer.toggleBtnHeight;
      }
    }

    if (activeTooltipText == null && educationDrawer.expanded) {
      String eduTip = educationDrawer.getContentTooltip();
      if (eduTip != null) {
        activeTooltipText = eduTip;
        float[] source = educationDrawer.getContentTooltipSource();
        if (source != null && source.length == 4) {
          tooltipSourceX = source[0];
          tooltipSourceY = source[1];
          tooltipSourceW = source[2];
          tooltipSourceH = source[3];
        }
      }
    }

    if (activeTooltipText == null) {
      String orbitToggleTip = orbitDrawer.getToggleButtonTooltip();
      if (orbitToggleTip != null) {
        activeTooltipText = orbitToggleTip;
        tooltipSourceX = orbitDrawer.toggleBtnX;
        tooltipSourceY = orbitDrawer.toggleBtnY;
        tooltipSourceW = orbitDrawer.toggleBtnWidth;
        tooltipSourceH = orbitDrawer.toggleBtnHeight;
      }
    }

    if (activeTooltipText == null && orbitDrawer.expanded) {
      String orbitTip = orbitDrawer.getContentTooltip();
      if (orbitTip != null) {
        activeTooltipText = orbitTip;
        float[] source = orbitDrawer.getContentTooltipSource();
        if (source != null && source.length == 4) {
          tooltipSourceX = source[0];
          tooltipSourceY = source[1];
          tooltipSourceW = source[2];
          tooltipSourceH = source[3];
        }
      }
    }

    if (activeTooltipText == null) {
      if (trajIcon.shouldShowTooltip()) {
        activeTooltipText = trajIcon.getTooltipText();
        tooltipSourceX = trajIcon.getTooltipSourceX();
        tooltipSourceY = trajIcon.getTooltipSourceY();
        tooltipSourceW = trajIcon.getTooltipSourceW();
        tooltipSourceH = trajIcon.getTooltipSourceH();
      } else if (apsisIcon.shouldShowTooltip()) {
        activeTooltipText = apsisIcon.getTooltipText();
        tooltipSourceX = apsisIcon.getTooltipSourceX();
        tooltipSourceY = apsisIcon.getTooltipSourceY();
        tooltipSourceW = apsisIcon.getTooltipSourceW();
        tooltipSourceH = apsisIcon.getTooltipSourceH();
      } else if (orbitIcon.shouldShowTooltip()) {
        activeTooltipText = orbitIcon.getTooltipText();
        tooltipSourceX = orbitIcon.getTooltipSourceX();
        tooltipSourceY = orbitIcon.getTooltipSourceY();
        tooltipSourceW = orbitIcon.getTooltipSourceW();
        tooltipSourceH = orbitIcon.getTooltipSourceH();
      } else if (soiIcon.shouldShowTooltip()) {
        activeTooltipText = soiIcon.getTooltipText();
        tooltipSourceX = soiIcon.getTooltipSourceX();
        tooltipSourceY = soiIcon.getTooltipSourceY();
        tooltipSourceW = soiIcon.getTooltipSourceW();
        tooltipSourceH = soiIcon.getTooltipSourceH();
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
           int warpIndex, List<CelestialBody> planets, List<CelestialBody> moons, CelestialBody sun, List<Spacecraft> ships) {
    timePanel.draw(timeManager);
    navDrawer.draw();
    taskDrawer.draw();
    educationDrawer.draw();
    missionStatus.draw();
    viewToggleButton.draw();

    if (cam.getMode() == ViewMode.MAP_VIEW) {
      trajIcon.draw();
      apsisIcon.draw(trajIcon.toggled); // Only show as active when trajectory is on
      orbitIcon.draw();
      soiIcon.draw();
    }

    if (timeWarp == 0) {
      pushStyle();
      fill(255, 80, 80);
      textSize(30 * uiScale);
      textAlign(CENTER, CENTER);
      text("PAUSED", width / 2, height - 60);
      popStyle();
    }

    Spacecraft displayShip = null;
    if (cam.focusShip != null) {
      displayShip = cam.focusShip;
    } else if (cam.mode == ViewMode.SHIP_VIEW && cam.followTarget != null) {
      displayShip = cam.followTarget;
    } else if (ships != null && ships.size() > 0) {
      displayShip = ships.get(0);
    }

    orbitContent.setSpacecraft(displayShip, simTime);
    orbitDrawer.draw();

    if (displayShip != null) {
      orbitalMinimap.draw(displayShip, planets, moons, sun);
    }

    tooltip.draw();
  }

  boolean handleMousePressed(float mx, float my, CameraController cam,
                             CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {
    if (viewToggleButton.handleClick(cam, ships)) {
      return true;
    }
    if (navDrawer.handleClick(mx, my)) {
      return true;
    }
    if (taskDrawer.handleClick(mx, my)) {
      return true;
    }
    if (educationDrawer.handleClick(mx, my)) {
      return true;
    }
    if (orbitDrawer.handleClick(mx, my)) {
      return true;
    }

    if (cam.getMode() == ViewMode.MAP_VIEW) {
      if (trajIcon.handleClick(mx, my)) {
        showTrajectory = trajIcon.toggled;
        // 只更新显示状态，不改变用户的开关选择
        if (!showTrajectory) {
          showApoapsis = false;
          showPeriapsis = false;
        } else {
          // 恢复用户之前的选择
          showApoapsis = apsisIcon.toggled;
          showPeriapsis = apsisIcon.toggled;
        }
        return true;
      }
      if (apsisIcon.handleClick(mx, my)) {
        // Toggle both apoapsis and periapsis together - 始终允许用户改变选择状态
        boolean nowOn = apsisIcon.toggled;
        // 只在轨迹也开启时才实际显示
        showApoapsis = nowOn && trajIcon.toggled;
        showPeriapsis = nowOn && trajIcon.toggled;
        return true;
      }
      if (orbitIcon.handleClick(mx, my)) {
        showOrbits = orbitIcon.toggled;
        return true;
      }
      if (soiIcon.handleClick(mx, my)) {
        showSOI = soiIcon.toggled;
        return true;
      }
    }

    if (timePanel.handleClick()) {
      return true;
    }
    return false;
  }
}
