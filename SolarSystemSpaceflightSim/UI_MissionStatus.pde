// ========== MISSION STATUS DISPLAY ==========

class MissionStatus {
  float panelX, panelY, panelW, panelH;
  float margin;
  float rowH;

  MissionStatus() {
    float scale = uiScale;
    panelW = width * 0.5f;
    panelH = 100 * scale;
    panelX = (width - panelW) / 2;
    panelY = height - panelH - 10 * scale;
    margin = 12 * scale;
    rowH = 20 * scale;
  }

  void update() {
    float scale = uiScale;
    panelW = width * 0.5f;
    panelX = (width - panelW) / 2;
    panelY = height - panelH - 10 * scale;
  }

  void draw() {
    if (missionExecutor == null) return;
    if (missionExecutor.state == MissionExecutorState.IDLE && !missionExecutor.hasActiveMission()) return;

    pushStyle();

    float scale = uiScale;

    // Panel background
    noStroke();
    fill(0, 0, 0, 160);
    rect(panelX, panelY, panelW, panelH, 8 * scale);

    // Title based on state
    String title = getStateTitle();
    color titleColor = getStateColor();
    fill(titleColor);
    textSize(14 * scale);
    textAlign(CENTER, TOP);
    text(title, panelX + panelW / 2, panelY + margin);

    // Status text
    fill(220, 220, 220);
    textSize(12 * scale);
    String statusText = missionExecutor.getDetailedStatus();
    if (statusText != null) {
      text(statusText, panelX + panelW / 2, panelY + margin + rowH);
    }

    // Progress bar
    float progressBarX = panelX + margin;
    float progressBarY = panelY + margin + rowH * 2;
    float progressBarW = panelW - 2 * margin;
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
    text(String.format("%d%%", (int)(progress * 100)), panelX + panelW / 2, progressBarY + progressBarH + 4 * scale);

    popStyle();
  }

  String getStateTitle() {
    // 优先检查回收任务
    if (missionExecutor.isRecoveryMission() && missionExecutor.getRecoveryController() != null) {
      RecoveryStage stage = missionExecutor.getRecoveryController().getStage();
      return getRecoveryStageTitle(stage);
    }
    // 然后检查发射任务
    if (missionExecutor.isLaunchMission() && missionExecutor.getLaunchController() != null) {
      return "LAUNCH MISSION IN PROGRESS";
    }
    // 普通任务
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
    // 普通任务
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
}
