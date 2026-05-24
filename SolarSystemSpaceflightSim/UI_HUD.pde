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
  DrawerPanel missionStatusDrawer;
  OrbitDrawerContent orbitContent;
  MissionStatusContent missionStatusContent;
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
      "MISSIONS",
      -65  // 垂直偏移，上移到视图按钮下方
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
      350  // 垂直偏移，按4个任务的任务面板长度排布
    );
    educationDrawer.expanded = true;  // 默认展开

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

    // 任务状态抽屉
    missionStatusContent = new MissionStatusContent();
    missionStatusDrawer = new DrawerPanel(
      DRAWER_BOTTOM,
      500,  // 基础宽度，updateTargetPositions 中会重新计算为屏幕一半
      0,
      missionStatusContent,
      "MISSION",
      0,
      false  // 不显示标签栏按钮
    );
    missionStatusDrawer.expanded = false;  // 默认折叠，会根据任务状态自动展开

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
    missionStatusDrawer.update();
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
    missionStatusDrawer.draw();
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
      textAlign(CENTER, TOP);
      text("PAUSED", width / 2, 120 * uiScale);
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

    if (showControlsHelp) {
      drawControlsHelpOverlay();
    }
  }

  void drawControlsHelpOverlay() {
    float scale = uiScale;
    pushStyle();

    noStroke();
    fill(0, 0, 0, 185);
    rect(0, 0, width, height);

    fill(255);
    textAlign(CENTER, TOP);
    textSize(28 * scale);
    text("CONTROLS", width / 2, 20 * scale);

    fill(170, 190, 220);
    textSize(14 * scale);
    text("Press ESC or click anywhere to close", width / 2, 56 * scale);

    float centerLeft = 300 * scale;
    float centerRight = width - 300 * scale;
    float centerW = centerRight - centerLeft;
    float leftMidX = centerLeft + 24 * scale;
    float rightMidX = centerRight - 374 * scale;

    float timeX = centerLeft + 40 * scale;
    float timeY = 130 * scale;
    drawHelpCard(timeX, timeY, 320 * scale, "TIME CONTROL", new String[]{
      "ESC / SPACE / P  Pause or resume",
      "Q / E  Change time warp",
      "RESTART / QUIT / HELP in pause menu"
    });
    drawHelpLine(timeX + 80 * scale, timeY, timePanel.getPauseCenterX(), timePanel.getPauseCenterY());
    drawHelpLine(timeX + 115 * scale, timeY, timePanel.getWarpDownCenterX(), timePanel.getWarpDownCenterY());
    drawHelpLine(timeX + 135 * scale, timeY, timePanel.getWarpUpCenterX(), timePanel.getWarpUpCenterY());

    float navX = leftMidX;
    float navY = min(height - 260 * scale, 610 * scale);
    drawHelpCard(navX, navY, 340 * scale, "MAP NAVIGATION", new String[]{
      "Mouse drag / wheel  Pan and zoom",
      "Double-click object  Focus target",
      "F  Snap camera focus"
    });

    float viewX = rightMidX;
    float viewY = 130 * scale;
    drawHelpCard(viewX, viewY, 360 * scale, "VIEW & MAP LAYERS", new String[]{
      "V  Switch map / ship view",
      "T  Toggle trajectory line",
      "AP/PE button  Toggle apsis markers",
      "O  Toggle orbital lines",
      "K  Toggle SOI boundaries"
    });
    drawHelpLine(viewX + 260 * scale, viewY, viewToggleButton.getX() + viewToggleButton.getW() / 2, viewToggleButton.getY() + viewToggleButton.getH() / 2);
    drawHelpLine(viewX + 240 * scale, viewY, trajIcon.getTooltipSourceX() + trajIcon.getTooltipSourceW() / 2, trajIcon.getTooltipSourceY() + trajIcon.getTooltipSourceH() / 2);
    drawHelpLine(viewX + 230 * scale, viewY, apsisIcon.getTooltipSourceX() + apsisIcon.getTooltipSourceW() / 2, apsisIcon.getTooltipSourceY() + apsisIcon.getTooltipSourceH() / 2);
    drawHelpLine(viewX + 220 * scale, viewY, orbitIcon.getTooltipSourceX() + orbitIcon.getTooltipSourceW() / 2, orbitIcon.getTooltipSourceY() + orbitIcon.getTooltipSourceH() / 2);
    drawHelpLine(viewX + 200 * scale, viewY, soiIcon.getTooltipSourceX() + soiIcon.getTooltipSourceW() / 2, soiIcon.getTooltipSourceY() + soiIcon.getTooltipSourceH() / 2);

    float leftDrawerX = leftMidX;
    float leftDrawerY = 350 * scale;
    drawHelpCard(leftDrawerX, leftDrawerY, 350 * scale, "LEFT DRAWERS", new String[]{
      "NAVIGATION  Focus planets or spacecraft",
      "ORBIT  Read orbit and spacecraft details",
      "Click side tabs to expand or collapse"
    });
    drawHelpLine(leftDrawerX, leftDrawerY + 45 * scale, navDrawer.toggleBtnX + navDrawer.toggleBtnWidth / 2, navDrawer.toggleBtnY + navDrawer.toggleBtnHeight / 2);
    drawHelpLine(leftDrawerX, leftDrawerY + 88 * scale, orbitDrawer.toggleBtnX + orbitDrawer.toggleBtnWidth / 2, orbitDrawer.toggleBtnY + orbitDrawer.toggleBtnHeight / 2);

    float rightDrawerX = rightMidX;
    float rightDrawerY = 350 * scale;
    drawHelpCard(rightDrawerX, rightDrawerY, 350 * scale, "RIGHT DRAWERS", new String[]{
      "MISSIONS  Select and start missions",
      "GUIDE  Read science and flight tips",
      "Use tabs to hide panels when needed"
    });
    drawHelpLine(rightDrawerX + 350 * scale, rightDrawerY + 45 * scale, taskDrawer.toggleBtnX + taskDrawer.toggleBtnWidth / 2, taskDrawer.toggleBtnY + taskDrawer.toggleBtnHeight / 2);
    drawHelpLine(rightDrawerX + 350 * scale, rightDrawerY + 88 * scale, educationDrawer.toggleBtnX + educationDrawer.toggleBtnWidth / 2, educationDrawer.toggleBtnY + educationDrawer.toggleBtnHeight / 2);

    float missionX = width / 2 - 220 * scale;
    float missionY = height - 170 * scale;
    drawHelpCard(missionX, missionY, 440 * scale, "MISSION STATUS", new String[]{
      "Bottom panel appears during mission execution",
      "Shows progress, phase, and important events"
    });
    drawHelpLine(missionX + 220 * scale, missionY + 96 * scale, width / 2, height - 36 * scale);

    popStyle();
  }

  void drawHelpCard(float x, float y, float w, String title, String[] lines) {
    float scale = uiScale;
    float lineH = 23 * scale;
    float h = 52 * scale + lines.length * lineH;

    pushStyle();
    fill(8, 10, 20, 225);
    stroke(120, 150, 190, 175);
    strokeWeight(1.5f * scale);
    rect(x, y, w, h, 10 * scale);

    fill(255);
    textAlign(LEFT, TOP);
    textSize(15 * scale);
    text(title, x + 18 * scale, y + 14 * scale);

    fill(220);
    textSize(13 * scale);
    for (int i = 0; i < lines.length; i++) {
      text(lines[i], x + 18 * scale, y + 42 * scale + i * lineH);
    }
    popStyle();
  }

  void drawHelpLine(float fromX, float fromY, float toX, float toY) {
    pushStyle();
    stroke(150, 180, 220, 145);
    strokeWeight(1.5f * uiScale);
    line(fromX, fromY, toX, toY);
    noStroke();
    fill(150, 180, 220, 180);
    ellipse(toX, toY, 6 * uiScale, 6 * uiScale);
    popStyle();
  }

  boolean handleMousePressed(float mx, float my, CameraController cam,
                             CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {
    if (showControlsHelp) {
      return true;
    }

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
    if (missionStatusDrawer.handleClick(mx, my)) {
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
