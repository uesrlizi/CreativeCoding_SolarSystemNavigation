class CameraController {
  // Active state (used by renderers)
  double camX, camY;
  double scale, targetScale;

  // Map view saved state
  double mapScale, mapTargetScale;
  double offsetX, offsetY;
  double targetOffsetX, targetOffsetY;
  CelestialBody focusBody;
  Spacecraft focusShip;

  // Ship view saved state
  double shipScale, shipTargetScale;
  double shipViewAngle;  // rad, radial direction from Earth to ship
  Spacecraft followTarget;

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
    shipScale = 1.0;
    shipTargetScale = 0.0;  // unset — triggers auto-zoom on first ship-view entry
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
    mapScale = initialScale;
    mapTargetScale = initialScale;
  }

  void update(float dt) {
    if (Double.isNaN(scale) || Double.isInfinite(scale)) scale = 1.0;
    if (Double.isNaN(targetScale) || Double.isInfinite(targetScale)) targetScale = 1.0;
    float scaleSpeed = 6.0;
    float offsetSpeed = 10.0;
    double scaleT = 1.0 - Math.exp(-scaleSpeed * dt);
    double offsetT = 1.0 - Math.exp(-offsetSpeed * dt);
    if (mode == ViewMode.MAP_VIEW) {
      scale += (targetScale - scale) * scaleT;
      offsetX += (targetOffsetX - offsetX) * offsetT;
      offsetY += (targetOffsetY - offsetY) * offsetT;
      double tx = 0, ty = 0;
      if (focusBody != null) { tx = focusBody.px; ty = focusBody.py; }
      else if (focusShip != null) { tx = focusShip.px; ty = focusShip.py; }
      camX = tx + offsetX;
      camY = ty + offsetY;
      // Keep map saved scale current
      mapScale = scale;
      mapTargetScale = targetScale;
    }
    if (mode == ViewMode.SHIP_VIEW && followTarget != null) {
      scale += (targetScale - scale) * scaleT;
      camX = followTarget.px;
      camY = followTarget.py;
      shipScale = scale;
      shipTargetScale = targetScale;
      // Compute view angle: radial direction from Earth to ship
      if (followTarget.earthRelative && followTarget.earthRef != null) {
        double rx = followTarget.earthRelPos[0];
        double ry = followTarget.earthRelPos[1];
        shipViewAngle = Math.atan2(ry, rx);
      }
    }
  }

  ViewMode getMode() {
    return mode;
  }

  void setViewMode(ViewMode m) {
    if (m == mode) return;

    // Save current mode's scale state
    if (mode == ViewMode.MAP_VIEW) {
      mapScale = scale;
      mapTargetScale = targetScale;
    } else if (mode == ViewMode.SHIP_VIEW) {
      shipScale = scale;
      shipTargetScale = targetScale;
    }

    // Switch and restore target mode's scale state
    mode = m;
    if (m == ViewMode.MAP_VIEW) {
      scale = mapScale;
      targetScale = mapTargetScale;
    } else if (m == ViewMode.SHIP_VIEW) {
      scale = shipScale;
      targetScale = shipTargetScale;
      if (followTarget != null) {
        camX = followTarget.px;
        camY = followTarget.py;
      }
      // First time entering ship view — auto-zoom
      if (shipTargetScale <= 0.0) {
        shipTargetScale = 0.22 * height / Spacecraft.SHIP_LENGTH_KM;
        targetScale = shipTargetScale;
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

  // --- Mouse / input (only affect active mode) ---

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
    else if (focusShip != null) { tx = focusShip.px; ty = focusShip.py; }
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
    focusShip = null;
    offsetX = 0;
    offsetY = 0;
    targetOffsetX = 0;
    targetOffsetY = 0;
    camX = 0;
    camY = 0;
  }

  // --- Focus (MAP_VIEW only — switches to MAP_VIEW if in SHIP_VIEW) ---

  void focusOn(CelestialBody body) {
    focusBody = body;
    focusShip = null;
    offsetX = (mode == ViewMode.SHIP_VIEW) ? 0 : camX - body.px;
    offsetY = (mode == ViewMode.SHIP_VIEW) ? 0 : camY - body.py;
    targetOffsetX = offsetX;
    targetOffsetY = offsetY;
    setViewMode(ViewMode.MAP_VIEW);
  }

  void focusOn(Spacecraft ship) {
    focusBody = null;
    focusShip = ship;
    offsetX = (mode == ViewMode.SHIP_VIEW) ? 0 : camX - ship.px;
    offsetY = (mode == ViewMode.SHIP_VIEW) ? 0 : camY - ship.py;
    targetOffsetX = offsetX;
    targetOffsetY = offsetY;
    setViewMode(ViewMode.MAP_VIEW);
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
    setViewMode(ViewMode.MAP_VIEW);
  }

  String getFocusName() {
    if (mode == ViewMode.SHIP_VIEW && followTarget != null) return "Spacecraft";
    if (focusBody != null && focusBody.a != 0) return focusBody.name;
    if (focusShip != null) return "Spacecraft";
    return null;
  }

  void snapFocus() {
    if (mode == ViewMode.SHIP_VIEW) return;
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

  // --- Coordinate transforms ---

  double[] screenToWorld(double sx, double sy) {
    double wx = (sx - width / 2.0) / scale + camX;
    double wy = (sy - height / 2.0) / scale + camY;
    return new double[]{wx, wy};
  }

  double[] worldToScreen(double wx, double wy) {
    double dx = wx - camX;
    double dy = wy - camY;

    if (mode == ViewMode.SHIP_VIEW && followTarget != null && followTarget.earthRelative) {
      // Rotate view: tangential dir → screen X, radial-outward → screen -Y (up)
      double cosA = Math.cos(shipViewAngle);
      double sinA = Math.sin(shipViewAngle);
      double sx = (-sinA * dx + cosA * dy) * scale + width / 2.0;
      double sy = -(cosA * dx + sinA * dy) * scale + height / 2.0;
      return new double[]{sx, sy};
    }

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
