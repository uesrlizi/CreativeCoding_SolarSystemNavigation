// ========== CAMERA CONTROLLER ==========

class CameraController {
  double camX, camY;
  double scale, targetScale;

  double mapScale, mapTargetScale;
  double offsetX, offsetY;
  double targetOffsetX, targetOffsetY;
  CelestialBody focusBody;

  ViewMode mode;
  boolean dragging;
  double dragSX, dragSY, dragCX, dragCY, dragOffsetX, dragOffsetY;

  CameraController() {
    camX = 0;
    camY = 0;
    scale = 1.0;
    targetScale = 1.0;
    mapScale = 1.0;
    mapTargetScale = 1.0;
    dragging = false;
    mode = ViewMode.MAP_VIEW;
    focusBody = null;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = 0;
    targetOffsetY = 0;
  }

  void initialize(double initialScale) {
    scale = initialScale;
    targetScale = initialScale;
    mapScale = initialScale;
    mapTargetScale = initialScale;
  }

  void update(float dt) {
    if (Double.isNaN(scale) || Double.isInfinite(scale)) scale = 1.0;
    if (Double.isNaN(targetScale) || Double.isInfinite(targetScale)) targetScale = 1.0;
    float scaleSpeed = 6.0f;
    float offsetSpeed = 10.0f;
    double scaleT = 1.0 - Math.exp(-scaleSpeed * dt);
    double offsetT = 1.0 - Math.exp(-offsetSpeed * dt);
    if (mode == ViewMode.MAP_VIEW) {
      scale += (targetScale - scale) * scaleT;
      offsetX += (targetOffsetX - offsetX) * offsetT;
      offsetY += (targetOffsetY - offsetY) * offsetT;
      double tx = 0, ty = 0;
      if (focusBody != null) { tx = focusBody.px; ty = focusBody.py; }
      camX = tx + offsetX;
      camY = ty + offsetY;
      mapScale = scale;
      mapTargetScale = targetScale;
    }
  }

  ViewMode getMode() {
    return mode;
  }

  void setViewMode(ViewMode m) {
    mode = m;
  }

  void handleMousePressed() {
    if (mode != ViewMode.MAP_VIEW) return;
    dragging = true;
    dragSX = mouseX;
    dragSY = mouseY;
    dragCX = camX;
    dragCY = camY;
    dragOffsetX = offsetX;
    dragOffsetY = offsetY;
  }

  void handleMouseDragged() {
    if (!dragging || mode != ViewMode.MAP_VIEW) return;
    offsetX = dragOffsetX - (mouseX - dragSX) / scale;
    offsetY = dragOffsetY - (mouseY - dragSY) / scale;
    targetOffsetX = offsetX;
    targetOffsetY = offsetY;
    double tx = 0, ty = 0;
    if (focusBody != null) { tx = focusBody.px; ty = focusBody.py; }
    camX = tx + offsetX;
    camY = ty + offsetY;
  }

  void handleMouseReleased() {
    dragging = false;
  }

  void handleMouseWheel(MouseEvent event) {
    if (Double.isNaN(targetScale) || Double.isInfinite(targetScale)) targetScale = 1.0;
    double factor = event.getCount() > 0 ? 0.85 : 1.18;
    targetScale *= factor;
    targetScale = constrainDouble(targetScale, 1e-18, 1e6);
  }

  void reset() {
    focusBody = null;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = 0;
    targetOffsetY = 0;
    camX = 0;
    camY = 0;
  }

  void focusOn(CelestialBody body) {
    focusBody = body;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = offsetX;
    targetOffsetY = offsetY;
    setViewMode(ViewMode.MAP_VIEW);
  }

  void focusOn(double x, double y, double targetScale) {
    focusBody = null;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = 0;
    targetOffsetY = 0;
    camX = x;
    camY = y;
    this.targetScale = targetScale;
    setViewMode(ViewMode.MAP_VIEW);
  }

  String getFocusName() {
    if (focusBody != null) return focusBody.name;
    return null;
  }

  void snapFocus() {
    if (mode == ViewMode.SHIP_VIEW) return;

    double desiredScale = targetScale;
    boolean hasSpecificTarget = false;

    if (focusBody != null) {
      hasSpecificTarget = true;
      if (focusBody.a != 0) {
        desiredScale = height / (4.0 * focusBody.radius);
      } else {
        desiredScale = (width * 0.15) / AU_KM;
      }
    } else {
      desiredScale = (width * 0.15) / AU_KM;
    }

    boolean needsCenter = Math.abs(targetOffsetX) > 0.01 || Math.abs(targetOffsetY) > 0.01;

    if (needsCenter) {
      targetOffsetX = 0;
      targetOffsetY = 0;
      if (hasSpecificTarget && desiredScale < scale) {
        targetScale = desiredScale;
      }
    } else {
      targetScale = desiredScale;
    }
  }

  double[] screenToWorld(double sx, double sy) {
    double wx = (sx - width / 2.0) / scale + camX;
    double wy = (sy - height / 2.0) / scale + camY;
    return new double[]{wx, wy};
  }

  double[] worldToScreen(double wx, double wy) {
    double dx = wx - camX;
    double dy = wy - camY;
    double sx = dx * scale + width / 2.0;
    double sy = dy * scale + height / 2.0;
    double[] result = new double[2];
    result[0] = sx;
    result[1] = sy;
    return result;
  }

  double constrainDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
