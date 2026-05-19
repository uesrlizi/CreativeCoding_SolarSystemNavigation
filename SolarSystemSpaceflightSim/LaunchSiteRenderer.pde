// ========== LAUNCH SITE RENDERER ==========
// 从旧项目移植的发射场渲染器

class LaunchSiteRenderer {

  void draw(LaunchSite site, CameraController cam, Spacecraft ship) {
    if (cam.getMode() != ViewMode.SHIP_VIEW) return;

    double[] sp = cam.worldToScreen(site.px, site.py);
    if (Double.isNaN(sp[0]) || Double.isNaN(sp[1])) return;

    float bl = (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale);
    float extent = bl * 3.0f;
    if (sp[0] + extent < -50 || sp[0] - extent > width + 50 ||
        sp[1] + extent < -50 || sp[1] - extent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);
    // 视图空间旋转：世界角度（baseAngle + PI/2）映射到屏幕角度0
    float siteRotation = (float)(site.baseAngle - cam.shipViewAngle);
    if (Float.isNaN(siteRotation) || Float.isInfinite(siteRotation)) siteRotation = 0;
    rotate(siteRotation);

    drawLaunchComplex(bl, ship);

    popMatrix();
  }

  // ========== 坐标系（旋转后） ==========
  // +X = 切线方向（沿地球表面，水平）
  // +Y = 指向地心（向下）
  // -Y = 径向向外（向上，飞船头部方向）
  // 原点 = 发射场世界坐标 = 地球表面
  // 建筑群升高到地面以上；飞船坐落在发射台上
  // groundY  = 0         — 地球表面
  // padSurfY = -bl*0.10  — 发射台表面（飞船引擎高度）

  // ========== 主建筑群 ==========

  void drawLaunchComplex(float bl, Spacecraft ship) {
    float bw = bl * 0.068f;         // 飞船半宽（第一级半径）
    float groundY = 0;              // 地球表面
    float padSurfY = -bl * 0.10f;   // 发射台表面，高于地面

    noStroke();

    drawTerrain(bl, groundY);
    drawAccessRoad(bl, groundY, padSurfY);
    drawFlameTrench(bl, padSurfY);
    drawConcretePad(bl, padSurfY, groundY);
    drawPadSurfaceDetails(bl, padSurfY);
    drawServiceTower(bl, bw, groundY);
    drawUmbilicalArms(bl, bw, groundY);
    drawHoldDownArms(bl, bw, padSurfY);
    drawLightningSystem(bl, groundY);
    drawSupportBuildings(bl, groundY, ship.col);
    drawExhaustDuct(bl, padSurfY);
  }

  // ========== 地形 ==========

  void drawTerrain(float bl, float groundY) {
    float groundW = bl * 2.2f;

    // 主地面填充 — 从刚好表面以上延伸到地下
    fill(42, 36, 27);
    beginShape();
    vertex(-groundW * 0.7f, groundY + bl * 0.30f);
    vertex(-groundW * 0.55f, groundY - bl * 0.02f);
    vertex(-groundW * 0.12f, groundY - bl * 0.04f);
    vertex( groundW * 0.12f, groundY - bl * 0.04f);
    vertex( groundW * 0.55f, groundY - bl * 0.02f);
    vertex( groundW * 0.7f, groundY + bl * 0.30f);
    endShape(CLOSE);

    // 地面层理/纹理
    fill(50, 42, 32);
    for (int i = 0; i < 8; i++) {
      float gx = -bl * 1.5f + i * bl * 0.38f;
      rect(gx, groundY + bl * 0.01f + i * bl * 0.01f, bl * 0.8f, bl * 0.013f, 2);
    }

    // 草地/灌木
    fill(55, 48, 28);
    for (int i = 0; i < 10; i++) {
      float gx = -bl * 1.5f + i * bl * 0.32f;
      float gy = groundY + bl * 0.05f + (i % 3) * bl * 0.02f;
      ellipse(gx, gy, bl * 0.18f, bl * 0.05f);
    }

    // 建筑物周围的暗色土壤
    fill(35, 28, 20);
    rect(-bl * 1.05f, groundY - bl * 0.03f, bl * 2.1f, bl * 0.03f, 3);

    // 砾石护堤
    fill(90, 82, 70);
    ellipse(0, groundY + bl * 0.12f, bl * 0.7f, bl * 0.06f);
  }

  // ========== 通道 ==========

  void drawAccessRoad(float bl, float groundY, float padSurfY) {
    float roadX = -bl * 1.3f;
    float roadW = bl * 0.15f;

    // 从地面开始的路面
    fill(95, 90, 82);
    beginShape();
    vertex(roadX - roadW * 0.3f, groundY + bl * 0.10f);
    vertex(roadX + roadW * 0.1f, groundY + bl * 0.02f);
    vertex(roadX + roadW * 0.3f, groundY - bl * 0.01f);
    vertex(roadX - roadW * 0.4f, groundY + bl * 0.07f);
    endShape(CLOSE);

    // 路肩
    fill(80, 75, 68);
    beginShape();
    vertex(roadX - roadW * 0.35f, groundY + bl * 0.09f);
    vertex(roadX - roadW * 0.25f, groundY + bl * 0.10f);
    vertex(roadX + roadW * 0.3f, groundY + bl * 0.01f);
    vertex(roadX + roadW * 0.15f, groundY - bl * 0.01f);
    endShape(CLOSE);

    // 中心虚线
    fill(130, 127, 118);
    for (int i = 0; i < 4; i++) {
      float rx = -bl * 1.2f + i * bl * 0.15f;
      float ry = groundY + bl * 0.03f + i * bl * 0.018f;
      rect(rx, ry, bl * 0.05f, bl * 0.005f, 1);
    }
  }

  // ========== 混凝土发射台 ==========

  void drawConcretePad(float bl, float padSurfY, float groundY) {
    float padHalfW = bl * 1.05f;
    float padThick = bl * 0.09f;       // 发射台坐落在地面，向上延伸
    float padBot = padSurfY + padThick; // padSurfY 是顶部，padBot 是地面

    // 主发射台块
    fill(148, 142, 132);
    rect(-padHalfW, padSurfY, padHalfW * 2, padThick);

    // 底部阴影
    fill(108, 102, 93);
    rect(-padHalfW, padBot - padThick * 0.22f, padHalfW * 2, padThick * 0.22f);

    // 顶部表面高光
    fill(178, 173, 163);
    rect(-padHalfW * 0.93f, padSurfY - padThick * 0.06f, padHalfW * 1.86f, padThick * 0.13f);

    // 左侧斜面
    fill(122, 116, 106);
    rect(-padHalfW, padSurfY, padThick * 0.4f, padThick);

    // 右侧斜面
    fill(118, 112, 102);
    rect(padHalfW - padThick * 0.4f, padSurfY, padThick * 0.4f, padThick);

    // 顶部表面砂砾纹理
    fill(155, 148, 138, 60);
    for (int i = 0; i < 12; i++) {
      float dx = -padHalfW * 0.8f + (i * 1.7f + (i * i) * 0.3f) % (padHalfW * 1.6f);
      float dy = padSurfY + (i * 0.7f + 3) % (padThick * 0.5f);
      ellipse(dx, dy, bl * 0.008f, bl * 0.004f);
    }

    // 下方支撑柱（延伸入地下）
    float pillarW = bl * 0.08f;
    float pillarH = bl * 0.06f;
    fill(112, 105, 95);
    for (int i = -3; i <= 3; i++) {
      if (i == 0) continue;
      float px = i * bl * 0.28f;
      rect(px - pillarW * 0.5f, padBot, pillarW, pillarH, 2);
    }
  }

  // ========== 发射台表面细节 ==========

  void drawPadSurfaceDetails(float bl, float padSurfY) {
    float padHalfW = bl * 1.05f;

    // 伸缩缝网格
    stroke(122, 116, 106, 100);
    strokeWeight(max(0.5f, bl * 0.004f));
    for (int i = -3; i <= 3; i++) {
      float lx = i * bl * 0.3f;
      if (Math.abs(lx) > padHalfW * 0.95f) continue;
      line(lx, padSurfY - bl * 0.003f, lx, padSurfY + bl * 0.03f);
    }
    for (int i = 0; i < 3; i++) {
      float ly = padSurfY + bl * 0.012f + i * bl * 0.02f;
      line(-padHalfW * 0.93f, ly, padHalfW * 0.93f, ly);
    }
    noStroke();

    // 中心对准标记
    fill(155, 50, 35, 160);
    rect(-bl * 0.03f, padSurfY - bl * 0.02f, bl * 0.06f, bl * 0.05f, 2);
    fill(200, 200, 190, 180);
    rect(-bl * 0.005f, padSurfY - bl * 0.015f, bl * 0.01f, bl * 0.04f, 1);
    rect(-bl * 0.025f, padSurfY + bl * 0.002f, bl * 0.05f, bl * 0.008f, 1);

    // 固定柱标记
    fill(100, 93, 83, 100);
    for (int sx = -1; sx <= 1; sx += 2) {
      for (int sy = -1; sy <= 1; sy += 2) {
        rect(sx * bl * 0.06f - bl * 0.015f, padSurfY - bl * 0.002f,
             bl * 0.03f, bl * 0.01f, 1);
      }
    }
  }

  // ========== 火焰沟槽 ==========

  void drawFlameTrench(float bl, float padSurfY) {
    float trenchHalfW = bl * 0.24f;
    float trenchDepth = bl * 0.19f;
    float trenchBot = padSurfY + trenchDepth;

    // 主沟槽空隙（从发射台表面开始，向下延伸入地）
    fill(22, 18, 15);
    rect(-trenchHalfW, padSurfY, trenchHalfW * 2, trenchDepth);

    // 更深的内部
    fill(15, 12, 10);
    rect(-trenchHalfW * 0.6f, padSurfY + trenchDepth * 0.08f, trenchHalfW * 1.2f, trenchDepth * 0.7f);

    // 火焰偏转器楔
    fill(42, 37, 32);
    beginShape();
    vertex(-trenchHalfW * 0.7f, trenchBot);
    vertex( trenchHalfW * 0.3f, padSurfY + trenchDepth * 0.2f);
    vertex( trenchHalfW * 0.6f, trenchBot);
    endShape(CLOSE);
    fill(55, 48, 42);
    beginShape();
    vertex(-trenchHalfW * 0.5f, trenchBot);
    vertex( trenchHalfW * 0.1f, padSurfY + trenchDepth * 0.3f);
    vertex( trenchHalfW * 0.4f, trenchBot);
    endShape(CLOSE);

    // 沟槽边缘混凝土压顶
    fill(158, 152, 142);
    rect(-trenchHalfW - bl * 0.018f, padSurfY - bl * 0.004f, bl * 0.036f, bl * 0.012f, 2);
    rect( trenchHalfW - bl * 0.018f, padSurfY - bl * 0.004f, bl * 0.036f, bl * 0.012f, 2);

    // 烧痕
    fill(50, 43, 36, 70);
    ellipse(-bl * 0.03f, padSurfY, bl * 0.55f, bl * 0.018f);
    ellipse( bl * 0.05f, padSurfY, bl * 0.40f, bl * 0.014f);
  }

  // ========== 排气管道 ==========

  void drawExhaustDuct(float bl, float padSurfY) {
    float ductTop = padSurfY + bl * 0.12f;
    float ductBot = padSurfY + bl * 0.24f;
    float ductHalfW = bl * 0.16f;

    fill(28, 24, 20);
    rect(-ductHalfW, ductTop, ductHalfW * 2, ductBot - ductTop);

    fill(18, 15, 12);
    beginShape();
    vertex( ductHalfW * 0.6f, ductTop + bl * 0.01f);
    vertex( ductHalfW * 1.1f, ductTop + bl * 0.04f);
    vertex( ductHalfW * 1.1f, ductBot - bl * 0.04f);
    vertex( ductHalfW * 0.6f, ductBot - bl * 0.01f);
    endShape(CLOSE);

    fill(140, 134, 124);
    rect(ductHalfW - bl * 0.01f, ductTop, bl * 0.018f, ductBot - ductTop);
  }

  // ========== 服务/脐带塔 ==========

  void drawServiceTower(float bl, float bw, float groundY) {
    float towerBaseY = groundY;              // 坐落在地面
    float towerTopY = groundY - bl * 1.15f;  // 足够高于整流罩
    float towerCX = bl * 0.13f;
    float towerHalfW = bl * 0.05f;
    float towerLeft = towerCX - towerHalfW;
    float towerRight = towerCX + towerHalfW;

    // --- 主柱 ---
    float colW = bl * 0.024f;
    fill(92, 87, 79);
    rect(towerLeft, towerTopY, colW, towerBaseY - towerTopY);
    rect(towerRight - colW, towerTopY, colW, towerBaseY - towerTopY);

    // 柱子高光
    fill(108, 103, 94);
    rect(towerLeft, towerTopY, colW * 0.35f, towerBaseY - towerTopY);
    rect(towerRight - colW * 0.35f, towerTopY, colW * 0.35f, towerBaseY - towerTopY);

    // --- X型支撑桁架 ---
    int bracePanels = 10;
    float panelH = (towerBaseY - towerTopY) / bracePanels;
    stroke(88, 83, 74);
    strokeWeight(max(0.5f, bl * 0.006f));
    for (int i = 0; i < bracePanels; i++) {
      float py = towerTopY + i * panelH;
      float npy = py + panelH;
      line(towerLeft + colW, py, towerRight - colW, npy);
      line(towerRight - colW, py, towerLeft + colW, npy);
      line(towerLeft + colW, py + panelH * 0.5f, towerRight - colW, py + panelH * 0.5f);
    }
    noStroke();

    // --- 电梯井 ---
    float shaftX = towerCX - bl * 0.009f;
    float shaftW = bl * 0.018f;
    fill(72, 67, 60);
    rect(shaftX, towerTopY + bl * 0.02f, shaftW, towerBaseY - towerTopY - bl * 0.02f);

    // --- 平台层 ---
    int numDecks = 6;
    for (int i = 0; i < numDecks; i++) {
      float dY = towerTopY + bl * 0.06f + i * bl * 0.18f;
      float dHalfW = bl * 0.14f - i * bl * 0.007f;
      fill(108, 103, 94);
      rect(towerLeft - dHalfW * 0.35f, dY, towerRight - towerLeft + dHalfW * 0.7f, bl * 0.015f, 2);
      fill(125, 120, 110);
      rect(towerLeft - dHalfW * 0.3f, dY - bl * 0.002f, towerRight - towerLeft + dHalfW * 0.6f, bl * 0.005f, 1);
      // 栏杆
      stroke(128, 123, 113);
      strokeWeight(max(0.3f, bl * 0.003f));
      float railY = dY - bl * 0.02f;
      line(towerLeft - dHalfW * 0.3f, railY, towerRight + dHalfW * 0.3f, railY);
      for (int r = -2; r <= 2; r++) {
        float rx = towerCX + r * dHalfW * 0.25f;
        line(rx, railY, rx, dY);
      }
      noStroke();
    }

    // --- 塔顶 ---
    fill(138, 133, 123);
    rect(towerCX - bl * 0.005f, towerTopY - bl * 0.05f, bl * 0.01f, bl * 0.05f);
    fill(185, 175, 55);
    ellipse(towerCX, towerTopY - bl * 0.05f, bl * 0.018f, bl * 0.018f);
    // 天线
    fill(100, 95, 85);
    rect(towerCX - bl * 0.025f, towerTopY - bl * 0.03f, bl * 0.05f, bl * 0.006f, 1);
    rect(towerCX + bl * 0.015f, towerTopY - bl * 0.035f, bl * 0.008f, bl * 0.02f, 1);

    // --- 塔基底座 ---
    fill(98, 91, 81);
    float footingW = bl * 0.045f;
    float footingH = bl * 0.03f;
    rect(towerLeft - bl * 0.006f, towerBaseY, footingW, footingH, 2);
    rect(towerRight - footingW + bl * 0.006f, towerBaseY, footingW, footingH, 2);
  }

  // ========== 脐带/摆动臂 ==========

  void drawUmbilicalArms(float bl, float bw, float groundY) {
    float towerCX = bl * 0.13f;
    float towerLeft = towerCX - bl * 0.05f;
    float towerTopY = groundY - bl * 1.15f;
    float shipCL = 0;

    int numArms = 4;
    float[] armHeights = {
      towerTopY + bl * 0.22f,   // 整流罩高度
      towerTopY + bl * 0.42f,   // 第二级
      towerTopY + bl * 0.62f,   // 级间段
      towerTopY + bl * 0.80f    // 第一级上部
    };

    for (int i = 0; i < numArms; i++) {
      float armY = armHeights[i];
      float armBaseX = towerLeft + bl * 0.005f;
      float armLen = Math.abs(shipCL - armBaseX);
      float armThick = bl * 0.015f - i * bl * 0.002f;

      fill(82, 76, 68);
      rect(armBaseX, armY, -armLen, armThick, 2);
      fill(98, 92, 82);
      rect(armBaseX - armLen * 0.08f, armY - armThick * 0.15f, -armLen * 0.84f, armThick * 0.35f, 1);

      // 铰链块
      fill(66, 60, 54);
      float hingeW = bl * 0.02f;
      rect(armBaseX - hingeW * 0.5f, armY - armThick * 0.2f, hingeW, armThick * 1.4f, 2);

      // 脐带连接器
      float tipX = armBaseX - armLen;
      fill(72, 65, 57);
      rect(tipX - bl * 0.007f, armY - armThick * 0.35f, bl * 0.01f, armThick * 1.7f, 2);

      // 服务管道
      stroke(108, 98, 78, 170);
      strokeWeight(max(0.4f, bl * 0.005f));
      line(armBaseX - bl * 0.01f, armY + armThick * 0.35f, tipX + bl * 0.007f, armY + armThick * 0.35f);
      noStroke();
    }

    // 尾部服务杆（第一级底部加油，靠近地面）
    float tsmX = bl * 0.06f;
    float tsmBaseY = groundY;
    float tsmTopY = groundY - bl * 0.22f;
    fill(88, 81, 72);
    rect(tsmX - bl * 0.01f, tsmTopY, bl * 0.022f, tsmBaseY - tsmTopY);

    // 柔性低温软管
    stroke(100, 90, 70, 170);
    strokeWeight(max(0.5f, bl * 0.007f));
    noFill();
    float hoseStartX = tsmX + bl * 0.006f;
    float hoseStartY = tsmTopY + bl * 0.01f;
    float hoseEndY = groundY - bl * 0.06f;
    bezier(hoseStartX, hoseStartY,
           tsmX - bl * 0.04f, hoseStartY - bl * 0.05f,
           -bw * 0.5f, hoseEndY,
           -bw * 0.3f, hoseEndY);
    noStroke();
  }

  // ========== 固定臂（在发射台表面） ==========

  void drawHoldDownArms(float bl, float bw, float padSurfY) {
    int armCount = 4;
    for (int i = 0; i < armCount; i++) {
      float side = (i < 2) ? -1 : 1;
      float hx = side * bw * 1.5f * (1 + (i % 2) * 0.25f);

      // 发射台上的基座
      fill(98, 91, 81);
      rect(hx - bl * 0.018f, padSurfY - bl * 0.01f, bl * 0.036f, bl * 0.03f, 2);

      // 垂直臂
      fill(82, 76, 66);
      rect(hx - bl * 0.009f, padSurfY - bl * 0.04f, bl * 0.018f, bl * 0.05f, 1);

      // 夹具
      fill(112, 102, 90);
      rect(hx - bl * 0.013f, padSurfY - bl * 0.045f, bl * 0.026f, bl * 0.012f, 1);
      fill(140, 128, 110);
      ellipse(hx, padSurfY - bl * 0.04f, bl * 0.01f, bl * 0.008f);
    }
  }

  // ========== 防雷系统 ==========

  void drawLightningSystem(float bl, float groundY) {
    float padHalfW = bl * 1.05f;
    float mastBaseY = groundY;           // 桅杆扎根于地面
    float mastTopY = groundY - bl * 1.30f; // 高于飞船头部（在-bl*1.11）

    float[][] mastXPos = {
      { -padHalfW * 0.82f },
      {  padHalfW * 0.82f }
    };

    for (float[] mxArr : mastXPos) {
      float mx = mxArr[0];
      float baseW = bl * 0.020f;
      float topW = bl * 0.008f;

      fill(118, 113, 103);
      beginShape();
      vertex(mx - baseW * 0.5f, mastBaseY);
      vertex(mx + baseW * 0.5f, mastBaseY);
      vertex(mx + topW * 0.5f, mastTopY);
      vertex(mx - topW * 0.5f, mastTopY);
      endShape(CLOSE);

      fill(135, 130, 120);
      beginShape();
      vertex(mx - baseW * 0.15f, mastBaseY);
      vertex(mx + baseW * 0.15f, mastBaseY);
      vertex(mx + topW * 0.15f, mastTopY);
      vertex(mx - topW * 0.15f, mastTopY);
      endShape(CLOSE);

      fill(98, 91, 81);
      rect(mx - bl * 0.025f, mastBaseY - bl * 0.003f, bl * 0.05f, bl * 0.028f, 2);

      // 绝缘环
      fill(180, 170, 100);
      for (int r = 0; r < 4; r++) {
        float ry = lerp(mastBaseY, mastTopY, 0.1f + r * 0.25f);
        float rw = baseW * (1.2f - r * 0.2f);
        ellipse(mx, ry, rw * 2.8f, rw * 1.2f);
      }

      fill(185, 175, 55);
      ellipse(mx, mastTopY, bl * 0.016f, bl * 0.016f);
    }

    // 悬链线
    stroke(78, 73, 63);
    strokeWeight(max(0.3f, bl * 0.004f));
    float m1x = mastXPos[0][0];
    float m2x = mastXPos[1][0];
    float sag = bl * 0.08f;
    noFill();
    bezier(m1x + bl * 0.006f, mastTopY,
           m1x + bl * 0.4f, mastTopY + sag,
           m2x - bl * 0.4f, mastTopY + sag,
           m2x - bl * 0.006f, mastTopY);
    noStroke();

    // 接地电缆
    stroke(68, 63, 53);
    strokeWeight(max(0.3f, bl * 0.003f));
    for (float[] mxArr : mastXPos) {
      float mx = mxArr[0];
      float gEndY = groundY + bl * 0.14f;
      line(mx + bl * 0.012f, mastBaseY, mx + bl * 0.07f, gEndY);
      fill(100, 93, 83);
      ellipse(mx + bl * 0.07f, gEndY, bl * 0.018f, bl * 0.012f);
    }
    noStroke();
  }

  // ========== 辅助建筑 ==========

  void drawSupportBuildings(float bl, float groundY, int shipCol) {
    float padHalfW = bl * 1.05f;

    // --- 掩体（左侧）---
    float bhCX = -padHalfW - bl * 0.22f;
    float bhW = bl * 0.26f;
    float bhH = bl * 0.14f;
    float bhBaseY = groundY;

    fill(128, 123, 113);
    rect(bhCX - bhW * 0.5f, bhBaseY - bhH, bhW, bhH, 3);
    fill(118, 113, 103);
    beginShape();
    vertex(bhCX - bhW * 0.55f, bhBaseY - bhH);
    vertex(bhCX + bhW * 0.55f, bhBaseY - bhH);
    vertex(bhCX + bhW * 0.45f, bhBaseY - bhH - bl * 0.018f);
    vertex(bhCX - bhW * 0.45f, bhBaseY - bhH - bl * 0.018f);
    endShape(CLOSE);
    fill(22, 18, 15);
    rect(bhCX - bl * 0.025f, bhBaseY - bhH + bl * 0.03f, bl * 0.05f, bl * 0.012f, 1);
    fill(58, 52, 45);
    rect(bhCX - bl * 0.018f, bhBaseY - bl * 0.03f, bl * 0.036f, bl * 0.05f, 1);

    // --- 设备楼（右侧）---
    float ebCX = padHalfW + bl * 0.12f;
    float ebW = bl * 0.20f;
    float ebH = bl * 0.10f;
    float ebBaseY = groundY;

    fill(138, 133, 123);
    rect(ebCX - ebW * 0.5f, ebBaseY - ebH, ebW, ebH, 2);
    fill(128, 123, 113);
    rect(ebCX - ebW * 0.53f, ebBaseY - ebH - bl * 0.007f, ebW * 1.06f, bl * 0.015f, 1);
    fill(98, 91, 81);
    rect(ebCX + bl * 0.03f, ebBaseY - ebH - bl * 0.026f, bl * 0.014f, bl * 0.022f);
    fill(62, 56, 48);
    rect(ebCX - bl * 0.012f, ebBaseY - bl * 0.022f, bl * 0.026f, bl * 0.036f, 1);
    fill(60, 80, 110, 150);
    rect(ebCX - bl * 0.04f, ebBaseY - ebH + bl * 0.025f, bl * 0.025f, bl * 0.022f, 1);

    // --- 燃料储罐（右侧）---
    float tkCX = padHalfW + bl * 0.42f;
    float tkR = bl * 0.055f;
    float tkCY = groundY - bl * 0.10f;
    fill(148, 143, 133);
    ellipse(tkCX, tkCY, tkR * 2, tkR * 2);
    fill(168, 163, 153, 120);
    ellipse(tkCX - tkR * 0.2f, tkCY - tkR * 0.2f, tkR * 0.8f, tkR * 0.7f);
    fill(100, 93, 83);
    rect(tkCX - tkR * 0.85f, tkCY + tkR * 0.4f, tkR * 0.25f, groundY - tkCY - tkR * 0.4f);
    rect(tkCX + tkR * 0.6f, tkCY + tkR * 0.4f, tkR * 0.25f, groundY - tkCY - tkR * 0.4f);
    fill(88, 81, 72);
    rect(tkCX - bl * 0.004f, tkCY + tkR + bl * 0.01f, bl * 0.008f, groundY - tkCY - tkR);
    fill((shipCol >> 16) & 0xFF, (shipCol >> 8) & 0xFF, shipCol & 0xFF, 130);
    ellipse(tkCX, tkCY, tkR * 1.6f, tkR * 0.4f);

    // --- 水塔（左侧）---
    float wtCX = -padHalfW - bl * 0.50f;
    float wtTankW = bl * 0.08f;
    float wtTankH = bl * 0.06f;
    float wtLegH = bl * 0.32f;
    float wtTankCY = groundY - wtLegH - wtTankH * 0.5f;

    fill(103, 96, 86);
    float legSpread = bl * 0.05f;
    rect(wtCX - legSpread, groundY - wtLegH, bl * 0.015f, wtLegH);
    rect(wtCX + legSpread, groundY - wtLegH, bl * 0.015f, wtLegH);
    stroke(98, 91, 81);
    strokeWeight(max(0.3f, bl * 0.003f));
    line(wtCX - legSpread + bl * 0.007f, groundY - wtLegH * 0.35f,
         wtCX + legSpread - bl * 0.007f, groundY - wtLegH * 0.65f);
    line(wtCX - legSpread + bl * 0.007f, groundY - wtLegH * 0.65f,
         wtCX + legSpread - bl * 0.007f, groundY - wtLegH * 0.35f);
    noStroke();

    fill(155, 150, 142);
    rect(wtCX - wtTankW * 0.5f, wtTankCY - wtTankH * 0.5f, wtTankW, wtTankH, 2);
    fill(145, 140, 132);
    arc(wtCX, wtTankCY - wtTankH * 0.5f, wtTankW, wtTankH * 0.5f, 0, PI, PIE);
    fill(100, 140, 180, 100);
    rect(wtCX - wtTankW * 0.4f, wtTankCY - wtTankH * 0.1f, wtTankW * 0.8f, wtTankH * 0.5f, 1);
    fill(88, 81, 72);
    rect(wtCX - bl * 0.004f, wtTankCY + wtTankH * 0.5f, bl * 0.008f, groundY - wtTankCY - wtTankH * 0.5f);
    fill(120, 110, 90);
    rect(wtCX - bl * 0.008f, groundY - bl * 0.06f, bl * 0.016f, bl * 0.02f, 1);
  }
}
