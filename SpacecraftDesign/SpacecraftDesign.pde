// Spacecraft Design Tool
// 宇宙飞船设计工具 - 纯Processing实现，无需外部库

color shipColor = color(200, 200, 210);

float bodyLength = 12.0;
float bodyWidth = 6.0;

float wingAngle = 45.0;
float wingLength = 10.0;
float wingWidth = 4.0;

float engineSize = 5.0;
float flameLength = 8.0;
float flameIntensity = 180.0;

float glowSize = 16.0;
float glowAlpha = 60.0;

float scale = 3.0;

int controlPanelX = 20;
int controlPanelWidth = 250;
int controlStartY = 80;

Slider[] sliders = new Slider[11];
Button resetBtn;
Button printBtn;

void setup() {
  size(900, 700);
  pixelDensity(1);
  
  int y = controlStartY;
  int spacing = 32;
  
  sliders[0] = new Slider(controlPanelX, y, "Body Length", 5, 30, bodyLength);
  y += spacing;
  sliders[1] = new Slider(controlPanelX, y, "Body Width", 2, 12, bodyWidth);
  y += spacing;
  
  sliders[2] = new Slider(controlPanelX, y, "Wing Angle", 20, 80, wingAngle);
  y += spacing;
  sliders[3] = new Slider(controlPanelX, y, "Wing Length", 5, 20, wingLength);
  y += spacing;
  sliders[4] = new Slider(controlPanelX, y, "Wing Width", 2, 8, wingWidth);
  y += spacing;
  
  sliders[5] = new Slider(controlPanelX, y, "Engine Size", 2, 10, engineSize);
  y += spacing;
  sliders[6] = new Slider(controlPanelX, y, "Flame Length", 3, 15, flameLength);
  y += spacing;
  sliders[7] = new Slider(controlPanelX, y, "Flame Intensity", 100, 255, flameIntensity);
  y += spacing;
  
  sliders[8] = new Slider(controlPanelX, y, "Glow Size", 8, 25, glowSize);
  y += spacing;
  sliders[9] = new Slider(controlPanelX, y, "Glow Alpha", 20, 100, glowAlpha);
  y += spacing;
  
  sliders[10] = new Slider(controlPanelX, y, "Preview Scale", 1, 8, scale);
  y += spacing + 20;
  
  resetBtn = new Button(controlPanelX, y, 100, 30, "Reset Defaults");
  printBtn = new Button(controlPanelX + 120, y, 100, 30, "Print Code");
}

void draw() {
  background(20);
  
  for (int i = 0; i < sliders.length; i++) {
    if (sliders[i] != null) {
      sliders[i].update();
    }
  }
  
  if (resetBtn != null) {
    resetBtn.update();
  }
  
  if (printBtn != null) {
    printBtn.update();
  }
  
  drawControlPanel();
  
  pushMatrix();
  translate(width / 2, height / 2);
  drawGrid();
  popMatrix();
  
  pushMatrix();
  translate(width / 2, height / 2);
  rotate(-HALF_PI);
  if (sliders[10] != null) {
    scale = sliders[10].getValue();
  }
  pushMatrix();
  scale(scale);
  drawSpacecraft(0, 0, 0);
  popMatrix();
  popMatrix();
  
  drawInfo();
}

void drawControlPanel() {
  fill(0, 0, 0, 200);
  noStroke();
  rect(0, 0, controlPanelWidth + 40, height);
  
  fill(255);
  textSize(20);
  textAlign(LEFT, TOP);
  text("Spacecraft Designer", controlPanelX, 20);
  
  textSize(12);
  fill(180);
  text("Drag sliders to adjust parameters", controlPanelX, 50);
}

void drawGrid() {
  stroke(50);
  strokeWeight(1);
  for (int i = -width/2; i < width/2; i += 50) {
    line(i, -height/2, i, height/2);
  }
  for (int i = -height/2; i < height/2; i += 50) {
    line(-width/2, i, width/2, i);
  }
}

void drawSpacecraft(float x, float y, float angle) {
  pushMatrix();
  translate(x, y);
  rotate(angle);
  
  drawGlow();
  drawWings();
  drawEngineFlame();
  drawBody();
  
  popMatrix();
}

void drawBody() {
  fill(shipColor);
  noStroke();
  
  beginShape();
  vertex(bodyLength * 0.5, 0);
  vertex(-bodyLength * 0.3, -bodyWidth * 0.5);
  vertex(-bodyLength * 0.5, -bodyWidth * 0.3);
  vertex(-bodyLength * 0.5, bodyWidth * 0.3);
  vertex(-bodyLength * 0.3, bodyWidth * 0.5);
  endShape(CLOSE);
}

void drawWings() {
  fill(shipColor);
  noStroke();
  
  pushMatrix();
  rotate(radians(wingAngle));
  rect(0, 0, wingLength, wingWidth, 2);
  popMatrix();
  
  pushMatrix();
  rotate(radians(-wingAngle));
  rect(0, -wingWidth, wingLength, wingWidth, 2);
  popMatrix();
}

void drawEngineFlame() {
  noStroke();
  
  fill(255, 150, 50, flameIntensity * 0.5);
  triangle(
    -bodyLength * 0.5, -engineSize * 0.6,
    -bodyLength * 0.5, engineSize * 0.6,
    -bodyLength * 0.5 - flameLength * 1.5, 0
  );
  
  fill(255, 200, 50, flameIntensity);
  triangle(
    -bodyLength * 0.5, -engineSize * 0.4,
    -bodyLength * 0.5, engineSize * 0.4,
    -bodyLength * 0.5 - flameLength, 0
  );
  
  fill(255, 255, 200, flameIntensity);
  triangle(
    -bodyLength * 0.5, -engineSize * 0.2,
    -bodyLength * 0.5, engineSize * 0.2,
    -bodyLength * 0.5 - flameLength * 0.6, 0
  );
}

void drawGlow() {
  noStroke();
  for (int i = 3; i >= 1; i--) {
    fill(red(shipColor), green(shipColor), blue(shipColor), glowAlpha / i);
    ellipse(0, 0, glowSize + i * 4, glowSize + i * 4);
  }
}

void drawInfo() {
  if (sliders[0] != null) {
    bodyLength = sliders[0].getValue();
  }
  if (sliders[1] != null) {
    bodyWidth = sliders[1].getValue();
  }
  if (sliders[2] != null) {
    wingAngle = sliders[2].getValue();
  }
  if (sliders[3] != null) {
    wingLength = sliders[3].getValue();
  }
  if (sliders[4] != null) {
    wingWidth = sliders[4].getValue();
  }
  if (sliders[5] != null) {
    engineSize = sliders[5].getValue();
  }
  if (sliders[6] != null) {
    flameLength = sliders[6].getValue();
  }
  if (sliders[7] != null) {
    flameIntensity = sliders[7].getValue();
  }
  if (sliders[8] != null) {
    glowSize = sliders[8].getValue();
  }
  if (sliders[9] != null) {
    glowAlpha = sliders[9].getValue();
  }
  
  fill(255);
  textSize(14);
  textAlign(LEFT, TOP);
  
  float x = width - 250;
  float y = 30;
  
  text("Current Values:", x, y);
  y += 25;
  textSize(12);
  fill(200);
  text("Body: " + nf(bodyLength, 1, 1) + " x " + nf(bodyWidth, 1, 1), x, y);
  y += 20;
  text("Wings: " + nf(wingAngle, 2, 1) + " deg", x, y);
  y += 20;
  text("Engine Flame: " + nf(flameLength, 1, 1), x, y);
  y += 20;
  text("Glow: " + nf(glowSize, 1, 1), x, y);
  y += 20;
  text("Scale: " + nf(scale, 1, 1) + "x", x, y);
  
  y += 40;
  fill(150);
  textSize(11);
  text("Press P to print code", x, y);
  text("Press R to reset", x, y + 15);
}

void keyPressed() {
  if (key == 'p' || key == 'P') {
    printCode();
  }
  if (key == 'r' || key == 'R') {
    resetDefaults();
  }
}

void resetDefaults() {
  if (sliders[0] != null) sliders[0].setValue(12.0);
  if (sliders[1] != null) sliders[1].setValue(6.0);
  if (sliders[2] != null) sliders[2].setValue(45.0);
  if (sliders[3] != null) sliders[3].setValue(10.0);
  if (sliders[4] != null) sliders[4].setValue(4.0);
  if (sliders[5] != null) sliders[5].setValue(5.0);
  if (sliders[6] != null) sliders[6].setValue(8.0);
  if (sliders[7] != null) sliders[7].setValue(180.0);
  if (sliders[8] != null) sliders[8].setValue(16.0);
  if (sliders[9] != null) sliders[9].setValue(60.0);
  if (sliders[10] != null) sliders[10].setValue(3.0);
}

void printCode() {
  println("\n========================================");
  println("SPACECRAFT DRAWING CODE");
  println("========================================\n");
  
  println("void drawSpacecraft(float x, float y, float angle) {");
  println("  pushMatrix();");
  println("  translate(x, y);");
  println("  rotate(angle);");
  println("");
  println("  // Glow effect");
  println("  noStroke();");
  println("  for (int i = 3; i >= 1; i--) {");
  println("    fill(red(shipColor), green(shipColor), blue(shipColor), " + (int)glowAlpha + " / i);");
  println("    ellipse(0, 0, " + nf(glowSize, 1, 1) + " + i * 4, " + nf(glowSize, 1, 1) + " + i * 4);");
  println("  }");
  println("");
  println("  // Wings");
  println("  fill(shipColor);");
  println("  noStroke();");
  println("  pushMatrix();");
  println("  rotate(radians(" + nf(wingAngle, 2, 1) + "));");
  println("  rect(0, 0, " + nf(wingLength, 1, 1) + ", " + nf(wingWidth, 1, 1) + ", 2);");
  println("  popMatrix();");
  println("  pushMatrix();");
  println("  rotate(radians(-" + nf(wingAngle, 2, 1) + "));");
  println("  rect(0, -" + nf(wingWidth, 1, 1) + ", " + nf(wingLength, 1, 1) + ", " + nf(wingWidth, 1, 1) + ", 2);");
  println("  popMatrix();");
  println("");
  println("  // Engine flame");
  println("  noStroke();");
  println("  fill(255, 150, 50, " + (int)(flameIntensity * 0.5) + ");");
  println("  triangle(");
  println("    -" + nf(bodyLength * 0.5, 1, 1) + ", -" + nf(engineSize * 0.6, 1, 1) + ",");
  println("    -" + nf(bodyLength * 0.5, 1, 1) + ", " + nf(engineSize * 0.6, 1, 1) + ",");
  println("    -" + nf(bodyLength * 0.5 + flameLength * 1.5, 1, 1) + ", 0");
  println("  );");
  println("  fill(255, 200, 50, " + (int)flameIntensity + ");");
  println("  triangle(");
  println("    -" + nf(bodyLength * 0.5, 1, 1) + ", -" + nf(engineSize * 0.4, 1, 1) + ",");
  println("    -" + nf(bodyLength * 0.5, 1, 1) + ", " + nf(engineSize * 0.4, 1, 1) + ",");
  println("    -" + nf(bodyLength * 0.5 + flameLength, 1, 1) + ", 0");
  println("  );");
  println("  fill(255, 255, 200, " + (int)flameIntensity + ");");
  println("  triangle(");
  println("    -" + nf(bodyLength * 0.5, 1, 1) + ", -" + nf(engineSize * 0.2, 1, 1) + ",");
  println("    -" + nf(bodyLength * 0.5, 1, 1) + ", " + nf(engineSize * 0.2, 1, 1) + ",");
  println("    -" + nf(bodyLength * 0.5 + flameLength * 0.6, 1, 1) + ", 0");
  println("  );");
  println("");
  println("  // Body");
  println("  fill(shipColor);");
  println("  noStroke();");
  println("  beginShape();");
  println("  vertex(" + nf(bodyLength * 0.5, 1, 1) + ", 0);");
  println("  vertex(-" + nf(bodyLength * 0.3, 1, 1) + ", -" + nf(bodyWidth * 0.5, 1, 1) + ");");
  println("  vertex(-" + nf(bodyLength * 0.5, 1, 1) + ", -" + nf(bodyWidth * 0.3, 1, 1) + ");");
  println("  vertex(-" + nf(bodyLength * 0.5, 1, 1) + ", " + nf(bodyWidth * 0.3, 1, 1) + ");");
  println("  vertex(-" + nf(bodyLength * 0.3, 1, 1) + ", " + nf(bodyWidth * 0.5, 1, 1) + ");");
  println("  endShape(CLOSE);");
  println("");
  println("  popMatrix();");
  println("}");
  println("\n========================================\n");
  println("Required variables:");
  println("color shipColor = color(200, 200, 210);");
  println("float bodyLength = " + nf(bodyLength, 1, 1) + ";");
  println("float bodyWidth = " + nf(bodyWidth, 1, 1) + ";");
  println("float wingAngle = " + nf(wingAngle, 2, 1) + ";");
  println("float wingLength = " + nf(wingLength, 1, 1) + ";");
  println("float wingWidth = " + nf(wingWidth, 1, 1) + ";");
  println("float engineSize = " + nf(engineSize, 1, 1) + ";");
  println("float flameLength = " + nf(flameLength, 1, 1) + ";");
  println("float flameIntensity = " + (int)flameIntensity + ";");
  println("float glowSize = " + nf(glowSize, 1, 1) + ";");
  println("float glowAlpha = " + (int)glowAlpha + ";");
  println("\n========================================\n");
}

class Slider {
  float x, y, w, h;
  String label;
  float minVal, maxVal;
  float value;
  
  Slider(float x, float y, String label, float minVal, float maxVal, float defaultVal) {
    this.x = x;
    this.y = y;
    this.label = label;
    this.minVal = minVal;
    this.maxVal = maxVal;
    this.value = defaultVal;
    this.w = 200;
    this.h = 20;
  }
  
  void update() {
    if (mousePressed) {
      if (mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h) {
        value = map(mouseX, x, x + w, minVal, maxVal);
        value = constrain(value, minVal, maxVal);
      }
    }
    
    fill(60);
    noStroke();
    rect(x, y, w, h, 3);
    
    fill(100, 150, 255);
    float handleX = map(value, minVal, maxVal, x, x + w);
    rect(handleX - 5, y, 10, h, 2);
    
    fill(255);
    textSize(11);
    textAlign(LEFT, CENTER);
    text(label + ": " + nf(value, 1, 1), x, y - 15);
  }
  
  float getValue() {
    return value;
  }
  
  void setValue(float v) {
    value = constrain(v, minVal, maxVal);
  }
}

class Button {
  float x, y, w, h;
  String label;
  boolean hover = false;
  
  Button(float x, float y, float w, float h, String label) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
  }
  
  void update() {
    hover = (mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h);
    
    if (hover) {
      fill(80, 120, 200);
    } else {
      fill(60, 100, 180);
    }
    noStroke();
    rect(x, y, w, h, 5);
    
    fill(255);
    textSize(12);
    textAlign(CENTER, CENTER);
    text(label, x + w/2, y + h/2);
    
    if (hover && mousePressed) {
      if (label.equals("Reset Defaults")) {
        resetDefaults();
      } else if (label.equals("Print Code")) {
        printCode();
      }
      delay(200);
    }
  }
}
