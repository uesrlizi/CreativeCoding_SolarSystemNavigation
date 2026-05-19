// ========== TASK MENU PANEL ==========

class TaskMenu {
  boolean visible;
  float panelX, panelY, panelW, panelH;
  float rowH, headerH, detailH, footerH;
  float panelMargin;

  List<MissionPreset> presets;
  MissionPreset selectedPreset;
  MissionValidationResult validationResult;
  int hoveredIndex;
  int hoveredFrames;
  boolean closeButtonHover;
  boolean startButtonHover;
  boolean abortButtonHover;
  int buttonHoverFrames;

  TaskMenu() {
    visible = false;
    float scale = uiScale;
    panelX = width - 320 * scale;
    panelY = 120 * scale;
    panelW = 300 * scale;
    rowH = 26 * scale;
    headerH = 42 * scale;
    detailH = 160 * scale;
    footerH = 80 * scale;
    panelMargin = 10 * scale;
    hoveredIndex = -1;
    hoveredFrames = 0;
    closeButtonHover = false;
    startButtonHover = false;
    abortButtonHover = false;
    buttonHoverFrames = 0;
    selectedPreset = null;
    validationResult = null;
  }

  void toggle() {
    visible = !visible;
    if (visible && presets == null) {
      presets = getAllMissionPresets(solarSystem);
    }
    if (visible) {
      validateSelected();
    }
  }

  void validateSelected() {
    if (selectedPreset == null || solarSystem.ships.size() == 0) {
      validationResult = null;
      return;
    }
    Spacecraft craft = solarSystem.ships.get(0);
    validationResult = missionValidator.validateMission(selectedPreset, craft, solarSystem, timeManager.simTime);
  }

  void update() {
    if (!visible) return;
    float scale = uiScale;

    panelX = width - 320 * scale;
    int presetCount = (presets != null) ? presets.size() : 0;
    panelH = headerH + presetCount * rowH + detailH + footerH + 8 * scale;

    boolean hitPanel = (mouseX >= panelX && mouseX <= panelX + panelW &&
                       mouseY >= panelY && mouseY <= panelY + panelH);

    float closeX = panelX + panelW - 28 * scale;
    float closeY = panelY + 8 * scale;
    float closeSize = 22 * scale;
    closeButtonHover = (mouseX >= closeX && mouseX <= closeX + closeSize &&
                       mouseY >= closeY && mouseY <= closeY + closeSize);

    float listY = panelY + headerH;
    if (hitPanel && mouseY >= listY && mouseY < listY + presetCount * rowH) {
      int idx = (int)((mouseY - listY) / rowH);
      if (idx == hoveredIndex) {
        hoveredFrames++;
      } else {
        hoveredIndex = idx;
        hoveredFrames = 1;
      }
    } else {
      hoveredIndex = -1;
      hoveredFrames = 0;
    }

    float footerY = panelY + headerH + presetCount * rowH + detailH + 8 * scale;
    float btnX = panelX + panelW - 100 * scale;
    float btnY = footerY + 10 * scale;
    float btnW = 80 * scale;
    float btnH = 28 * scale;
    startButtonHover = (mouseX >= btnX && mouseX <= btnX + btnW &&
                        mouseY >= btnY && mouseY <= btnY + btnH);

    float abortBtnY = footerY + 44 * scale;
    abortButtonHover = (mouseX >= btnX && mouseX <= btnX + btnW &&
                       mouseY >= abortBtnY && mouseY <= abortBtnY + btnH);

    if (startButtonHover || closeButtonHover || abortButtonHover) {
      buttonHoverFrames++;
    } else {
      buttonHoverFrames = 0;
    }
  }

  void draw() {
    if (!visible) return;
    float scale = uiScale;

    pushStyle();

    int presetCount = (presets != null) ? presets.size() : 0;
    panelH = headerH + presetCount * rowH + detailH + footerH + 8 * scale;

    noStroke();
    fill(0, 0, 0, 160);
    rect(panelX, panelY, panelW, panelH, 8 * scale);

    fill(200);
    textSize(16 * scale);
    textAlign(LEFT, TOP);
    text("MISSIONS", panelX + panelMargin, panelY + panelMargin);

    float closeX = panelX + panelW - 28 * scale;
    float closeY = panelY + 8 * scale;
    float closeSize = 22 * scale;
    fill(closeButtonHover ? color(220, 100, 100) : color(180, 80, 80));
    rect(closeX, closeY, closeSize, closeSize, 4 * scale);
    fill(255);
    textSize(16 * scale);
    textAlign(CENTER, CENTER);
    text("×", closeX + closeSize / 2, closeY + closeSize / 2);

    float rowY = panelY + headerH;
    if (presets != null) {
      for (int i = 0; i < presets.size(); i++) {
        MissionPreset p = presets.get(i);
        drawPresetRow(rowY, p, p == selectedPreset, i);
        rowY += rowH;
      }
    }

    float detailY = rowY;
    fill(10, 20, 40, 100);
    rect(panelX + panelMargin, detailY + 4 * scale, panelW - 2 * panelMargin, detailH - 8 * scale, 4 * scale);

    if (selectedPreset != null) {
      fill(255, 200, 100);
      textSize(14 * scale);
      textAlign(LEFT, TOP);
      text(selectedPreset.name, panelX + panelMargin + 8 * scale, detailY + 12 * scale);

      fill(220);
      textSize(12 * scale);
      String desc = selectedPreset.description;
      float maxW = panelW - 2 * panelMargin - 16 * scale;
      float textY = detailY + 36 * scale;
      float lineH = 16 * scale;
      drawWrappedText(desc, panelX + panelMargin + 8 * scale, textY, maxW, lineH);

      float valY = detailY + 80 * scale;
      if (validationResult != null) {
        if (validationResult.canExecute) {
          fill(100, 255, 100);
        } else {
          fill(255, 100, 100);
        }
        textSize(11 * scale);
        drawWrappedText(validationResult.reason, panelX + panelMargin + 8 * scale, valY, maxW, lineH);

        if (validationResult.requiredDeltaV > 0) {
          fill(200, 200, 255);
          textSize(12 * scale);
          text(String.format("Δv: %.3f km/s", validationResult.requiredDeltaV),
               panelX + panelMargin + 8 * scale, valY + 40 * scale);
        }
      } else {
        fill(150);
        textSize(11 * scale);
        text("Validation pending...", panelX + panelMargin + 8 * scale, valY);
      }
    } else {
      fill(150);
      textSize(12 * scale);
      textAlign(LEFT, TOP);
      text("Select a mission...", panelX + panelMargin + 8 * scale, detailY + 40 * scale);
    }

    float footerY = detailY + detailH;
    float btnX = panelX + panelW - 100 * scale;
    float btnY = footerY + 10 * scale;
    float btnW = 80 * scale;
    float btnH = 28 * scale;

    boolean canStart = selectedPreset != null && validationResult != null && validationResult.canExecute;
    if (canStart) {
      fill(startButtonHover ? color(80, 200, 100) : color(60, 160, 80));
    } else {
      fill(80, 80, 80);
    }
    rect(btnX, btnY, btnW, btnH, 6 * scale);
    fill(canStart ? 255 : 120);
    textSize(14 * scale);
    textAlign(CENTER, CENTER);
    text("START", btnX + btnW / 2, btnY + btnH / 2);

    boolean canAbort = missionExecutor.state == MissionExecutorState.WAITING_FOR_MANEUVER ||
                       missionExecutor.state == MissionExecutorState.ORIENTING ||
                       missionExecutor.state == MissionExecutorState.BURNING;
    float abortBtnY = footerY + 44 * scale;
    if (canAbort) {
      fill(abortButtonHover ? color(220, 80, 80) : color(180, 60, 60));
    } else {
      fill(60, 60, 60);
    }
    rect(btnX, abortBtnY, btnW, btnH, 6 * scale);
    fill(canAbort ? 255 : 100);
    textSize(14 * scale);
    textAlign(CENTER, CENTER);
    text("ABORT", btnX + btnW / 2, abortBtnY + btnH / 2);

    if (missionExecutor.state != MissionExecutorState.IDLE) {
      fill(200);
      textSize(11 * scale);
      textAlign(LEFT, CENTER);
      text(missionExecutor.statusText, panelX + panelMargin, footerY + 24 * scale);

      float progressW = (panelW - 2 * panelMargin - btnW - 10 * scale);
      float progressX = panelX + panelMargin;
      float progressY = footerY + 50 * scale;
      float progressH = 10 * scale;
      fill(60);
      rect(progressX, progressY, progressW, progressH, 4 * scale);
      fill(80, 160, 220);
      rect(progressX, progressY, (float)(progressW * missionExecutor.progress), progressH, 4 * scale);
    }

    popStyle();
  }

  void drawPresetRow(float y, MissionPreset preset, boolean isSelected, int idx) {
    float scale = uiScale;
    boolean isHovered = (hoveredIndex == idx);

    if (isSelected) {
      fill(255, 220, 100, 40);
    } else if (isHovered) {
      fill(255, 255, 255, 12);
    }
    if (isSelected || isHovered) {
      noStroke();
      rect(panelX + 4 * scale, y + 1, panelW - 8 * scale, rowH - 2, 3 * scale);
    }

    fill(isSelected ? color(255, 220, 100) : 200);
    textSize(14 * scale);
    textAlign(LEFT, CENTER);
    text(preset.name, panelX + panelMargin + 4 * scale, y + rowH / 2);
  }

  void drawWrappedText(String text, float x, float y, float maxW, float lineH) {
    String[] words = text.split(" ");
    String line = "";
    float currentY = y;

    for (String word : words) {
      String testLine = line.length() > 0 ? line + " " + word : word;
      float w = textWidth(testLine);

      if (w > maxW && line.length() > 0) {
        text(line, x, currentY);
        currentY += lineH;
        line = word;
      } else {
        line = testLine;
      }
    }

    if (line.length() > 0) {
      text(line, x, currentY);
    }
  }

  boolean handleClick(float mx, float my) {
    if (!visible) return false;

    float scale = uiScale;
    int presetCount = (presets != null) ? presets.size() : 0;

    if (mx < panelX || mx > panelX + panelW || my < panelY || my > panelY + panelH) {
      return false;
    }

    float closeX = panelX + panelW - 28 * scale;
    float closeY = panelY + 8 * scale;
    float closeSize = 22 * scale;
    if (mx >= closeX && mx <= closeX + closeSize &&
        my >= closeY && my <= closeY + closeSize) {
      visible = false;
      return true;
    }

    float listY = panelY + headerH;
    if (presets != null && my >= listY && my < listY + presetCount * rowH) {
      int idx = (int)((my - listY) / rowH);
      if (idx >= 0 && idx < presets.size()) {
        selectedPreset = presets.get(idx);
        validateSelected();
        return true;
      }
    }

    float footerY = panelY + headerH + presetCount * rowH + detailH + 8 * scale;
    float btnX = panelX + panelW - 100 * scale;
    float btnY = footerY + 10 * scale;
    float btnW = 80 * scale;
    float btnH = 28 * scale;

    if (mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH) {
      if (selectedPreset != null && validationResult != null && validationResult.canExecute) {
        startMission(selectedPreset);
      }
      return true;
    }

    float abortBtnY = footerY + 44 * scale;
    if (mx >= btnX && mx <= btnX + btnW && my >= abortBtnY && my <= abortBtnY + btnH) {
      missionExecutor.abortMission();
      return true;
    }

    return true;
  }

  void startMission(MissionPreset preset) {
    CelestialBody body = preset.initialBody;
    if (body == null) return;

    Spacecraft ship;
    if (solarSystem.ships.size() > 0) {
      ship = solarSystem.ships.get(0);
    } else {
      ship = createSpacecraftFromPreset(preset.requiredSpacecraftPreset);
      if (ship == null) return;
      solarSystem.ships.add(ship);
    }

    ship.referenceBody = body;
    if (preset.initialOrbit != null) {
      ship.orbit = new Orbit(
        preset.initialOrbit.a,
        preset.initialOrbit.e,
        preset.initialOrbit.w,
        preset.initialOrbit.M0,
        timeManager.simTime,
        preset.initialOrbit.period,
        body
      );
      ship.updateOnRails(timeManager.simTime);
    }

    camera.focusOn(ship);
    camera.followShip(ship);
    camera.snapFocus();

    if (trajectoryPredictor != null) {
      trajectoryPredictor.markDirty();
    }

    MissionTask task = new MissionTask(preset);
    List<ManeuverNode> maneuvers = validationResult.maneuvers;
    missionExecutor.startMission(task, maneuvers, ship, solarSystem, timeManager.simTime);
  }

  String getHoveredTooltipText() {
    if (!visible) return null;
    if (buttonHoverFrames >= Button.TOOLTIP_DELAY) {
      if (closeButtonHover) return "Close menu";
      if (startButtonHover) return "Start selected mission";
      if (abortButtonHover) return "Abort current mission";
    }
    return null;
  }
}
