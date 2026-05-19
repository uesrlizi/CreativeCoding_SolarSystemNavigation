// ========== HEADING INDICATOR ==========

class HeadingIndicator {
  float centerX, centerY;
  float radius;
  float margin;

  HeadingIndicator() {
    float scale = uiScale;
    radius = 60 * scale;
    margin = 10 * scale;
    centerX = width - radius - margin;
    centerY = height - radius - margin;
  }

  void update() {
    float scale = uiScale;
    radius = 60 * scale;
    margin = 10 * scale;
    centerX = width - radius - margin;
    centerY = height - radius - margin;
  }

  void draw(Spacecraft craft) {
    if (craft == null) return;

    pushStyle();
    float scale = uiScale;

    // Draw background circle
    noStroke();
    fill(0, 0, 0, 120);
    ellipse(centerX, centerY, radius * 2, radius * 2);

    // Draw tick marks (顺时针角度)
    stroke(100, 100, 120, 150);
    strokeWeight(1 * scale);
    for (int i = 0; i < 12; i++) {
      float angle = (float)(i * TWO_PI / 12);
      float innerR = radius * 0.85f;
      float outerR = radius * 0.95f;
      float x1 = centerX + (float)cos(angle) * innerR;
      float y1 = centerY + (float)sin(angle) * innerR;
      float x2 = centerX + (float)cos(angle) * outerR;
      float y2 = centerY + (float)sin(angle) * outerR;
      line(x1, y1, x2, y2);
    }

    // Draw degree labels (0°, 90°, 180°, 270°) - 顺时针角度
    fill(150, 150, 180);
    textSize(10 * scale);
    textAlign(CENTER, CENTER);
    String[] labels = {"0°", "90°", "180°", "270°"};
    for (int i = 0; i < 4; i++) {
      float angle = (float)(i * TWO_PI / 4);
      float labelR = radius * 0.7f;
      float x = centerX + (float)cos(angle) * labelR;
      float y = centerY + (float)sin(angle) * labelR;
      text(labels[i], x, y);
    }

    // Draw orbit direction markers (Prograde, Retrograde, RadialOut, RadialIn)
    if (craft.orbit != null && craft.referenceBody != null) {
      Vector2 prograde = craft.getPrograde();
      drawDirectionMarker(prograde, color(100, 200, 100), radius * 0.6f, "P");
      drawDirectionMarker(prograde.clone().mul(-1), color(200, 100, 100), radius * 0.6f, "R");
      drawDirectionMarker(craft.getRadialOut(), color(100, 150, 255), radius * 0.45f, "O");
      drawDirectionMarker(craft.getRadialIn(), color(255, 150, 100), radius * 0.45f, "I");
    }

    // Draw target direction if available
    if (craft.autoControl != null && craft.autoControl.hasTargetDirection) {
      Vector2 targetDir = craft.autoControl.targetDirection;
      drawDirectionPointer(targetDir, color(100, 255, 100), radius * 0.8f, true);
    }

    // Draw current heading
    Vector2 currentDir = craft.attitude.getForward();
    drawDirectionPointer(currentDir, color(255, 255, 255), radius * 0.75f, false);

    // Draw orientation error if applicable
    if (craft.autoControl != null && craft.autoControl.hasTargetDirection) {
      drawErrorArc(craft.attitude.getForward(), craft.autoControl.targetDirection, craft.autoControl.orientationError);
    }

    // Draw center dot
    noStroke();
    fill(200, 200, 220);
    ellipse(centerX, centerY, 8 * scale, 8 * scale);

    popStyle();
  }

  void drawDirectionMarker(Vector2 dir, color c, float r, String label) {
    float scale = uiScale;
    if (dir.magnitudeSq() < 0.0001) return;

    // 直接用dir.angle()作为顺时针角度
    float angle = (float)dir.angle();
    float x = centerX + (float)cos(angle) * r;
    float y = centerY + (float)sin(angle) * r;

    noStroke();
    fill(c, 150);
    ellipse(x, y, 8 * scale, 8 * scale);

    if (label != null && label.length() > 0) {
      fill(c);
      textSize(9 * scale);
      textAlign(CENTER, CENTER);
      text(label, x, y);
    }
  }

  void drawDirectionPointer(Vector2 dir, color c, float r, boolean isTarget) {
    float scale = uiScale;
    if (dir.magnitudeSq() < 0.0001) return;

    // 直接用dir.angle()作为顺时针角度
    float angle = (float)dir.angle();
    float innerR = r * 0.2f;
    float tipX = centerX + (float)cos(angle) * r;
    float tipY = centerY + (float)sin(angle) * r;
    float baseX = centerX + (float)cos(angle) * innerR;
    float baseY = centerY + (float)sin(angle) * innerR;

    // Draw pointer line
    stroke(c);
    strokeWeight(isTarget ? 2 * scale : 3 * scale);
    line(baseX, baseY, tipX, tipY);

    // Draw arrow head
    noStroke();
    fill(c);
    float arrowSize = isTarget ? 10 * scale : 12 * scale;
    float arrowAngle1 = angle + (float)PI * 0.85f;
    float arrowAngle2 = angle - (float)PI * 0.85f;
    triangle(
      tipX, tipY,
      tipX + (float)cos(arrowAngle1) * arrowSize, tipY + (float)sin(arrowAngle1) * arrowSize,
      tipX + (float)cos(arrowAngle2) * arrowSize, tipY + (float)sin(arrowAngle2) * arrowSize
    );
  }

  void drawErrorArc(Vector2 currentDir, Vector2 targetDir, double errorRad) {
    float scale = uiScale;
    float r = radius * 0.55f;

    float currentAngle = (float)currentDir.angle();
    float targetAngle = (float)targetDir.angle();

    // Draw arc between current and target
    noFill();
    stroke(255, 150, 0, 180);
    strokeWeight(3 * scale);

    // Determine arc direction
    float startAngle, endAngle;
    if (errorRad > 0) {
      startAngle = -currentAngle;  // Processing uses clockwise angles
      endAngle = -targetAngle;
    } else {
      startAngle = -targetAngle;
      endAngle = -currentAngle;
    }

    // Draw arc
    arc(centerX, centerY, r * 2, r * 2, startAngle, endAngle);

    // Draw error text
    float errorDeg = (float)Math.toDegrees(Math.abs(errorRad));
    float textAngle = -(currentAngle + targetAngle) / 2;
    float textX = centerX + (float)cos(textAngle) * r * 0.7f;
    float textY = centerY + (float)sin(textAngle) * r * 0.7f;

    fill(255, 200, 0);
    textSize(10 * scale);
    textAlign(CENTER, CENTER);
    text(String.format("%.1f°", errorDeg), textX, textY);
  }
}
