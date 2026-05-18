// ========== TOOLTIP ==========

class Tooltip {
  boolean active;
  String text;
  float tx, ty, tw, th;

  Tooltip() {
    active = false;
  }

  void show(String description, String shortcut, float bx, float by, float bw, float bh) {
    float scale = uiScale;
    float margin = 8 * scale;

    if (shortcut == null || shortcut.length() == 0) {
      this.text = description;
    } else {
      this.text = description + "  [" + shortcut + "]";
    }

    pushStyle();
    textSize(12 * scale);
    float textW = textWidth(this.text);
    float textH = 14 * scale;
    float maxW = min(280 * scale, width - 40 * scale);
    boolean needsWrap = textW > maxW;
    if (needsWrap) {
      tw = maxW + 2 * margin;
      th = textH * 2 + 2 * margin;
    } else {
      tw = textW + 2 * margin;
      th = textH + 2 * margin;
    }
    popStyle();

    float gap = 6 * scale;
    float preferredX = bx + bw + gap;
    if (preferredX + tw <= width) {
      tx = preferredX;
    } else {
      tx = bx - tw - gap;
    }

    float preferredY = by;
    if (preferredY + th <= height) {
      ty = preferredY;
    } else {
      ty = by + bh - th;
    }

    tx = max(10.0, min(width - tw - 10.0, tx));
    ty = max(10.0, min(height - th - 10.0, ty));

    active = true;
  }

  void hide() {
    active = false;
  }

  void draw() {
    if (!active) return;

    float scale = uiScale;
    float margin = 8 * scale;

    pushStyle();

    noStroke();
    fill(0, 0, 0, 210);
    rect(tx, ty, tw, th, 6 * scale);

    fill(255);
    textSize(12 * scale);
    textAlign(LEFT, TOP);

    float maxTextW = tw - 2 * margin;
    float currentX = tx + margin;
    float currentY = ty + margin;
    String[] words = split(text, ' ');
    String line = "";

    for (int i = 0; i < words.length; i++) {
      String testLine = (line.length() > 0) ? (line + " " + words[i]) : words[i];
      float testW = textWidth(testLine);
      if (testW > maxTextW && line.length() > 0) {
        text(line, currentX, currentY);
        currentY += 14 * scale;
        line = words[i];
      } else {
        line = testLine;
      }
    }
    if (line.length() > 0) {
      text(line, currentX, currentY);
    }

    popStyle();
  }
}
