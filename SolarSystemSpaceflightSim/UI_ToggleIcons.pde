// ========== TOGGLE ICON BUTTONS ==========

class ToggleIconButton {
  float x, y, w, h;
  boolean toggled;
  boolean hovered;
  int hoverFrames;
  String tooltipText;
  String shortcut;

  ToggleIconButton(float x, float y, float size, String tooltip, String shortcutKey) {
    this.x = x;
    this.y = y;
    this.w = size;
    this.h = size;
    this.tooltipText = tooltip;
    this.shortcut = shortcutKey;
    this.toggled = false;
    this.hoverFrames = 0;
  }

  void update(float mx, float my, boolean mPressed) {
    boolean nowHovered = (mx >= x && mx <= x + w && my >= y && my <= y + h);
    if (nowHovered) {
      hoverFrames++;
    } else {
      hoverFrames = 0;
    }
    hovered = nowHovered;
  }

  void updatePosition(float newX, float newY) {
    x = newX;
    y = newY;
  }

  boolean handleClick(float mx, float my) {
    if (mx >= x && mx <= x + w && my >= y && my <= y + h) {
      toggled = !toggled;
      return true;
    }
    return false;
  }

  boolean shouldShowTooltip() {
    return hoverFrames >= Button.TOOLTIP_DELAY;
  }

  String getTooltipText() {
    if (shortcut == null || shortcut.length() == 0) {
      return tooltipText;
    }
    return tooltipText + "  [" + shortcut + "]";
  }

  float getTooltipSourceX() { return x; }
  float getTooltipSourceY() { return y; }
  float getTooltipSourceW() { return w; }
  float getTooltipSourceH() { return h; }
}

class TrajectoryIconButton extends ToggleIconButton {
  TrajectoryIconButton(float x, float y, float size) {
    super(x, y, size, "Toggle trajectory line", "T");
  }

  void draw() {
    float scale = uiScale;
    float halfW = w / 2;
    float halfH = h / 2;

    noStroke();
    if (mousePressed && hovered) {
      fill(80, 100, 140, 200);
    } else if (hovered) {
      fill(60, 60, 80, 180);
    } else {
      fill(0, 0, 0, 160);
    }
    rect(x, y, w, h, 6 * scale);

    // Draw trajectory icon - curved line with dots
    float centerX = x + halfW;
    float centerY = y + halfH;
    float iconSize = w * 0.35f;

    if (toggled) {
      stroke(255, 220, 100);
    } else {
      stroke(150, 180, 220, 150);
    }
    strokeWeight(2 * scale);
    noFill();

    // Draw a curved arc for trajectory
    beginShape();
    for (int i = 0; i <= 20; i++) {
      float t = i / 20.0f;
      float angle = -HALF_PI + t * PI;
      float px = centerX + cos(angle) * iconSize * 0.9f;
      float py = centerY + sin(angle * 0.6f) * iconSize * 0.7f;
      vertex(px, py);
    }
    endShape();

    // Draw dots along the trajectory
    noStroke();
    if (toggled) {
      fill(255, 220, 100);
    } else {
      fill(150, 180, 220, 150);
    }
    ellipse(centerX - iconSize * 0.7f, centerY - iconSize * 0.2f, 4 * scale, 4 * scale);
    ellipse(centerX, centerY + iconSize * 0.4f, 4 * scale, 4 * scale);
    ellipse(centerX + iconSize * 0.7f, centerY - iconSize * 0.2f, 4 * scale, 4 * scale);
  }
}

class ApsisIconButton extends ToggleIconButton {
  ApsisIconButton(float x, float y, float size) {
    super(x, y, size, "Toggle apoapsis/periapsis markers", "");
  }

  void draw(boolean showMarkers) {
    float scale = uiScale;
    float halfW = w / 2;
    float halfH = h / 2;

    noStroke();
    if (mousePressed && hovered) {
      fill(80, 100, 140, 200);
    } else if (hovered) {
      fill(60, 60, 80, 180);
    } else {
      fill(0, 0, 0, 160);
    }
    rect(x, y, w, h, 6 * scale);

    // Draw apsis icon - two dots (apoapsis and periapsis)
    float centerX = x + halfW;
    float centerY = y + halfH;
    float iconSize = w * 0.3f;

    if (toggled) {
      if (showMarkers) {
        // 完全激活状态：用户开了，轨迹也开了
        // Apoapsis (top, yellow/orange)
        fill(255, 180, 80);
        ellipse(centerX, centerY - iconSize, 8 * scale, 8 * scale);

        // Periapsis (bottom, cyan/blue)
        fill(80, 180, 255);
        ellipse(centerX, centerY + iconSize, 8 * scale, 8 * scale);

        // Connecting line
        stroke(200, 200, 200, 100);
        strokeWeight(1.5f * scale);
        line(centerX, centerY - iconSize + 4 * scale, centerX, centerY + iconSize - 4 * scale);
      } else {
        // 半激活状态：用户开了，但轨迹没开 - 用彩色但半透明
        // Apoapsis (top, yellow/orange)
        fill(255, 180, 80, 120);
        ellipse(centerX, centerY - iconSize, 8 * scale, 8 * scale);

        // Periapsis (bottom, cyan/blue)
        fill(80, 180, 255, 120);
        ellipse(centerX, centerY + iconSize, 8 * scale, 8 * scale);

        // Connecting line
        stroke(200, 200, 200, 60);
        strokeWeight(1.5f * scale);
        line(centerX, centerY - iconSize + 4 * scale, centerX, centerY + iconSize - 4 * scale);
      }
    } else {
      // 关闭状态：用户没开
      fill(150, 150, 150, 100);
      ellipse(centerX, centerY - iconSize, 8 * scale, 8 * scale);
      ellipse(centerX, centerY + iconSize, 8 * scale, 8 * scale);

      stroke(100, 100, 100, 80);
      strokeWeight(1.5f * scale);
      line(centerX, centerY - iconSize + 4 * scale, centerX, centerY + iconSize - 4 * scale);
    }
  }
}

class SOIIconButton extends ToggleIconButton {
  SOIIconButton(float x, float y, float size) {
    super(x, y, size, "Toggle SOI boundaries", "K");
  }

  void draw() {
    float scale = uiScale;
    float halfW = w / 2;
    float halfH = h / 2;

    noStroke();
    if (mousePressed && hovered) {
      fill(80, 100, 140, 200);
    } else if (hovered) {
      fill(60, 60, 80, 180);
    } else {
      fill(0, 0, 0, 160);
    }
    rect(x, y, w, h, 6 * scale);

    // Draw SOI icon - dashed circle with center dot
    float centerX = x + halfW;
    float centerY = y + halfH;
    float iconSize = w * 0.3f;

    noFill();
    if (toggled) {
      stroke(255, 220, 100);
    } else {
      stroke(150, 180, 220, 150);
    }
    strokeWeight(2 * scale);

    // Draw dashed circle
    int dashCount = 12;
    for (int i = 0; i < dashCount; i++) {
      float startAngle = i * TWO_PI / dashCount;
      float endAngle = startAngle + TWO_PI / dashCount * 0.6f;
      arc(centerX, centerY, iconSize * 2, iconSize * 2, startAngle, endAngle);
    }

    // Draw center dot
    noStroke();
    if (toggled) {
      fill(255, 220, 100);
    } else {
      fill(150, 180, 220, 150);
    }
    ellipse(centerX, centerY, 6 * scale, 6 * scale);
  }
}

class OrbitIconButton extends ToggleIconButton {
  OrbitIconButton(float x, float y, float size) {
    super(x, y, size, "Toggle orbital lines", "O");
  }

  void draw() {
    float scale = uiScale;
    float halfW = w / 2;
    float halfH = h / 2;

    noStroke();
    if (mousePressed && hovered) {
      fill(80, 100, 140, 200);
    } else if (hovered) {
      fill(60, 60, 80, 180);
    } else {
      fill(0, 0, 0, 160);
    }
    rect(x, y, w, h, 6 * scale);

    // Draw orbit icon - ellipse/circle
    float centerX = x + halfW;
    float centerY = y + halfH;
    float iconSize = w * 0.35f;

    noFill();
    if (toggled) {
      stroke(255, 220, 100);
    } else {
      stroke(150, 180, 220, 150);
    }
    strokeWeight(2 * scale);

    // Draw elliptical orbit
    ellipse(centerX, centerY, iconSize * 2, iconSize * 1.2f);

    // Draw small center dot
    noStroke();
    if (toggled) {
      fill(255, 220, 100);
    } else {
      fill(150, 180, 220, 150);
    }
    ellipse(centerX, centerY, 4 * scale, 4 * scale);
  }
}
