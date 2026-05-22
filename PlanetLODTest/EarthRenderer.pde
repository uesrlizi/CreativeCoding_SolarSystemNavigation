// ========== 地球渲染器 ==========
// LOD系统空壳

class EarthRenderer {
  float rotation;
  float rotationSpeed;
  boolean rotationPaused;

  // 缓存相关
  boolean useCache;
  PGraphics[] lodCache;
  boolean[] cacheDirty;
  float[] cachedDistances;

  // 性能统计
  long lastDrawTime;
  long[] drawTimes;
  int currentDrawTimeIndex;

  EarthRenderer() {
    rotation = 0;
    rotationSpeed = 0.005;
    rotationPaused = false;

    useCache = true;
    lodCache = new PGraphics[6];
    cacheDirty = new boolean[6];
    cachedDistances = new float[6];
    drawTimes = new long[6];

    for (int i = 0; i < 6; i++) {
      cacheDirty[i] = true;
      cachedDistances[i] = -1;
      drawTimes[i] = 0;
    }
  }

  void update() {
    if (!rotationPaused) {
      rotation += rotationSpeed;
    }
  }

  void toggleRotation() {
    rotationPaused = !rotationPaused;
  }

  void toggleCache() {
    useCache = !useCache;
  }

  void clearCache() {
    for (int i = 0; i < 6; i++) {
      cacheDirty[i] = true;
      if (lodCache[i] != null) {
        lodCache[i].dispose();
        lodCache[i] = null;
      }
    }
  }

  // ========== 自动LOD选择 ==========

  void drawAutoLOD(float distance) {
    float screenRadius = 100 * (300 / distance);

    if (screenRadius < 20) {
      drawLOD(0, distance);
    } else if (screenRadius < 80) {
      drawLOD(1, distance);
    } else if (screenRadius < 250) {
      drawLOD(2, distance);
    } else if (screenRadius < 500) {
      drawLOD(3, distance);
    } else {
      drawLOD(4, distance);
    }
  }

  // ========== 绘制指定LOD ==========

  void drawLOD(int lod, float distance) {
    long start = System.nanoTime();
    float screenRadius = 100 * (300 / distance);

    // 这里调用各LOD实现
    switch(lod) {
      case 0: drawLOD0(screenRadius); break;
      case 1: drawLOD1(screenRadius); break;
      case 2: drawLOD2(screenRadius); break;
      case 3: drawLOD3(screenRadius); break;
      case 4: drawLOD4(screenRadius); break;
      case 5: drawLOD5(screenRadius); break;
    }

    drawTimes[lod] = (System.nanoTime() - start) / 1000;
  }

  // ========== LOD实现 - 北极视角 ==========

  void drawLOD0(float r) {
    // LOD0: 简单圆 - 仅有海洋颜色
    noStroke();
    fill(60, 120, 220);
    ellipse(0, 0, r*2, r*2);
    drawAtmosphereEdge(r);
  }

  void drawLOD1(float r) {
    // LOD1: 简化大陆 - 几何图形表示主要大陆
    noStroke();
    fill(60, 120, 220);
    ellipse(0, 0, r*2, r*2);

    pushMatrix();
    rotate(rotation);

    fill(80, 160, 90);
    // 北美洲
    arc(0, 0, r*1.6, r*1.6, -PI*0.7, -PI*0.3);
    // 欧亚大陆
    arc(0, 0, r*1.7, r*1.7, PI*0.2, PI*0.8);

    popMatrix();
    drawAtmosphereEdge(r);
  }

  void drawLOD2(float r) {
    // LOD2: 中等细节 - 更多大陆形状
    noStroke();
    fill(60, 120, 220);
    ellipse(0, 0, r*2, r*2);

    pushMatrix();
    rotate(rotation);

    fill(80, 160, 90);
    // 北美洲
    beginShape();
    for (float a = -PI*0.75; a < -PI*0.25; a += 0.1) {
      float rad = r * (0.75 + sin(a*3)*0.05);
      vertex(cos(a)*rad, sin(a)*rad);
    }
    endShape(CLOSE);

    // 欧洲-亚洲
    beginShape();
    for (float a = PI*0.15; a < PI*0.85; a += 0.08) {
      float rad = r * (0.8 + sin(a*4)*0.08);
      vertex(cos(a)*rad, sin(a)*rad);
    }
    endShape(CLOSE);

    // 格陵兰岛
    fill(70, 140, 80);
    ellipse(-r*0.3, -r*0.2, r*0.25, r*0.35);

    popMatrix();
    drawAtmosphereEdge(r);
  }

  void drawLOD3(float r) {
    // LOD3: 详细大陆 - 更多地理特征
    noStroke();
    fill(60, 120, 220);
    ellipse(0, 0, r*2, r*2);

    pushMatrix();
    rotate(rotation);

    // 使用极坐标绘制大陆
    drawContinentsLOD3(r);

    popMatrix();
    drawAtmosphereEdge(r);
  }

  void drawLOD4(float r) {
    // LOD4: 最详细 - 带海岸线细节和地形起伏
    noStroke();
    fill(60, 120, 220);
    ellipse(0, 0, r*2, r*2);

    pushMatrix();
    rotate(rotation);

    drawContinentsLOD4(r);

    popMatrix();
    drawAtmosphereEdge(r);
  }

  void drawLOD5(float r) {
    // LOD5: 同LOD4但可用于缓存
    noStroke();
    fill(60, 120, 220);
    ellipse(0, 0, r*2, r*2);

    pushMatrix();
    rotate(rotation);

    drawContinentsLOD4(r);

    popMatrix();
    drawAtmosphereEdge(r);
  }

  // ========== 辅助绘制函数 ==========

  void drawContinentsLOD3(float r) {
    // 北美洲
    fill(85, 165, 95);
    beginShape();
    for (float ang = -PI*0.8; ang < -PI*0.2; ang += 0.06) {
      float nr = r * (0.72 + noise(cos(ang)*5, sin(ang)*5)*0.12);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 欧洲
    fill(80, 160, 90);
    beginShape();
    for (float ang = PI*0.1; ang < PI*0.5; ang += 0.05) {
      float nr = r * (0.65 + noise(cos(ang)*6, sin(ang)*6)*0.15);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 亚洲
    fill(75, 155, 85);
    beginShape();
    for (float ang = PI*0.4; ang < PI*0.9; ang += 0.05) {
      float nr = r * (0.75 + noise(cos(ang)*5, sin(ang)*5)*0.18);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 格陵兰
    fill(70, 145, 80);
    ellipse(-r*0.28, -r*0.25, r*0.22, r*0.32);

    // 冰岛
    fill(90, 170, 100);
    ellipse(r*0.12, -r*0.45, r*0.08, r*0.1);
  }

  void drawContinentsLOD4(float r) {
    float detail = 12;

    // 北美洲 - 更多细节
    fill(85, 165, 95);
    beginShape();
    for (float ang = -PI*0.85; ang < -PI*0.18; ang += 0.03) {
      float nr = r * (0.72 + noise(cos(ang)*detail, sin(ang)*detail)*0.15);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 北美洲内陆细节
    fill(75, 150, 85);
    beginShape();
    for (float ang = -PI*0.75; ang < -PI*0.3; ang += 0.04) {
      float nr = r * (0.5 + noise(cos(ang)*detail*1.5, sin(ang)*detail*1.5)*0.12);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 欧洲
    fill(80, 160, 90);
    beginShape();
    for (float ang = PI*0.08; ang < PI*0.52; ang += 0.03) {
      float nr = r * (0.62 + noise(cos(ang)*detail*1.2, sin(ang)*detail*1.2)*0.18);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 亚洲
    fill(72, 152, 82);
    beginShape();
    for (float ang = PI*0.38; ang < PI*0.95; ang += 0.03) {
      float nr = r * (0.78 + noise(cos(ang)*detail, sin(ang)*detail)*0.2);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 西伯利亚高原
    fill(65, 140, 75);
    beginShape();
    for (float ang = PI*0.5; ang < PI*0.85; ang += 0.04) {
      float nr = r * (0.55 + noise(cos(ang)*detail*1.5, sin(ang)*detail*1.5)*0.12);
      vertex(cos(ang)*nr, sin(ang)*nr);
    }
    endShape(CLOSE);

    // 格陵兰
    fill(70, 145, 80);
    pushStyle();
    noStroke();
    beginShape();
    float ga0 = -PI*0.6, ga1 = -PI*0.1;
    for (float ang = ga0; ang < ga1; ang += 0.05) {
      float nr = r * (0.28 + noise(cos(ang)*8, sin(ang)*8)*0.08);
      float cx = -r*0.28 + cos(ang)*nr;
      float cy = -r*0.25 + sin(ang)*nr;
      if (cx*cx + cy*cy < r*r) vertex(cx, cy);
    }
    endShape(CLOSE);
    popStyle();

    // 冰盖中心
    fill(200, 220, 240, 100);
    ellipse(-r*0.28, -r*0.25, r*0.12, r*0.18);

    // 冰岛
    fill(90, 170, 100);
    ellipse(r*0.12, -r*0.45, r*0.09, r*0.11);

    // 北极冰盖
    fill(240, 248, 255, 150);
    ellipse(0, 0, r*0.5, r*0.5);
  }

  // ========== 大气效果 ==========

  void drawAtmosphereEdge(float r) {
    int layers = 4;
    for (int i = layers; i > 0; i--) {
      float k = i / (float)layers;
      float ar = r * (1 + k * 0.13f);
      fill(100, 180, 255, (int)(35 * (1 - k) * (1 - k)));
      ellipse(0, 0, ar * 2, ar * 2);
    }
  }

  // ========== 获取性能数据 ==========

  long getLastDrawTime(int lod) {
    return drawTimes[lod];
  }
}

