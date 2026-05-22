// ========== 简化摄像机系统 ==========
// 参照主项目的摄像机逻辑

class SimpleCamera {
  double camX, camY;
  double scale, targetScale;
  double offsetX, offsetY;

  boolean dragging;
  double dragSX, dragSY, dragOffsetX, dragOffsetY;

  SimpleCamera() {
    reset();
  }

  void reset() {
    camX = 0;
    camY = 0;
    scale = 1.0;
    targetScale = 1.0;
    offsetX = 0;
    offsetY = 0;
    dragging = false;
  }

  void update() {
    // 指数平滑缩放
    float scaleSpeed = 6.0f;
    float dt = 1.0f / 60.0f;
    double scaleT = 1.0 - Math.exp(-scaleSpeed * dt);
    scale += (targetScale - scale) * scaleT;

    // 摄像机位置 = 偏移（平移）
    camX = offsetX;
    camY = offsetY;
  }

  // 应用摄像机变换
  void apply() {
    translate((float)camX, (float)camY);
  }

  // 获取当前缩放对应的距离值（用于LOD选择）
  float getDistance() {
    // 缩放1.0对应距离300
    return 300.0f / (float)scale;
  }

  // 获取地球在屏幕上的半径
  float getScreenRadius() {
    float baseRadius = 100;
    return baseRadius * (float)scale;
  }

  // ========== 交互功能 ==========

  void handleMousePressed() {
    dragging = true;
    dragSX = mouseX;
    dragSY = mouseY;
    dragOffsetX = offsetX;
    dragOffsetY = offsetY;
  }

  void handleMouseDragged() {
    if (!dragging) return;
    offsetX = dragOffsetX + (mouseX - dragSX);
    offsetY = dragOffsetY + (mouseY - dragSY);
  }

  void handleMouseReleased() {
    dragging = false;
  }

  void handleMouseWheel(MouseEvent event) {
    double factor = event.getCount() > 0 ? 0.85 : 1.18;
    targetScale *= factor;
    targetScale = constrainDouble(targetScale, 0.01, 1000.0);
  }

  double constrainDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

