// ========== RECOVERY CONTROLLER ==========
// 回收任务控制器

class RecoveryController {
  // === 状态 ===
  RecoveryStage stage;
  String statusText;
  double progress;

  // === 关联对象 ===
  Spacecraft spacecraft;
  LaunchSite launchSite;
  CelestialBody earth;
  RecoveryGuidanceSystem guidance;

  // === 时间记录 ===
  double missionStartTime;
  double deorbitBurnStartTime;
  double stageEntryTime;

  // === 目标 ===
  Vector2 targetLandingPosition;
  double deorbitBurnDuration;
  double timeToDeorbitBurn;
  double deorbitBurnTargetTime;  // 目标点火时间（绝对simTime）

  // === 新增变量 ===
  double timeToDeorbitBurnAtStart = 0;
  double lastUpdateSimTime = 0;

  // === 构造函数 ===
  RecoveryController() {
    this.stage = RecoveryStage.IDLE;
    this.statusText = "Ready";
    this.progress = 0.0;
    this.guidance = new RecoveryGuidanceSystem();
  }

  // === 初始化 ===
  void init(Spacecraft craft, LaunchSite site, CelestialBody earthBody) {
    this.spacecraft = craft;
    this.launchSite = site;
    this.earth = earthBody;
  }

  // === 开始回收任务（用户点击开始时调用）===
  void startRecovery(double currentSimTime) {
    println("[RecoveryController] ========== startRecovery() called ==========");
    println("[RecoveryController] spacecraft: " + (spacecraft != null ? "exists" : "null"));
    println("[RecoveryController] earth: " + (earth != null ? earth.name : "null"));
    println("[RecoveryController] launchSite: " + (launchSite != null ? "exists" : "null"));

    if (spacecraft == null || earth == null) {
      println("[RecoveryController] FAILED: spacecraft or earth is null");
      return;
    }

    // 重置PID控制器
    guidance.resetPIDs();

    // 任务开始
    this.missionStartTime = currentSimTime;
    this.stage = RecoveryStage.PREPARING;
    println("[RecoveryController] Stage set to PREPARING");

    // 获取实时轨道状态
    Orbit currentOrbit = spacecraft.orbit;
    println("[RecoveryController] spacecraft.orbit: " + (currentOrbit != null ? "exists" : "null"));
    if (currentOrbit == null && spacecraft.referenceBody != null) {
      // 如果没有轨道对象，从状态向量创建
      println("[RecoveryController] Creating orbit from state vector...");
      currentOrbit = Orbit_fromStateVector(spacecraft.stateVector.position, spacecraft.stateVector.velocity, spacecraft.referenceBody, currentSimTime);
    }

    if (currentOrbit == null) {
      println("[RecoveryController] FAILED: No valid orbit");
      stage = RecoveryStage.ABORT;
      statusText = "Error: No valid orbit";
      return;
    }

    println("[RecoveryController] Got valid orbit, a=" + currentOrbit.a + ", e=" + currentOrbit.e);

    // 快速计算离轨点（当前圈最近的）
    println("[RecoveryController] Finding deorbit opportunity...");
    timeToDeorbitBurn = guidance.findNextDeorbitOpportunity(currentOrbit, earth, launchSite, currentSimTime);
    timeToDeorbitBurnAtStart = timeToDeorbitBurn;
    deorbitBurnTargetTime = currentSimTime + timeToDeorbitBurn;
    println("[RecoveryController] timeToDeorbitBurn: " + timeToDeorbitBurn + " seconds");
    println("[RecoveryController] deorbitBurnTargetTime: " + deorbitBurnTargetTime + " simTime");
    println("[RecoveryController] currentSimTime: " + currentSimTime);

    // 计算目标着陆位置
    double siteAngle = launchSite.baseAngle;
    double r = earth.radius;
    targetLandingPosition = new Vector2(r * Math.cos(siteAngle), r * Math.sin(siteAngle));

    println("[RecoveryController] Target landing position: angle=" + String.format("%.1f", Math.toDegrees(siteAngle)) + "°" +
            ", pos=(" + String.format("%.1f", targetLandingPosition.x) + "," + String.format("%.1f", targetLandingPosition.y) + ")");
    println("[RecoveryController] Current spacecraft position: (" +
            String.format("%.1f", spacecraft.stateVector.position.x) + "," + String.format("%.1f", spacecraft.stateVector.position.y) + ")");

    // 动态计算离轨燃烧持续时间
    deorbitBurnDuration = guidance.computeDeorbitBurnDuration(spacecraft);

    statusText = "Preparing for deorbit in " + formatTime(timeToDeorbitBurn);
    progress = 0.0;

    println("[RecoveryController] Status: " + statusText);

    // 激活自动控制
    spacecraft.autoControl.isActive = true;
    println("[RecoveryController] Auto control activated");

    println("[RecoveryController] ========== startRecovery() complete ==========");
  }

  // === 帧更新（保持向后兼容）===
  void update(double simTime, double simDt) {
    updateTick(simDt, simTime);
  }

  // === Tick更新 ===
  void updateTick(double tickDt, double currentSimTime) {
    lastUpdateSimTime = currentSimTime;
    if (spacecraft == null) return;

    double timeSinceStart = currentSimTime - missionStartTime;

    switch (stage) {
      case IDLE:
        break;

      case PREPARING:
        updatePreparing(timeSinceStart, currentSimTime);
        break;

      case DEORBIT_BURN:
        updateDeorbitBurn(tickDt, timeSinceStart, currentSimTime);
        break;

      case COAST_TO_ENTRY:
        updateCoastToEntry(tickDt);
        break;

      case REENTRY_GUIDANCE:
        updateReentryGuidance(tickDt, currentSimTime);
        break;

      case GLIDE_PHASE:
        updateGlidePhase(tickDt, currentSimTime);
        break;

      case TURNAROUND_MANEUVER:
        updateTurnaroundManeuver(tickDt, currentSimTime);
        break;

      case HOVER_SLIDE:
        updateHoverSlide(tickDt, currentSimTime);
        break;

      case FINAL_DESCENT:
        updateFinalDescent(tickDt, currentSimTime);
        break;

      case LANDING_BURN:
        updateLandingBurn(tickDt);
        break;

      case LANDED:
        updateLanded();
        break;

      case ABORT:
        break;
    }

    updateProgress(timeSinceStart);
  }

  // === 准备阶段 ===
  void updatePreparing(double timeSinceStart, double currentSimTime) {
    // 正确计算剩余时间
    timeToDeorbitBurn = deorbitBurnTargetTime - currentSimTime;

    // 每15秒输出一次日志，包含位置信息
    if ((int)currentSimTime % 15 == 0) {
      Vector2 pos = spacecraft.stateVector.position;
      double currentAngle = Math.atan2(pos.y, pos.x);
      double targetAngle = Math.atan2(targetLandingPosition.y, targetLandingPosition.x);
      double angleDiff = Math.toDegrees(Math.abs(guidance.normalizeAnglePI(targetAngle - currentAngle)));

      println("[RecoveryController] PREPARING: t=" + (int)currentSimTime +
              ", t-ignite=" + String.format("%.1f", timeToDeorbitBurn) + "s" +
              ", angleToTarget=" + String.format("%.1f", angleDiff) + "°");
    }

    if (timeToDeorbitBurn <= 3.0 && timeToDeorbitBurn > 0) {
      // 开始定向
      println("[RecoveryController] Starting orientation to retrograde...");
      Vector2 retrograde = spacecraft.getRetrograde();
      spacecraft.autoControl.setTargetDirection(retrograde);
    }

    if (timeToDeorbitBurn <= 0) {
      // 开始离轨燃烧
      println("[RecoveryController] ========== STARTING DEORBIT BURN ==========");
      println("[RecoveryController] Time reached: currentSimTime=" + currentSimTime);
      stage = RecoveryStage.DEORBIT_BURN;
      stageEntryTime = currentSimTime;
      deorbitBurnStartTime = currentSimTime;

      // 设置燃烧
      spacecraft.autoControl.setBurn(1.0f, deorbitBurnDuration);
      spacecraft.autoControl.targetThrottle = 1.0f;
      if (spacecraft.mainEngine != null) {
        spacecraft.mainEngine.setThrottle(1.0f);
      }
      Vector2 retrograde = spacecraft.getRetrograde();
      spacecraft.autoControl.setTargetDirection(retrograde);
      spacecraft.enterOffRails();

      statusText = "Deorbit burn in progress";
      println("[RecoveryController] Deorbit burn initiated!");
    } else {
      statusText = "Preparing for deorbit in " + formatTime(timeToDeorbitBurn);
    }
  }

  // === 离轨燃烧阶段 ===
  void updateDeorbitBurn(double tickDt, double timeSinceStart, double currentSimTime) {
    // 用绝对时间计算燃烧时间
    double elapsedBurnTime = currentSimTime - deorbitBurnStartTime;

    // 每30帧输出一次日志（约0.5秒）
    if ((int)(currentSimTime * 60) % 30 == 0) {
      double remaining = Math.max(deorbitBurnDuration - elapsedBurnTime, 0);
      println("[RecoveryController] DEORBIT_BURN: elapsed=" + elapsedBurnTime + "s / " + deorbitBurnDuration + "s" +
              ", remaining=" + remaining + "s" +
              ", targetThrottle=" + spacecraft.autoControl.targetThrottle +
              ", engineThrottle=" + (spacecraft.mainEngine != null ? spacecraft.mainEngine.currentThrottle : "null"));
    }

    if (elapsedBurnTime >= deorbitBurnDuration) {
      // 燃烧完成
      println("[RecoveryController] ========== DEORBIT BURN COMPLETE ==========");
      stage = RecoveryStage.COAST_TO_ENTRY;
      stageEntryTime = currentSimTime;
      guidance.resetPIDs(); // 重置PID，为下一阶段做准备

      // 关闭引擎
      spacecraft.autoControl.targetThrottle = 0.0f;
      if (spacecraft.mainEngine != null) {
        spacecraft.mainEngine.setThrottle(0.0f);
      }

      statusText = "Coasting to entry interface";
      println("[RecoveryController] Status: " + statusText);
    } else {
      // 确保油门一直开着
      spacecraft.autoControl.targetThrottle = 1.0f;
      if (spacecraft.mainEngine != null) {
        spacecraft.mainEngine.setThrottle(1.0f);
      }

      // 更新状态文本
      double remaining = deorbitBurnDuration - elapsedBurnTime;
      statusText = "Deorbit burn: " + formatTime(remaining) + " remaining";
    }
  }

  // === 再入前滑行阶段 ===
  void updateCoastToEntry(double tickDt) {
    double altitude = spacecraft.getAltitude();

    if (altitude <= 120.0) {
      // 进入再入界面
      stage = RecoveryStage.REENTRY_GUIDANCE;
      stageEntryTime = missionStartTime + altitude; // 简化
      statusText = "Entry interface - Beginning reentry guidance";
      guidance.resetPIDs();
    } else {
      // 保持指向速度方向
      Vector2 prograde = spacecraft.getPrograde();
      spacecraft.autoControl.setTargetDirection(prograde);
      statusText = "Coasting to entry: " + (int)altitude + " km";
    }
  }

  // === 再入制导阶段 ===
  void updateReentryGuidance(double tickDt, double currentSimTime) {
    double altitude = spacecraft.getAltitude();
    double speed = spacecraft.stateVector.velocity.magnitude();
    double mach = earth.atmosphere.getMachNumber(speed, altitude);

    // 更新阻力系数
    spacecraft.updateDragCoefficient(mach, altitude);

    // 获取制导输出（带位置闭环）
    GuidanceOutput guidanceOut = guidance.reentryGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity,
      earth.GM,
      spacecraft.gLoad,
      targetLandingPosition,
      currentSimTime,
      earth
    );

    // 设置攻角
    spacecraft.setAngleOfAttack(guidanceOut.targetAngleOfAttack);

    // 保持大致方向
    Vector2 prograde = spacecraft.getPrograde();
    spacecraft.autoControl.setTargetDirection(prograde);

    if (altitude <= 20.0) {
      stage = RecoveryStage.GLIDE_PHASE;
      statusText = "Glide phase - Navigating to landing site";
      println("[RecoveryController] ========== EXIT REENTRY, ENTER GLIDE_PHASE ==========");
      guidance.resetPIDs();
    } else {
      statusText = "Reentry: " + (int)altitude + " km, Mach " + String.format("%.1f", mach) + ", G: " + String.format("%.1f", spacecraft.gLoad);
    }
  }

  // === 滑翔阶段 ===
  void updateGlidePhase(double tickDt, double currentSimTime) {
    double altitude = spacecraft.getAltitude();

    // 预测着陆点（每2秒一次）
    if ((int)currentSimTime % 2 == 0) {
      Vector2 predictedLanding = guidance.predictLandingPosition(
        spacecraft.stateVector.position,
        spacecraft.stateVector.velocity,
        earth
      );

      // 计算预测着陆点与目标的误差
      double predictedError = predictedLanding.sub(targetLandingPosition).magnitude();

      // 计算角度
      Vector2 pos = spacecraft.stateVector.position;
      Vector2 vel = spacecraft.stateVector.velocity;
      double currentAngle = Math.toDegrees(Math.atan2(pos.y, pos.x));
      double targetAngle = Math.toDegrees(Math.atan2(targetLandingPosition.y, targetLandingPosition.x));
      double velocityAngle = Math.toDegrees(Math.atan2(vel.y, vel.x));

      println("[RecoveryController] GLIDE_PHASE: alt=" + (int)altitude + "km" +
              ", posAngle=" + String.format("%.1f", currentAngle) + "°" +
              ", velAngle=" + String.format("%.1f", velocityAngle) + "°" +
              ", targetAngle=" + String.format("%.1f", targetAngle) + "°");
      println("[RecoveryController]   -> pos=(" + String.format("%.0f", pos.x) + "," + String.format("%.0f", pos.y) + ")" +
              ", target=(" + String.format("%.0f", targetLandingPosition.x) + "," + String.format("%.0f", targetLandingPosition.y) + ")" +
              ", predicted=(" + String.format("%.0f", predictedLanding.x) + "," + String.format("%.0f", predictedLanding.y) + ")");
    }

    // 滑翔制导
    GuidanceOutput guidanceOut = guidance.glideGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity,
      targetLandingPosition,
      currentSimTime,
      earth
    );

    spacecraft.setAngleOfAttack(guidanceOut.targetAngleOfAttack);

    // 保持朝向速度方向（滑翔时头朝运动方向）
    Vector2 prograde = spacecraft.getPrograde();
    spacecraft.autoControl.setTargetDirection(prograde);

    if (altitude <= 10.0) {
      stage = RecoveryStage.TURNAROUND_MANEUVER;
      statusText = "Performing turnaround maneuver";
      println("[RecoveryController] ========== EXIT GLIDE, ENTER TURNAROUND ==========");
      guidance.resetPIDs();
    } else {
      statusText = "Gliding: " + (int)altitude + " km, AoA: " + String.format("%.2f", guidanceOut.targetAngleOfAttack);
    }
  }

  // === 转向机动阶段 ===
  void updateTurnaroundManeuver(double tickDt, double currentSimTime) {
    double altitude = spacecraft.getAltitude();

    // 转向径向向外的同时，加入水平控制
    LandingGuidanceOutput landingOut = guidance.propulsiveLandingGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity,
      targetLandingPosition,
      altitude,
      earth.GM,
      currentSimTime
    );

    // 在转向阶段，还是以径向向外为主，但可以加入一点水平修正
    Vector2 radialOut = spacecraft.getRadialOut();
    // 平滑过渡，高度越低，水平修正越多
    double blendFactor = Math.max(0.0, Math.min(1.0, (10.0 - altitude) / 5.0));
    Vector2 targetDir = radialOut.mul(1.0 - blendFactor).add(landingOut.targetDirection.mul(blendFactor)).normalized();

    spacecraft.autoControl.setTargetDirection(targetDir);
    spacecraft.autoControl.targetThrottle = 0.0f; // 这个阶段还不点火

    if (altitude <= 5.0 || spacecraft.autoControl.isOriented()) {
      stage = RecoveryStage.HOVER_SLIDE;
      spacecraft.deployLandingLegs();
      statusText = "Approaching - Hover and slide";
      println("[RecoveryController] ========== EXIT TURNAROUND, ENTER HOVER_SLIDE ==========");
      guidance.resetPIDs();
    } else {
      statusText = "Turning for landing: " + String.format("%.0f", altitude * 1000) + " m";
    }
  }

  // === 悬停平移阶段 ===
  void updateHoverSlide(double tickDt, double currentSimTime) {
    double altitude = spacecraft.getAltitude();

    // 着陆制导
    LandingGuidanceOutput landingOut = guidance.propulsiveLandingGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity,
      targetLandingPosition,
      altitude,
      earth.GM,
      currentSimTime
    );

    spacecraft.autoControl.setTargetDirection(landingOut.targetDirection);
    spacecraft.autoControl.targetThrottle = landingOut.targetThrottle;
    if (spacecraft.mainEngine != null) {
      spacecraft.mainEngine.setThrottle(landingOut.targetThrottle);
    }

    if (altitude <= 0.5) {
      stage = RecoveryStage.FINAL_DESCENT;
      statusText = "Final descent";
      println("[RecoveryController] ========== EXIT HOVER_SLIDE, ENTER FINAL_DESCENT ==========");
      guidance.resetPIDs();
    } else {
      statusText = "Approaching: " + String.format("%.1f", altitude * 1000) + " m";
    }
  }

  // === 最终下降阶段 ===
  void updateFinalDescent(double tickDt, double currentSimTime) {
    double altitude = spacecraft.getAltitude();

    // 保持完整的着陆制导，直到非常接近地面
    LandingGuidanceOutput landingOut = guidance.propulsiveLandingGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity,
      targetLandingPosition,
      altitude,
      earth.GM,
      currentSimTime
    );

    spacecraft.autoControl.setTargetDirection(landingOut.targetDirection);
    spacecraft.autoControl.targetThrottle = landingOut.targetThrottle;
    if (spacecraft.mainEngine != null) {
      spacecraft.mainEngine.setThrottle(landingOut.targetThrottle);
    }

    double shipHalfHeight = Spacecraft.SHIP_LENGTH_KM * 0.5;
    double landingBurnAltitude = 0.05 + shipHalfHeight; // 原50m + 箭体半高40m = 90m

    if (altitude <= landingBurnAltitude) { // 考虑箭体高度，提前进入着陆燃烧
      stage = RecoveryStage.LANDING_BURN;
      statusText = "Touchdown imminent";
      println("[RecoveryController] ========== EXIT FINAL_DESCENT, ENTER LANDING_BURN ==========");
      guidance.resetPIDs();
    } else {
      statusText = "Final descent: " + String.format("%.0f", altitude * 1000) + " m";
    }
  }

  // === 着陆燃烧阶段 ===
  void updateLandingBurn(double tickDt) {
    double altitude = spacecraft.getAltitude();
    double r = spacecraft.stateVector.position.magnitude();
    double verticalVel = spacecraft.stateVector.position.dot(spacecraft.stateVector.velocity) / r;

    // 考虑火箭本体高度：当底部接近地表时触地
    double shipHalfHeight = Spacecraft.SHIP_LENGTH_KM * 0.5;
    double touchdownAltitude = shipHalfHeight;

    // 保持竖直姿态（径向向外）
    Vector2 radialOut = spacecraft.getRadialOut();
    spacecraft.autoControl.setTargetDirection(radialOut);

    // ========== 精细软着陆控制 ==========
    // 目标：落地瞬间垂直速度接近0
    double heightAboveSurface = altitude - touchdownAltitude; // 底部距地表高度（km）

    // 根据高度和当前速度计算目标下降率
    double targetVerticalVel;
    if (heightAboveSurface > 0.03) { // >30m: 平缓下降，-2m/s
      targetVerticalVel = -0.002;
    } else if (heightAboveSurface > 0.01) { // 10-30m: 继续减缓，-1m/s
      targetVerticalVel = -0.001;
    } else { // <10m: 非常缓慢，-0.5m/s并逐渐趋近0
      targetVerticalVel = -0.0005 * (heightAboveSurface / 0.01);
    }

    // 速度误差（需要增加推力来减速）
    double vertVelError = targetVerticalVel - verticalVel;

    // 更新积分项（仅在有高度时）
    if (altitude > 0.01) {
      guidance.vertVelIntegral += vertVelError * tickDt;
      guidance.vertVelIntegral = constrainDouble(guidance.vertVelIntegral, -0.5, 0.5);
    }

    // PID计算
    double baseThrottle = guidance.vertVelKp * vertVelError +
                          guidance.vertVelKi * guidance.vertVelIntegral;

    // 重力补偿（随高度变化）
    double earthRadius = r - altitude;
    double gravityRatio = (earthRadius * earthRadius) / (r * r);
    double gravityCompensation = 0.45 * gravityRatio;

    // 总油门
    double throttle = baseThrottle + gravityCompensation;

    // 限制油门范围
    throttle = constrainDouble(throttle, 0.15, 0.6);

    // 每30帧输出一次着陆状态
    if ((int)(System.currentTimeMillis() / 500) % 30 == 0) {
      println("[Recovery] LANDING_BURN: alt=" + String.format("%.1f", altitude*1000) + "m" +
              ", heightAboveSurface=" + String.format("%.1f", heightAboveSurface*1000) + "m" +
              ", vertVel=" + String.format("%.1f", verticalVel*1000) + "m/s" +
              ", targetVel=" + String.format("%.1f", targetVerticalVel*1000) + "m/s" +
              ", throttle=" + String.format("%.2f", throttle));
    }

    spacecraft.autoControl.targetThrottle = (float)throttle;
    if (spacecraft.mainEngine != null) {
      spacecraft.mainEngine.setThrottle((float)throttle);
    }

    // ========== 触地检测 ==========
    if (altitude <= touchdownAltitude) {
      // 触地（火箭底部碰到地表）
      println("[Recovery] ========== TOUCHDOWN! ==========");
      println("[Recovery] Touchdown vertical velocity: " + String.format("%.2f", verticalVel*1000) + " m/s");

      stage = RecoveryStage.LANDED;
      spacecraft.autoControl.targetThrottle = 0.0f;
      if (spacecraft.mainEngine != null) {
        spacecraft.mainEngine.shutdown();
      }
      spacecraft.state = SpacecraftState.LANDED;
      spacecraft.isFixedToSurface = true; // 固定在表面

      // 立即校正位置，确保整个箭体在地表以上
      snapToSurface(spacecraft);

      statusText = "LANDING COMPLETE!";
      progress = 1.0;
    }
  }

  // === 校正火箭位置到地表以上 ===
  void snapToSurface(Spacecraft ship) {
    if (ship.referenceBody == null) return;

    Vector2 pos = ship.stateVector.position;
    double currentRadius = pos.magnitude();
    double targetRadius = ship.referenceBody.radius + Spacecraft.SHIP_LENGTH_KM * 0.5;

    if (currentRadius < targetRadius) {
      ship.stateVector.position = pos.normalized().mul(targetRadius);
      ship.stateVector.velocity = new Vector2(0, 0);
    }
  }

  // === 着陆状态 ===
  void updateLanded() {
    // 确保飞船被固定在表面
    if (!spacecraft.isFixedToSurface) {
      spacecraft.isFixedToSurface = true;
      spacecraft.state = SpacecraftState.LANDED;
    }

    // 保持关闭
    if (spacecraft.autoControl.targetThrottle > 0.001f) {
      spacecraft.autoControl.targetThrottle = 0.0f;
      spacecraft.autoControl.stop();
      if (spacecraft.mainEngine != null) {
        spacecraft.mainEngine.shutdown();
      }
    }
  }

  // === 状态查询方法 ===
  RecoveryStage getStage() {
    return stage;
  }

  String getStatusText() {
    return statusText;
  }

  double getProgress() {
    return progress;
  }

  boolean isActive() {
    return stage != RecoveryStage.IDLE && stage != RecoveryStage.LANDED && stage != RecoveryStage.ABORT;
  }

  // === 更新进度 ===
  void updateProgress(double timeSinceStart) {
    double alt = spacecraft.getAltitude();

    switch (stage) {
      case IDLE:
        progress = 0.0;
        break;

      case PREPARING: {
        // 基于剩余倒计时进度
        double remaining = deorbitBurnTargetTime - lastUpdateSimTime;
        double preparingProgress = 1.0 - constrainDouble(remaining / timeToDeorbitBurnAtStart, 0.0, 1.0);
        progress = 0.08 * preparingProgress;
        break;
      }

      case DEORBIT_BURN: {
        double burnProgress = 1.0 - (spacecraft.autoControl.burnTimeRemaining / deorbitBurnDuration);
        burnProgress = constrainDouble(burnProgress, 0.0, 1.0);
        progress = 0.08 + 0.07 * burnProgress;
        break;
      }

      case COAST_TO_ENTRY: {
        // 从初始高度下降到 120km
        double startAlt = 520.0; // 假设LEO高度
        double endAlt = 120.0;
        double coastProgress = (startAlt - alt) / (startAlt - endAlt);
        coastProgress = constrainDouble(coastProgress, 0.0, 1.0);
        progress = 0.15 + 0.15 * coastProgress;
        break;
      }

      case REENTRY_GUIDANCE: {
        // 从 120km 下降到 20km，使用非线性映射让进度更均匀
        double reentryProgress = (120.0 - alt) / (120.0 - 20.0);
        reentryProgress = constrainDouble(reentryProgress, 0.0, 1.0);
        reentryProgress = Math.sqrt(reentryProgress); // 让初始变化更明显
        progress = 0.30 + 0.25 * reentryProgress;
        break;
      }

      case GLIDE_PHASE: {
        // 从 20km 下降到 10km
        double glideProgress = (20.0 - alt) / (20.0 - 10.0);
        glideProgress = constrainDouble(glideProgress, 0.0, 1.0);
        progress = 0.55 + 0.20 * glideProgress;
        break;
      }

      case TURNAROUND_MANEUVER: {
        // 从 10km 下降到 5km，或者基于定向进度
        double turnProgress = (10.0 - alt) / (10.0 - 5.0);
        turnProgress = constrainDouble(turnProgress, 0.0, 1.0);
        // 也考虑定向进度
        if (spacecraft.autoControl.isOriented()) {
          turnProgress = Math.max(turnProgress, 0.8);
        }
        progress = 0.75 + 0.08 * turnProgress;
        break;
      }

      case HOVER_SLIDE: {
        // 从 5km 下降到 0.5km
        double hoverProgress = (5.0 - alt) / (5.0 - 0.5);
        hoverProgress = constrainDouble(hoverProgress, 0.0, 1.0);
        progress = 0.83 + 0.10 * hoverProgress;
        break;
      }

      case FINAL_DESCENT: {
        // 从 0.5km 下降到着陆燃烧高度 (~0.09km)
        double shipHalfHeight = Spacecraft.SHIP_LENGTH_KM * 0.5;
        double landingBurnAlt = 0.05 + shipHalfHeight;
        double descentProgress = (0.5 - alt) / (0.5 - landingBurnAlt);
        descentProgress = constrainDouble(descentProgress, 0.0, 1.0);
        progress = 0.93 + 0.05 * descentProgress;
        break;
      }

      case LANDING_BURN: {
        // 从着陆燃烧高度下降到触地
        double shipHalfHeight = Spacecraft.SHIP_LENGTH_KM * 0.5;
        double touchdownAlt = shipHalfHeight;
        double landingBurnStartAlt = 0.05 + shipHalfHeight;
        double landingProgress = (landingBurnStartAlt - alt) / (landingBurnStartAlt - touchdownAlt);
        landingProgress = constrainDouble(landingProgress, 0.0, 1.0);
        progress = 0.98 + 0.02 * landingProgress;
        break;
      }

      case LANDED:
        progress = 1.0;
        break;

      case ABORT:
        progress = 1.0;
        break;
    }
  }

  // === 检查任务是否完成 ===
  boolean isComplete() {
    return stage == RecoveryStage.LANDED || stage == RecoveryStage.ABORT;
  }

  // === 格式化时间 ===
  String formatTime(double seconds) {
    if (seconds < 60) {
      return String.format("%.1fs", seconds);
    } else if (seconds < 3600) {
      return String.format("%.1fm", seconds / 60);
    } else {
      return String.format("%.1fh", seconds / 3600);
    }
  }
}
