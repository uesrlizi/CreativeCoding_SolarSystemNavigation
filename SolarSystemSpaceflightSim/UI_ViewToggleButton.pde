// ========== VIEW TOGGLE BUTTON ==========

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
    panelW = 175 * scale;
    panelH = 36 * scale;
    panelX = width - panelW - 10 * scale;
    panelY = 10 * scale;

    boolean hovered = (mouseX >= panelX && mouseX <= panelX + panelW &&
                      mouseY >= panelY && mouseY <= panelY + panelH);

    noStroke();
    if (mousePressed && hovered) {
      fill(80, 100, 140, 200);
    } else if (hovered) {
      fill(60, 60, 80, 180);
    } else {
      fill(0, 0, 0, 160);
    }
    rect(panelX, panelY, panelW, panelH, 6 * scale);

    float iconX = panelX + 12 * scale;
    float iconY = panelY + panelH / 2;
    float boxSize = 10 * scale;

    fill(150, 180, 220, 180);
    rect(iconX - boxSize/2 + 2*scale, iconY - boxSize/2 - 2*scale, boxSize, boxSize, 2*scale);

    fill(200, 230, 255);
    rect(iconX - boxSize/2 - 2*scale, iconY - boxSize/2 + 2*scale, boxSize, boxSize, 2*scale);

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

  boolean handleClick(CameraController cam, List<Spacecraft> ships) {
    if (mouseX >= panelX && mouseX <= panelX + panelW &&
        mouseY >= panelY && mouseY <= panelY + panelH) {
      if (cam.getMode() == ViewMode.MAP_VIEW) {
        if (cam.followTarget == null && ships.size() > 0) {
          cam.followShip(ships.get(0));
        }
        cam.setViewMode(ViewMode.SHIP_VIEW);
      } else {
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

  float getX() { return panelX; }
  float getY() { return panelY; }
  float getW() { return panelW; }
  float getH() { return panelH; }
}
