// ============================================================
//  右下角飞船状态面板
// ============================================================
class ShipStatusPanel {
  float panelX, panelY, panelW, panelH;
  float panelMargin;
  Button launchButton;
  Button transferButton;
  float targetRowH;
  int hoveredTargetIndex;   // -1: 无, >=0: 行星索引
  int hoveredTargetFrames;

  ShipStatusPanel() {
    float scale = uiScale;
    panelW = 275 * scale;
    panelH = 360 * scale;
    panelX = width - panelW - 10 * scale;
    panelY = height - panelH - 10 * scale;
    panelMargin = 10 * scale;
    targetRowH = 26 * scale;

    // Launch button
    float btnX = panelX + panelMargin;
    float btnY = panelY + panelH - 48 * scale;
    float btnW = 140 * scale;
    float btnH = 32 * scale;
    launchButton = new Button(btnX, btnY, btnW, btnH, "Launch",
                              "Start launch sequence", "L");

    // Transfer button (same position)
    transferButton = new Button(btnX, btnY, btnW, btnH, "Transfer",
                                "Initiate Hohmann transfer to target", "T");

    hoveredTargetIndex = -1;
    hoveredTargetFrames = 0;
  }

  void update() {
    launchButton.update();
    transferButton.update();

    // 更新位置（全屏应用，width/height 可能变化）
    float scale = uiScale;
    panelX = width - panelW - 10 * scale;
    panelY = height - panelH - 10 * scale;
    launchButton.x = panelX + panelMargin;
    launchButton.y = panelY + panelH - 48 * scale;
    transferButton.x = launchButton.x;
    transferButton.y = launchButton.y;

    // 跟踪目标行星行 hover
    hoveredTargetIndex = -1;
    hoveredTargetFrames = 0;
    ShipState state = launchController.getState();
    if (state == ShipState.ORBIT) {
      CelestialBody earth = launchController.getEarth();
      List<CelestialBody> planets = solarSystem.planets;
      int rowY = (int)(panelY + 140 * scale);
      for (int i = 0; i < planets.size(); i++) {
        if (planets.get(i) == earth) continue;
        if (mouseX >= panelX && mouseX <= panelX + panelW &&
            mouseY >= rowY && mouseY <= rowY + targetRowH) {
          hoveredTargetIndex = i;
          hoveredTargetFrames = 1;
          break;
        }
        rowY += targetRowH;
      }
    }
  }

  void draw(LaunchController ctrl, Spacecraft ship, CelestialBody earth, List<CelestialBody> planets) {
    float scale = uiScale;
    ShipState state = ctrl.getState();

    pushStyle();

    // 面板背景
    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8 * scale);

    // 标题
    fill(100, 200, 100);
    textSize(16 * scale);
    textAlign(LEFT, TOP);
    text("SPACECRAFT", panelX + panelMargin, panelY + panelMargin);

    // ========== 上半部分：高度 + 速度 ==========
    float dataY = panelY + 40 * scale;
    drawAltitudeSpeed(ship, state, dataY);

    // 分隔线
    float sepY = panelY + 120 * scale;
    stroke(100, 100, 120, 100);
    strokeWeight(1);
    line(panelX + panelMargin, sepY, panelX + panelW - panelMargin, sepY);
    noStroke();

    // ========== 下半部分：阶段指示 ==========
    float phaseY = panelY + 135 * scale;
    drawPhaseIndicator(ship, state, ctrl, earth, planets, phaseY);

    popStyle();
  }

  void drawAltitudeSpeed(Spacecraft ship, ShipState state, float y) {
    float scale = uiScale;
    float currentAlt = 0;
    double currentSpeed = 0;

    // 计算当前高度和速度
    if (state == ShipState.IDLE || state == ShipState.COUNTDOWN ||
        state == ShipState.IGNITION) {
      currentAlt = 0;
      currentSpeed = 0;
    } else if (ship.earthRelative) {
      currentAlt = (float)ship.launchAltitude;
      currentSpeed = sqrt((float)(ship.earthRelVel[0] * ship.earthRelVel[0] +
                          ship.earthRelVel[1] * ship.earthRelVel[1]));
    } else {
      // 日心模式：距离太阳的高度（公里）
      currentAlt = (float)(sqrt((float)(ship.px * ship.px + ship.py * ship.py)) / 1000);
      // 轨道速度
      double nu = ship.currentNu + 0.01;
      double[] pos = orbitalToCartesian(ship.a, ship.e, ship.i, ship.omega, ship.w, nu);
      currentSpeed = sqrt((float)((pos[0] - ship.px) * (pos[0] - ship.px) +
                          (pos[1] - ship.py) * (pos[1] - ship.py))) / 0.01;
    }

    // 高度条（仅地球相对模式显示 LEO 刻度）
    float barX = panelX + panelMargin;
    float barY = y;
    float barW = panelW - 2 * panelMargin;
    float barH = 18 * scale;

    fill(30, 30, 30);
    noStroke();
    rect(barX, barY, barW, barH, 4 * scale);

    float leoAlt = (float)MissionPlanner.LEO_ALTITUDE_KM;
    float fillRatio = 0;
    if (ship.earthRelative) {
      fillRatio = min(1, max(0, currentAlt / leoAlt));
    } else {
      // 日心模式：用简单的归一化显示
      float auToKm = 149600000;
      float maxAlt = 10 * auToKm;
      fillRatio = min(1, max(0, currentAlt / maxAlt));
    }
    fill(80, 180, 80);
    rect(barX, barY, barW * fillRatio, barH, 4 * scale);

    // LEO 目标线（仅地球相对模式）
    if (ship.earthRelative) {
      float targetX = barX + barW * 1;
      stroke(100, 200, 100);
      strokeWeight(2);
      line(targetX, barY - 2, targetX, barY + barH + 2);
      noStroke();
    }

    // 高度文字
    fill(200);
    textSize(13 * scale);
    textAlign(LEFT, TOP);
    if (ship.earthRelative) {
      text(String.format("Altitude: %.0f / 420 km", currentAlt),
           barX, barY + barH + 6);
    } else {
      text(String.format("Sun distance: %.3f AU", currentAlt / 149600000),
           barX, barY + barH + 6);
    }

    // 速度文字
    textAlign(RIGHT, TOP);
    text(String.format("Speed: %.2f km/s", currentSpeed),
         panelX + panelW - panelMargin, barY + barH + 6);

    // 引擎指示器（小）
    float engineY = barY + barH + 26 * scale;
    if (ship.thrustActive) {
      fill(255, 160, 40);
      textSize(12 * scale);
      textAlign(LEFT, TOP);
      text("ENGINE: BURNING", panelX + panelMargin, engineY);
      // 小火焰图标
      float flameX = panelX + panelW - 40 * scale;
      float flameY = engineY + 5 * scale;
      float s = 4 * scale;
      fill(255, 200, 50, 180);
      noStroke();
      triangle(flameX, flameY - s, flameX, flameY + s, flameX + s * 2.5f, flameY);
    } else {
      fill(120);
      textSize(12 * scale);
      textAlign(LEFT, TOP);
      text("ENGINE: OFF", panelX + panelMargin, engineY);
    }
  }

  void drawPhaseIndicator(Spacecraft ship, ShipState state, LaunchController ctrl,
                          CelestialBody earth, List<CelestialBody> planets, float y) {
    float scale = uiScale;

    switch (state) {
      case IDLE:
        fill(100, 200, 100);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: READY", panelX + panelMargin, y);
        fill(180);
        textSize(12 * scale);
        text("Spacecraft on launch pad", panelX + panelMargin, y + 22);
        launchButton.draw();
        break;

      case COUNTDOWN:
        float remaining = (float)(Spacecraft.COUNTDOWN_DURATION -
                         (timeManager.simTime - ship.countdownStartTime));
        int sec = (int)ceil(max(0.0f, remaining));
        fill(255, 200, 50);
        textSize(28 * scale);
        textAlign(CENTER, TOP);
        text("T - " + sec + " s", panelX + panelW / 2, y);
        break;

      case IGNITION:
        float pulse = (float)(sin(millis() / 1000.0 * 18.0) * 0.3 + 0.7);
        fill(255, (int)(100 * pulse), (int)(20 * pulse));
        textSize(18 * scale);
        textAlign(CENTER, TOP);
        text("ENGINE IGNITION", panelX + panelW / 2, y);
        fill(180);
        textSize(13 * scale);
        text("Hold-down phase", panelX + panelW / 2, y + 26);
        break;

      case LAUNCHING:
        fill(255, 160, 60);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: ASCENT", panelX + panelMargin, y);
        // Apoapsis
        double apo = ship.computeApoapsis();
        fill(180);
        textSize(12 * scale);
        if (ship.thrustActive) {
          text(String.format("Apoapsis: %.0f / 420 km", apo),
               panelX + panelMargin, y + 22);
          // 进度条
          float barX = panelX + panelMargin;
          float barY = y + 42;
          float barW = panelW - 2 * panelMargin;
          float barH = 12 * scale;
          double progress = Math.min(1.0, Math.max(0.0, apo / MissionPlanner.LEO_ALTITUDE_KM));
          drawProgressBar(barX, barY, barW, barH, (float)progress,
                         "Burn: " + (int)(progress * 100) + "%");
        } else {
          text(String.format("Apoapsis: %.0f km", apo),
               panelX + panelMargin, y + 22);
          fill(70, 90, 110);
          noStroke();
          rect(panelX + panelMargin, y + 42, panelW - 2 * panelMargin, 12 * scale, 4 * scale);
          fill(180);
          textSize(11 * scale);
          textAlign(CENTER, CENTER);
          text("Coasting to apoapsis...", panelX + panelW / 2, y + 48);
        }
        break;

      case CIRCULARIZING:
        fill(255, 160, 60);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: CIRCULARIZING", panelX + panelMargin, y);
        // Perigee
        double peri = ship.computePerigee();
        fill(180);
        textSize(12 * scale);
        text(String.format("Perigee: %.0f / 420 km", peri),
             panelX + panelMargin, y + 22);
        // 进度条
        float barX = panelX + panelMargin;
        float barY = y + 42;
        float barW = panelW - 2 * panelMargin;
        float barH = 12 * scale;
        double periProgress = Math.min(1.0, Math.max(0.0, peri / MissionPlanner.LEO_ALTITUDE_KM));
        drawProgressBar(barX, barY, barW, barH, (float)periProgress,
                       "Circularize: " + (int)(periProgress * 100) + "%");
        break;

      case ORBIT:
        fill(100, 200, 100);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: IN ORBIT", panelX + panelMargin, y);
        // 目标行星列表
        if (ctrl.getSelectedTarget() == null) {
          fill(180);
          textSize(12 * scale);
          text("Select a target planet:", panelX + panelMargin, y + 22);
          int rowY = (int)(y + 42);
          for (int i = 0; i < planets.size(); i++) {
            CelestialBody p = planets.get(i);
            if (p == earth) continue;
            // 行绘制
            boolean isHovered = (hoveredTargetIndex == i);
            if (isHovered) {
              fill(255, 255, 255, 15);
              noStroke();
              rect(panelX + panelMargin - 5, rowY - 2, panelW - 2 * panelMargin + 10, targetRowH - 2, 4 * scale);
            }
            fill(p.col);
            textSize(13 * scale);
            textAlign(LEFT, CENTER);
            text(p.name, panelX + panelMargin + 8, rowY + targetRowH / 2);
            rowY += targetRowH;
          }
        } else {
          // 已选择目标，显示 Transfer 按钮
          fill(180);
          textSize(12 * scale);
          text("Target: " + ctrl.getSelectedTarget().name, panelX + panelMargin, y + 22);
          transferButton.enabled = ctrl.canTransfer();
          transferButton.draw();
        }
        break;

      case WAITING_FOR_WINDOW:
        fill(150, 200, 255);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: WAITING FOR WINDOW", panelX + panelMargin, y);
        // 显示倒计时
        TransferParameters mission = ctrl.getCurrentMission();
        if (mission != null) {
          double secToWindow = mission.launchDate - timeManager.simTime;
          fill(180);
          textSize(12 * scale);
          if (secToWindow > 0) {
            text("Time to TMI: " + formatSimTime(secToWindow),
                 panelX + panelMargin, y + 22);
            // 显示 ΔV 预算
            text(String.format("TMI ΔV: %.2f km/s", mission.tmiDeltaV),
                 panelX + panelMargin, y + 40);
            text(String.format("TOI ΔV: %.2f km/s", mission.toiDeltaV),
                 panelX + panelMargin, y + 58);
          } else {
            text("TMI Burn Ready!", panelX + panelMargin, y + 22);
          }
        }
        break;

      case TMI_BURN:
        fill(255, 150, 50);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: TMI BURN", panelX + panelMargin, y);
        // 燃烧进度
        fill(180);
        textSize(12 * scale);
        double tmiTarget = ctrl.currentMission != null ? ctrl.currentMission.tmiDeltaV : ship.tmiTargetDV;
        double tmiApplied = ship.tmiAccumulatedDV;
        double tmiProgress = tmiTarget > 0 ? tmiApplied / tmiTarget : 1.0;
        text(String.format("TMI: %d%% complete", (int)(tmiProgress * 100)),
             panelX + panelMargin, y + 22);
        // 进度条
        float tmiBarX = panelX + panelMargin;
        float tmiBarY = y + 42;
        float tmiBarW = panelW - 2 * panelMargin;
        float tmiBarH = 12 * scale;
        drawProgressBar(tmiBarX, tmiBarY, tmiBarW, tmiBarH, (float)tmiProgress,
                       String.format("%.2f / %.2f km/s", tmiApplied, tmiTarget));
        break;

      case TRANSFER:
        fill(100, 150, 255);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: TRANSFER", panelX + panelMargin, y);
        // 日心距离
        float auDist = (float)(sqrt((float)(ship.px * ship.px + ship.py * ship.py)) / 1.496e8);
        fill(180);
        textSize(12 * scale);
        text(String.format("Sun distance: %.3f AU", auDist),
             panelX + panelMargin, y + 22);
        // 转移进度（使用新的 TransferParameters）
        TransferParameters transMission = ctrl.getCurrentMission();
        if (transMission != null) {
          double elapsed = timeManager.simTime - ctrl.transferStartTime;
          double total = transMission.transferTime;
          double progress = Math.min(1.0, elapsed / Math.max(1.0, total));
          float tBarX = panelX + panelMargin;
          float tBarY = y + 42;
          float tBarW = panelW - 2 * panelMargin;
          float tBarH = 10 * scale;
          double secLeft = total - elapsed;
          drawProgressBar(tBarX, tBarY, tBarW, tBarH, (float)progress,
                         "ETA: " + formatSimTime(secLeft));
        } else if (ctrl.transferOrbitParams != null) {
          // 向后兼容
          double elapsed = timeManager.simTime - ctrl.transferStartTime;
          double total = ctrl.planner.calculateTransferTime(ctrl.transferOrbitParams[0], GM_SUN);
          double progress = Math.min(1.0, elapsed / Math.max(1.0, total));
          float tBarX = panelX + panelMargin;
          float tBarY = y + 42;
          float tBarW = panelW - 2 * panelMargin;
          float tBarH = 10 * scale;
          drawProgressBar(tBarX, tBarY, tBarW, tBarH, (float)progress,
                         "Transfer: " + (int)(progress * 100) + "%");
        }
        break;

      case APPROACHING_TARGET:
        fill(100, 180, 255);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: APPROACHING TARGET", panelX + panelMargin, y);
        // 接近距离
        fill(180);
        textSize(12 * scale);
        double approachDist = ctrl.closestApproachDistance / 1e6;
        text(String.format("Distance: %.2f M km", approachDist),
             panelX + panelMargin, y + 22);
        break;

      case TOI_BURN:
        fill(255, 150, 50);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: TOI BURN", panelX + panelMargin, y);
        // 燃烧进度
        fill(180);
        textSize(12 * scale);
        double toiTarget = ctrl.currentMission != null ? ctrl.currentMission.toiDeltaV : ship.toiTargetDV;
        double toiApplied = ship.toiAccumulatedDV;
        double toiProgress = toiTarget > 0 ? toiApplied / toiTarget : 1.0;
        text(String.format("TOI: %d%% complete", (int)(toiProgress * 100)),
             panelX + panelMargin, y + 22);
        // 进度条
        float toiBarX = panelX + panelMargin;
        float toiBarY = y + 42;
        float toiBarW = panelW - 2 * panelMargin;
        float toiBarH = 12 * scale;
        drawProgressBar(toiBarX, toiBarY, toiBarW, toiBarH, (float)toiProgress,
                       String.format("%.2f / %.2f km/s", toiApplied, toiTarget));
        break;

      case CAPTURED:
        fill(100, 200, 100);
        textSize(15 * scale);
        textAlign(LEFT, TOP);
        text("PHASE: CAPTURED", panelX + panelMargin, y);
        fill(180);
        textSize(12 * scale);
        if (ctrl.getSelectedTarget() != null) {
          text("Orbiting " + ctrl.getSelectedTarget().name,
               panelX + panelMargin, y + 22);
        }
        break;
    }
  }

  void drawProgressBar(float x, float y, float w, float h, float progress, String label) {
    float scale = uiScale;

    fill(30, 30, 30);
    noStroke();
    rect(x, y, w, h, 4 * scale);

    fill(80, 180, 80);
    rect(x, y, w * min(1.0f, max(0.0f, progress)), h, 4 * scale);

    fill(220);
    textSize(11 * scale);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  boolean handleClick(float mx, float my, LaunchController ctrl, List<CelestialBody> planets) {
    ShipState state = ctrl.getState();

    // Launch button
    if (state == ShipState.IDLE && launchButton.consumeClick()) {
      ctrl.startLaunch();
      return true;
    }

    // Transfer button
    if (state == ShipState.ORBIT && ctrl.canTransfer() && transferButton.consumeClick()) {
      ctrl.initiateTransfer();
      return true;
    }

    // Target selection (ORBIT state, no target selected yet)
    if (state == ShipState.ORBIT && ctrl.getSelectedTarget() == null) {
      CelestialBody earth = ctrl.getEarth();
      float scale = uiScale;
      int rowY = (int)(panelY + 140 * scale);
      for (int i = 0; i < planets.size(); i++) {
        CelestialBody p = planets.get(i);
        if (p == earth) continue;
        if (mx >= panelX && mx <= panelX + panelW &&
            my >= rowY && my <= rowY + targetRowH) {
          ctrl.selectTarget(p);
          return true;
        }
        rowY += targetRowH;
      }
    }

    return false;
  }

  ArrayList<Button> getAllButtons() {
    ArrayList<Button> buttons = new ArrayList<Button>();
    ShipState state = launchController.getState();
    if (state == ShipState.IDLE) {
      buttons.add(launchButton);
    } else if (state == ShipState.ORBIT) {
      buttons.add(transferButton);
    }
    return buttons;
  }

  String getHoveredTooltipText() {
    ShipState state = launchController.getState();
    if (state == ShipState.IDLE && launchButton.shouldShowTooltip()) {
      return launchButton.getTooltipText();
    }
    if (state == ShipState.ORBIT && transferButton.shouldShowTooltip()) {
      return transferButton.getTooltipText();
    }
    if (hoveredTargetIndex >= 0 && hoveredTargetFrames >= Button.TOOLTIP_DELAY) {
      CelestialBody earth = launchController.getEarth();
      List<CelestialBody> planets = solarSystem.planets;
      int displayCount = 0;
      CelestialBody target = null;
      for (int i = 0; i < planets.size(); i++) {
        if (planets.get(i) == earth) continue;
        if (displayCount == hoveredTargetIndex) {
          target = planets.get(i);
          break;
        }
        displayCount++;
      }
      if (target != null) {
        return "Select " + target.name + " as transfer target";
      }
    }
    return null;
  }
}
