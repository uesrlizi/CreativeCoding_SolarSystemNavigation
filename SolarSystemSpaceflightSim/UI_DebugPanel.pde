// ============================================================
//  UI_DebugPanel - 调试面板
//  显示物理系统、轨道信息等调试数据
// ============================================================

class DebugPanel {
  boolean visible;
  float panelX, panelY;
  float panelWidth, panelHeight;
  float uiScale;

  DebugPanel() {
    this.visible = false;
    this.panelWidth = 300;
    this.panelHeight = 320;
    this.uiScale = 1.0f;
  }

  void toggle() {
    visible = !visible;
  }

  void draw(PhysicsSystem physicsSystem, CameraController camera, float scale) {
    if (!visible) return;

    this.uiScale = scale;
    this.panelWidth = 300 * uiScale;
    this.panelHeight = 320 * uiScale;

    // 面板位置（右上角）
    this.panelX = width - panelWidth - 20 * uiScale;
    this.panelY = 140 * uiScale;

    // 绘制背景
    noStroke();
    fill(20, 25, 35, 220);
    rectMode(CORNER);
    rect(panelX, panelY, panelWidth, panelHeight, 8 * uiScale);

    // 绘制标题
    fill(255, 220, 120);
    textSize(16 * uiScale);
    textAlign(LEFT, TOP);
    text("Debug Info", panelX + 12 * uiScale, panelY + 10 * uiScale);

    // 绘制分隔线
    stroke(80, 90, 110, 150);
    strokeWeight(1);
    line(panelX + 10 * uiScale, panelY + 35 * uiScale,
         panelX + panelWidth - 10 * uiScale, panelY + 35 * uiScale);

    float currentY = 45 * uiScale;

    // 绘制物理系统调试信息
    if (physicsSystem != null) {
      fill(220, 230, 240);
      textSize(12 * uiScale);
      textLeading(16 * uiScale);

      String info = physicsSystem.debugInfo;
      if (info != null && info.length() > 0) {
        text(info, panelX + 12 * uiScale, panelY + currentY);
        int lines = 1;
        for (int i = 0; i < info.length(); i++) {
          if (info.charAt(i) == '\n') lines++;
        }
        currentY += (lines * 16 + 5) * uiScale;
      }
    }

    // 绘制MissionExecutor状态 (Stage 5)
    if (missionExecutor != null) {
      fill(180, 200, 255);
      textSize(13 * uiScale);
      text("Mission Executor", panelX + 12 * uiScale, panelY + currentY);
      currentY += 18 * uiScale;

      fill(200, 220, 240);
      textSize(12 * uiScale);
      String stateStr = missionExecutor.state.toString();
      text("State: " + stateStr, panelX + 12 * uiScale, panelY + currentY);
      currentY += 16 * uiScale;

      text("Status: " + missionExecutor.statusText, panelX + 12 * uiScale, panelY + currentY);
      currentY += 16 * uiScale;

      text(String.format("Progress: %.1f%%", missionExecutor.progress * 100), panelX + 12 * uiScale, panelY + currentY);
      currentY += 16 * uiScale;

      text("Maneuver Index: " + missionExecutor.currentManeuverIndex, panelX + 12 * uiScale, panelY + currentY);
    }
  }
}
