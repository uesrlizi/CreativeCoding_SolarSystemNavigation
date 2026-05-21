// ========== NAVIGATION FOCUS PANEL ==========

class NavigationFocusPanel {
  float panelX, panelY, panelW, panelH;
  float rowH, headerH;
  CelestialBody selectedBody;
  boolean selectedShip;
  long lastClickTime;
  CelestialBody lastClickBody;
  boolean lastClickedShip;
  float panelMargin;
  static final int PANEL_DOUBLE_CLICK_MS = 300;

  int hoveredIndex;
  int hoveredFrames;

  NavigationFocusPanel() {
    float scale = uiScale;
    panelX = 10 * scale;
    panelY = 120 * scale;
    panelW = 260 * scale;  // 调整为更合理的宽度
    rowH = 26 * scale;
    headerH = 42 * scale;
    panelMargin = 12 * scale;

    selectedBody = null;
    selectedShip = false;
    lastClickTime = 0;
    lastClickBody = null;
    lastClickedShip = false;
    hoveredIndex = -1;
    hoveredFrames = 0;
  }

  void update() {
    float scale = uiScale;
    int bodyCount = 1 + 8;
    panelH = headerH + (bodyCount + 1 + 1) * rowH + 8 * scale;

    boolean hitPanel = (mouseX >= panelX && mouseX <= panelX + panelW &&
                        mouseY >= panelY && mouseY <= panelY + panelH);
    if (!hitPanel) {
      hoveredIndex = -1;
      hoveredFrames = 0;
    } else {
      float rowY = panelY + headerH;
      int idx = -1;

      if (mouseY >= rowY && mouseY < rowY + rowH) {
        idx = 0;
      }
      rowY += rowH;

      for (int i = 0; i < 8; i++) {
        if (mouseY >= rowY && mouseY < rowY + rowH) {
          idx = i + 1;
          break;
        }
        rowY += rowH;
      }
      rowY += rowH;

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
  }

  void draw(CameraController cam, CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {
    float scale = uiScale;
    pushStyle();

    int bodyCount = 1 + 8;
    panelH = headerH + (bodyCount + 1 + 1) * rowH + 8 * scale;

    String focusName = getFocusName(cam);
    if (focusName != null) {
      fill(255, 200, 100);
      textSize(12 * scale);
      textAlign(RIGHT, TOP);
      text("Focus: " + focusName, panelX + panelW - panelMargin, panelY + panelMargin);
    }

    float rowY = panelY + headerH;

    drawBodyRow(rowY, sun, sun == cam.focusBody, selectedBody == sun, 0, cam);
    rowY += rowH;

    for (int i = 0; i < planets.size(); i++) {
      CelestialBody p = planets.get(i);
      drawBodyRow(rowY, p, p == cam.focusBody, selectedBody == p, i + 1, cam);
      rowY += rowH;
    }

    stroke(100, 100, 120, 100);
    strokeWeight(1);
    line(panelX + panelMargin, rowY, panelX + panelW - panelMargin, rowY);
    noStroke();
    rowY += rowH;

    // Log spacecraft row position
    if (cam.focusShip != null) {
      println("drawSpacecraftRow at y=" + rowY + ", (headerH=" + headerH + ", 10*rowH=" + (10*rowH) + ")");
    }

    drawSpacecraftRow(rowY, ships, cam.focusShip != null, cam);
    rowY += rowH;

    popStyle();
  }

  // Check if target is visible on screen (center position only)
  boolean isTargetVisible(CameraController cam, CelestialBody body) {
    if (cam.getMode() == ViewMode.MAP_VIEW) {
      // In map view, check if within view bounds - simplified
      double[] screenPos = cam.worldToScreen(body.px, body.py);
      double px = screenPos[0];
      double py = screenPos[1];
      return px >= 0 && px <= width && py >= 0 && py <= height;
    } else {
      // In ship view, just check if this is the follow target
      return cam.followTarget != null;
    }
  }

  boolean isTargetVisible(CameraController cam, Spacecraft ship) {
    if (cam.getMode() == ViewMode.MAP_VIEW) {
      double[] screenPos = cam.worldToScreen(ship.worldX, ship.worldY);
      double px = screenPos[0];
      double py = screenPos[1];
      return px >= 0 && px <= width && py >= 0 && py <= height;
    } else {
      return cam.followTarget == ship;
    }
  }

  boolean handleClick(float mx, float my, CameraController cam, CelestialBody sun, List<CelestialBody> planets, List<Spacecraft> ships) {

    if (mx < panelX || mx > panelX + panelW || my < panelY || my > panelY + panelH) {
      selectedBody = null;
      selectedShip = false;
      return false;
    }

    // Check if clicked on SNAP button for already focused body
    if (cam.focusBody != null) {
      int focusIdx = -1;
      if (cam.focusBody == sun) {
        focusIdx = 0;
      } else {
        for (int i = 0; i < planets.size(); i++) {
          if (planets.get(i) == cam.focusBody) {
            focusIdx = i + 1;
            break;
          }
        }
      }
      if (focusIdx >= 0) {
        float scale = uiScale;
        float btnRowY = panelY + headerH + focusIdx * rowH;
        float btnX = panelX + panelW - 58 * scale;
        float btnW = 48 * scale;
        float btnH = 18 * scale;
        float btnCY = btnRowY + rowH / 2;
        if (mx >= btnX && mx <= btnX + btnW &&
            my >= btnCY - btnH / 2 && my <= btnCY + btnH / 2) {
          cam.snapFocus();
          return true;
        }
      }
    }

    // Check if clicked on SNAP button for already focused ship
    if (cam.focusShip != null && ships.size() > 0 && cam.focusShip == ships.get(0)) {
      float scale = uiScale;
      float btnRowY = panelY + headerH + 10 * rowH;  // 10: sun(1) + planets(8) + separator(1)
      float btnX = panelX + panelW - 58 * scale;
      float btnW = 48 * scale;
      float btnH = 18 * scale;
      float btnCY = btnRowY + rowH / 2;
      println("Ship SNAP button check:");
      println("  Click: mx=" + mx + ", my=" + my);
      println("  Button: x=" + btnX + "-" + (btnX+btnW) + ", y=" + (btnCY-btnH/2) + "-" + (btnCY+btnH/2));
      println("  btnRowY=" + btnRowY + ", headerH=" + headerH + ", rowH=" + rowH);
      if (mx >= btnX && mx <= btnX + btnW &&
          my >= btnCY - btnH / 2 && my <= btnCY + btnH / 2) {
        println("  HIT - calling snapFocus()");
        cam.snapFocus();
        return true;
      }
    }

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
          // Auto-snap if target is not visible
          if (!isTargetVisible(cam, selectedBody)) {
            cam.snapFocus();
          }
          selectedBody = null;
          selectedShip = false;
          return true;
        }
      }
    }

    if (selectedShip && ships.size() > 0) {
      float scale = uiScale;
      float btnRowY = panelY + headerH + 10 * rowH;  // 10: sun(1) + planets(8) + separator(1)
      float btnX = panelX + panelW - 58 * scale;
      float btnW = 48 * scale;
      float btnH = 18 * scale;
      float btnCY = btnRowY + rowH / 2;
      if (mx >= btnX && mx <= btnX + btnW &&
          my >= btnCY - btnH / 2 && my <= btnCY + btnH / 2) {
        cam.focusOn(ships.get(0));
        // Auto-snap if target is not visible
        if (!isTargetVisible(cam, ships.get(0))) {
          cam.snapFocus();
        }
        selectedShip = false;
        selectedBody = null;
        return true;
      }
    }

    float rowY = panelY + headerH;

    if (my >= rowY && my < rowY + rowH) {
      return handleBodyClicked(mx, my, sun, cam);
    }
    rowY += rowH;

    for (int i = 0; i < planets.size(); i++) {
      if (my >= rowY && my < rowY + rowH) {
        return handleBodyClicked(mx, my, planets.get(i), cam);
      }
      rowY += rowH;
    }
    rowY += rowH;

    if (my >= rowY && my < rowY + rowH && ships.size() > 0) {
      long now = millis();
      if (lastClickedShip && selectedShip &&
          now - lastClickTime < PANEL_DOUBLE_CLICK_MS) {
        cam.focusOn(ships.get(0));
        // Auto-snap if target is not visible
        if (!isTargetVisible(cam, ships.get(0))) {
          cam.snapFocus();
        }
        selectedShip = false;
        selectedBody = null;
        lastClickTime = 0;
        lastClickedShip = false;
      } else {
        selectedShip = true;
        selectedBody = null;
        lastClickTime = now;
        lastClickBody = null;
        lastClickedShip = true;
      }
      return true;
    }

    selectedBody = null;
    selectedShip = false;
    return false;
  }

  boolean handleBodyClicked(float mx, float my, CelestialBody body, CameraController cam) {
    long now = millis();
    if (body == lastClickBody && !lastClickedShip &&
        now - lastClickTime < PANEL_DOUBLE_CLICK_MS) {
      selectedBody = null;
      selectedShip = false;
      lastClickTime = 0;
      lastClickBody = null;
      lastClickedShip = false;
      cam.focusOn(body);
      // Auto-snap if target is not visible
      if (!isTargetVisible(cam, body)) {
        cam.snapFocus();
      }
      return true;
    } else {
      selectedBody = body;
      selectedShip = false;
      lastClickTime = now;
      lastClickBody = body;
      lastClickedShip = false;
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
    return null;
  }

  float[] getTooltipSource() {
    float scale = uiScale;
    // If a row is hovered, use that row's position
    if (hoveredIndex >= 0 && hoveredFrames >= Button.TOOLTIP_DELAY) {
      float rowY = panelY + headerH + hoveredIndex * rowH;
      return new float[] { panelX, rowY, panelW, rowH };
    }
    // Fallback to full panel
    return new float[] { panelX, panelY, panelW, panelH };
  }

  String getFocusName(CameraController cam) {
    if (cam.focusBody != null) return cam.focusBody.name;
    if (cam.focusShip != null) return "Spacecraft";
    return null;
  }

  float getPanelHeight() {
    float scale = uiScale;
    int bodyCount = 1 + 8;
    return headerH + (bodyCount + 1 + 1) * rowH + 8 * scale;
  }

  void drawBodyRow(float y, CelestialBody body, boolean isFocused, boolean isSelected, int idx, CameraController cam) {
    float scale = uiScale;
    boolean isHoveredLine = (hoveredIndex == idx);

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

    fill(body.col);
    noStroke();
    ellipse(panelX + 16 * scale, y + rowH / 2, 8 * scale, 8 * scale);

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

    if (isSelected && !isFocused) {
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
      float btnX = panelX + panelW - 58 * scale;
      float btnW = 48 * scale;
      float btnH = 18 * scale;
      float btnCY = y + rowH / 2;
      boolean btnHover = mouseX >= btnX && mouseX <= btnX + btnW &&
                         mouseY >= btnCY - btnH / 2 && mouseY <= btnCY + btnH / 2;
      fill(btnHover ? color(80, 200, 110) : color(60, 160, 80));
      noStroke();
      rect(btnX, btnCY - btnH / 2, btnW, btnH, 3 * scale);
      fill(255);
      textSize(11 * scale);
      textAlign(CENTER, CENTER);
      text("SNAP", btnX + btnW / 2, btnCY);
    }
  }

  void drawSpacecraftRow(float y, List<Spacecraft> ships, boolean isFocused, CameraController cam) {
    float scale = uiScale;
    boolean isHoveredLine = (hoveredIndex == 9);

    if (isFocused) {
      fill(255, 220, 100, 40);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    } else if (selectedShip) {
      fill(255, 255, 255, 25);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    } else if (isHoveredLine) {
      fill(255, 255, 255, 12);
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    }

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

    if (isFocused) {
      fill(255, 220, 100);
    } else if (selectedShip) {
      fill(240);
    } else {
      fill(200);
    }
    textSize(15 * scale);
    textAlign(LEFT, CENTER);
    text("Spacecraft", panelX + 32 * scale, y + rowH / 2);

    if (selectedShip && !isFocused && ships.size() > 0) {
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
      float btnX = panelX + panelW - 58 * scale;
      float btnW = 48 * scale;
      float btnH = 18 * scale;
      float btnCY = y + rowH / 2;
      boolean btnHover = mouseX >= btnX && mouseX <= btnX + btnW &&
                         mouseY >= btnCY - btnH / 2 && mouseY <= btnCY + btnH / 2;
      fill(btnHover ? color(80, 200, 110) : color(60, 160, 80));
      noStroke();
      rect(btnX, btnCY - btnH / 2, btnW, btnH, 3 * scale);
      fill(255);
      textSize(11 * scale);
      textAlign(CENTER, CENTER);
      text("SNAP", btnX + btnW / 2, btnCY);
    }
  }
}
