// ========== LAUNCH SITE RENDERER（全新设计 - 扩展版） ==========
// 极简工业风格 - 清晰层次，功能优先 - 扩展建筑与地面

class LaunchSiteRenderer {

  void draw(LaunchSite site, CameraController cam, Spacecraft ship) {
    draw(site, cam, ship, 0.0f);
  }

  void draw(LaunchSite site, CameraController cam, Spacecraft ship, float umbilicalDeployProgress) {
    if (cam.getMode() != ViewMode.SHIP_VIEW) return;

    double[] sp = cam.worldToScreen(site.px, site.py);
    if (Double.isNaN(sp[0]) || Double.isNaN(sp[1])) return;

    float bl = (float)(Spacecraft.SHIP_LENGTH_KM * cam.scale);
    float extent = bl * 5.0f;  // 扩大可视范围
    if (sp[0] + extent < -50 || sp[0] - extent > width + 50 ||
        sp[1] + extent < -50 || sp[1] - extent > height + 50) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);
    float siteRotation = (float)(site.baseAngle - cam.shipViewAngle);
    if (Float.isNaN(siteRotation) || Float.isInfinite(siteRotation)) siteRotation = 0;
    rotate(siteRotation);

    drawLaunchSite(bl, ship, umbilicalDeployProgress);

    popMatrix();
  }

  // ========== 全新发射场设计 ==========

  void drawLaunchSite(float bl, Spacecraft ship) {
    drawLaunchSite(bl, ship, 0.0f);
  }

  void drawLaunchSite(float bl, Spacecraft ship, float umbilicalDeployProgress) {
    float bw = bl * 0.068f;    // 飞船半宽
    float groundY = 0;         // 地面线
    float padY = -bl * 0.10f;  // 发射台高度（保持不变）

    noStroke();

    // 绘制层次：从下往上
    drawPerimeterFence(bl, groundY);
    drawGround(bl, groundY);
    drawDistantStructures(bl, groundY);
    drawRemoteStructures(bl, groundY);
    drawExhaustSystem(bl, padY, groundY);
    drawLaunchPad(bl, padY, groundY);
    drawHoldDowns(bl, bw, padY, umbilicalDeployProgress);
    drawServiceStructure(bl, bw, groundY);
    drawUmbilicalConnections(bl, bw, groundY, umbilicalDeployProgress);
    drawLightningMasts(bl, groundY);
    drawNearbyFacilities(bl, groundY);
  }

  // ========== 0. 外围围栏 ==========

  void drawPerimeterFence(float bl, float groundY) {
    // 围栏柱
    fill(55, 50, 45);
    for (int i = -8; i <= 8; i++) {
      float fx = i * bl * 0.5f;
      rect(fx - bl * 0.008f, groundY - bl * 0.06f, bl * 0.016f, bl * 0.06f);
    }

    // 围栏线
    stroke(65, 60, 55, 100);
    strokeWeight(max(0.3f, bl * 0.002f));
    line(-bl * 4.0f, groundY - bl * 0.045f, bl * 4.0f, groundY - bl * 0.045f);
    line(-bl * 4.0f, groundY - bl * 0.03f, bl * 4.0f, groundY - bl * 0.03f);
    noStroke();
  }

  // ========== 1. 地面（扩大版） ==========

  void drawGround(float bl, float groundY) {
    // 主地面 - 扩展到 8倍飞船长度
    fill(38, 35, 30);
    rect(-bl * 4.0f, groundY, bl * 8.0f, bl * 0.5f);

    // 发射场核心区域 - 压实地面
    fill(50, 45, 40);
    rect(-bl * 2.5f, groundY - bl * 0.025f, bl * 5.0f, bl * 0.025f);

    // 中心区域标记
    fill(58, 53, 48);
    rect(-bl * 1.5f, groundY - bl * 0.04f, bl * 3.0f, bl * 0.02f);

    // 简单的路面纹理
    stroke(45, 42, 36, 60);
    strokeWeight(max(0.5f, bl * 0.004f));
    for (int i = 0; i < 20; i++) {
      float lx = -bl * 2.2f + i * bl * 0.24f;
      line(lx, groundY + bl * 0.06f, lx - bl * 0.12f, groundY + bl * 0.18f);
    }
    noStroke();

    // 地面标识 - 安全距离标记
    fill(80, 75, 68, 50);
    ellipse(0, groundY + bl * 0.1f, bl * 2.0f, bl * 0.04f);
  }

  // ========== 2. 远端建筑群 ==========

  void drawDistantStructures(float bl, float groundY) {
    // =============== 左侧远端 ===============

    // 大型燃料储存区
    float tankAreaX = -bl * 2.8f;
    fill(70, 66, 60);
    rect(tankAreaX - bl * 0.15f, groundY - bl * 0.12f, bl * 0.3f, bl * 0.12f, 2);
    // 三个燃料罐
    for (int i = 0; i < 3; i++) {
      float tx = tankAreaX - bl * 0.08f + i * bl * 0.08f;
      fill(85, 80, 74);
      ellipse(tx, groundY - bl * 0.08f, bl * 0.06f, bl * 0.06f);
      fill(100, 95, 89, 80);
      ellipse(tx - bl * 0.008f, groundY - bl * 0.088f, bl * 0.035f, bl * 0.03f);
    }

    // 管制塔
    float ctrlTowerX = -bl * 2.2f;
    fill(60, 56, 50);
    rect(ctrlTowerX - bl * 0.035f, groundY - bl * 0.22f, bl * 0.07f, bl * 0.22f);
    fill(75, 71, 65);
    rect(ctrlTowerX - bl * 0.05f, groundY - bl * 0.3f, bl * 0.1f, bl * 0.08f, 2);
    // 塔台窗户
    fill(180, 200, 220, 100);
    for (int i = 0; i < 3; i++) {
      rect(ctrlTowerX - bl * 0.035f + i * bl * 0.025f, groundY - bl * 0.28f, bl * 0.018f, bl * 0.025f);
    }

    // =============== 右侧远端 ===============

    // 发射控制中心
    float lccX = bl * 2.0f;
    fill(55, 51, 45);
    rect(lccX - bl * 0.18f, groundY - bl * 0.16f, bl * 0.36f, bl * 0.16f, 3);
    fill(65, 61, 55);
    rect(lccX - bl * 0.16f, groundY - bl * 0.18f, bl * 0.32f, bl * 0.05f, 2);
    // LCC窗户
    fill(150, 180, 200, 80);
    for (int i = 0; i < 6; i++) {
      rect(lccX - bl * 0.13f + i * bl * 0.042f, groundY - bl * 0.12f, bl * 0.028f, bl * 0.035f);
    }

    // 备用电源站
    float powerX = bl * 2.7f;
    fill(65, 61, 55);
    rect(powerX - bl * 0.08f, groundY - bl * 0.1f, bl * 0.16f, bl * 0.1f, 2);
    fill(80, 75, 68);
    rect(powerX - bl * 0.03f, groundY - bl * 0.14f, bl * 0.06f, bl * 0.05f, 1);

    // =============== 警示灯 ==========
    fill(200, 40, 40, 180);
    ellipse(-bl * 2.5f, groundY - bl * 0.14f, bl * 0.015f, bl * 0.015f);
    ellipse(bl * 2.3f, groundY - bl * 0.2f, bl * 0.015f, bl * 0.015f);
  }

  // ========== 3. 中距离建筑 ==========

  void drawRemoteStructures(float bl, float groundY) {
    // 左侧 - 燃料加注站
    fill(72, 68, 62);
    rect(-bl * 1.15f, groundY - bl * 0.15f, bl * 0.15f, bl * 0.15f, 3);
    fill(82, 78, 72);
    rect(-bl * 0.98f, groundY - bl * 0.12f, bl * 0.12f, bl * 0.12f, 3);
    // 连接管道
    stroke(60, 55, 48, 100);
    strokeWeight(max(0.4f, bl * 0.004f));
    line(-bl * 1.05f, groundY - bl * 0.08f, -bl * 0.5f, groundY - bl * 0.08f);
    noStroke();

    // 右侧 - 设备楼
    fill(68, 64, 58);
    rect(bl * 0.85f, groundY - bl * 0.18f, bl * 0.18f, bl * 0.18f, 2);
    fill(88, 84, 78);
    rect(bl * 0.86f, groundY - bl * 0.17f, bl * 0.08f, bl * 0.08f, 1);

    // 右侧 - 液氧罐
    float loxX = bl * 1.25f;
    fill(100, 140, 180, 100);
    ellipse(loxX, groundY - bl * 0.07f, bl * 0.08f, bl * 0.08f);
    fill(120, 160, 200, 80);
    ellipse(loxX - bl * 0.01f, groundY - bl * 0.08f, bl * 0.05f, bl * 0.045f);

    // 小警示灯
    fill(200, 40, 40, 150);
    ellipse(-bl * 1.08f, groundY - bl * 0.16f, bl * 0.012f, bl * 0.012f);
    ellipse(bl * 0.94f, groundY - bl * 0.19f, bl * 0.012f, bl * 0.012f);
  }

  // ========== 4. 排气系统 ==========

  void drawExhaustSystem(float bl, float padY, float groundY) {
    // 火焰导流槽
    fill(20, 18, 16);
    rect(-bl * 0.25f, padY, bl * 0.5f, bl * 0.22f);

    // 导流槽内衬
    fill(35, 30, 25);
    rect(-bl * 0.2f, padY + bl * 0.02f, bl * 0.4f, bl * 0.18f);

    // 右排气道（更大）
    fill(22, 20, 18);
    rect(bl * 0.15f, padY + bl * 0.12f, bl * 0.5f, bl * 0.18f);
    fill(85, 80, 75);
    rect(bl * 0.15f, padY + bl * 0.12f, bl * 0.02f, bl * 0.18f);

    // 左排气道
    fill(22, 20, 18);
    rect(-bl * 0.65f, padY + bl * 0.12f, bl * 0.4f, bl * 0.15f);
  }

  // ========== 5. 发射台 ==========

  void drawLaunchPad(float bl, float padY, float groundY) {
    // 主混凝土平台
    fill(120, 115, 108);
    rect(-bl * 0.75f, padY, bl * 1.5f, bl * 0.1f);

    // 平台边缘斜面
    fill(95, 90, 83);
    rect(-bl * 0.75f, padY, bl * 0.06f, bl * 0.1f);
    rect(bl * 0.69f, padY, bl * 0.06f, bl * 0.1f);

    // 平台表面高光
    fill(140, 135, 128);
    rect(-bl * 0.7f, padY - bl * 0.01f, bl * 1.4f, bl * 0.02f);

    // 平台防滑纹理
    stroke(100, 95, 88, 60);
    strokeWeight(max(0.3f, bl * 0.002f));
    for (int i = 0; i < 14; i++) {
      float lx = -bl * 0.68f + i * bl * 0.105f;
      line(lx, padY + bl * 0.02f, lx, padY + bl * 0.08f);
    }
    noStroke();

    // 中心标记
    fill(180, 50, 40, 120);
    ellipse(0, padY + bl * 0.05f, bl * 0.05f, bl * 0.05f);
    fill(220, 210, 200, 150);
    ellipse(0, padY + bl * 0.05f, bl * 0.015f, bl * 0.015f);

    // 平台周边行走道
    fill(110, 105, 98);
    rect(-bl * 0.82f, padY - bl * 0.015f, bl * 0.07f, bl * 0.015f);
    rect(bl * 0.75f, padY - bl * 0.015f, bl * 0.07f, bl * 0.015f);
  }

  // ========== 6. 固定臂 ==========

  void drawHoldDowns(float bl, float bw, float padY) {
    drawHoldDowns(bl, bw, padY, 0.0f);
  }

  void drawHoldDowns(float bl, float bw, float padY, float umbilicalDeployProgress) {
    // 四个固定臂 - 在脐带臂展开时一起松开
    float releaseProgress = (float)constrainDouble((umbilicalDeployProgress - 0.5f) * 2.0f, 0.0f, 1.0f);

    for (int i = 0; i < 4; i++) {
      float side = (i < 2) ? -1 : 1;
      float offset = (i % 2 == 0) ? 0.8f : 1.2f;
      float hx = side * bw * offset;

      // 基座
      fill(80, 75, 68);
      rect(hx - bl * 0.02f, padY - bl * 0.015f, bl * 0.04f, bl * 0.035f, 2);

      // 支柱 - 松开时向外略微移动
      float releaseOffset = releaseProgress * bl * 0.008f * side;
      fill(65, 60, 53);
      rect(hx - bl * 0.01f + releaseOffset, padY - bl * 0.05f, bl * 0.02f, bl * 0.04f);

      // 夹头 - 松开时向外打开
      if (releaseProgress < 1.0f) {
        float jawOpen = releaseProgress * bl * 0.01f * side;
        fill(95, 88, 78);
        rect(hx - bl * 0.018f + jawOpen, padY - bl * 0.058f, bl * 0.036f, bl * 0.015f, 1);
      }
    }
  }

  // ========== 7. 服务塔架 ==========

  void drawServiceStructure(float bl, float bw, float groundY) {
    float towerX = bl * 0.38f;  // 离飞船足够远
    float towerH = bl * 1.18f;
    float towerW = bl * 0.13f;

    // 主塔架
    fill(68, 64, 58);
    rect(towerX - towerW * 0.5f, groundY - towerH, towerW, towerH);

    // 塔架高光边
    fill(82, 78, 72);
    rect(towerX - towerW * 0.5f, groundY - towerH, towerW * 0.25f, towerH);

    // 多层平台（向外延伸更多）
    for (int i = 0; i < 7; i++) {
      float py = groundY - bl * 0.13f - i * bl * 0.155f;
      float extend = bl * 0.18f + (i < 5 ? bl * 0.025f * i : 0);

      fill(78, 74, 68);
      rect(towerX - towerW * 0.5f - extend, py, towerW + extend, bl * 0.022f, 2);

      fill(92, 88, 82);
      rect(towerX - towerW * 0.5f - extend + bl * 0.008f, py - bl * 0.005f, towerW + extend - bl * 0.016f, bl * 0.008f);

      // 平台栏杆柱
      fill(100, 96, 90);
      for (int j = 0; j < 4; j++) {
        float rx = towerX - towerW * 0.5f - extend + bl * 0.02f + j * (towerW + extend - bl * 0.04f) / 3;
        rect(rx - bl * 0.003f, py - bl * 0.025f, bl * 0.006f, bl * 0.022f);
      }
    }

    // 塔顶信号灯
    fill(170, 50, 50, 200);
    ellipse(towerX, groundY - towerH - bl * 0.03f, bl * 0.018f, bl * 0.018f);

    // 塔基加宽
    fill(58, 54, 48);
    rect(towerX - bl * 0.1f, groundY - bl * 0.015f, bl * 0.2f, bl * 0.02f, 2);
  }

  // ========== 8. 脐带连接臂 ==========

  void drawUmbilicalConnections(float bl, float bw, float groundY) {
    drawUmbilicalConnections(bl, bw, groundY, 0.0f);
  }

  void drawUmbilicalConnections(float bl, float bw, float groundY, float umbilicalDeployProgress) {
    float towerX = bl * 0.38f;
    float towerLeft = towerX - bl * 0.065f;
    float shipSide = -bw;  // 飞船左边缘

    // 三个连接臂 - 不同的展开时序
    float[] armYs = {
      groundY - bl * 0.98f,  // 第二级
      groundY - bl * 0.75f,  // 第一级上部
      groundY - bl * 0.48f   // 第一级中部
    };

    // 每个臂的展开时间窗口 (从早到晚)
    float[] armStartProgress = {0.0f, 0.15f, 0.3f};
    float[] armEndProgress = {0.5f, 0.65f, 0.8f};

    for (int i = 0; i < 3; i++) {
      float ay = armYs[i];
      float armLen = towerLeft - shipSide;
      float thick = bl * 0.017f - i * bl * 0.002f;

      // 计算当前臂的展开进度
      float armProgress = (float)constrainDouble(
        (umbilicalDeployProgress - armStartProgress[i]) /
        (armEndProgress[i] - armStartProgress[i]),
        0.0f, 1.0f
      );

      // 展开角度：从水平(0)到向上约120度
      float deployAngle = armProgress * radians(120.0f);

      pushMatrix();
      translate(towerLeft, ay + thick * 0.5f);
      rotate(-deployAngle);  // 向上旋转

      // 主臂 - 长度逐渐缩短
      float currentArmLen = armLen * (1.0f - armProgress * 0.3f);
      fill(70, 65, 58);
      rect(0, -thick * 0.5f, -currentArmLen, thick, 2);

      // 臂上表面
      fill(88, 82, 75);
      rect(-bl * 0.012f, -thick * 0.72f, -currentArmLen + bl * 0.024f, thick * 0.38f);

      // 塔侧铰链
      fill(55, 50, 44);
      rect(-bl * 0.016f, -thick * 0.78f, bl * 0.032f, thick * 1.56f, 2);

      // 飞船侧连接器 - 只在未完全展开时显示
      if (armProgress < 0.95f) {
        float connectorX = -currentArmLen;
        fill(62, 56, 48);
        rect(connectorX - bl * 0.009f, -thick * 0.92f, bl * 0.018f, thick * 1.84f, 2);
      }

      // 管线 - 逐渐松弛并断开
      if (armProgress < 1.0f) {
        float hoseEndX = -armLen * (1.0f - armProgress * 0.5f);
        stroke(120, 100, 70, 150);
        strokeWeight(max(0.38f, bl * 0.0042f));
        noFill();
        bezier(-bl * 0.009f, thick * -0.02f,
               -bl * 0.05f - armProgress * bl * 0.1f, thick * 0.05f + armProgress * bl * 0.05f,
               hoseEndX + bl * 0.03f, -thick * 0.05f + armProgress * bl * 0.03f,
               hoseEndX, -thick * 0.02f);
        noStroke();
      }

      popMatrix();
    }

    // 底部加注站
    fill(70, 65, 58);
    rect(bl * 0.2f, groundY - bl * 0.28f, bl * 0.035f, bl * 0.28f);
    fill(85, 80, 73);
    rect(bl * 0.16f, groundY - bl * 0.32f, bl * 0.08f, bl * 0.06f, 2);

    // 柔性软管 - 后期断开
    if (umbilicalDeployProgress < 0.85f) {
      float hoseProgress = (float)constrainDouble(umbilicalDeployProgress / 0.85f, 0.0f, 1.0f);
      stroke(100, 85, 65, 180);
      strokeWeight(max(0.65f, bl * 0.0075f));
      noFill();
      float hoseStart = bl * 0.215f;
      bezier(hoseStart, groundY - bl * 0.27f,
             bl * 0.09f, groundY - bl * 0.34f - hoseProgress * bl * 0.05f,
             -bw * 0.55f + hoseProgress * bl * 0.1f, groundY - bl * 0.13f - hoseProgress * bl * 0.03f,
             -bw * 0.28f + hoseProgress * bl * 0.05f, groundY - bl * 0.13f);
      noStroke();
    }
  }

  // ========== 9. 防雷桅杆 ==========

  void drawLightningMasts(float bl, float groundY) {
    float mastH = bl * 1.4f;
    float[] mastXs = { -bl * 1.15f, bl * 1.15f };

    for (float mx : mastXs) {
      // 主桅杆
      fill(90, 86, 80);
      float baseW = bl * 0.028f;
      float topW = bl * 0.009f;
      beginShape();
        vertex(mx - baseW * 0.5f, groundY);
        vertex(mx + baseW * 0.5f, groundY);
        vertex(mx + topW * 0.5f, groundY - mastH);
        vertex(mx - topW * 0.5f, groundY - mastH);
      endShape(CLOSE);

      // 桅杆横撑
      stroke(75, 71, 65, 120);
      strokeWeight(max(0.35f, bl * 0.0035f));
      for (int i = 0; i < 5; i++) {
        float hy = groundY - bl * 0.2f - i * bl * 0.25f;
        float hw = baseW * (1.0f - i * 0.15f);
        line(mx - hw * 0.7f, hy, mx + hw * 0.7f, hy);
      }
      noStroke();

      // 桅杆基座
      fill(70, 66, 60);
      rect(mx - bl * 0.035f, groundY - bl * 0.014f, bl * 0.07f, bl * 0.028f, 2);

      // 顶部避雷针
      fill(180, 170, 50);
      ellipse(mx, groundY - mastH, bl * 0.016f, bl * 0.016f);
    }

    // 连接线缆
    stroke(75, 70, 64, 120);
    strokeWeight(max(0.32f, bl * 0.0032f));
    noFill();
    float sag = bl * 0.13f;
    bezier(mastXs[0] + bl * 0.006f, groundY - mastH,
           mastXs[0] + bl * 0.55f, groundY - mastH + sag,
           mastXs[1] - bl * 0.55f, groundY - mastH + sag,
           mastXs[1] - bl * 0.006f, groundY - mastH);
    noStroke();

    // 接地引下线
    stroke(60, 55, 48, 150);
    strokeWeight(max(0.28f, bl * 0.0028f));
    for (float mx : mastXs) {
      line(mx + bl * 0.01f, groundY, mx + bl * 0.08f, groundY + bl * 0.12f);
    }
    noStroke();
  }

  // ========== 10. 周边设施 ==========

  void drawNearbyFacilities(float bl, float groundY) {
    // 左侧 - 小型工具棚
    fill(75, 70, 64);
    rect(-bl * 0.5f, groundY - bl * 0.08f, bl * 0.08f, bl * 0.08f, 2);
    fill(60, 55, 48);
    rect(-bl * 0.49f, groundY - bl * 0.095f, bl * 0.078f, bl * 0.02f);

    // 左侧 - 气瓶组
    for (int i = 0; i < 4; i++) {
      float gx = -bl * 0.4f + i * bl * 0.03f;
      fill(160, 165, 170);
      ellipse(gx, groundY - bl * 0.04f, bl * 0.02f, bl * 0.025f);
    }

    // 右侧 - 电气柜
    fill(65, 62, 56);
    rect(bl * 0.55f, groundY - bl * 0.1f, bl * 0.06f, bl * 0.1f, 1);
    rect(bl * 0.63f, groundY - bl * 0.085f, bl * 0.05f, bl * 0.085f, 1);

    // 右侧 - 消防水龙站
    fill(180, 60, 60);
    rect(bl * 0.72f, groundY - bl * 0.07f, bl * 0.045f, bl * 0.07f, 2);
    fill(200, 80, 80);
    rect(bl * 0.725f, groundY - bl * 0.075f, bl * 0.035f, bl * 0.01f);

    // 地面消防管线标记
    stroke(180, 60, 60, 80);
    strokeWeight(max(0.4f, bl * 0.004f));
    line(bl * 0.74f, groundY - bl * 0.005f, bl * 0.74f, groundY + bl * 0.08f);
    line(bl * 0.65f, groundY + bl * 0.08f, bl * 0.85f, groundY + bl * 0.08f);
    noStroke();

    // 安全距离标志牌
    fill(220, 200, 60, 120);
    rect(-bl * 1.35f, groundY - bl * 0.05f, bl * 0.09f, bl * 0.05f, 1);
    rect(bl * 1.26f, groundY - bl * 0.05f, bl * 0.09f, bl * 0.05f, 1);
  }
}
