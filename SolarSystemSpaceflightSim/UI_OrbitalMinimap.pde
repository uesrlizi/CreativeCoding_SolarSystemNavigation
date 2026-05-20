// ========== ORBITAL MINIMAP ==========

class OrbitalMinimap {
  float centerX, centerY;
  float size;  // 方形边长的一半
  float margin;

  OrbitalMinimap() {
    float scale = uiScale;
    size = 85 * scale;
    margin = 10 * scale;
    updatePosition();
  }

  void update() {
    float scale = uiScale;
    size = 85 * scale;
    margin = 10 * scale;
    updatePosition();
  }

  void updatePosition() {
    // 小地图放在右下角
    centerX = width - size - margin;
    centerY = height - size - margin;
  }

  void draw(Spacecraft craft, List<CelestialBody> planets, List<CelestialBody> moons, CelestialBody sun) {
    if (craft == null) return;

    pushStyle();
    float scale = uiScale;

    // 绘制背景方形
    noStroke();
    fill(20, 20, 40, 200);
    rectMode(CENTER);
    rect(centerX, centerY, size * 2, size * 2);

    // 如果没有轨道或参考天体，只画背景和边框
    if (craft.orbit == null || craft.referenceBody == null) {
      // 绘制边框
      noFill();
      stroke(150, 150, 180, 200);
      strokeWeight(2 * scale);
      rect(centerX, centerY, size * 2, size * 2);
      popStyle();
      return;
    }

    Orbit orbit = craft.orbit;
    CelestialBody referenceBody = craft.referenceBody;

    // 计算缩放比例：轨道长轴占0.8的地图宽度
    double semiMajorAxis = orbit.a;
    float mapScale = (size * 0.8f) / (float)semiMajorAxis;

    // 计算椭圆的几何中心（相对于参考天体的偏移）
    // 椭圆中心距离焦点（天体位置）的距离是 a*e
    double ellipseCenterOffset = orbit.a * orbit.e;
    double ellipseCenterX = referenceBody.px - ellipseCenterOffset * Math.cos(orbit.w);
    double ellipseCenterY = referenceBody.py - ellipseCenterOffset * Math.sin(orbit.w);
    Vector2 orbitCenter = new Vector2(ellipseCenterX, ellipseCenterY);

    // 应用矩形剪裁
    float clipLeft = centerX - size;
    float clipTop = centerY - size;
    clip(clipLeft, clipTop, size * 2, size * 2);

    // 1. 绘制轨道椭圆
    drawOrbitEllipse(orbit, orbitCenter, mapScale, craft.col);

    // 2. 绘制范围内所有天体
    drawBodiesOnMinimap(planets, moons, sun, orbitCenter, mapScale);

    // 3. 绘制飞船
    drawShipOnMinimap(craft, orbitCenter, mapScale);

    // 取消剪裁
    noClip();

    // 绘制边框（在剪裁之上）
    noFill();
    stroke(150, 150, 180, 200);
    strokeWeight(2 * scale);
    rect(centerX, centerY, size * 2, size * 2);

    popStyle();
  }

  void drawOrbitEllipse(Orbit orbit, Vector2 orbitCenter, float mapScale, color c) {
    float scale = uiScale;

    noFill();
    stroke(red(c), green(c), blue(c), 150);
    strokeWeight(1.5f * scale);

    beginShape();
    int steps = 100;
    for (int i = 0; i <= steps; i++) {
      double nu = 2.0 * PI * i / steps;
      double[] pos = orbitalToCartesian2D(orbit.a, orbit.e, orbit.w, nu);

      // 轨道坐标是相对于参考天体的，需要加上参考天体位置再减去椭圆中心
      double worldX = pos[0] + orbit.referenceBody.px - orbitCenter.x;
      double worldY = pos[1] + orbit.referenceBody.py - orbitCenter.y;

      // 转换到小地图坐标
      float x = centerX + (float)worldX * mapScale;
      float y = centerY + (float)worldY * mapScale;

      vertex(x, y);
    }
    endShape(CLOSE);
  }

  void drawBodiesOnMinimap(List<CelestialBody> planets, List<CelestialBody> moons, CelestialBody sun, Vector2 orbitCenter, float mapScale) {
    float scale = uiScale;

    // 先绘制太阳
    drawSingleBody(sun, orbitCenter, mapScale);

    // 绘制行星
    if (planets != null) {
      for (CelestialBody planet : planets) {
        drawSingleBody(planet, orbitCenter, mapScale);
      }
    }

    // 绘制卫星
    if (moons != null) {
      for (CelestialBody moon : moons) {
        drawSingleBody(moon, orbitCenter, mapScale);
      }
    }
  }

  void drawSingleBody(CelestialBody body, Vector2 orbitCenter, float mapScale) {
    if (body == null) return;

    float scale = uiScale;

    // 计算天体相对于轨道中心的位置
    double relX = body.px - orbitCenter.x;
    double relY = body.py - orbitCenter.y;

    // 转换到小地图坐标
    float x = centerX + (float)relX * mapScale;
    float y = centerY + (float)relY * mapScale;

    // 计算天体在小地图上的半径 - 实际比例，但有最小可见尺寸
    float bodyRadius = max(2 * scale, (float)body.radius * mapScale);

    // 数学预检查：如果距离中心超过 size + bodyRadius，就不绘制了
    float dx = abs(x - centerX);
    float dy = abs(y - centerY);
    if (dx > size + bodyRadius || dy > size + bodyRadius) return;

    noStroke();
    fill(body.col);
    ellipse(x, y, bodyRadius * 2, bodyRadius * 2);
  }

  void drawShipOnMinimap(Spacecraft craft, Vector2 orbitCenter, float mapScale) {
    float scale = uiScale;

    // 计算飞船相对于轨道中心的位置
    double relX = craft.worldX - orbitCenter.x;
    double relY = craft.worldY - orbitCenter.y;

    // 转换到小地图坐标
    float x = centerX + (float)relX * mapScale;
    float y = centerY + (float)relY * mapScale;

    // 绘制飞船图标
    pushMatrix();
    translate(x, y);
    rotate((float)craft.attitude.angle);

    float iconSize = 8 * scale;

    noStroke();
    fill(red(craft.col), green(craft.col), blue(craft.col), 200);

    // V形箭头
    beginShape();
    vertex(iconSize * 0.8f, 0);
    vertex(-iconSize * 0.8f, -iconSize * 0.9f);
    vertex(-iconSize * 0.5f, 0);
    vertex(-iconSize * 0.8f, iconSize * 0.9f);
    endShape(CLOSE);

    // 中心点
    fill(255, 255, 255, 140);
    ellipse(0, 0, iconSize * 0.35f, iconSize * 0.35f);

    popMatrix();
  }
}
