// ========== TUTORIAL STEP ENUM ==========
enum TutorialStep {
  INTRO,                  // 询问是否进入教程
  SHOW_CONTROLS_HELP,    // 介绍操作提示按钮
  PAN_ZOOM,              // 视图平移缩放（允许操作）
  SWITCH_TO_SHIP_VIEW,   // 切换到飞船视图（需点击按钮）
  TRANSITION_AFTER_VIEW, // 点击视图按钮后的过渡等待
  OPEN_TASK_PANEL,       // 打开任务面板（需点击标签）
  INTRO_EDU_PANEL,       // 介绍科普面板
  START_MISSION,         // 开始发射任务
  COMPLETED              // 完成
}

// ========== TUTORIAL SYSTEM ==========
class TutorialSystem {
  boolean active;
  TutorialStep currentStep;

  Button yesButton, noButton, nextButton;
  HUD hud; // Reference to HUD for UI positions

  int transitionStartTime;
  static final int TRANSITION_DURATION = 1000; // 1 second in ms

  TutorialSystem() {
    this.active = true;
    this.currentStep = TutorialStep.INTRO;
    createButtons();
  }

  void setHUD(HUD h) {
    hud = h;
  }

  void createButtons() {
    float scale = uiScale;

    yesButton = new Button(0, 0, 120 * scale, 40 * scale, "Start", "Start tutorial");
    noButton = new Button(0, 0, 120 * scale, 40 * scale, "Skip", "Skip tutorial");
    nextButton = new Button(0, 0, 100 * scale, 40 * scale, "Next", "Next step");

    // Set default dark blue colors for tutorial buttons
    setButtonDarkBlue(yesButton);
    setButtonDarkBlue(noButton);
    setButtonDarkBlue(nextButton);
  }

  void setButtonDarkBlue(Button btn) {
    btn.normalBg = color(20, 40, 80, 180);
    btn.hoverBg = color(30, 60, 120, 200);
    btn.pressedBg = color(40, 80, 150, 220);
  }

  void update() {
    if (!active) return;

    yesButton.update();
    noButton.update();
    nextButton.update();

    // Handle transition after view button
    if (currentStep == TutorialStep.TRANSITION_AFTER_VIEW) {
      if (millis() - transitionStartTime >= TRANSITION_DURATION) {
        currentStep = TutorialStep.OPEN_TASK_PANEL;
      }
    }
  }

  // Get view toggle button bounds from HUD (using live HUD data)
  float[] getViewToggleBounds() {
    if (hud != null) {
      float x = hud.viewToggleButton.getX();
      float y = hud.viewToggleButton.getY();
      float w = hud.viewToggleButton.getW();
      float h = hud.viewToggleButton.getH();
      return new float[]{x, y, w, h};
    }
    // Fallback if HUD not available
    float scale = uiScale;
    float x = width - 175 * scale;
    float y = 10 * scale;
    float w = 165 * scale;
    float h = 40 * scale;
    return new float[]{x, y, w, h};
  }

  // Get task panel tab bounds from HUD (using live HUD data)
  float[] getTaskPanelTabBounds() {
    if (hud != null) {
      hud.taskDrawer.updateToggleButtonPosition(); // Ensure position is updated
      float x = hud.taskDrawer.toggleBtnX;
      float y = hud.taskDrawer.toggleBtnY;
      float w = hud.taskDrawer.toggleBtnWidth;
      float h = hud.taskDrawer.toggleBtnHeight;
      return new float[]{x, y, w, h};
    }
    // Fallback if HUD not available
    float scale = uiScale;
    float x = width - 40 * scale;
    float y = 120 * scale - 65 * scale;
    float w = 36 * scale;
    float h = 120 * scale;
    return new float[]{x, y, w, h};
  }

  // Get education panel tab bounds from HUD (using live HUD data)
  float[] getEduPanelTabBounds() {
    if (hud != null) {
      hud.educationDrawer.updateToggleButtonPosition(); // Ensure position is updated
      float x = hud.educationDrawer.toggleBtnX;
      float y = hud.educationDrawer.toggleBtnY;
      float w = hud.educationDrawer.toggleBtnWidth;
      float h = hud.educationDrawer.toggleBtnHeight;
      return new float[]{x, y, w, h};
    }
    // Fallback if HUD not available
    float scale = uiScale;
    float x = width - 40 * scale;
    float y = 120 * scale + 520 * scale;
    float w = 36 * scale;
    float h = 120 * scale;
    return new float[]{x, y, w, h};
  }

  // Get HELP button bounds from time panel (using live HUD data)
  float[] getHelpButtonBounds() {
    if (hud != null) {
      Button helpBtn = hud.timePanel.helpButton;
      float x = helpBtn.x;
      float y = helpBtn.y;
      float w = helpBtn.w;
      float h = helpBtn.h;
      return new float[]{x, y, w, h};
    }
    // Fallback
    float scale = uiScale;
    float x = width / 2;
    float y = 50 * scale;
    float w = 90 * scale;
    float h = 36 * scale;
    return new float[]{x, y, w, h};
  }

  // Get START button bounds from task menu (using live HUD data)
  float[] getStartButtonBounds() {
    if (hud != null) {
      float scale = uiScale;
      // Get task drawer position
      DrawerPanel taskDrawer = hud.taskDrawer;
      taskDrawer.update(); // Ensure drawer position is updated

      // Get actual panel position from taskMenu
      TaskMenu taskMenu = (TaskMenu)taskDrawer.content;
      float panelX = taskMenu.currentDrawerX != 0 ? taskMenu.currentDrawerX : taskDrawer.expandedPosition;
      float panelY = taskMenu.currentDrawerY != 0 ? taskMenu.currentDrawerY : (120 * scale - 65 * scale);
      float panelW = taskMenu.currentDrawerW != 0 ? taskMenu.currentDrawerW : 290;

      // Calculate START button position similar to TaskMenu
      int presetCount = (taskMenu.availablePresets != null) ? taskMenu.availablePresets.size() : 0;
      float headerH = 48 * scale;
      float rowH = 32 * scale;
      float detailH = 140 * scale;

      float footerY = panelY + headerH + presetCount * rowH + detailH;
      float btnX = panelX + panelW - 100 * scale;
      float btnY = footerY + 15 * scale;
      float btnW = 80 * scale;
      float btnH = 32 * scale;

      return new float[]{btnX, btnY, btnW, btnH};
    }
    // Fallback
    float scale = uiScale;
    float x = width - 150 * scale;
    float y = height * 0.45f;
    float w = 80 * scale;
    float h = 32 * scale;
    return new float[]{x, y, w, h};
  }

  boolean isClickInBounds(float mx, float my, float[] bounds) {
    return mx >= bounds[0] && mx <= bounds[0] + bounds[2] &&
           my >= bounds[1] && my <= bounds[1] + bounds[3];
  }

  boolean handleClick(float mx, float my) {
    if (!active) return false;

    // INTRO step
    if (currentStep == TutorialStep.INTRO) {
      if (yesButton.handleClick(mx, my)) {
        currentStep = TutorialStep.SHOW_CONTROLS_HELP;
        return true;
      }
      if (noButton.handleClick(mx, my)) {
        active = false;
        return true;
      }
      return true;
    }


    // SHOW_CONTROLS_HELP - use Next or click anywhere
    if (currentStep == TutorialStep.SHOW_CONTROLS_HELP) {
      nextButton.handleClick(mx, my); // Still call for hover effects
      currentStep = TutorialStep.PAN_ZOOM;
      return true;
    }

    // PAN_ZOOM - use Next after playing
    if (currentStep == TutorialStep.PAN_ZOOM) {
      if (nextButton.handleClick(mx, my)) {
        currentStep = TutorialStep.SWITCH_TO_SHIP_VIEW;
        return true;
      }
      // Check if click is in the UI areas - block those
      float scale = uiScale;
      float leftWidth = 300 * scale;
      float rightWidth = 330 * scale;
      float topHeight = 120 * scale;
      if (mx < leftWidth || mx > width - rightWidth || my < topHeight) {
        return true; // Block clicks on left/right/top UI areas
      }
      return false; // Let camera handle clicks in the middle area
    }

    // SWITCH_TO_SHIP_VIEW - must click view toggle
    if (currentStep == TutorialStep.SWITCH_TO_SHIP_VIEW) {
      if (isClickInBounds(mx, my, getViewToggleBounds())) {
        currentStep = TutorialStep.TRANSITION_AFTER_VIEW;
        transitionStartTime = millis();
        return false; // Let HUD handle the click
      }
      return true;
    }

    // TRANSITION_AFTER_VIEW - block input but don't draw anything
    if (currentStep == TutorialStep.TRANSITION_AFTER_VIEW) {
      return true; // Block all input
    }

    // OPEN_TASK_PANEL - use Next or click anywhere
    if (currentStep == TutorialStep.OPEN_TASK_PANEL) {
      nextButton.handleClick(mx, my); // Still call for hover effects
      currentStep = TutorialStep.INTRO_EDU_PANEL;
      return true;
    }

    // INTRO_EDU_PANEL - use Next or click anywhere
    if (currentStep == TutorialStep.INTRO_EDU_PANEL) {
      nextButton.handleClick(mx, my); // Still call for hover effects
      currentStep = TutorialStep.START_MISSION;
      return true;
    }

    // START_MISSION - must click START button
    if (currentStep == TutorialStep.START_MISSION) {
      if (isClickInBounds(mx, my, getStartButtonBounds())) {
        active = false; // End tutorial directly
        return false; // Let HUD handle the click
      }
      return true;
    }

    return true;
  }

  // Check if we should block mouse drag/scroll
  boolean shouldBlockCameraInput() {
    if (!active) return false;
    // Only PAN_ZOOM step allows camera input
    return currentStep != TutorialStep.PAN_ZOOM;
  }

  void draw() {
    if (!active) return;

    pushStyle();

    // Draw spotlight mask (except for steps that don't need it)
    if (currentStep != TutorialStep.INTRO &&
        currentStep != TutorialStep.PAN_ZOOM &&
        currentStep != TutorialStep.TRANSITION_AFTER_VIEW) {
      drawSpotlightMask();
    } else if (currentStep == TutorialStep.INTRO) {
      // Full mask for INTRO
      noStroke();
      fill(0, 0, 0, 180);
      rect(0, 0, width, height);
    }

    switch (currentStep) {
      case INTRO:
        drawIntro();
        break;
      case SHOW_CONTROLS_HELP:
        drawShowControlsHelp();
        break;
      case PAN_ZOOM:
        drawPanZoom();
        break;
      case SWITCH_TO_SHIP_VIEW:
        drawSwitchToShipView();
        break;
      case TRANSITION_AFTER_VIEW:
        // Do nothing - no mask, no UI, just block input
        break;
      case OPEN_TASK_PANEL:
        drawOpenTaskPanel();
        break;
      case INTRO_EDU_PANEL:
        drawIntroEduPanel();
        break;
      case START_MISSION:
        drawStartMission();
        break;
      case COMPLETED:
        break;
    }

    popStyle();
  }

  // Draw spotlight mask - darken everything except target area
  void drawSpotlightMask() {
    float scale = uiScale;

    // Handle special cases first (full panels)
    if (currentStep == TutorialStep.OPEN_TASK_PANEL && hud != null) {
      // Show entire task panel including tab
      DrawerPanel drawer = hud.taskDrawer;
      drawer.update(); // Full update to get correct positions
      float tabX = drawer.toggleBtnX;
      float panelX = drawer.expandedPosition;
      float panelY = 120 * scale - 65 * scale;
      float panelW = 290 * scale;
      float contentH = drawer.content.getContentHeight();

      // Combine tab and panel into one hole
      float holeX = tabX;
      float holeY = panelY;
      float holeW = (panelX + panelW) - tabX + 10 * scale;
      float holeH = contentH + 20 * scale;
      drawMaskWithHole(holeX, holeY, holeW, holeH);
      return;
    }

    if (currentStep == TutorialStep.INTRO_EDU_PANEL && hud != null) {
      // Show entire education panel including tab
      DrawerPanel drawer = hud.educationDrawer;
      drawer.update(); // Full update to get correct positions
      float tabX = drawer.toggleBtnX;
      float tabY = drawer.toggleBtnY;
      float panelX = drawer.expandedPosition;
      float panelY = 120 * scale + 520 * scale;
      float panelW = 290 * scale;
      float contentH = drawer.content.getContentHeight();

      // Combine tab and panel into one hole
      float holeX = tabX;
      float holeY = tabY - 10 * scale; // Start from tab top
      float holeW = (panelX + panelW) - tabX + 10 * scale;
      float holeH = (panelY + contentH) - holeY + 20 * scale;
      drawMaskWithHole(holeX, holeY, holeW, holeH);
      return;
    }

    // Regular cases - just the button
    float[] spotlightBounds = null;
    switch (currentStep) {
      case SHOW_CONTROLS_HELP:
        spotlightBounds = getHelpButtonBounds();
        break;
      case SWITCH_TO_SHIP_VIEW:
        spotlightBounds = getViewToggleBounds();
        break;
      case START_MISSION:
        spotlightBounds = getStartButtonBounds();
        break;
      default:
        break;
    }

    if (spotlightBounds != null) {
      float padding = 10 * scale;
      float x = spotlightBounds[0] - padding;
      float y = spotlightBounds[1] - padding;
      float w = spotlightBounds[2] + padding * 2;
      float h = spotlightBounds[3] + padding * 2;
      drawMaskWithHole(x, y, w, h);
    } else {
      // Fallback to full mask
      noStroke();
      fill(0, 0, 0, 180);
      rect(0, 0, width, height);
    }
  }

  // Helper to draw mask with a rectangular hole
  void drawMaskWithHole(float x, float y, float w, float h) {
    noStroke();
    fill(0, 0, 0, 180);

    // Top rectangle (above hole)
    rect(0, 0, width, y);
    // Bottom rectangle (below hole)
    rect(0, y + h, width, height - (y + h));
    // Left rectangle (left of hole)
    rect(0, y, x, h);
    // Right rectangle (right of hole)
    rect(x + w, y, width - (x + w), h);
  }

  void drawIntro() {
    float scale = uiScale;

    float cardW = 460 * scale;
    float cardX = width / 2 - cardW / 2;
    float cardY = height / 2 - 160 * scale;

    // Darken background slightly
    noStroke();
    fill(0, 0, 0, 150);
    rect(0, 0, width, height);

    // Draw floating card with custom height to fit buttons
    float lineH = 23 * scale;
    String[] lines = new String[] {
      "Start the tutorial?",
      "It will guide you through the basic controls"
    };
    float cardH = 140 * scale + lines.length * lineH;

    pushStyle();
    noStroke();
    fill(8, 10, 20, 230);
    stroke(150, 180, 220, 180);
    strokeWeight(2 * scale);
    rect(cardX, cardY, cardW, cardH, 10 * scale);

    fill(255, 220, 100);
    textAlign(LEFT, TOP);
    textSize(18 * scale);
    text("Welcome to Solar System Spaceflight Simulation", cardX + 18 * scale, cardY + 14 * scale);

    fill(220, 230, 255);
    textSize(14 * scale);
    for (int i = 0; i < lines.length; i++) {
      text(lines[i], cardX + 18 * scale, cardY + 46 * scale + i * lineH);
    }
    popStyle();

    // Adjust buttons - Skip on left, Start on right, closer together and centered
    float btnY = cardY + cardH - 70 * scale;
    float btnSpacing = 30 * scale;
    float totalBtnWidth = noButton.w + yesButton.w + btnSpacing;
    float buttonsStartX = cardX + (cardW - totalBtnWidth) / 2;

    noButton.x = buttonsStartX;
    noButton.y = btnY;
    noButton.draw();

    // Save original colors and set green for Start button
    color origNormal = yesButton.normalBg;
    color origHover = yesButton.hoverBg;
    color origPressed = yesButton.pressedBg;
    yesButton.normalBg = color(30, 120, 50, 180);
    yesButton.hoverBg = color(40, 150, 70, 200);
    yesButton.pressedBg = color(50, 170, 80, 220);

    yesButton.x = buttonsStartX + noButton.w + btnSpacing;
    yesButton.y = btnY;
    yesButton.draw();

    // Restore original colors
    yesButton.normalBg = origNormal;
    yesButton.hoverBg = origHover;
    yesButton.pressedBg = origPressed;
  }

  void drawShowControlsHelp() {
    float scale = uiScale;
    float[] bounds = getHelpButtonBounds();

    float targetX = bounds[0] + bounds[2] / 2;
    float targetY = bounds[1] + bounds[3] / 2;

    float cardW = 320 * scale;
    float cardX = targetX - cardW / 2;
    float cardY = targetY + 60 * scale;

    drawTooltipCard(cardX, cardY, cardW,
      "Controls Help",
      new String[] {
        "Click the HELP button or press H",
        "to open the full controls guide",
        "View shortcuts and features anytime"
      });

    drawHelpLine(cardX + cardW / 2, cardY, targetX, targetY);
    drawNextButton(cardX + cardW / 2, cardY + 160 * scale);
  }

  void drawPanZoom() {
    float scale = uiScale;

    // Draw masks - cover left/right drawers and top buttons
    noStroke();
    fill(0, 0, 0, 150);
    float leftWidth = 300 * scale;   // Cover left drawer
    float rightWidth = 330 * scale;  // Cover right drawers
    float topHeight = 120 * scale;   // Cover top buttons

    rect(0, 0, leftWidth, height);           // Left mask
    rect(width - rightWidth, 0, rightWidth, height); // Right mask
    rect(0, 0, width, topHeight);            // Top mask

    float centerX = width / 2;
    float centerY = height / 2;

    float cardW = 340 * scale;
    float cardX = centerX - cardW / 2;
    float cardY = 30 * scale;

    noStroke();
    fill(0, 0, 0, 200);
    rect(cardX - 10 * scale, cardY - 10 * scale, cardW + 20 * scale, 200 * scale, 10 * scale);

    drawTooltipCard(cardX, cardY, cardW,
      "Try Pan & Zoom!",
      new String[] {
        "Drag mouse: Pan the view",
        "Scroll wheel: Zoom in/out",
        "Double-click: Focus on object",
        "Click Next when ready"
      });

    drawNextButton(cardX + cardW / 2, cardY + 160 * scale);
  }

  void drawSwitchToShipView() {
    float scale = uiScale;
    float[] bounds = getViewToggleBounds();

    float targetX = bounds[0] + bounds[2] / 2;
    float targetY = bounds[1] + bounds[3] / 2;

    float cardW = 320 * scale;
    float cardX = bounds[0] - cardW - 120 * scale; // Move further left towards center
    float cardY = bounds[1];

    drawTooltipCard(cardX, cardY, cardW,
      "Click the View Button",
      new String[] {
        "Click the button on the right",
        "to switch to Ship View",
        "You must click it to continue"
      });

    drawHelpLine(cardX + cardW, cardY + 60 * scale, targetX, targetY);
    highlightBounds(bounds);
  }

  void drawOpenTaskPanel() {
    float scale = uiScale;
    if (hud == null) return;

    DrawerPanel drawer = hud.taskDrawer;
    drawer.updateTargetPositions();

    float cardW = 320 * scale;
    float cardX = drawer.expandedPosition - cardW - 120 * scale; // Move further left towards center
    float cardY = 120 * scale - 65 * scale;

    drawTooltipCard(cardX, cardY, cardW,
      "MISSIONS Panel",
      new String[] {
        "This is the MISSIONS panel",
        "Select preset missions here",
        "Click START to begin your journey"
      });

    drawNextButton(cardX + cardW / 2, cardY + 160 * scale);
  }

  void drawIntroEduPanel() {
    float scale = uiScale;
    if (hud == null) return;

    DrawerPanel drawer = hud.educationDrawer;
    drawer.updateTargetPositions();

    float cardW = 320 * scale;
    float cardX = drawer.expandedPosition - cardW - 120 * scale; // Move further left towards center
    float cardY = 120 * scale + 520 * scale;

    drawTooltipCard(cardX, cardY, cardW,
      "GUIDE Panel",
      new String[] {
        "This is the GUIDE panel",
        "Learn about spaceflight concepts",
        "Tips and info while you explore!"
      });

    drawNextButton(cardX + cardW / 2, cardY + 160 * scale);
  }

  void drawStartMission() {
    float scale = uiScale;
    float[] bounds = getStartButtonBounds();

    float targetX = bounds[0] + bounds[2] / 2;
    float targetY = bounds[1] + bounds[3] / 2;

    float cardW = 320 * scale;
    float cardX = bounds[0] - cardW - 120 * scale; // Move further left towards center
    float cardY = bounds[1] - 50 * scale;

    drawTooltipCard(cardX, cardY, cardW,
      "Start Your First Mission",
      new String[] {
        "Select a preset mission in the panel",
        "Click START to begin the launch",
        "Have a great journey!"
      });

    drawHelpLine(cardX + cardW, cardY + 60 * scale, targetX, targetY);
    highlightBounds(bounds);
  }


  void highlightBounds(float[] bounds) {
    float scale = uiScale;
    pushStyle();
    noFill();
    stroke(255, 220, 100, 200);
    strokeWeight(3 * scale);
    rect(bounds[0], bounds[1], bounds[2], bounds[3], 8 * scale);
    popStyle();
  }

  void drawTooltipCard(float x, float y, float w, String title, String[] lines) {
    float scale = uiScale;
    float lineH = 23 * scale;
    float h = 52 * scale + lines.length * lineH;

    pushStyle();

    noStroke();
    fill(8, 10, 20, 230);
    stroke(150, 180, 220, 180);
    strokeWeight(2 * scale);
    rect(x, y, w, h, 10 * scale);

    fill(255, 220, 100);
    textAlign(LEFT, TOP);
    textSize(18 * scale);
    text(title, x + 18 * scale, y + 14 * scale);

    fill(220, 230, 255);
    textSize(14 * scale);
    for (int i = 0; i < lines.length; i++) {
      text(lines[i], x + 18 * scale, y + 46 * scale + i * lineH);
    }

    popStyle();
  }

  void drawHelpLine(float fromX, float fromY, float toX, float toY) {
    pushStyle();
    stroke(150, 200, 255, 180);
    strokeWeight(2 * uiScale);
    line(fromX, fromY, toX, toY);
    noStroke();
    fill(150, 200, 255, 200);
    ellipse(toX, toY, 8 * uiScale, 8 * uiScale);
    popStyle();
  }

  void drawNextButton(float centerX, float y) {
    float scale = uiScale;
    nextButton.x = centerX - 50 * scale;
    nextButton.y = y;
    nextButton.draw();
  }

  boolean isActive() {
    return active;
  }

  // Handle ESC key - returns true if consumed
  boolean handleKeyPressed() {
    if (!active) return false;

    if (keyCode == ESC) {
      active = false;
      key = 0; // Prevent default exit behavior
      return true;
    }
    return false;
  }
}
