// ============================================================
//  右上角视图切换按钮
// ============================================================
class ViewToggleButton {
  float panelX, panelY, panelW, panelH;
  int hoverFrames;

  ViewToggleButton() {
    float scale = uiScale;
    panelW = 175 * scale;
    panelH = 36 * scale;
    panelX = width - panelW - 10 * scale;
    panelY = 10 * scale;
    hoverFrames = 0;
  }

  void update() {
    // 检查 hover
    boolean nowHovered = (mouseX >= panelX && mouseX <= panelX + panelW &&
                         mouseY >= panelY && mouseY <= panelY + panelH);
    if (nowHovered) {
      hoverFrames++;
    } else {
      hoverFrames = 0;
    }
  }

  void draw() {
    float scale = uiScale;

    // 检查 hover 状态用于绘制
    boolean hovered = (mouseX >= panelX && mouseX <= panelX + panelW &&
                      mouseY >= panelY && mouseY <= panelY + panelH);

    // 面板背景
    noStroke();
    if (mousePressed && hovered) {
      fill(80, 100, 140, 200);
    } else if (hovered) {
      fill(60, 60, 80, 180);
    } else {
      fill(0, 0, 0, 160);
    }
    rect(panelX, panelY, panelW, panelH, 6 * scale);

    // 左侧：切换图标（两个重叠的方框）
    float iconX = panelX + 12 * scale;
    float iconY = panelY + panelH / 2;
    float boxSize = 10 * scale;

    // 后框
    fill(150, 180, 220, 180);
    rect(iconX - boxSize/2 + 2*scale, iconY - boxSize/2 - 2*scale, boxSize, boxSize, 2*scale);

    // 前框
    fill(200, 230, 255);
    rect(iconX - boxSize/2 - 2*scale, iconY - boxSize/2 + 2*scale, boxSize, boxSize, 2*scale);

    // 右侧：当前视图状态文字
    String statusText;
    if (camera.getMode() == ViewMode.MAP_VIEW) {
      statusText = "MAP VIEW";
    } else {
      statusText = "SHIP VIEW";
    }

    fill(255);
    textSize(14 * scale);
    textAlign(LEFT, CENTER);
    text(statusText, panelX + 38 * scale, panelY + panelH / 2);
  }

  boolean handleClick(CameraController cam) {
    // 直接检测是否在范围内点击
    if (mouseX >= panelX && mouseX <= panelX + panelW &&
        mouseY >= panelY && mouseY <= panelY + panelH) {
      if (cam.getMode() == ViewMode.MAP_VIEW) {
        // 切换到 SHIP_VIEW，自动 follow 当前飞船
        if (cam.followTarget == null && launchController.getCurrentShip() != null) {
          cam.followShip(launchController.getCurrentShip());
        }
        cam.setViewMode(ViewMode.SHIP_VIEW);
      } else {
        // 切换回 MAP_VIEW
        cam.setViewMode(ViewMode.MAP_VIEW);
      }
      return true;
    }
    return false;
  }

  boolean shouldShowTooltip() {
    return hoverFrames >= Button.TOOLTIP_DELAY;
  }

  String getHoveredTooltipText() {
    if (shouldShowTooltip()) {
      return "Switch between map and ship view  [V]";
    }
    return null;
  }

  // 提供给 HUD 的 tooltip 源位置
  float getX() { return panelX; }
  float getY() { return panelY; }
  float getW() { return panelW; }
  float getH() { return panelH; }
}
