// ============================================================
//  左上角时间流速面板
// ============================================================
class TimeControlPanel {
  float panelX, panelY, panelW, panelH;
  float panelMargin;
  Button pauseButton;
  Button warpDownButton;
  Button warpUpButton;

  TimeControlPanel() {
    float scale = uiScale;
    panelX = 10 * scale;
    panelY = 10 * scale;
    panelW = 330 * scale;
    panelH = 100 * scale;
    panelMargin = 10 * scale;

    // 第一行：标题
    // 第二行：按钮
    float titleHeight = 22 * scale;
    float bx = panelX + panelMargin;
    float by = panelY + panelMargin + titleHeight + 4 * scale;
    float pauseW = 36 * scale;
    float pauseH = 28 * scale;
    float warpW = 28 * scale;
    float warpH = 28 * scale;

    pauseButton = new Button(bx, by, pauseW, pauseH, "||",
                             "Pause/resume simulation", "Space");

    bx += pauseW + 6 * scale;
    warpDownButton = new Button(bx, by, warpW, warpH, "<",
                                "Slower time warp", "Q");

    bx += warpW + 6 * scale;
    warpUpButton = new Button(bx, by, warpW, warpH, ">",
                              "Faster time warp", "E");
  }

  void update() {
    pauseButton.update();
    warpDownButton.update();
    warpUpButton.update();

    // 更新暂停按钮标签
    if (timeManager.timeWarp == 0) {
      pauseButton.label = ">";
    } else {
      pauseButton.label = "||";
    }
  }

  void draw(TimeManager tm) {
    float scale = uiScale;

    pushStyle();

    // 面板背景
    noStroke();
    fill(0, 0, 0, 160);
    rect(panelX, panelY, panelW, panelH, 8 * scale);

    // 标题
    fill(200);
    textSize(16 * scale);
    textAlign(LEFT, TOP);
    text("TIME CONTROL", panelX + panelMargin, panelY + panelMargin);

    // 按钮
    pauseButton.draw();
    warpDownButton.draw();
    warpUpButton.draw();

    // 横向档位条
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

    // 当前 warp 标签
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
    return false;
  }

  ArrayList<Button> getAllButtons() {
    ArrayList<Button> buttons = new ArrayList<Button>();
    buttons.add(pauseButton);
    buttons.add(warpDownButton);
    buttons.add(warpUpButton);
    return buttons;
  }

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
    return null;
  }
}
