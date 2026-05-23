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
static final int DRAWER_BOTTOM = 2;

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
  float verticalOffset;  // 垂直偏移
  boolean showToggleButton;  // 是否显示切换按钮

  DrawerContent content;

  DrawerPanel(int side, float panelWidth, float visibleWidthWhenCollapsed, DrawerContent content, String collapsedLabel) {
    this(side, panelWidth, visibleWidthWhenCollapsed, content, collapsedLabel, 0, true);
  }

  DrawerPanel(int side, float panelWidth, float visibleWidthWhenCollapsed, DrawerContent content, String collapsedLabel, float verticalOffset) {
    this(side, panelWidth, visibleWidthWhenCollapsed, content, collapsedLabel, verticalOffset, true);
  }

  DrawerPanel(int side, float panelWidth, float visibleWidthWhenCollapsed, DrawerContent content, String collapsedLabel, float verticalOffset, boolean showToggleButton) {
    this.side = side;
    this.panelWidth = panelWidth;
    this.visibleWidthWhenCollapsed = visibleWidthWhenCollapsed;
    this.content = content;
    this.collapsedLabel = collapsedLabel;
    this.verticalOffset = verticalOffset;
    this.showToggleButton = showToggleButton;

    float scale = uiScale;
    if (side == DRAWER_BOTTOM) {
      this.toggleBtnWidth = 120 * scale;  // 宽按钮
      this.toggleBtnHeight = 36 * scale;   // 矮高度
    } else {
      this.toggleBtnWidth = 36 * scale;    // 窄宽度
      this.toggleBtnHeight = 120 * scale;  // 高高度，纵向长条
    }
    this.animationSpeed = 0.15f;
    this.expanded = true;
    this.toggleBtnHover = false;
    this.toggleBtnHoverFrames = 0;

    updateTargetPositions();
    this.currentPosition = collapsedPosition;  // 从折叠位置开始
  }

  void updateTargetPositions() {
    float scale = uiScale;
    if (side == DRAWER_LEFT) {
      expandedPosition = 10 * scale;
      collapsedPosition = -panelWidth;
    } else if (side == DRAWER_RIGHT) {
      expandedPosition = width - panelWidth - 10 * scale;
      collapsedPosition = width;
    } else if (side == DRAWER_BOTTOM) {
      float contentHeight = (content != null) ? content.getContentHeight() : 100 * scale;
      expandedPosition = height - contentHeight - 10 * scale;
      collapsedPosition = height;
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

    // 对于底部抽屉，根据内容是否应该可见自动控制展开状态
    if (side == DRAWER_BOTTOM && content != null) {
      expanded = content.shouldBeVisible();
    }

    float target = expanded ? expandedPosition : collapsedPosition;
    currentPosition = lerp(currentPosition, target, animationSpeed);

    if (content != null) {
      float scale = uiScale;
      float contentX, contentY, contentW;
      if (side == DRAWER_BOTTOM) {
        contentW = width * 0.5f;
        contentX = (width - contentW) / 2;
        contentY = currentPosition;
      } else {
        contentW = panelWidth;
        contentX = currentPosition;
        contentY = 120 * scale + verticalOffset;
      }
      content.updateContent(contentX, contentY, contentW);
    }

    // 只有在 showToggleButton 为 true 时才处理按钮相关逻辑
    if (showToggleButton) {
      updateToggleButtonPosition();

      toggleBtnHover = (mouseX >= toggleBtnX && mouseX <= toggleBtnX + toggleBtnWidth &&
                       mouseY >= toggleBtnY && mouseY <= toggleBtnY + toggleBtnHeight);
      if (toggleBtnHover) {
        toggleBtnHoverFrames++;
      } else {
        toggleBtnHoverFrames = 0;
      }
    }
  }

  void updateToggleButtonPosition() {
    float scale = uiScale;
    float contentHeight = (content != null) ? content.getContentHeight() : 200 * scale;

    if (side == DRAWER_LEFT) {
      toggleBtnX = currentPosition + panelWidth + 4 * scale;
      float panelTop = 120 * scale + verticalOffset;
      toggleBtnY = panelTop + contentHeight / 2 - toggleBtnHeight / 2;
    } else if (side == DRAWER_RIGHT) {
      toggleBtnX = currentPosition - toggleBtnWidth - 4 * scale;
      float panelTop = 120 * scale + verticalOffset;
      toggleBtnY = panelTop + contentHeight / 2 - toggleBtnHeight / 2;
    } else if (side == DRAWER_BOTTOM) {
      // 对于底部抽屉，按钮横向显示在面板上方
      toggleBtnWidth = 120 * scale;  // 宽按钮
      toggleBtnHeight = 36 * scale;  // 矮高度
      toggleBtnX = (width - toggleBtnWidth) / 2;
      toggleBtnY = currentPosition - toggleBtnHeight - 4 * scale;
    }
  }

  void draw() {
    // 如果内容不可见，完全不绘制
    if (!shouldBeVisible()) {
      return;
    }

    float scale = uiScale;
    pushStyle();

    if (content != null) {
      float contentX, contentY, contentHeight, contentW;

      // 始终绘制面板，根据 currentPosition 平滑滑动
      // 通过判断面板位置决定是否绘制内容（完全折叠时不绘制）
      float visibleRatio;

      if (side == DRAWER_BOTTOM) {
        contentW = width * 0.5f;
        contentX = (width - contentW) / 2;
        contentY = currentPosition;
        contentHeight = content.getContentHeight();
        visibleRatio = (collapsedPosition - currentPosition) / (collapsedPosition - expandedPosition);
      } else {
        contentW = panelWidth;
        contentX = currentPosition;
        contentY = 120 * scale + verticalOffset;
        contentHeight = content.getContentHeight();
        if (side == DRAWER_LEFT) {
          visibleRatio = (currentPosition - collapsedPosition) / (expandedPosition - collapsedPosition);
        } else {
          visibleRatio = (collapsedPosition - currentPosition) / (collapsedPosition - expandedPosition);
        }
      }

      visibleRatio = constrain(visibleRatio, 0, 1);

      // 只要面板稍微展开就绘制背景和内容
      if (visibleRatio > 0.01) {
        noStroke();
        fill(0, 0, 0, 150);
        rect(contentX, contentY, contentW, contentHeight, 8 * scale);

        // 同时绘制内容
        content.drawContent(contentX, contentY, contentW, contentHeight);
      }
    }

    // 只有在 showToggleButton 为 true 时才绘制按钮
    if (showToggleButton) {
      // 确保按钮位置与面板同步更新
      updateToggleButtonPosition();
      drawToggleButton();
    }

    popStyle();
  }

  void drawToggleButton() {
    float scale = uiScale;
    pushStyle();
    noStroke();
    fill(toggleBtnHover ? color(80, 100, 140, 200) : color(40, 50, 70, 180));
    rect(toggleBtnX, toggleBtnY, toggleBtnWidth, toggleBtnHeight, 6 * scale);

    // 绘制标签栏文本
    if (collapsedLabel != null && collapsedLabel.length() > 0) {
      fill(255, 200, 100);
      textSize(14 * scale);
      textAlign(CENTER, CENTER);

      if (side == DRAWER_BOTTOM) {
        // 底部抽屉，横向显示文本
        text(collapsedLabel, toggleBtnX + toggleBtnWidth / 2, toggleBtnY + toggleBtnHeight / 2);
      } else {
        // 左右抽屉，纵向显示文本（旋转90度）
        pushMatrix();
        translate(toggleBtnX + toggleBtnWidth / 2, toggleBtnY + toggleBtnHeight / 2);
        rotate(HALF_PI); // 旋转90度
        text(collapsedLabel, 0, 0);
        popMatrix();
      }
    } else {
      // 如果没有标签，显示简单的箭头
      fill(220, 230, 255);
      textSize(14 * scale);
      textAlign(CENTER, CENTER);
      String arrow;
      if (side == DRAWER_LEFT) {
        arrow = expanded ? "<" : ">";
      } else if (side == DRAWER_RIGHT) {
        arrow = expanded ? ">" : "<";
      } else { // DRAWER_BOTTOM
        arrow = expanded ? "v" : "^";
      }
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

    // 如果不显示按钮，或者是底部抽屉，不响应按钮点击
    if (!showToggleButton || side == DRAWER_BOTTOM) {
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
      float contentY = 120 * scale + verticalOffset;
      float contentHeight = content.getContentHeight();
      if (mx >= currentPosition && mx <= currentPosition + panelWidth &&
          my >= contentY && my <= contentY + contentHeight) {
        return content.handleContentClick(mx, my, currentPosition, contentY, panelWidth);
      }
    }

    return false;
  }

  String getToggleButtonTooltip() {
    // 如果不显示按钮，或者是底部抽屉，不显示工具提示
    if (!showToggleButton || side == DRAWER_BOTTOM) {
      return null;
    }

    // 如果内容不可见，不显示提示
    if (!shouldBeVisible()) {
      return null;
    }

    // 检查按钮悬停
    updateToggleButtonPosition();
    boolean hovered = (mouseX >= toggleBtnX && mouseX <= toggleBtnX + toggleBtnWidth &&
                      mouseY >= toggleBtnY && mouseY <= toggleBtnY + toggleBtnHeight);

    if (hovered && toggleBtnHoverFrames >= Button.TOOLTIP_DELAY) {
      String label = (collapsedLabel != null) ? collapsedLabel.toLowerCase() : "panel";
      return expanded ? "Collapse " + label : "Expand " + label;
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
