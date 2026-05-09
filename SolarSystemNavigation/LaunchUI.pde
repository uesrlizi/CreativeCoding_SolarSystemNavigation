class LaunchUI {
  String shipName = "";
  boolean inputFocused = false;
  int nameInputWidth = 150;

  LaunchUI() {
  }

  boolean isTextInputClicked(int mx, int my) {
    int panelX = 10;
    int panelY = height - 160;
    int inputX = panelX + 10;
    int inputY = panelY + 60;
    return mx >= inputX && mx <= inputX + nameInputWidth && my >= inputY && my <= inputY + 30;
  }

  void setInputFocus(boolean focused) {
    inputFocused = focused;
  }

  void draw() {
    drawLaunchPanel();
    drawTargetPanel();
    drawShipStatus();
  }

  void drawLaunchPanel() {
    int panelX = 10;
    int panelY = height - 160;
    int panelW = 200;
    int panelH = 150;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Launch Control", panelX + 10, panelY + 10);

    fill(180);
    textSize(14);
    text("Ship Name:", panelX + 10, panelY + 40);

    drawTextInput(panelX + 10, panelY + 60, nameInputWidth, 30);

    boolean canLaunch = launchController.canLaunch() && shipName.length() > 0;
    drawButton("LAUNCH [L]", panelX + 10, panelY + 100, 80, 35, canLaunch);

    textSize(11);
    fill(150);
    text(launchController.getStatusText(), panelX + 10, panelY + 140);
  }

  void drawTargetPanel() {
    if (launchController.getState() != ShipState.ORBIT &&
        launchController.getState() != ShipState.TRANSFER) return;

    int panelX = width - 270;
    int panelY = height - 320;
    int panelW = 260;
    int panelH = 250;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Mission Target", panelX + 10, panelY + 10);

    for (int idx = 0; idx < solarSystem.planets.size(); idx++) {
      CelestialBody p = solarSystem.planets.get(idx);
      int rowY = panelY + 40 + idx * 30;

      boolean isSelected = (launchController.getSelectedTarget() == p);
      if (isSelected) {
        fill(50, 80, 50, 200);
        noStroke();
        rect(panelX + 5, rowY - 3, panelW - 10, 26, 4);
      }

      fill(p.col);
      textSize(14);
      text((idx + 1) + ". " + p.name, panelX + 15, rowY);

      if (isSelected) {
        fill(100, 200, 100);
        textSize(11);
        text("Selected", panelX + 150, rowY + 2);
      }
    }

    boolean canTransfer = launchController.canTransfer();
    drawButton("TRANSFER [T]", panelX + 10, panelY + 220, 100, 25, canTransfer);
  }

  void drawShipStatus() {
    if (launchController.getCurrentShip() == null) return;

    int panelX = width - 270;
    int panelY = height - 370;
    int panelW = 260;
    int panelH = 50;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    Spacecraft ship = launchController.getCurrentShip();
    fill(100, 200, 100);
    textSize(14);
    textAlign(LEFT, TOP);
    text("Ship: " + ship.name, panelX + 10, panelY + 8);

    fill(180);
    textSize(12);
    double altitude = (ship.a - 6371000) / 1000.0;
    text(String.format("Alt: %.0f km", altitude), panelX + 10, panelY + 28);
  }

  void drawTextInput(int x, int y, int w, int h) {
    stroke(100);
    strokeWeight(1);
    noFill();
    rect(x, y, w, h, 4);

    fill(inputFocused ? 255 : 200);
    noStroke();
    textSize(14);
    textAlign(LEFT, CENTER);
    String display = shipName;
    if (inputFocused && (frameCount / 30) % 2 == 0) {
      display += "_";
    }
    text(display.length() > 0 ? display : "Enter name...", x + 5, y + h / 2);
  }

  void drawButton(String label, int x, int y, int w, int h, boolean enabled) {
    if (enabled) {
      fill(50, 150, 50);
    } else {
      fill(80, 80, 80);
    }
    noStroke();
    rect(x, y, w, h, 6);

    fill(enabled ? 255 : 150);
    textSize(14);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  boolean isLaunchButtonClicked(int mx, int my) {
    int bx = 10 + 10;
    int by = height - 160 + 100;
    return mx >= bx && mx <= bx + 80 && my >= by && my <= by + 35;
  }

  boolean isTargetClicked(int mx, int my, int idx) {
    int panelX = width - 270;
    int panelY = height - 320;
    int rowY = panelY + 40 + idx * 30;
    return mx >= panelX && mx <= panelX + 260 && my >= rowY && my <= rowY + 26;
  }

  boolean isTransferButtonClicked(int mx, int my) {
    int bx = width - 270 + 10;
    int by = height - 320 + 220;
    return mx >= bx && mx <= bx + 100 && my >= by && my <= by + 25;
  }

  void handleClick(int mx, int my) {
    boolean wasInputFocused = inputFocused;
    inputFocused = isTextInputClicked(mx, my);
    
    if (inputFocused) {
      return;
    }
    
    if (launchController.canLaunch() && shipName.length() > 0) {
      if (isLaunchButtonClicked(mx, my)) {
        launchController.startLaunch(shipName);
        return;
      }
    }

    if (launchController.canSelectTarget()) {
      for (int idx = 0; idx < solarSystem.planets.size(); idx++) {
        if (isTargetClicked(mx, my, idx)) {
          launchController.selectTarget(solarSystem.planets.get(idx));
          return;
        }
      }

      if (isTransferButtonClicked(mx, my) && launchController.canTransfer()) {
        launchController.initiateTransfer();
      }
    }
  }

  void keyPressed(char keyChar) {
    if (keyChar == BACKSPACE) {
      if (shipName.length() > 0) {
        shipName = shipName.substring(0, shipName.length() - 1);
      }
    } else if (keyChar == ENTER || keyChar == RETURN) {
      if (launchController.canLaunch() && shipName.length() > 0) {
        launchController.startLaunch(shipName);
      }
    } else if (keyChar >= 32 && keyChar <= 126) {
      if (shipName.length() < 20) {
        shipName += keyChar;
      }
    }
  }
}
