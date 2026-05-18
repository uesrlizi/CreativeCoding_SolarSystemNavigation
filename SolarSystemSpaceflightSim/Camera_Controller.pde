// ========== CAMERA CONTROLLER ==========

class CameraController {
  double camX, camY;
  double scale, targetScale;

  double mapScale, mapTargetScale;
  double offsetX, offsetY;
  double targetOffsetX, targetOffsetY;
  CelestialBody focusBody;
  Spacecraft focusShip;

  double shipScale, shipTargetScale;
  double shipViewAngle;
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
    shipTargetScale = 0.0;
    dragging = false;
    mode = ViewMode.MAP_VIEW;
    focusBody = null;
    focusShip = null;
    followTarget = null;
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
      if (focusBody != null) {
        tx = focusBody.px;
        ty = focusBody.py;
      } else if (focusShip != null) {
        tx = focusShip.worldX;
        ty = focusShip.worldY;
      }
      camX = tx + offsetX;
      camY = ty + offsetY;
      mapScale = scale;
      mapTargetScale = targetScale;
    }

    if (mode == ViewMode.SHIP_VIEW && followTarget != null) {
      scale += (targetScale - scale) * scaleT;
      camX = followTarget.worldX;
      camY = followTarget.worldY;
      shipScale = scale;
      shipTargetScale = targetScale;
      if (followTarget.referenceBody != null) {
        double rx = followTarget.stateVector.position.x;
        double ry = followTarget.stateVector.position.y;
        shipViewAngle = Math.atan2(ry, rx);
      }
    }
  }

  ViewMode getMode() {
    return mode;
  }

  void setViewMode(ViewMode m) {
    if (m == mode) return;

    if (mode == ViewMode.MAP_VIEW) {
      mapScale = scale;
      mapTargetScale = targetScale;
    } else if (mode == ViewMode.SHIP_VIEW) {
      shipScale = scale;
      shipTargetScale = targetScale;
    }

    mode = m;
    if (m == ViewMode.MAP_VIEW) {
      scale = mapScale;
      targetScale = mapTargetScale;
    } else if (m == ViewMode.SHIP_VIEW) {
      scale = shipScale;
      targetScale = shipTargetScale;
      if (followTarget != null) {
        camX = followTarget.worldX;
        camY = followTarget.worldY;
      }
      if (shipTargetScale <= 0.0) {
        shipTargetScale = 0.22 * height / Spacecraft.SHIP_LENGTH_KM;
        targetScale = shipTargetScale;
      }
    }
  }

  void followShip(Spacecraft ship) {
    followTarget = ship;
    if (ship != null) {
      camX = ship.worldX;
      camY = ship.worldY;
    }
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
    else if (focusShip != null) { tx = focusShip.worldX; ty = focusShip.worldY; }
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

  void focusOn(CelestialBody body) {
    focusBody = body;
    focusShip = null;
    offsetX = (mode == ViewMode.SHIP_VIEW) ? 0 : camX - body.px;
    offsetY = (mode == ViewMode.SHIP_VIEW) ? 0 : camY - body.py;
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

  void focusOn(Spacecraft craft) {
    focusBody = null;
    focusShip = craft;
    offsetX = (mode == ViewMode.SHIP_VIEW) ? 0 : camX - craft.worldX;
    offsetY = (mode == ViewMode.SHIP_VIEW) ? 0 : camY - craft.worldY;
    targetOffsetX = offsetX;
    targetOffsetY = offsetY;
    setViewMode(ViewMode.MAP_VIEW);
  }

  String getFocusName() {
    if (mode == ViewMode.SHIP_VIEW && followTarget != null) return "Spacecraft";
    if (focusShip != null) return "Spacecraft";
    if (focusBody != null) return focusBody.name;
    return null;
  }

  void snapFocus() {
    if (mode == ViewMode.SHIP_VIEW) return;

    // First, calculate desired target scale
    double desiredScale = targetScale;
    boolean hasSpecificTarget = false;

    if (focusShip != null) {
      hasSpecificTarget = true;
      if (focusShip.referenceBody != null) {
        // Earth-relative phase
        double r = focusShip.stateVector.position.magnitude();
        double altitude = r - EARTH_RADIUS_KM;
        if (altitude < 50.0) {
          // On surface: zoom to planet scale
          desiredScale = height / (2.0 * focusShip.referenceBody.radius);
        } else {
          // In flight: zoom to orbit semi-major axis scale
          if (focusShip.orbit != null && focusShip.orbit.a > 0.0 && focusShip.orbit.a < Double.MAX_VALUE / 2.0) {
            desiredScale = height / (4.0 * focusShip.orbit.a);
          } else {
            desiredScale = height / (4.0 * r);
          }
        }
      } else {
        // Heliocentric phase: use solar orbit semi-major axis
        if (focusShip.orbit != null && focusShip.orbit.a > 0.0) {
          desiredScale = height / (4.0 * focusShip.orbit.a);
        } else {
          double r = Math.sqrt(focusShip.worldX * focusShip.worldX + focusShip.worldY * focusShip.worldY);
          desiredScale = height / (4.0 * Math.max(r, AU_KM));
        }
      }
    } else if (focusBody != null) {
      hasSpecificTarget = true;
      if (focusBody.a != 0) {
        // Planet: zoom to planet radius scale
        desiredScale = height / (4.0 * focusBody.radius);
      } else {
        // Sun: use default solar system scale
        desiredScale = (width * 0.15) / AU_KM;
      }
    } else {
      desiredScale = (width * 0.15) / AU_KM;
    }

    // Check if we need to center
    boolean needsCenter = Math.abs(targetOffsetX) > 0.01 || Math.abs(targetOffsetY) > 0.01;

    if (needsCenter) {
      targetOffsetX = 0;
      targetOffsetY = 0;
      // If desired scale is smaller than current, also zoom in on first snap
      if (hasSpecificTarget && desiredScale < scale) {
        targetScale = desiredScale;
      }
    } else {
      // Already centered, just set the scale
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

    if (mode == ViewMode.SHIP_VIEW && followTarget != null && followTarget.referenceBody != null) {
      double cosA = Math.cos(shipViewAngle);
      double sinA = Math.sin(shipViewAngle);
      double sx = (-sinA * dx + cosA * dy) * scale + width / 2.0;
      double sy = -(cosA * dx + sinA * dy) * scale + height / 2.0;
      return new double[]{sx, sy};
    }

    double sx = dx * scale + width / 2.0;
    double sy = dy * scale + height / 2.0;
    double[] result = new double[2];
    result[0] = sx;
    result[1] = sy;
    return result;
  }
}
