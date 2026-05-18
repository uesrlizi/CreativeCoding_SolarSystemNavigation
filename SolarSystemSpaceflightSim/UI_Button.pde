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

  static final int TOOLTIP_DELAY = 60;

  color normalBg, hoverBg, pressedBg, disabledBg;
  color toggledBg, toggledHoverBg;
  color normalText, disabledText;

  Button(float x, float y, float w, float h, String label, String description) {
    this(x, y, w, h, label, description, "");
  }

  Button(float x, float y, float w, float h, String label, String description, String shortcut) {
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
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);

    popStyle();
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
