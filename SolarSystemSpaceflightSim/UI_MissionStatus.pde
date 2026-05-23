// ========== MISSION STATUS DRAWER CONTENT ==========

class MissionStatusContent implements DrawerContent {
  float margin;
  float rowH;
  float currentDrawerX, currentDrawerY, currentDrawerW;

  MissionStatusContent() {
    float scale = uiScale;
    margin = 12 * scale;
    rowH = 20 * scale;
    currentDrawerX = 0;
    currentDrawerY = 0;
    currentDrawerW = 0;
  }

  public void updateContent(float drawerX, float drawerY, float drawerW) {
    this.currentDrawerX = drawerX;
    this.currentDrawerY = drawerY;
    this.currentDrawerW = drawerW;
  }

  public void drawContent(float drawX, float drawY, float drawW, float drawH) {
    if (missionExecutor == null) return;

    pushStyle();

    float scale = uiScale;

    // Title based on state
    String title = getStateTitle();
    color titleColor = getStateColor();
    fill(titleColor);
    textSize(14 * scale);
    textAlign(CENTER, TOP);
    text(title, drawX + drawW / 2, drawY + margin);

    // Status text
    fill(220, 220, 220);
    textSize(12 * scale);
    String statusText = missionExecutor.getDetailedStatus();
    if (statusText != null) {
      text(statusText, drawX + drawW / 2, drawY + margin + rowH);
    }

    // Progress bar
    float progressBarX = drawX + margin;
    float progressBarY = drawY + margin + rowH * 2;
    float progressBarW = drawW - 2 * margin;
    float progressBarH = 10 * scale;

    fill(40, 40, 40);
    rect(progressBarX, progressBarY, progressBarW, progressBarH, 4 * scale);

    float progress = (float)missionExecutor.getDetailedProgress();
    fill(80, 160, 220);
    rect(progressBarX, progressBarY, progressBarW * progress, progressBarH, 4 * scale);

    // Progress percentage
    fill(200);
    textSize(10 * scale);
    textAlign(CENTER, TOP);
    text(String.format("%d%%", (int)(progress * 100)), drawX + drawW / 2, progressBarY + progressBarH + 4 * scale);

    popStyle();
  }

  public boolean handleContentClick(float mx, float my, float contentX, float contentY, float contentW) {
    return false; // 任务状态面板不处理点击
  }

  public String getContentTooltip() {
    return null;
  }

  public float[] getContentTooltipSource() {
    return null;
  }

  public float getContentHeight() {
    float scale = uiScale;
    return 100 * scale;
  }

  public boolean shouldBeVisible() {
    if (missionExecutor == null) return false;
    return missionExecutor.hasActiveMission();
  }

  String getStateTitle() {
    // 优先检查回收任务（且必须是活动的）
    if (missionExecutor.isRecoveryMission() && missionExecutor.getRecoveryController() != null) {
      RecoveryStage stage = missionExecutor.getRecoveryController().getStage();
      if (missionExecutor.getRecoveryController().isActive()) {
        return getRecoveryStageTitle(stage);
      }
    }
    // 然后检查发射任务（且必须是活动的）
    if (missionExecutor.isLaunchMission() && missionExecutor.getLaunchController() != null) {
      if (missionExecutor.getLaunchController().isActive()) {
        LaunchController launchController = missionExecutor.getLaunchController();
        // 直接获取飞船的 LaunchState
        if (solarSystem.ships.size() > 0) {
          Spacecraft ship = solarSystem.ships.get(0);
          return getLaunchStageTitle(ship.launchState);
        }
      }
    }
    // 普通任务 - 获取当前任务预设来判断类型
    if (missionExecutor.hasActiveMission() && missionExecutor.currentTask != null &&
        missionExecutor.currentTask.preset != null) {
      MissionPreset preset = missionExecutor.currentTask.preset;
      return getGenericMissionTitle(preset, missionExecutor.state, missionExecutor.currentManeuverIndex, missionExecutor.maneuverSequence);
    }
    // 普通任务（无预设信息）
    switch (missionExecutor.state) {
      case WAITING_FOR_MANEUVER: return "MISSION IN PROGRESS - Waiting";
      case ORIENTING: return "MISSION IN PROGRESS - Orienting";
      case BURNING: return "MISSION IN PROGRESS - Burning";
      case COMPLETED: return "MISSION COMPLETED";
      case FAILED: return "MISSION FAILED";
      default: return "MISSION";
    }
  }

  color getStateColor() {
    // 优先检查回收任务
    if (missionExecutor.isRecoveryMission() && missionExecutor.getRecoveryController() != null) {
      RecoveryStage stage = missionExecutor.getRecoveryController().getStage();
      return getRecoveryStageColor(stage);
    }
    // 然后检查发射任务
    if (missionExecutor.isLaunchMission() && missionExecutor.getLaunchController() != null) {
      if (missionExecutor.getLaunchController().isActive()) {
        if (solarSystem.ships.size() > 0) {
          Spacecraft ship = solarSystem.ships.get(0);
          return getLaunchStageColor(ship.launchState);
        }
      }
    }
    // 普通任务 - 获取当前任务预设来判断类型
    if (missionExecutor.hasActiveMission() && missionExecutor.currentTask != null &&
        missionExecutor.currentTask.preset != null) {
      MissionPreset preset = missionExecutor.currentTask.preset;
      return getGenericMissionColor(preset, missionExecutor.state);
    }
    // 普通任务（无预设信息）
    switch (missionExecutor.state) {
      case WAITING_FOR_MANEUVER: return color(255, 220, 100);
      case ORIENTING: return color(100, 200, 255);
      case BURNING: return color(255, 100, 100);
      case COMPLETED: return color(100, 255, 100);
      case FAILED: return color(255, 50, 50);
      default: return color(200, 200, 200);
    }
  }

  // ========== 回收任务阶段标题 ==========
  String getRecoveryStageTitle(RecoveryStage stage) {
    switch (stage) {
      case IDLE: return "RECOVERY READY";
      case PREPARING: return "RECOVERY - Preparing";
      case DEORBIT_BURN: return "RECOVERY - Deorbit Burn";
      case COAST_TO_ENTRY: return "RECOVERY - Coasting to Entry";
      case REENTRY_GUIDANCE: return "RECOVERY - Reentry";
      case GLIDE_PHASE: return "RECOVERY - Gliding";
      case TURNAROUND_MANEUVER: return "RECOVERY - Turning Around";
      case HOVER_SLIDE: return "RECOVERY - Approaching";
      case FINAL_DESCENT: return "RECOVERY - Final Descent";
      case LANDING_BURN: return "RECOVERY - Landing Burn";
      case LANDED: return "RECOVERY COMPLETE";
      case ABORT: return "RECOVERY ABORTED";
      default: return "RECOVERY";
    }
  }

  // ========== 回收任务阶段颜色 ==========
  color getRecoveryStageColor(RecoveryStage stage) {
    switch (stage) {
      case IDLE: return color(200, 200, 200);
      case PREPARING: return color(255, 220, 100);
      case DEORBIT_BURN: return color(255, 100, 100);
      case COAST_TO_ENTRY: return color(100, 200, 255);
      case REENTRY_GUIDANCE: return color(255, 150, 50);
      case GLIDE_PHASE: return color(100, 200, 200);
      case TURNAROUND_MANEUVER: return color(150, 150, 255);
      case HOVER_SLIDE: return color(100, 200, 150);
      case FINAL_DESCENT: return color(200, 150, 100);
      case LANDING_BURN: return color(255, 100, 150);
      case LANDED: return color(100, 255, 100);
      case ABORT: return color(255, 50, 50);
      default: return color(200, 200, 200);
    }
  }

  // ========== 发射任务阶段标题 ==========
  String getLaunchStageTitle(LaunchState state) {
    switch (state) {
      case ON_PAD: return "LAUNCH - On Pad";
      case COUNTDOWN: return "LAUNCH - Countdown";
      case IGNITION: return "LAUNCH - Ignition";
      case LAUNCHING: return "LAUNCH - Ascending";
      case COAST: return "LAUNCH - Coasting to Apogee";
      case CIRCULARIZING: return "LAUNCH - Circularizing Orbit";
      case IN_ORBIT: return "LAUNCH - In Orbit";
      default: return "LAUNCH MISSION";
    }
  }

  // ========== 发射任务阶段颜色 ==========
  color getLaunchStageColor(LaunchState state) {
    switch (state) {
      case ON_PAD: return color(200, 200, 200);
      case COUNTDOWN: return color(255, 220, 100);
      case IGNITION: return color(255, 100, 100);
      case LAUNCHING: return color(255, 150, 50);
      case COAST: return color(100, 200, 255);
      case CIRCULARIZING: return color(150, 150, 255);
      case IN_ORBIT: return color(100, 255, 100);
      default: return color(200, 200, 200);
    }
  }

  // ========== 普通任务标题（GEO、月球转移等） ==========
  String getGenericMissionTitle(MissionPreset preset, MissionExecutorState state,
                                  int currentManeuverIndex, List<ManeuverNode> maneuvers) {
    String missionName = "MISSION";
    if (preset.id != null) {
      if (preset.id.equals(MISSION_PRESET_GEO)) {
        missionName = "GEO TRANSFER";
      } else if (preset.id.equals(MISSION_PRESET_LUNAR_TRANSFER)) {
        missionName = "LUNAR TRANSFER";
      }
    }

    // 根据状态和当前机动返回细化标题
    switch (state) {
      case WAITING_FOR_MANEUVER:
        if (maneuvers != null && currentManeuverIndex < maneuvers.size()) {
          ManeuverNode node = maneuvers.get(currentManeuverIndex);
          if (node.description != null && node.description.length() > 0) {
            return missionName + " - Waiting: " + node.description;
          }
          return missionName + " - Waiting: Maneuver " + (currentManeuverIndex + 1) + "/" + maneuvers.size();
        }
        return missionName + " - Waiting";
      case ORIENTING:
        if (maneuvers != null && currentManeuverIndex < maneuvers.size()) {
          ManeuverNode node = maneuvers.get(currentManeuverIndex);
          if (node.description != null && node.description.length() > 0) {
            return missionName + " - Orienting: " + node.description;
          }
          return missionName + " - Orienting: Maneuver " + (currentManeuverIndex + 1) + "/" + maneuvers.size();
        }
        return missionName + " - Orienting";
      case BURNING:
        if (maneuvers != null && currentManeuverIndex < maneuvers.size()) {
          ManeuverNode node = maneuvers.get(currentManeuverIndex);
          if (node.description != null && node.description.length() > 0) {
            return missionName + " - Burning: " + node.description;
          }
          return missionName + " - Burning: Maneuver " + (currentManeuverIndex + 1) + "/" + maneuvers.size();
        }
        return missionName + " - Burning";
      case COMPLETED:
        return missionName + " COMPLETED";
      case FAILED:
        return missionName + " FAILED";
      default:
        return missionName;
    }
  }

  // ========== 普通任务颜色（GEO、月球转移等） ==========
  color getGenericMissionColor(MissionPreset preset, MissionExecutorState state) {
    switch (state) {
      case WAITING_FOR_MANEUVER: return color(255, 220, 100);
      case ORIENTING: return color(100, 200, 255);
      case BURNING: return color(255, 100, 100);
      case COMPLETED: return color(100, 255, 100);
      case FAILED: return color(255, 50, 50);
      default: return color(200, 200, 200);
    }
  }
}
