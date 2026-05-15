// ============================================================
//  左侧导航聚焦面板
// ============================================================
class NavigationFocusPanel {
  float panelX, panelY, panelW, panelH;
  float rowH, headerH, footerH;
  CelestialBody selectedBody;
  long lastClickTime;
  CelestialBody lastClickBody;
  float panelMargin;
  static final int PANEL_DOUBLE_CLICK_MS = 300;

  // hover 跟踪
  int hoveredIndex;       // -1: 无, 0-8: 天体, 9: 飞船
  int hoveredFrames;
  boolean snapButtonHover;
  int snapButtonHoverFrames;

  NavigationFocusPanel() {
    float scale = uiScale;
    panelX = 10 * scale;
    panelY = 120 * scale;
    panelW = 270 * scale;
    rowH = 26 * scale;
    headerH = 42 * scale;
    footerH = 36 * scale;
    panelMargin = 10 * scale;

    selectedBody = null;
    lastClickTime = 0;
    lastClickBody = null;
    hoveredIndex = -1;
    hoveredFrames = 0;
    snapButtonHover = false;
    snapButtonHoverFrames = 0;
  }

  void update() {
    float scale = uiScale;
    // 计算当前面板高度
    int bodyCount = 1 + 8;  // sun + 8 planets
    panelH = headerH + (bodyCount + 1 + 1) * rowH + 8 * scale + footerH;

    // 检测 hover
    if (camera.getMode() != ViewMode.MAP_VIEW) {
      hoveredIndex = -1;
      hoveredFrames = 0;
      snapButtonHover = false;
      snapButtonHoverFrames = 0;
      return;
    }

    boolean hitPanel = (mouseX >= panelX && mouseX <= panelX + panelW &&
                        mouseY >= panelY && mouseY <= panelY + panelH);
    if (!hitPanel) {
      hoveredIndex = -1;
      hoveredFrames = 0;
    } else {
      float rowY = panelY + headerH;
      int idx = -1;

      // Sun
      if (mouseY >= rowY && mouseY < rowY + rowH) {
        idx = 0;
      }
      rowY += rowH;

      // 8 planets
      for (int i = 0; i < 8; i++) {
        if (mouseY >= rowY && mouseY < rowY + rowH) {
          idx = i + 1;
          break;
        }
        rowY += rowH;
      }
      rowY += rowH;  // 分隔线

      // Spacecraft
      if (mouseY >= rowY && mouseY < rowY + rowH) {
        idx = 9;
      }

      if (idx == hoveredIndex) {
        hoveredFrames++;
      } else {
        hoveredIndex = idx;
        hoveredFrames = 1;
      }
    }

    // Snap button hover
    float footerY = panelY + headerH + (9 + 1 + 1) * rowH + 8 * scale;
    float btnX = panelX + panelW - 70 * scale;
    float btnY = footerY + 2;
    float btnW = 56 * scale;
    float btnH = 22 * scale;
    snapButtonHover = (mouseX >= btnX && mouseX <= btnX + btnW &&
                       mouseY >= btnY && mouseY <= btnY + btnH);
    if (snapButtonHover) {
      snapButtonHoverFrames++;
    } else {
      snapButtonHoverFrames = 0;
    }
  }

  void draw(CameraController cam, CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {
    if (cam.getMode() != ViewMode.MAP_VIEW) return;

    float scale = uiScale;
    pushStyle();

    int bodyCount = 1 + 8;  // sun + 8 planets
    panelH = headerH + (bodyCount + 1 + 1) * rowH + 8 * scale + footerH;

    // 面板背景
    noStroke();
    fill(0, 0, 0, 150);
    rect(panelX, panelY, panelW, panelH, 8 * scale);

    // 标题 + 聚焦目标
    fill(200);
    textSize(16 * scale);
    textAlign(LEFT, TOP);
    text("NAVIGATION", panelX + panelMargin, panelY + panelMargin);

    String focusName = getFocusName(cam);
    if (focusName != null) {
      fill(255, 200, 50);
      textSize(12 * scale);
      textAlign(RIGHT, TOP);
      text("Focus: " + focusName, panelX + panelW - panelMargin, panelY + panelMargin);
    }

    // 天体行
    float rowY = panelY + headerH;

    // Sun row
    drawBodyRow(rowY, sun, sun == cam.focusBody, selectedBody == sun, 0);
    rowY += rowH;

    // 8 planets
    for (int i = 0; i < planets.size(); i++) {
      CelestialBody p = planets.get(i);
      drawBodyRow(rowY, p, p == cam.focusBody, selectedBody == p, i + 1);
      rowY += rowH;
    }

    // 分隔线
    stroke(100, 100, 120, 100);
    strokeWeight(1);
    line(panelX + panelMargin, rowY, panelX + panelW - panelMargin, rowY);
    noStroke();
    rowY += rowH;

    // Spacecraft row
    drawSpacecraftRow(rowY, ships, cam.focusShip != null);
    rowY += rowH;

    // Footer: Snap button
    float footerY = rowY + 8 * scale;
    float btnX = panelX + panelW - 70 * scale;
    float btnY = footerY + 2;
    float btnW = 56 * scale;
    float btnH = 22 * scale;

    fill(snapButtonHover ? color(80, 160, 220) : color(50, 120, 180));
    noStroke();
    rect(btnX, btnY, btnW, btnH, 4 * scale);
    fill(255);
    textSize(13 * scale);
    textAlign(CENTER, CENTER);
    text("SNAP", btnX + btnW / 2, btnY + btnH / 2);

    popStyle();
  }

  void drawBodyRow(float y, CelestialBody body, boolean isFocused, boolean isSelected, int idx) {
    float scale = uiScale;

    boolean isHoveredLine = (hoveredIndex == idx);

    // 行背景高亮
    if (isFocused) {
      fill(255, 220, 100, 40);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    } else if (isSelected) {
      fill(255, 255, 255, 25);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    } else if (isHoveredLine) {
      fill(255, 255, 255, 12);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    }

    // 色点
    fill(body.col);
    noStroke();
    ellipse(panelX + 16 * scale, y + rowH / 2, 8 * scale, 8 * scale);

    // 名称
    if (isFocused) {
      fill(255, 220, 100);
    } else if (isSelected) {
      fill(240);
    } else {
      fill(200);
    }
    textSize(15 * scale);
    textAlign(LEFT, CENTER);
    text(body.name, panelX + 32 * scale, y + rowH / 2);

    // 右侧：聚焦按钮或聚焦指示器
    if (isSelected && !isFocused) {
      // 绘制聚焦按钮
      float btnX = panelX + panelW - 58 * scale;
      float btnW = 48 * scale;
      float btnH = 18 * scale;
      float btnCY = y + rowH / 2;
      boolean btnHover = mouseX >= btnX && mouseX <= btnX + btnW &&
                         mouseY >= btnCY - btnH / 2 && mouseY <= btnCY + btnH / 2;
      fill(btnHover ? color(80, 160, 220) : color(50, 120, 180));
      noStroke();
      rect(btnX, btnCY - btnH / 2, btnW, btnH, 3 * scale);
      fill(255);
      textSize(12 * scale);
      textAlign(CENTER, CENTER);
      text("Focus", btnX + btnW / 2, btnCY);
    } else if (isFocused) {
      // 聚焦指示器
      fill(255, 220, 100, 150);
      noStroke();
      float cx = panelX + panelW - 18 * scale;
      float cy = y + rowH / 2;
      ellipse(cx, cy, 9 * scale, 9 * scale);
    }
  }

  void drawSpacecraftRow(float y, List<Spacecraft> ships, boolean isFocused) {
    float scale = uiScale;
    boolean isHoveredLine = (hoveredIndex == 9);

    // 行背景高亮
    if (isFocused) {
      fill(255, 220, 100, 40);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    } else if (isHoveredLine) {
      fill(255, 255, 255, 12);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    }

    // 小箭头图标代替色点
    if (ships.size() > 0) {
      fill(ships.get(0).col);
    } else {
      fill(100, 255, 150);
    }
    float cx = panelX + 16 * scale;
    float cy = y + rowH / 2;
    float s = 4 * scale;
    noStroke();
    triangle(cx - s, cy - s, cx - s, cy + s, cx + s, cy);

    // 名称
    if (isFocused) {
      fill(255, 220, 100);
    } else {
      fill(200);
    }
    textSize(15 * scale);
    textAlign(LEFT, CENTER);
    text("Spacecraft", panelX + 32 * scale, y + rowH / 2);

    // 聚焦指示器
    if (isFocused) {
      fill(255, 220, 100, 150);
      noStroke();
      float indicCx = panelX + panelW - 18 * scale;
      float indicCy = y + rowH / 2;
      ellipse(indicCx, indicCy, 9 * scale, 9 * scale);
    }
  }

  boolean handleClick(float mx, float my, CameraController cam,
                     CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {
    if (cam.getMode() != ViewMode.MAP_VIEW) return false;

    // 检查是否在面板范围内
    if (mx < panelX || mx > panelX + panelW || my < panelY || my > panelY + panelH) {
      selectedBody = null;
      return false;
    }

    float rowY = panelY + headerH;

    // 首先检查：选中行上的聚焦按钮
    if (selectedBody != null) {
      int selIdx = -1;
      if (selectedBody == sun) {
        selIdx = 0;
      } else {
        for (int i = 0; i < planets.size(); i++) {
          if (planets.get(i) == selectedBody) {
            selIdx = i + 1;
            break;
          }
        }
      }
      if (selIdx >= 0) {
        float scale = uiScale;
        float btnRowY = panelY + headerH + selIdx * rowH;
        float btnX = panelX + panelW - 58 * scale;
        float btnW = 48 * scale;
        float btnH = 18 * scale;
        float btnCY = btnRowY + rowH / 2;
        if (mx >= btnX && mx <= btnX + btnW &&
            my >= btnCY - btnH / 2 && my <= btnCY + btnH / 2) {
          cam.focusOn(selectedBody);
          selectedBody = null;
          return true;
        }
      }
    }

    // 接下来检查行点击（选择/聚焦）

    // Sun
    if (my >= rowY && my < rowY + rowH) {
      return handleBodyClicked(mx, my, sun, cam);
    }
    rowY += rowH;

    // 8 planets
    for (int i = 0; i < planets.size(); i++) {
      if (my >= rowY && my < rowY + rowH) {
        return handleBodyClicked(mx, my, planets.get(i), cam);
      }
      rowY += rowH;
    }
    rowY += rowH;  // 分隔线

    // Spacecraft row
    if (my >= rowY && my < rowY + rowH) {
      if (ships.size() > 0) {
        long now = millis();
        if (lastClickBody == null &&
            now - lastClickTime < PANEL_DOUBLE_CLICK_MS) {
          // 双击飞船
          cam.focusOn(ships.get(0));
          lastClickTime = 0;
        } else {
          // 单击
          lastClickTime = now;
          lastClickBody = null;
          selectedBody = null;
        }
        return true;
      }
      return false;
    }
    rowY += rowH;

    // Footer: Snap button
    float scale = uiScale;
    float footerY = rowY + 8 * scale;
    float btnX = panelX + panelW - 70 * scale;
    float btnY = footerY + 2;
    float btnW = 56 * scale;
    float btnH = 22 * scale;
    if (mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH) {
      selectedBody = null;
      cam.snapFocus();
      return true;
    }

    // 点击面板空白处，取消选择
    selectedBody = null;
    return false;
  }

  boolean handleBodyClicked(float mx, float my, CelestialBody body, CameraController cam) {
    long now = millis();
    if (body == lastClickBody &&
        now - lastClickTime < PANEL_DOUBLE_CLICK_MS) {
      // 双击：直接聚焦
      selectedBody = null;
      lastClickTime = 0;
      lastClickBody = null;
      cam.focusOn(body);
      return true;
    } else {
      // 单击：选择
      selectedBody = body;
      lastClickTime = now;
      lastClickBody = body;
      return true;
    }
  }

  String getHoveredTooltipText() {
    if (hoveredIndex >= 0 && hoveredFrames >= Button.TOOLTIP_DELAY) {
      if (hoveredIndex == 0) {
        return "Focus on the Sun (double-click)";
      } else if (hoveredIndex <= 8) {
        return "Focus on planet (double-click)";
      } else if (hoveredIndex == 9) {
        return "Focus on Spacecraft (double-click)";
      }
    }
    if (snapButtonHoverFrames >= Button.TOOLTIP_DELAY) {
      return "Snap camera to current focus  [F]";
    }
    return null;
  }

  String getFocusName(CameraController cam) {
    if (cam.focusBody != null) {
      return cam.focusBody.name;
    } else if (cam.focusShip != null) {
      return "Spacecraft";
    }
    return null;
  }
}
