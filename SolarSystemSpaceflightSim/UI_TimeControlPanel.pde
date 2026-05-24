// ========== TIME CONTROL PANEL ==========

class TimeControlPanel {
  float panelX, panelY, panelW, panelH;
  float panelMargin;
  Button pauseButton;
  Button warpDownButton;
  Button warpUpButton;
  Button restartButton;
  Button quitButton;
  Button helpButton;

  TimeControlPanel() {
    float scale = uiScale;
    panelX = 10 * scale;
    panelY = 10 * scale;
    panelW = 330 * scale;
    panelH = 100 * scale;
    panelMargin = 10 * scale;

    float titleHeight = 22 * scale;
    float bx = panelX + panelMargin;
    float by = panelY + panelMargin + titleHeight + 4 * scale;
    float pauseW = 36 * scale;
    float pauseH = 28 * scale;
    float warpW = 28 * scale;
    float warpH = 28 * scale;

    pauseButton = new Button(bx, by, pauseW, pauseH, "||",
                             "Pause/resume simulation", "Space/ESC");

    bx += pauseW + 6 * scale;
    warpDownButton = new Button(bx, by, warpW, warpH, "<",
                                "Slower time warp", "Q");

    bx += warpW + 6 * scale;
    warpUpButton = new Button(bx, by, warpW, warpH, ">",
                              "Faster time warp", "E");

    // 暂停时显示的按钮 - 放在时间控制面板右侧
    float restartW = 120 * scale;
    float buttonH = 36 * scale;  // 和视图按钮一样高
    float quitW = 100 * scale;
    float helpW = 90 * scale;
    float gap = 10 * scale;
    float rightButtonsX = panelX + panelW + gap;

    // 计算 Y 位置使按钮顶部对齐面板顶部
    float rightButtonsY = panelY;

    helpButton = new Button(rightButtonsX, rightButtonsY, helpW, buttonH, "HELP",
                            "Show controls help", "", Button.ICON_HELP);
    rightButtonsX += helpW + 6 * scale;
    restartButton = new Button(rightButtonsX, rightButtonsY, restartW, buttonH, "RESTART",
                               "Restart the simulation", "", Button.ICON_RESTART);
    rightButtonsX += restartW + 6 * scale;
    quitButton = new Button(rightButtonsX, rightButtonsY, quitW, buttonH, "QUIT",
                            "Exit the game", "", Button.ICON_QUIT);
  }

  void update() {
    pauseButton.update();
    warpDownButton.update();
    warpUpButton.update();
    restartButton.update();
    quitButton.update();
    helpButton.update();

    if (timeManager.timeWarp == 0) {
      pauseButton.label = ">";
    } else {
      pauseButton.label = "||";
    }
  }

  void draw(TimeManager tm) {
    float scale = uiScale;

    pushStyle();

    noStroke();
    fill(0, 0, 0, 160);
    rect(panelX, panelY, panelW, panelH, 8 * scale);

    fill(200);
    textSize(16 * scale);
    textAlign(LEFT, TOP);
    text("TIME CONTROL", panelX + panelMargin, panelY + panelMargin);

    pauseButton.draw();
    warpDownButton.draw();
    warpUpButton.draw();

    helpButton.draw();

    // 只在暂停时显示重新开始和退出按钮
    if (tm.timeWarp == 0) {
      restartButton.draw();
      quitButton.draw();
    }

    float titleHeight = 22 * scale;
    float barX = panelX + panelMargin;
    float barY = panelY + panelMargin + titleHeight + 4 * scale + 36 * scale;
    float barH = 8 * scale;
    float totalBarW = panelW - 2 * panelMargin;
    float gap = 4 * scale;
    float slotW = (totalBarW - 7 * gap) / 8;

    for (int i = 0; i < 8; i++) {
      float slotX = barX + i * (slotW + gap);
      if (i == tm.warpIndex && tm.timeWarp > 0) {
        fill(100, 200, 100);
      } else if (i == tm.warpIndex && tm.timeWarp == 0) {
        fill(200, 100, 100);
      } else {
        fill(70, 70, 70);
      }
      noStroke();
      rect(slotX, barY, slotW, barH, 3 * scale);
    }

    fill(180);
    textSize(13 * scale);
    String warpStr = tm.formatWarp(tm.timeWarp, tm.WARP_LABELS, tm.warpIndex);
    text(warpStr, panelX + panelMargin, barY + 14 * scale);

    popStyle();
  }

  boolean handleClick() {
    if (pauseButton.consumeClick()) {
      timeManager.togglePause();
      return true;
    }
    if (warpDownButton.consumeClick()) {
      timeManager.decreaseWarp();
      return true;
    }
    if (warpUpButton.consumeClick()) {
      timeManager.increaseWarp();
      return true;
    }
    if (helpButton.consumeClick()) {
      showControlsHelp = true;
      return true;
    }
    if (timeManager.timeWarp == 0) {
      if (restartButton.consumeClick()) {
        restartGame();
        return true;
      }
      if (quitButton.consumeClick()) {
        exit();
        return true;
      }
    }
    return false;
  }

  ArrayList<Button> getAllButtons() {
    ArrayList<Button> buttons = new ArrayList<Button>();
    buttons.add(pauseButton);
    buttons.add(warpDownButton);
    buttons.add(warpUpButton);
    buttons.add(helpButton);
    if (timeManager.timeWarp == 0) {
      buttons.add(restartButton);
      buttons.add(quitButton);
    }
    return buttons;
  }

  float getPauseCenterX() { return pauseButton.x + pauseButton.w / 2; }
  float getPauseCenterY() { return pauseButton.y + pauseButton.h / 2; }
  float getWarpDownCenterX() { return warpDownButton.x + warpDownButton.w / 2; }
  float getWarpDownCenterY() { return warpDownButton.y + warpDownButton.h / 2; }
  float getWarpUpCenterX() { return warpUpButton.x + warpUpButton.w / 2; }
  float getWarpUpCenterY() { return warpUpButton.y + warpUpButton.h / 2; }

  String getHoveredTooltipText() {
    if (pauseButton.shouldShowTooltip()) {
      return pauseButton.getTooltipText();
    }
    if (warpDownButton.shouldShowTooltip()) {
      return warpDownButton.getTooltipText();
    }
    if (warpUpButton.shouldShowTooltip()) {
      return warpUpButton.getTooltipText();
    }
    if (helpButton.shouldShowTooltip()) {
      return helpButton.getTooltipText();
    }
    if (timeManager.timeWarp == 0) {
      if (restartButton.shouldShowTooltip()) {
        return restartButton.getTooltipText();
      }
      if (quitButton.shouldShowTooltip()) {
        return quitButton.getTooltipText();
      }
    }
    return null;
  }
}
