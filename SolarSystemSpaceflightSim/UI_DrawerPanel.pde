// ========== DRAWER PANEL COMPONENT ==========

// DrawerContent 接口 - 抽屉内容提供者
interface DrawerContent {
  void updateContent(float drawerX, float drawerY, float drawerW); // 更新时传递位置
  void drawContent(float drawX, float drawY, float drawW, float drawH);
  boolean handleContentClick(float mx, float my, float contentX, float contentY, float contentW);
  String getContentTooltip();
  float[] getContentTooltipSource();
  float getContentHeight();
  boolean shouldBeVisible();  // 新增：判断内容是否应该可见
}

// DrawerSide enum - 抽屉方向
static final int DRAWER_LEFT = 0;
static final int DRAWER_RIGHT = 1;

// DrawerPanel 类 - 可复用的抽屉面板包装器
class DrawerPanel {

  boolean expanded;
  float currentPosition;
  float expandedPosition;
  float collapsedPosition;
  float animationSpeed;

  float toggleBtnWidth;   // 按钮宽度
  float toggleBtnHeight;  // 按钮高度
  float toggleBtnX, toggleBtnY;
  boolean toggleBtnHover;
  int toggleBtnHoverFrames;

  int side;
  float panelWidth;
  float visibleWidthWhenCollapsed;
  String collapsedLabel;

  DrawerContent content;

  DrawerPanel(int side, float panelWidth, float visibleWidthWhenCollapsed, DrawerContent content, String collapsedLabel) {
    this.side = side;
    this.panelWidth = panelWidth;
    this.visibleWidthWhenCollapsed = visibleWidthWhenCollapsed;
    this.content = content;
    this.collapsedLabel = collapsedLabel;

    float scale = uiScale;
    this.toggleBtnWidth = 36 * scale;   // 窄宽度
    this.toggleBtnHeight = 120 * scale;  // 高高度，纵向长条
    this.animationSpeed = 0.15f;
    this.expanded = true;
    this.toggleBtnHover = false;
    this.toggleBtnHoverFrames = 0;

    updateTargetPositions();
    this.currentPosition = expandedPosition;
  }

  void updateTargetPositions() {
    float scale = uiScale;
    if (side == DRAWER_LEFT) {
      expandedPosition = 10 * scale;
      // 对称逻辑：面板右边缘 = 0（屏幕左边缘），按钮从 4px 开始
      // 面板右边缘 = currentPosition + panelWidth = 0 → currentPosition = -panelWidth
      // 按钮左边缘 = currentPosition + panelWidth + 4 = 4
      collapsedPosition = -panelWidth;
    } else {
      expandedPosition = width - panelWidth - 10 * scale;
      // 对称逻辑：面板左边缘 = width（屏幕右边缘），按钮在 width - toggleBtnWidth - 4
      // 面板左边缘 = currentPosition = width
      // 按钮左边缘 = currentPosition - toggleBtnWidth - 4 = width - toggleBtnWidth - 4
      collapsedPosition = width;
    }
  }

  // 判断抽屉是否应该可见
  boolean shouldBeVisible() {
    if (content != null) {
      return content.shouldBeVisible();
    }
    return true;  // 默认可见
  }

  void update() {
    updateTargetPositions();

    // 如果内容不可见，不做任何处理（完全隐藏）
    if (!shouldBeVisible()) {
      return;
    }

    float target = expanded ? expandedPosition : collapsedPosition;
    currentPosition = lerp(currentPosition, target, animationSpeed);

    if (content != null) {
      float scale = uiScale;
      float contentY = 120 * scale;
      float contentHeight = content.getContentHeight();
      content.updateContent(currentPosition, contentY, panelWidth);
    }

    updateToggleButtonPosition();

    toggleBtnHover = (mouseX >= toggleBtnX && mouseX <= toggleBtnX + toggleBtnWidth &&
                     mouseY >= toggleBtnY && mouseY <= toggleBtnY + toggleBtnHeight);
    if (toggleBtnHover) {
      toggleBtnHoverFrames++;
    } else {
      toggleBtnHoverFrames = 0;
    }
  }

  void updateToggleButtonPosition() {
    float scale = uiScale;
    float contentHeight = (content != null) ? content.getContentHeight() : 200 * scale;

    if (side == DRAWER_LEFT) {
      toggleBtnX = currentPosition + panelWidth + 4 * scale;
    } else {
      toggleBtnX = currentPosition - toggleBtnWidth - 4 * scale;
    }

    float panelTop = 120 * scale;
    toggleBtnY = panelTop + contentHeight / 2 - toggleBtnHeight / 2;
  }

  void draw() {
    // 如果内容不可见，完全不绘制
    if (!shouldBeVisible()) {
      return;
    }

    float scale = uiScale;
    pushStyle();

    if (content != null) {
      float contentY = 120 * scale;
      float contentHeight = content.getContentHeight();

      // 始终绘制面板，根据 currentPosition 平滑滑动
      // 通过判断面板位置决定是否绘制内容（完全折叠时不绘制）
      float visibleRatio;
      if (side == DRAWER_LEFT) {
        visibleRatio = (currentPosition - collapsedPosition) / (expandedPosition - collapsedPosition);
      } else {
        visibleRatio = (collapsedPosition - currentPosition) / (collapsedPosition - expandedPosition);
      }
      visibleRatio = constrain(visibleRatio, 0, 1);

      // 只要面板稍微展开就绘制背景和内容
      if (visibleRatio > 0.01) {
        noStroke();
        fill(0, 0, 0, 150);
        rect(currentPosition, contentY, panelWidth, contentHeight, 8 * scale);

        // 同时绘制内容
        content.drawContent(currentPosition, contentY, panelWidth, contentHeight);
      }
    }

    // 确保按钮位置与面板同步更新
    updateToggleButtonPosition();
    drawToggleButton();

    popStyle();
  }

  void drawToggleButton() {
    float scale = uiScale;
    pushStyle();
    noStroke();
    fill(toggleBtnHover ? color(80, 100, 140, 200) : color(40, 50, 70, 180));
    rect(toggleBtnX, toggleBtnY, toggleBtnWidth, toggleBtnHeight, 6 * scale);

    // 绘制纵向标签栏文本（旋转90度）
    if (collapsedLabel != null && collapsedLabel.length() > 0) {
      fill(255, 200, 100);
      textSize(14 * scale);
      textAlign(CENTER, CENTER);

      // 旋转文字纵向排列
      pushMatrix();
      translate(toggleBtnX + toggleBtnWidth / 2, toggleBtnY + toggleBtnHeight / 2);
      rotate(HALF_PI); // 旋转90度
      text(collapsedLabel, 0, 0);
      popMatrix();
    } else {
      // 如果没有标签，显示简单的箭头
      fill(220, 230, 255);
      textSize(14 * scale);
      textAlign(CENTER, CENTER);
      String arrow = (side == DRAWER_LEFT) ? (expanded ? "<" : ">") : (expanded ? ">" : "<");
      text(arrow, toggleBtnX + toggleBtnWidth / 2, toggleBtnY + toggleBtnHeight / 2);
    }
    popStyle();
  }

  void drawCollapsedLabel() {
    // 标签已集成在按钮中，不再单独绘制
  }

  boolean handleClick(float mx, float my) {
    float scale = uiScale;

    // 如果内容不可见，不处理任何点击
    if (!shouldBeVisible()) {
      return false;
    }

    // 检查切换按钮点击
    updateToggleButtonPosition();
    boolean clicked = (mx >= toggleBtnX && mx <= toggleBtnX + toggleBtnWidth &&
                      my >= toggleBtnY && my <= toggleBtnY + toggleBtnHeight);

    if (clicked) {
      expanded = !expanded;
      return true;
    }

    // 未展开时，只响应按钮点击
    if (!expanded) {
      return false;
    }

    if (content != null) {
      float contentY = 120 * scale;
      float contentHeight = content.getContentHeight();
      if (mx >= currentPosition && mx <= currentPosition + panelWidth &&
          my >= contentY && my <= contentY + contentHeight) {
        return content.handleContentClick(mx, my, currentPosition, contentY, panelWidth);
      }
    }

    return false;
  }

  String getToggleButtonTooltip() {
    // 如果内容不可见，不显示提示
    if (!shouldBeVisible()) {
      return null;
    }

    // 检查按钮悬停
    updateToggleButtonPosition();
    boolean hovered = (mouseX >= toggleBtnX && mouseX <= toggleBtnX + toggleBtnWidth &&
                      mouseY >= toggleBtnY && mouseY <= toggleBtnY + toggleBtnHeight);

    if (hovered && toggleBtnHoverFrames >= Button.TOOLTIP_DELAY) {
      if (side == DRAWER_LEFT) {
        return expanded ? "Collapse navigation panel" : "Expand navigation panel";
      } else {
        return expanded ? "Collapse mission panel" : "Expand mission panel";
      }
    }
    return null;
  }

  String getContentTooltip() {
    // 如果内容不可见，不显示提示
    if (!shouldBeVisible()) {
      return null;
    }

    if (content != null) {
      return content.getContentTooltip();
    }
    return null;
  }

  float[] getContentTooltipSource() {
    // 如果内容不可见，不返回提示源
    if (!shouldBeVisible()) {
      return null;
    }

    if (content != null) {
      return content.getContentTooltipSource();
    }
    return null;
  }
}
