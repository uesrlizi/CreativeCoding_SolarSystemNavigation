// ========== LABEL MANAGER ==========

class Label {
  String text;
  float x, y;  // Anchor position (body position)
  float bodyRadius;  // Screen radius of the body
  color col;
  int priority;  // Higher = more important
  float offsetDir;  // 0=right, 1=up, 2=left, 3=down
  float labelWidth, labelHeight;
  float drawX, drawY;  // Final draw position
  boolean visible;

  // For apoapsis/periapsis markers
  boolean isMarker;  // true if this is an AP/PE marker with icon + label
  float markerSize;  // Size of the marker circle
  float markerDrawX, markerDrawY;  // Position of the marker

  Label(String t, float x_, float y_, float r, color c, int p, float d) {
    text = t;
    x = x_;
    y = y_;
    bodyRadius = r;
    col = c;
    priority = p;
    offsetDir = d;
    visible = true;
    isMarker = false;
  }

  // Constructor for markers (AP/PE)
  Label(String t, float x_, float y_, float markerSize_, color c, int p) {
    text = t;
    x = x_;
    y = y_;
    bodyRadius = 0;
    col = c;
    priority = p;
    offsetDir = 0;
    visible = true;
    isMarker = true;
    markerSize = markerSize_;
  }

  void calculateSize() {
    if (isMarker) {
      // Marker: small circle + short label
      pushStyle();
      textSize(11 * uiScale);
      labelWidth = textWidth(text) + markerSize + 6;
      labelHeight = max(markerSize, 14 * uiScale);
      popStyle();
    } else {
      // Regular body label
      pushStyle();
      textSize(17 * uiScale);
      labelWidth = textWidth(text) + 10;
      labelHeight = 20 * uiScale;
      popStyle();
    }
  }

  void calculateDrawPosition() {
    if (isMarker) {
      // Marker draws icon at x,y and label to the right
      markerDrawX = x;
      markerDrawY = y;
      drawX = x + markerSize / 2 + 3;
      drawY = y;
    } else {
      float offsetDist = max(bodyRadius + 5, 8);
      switch((int)offsetDir) {
        case 0:  // Right
          drawX = x + offsetDist;
          drawY = y;
          break;
        case 1:  // Up
          drawX = x - labelWidth / 2;
          drawY = y - offsetDist - labelHeight / 2;
          break;
        case 2:  // Left
          drawX = x - offsetDist - labelWidth;
          drawY = y;
          break;
        case 3:  // Down
          drawX = x - labelWidth / 2;
          drawY = y + offsetDist + labelHeight / 2;
          break;
      }
    }
  }

  boolean intersects(Label other) {
    // Get bounding boxes for both labels
    float aLeft, aRight, aTop, aBottom;
    float bLeft, bRight, bTop, bBottom;

    if (isMarker) {
      // Marker bounding box includes the icon and label
      aLeft = x - markerSize / 2;
      aRight = x + labelWidth;
      aTop = y - max(markerSize, labelHeight) / 2;
      aBottom = y + max(markerSize, labelHeight) / 2;
    } else {
      aLeft = drawX;
      aRight = drawX + labelWidth;
      aTop = drawY;
      aBottom = drawY + labelHeight;
    }

    if (other.isMarker) {
      bLeft = other.x - other.markerSize / 2;
      bRight = other.x + other.labelWidth;
      bTop = other.y - max(other.markerSize, other.labelHeight) / 2;
      bBottom = other.y + max(other.markerSize, other.labelHeight) / 2;
    } else {
      bLeft = other.drawX;
      bRight = other.drawX + other.labelWidth;
      bTop = other.drawY;
      bBottom = other.drawY + other.labelHeight;
    }

    return aLeft < bRight && aRight > bLeft &&
           aTop < bBottom && aBottom > bTop;
  }
}

class LabelManager {
  ArrayList<Label> labels;

  LabelManager() {
    labels = new ArrayList<Label>();
  }

  void reset() {
    labels.clear();
  }

  void addLabel(String text, float x, float y, float bodyRadius, color col, int priority, float offsetDir) {
    labels.add(new Label(text, x, y, bodyRadius, col, priority, offsetDir));
  }

  void addMarker(String text, float x, float y, float markerSize, color col, int priority) {
    labels.add(new Label(text, x, y, markerSize, col, priority));
  }

  void processLabels() {
    // First calculate all sizes
    for (Label l : labels) {
      l.calculateSize();
    }
    // Sort by priority descending
    sortLabels();
    // Calculate draw positions with smart offset direction
    for (Label l : labels) {
      l.calculateDrawPosition();
    }
    // Resolve collisions - hide lower priority labels
    resolveCollisions();
  }

  void sortLabels() {
    // Bubble sort by priority descending
    for (int i = 0; i < labels.size(); i++) {
      for (int j = i + 1; j < labels.size(); j++) {
        if (labels.get(i).priority < labels.get(j).priority) {
          Label temp = labels.get(i);
          labels.set(i, labels.get(j));
          labels.set(j, temp);
        }
      }
    }
  }

  void resolveCollisions() {
    // Keep high priority labels, hide overlapping lower ones
    for (int i = 0; i < labels.size(); i++) {
      Label a = labels.get(i);
      if (!a.visible) continue;
      for (int j = i + 1; j < labels.size(); j++) {
        Label b = labels.get(j);
        if (!b.visible) continue;
        if (a.intersects(b)) {
          // a has higher priority, hide b
          b.visible = false;
        }
      }
    }
  }

  void drawLabels() {
    for (Label l : labels) {
      if (!l.visible) continue;

      if (l.isMarker) {
        // Draw marker (AP/PE)
        // Check if within screen (with margin)
        float margin = 20;
        if (l.x + l.labelWidth < -margin || l.x > width + margin ||
            l.y + l.labelHeight < -margin || l.y > height + margin) {
          continue;
        }
        pushStyle();
        noStroke();
        fill(l.col, 200);
        ellipse(l.markerDrawX, l.markerDrawY, l.markerSize, l.markerSize);
        fill(255, 230);
        textSize(11 * uiScale);
        textAlign(LEFT, CENTER);
        text(l.text, l.drawX, l.drawY);
        popStyle();
      } else {
        // Draw regular body label
        if (l.drawX + l.labelWidth < 0 || l.drawX > width ||
            l.drawY + l.labelHeight < 0 || l.drawY > height) {
          continue;
        }
        pushStyle();
        noStroke();
        fill(l.col, 200);
        textSize(17 * uiScale);
        if (l.offsetDir == 0 || l.offsetDir == 2) {
          textAlign(l.offsetDir == 0 ? LEFT : RIGHT, CENTER);
          text(l.text, l.offsetDir == 0 ? l.drawX : l.drawX + l.labelWidth, l.drawY + l.labelHeight/2);
        } else {
          textAlign(CENTER, l.offsetDir == 1 ? TOP : BOTTOM);
          text(l.text, l.drawX + l.labelWidth/2, l.offsetDir == 1 ? l.drawY : l.drawY + l.labelHeight);
        }
        popStyle();
      }
    }
  }
}
