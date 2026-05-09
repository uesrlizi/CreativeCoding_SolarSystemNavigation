class Camera {
  double camX, camY;
  double scale;
  double targetScale;
  boolean dragging;
  double dragSX, dragSY, dragCX, dragCY;

  Camera() {
    camX = 0;
    camY = 0;
    scale = 1.0;
    targetScale = 1.0;
    dragging = false;
  }

  void initialize(double initialScale) {
    scale = initialScale;
    targetScale = initialScale;
  }

  void update() {
    scale += (targetScale - scale) * 0.1;
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
      camX = dragCX - (mouseX - dragSX) / scale;
      camY = dragCY - (mouseY - dragSY) / scale;
    }
  }

  void handleMouseReleased() {
    dragging = false;
  }

  void handleMouseWheel(MouseEvent event) {
    double factor = event.getCount() > 0 ? 0.85 : 1.18;
    targetScale *= factor;
    targetScale = constrainDouble(targetScale, 1e-18, 1e-1);
  }

  void reset() {
    camX = 0;
    camY = 0;
  }

  void focusOn(double x, double y, double targetScale) {
    camX = x;
    camY = y;
    this.targetScale = targetScale;
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
