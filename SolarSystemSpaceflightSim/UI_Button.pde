// ========== BUTTON ==========

class Button {
  float x, y, w, h;
  String label;
  String description;
  String shortcut;
  boolean enabled;
  boolean isToggle;
  boolean toggled;
  int hoverFrames;
  boolean handledClick;
  int iconType;

  static final int TOOLTIP_DELAY = 60;
  static final int ICON_NONE = 0;
  static final int ICON_RESTART = 1;
  static final int ICON_QUIT = 2;
  static final int ICON_HELP = 3;

  color normalBg, hoverBg, pressedBg, disabledBg;
  color toggledBg, toggledHoverBg;
  color normalText, disabledText;

  Button(float x, float y, float w, float h, String label, String description) {
    this(x, y, w, h, label, description, "", ICON_NONE);
  }

  Button(float x, float y, float w, float h, String label, String description, String shortcut) {
    this(x, y, w, h, label, description, shortcut, ICON_NONE);
  }

  Button(float x, float y, float w, float h, String label, String description, String shortcut, int iconType) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
    this.description = description;
    this.shortcut = shortcut;
    this.enabled = true;
    this.isToggle = false;
    this.toggled = false;
    this.hoverFrames = 0;
    this.handledClick = false;
    this.iconType = iconType;

    this.normalBg = color(0, 0, 0, 160);
    this.hoverBg = color(60, 60, 80, 180);
    this.pressedBg = color(80, 100, 140, 200);
    this.disabledBg = color(40, 40, 40, 120);
    this.toggledBg = color(40, 80, 140, 180);
    this.toggledHoverBg = color(60, 100, 160, 200);
    this.normalText = color(255);
    this.disabledText = color(140);
  }

  void setToggle(boolean isToggle) { this.isToggle = isToggle; }
  void setToggled(boolean toggled) { this.toggled = toggled; }
  boolean isToggled() { return toggled; }

  boolean isHovered() {
    return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
  }

  void update() {
    boolean hover = isHovered();

    if (hover) {
      hoverFrames++;
    } else {
      hoverFrames = 0;
    }

    if (!mousePressed) {
      handledClick = false;
    }
  }

  boolean consumeClick() {
    if (isHovered() && mousePressed && enabled && !handledClick) {
      handledClick = true;
      return true;
    }
    return false;
  }

  boolean shouldShowTooltip() {
    return hoverFrames >= TOOLTIP_DELAY && enabled;
  }

  String getTooltipText() {
    if (shortcut == null || shortcut.length() == 0) {
      return description;
    }
    return description + "  [" + shortcut + "]";
  }

  void draw() {
    float scale = uiScale;

    pushStyle();

    noStroke();

    if (!enabled) {
      fill(disabledBg);
    } else if (mousePressed && isHovered()) {
      fill(pressedBg);
    } else if (isToggle && toggled) {
      if (hoverFrames > 0) {
        fill(toggledHoverBg);
      } else {
        fill(toggledBg);
      }
    } else if (hoverFrames > 0) {
      fill(hoverBg);
    } else {
      fill(normalBg);
    }

    rect(x, y, w, h, 6 * scale);

    if (enabled) {
      fill(normalText);
    } else {
      fill(disabledText);
    }

    textSize(14 * scale);
    if (iconType != ICON_NONE) {
      float iconWidth = 18 * scale;  // 图标区域宽度
      float spacing = 10 * scale;     // 图标与文字间距
      float contentWidth = iconWidth + spacing + textWidth(label);
      float startX = x + (w - contentWidth) / 2;
      drawIcon(startX + iconWidth/2, y + h / 2, scale);
      // 确保文字颜色正确设置
      if (enabled) {
        fill(normalText);
      } else {
        fill(disabledText);
      }
      textAlign(LEFT, CENTER);
      text(label, startX + iconWidth + spacing, y + h / 2);
    } else {
      textAlign(CENTER, CENTER);
      text(label, x + w / 2, y + h / 2);
    }

    popStyle();
  }

  void drawIcon(float iconX, float iconY, float scale) {
    pushStyle();  // 保存绘图状态

    if (iconType == ICON_RESTART) {
      // 重新开始图标 - 圆形箭头，参考右上角按钮风格
      float iconSize = 14 * scale;
      float lineWeight = 2 * scale;

      // 使用右上角按钮的配色风格
      color iconColor = enabled ? color(150, 180, 220, 200) : disabledText;

      strokeWeight(lineWeight);
      stroke(iconColor);
      noFill();

      // 画圆弧 - 更流畅的形状
      float arcRadius = iconSize / 2;
      arc(iconX, iconY, arcRadius * 2, arcRadius * 2, radians(45), radians(315));

      // 画箭头 - 更精致的三角形
      noStroke();
      fill(iconColor);
      float arrowSize = 5 * scale;
      float arrowX = iconX + arcRadius * cos(radians(45));
      float arrowY = iconY - arcRadius * sin(radians(45));
      triangle(
        arrowX, arrowY - arrowSize,
        arrowX + arrowSize * 1.3f, arrowY + arrowSize * 0.3f,
        arrowX - arrowSize * 0.3f, arrowY + arrowSize * 0.3f
      );
    } else if (iconType == ICON_QUIT) {
      // 退出图标 - 更精致的 X
      float iconSize = 12 * scale;
      float lineWeight = 2.2f * scale;
      color iconColor = enabled ? color(150, 180, 220, 200) : disabledText;

      strokeWeight(lineWeight);
      strokeCap(ROUND);
      stroke(iconColor);

      line(iconX - iconSize/2, iconY - iconSize/2, iconX + iconSize/2, iconY + iconSize/2);
      line(iconX + iconSize/2, iconY - iconSize/2, iconX - iconSize/2, iconY + iconSize/2);
    } else if (iconType == ICON_HELP) {
      color iconColor = enabled ? color(150, 180, 220, 200) : disabledText;
      strokeWeight(2 * scale);
      stroke(iconColor);
      noFill();
      ellipse(iconX, iconY, 14 * scale, 14 * scale);
      fill(iconColor);
      textSize(13 * scale);
      textAlign(CENTER, CENTER);
      text("?", iconX, iconY - 1 * scale);
    }

    popStyle();  // 恢复绘图状态
  }

  // New update method with mouse coords
  void update(float mx, float my, boolean mPressed) {
    boolean hover = mx >= x && mx <= x + w && my >= y && my <= y + h;

    if (hover) {
      hoverFrames++;
    } else {
      hoverFrames = 0;
    }

    if (!mPressed) {
      handledClick = false;
    }
  }

  // New handleClick method
  boolean handleClick(float mx, float my) {
    boolean hover = mx >= x && mx <= x + w && my >= y && my <= y + h;
    if (hover && mousePressed && enabled && !handledClick) {
      handledClick = true;
      if (isToggle) {
        toggled = !toggled;
      }
      return true;
    }
    return false;
  }
}
