// ========== 地球渲染器 ==========
// 使用 SVG 地球

class EarthRenderer {
  float rotation;
  float rotationSpeed;
  boolean rotationPaused;

  // SVG 形状
  PShape earthSVG;

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

    // 加载 SVG
    earthSVG = loadShape("earth.svg");

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

  // ========== LOD实现 - 使用 SVG ==========

  void drawLOD0(float r) {
    drawEarthSVG(r);
  }

  void drawLOD1(float r) {
    drawEarthSVG(r);
  }

  void drawLOD2(float r) {
    drawEarthSVG(r);
  }

  void drawLOD3(float r) {
    drawEarthSVG(r);
  }

  void drawLOD4(float r) {
    drawEarthSVG(r);
  }

  void drawLOD5(float r) {
    drawEarthSVG(r);
  }

  void drawEarthSVG(float r) {
    pushMatrix();
    rotate(rotation);

    // SVG 是 14x14 单位，缩放适配半径 r
    float scaleFactor = (r * 2) / 14.0;
    scale(scaleFactor);

    // SVG 中心在 (7,7)，平移到原点
    translate(-7, -7);

    shape(earthSVG);

    popMatrix();

    drawAtmosphereEdge(r);
  }

  // ========== 辅助绘制函数 ==========

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

