// ========== TASK MENU PANEL ==========

class TaskMenu {
  boolean visible;
  float panelX, panelY, panelW, panelH;
  float rowH, headerH, detailH, footerH;
  float panelMargin;

  List<MissionPreset> availablePresets;
  MissionPreset selectedPreset;
  MissionValidationResult validationResult;
  int hoveredIndex;
  int hoveredFrames;
  boolean closeButtonHover;
  boolean startButtonHover;
  int buttonHoverFrames;

  MissionExecutorState lastExecutorState;  // 跟踪执行器状态变化

  TaskMenu() {
    visible = false;
    float scale = uiScale;
    panelX = width - 320 * scale;
    panelY = 120 * scale;
    panelW = 300 * scale;
    rowH = 32 * scale;
    headerH = 48 * scale;
    detailH = 140 * scale;
    footerH = 70 * scale;
    panelMargin = 12 * scale;
    hoveredIndex = -1;
    hoveredFrames = 0;
    closeButtonHover = false;
    startButtonHover = false;
    buttonHoverFrames = 0;
    selectedPreset = null;
    validationResult = null;
    lastExecutorState = MissionExecutorState.IDLE;
  }

  void toggle() {
    visible = !visible;
    if (visible) {
      refreshAvailablePresets();
    }
  }

  void refreshAvailablePresets() {
    availablePresets = getAvailableMissionPresets(solarSystem);
    // 如果之前选中的任务不再可用，清空选择
    if (selectedPreset != null && isMissionLocked(selectedPreset)) {
      selectedPreset = null;
      validationResult = null;
    }
    // 默认选中第一个可用任务
    if (selectedPreset == null && availablePresets.size() > 0) {
      selectedPreset = availablePresets.get(0);
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

    // 检测任务执行器状态变化 - 当任务完成时刷新可用任务列表
    MissionExecutorState currentState = missionExecutor.state;
    if (lastExecutorState != currentState) {
      // 检测是否从执行中状态变为完成/失败状态
      boolean wasInProgress = (lastExecutorState == MissionExecutorState.WAITING_FOR_MANEUVER ||
                               lastExecutorState == MissionExecutorState.ORIENTING ||
                               lastExecutorState == MissionExecutorState.BURNING);
      boolean isDone = (currentState == MissionExecutorState.COMPLETED ||
                        currentState == MissionExecutorState.FAILED);

      if (wasInProgress && isDone) {
        refreshAvailablePresets();
      }
      lastExecutorState = currentState;
    }

    panelX = width - 320 * scale;
    int presetCount = (availablePresets != null) ? availablePresets.size() : 0;
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
    float btnY = footerY + 15 * scale;
    float btnW = 80 * scale;
    float btnH = 32 * scale;
    startButtonHover = (mouseX >= btnX && mouseX <= btnX + btnW &&
                        mouseY >= btnY && mouseY <= btnY + btnH);

    if (startButtonHover || closeButtonHover) {
      buttonHoverFrames++;
    } else {
      buttonHoverFrames = 0;
    }
  }

  void draw() {
    if (!visible) return;
    float scale = uiScale;

    pushStyle();

    int presetCount = (availablePresets != null) ? availablePresets.size() : 0;
    panelH = headerH + presetCount * rowH + detailH + footerH + 8 * scale;

    noStroke();
    fill(0, 0, 0, 170);
    rect(panelX, panelY, panelW, panelH, 10 * scale);

    // 标题栏
    fill(255, 200, 100);
    textSize(18 * scale);
    textAlign(LEFT, TOP);
    text("MISSIONS", panelX + panelMargin, panelY + panelMargin + 4);

    // 显示当前进度状态
    fill(180, 200, 220);
    textSize(11 * scale);
    String statusText = getProgressStatusText();
    text(statusText, panelX + panelMargin, panelY + headerH - 22 * scale);

    // 关闭按钮
    float closeX = panelX + panelW - 28 * scale;
    float closeY = panelY + 8 * scale;
    float closeSize = 22 * scale;
    fill(closeButtonHover ? color(220, 100, 100) : color(160, 70, 70));
    rect(closeX, closeY, closeSize, closeSize, 5 * scale);
    fill(255);
    textSize(16 * scale);
    textAlign(CENTER, CENTER);
    text("×", closeX + closeSize / 2, closeY + closeSize / 2);

    // 任务列表
    float rowY = panelY + headerH;
    if (availablePresets != null) {
      for (int i = 0; i < availablePresets.size(); i++) {
        MissionPreset p = availablePresets.get(i);
        drawPresetRow(rowY, p, p == selectedPreset, i);
        rowY += rowH;
      }
    }

    // 任务详情区域
    float detailY = rowY;
    fill(15, 25, 45, 120);
    rect(panelX + panelMargin, detailY + 4 * scale, panelW - 2 * panelMargin, detailH - 8 * scale, 6 * scale);

    if (selectedPreset != null) {
      fill(255, 200, 100);
      textSize(15 * scale);
      textAlign(LEFT, TOP);
      text(selectedPreset.name, panelX + panelMargin + 10 * scale, detailY + 14 * scale);

      fill(220, 230, 240);
      textSize(12 * scale);
      String desc = selectedPreset.description;
      float maxW = panelW - 2 * panelMargin - 20 * scale;
      float textY = detailY + 40 * scale;
      float lineH = 17 * scale;
      drawWrappedText(desc, panelX + panelMargin + 10 * scale, textY, maxW, lineH);
    } else {
      fill(140);
      textSize(12 * scale);
      textAlign(LEFT, TOP);
      text("No mission available", panelX + panelMargin + 10 * scale, detailY + 50 * scale);
    }

    // 底部区域 - START按钮
    float footerY = detailY + detailH;
    float btnX = panelX + panelW - 100 * scale;
    float btnY = footerY + 15 * scale;
    float btnW = 80 * scale;
    float btnH = 32 * scale;

    boolean missionInProgress = (missionExecutor.state != MissionExecutorState.IDLE &&
                                 missionExecutor.state != MissionExecutorState.COMPLETED &&
                                 missionExecutor.state != MissionExecutorState.FAILED);
    boolean canStart = selectedPreset != null && !missionInProgress;

    // 绘制按钮
    if (canStart) {
      fill(startButtonHover ? color(80, 200, 110) : color(60, 160, 80));
    } else {
      fill(60, 60, 60);
    }
    rect(btnX, btnY, btnW, btnH, 7 * scale);
    fill(canStart ? 255 : 120);
    textSize(14 * scale);
    textAlign(CENTER, CENTER);
    text("START", btnX + btnW / 2, btnY + btnH / 2);

    // 任务进行中显示状态
    if (missionInProgress) {
      fill(220, 180, 80);
      textSize(11 * scale);
      textAlign(LEFT, CENTER);
      text("Mission in progress...", panelX + panelMargin, footerY + 31 * scale);
    }

    popStyle();
  }

  String getProgressStatusText() {
    switch (currentGameProgress) {
      case GROUNDED:
        return "Status: Grounded at launch site";
      case IN_LEO:
        return "Status: In Low Earth Orbit";
      case IN_GEO:
        return "Status: In Geostationary Orbit";
      case AT_MOON:
        return "Status: At the Moon";
      default:
        return "";
    }
  }

  void drawPresetRow(float y, MissionPreset preset, boolean isSelected, int idx) {
    float scale = uiScale;
    boolean isHovered = (hoveredIndex == idx);

    // 背景
    if (isSelected) {
      fill(255, 200, 100, 50);
    } else if (isHovered) {
      fill(255, 255, 255, 15);
    }
    if (isSelected || isHovered) {
      noStroke();
      rect(panelX + 6 * scale, y + 2, panelW - 12 * scale, rowH - 4, 6 * scale);
    }

    // 任务名称
    fill(isSelected ? color(255, 220, 120) : 210);
    textSize(14 * scale);
    textAlign(LEFT, CENTER);
    text(preset.name, panelX + panelMargin + 8 * scale, y + rowH / 2);
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
    int presetCount = (availablePresets != null) ? availablePresets.size() : 0;

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
    if (availablePresets != null && my >= listY && my < listY + presetCount * rowH) {
      int idx = (int)((my - listY) / rowH);
      if (idx >= 0 && idx < availablePresets.size()) {
        selectedPreset = availablePresets.get(idx);
        return true;
      }
    }

    float footerY = panelY + headerH + presetCount * rowH + detailH + 8 * scale;
    float btnX = panelX + panelW - 100 * scale;
    float btnY = footerY + 15 * scale;
    float btnW = 80 * scale;
    float btnH = 32 * scale;

    boolean missionInProgress = (missionExecutor.state != MissionExecutorState.IDLE &&
                                 missionExecutor.state != MissionExecutorState.COMPLETED &&
                                 missionExecutor.state != MissionExecutorState.FAILED);

    if (mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH) {
      if (selectedPreset != null && !missionInProgress) {
        startMission(selectedPreset);
      }
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

    // 检查是否是发射任务
    boolean isLaunchMission = (preset.goal.type == MissionGoalType.LAUNCH_TO_ORBIT);

    if (isLaunchMission) {
      // 发射任务：重置到发射场
      LaunchSite site = getLaunchSiteForBody(body);
      if (site != null) {
        ship.initOnLaunchPad(body, site);
      }
    }
    // 普通任务（GEO、月球转移）：不重置轨道，从当前位置继续

    // 验证并计算机动
    validationResult = missionValidator.validateMission(preset, ship, solarSystem, timeManager.simTime);
    if (!validationResult.canExecute) {
      return; // 验证失败，不开始
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

  LaunchSite getLaunchSiteForBody(CelestialBody body) {
    return launchSite;
  }

  String getHoveredTooltipText() {
    if (!visible) return null;
    if (buttonHoverFrames >= Button.TOOLTIP_DELAY) {
      if (closeButtonHover) return "Close menu";
      if (startButtonHover) return "Start selected mission";
    }
    return null;
  }
}
