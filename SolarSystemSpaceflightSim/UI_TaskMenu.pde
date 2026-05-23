// ========== TASK MENU PANEL ==========

class TaskMenu implements DrawerContent {
  float panelX, panelY, panelW, panelH;
  float rowH, headerH, detailH, footerH;
  float panelMargin;

  List<MissionPreset> availablePresets;
  MissionPreset selectedPreset;
  MissionValidationResult validationResult;
  int hoveredIndex;
  int hoveredFrames;
  boolean startButtonHover;
  int buttonHoverFrames;

  MissionExecutorState lastExecutorState;

  // 保存抽屉当前位置
  float currentDrawerX = 0;
  float currentDrawerY = 0;
  float currentDrawerW = 0;

  TaskMenu() {
    float scale = uiScale;
    panelX = width - 310 * scale;
    panelY = 120 * scale;
    panelW = 290; // 使用像素值，与 DrawerPanel 传入的一致
    rowH = 32 * scale;
    headerH = 48 * scale;
    detailH = 140 * scale;
    footerH = 70 * scale;
    panelMargin = 14 * scale;
    hoveredIndex = -1;
    hoveredFrames = 0;
    startButtonHover = false;
    buttonHoverFrames = 0;
    selectedPreset = null;
    validationResult = null;
    lastExecutorState = MissionExecutorState.IDLE;
  }

  void refreshAvailablePresets() {
    availablePresets = getAvailableMissionPresets(solarSystem);
    if (selectedPreset != null && isMissionLocked(selectedPreset)) {
      selectedPreset = null;
      validationResult = null;
    }
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

  // ========== DrawerContent 接口实现 ==========

  // 保存抽屉位置供 updateContent 使用
  float drawerX = 0;
  float drawerY = 0;
  float drawerW = 0;

  public void updateContent(float drawerX, float drawerY, float drawerW) {
    float scale = uiScale;

    MissionExecutorState currentState = missionExecutor.state;
    if (lastExecutorState != currentState) {
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

    // 保存抽屉位置 - DrawerPanel 传入的就是实际像素值
    this.currentDrawerX = drawerX;
    this.currentDrawerY = drawerY;
    this.currentDrawerW = drawerW;

    float originalX = panelX;
    float originalY = panelY;
    float originalW = panelW;
    panelX = drawerX;
    panelY = drawerY;
    panelW = drawerW;

    int presetCount = (availablePresets != null) ? availablePresets.size() : 0;
    panelH = headerH + presetCount * rowH + detailH + footerH + 8 * scale;

    boolean hitPanel = (mouseX >= panelX && mouseX <= panelX + panelW &&
                       mouseY >= panelY && mouseY <= panelY + panelH);

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

    if (startButtonHover) {
      buttonHoverFrames++;
    } else {
      buttonHoverFrames = 0;
    }

    panelX = originalX;
    panelY = originalY;
    panelW = originalW;
  }

  public void drawContent(float drawX, float drawY, float drawW, float drawH) {
    float scale = uiScale;
    float originalX = panelX;
    float originalY = panelY;
    float originalW = panelW;

    // 保存抽屉位置供 update 使用
    currentDrawerX = drawX;
    currentDrawerY = drawY;
    currentDrawerW = drawW;

    panelX = drawX;
    panelY = drawY;
    panelW = drawW;  // DrawerPanel 传入的就是实际像素值

    pushStyle();

    int presetCount = (availablePresets != null) ? availablePresets.size() : 0;
    panelH = headerH + presetCount * rowH + detailH + footerH + 8 * scale;

    fill(180, 200, 220);
    textSize(11 * scale);
    String statusText;
    if (missionExecutor.hasActiveMission()) {
      statusText = missionExecutor.getDetailedStatus();
    } else {
      statusText = getProgressStatusText();
    }
    text(statusText, panelX + panelMargin, panelY + panelMargin + 4);

    float rowY = panelY + headerH;
    if (availablePresets != null) {
      for (int i = 0; i < availablePresets.size(); i++) {
        MissionPreset p = availablePresets.get(i);
        drawPresetRow(rowY, p, p == selectedPreset, i);
        rowY += rowH;
      }
    }

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

    float footerY = detailY + detailH;
    float btnX = panelX + panelW - 100 * scale;
    float btnY = footerY + 15 * scale;
    float btnW = 80 * scale;
    float btnH = 32 * scale;

    boolean missionInProgress = missionExecutor.hasActiveMission();
    boolean canStart = selectedPreset != null && !missionInProgress;

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

    if (missionInProgress) {
      // 只显示简单的状态提示
      fill(220, 180, 80);
      textSize(11 * scale);
      textAlign(LEFT, CENTER);
      text("Mission in progress...", panelX + panelMargin, footerY + 31 * scale);
    }

    popStyle();

    panelX = originalX;
    panelY = originalY;
    panelW = originalW;
  }

  public boolean handleContentClick(float mx, float my, float contentX, float contentY, float contentW) {
    float scale = uiScale;
    float originalX = panelX;
    float originalY = panelY;
    float originalW = panelW;

    // 保存抽屉位置
    currentDrawerX = contentX;
    currentDrawerY = contentY;
    currentDrawerW = contentW;

    panelX = contentX;
    panelY = contentY;
    panelW = contentW;  // 使用传入的宽度，DrawerPanel 传入的就是实际像素值

    int presetCount = (availablePresets != null) ? availablePresets.size() : 0;

    float listY = panelY + headerH;
    if (availablePresets != null && my >= listY && my < listY + presetCount * rowH) {
      int idx = (int)((my - listY) / rowH);
      if (idx >= 0 && idx < availablePresets.size()) {
        selectedPreset = availablePresets.get(idx);
        panelX = originalX;
        panelY = originalY;
        panelW = originalW;
        return true;
      }
    }

    float footerY = panelY + headerH + presetCount * rowH + detailH + 8 * scale;
    float btnX = panelX + panelW - 100 * scale;
    float btnY = footerY + 15 * scale;
    float btnW = 80 * scale;
    float btnH = 32 * scale;

    boolean missionInProgress = missionExecutor.hasActiveMission();

    if (mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH) {
      if (selectedPreset != null && !missionInProgress) {
        startMission(selectedPreset);
      }
      panelX = originalX;
      panelY = originalY;
      panelW = originalW;
      return true;
    }

    panelX = originalX;
    panelY = originalY;
    panelW = originalW;
    return true;
  }

  public String getContentTooltip() {
    if (buttonHoverFrames >= Button.TOOLTIP_DELAY && startButtonHover) {
      return "Start selected mission";
    }
    return null;
  }

  public float[] getContentTooltipSource() {
    float scale = uiScale;
    // If START button is hovered, use its position
    if (buttonHoverFrames >= Button.TOOLTIP_DELAY && startButtonHover) {
      float useX = (currentDrawerX != 0) ? currentDrawerX : panelX;
      float useY = (currentDrawerY != 0) ? currentDrawerY : panelY;
      float useW = (currentDrawerW != 0) ? currentDrawerW : panelW;
      int presetCount = (availablePresets != null) ? availablePresets.size() : 0;
      float footerY = useY + headerH + presetCount * rowH + detailH + 8 * scale;
      float btnX = useX + useW - 100 * scale;
      float btnY = footerY + 15 * scale;
      float btnW = 80 * scale;
      float btnH = 32 * scale;
      return new float[] { btnX, btnY, btnW, btnH };
    }
    // Fallback to full panel
    float useX = (currentDrawerX != 0) ? currentDrawerX : panelX;
    float useY = (currentDrawerY != 0) ? currentDrawerY : panelY;
    float useW = (currentDrawerW != 0) ? currentDrawerW : panelW;
    return new float[] { useX, useY, useW, panelH };
  }

  public float getContentHeight() {
    float scale = uiScale;
    int presetCount = (availablePresets != null) ? availablePresets.size() : 0;
    return headerH + presetCount * rowH + detailH + footerH + 8 * scale;
  }

  public boolean shouldBeVisible() {
    return true;  // 任务面板始终可见
  }

  // ========== 原有方法 ==========

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

    if (isSelected) {
      fill(255, 200, 100, 50);
    } else if (isHovered) {
      fill(255, 255, 255, 15);
    }
    if (isSelected || isHovered) {
      noStroke();
      rect(panelX + 6 * scale, y + 2, panelW - 12 * scale, rowH - 4, 6 * scale);
    }

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

  void startMission(MissionPreset preset) {
    println("[TaskMenu] ========== Starting mission: " + preset.name + " ==========");
    CelestialBody body = preset.initialBody;
    if (body == null) {
      println("[TaskMenu] FAILED: initialBody is null");
      return;
    }

    Spacecraft ship;
    if (solarSystem.ships.size() > 0) {
      ship = solarSystem.ships.get(0);
      println("[TaskMenu] Using existing spacecraft");
    } else {
      ship = createSpacecraftFromPreset(preset.requiredSpacecraftPreset);
      if (ship == null) {
        println("[TaskMenu] FAILED: Could not create spacecraft from preset");
        return;
      }
      solarSystem.ships.add(ship);
      println("[TaskMenu] Created new spacecraft");
    }

    boolean isLaunchMission = (preset.goal.type == MissionGoalType.LAUNCH_TO_ORBIT);
    boolean isReturnMission = (preset.goal.type == MissionGoalType.RETURN_TO_LAUNCHSITE);
    println("[TaskMenu] isLaunchMission=" + isLaunchMission + ", isReturnMission=" + isReturnMission);

    if (isLaunchMission) {
      LaunchSite site = getLaunchSiteForBody(body);
      if (site != null) {
        ship.initOnLaunchPad(body, site);
        println("[TaskMenu] Initialized spacecraft on launch pad");
      }
    }

    println("[TaskMenu] Validating mission...");
    validationResult = missionValidator.validateMission(preset, ship, solarSystem, timeManager.simTime);
    if (!validationResult.canExecute) {
      println("[TaskMenu] FAILED: " + validationResult.reason);
      return;
    }
    println("[TaskMenu] Validation passed: " + validationResult.reason);

    if (trajectoryPredictor != null) {
      trajectoryPredictor.markDirty();
    }

    MissionTask task = new MissionTask(preset);
    List<ManeuverNode> maneuvers = validationResult.maneuvers;
    println("[TaskMenu] Calling missionExecutor.startMission()...");
    missionExecutor.startMission(task, maneuvers, ship, solarSystem, timeManager.simTime);
    println("[TaskMenu] ========== Mission startup complete ==========");
  }

  LaunchSite getLaunchSiteForBody(CelestialBody body) {
    return launchSite;
  }
}
