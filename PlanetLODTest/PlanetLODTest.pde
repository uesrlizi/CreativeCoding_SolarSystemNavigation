// Planet LOD 测试项目
// 用于测试和对比不同的天体渲染LOD方案

// ========== 全局状态 ==========
SimpleCamera camera;
EarthRenderer earth;
DebugUI debugUI;

int currentLOD = -1; // -1 = 自动选择
String[] lodNames = {"LOD0 (简单圆)", "LOD1 (简化大陆)", "LOD2 (中等细节)", "LOD3 (详细大陆)", "LOD4 (最高细节)", "LOD5 (缓存)"};

void setup() {
  size(1280, 720, P2D);
  smooth(8);

  // 初始化摄像机
  camera = new SimpleCamera();
  camera.scale = 1.0;
  camera.targetScale = 1.0;

  // 初始化地球渲染器
  earth = new EarthRenderer();

  // 初始化调试UI
  debugUI = new DebugUI();
}

void draw() {
  background(10, 15, 30);

  // 更新
  camera.update();
  earth.update();

  // 绘制星空背景
  drawStarfield();

  // 绘制地球 - 根据距离自动选择LOD，或强制使用指定LOD
  pushMatrix();
  translate(width/2, height/2);
  camera.apply();

  if (currentLOD == -1) {
    earth.drawAutoLOD(camera.getDistance());
  } else {
    earth.drawLOD(currentLOD, camera.getDistance());
  }

  popMatrix();

  // 绘制调试UI
  debugUI.draw(camera, earth);
}

void drawStarfield() {
  // 简单星空背景
  noStroke();
  int seed = 12345;
  for (int i = 0; i < 200; i++) {
    randomSeed(seed + i);
    float x = random(width);
    float y = random(height);
    float bright = 0.3 + random(0.7);
    fill(255, 255, 255, (int)(bright * 150));
    ellipse(x, y, random(1, 2.5), random(1, 2.5));
  }
}

// ========== 输入处理 ==========
void mousePressed() {
  camera.handleMousePressed();
}

void mouseDragged() {
  camera.handleMouseDragged();
}

void mouseReleased() {
  camera.handleMouseReleased();
}

void mouseWheel(MouseEvent event) {
  camera.handleMouseWheel(event);
}

void keyPressed() {
  // LOD选择：0-5
  if (key >= '0' && key <= '5') {
    currentLOD = key - '0';
    earth.clearCache(); // 切换时清缓存
  }
  // 按A恢复自动选择
  if (key == 'a' || key == 'A') {
    currentLOD = -1;
  }
  // 按R重置摄像机
  if (key == 'r' || key == 'R') {
    camera.reset();
  }
  // 按C切换缓存启用/禁用
  if (key == 'c' || key == 'C') {
    earth.toggleCache();
  }
  // 空格键暂停旋转
  if (key == ' ') {
    earth.toggleRotation();
  }
}

