enum ViewMode {
  MAP_VIEW,
  SHIP_VIEW
}

class CameraController {
  double camX, camY;
  double scale;
  double targetScale;
  boolean dragging;
  double dragSX, dragSY, dragCX, dragCY;

  ViewMode mode;
  Spacecraft followTarget;

  CelestialBody focusBody;
  Spacecraft focusShip;
  double offsetX, offsetY;

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
  }

  void initialize(double initialScale) {
    scale = initialScale;
    targetScale = initialScale;
  }

  void update() {
    scale += (targetScale - scale) * 0.1;
    if (mode == ViewMode.MAP_VIEW) {
      if (focusBody != null) {
        camX = focusBody.px + offsetX;
        camY = focusBody.py + offsetY;
      } else if (focusShip != null) {
        camX = focusShip.px + offsetX;
        camY = focusShip.py + offsetY;
      }
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
      if (followTarget.earthRelative) {
        targetScale = height / 1.5;
      } else if (followTarget.a > 0) {
        targetScale = (width * 0.3) / followTarget.a;
      }
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
  }

  void handleMouseDragged() {
    if (dragging) {
      double newCX = dragCX - (mouseX - dragSX) / scale;
      double newCY = dragCY - (mouseY - dragSY) / scale;
      if (focusBody != null || focusShip != null) {
        offsetX += newCX - camX;
        offsetY += newCY - camY;
      }
      camX = newCX;
      camY = newCY;
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
    camX = 0;
    camY = 0;
  }

  void focusOn(CelestialBody body) {
    focusBody = body;
    focusShip = null;
    offsetX = 0;
    offsetY = 0;
    mode = ViewMode.MAP_VIEW;
  }

  void focusOn(Spacecraft ship) {
    focusBody = null;
    focusShip = ship;
    offsetX = 0;
    offsetY = 0;
    mode = ViewMode.MAP_VIEW;
  }

  void focusOn(double x, double y, double targetScale) {
    focusBody = null;
    focusShip = null;
    offsetX = 0;
    offsetY = 0;
    camX = x;
    camY = y;
    this.targetScale = targetScale;
  }

  String getFocusName() {
    if (focusBody != null) return focusBody.name;
    if (focusShip != null) return focusShip.name;
    return null;
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
