// ========== HUD ==========

class HUD {
  TimeControlPanel timePanel;
  NavigationFocusPanel navPanel;
  TaskMenu taskMenu;
  MissionStatus missionStatus;
  HeadingIndicator headingIndicator;
  OrbitalMinimap orbitalMinimap;
  OrbitDisplay orbitDisplay;
  Tooltip tooltip;
  String activeTooltipText;
  float tooltipSourceX, tooltipSourceY, tooltipSourceW, tooltipSourceH;

  Button taskButton;
  Button trajButton;
  Button apoButton;
  Button periButton;

  HUD() {
    timePanel = new TimeControlPanel();
    navPanel = new NavigationFocusPanel();
    taskMenu = new TaskMenu();
    missionStatus = new MissionStatus();
    headingIndicator = new HeadingIndicator();
    orbitalMinimap = new OrbitalMinimap();
    orbitDisplay = new OrbitDisplay();
    tooltip = new Tooltip();
    activeTooltipText = null;

    createButtons();
  }

  void createButtons() {
    float scale = uiScale;
    float navPanelBottom = 120 + (42 + (9 + 1 + 1) * 26 + 36); // 估算导航面板高度
    float startY = (navPanelBottom + 20) * scale;
    float btnW = 270 * scale; // 和导航面板同宽
    float btnH = 26 * scale;
    float gap = 6 * scale;
    float x = 10 * scale;

    taskButton = new Button(x, startY, btnW, btnH, "Select Mission", "Open mission menu [M]");
    trajButton = new Button(x, startY + (btnH + gap), btnW, btnH, "Show Trajectory", "Toggle trajectory line [T]");
    apoButton = new Button(x, startY + (btnH + gap) * 2, btnW, btnH, "Show Apoapsis", "Toggle apoapsis markers");
    periButton = new Button(x, startY + (btnH + gap) * 3, btnW, btnH, "Show Periapsis", "Toggle periapsis markers");

    trajButton.setToggle(true);
    trajButton.setToggled(showTrajectory);
    apoButton.setToggle(true);
    apoButton.setToggled(showApoapsis);
    periButton.setToggle(true);
    periButton.setToggled(showPeriapsis);
  }

  void update() {
    timePanel.update();
    navPanel.update();
    taskMenu.update();
    missionStatus.update();
    headingIndicator.update();
    orbitalMinimap.update();
    orbitDisplay.update();

    if (taskButton != null) {
      taskButton.update(mouseX, mouseY, mousePressed);
      trajButton.update(mouseX, mouseY, mousePressed);
      apoButton.update(mouseX, mouseY, mousePressed);
      periButton.update(mouseX, mouseY, mousePressed);
    } else {
      createButtons();
    }

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

    if (activeTooltipText == null) {
      String taskTip = taskMenu.getHoveredTooltipText();
      if (taskTip != null) {
        activeTooltipText = taskTip;
      }
    }

    if (activeTooltipText == null) {
      if (taskButton.shouldShowTooltip()) activeTooltipText = taskButton.getTooltipText();
      else if (trajButton.shouldShowTooltip()) activeTooltipText = trajButton.getTooltipText();
      else if (apoButton.shouldShowTooltip()) activeTooltipText = apoButton.getTooltipText();
      else if (periButton.shouldShowTooltip()) activeTooltipText = periButton.getTooltipText();
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
    navPanel.draw(cam, sun, planets, ships);
    taskMenu.draw();
    missionStatus.draw();

    if (cam.getMode() == ViewMode.MAP_VIEW) {
      taskButton.draw();
      trajButton.draw();
      apoButton.draw();
      periButton.draw();
    }

    if (timeWarp == 0) {
      pushStyle();
      fill(255, 80, 80);
      textSize(30 * uiScale);
      textAlign(CENTER, CENTER);
      text("PAUSED", width / 2, height - 60);
      popStyle();
    }

    // 显示聚焦的航天器信息
    Spacecraft displayShip = null;
    if (cam.focusShip != null) {
      displayShip = cam.focusShip;
    } else if (cam.mode == ViewMode.SHIP_VIEW && cam.followTarget != null) {
      displayShip = cam.followTarget;
    } else if (ships != null && ships.size() > 0) {
      displayShip = ships.get(0);
    }

    if (displayShip != null) {
      orbitDisplay.draw(displayShip, simTime);
      orbitalMinimap.draw(displayShip, planets, moons, sun);
      // headingIndicator.draw(displayShip);
    }

    tooltip.draw();
  }

  boolean handleMousePressed(float mx, float my, CameraController cam,
                             CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {
    if (taskMenu.handleClick(mx, my)) {
      return true;
    }

    if (cam.getMode() == ViewMode.MAP_VIEW) {
      if (taskButton.handleClick(mx, my)) {
        taskMenu.toggle();
        return true;
      }
      if (trajButton.handleClick(mx, my)) {
        showTrajectory = !showTrajectory;
        trajButton.setToggled(showTrajectory);
        return true;
      }
      if (apoButton.handleClick(mx, my)) {
        showApoapsis = !showApoapsis;
        apoButton.setToggled(showApoapsis);
        return true;
      }
      if (periButton.handleClick(mx, my)) {
        showPeriapsis = !showPeriapsis;
        periButton.setToggled(showPeriapsis);
        return true;
      }
    }

    if (navPanel.handleClick(mx, my, cam, sun, planets, ships)) {
      return true;
    }
    if (timePanel.handleClick()) {
      return true;
    }
    return false;
  }
}
