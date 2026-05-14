class CameraController {
  double camX, camY;
  double scale;
  double targetScale;
  boolean dragging;
  double dragSX, dragSY, dragCX, dragCY, dragOffsetX, dragOffsetY;

  ViewMode mode;
  Spacecraft followTarget;

  CelestialBody focusBody;
  Spacecraft focusShip;
  double offsetX, offsetY;
  double targetOffsetX, targetOffsetY;

  CameraController() {
    camX = 0;
    camY = 0;
    scale = 1.0;
    targetScale = 1.0;
    dragging = false;
    mode = ViewMode.MAP_VIEW;
    followTarget = null;
    focusBody = null;
    focusShip = null;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = 0;
    targetOffsetY = 0;
  }

  void initialize(double initialScale) {
    scale = initialScale;
    targetScale = initialScale;
  }

  void update() {
    scale += (targetScale - scale) * 0.1;
    offsetX += (targetOffsetX - offsetX) * 0.15;
    offsetY += (targetOffsetY - offsetY) * 0.15;
    if (mode == ViewMode.MAP_VIEW) {
      double tx = 0, ty = 0;
      if (focusBody != null) { tx = focusBody.px; ty = focusBody.py; }
      else if (focusShip != null) { tx = focusShip.px; ty = focusShip.py; }
      camX = tx + offsetX;
      camY = ty + offsetY;
    }
    if (mode == ViewMode.SHIP_VIEW && followTarget != null) {
      camX = followTarget.px;
      camY = followTarget.py;
    }
  }

  ViewMode getMode() {
    return mode;
  }

  void setViewMode(ViewMode m) {
    mode = m;
    if (m == ViewMode.SHIP_VIEW && followTarget != null) {
      camX = followTarget.px;
      camY = followTarget.py;
    }
  }

  void followShip(Spacecraft ship) {
    followTarget = ship;
    if (ship != null) {
      camX = ship.px;
      camY = ship.py;
    }
  }

  void handleMousePressed() {
    dragging = true;
    dragSX = mouseX;
    dragSY = mouseY;
    dragCX = camX;
    dragCY = camY;
    dragOffsetX = offsetX;
    dragOffsetY = offsetY;
  }

  void handleMouseDragged() {
    if (dragging) {
      offsetX = dragOffsetX - (mouseX - dragSX) / scale;
      offsetY = dragOffsetY - (mouseY - dragSY) / scale;
      targetOffsetX = offsetX;
      targetOffsetY = offsetY;
      double tx = 0, ty = 0;
      if (focusBody != null) { tx = focusBody.px; ty = focusBody.py; }
      else if (focusShip != null) { tx = focusShip.px; ty = focusShip.py; }
      camX = tx + offsetX;
      camY = ty + offsetY;
    }
  }

  void handleMouseReleased() {
    dragging = false;
  }

  void handleMouseWheel(MouseEvent event) {
    double factor = event.getCount() > 0 ? 0.85 : 1.18;
    targetScale *= factor;
    targetScale = constrainDouble(targetScale, 1e-18, 1e6);
  }

  void reset() {
    focusBody = null;
    focusShip = null;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = 0;
    targetOffsetY = 0;
    camX = 0;
    camY = 0;
  }

  void focusOn(CelestialBody body) {
    focusBody = body;
    focusShip = null;
    offsetX = camX - body.px;
    offsetY = camY - body.py;
    targetOffsetX = offsetX;
    targetOffsetY = offsetY;
    mode = ViewMode.MAP_VIEW;
  }

  void focusOn(Spacecraft ship) {
    focusBody = null;
    focusShip = ship;
    offsetX = camX - ship.px;
    offsetY = camY - ship.py;
    targetOffsetX = offsetX;
    targetOffsetY = offsetY;
    mode = ViewMode.MAP_VIEW;
  }

  void focusOn(double x, double y, double targetScale) {
    focusBody = null;
    focusShip = null;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = 0;
    targetOffsetY = 0;
    camX = x;
    camY = y;
    this.targetScale = targetScale;
  }

  String getFocusName() {
    if (focusBody != null && focusBody.a != 0) return focusBody.name;
    if (focusShip != null) return focusShip.name;
    return null;
  }

  void snapFocus() {
    if (focusShip != null) {
      if (Math.abs(targetOffsetX) > 0.01 || Math.abs(targetOffsetY) > 0.01) {
        targetOffsetX = 0;
        targetOffsetY = 0;
      }
    } else if (focusBody != null && focusBody.a != 0) {
      if (Math.abs(targetOffsetX) > 0.01 || Math.abs(targetOffsetY) > 0.01) {
        targetOffsetX = 0;
        targetOffsetY = 0;
      } else {
        targetScale = height / (4.0 * focusBody.radius);
      }
    } else {
      if (Math.abs(targetOffsetX) > 0.01 || Math.abs(targetOffsetY) > 0.01) {
        targetOffsetX = 0;
        targetOffsetY = 0;
      } else {
        targetScale = (width * 0.15) / AU_KM;
      }
    }
  }

  double[] screenToWorld(double sx, double sy) {
    double wx = (sx - width / 2.0) / scale + camX;
    double wy = (sy - height / 2.0) / scale + camY;
    return new double[]{wx, wy};
  }

  double[] worldToScreen(double wx, double wy) {
    double sx = (wx - camX) * scale + width / 2.0;
    double sy = (wy - camY) * scale + height / 2.0;
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
