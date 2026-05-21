// ========== MISSION STATUS DISPLAY ==========

class MissionStatus {
  float panelX, panelY, panelW, panelH;
  float margin;
  float rowH;

  MissionStatus() {
    float scale = uiScale;
    panelW = 300 * scale;
    panelH = 100 * scale;
    panelX = (width - panelW) / 2;
    panelY = height - panelH - 10 * scale;
    margin = 12 * scale;
    rowH = 20 * scale;
  }

  void update() {
    float scale = uiScale;
    panelW = 300 * scale;
    panelX = (width - panelW) / 2;
    panelY = height - panelH - 10 * scale;
  }

  void draw() {
    if (missionExecutor == null) return;
    if (missionExecutor.state == MissionExecutorState.IDLE) return;

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
    String statusText = missionExecutor.statusText;
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

    float progress = (float)missionExecutor.progress;
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
    switch (missionExecutor.state) {
      case WAITING_FOR_MANEUVER: return color(255, 220, 100);
      case ORIENTING: return color(100, 200, 255);
      case BURNING: return color(255, 100, 100);
      case COMPLETED: return color(100, 255, 100);
      case FAILED: return color(255, 50, 50);
      default: return color(200, 200, 200);
    }
  }
}
