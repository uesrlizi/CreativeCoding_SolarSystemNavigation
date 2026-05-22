// ========== 调试UI ==========
// 显示性能数据和控制选项

class DebugUI {
  // 帧率历史记录
  float[] frameTimeHistory;
  int historyIndex;
  long lastFrameNanos;

  DebugUI() {
    frameTimeHistory = new float[120];
    historyIndex = 0;
    lastFrameNanos = System.nanoTime();
  }

  void draw(SimpleCamera cam, EarthRenderer earth) {
    // 更新帧时间
    long now = System.nanoTime();
    float frameTimeMs = (now - lastFrameNanos) / 1e6f;
    lastFrameNanos = now;

    frameTimeHistory[historyIndex] = frameTimeMs;
    historyIndex = (historyIndex + 1) % frameTimeHistory.length;

    // 绘制半透明背景面板
    drawPanelBackground();

    // 绘制信息
    drawInfo(cam, earth);

    // 绘制性能图表
    drawPerformanceGraph(earth);

    // 绘制控制提示
    drawControls();
  }

  void drawPanelBackground() {
    noStroke();
    fill(0, 0, 0, 200);
    rect(10, 10, 400, 500);
  }

  void drawInfo(SimpleCamera cam, EarthRenderer earth) {
    textFont(createFont("Consolas", 14));
    textAlign(LEFT, TOP);
    noStroke();

    float y = 20;
    float lineHeight = 22;

    // 标题
    fill(255, 200, 100);
    textSize(18);
    text("Planet LOD Test", 20, y);
    y += 30;

    textSize(14);

    // ========== 当前LOD大显示 ==========
    float autoScreenRadius = cam.getScreenRadius();
    int autoLOD;
    if (autoScreenRadius < 20) autoLOD = 0;
    else if (autoScreenRadius < 80) autoLOD = 1;
    else if (autoScreenRadius < 250) autoLOD = 2;
    else if (autoScreenRadius < 500) autoLOD = 3;
    else autoLOD = 4;

    int displayLOD = (currentLOD == -1) ? autoLOD : currentLOD;

    // 大字体显示当前LOD
    textSize(36);
    fill(255, 220, 100);
    text(String.format("LOD %d", displayLOD), 20, y);
    y += 40;

    // 显示LOD名称
    textSize(16);
    fill(200, 200, 200);
    text(lodNames[displayLOD], 20, y);
    y += 28;

    // 显示是自动还是强制
    fill(currentLOD == -1 ? color(100, 200, 255) : color(255, 150, 100));
    text(currentLOD == -1 ? "模式: 自动选择" : "模式: 强制锁定", 20, y);
    y += 30;

    textSize(14);

    // 摄像机信息
    fill(200, 200, 200);
    text(String.format("距离: %.1f", cam.getDistance()), 20, y); y += lineHeight;
    text(String.format("屏幕半径: %.1f px", cam.getScreenRadius()), 20, y); y += lineHeight;
    y += 10;

    // 缓存状态
    fill(earth.useCache ? color(100, 255, 100) : color(255, 100, 100));
    text("缓存: " + (earth.useCache ? "开启" : "关闭"), 20, y); y += lineHeight;
    y += 15;

    // 各LOD的绘制时间
    fill(255, 255, 255);
    text("LOD性能 (微秒):", 20, y); y += lineHeight;

    for (int i = 0; i < 6; i++) {
      long time = earth.getLastDrawTime(i);

      // 当前使用的LOD高亮
      if (i == displayLOD) {
        fill(255, 220, 100);
        text(">", 12, y);
      }

      // 颜色表示性能
      if (time == 0) {
        fill(100, 100, 100); // 未测量
      } else if (time < 500) {
        fill(100, 255, 100); // 快
      } else if (time < 2000) {
        fill(255, 200, 50); // 中
      } else {
        fill(255, 100, 100); // 慢
      }

      text(String.format("[%d] %-12s: %6d μs", i, lodNames[i], time), 28, y);
      y += lineHeight;
    }

    y += 15;

    // 平均帧率
    float avgFrameTime = 0;
    int count = 0;
    for (float ft : frameTimeHistory) {
      if (ft > 0) {
        avgFrameTime += ft;
        count++;
      }
    }
    if (count > 0) avgFrameTime /= count;
    float fps = 1000.0f / avgFrameTime;

    fill(fps > 50 ? color(100, 255, 100) : fps > 30 ? color(255, 200, 50) : color(255, 100, 100));
    text(String.format("帧率: %.1f FPS (%.2f ms)", fps, avgFrameTime), 20, y);
  }

  void drawPerformanceGraph(EarthRenderer earth) {
    float graphX = 20;
    float graphY = 410;
    float graphW = 360;
    float graphH = 80;

    // 图表背景
    noStroke();
    fill(30, 30, 40, 200);
    rect(graphX, graphY, graphW, graphH);

    // 网格线
    stroke(60, 60, 80);
    strokeWeight(1);
    for (int i = 0; i <= 4; i++) {
      float y = graphY + i * graphH / 4;
      line(graphX, y, graphX + graphW, y);
    }

    // 绘制帧时间历史
    noStroke();
    fill(100, 200, 255, 150);
    beginShape();
    vertex(graphX, graphY + graphH);

    for (int i = 0; i < frameTimeHistory.length; i++) {
      int idx = (historyIndex - i + frameTimeHistory.length) % frameTimeHistory.length;
      float ft = frameTimeHistory[idx];
      float px = graphX + i;
      float normalized = min(ft / 50.0f, 1.0f); // 50ms 满量程
      float py = graphY + graphH * (1 - normalized);
      vertex(px, py);
    }

    // 绘制图表边框
    stroke(80, 80, 100);
    noFill();
    rect(graphX, graphY, graphW, graphH);
  }

  void drawControls() {
    // 底部控制提示
    float y = height - 80;

    noStroke();
    fill(0, 0, 0, 150);
    rect(10, y, width - 20, 70);

    textFont(createFont("Consolas", 12));
    textAlign(LEFT, TOP);
    y += 10;

    fill(255, 255, 255);
    textSize(12);

    String[] controls = {
      "左键拖拽: 平移",
      "滚轮: 缩放",
      "0-5: 强制使用指定LOD",
      "A: 自动LOD选择",
      "C: 切换缓存",
      "空格: 暂停旋转",
      "R: 重置摄像机"
    };

    float x = 20;
    for (String ctrl : controls) {
      fill(200, 200, 200);
      text(ctrl, x, y);
      x += 230;
    }
  }
}

