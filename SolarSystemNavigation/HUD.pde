class HUD {
  LaunchUI launchUI;
  ShipViewHUD shipViewHUD;

  CelestialBody selectedBody;
  long lastPanelClickTime;
  CelestialBody lastPanelClickBody;
  static final int PANEL_DOUBLE_CLICK_MS = 300;

  HUD() {
    launchUI = new LaunchUI();
    shipViewHUD = new ShipViewHUD();
    selectedBody = null;
    lastPanelClickTime = 0;
    lastPanelClickBody = null;
  }

  void draw(CameraController cam, double simTime, double timeWarp,
            double[] WARP_LEVELS, String[] WARP_LABELS,
            int warpIndex, List<CelestialBody> planets, CelestialBody sun) {
    drawInfoPanel(cam, simTime, timeWarp, WARP_LABELS, warpIndex);
    drawCelestialPanel(cam, planets, sun);
    drawViewModeIndicator();
    launchUI.draw();

    if (cam.getMode() == ViewMode.SHIP_VIEW && cam.followTarget != null) {
      shipViewHUD.draw(cam.followTarget);
    }

    if (timeWarp == 0) {
      drawPauseIndicator();
    }
  }

  void drawInfoPanel(CameraController cam, double simTime, double timeWarp,
                     String[] WARP_LABELS, int warpIndex) {
    noStroke();
    fill(0, 0, 0, 160);
    rect(10, 10, 420, 215, 8);

    fill(220);
    textSize(21 * uiScale);
    textAlign(LEFT, TOP);
    text("Spacecraft Launch Simulator", 20, 18);

    textSize(16 * uiScale);
    fill(180);
    double simDays = simTime / DAY_S;
    double simYears = simDays / 365.25;
    text(String.format("Time: %.1f days (%.2f years)", simDays, simYears), 20, 48);

    String warpStr = timeManager.formatWarp(timeWarp, WARP_LABELS, warpIndex);
    fill(100, 200, 100);
    textSize(15 * uiScale);
    text("Time Warp: " + warpStr, 20, 76);

    double auPerPixel = 1.0 / (AU_KM * cam.scale);
    fill(180);
    text(String.format("Zoom: %.4f AU/px", auPerPixel), 20, 104);

    fill(160);
    textSize(15 * uiScale);
    text("[Space] Pause  [Q/E] Warp  [V] View  [F] Snap Focus", 20, 134);
    text("[O] Orbits  [L] Labels  [T] Trails", 20, 160);
    text("Drag to Pan  Scroll to Zoom  Double-click to focus", 20, 186);
  }

  void drawViewModeIndicator() {
    noStroke();
    fill(0, 0, 0, 160);
    rect(width - 130, 10, 120, 35, 8);

    fill(200);
    textSize(14 * uiScale);
    textAlign(LEFT, CENTER);
    String modeText = (camera.getMode() == ViewMode.MAP_VIEW) ? "MAP VIEW" : "SHIP VIEW";
    text(modeText + " [V]", width - 120, 28);
  }

  void drawCelestialPanel(CameraController cam, List<CelestialBody> planets, CelestialBody sun) {
    int px = 10;
    int py = 230;
    int pw = 260;
    int rowH = 26;
    int headerH = 42;
    int bodyCount = 1 + planets.size();
    int rowsH = bodyCount * rowH;
    int sepY = py + headerH + rowsH + 4;
    int footerH = 34;
    int ph = headerH + rowsH + 8 + footerH;

    CelestialBody focusBody = cam.focusBody;
    Spacecraft focusShip = cam.focusShip;

    noStroke();
    fill(0, 0, 0, 150);
    rect(px, py, pw, ph, 8);

    // Header
    fill(200);
    textSize(16 * uiScale);
    textAlign(LEFT, TOP);
    text("Bodies", px + 10, py + 10);

    // Body rows
    int rowY = py + headerH;
    drawBodyRow(px, rowY, pw, rowH, sun, focusBody, selectedBody);
    rowY += rowH;
    for (int i = 0; i < planets.size(); i++) {
      CelestialBody p = planets.get(i);
      drawBodyRow(px, rowY, pw, rowH, p, focusBody, selectedBody);
      rowY += rowH;
    }

    // Separator
    stroke(100, 100, 120, 100);
    strokeWeight(1);
    line(px + 10, sepY, px + pw - 10, sepY);
    noStroke();

    // Footer: focus info + Snap button
    int footerY = sepY + 6;

    if (focusBody != null && focusBody.a != 0) {
      fill(focusBody.col);
      textSize(14 * uiScale);
      textAlign(LEFT, CENTER);
      text("Focusing: " + focusBody.name, px + 12, footerY + 12);
    } else if (focusShip != null) {
      fill(255, 200, 50);
      textSize(14 * uiScale);
      textAlign(LEFT, CENTER);
      text("Focusing: " + focusShip.name, px + 12, footerY + 12);
    }

    // Snap button (always visible)
    int btnX = px + pw - 70;
    int btnY = footerY + 2;
    int btnW = 56;
    int btnH = 22;
    boolean hover = mouseX >= btnX && mouseX <= btnX + btnW &&
                    mouseY >= btnY && mouseY <= btnY + btnH;
    fill(hover ? color(80, 160, 220) : color(50, 120, 180));
    rect(btnX, btnY, btnW, btnH, 4);
    fill(255);
    textSize(13 * uiScale);
    textAlign(CENTER, CENTER);
    text("Snap", btnX + btnW / 2, btnY + btnH / 2);
  }

  void drawBodyRow(int px, int y, int pw, int rowH, CelestialBody body,
                   CelestialBody focusBody, CelestialBody selected) {
    boolean isFocused = (focusBody == body);
    boolean isSelected = (selected == body);
    boolean hover = mouseX >= px && mouseX <= px + pw &&
                    mouseY >= y && mouseY <= y + rowH;

    // Row highlight
    if (isFocused) {
      fill(255, 220, 100, 40);
      noStroke();
      rect(px + 4, y + 1, pw - 8, rowH - 2, 3);
    } else if (isSelected) {
      fill(255, 255, 255, 25);
      noStroke();
      rect(px + 4, y + 1, pw - 8, rowH - 2, 3);
    } else if (hover) {
      fill(255, 255, 255, 12);
      noStroke();
      rect(px + 4, y + 1, pw - 8, rowH - 2, 3);
    }

    // Color dot
    fill(body.col);
    noStroke();
    ellipse(px + 16, y + rowH / 2, 8, 8);

    // Name
    if (isFocused) {
      fill(255, 220, 100);
    } else if (isSelected) {
      fill(240);
    } else {
      fill(200);
    }
    textSize(15 * uiScale);
    textAlign(LEFT, CENTER);
    text(body.name, px + 32, y + rowH / 2);

    // Focus button on right side when selected and not already focused
    if (isSelected && !isFocused) {
      int btnX = px + pw - 58;
      int btnW = 48;
      int btnH = 18;
      int btnCY = y + rowH / 2;
      boolean btnHover = mouseX >= btnX && mouseX <= btnX + btnW &&
                         mouseY >= btnCY - btnH / 2 && mouseY <= btnCY + btnH / 2;
      fill(btnHover ? color(80, 160, 220) : color(50, 120, 180));
      noStroke();
      rect(btnX, btnCY - btnH / 2, btnW, btnH, 3);
      fill(255);
      textSize(12 * uiScale);
      textAlign(CENTER, CENTER);
      text("Focus", btnX + btnW / 2, btnCY);
    } else if (isFocused) {
      // Focused indicator
      fill(255, 220, 100, 150);
      noStroke();
      int cx = px + pw - 18;
      int cy = y + rowH / 2;
      ellipse(cx, cy, 9, 9);
    }
  }

  boolean handleClick(float mx, float my, CelestialBody sun,
                      List<CelestialBody> planets, CameraController cam) {
    int px = 10;
    int py = 230;
    int pw = 260;
    int rowH = 26;
    int headerH = 42;
    int bodyCount = 1 + planets.size();
    int rowsH = bodyCount * rowH;
    int sepY = py + headerH + rowsH + 4;
    int footerH = 34;
    int ph = headerH + rowsH + 8 + footerH;

    if (mx < px || mx > px + pw || my < py || my > py + ph) return false;

    // Check focus button on the currently selected row (must check before row click)
    if (selectedBody != null && selectedBody != cam.focusBody) {
      int selIdx = -1;
      if (selectedBody == sun) selIdx = 0;
      else selIdx = planets.indexOf(selectedBody) + 1;
      if (selIdx >= 0) {
        int btnRowY = py + headerH + selIdx * rowH;
        int btnX = px + pw - 58;
        int btnW = 48;
        int btnH = 18;
        int btnCY = btnRowY + rowH / 2;
        if (mx >= btnX && mx <= btnX + btnW &&
            my >= btnCY - btnH / 2 && my <= btnCY + btnH / 2) {
          CelestialBody toFocus = selectedBody;
          selectedBody = null;
          cam.focusOn(toFocus);
          return true;
        }
      }
    }

    // Check body rows
    int rowY = py + headerH;
    CelestialBody clickedBody = null;
    if (my >= rowY && my < rowY + rowH && mx >= px && mx <= px + pw) {
      clickedBody = sun;
    }
    rowY += rowH;
    for (int i = 0; i < planets.size(); i++) {
      if (my >= rowY && my < rowY + rowH && mx >= px && mx <= px + pw) {
        clickedBody = planets.get(i);
        break;
      }
      rowY += rowH;
    }

    if (clickedBody != null) {
      long now = millis();
      if (clickedBody == lastPanelClickBody &&
          now - lastPanelClickTime < PANEL_DOUBLE_CLICK_MS) {
        // Double-click — focus immediately
        selectedBody = null;
        lastPanelClickTime = 0;
        lastPanelClickBody = null;
        cam.focusOn(clickedBody);
        return true;
      }
      // Single click — select
      selectedBody = clickedBody;
      lastPanelClickTime = now;
      lastPanelClickBody = clickedBody;
      return true;
    }

    // Check Snap button
    int footerY = sepY + 6;
    int btnX = px + pw - 70;
    int btnY = footerY + 2;
    int btnW = 56;
    int btnH = 22;
    if (mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH) {
      selectedBody = null;
      doSnap(cam);
      return true;
    }

    // Click on panel but not on interactive element — deselect
    selectedBody = null;
    return false;
  }

  void doSnap(CameraController cam) {
    cam.snapFocus();
  }

  void drawPauseIndicator() {
    fill(255, 80, 80);
    textSize(30 * uiScale);
    textAlign(CENTER, CENTER);
    text("PAUSED", width / 2, height - 60);
  }

}