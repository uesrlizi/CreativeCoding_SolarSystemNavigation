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
    println("[RecoveryController] timeToDeorbitBurn: " + timeToDeorbitBurn + " seconds");

    // 计算目标着陆位置
    double siteAngle = launchSite.baseAngle;
    double r = earth.radius;
    targetLandingPosition = new Vector2(r * Math.cos(siteAngle), r * Math.sin(siteAngle));

    // 设置离轨燃烧持续时间
    deorbitBurnDuration = 6.0; // 秒

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
    if (spacecraft == null) return;

    double timeSinceStart = currentSimTime - missionStartTime;

    switch (stage) {
      case IDLE:
        break;

      case PREPARING:
        updatePreparing(timeSinceStart, currentSimTime);
        break;

      case DEORBIT_BURN:
        updateDeorbitBurn(tickDt, timeSinceStart);
        break;

      case COAST_TO_ENTRY:
        updateCoastToEntry(tickDt);
        break;

      case REENTRY_GUIDANCE:
        updateReentryGuidance(tickDt);
        break;

      case GLIDE_PHASE:
        updateGlidePhase(tickDt);
        break;

      case TURNAROUND_MANEUVER:
        updateTurnaroundManeuver(tickDt);
        break;

      case HOVER_SLIDE:
        updateHoverSlide(tickDt);
        break;

      case FINAL_DESCENT:
        updateFinalDescent(tickDt);
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
    timeToDeorbitBurn -= currentSimTime - (missionStartTime + timeSinceStart - timeToDeorbitBurn); // 修正时间

    if (timeToDeorbitBurn <= 3.0 && timeToDeorbitBurn > 0) {
      // 开始定向
      Vector2 retrograde = spacecraft.getRetrograde();
      spacecraft.autoControl.setTargetDirection(retrograde);
    }

    if (timeToDeorbitBurn <= 0) {
      // 开始离轨燃烧
      stage = RecoveryStage.DEORBIT_BURN;
      stageEntryTime = currentSimTime;
      deorbitBurnStartTime = currentSimTime;

      // 设置燃烧
      spacecraft.autoControl.setBurn(1.0f, deorbitBurnDuration);
      Vector2 retrograde = spacecraft.getRetrograde();
      spacecraft.autoControl.setTargetDirection(retrograde);
      spacecraft.enterOffRails();

      statusText = "Deorbit burn in progress";
    } else {
      statusText = "Preparing for deorbit in " + formatTime(timeToDeorbitBurn);
    }
  }

  // === 离轨燃烧阶段 ===
  void updateDeorbitBurn(double tickDt, double timeSinceStart) {
    if (!spacecraft.autoControl.isBurning) {
      // 燃烧完成
      stage = RecoveryStage.COAST_TO_ENTRY;
      stageEntryTime = missionStartTime + timeSinceStart;

      // 关闭引擎
      spacecraft.setEngineThrottle(0.0f);

      statusText = "Coasting to entry interface";
    } else {
      statusText = "Deorbit burn: " + formatTime(spacecraft.autoControl.burnTimeRemaining) + " remaining";
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
    } else {
      // 保持指向速度方向
      Vector2 prograde = spacecraft.getPrograde();
      spacecraft.autoControl.setTargetDirection(prograde);
      statusText = "Coasting to entry: " + (int)altitude + " km";
    }
  }

  // === 再入制导阶段 ===
  void updateReentryGuidance(double tickDt) {
    double altitude = spacecraft.getAltitude();
    double speed = spacecraft.stateVector.velocity.magnitude();
    double mach = earth.atmosphere.getMachNumber(speed, altitude);

    // 更新阻力系数
    spacecraft.updateDragCoefficient(mach, altitude);

    // 获取制导输出
    GuidanceOutput guidanceOut = guidance.reentryGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity,
      earth.GM,
      spacecraft.gLoad
    );

    // 设置攻角
    spacecraft.setAngleOfAttack(guidanceOut.targetAngleOfAttack);

    // 保持大致方向
    Vector2 prograde = spacecraft.getPrograde();
    spacecraft.autoControl.setTargetDirection(prograde);

    if (altitude <= 20.0) {
      stage = RecoveryStage.GLIDE_PHASE;
      statusText = "Glide phase - Navigating to landing site";
    } else {
      statusText = "Reentry: " + (int)altitude + " km, Mach " + String.format("%.1f", mach) + ", G: " + String.format("%.1f", spacecraft.gLoad);
    }
  }

  // === 滑翔阶段 ===
  void updateGlidePhase(double tickDt) {
    double altitude = spacecraft.getAltitude();

    // 滑翔制导
    GuidanceOutput guidanceOut = guidance.glideGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity
    );

    spacecraft.setAngleOfAttack(guidanceOut.targetAngleOfAttack);

    // 保持大致朝向目标
    Vector2 toTarget = targetLandingPosition.sub(spacecraft.stateVector.position).normalized();
    spacecraft.autoControl.setTargetDirection(toTarget);

    if (altitude <= 10.0) {
      stage = RecoveryStage.TURNAROUND_MANEUVER;
      statusText = "Performing turnaround maneuver";
    } else {
      statusText = "Gliding: " + (int)altitude + " km to go";
    }
  }

  // === 转向机动阶段 ===
  void updateTurnaroundManeuver(double tickDt) {
    double altitude = spacecraft.getAltitude();

    // 转向径向向内（准备动力着陆）
    Vector2 radialIn = spacecraft.getRadialIn();
    spacecraft.autoControl.setTargetDirection(radialIn);

    if (altitude <= 5.0 || spacecraft.autoControl.isOriented()) {
      stage = RecoveryStage.HOVER_SLIDE;
      spacecraft.deployLandingLegs();
      statusText = "Approaching - Hover and slide";
    } else {
      statusText = "Turning for landing";
    }
  }

  // === 悬停平移阶段 ===
  void updateHoverSlide(double tickDt) {
    double altitude = spacecraft.getAltitude();

    // 着陆制导
    LandingGuidanceOutput landingOut = guidance.propulsiveLandingGuidance(
      spacecraft.stateVector.position,
      spacecraft.stateVector.velocity,
      targetLandingPosition,
      altitude,
      earth.GM
    );

    spacecraft.autoControl.setTargetDirection(landingOut.targetDirection);
    spacecraft.autoControl.targetThrottle = landingOut.targetThrottle;
    if (spacecraft.mainEngine != null) {
      spacecraft.mainEngine.setThrottle(landingOut.targetThrottle);
    }

    if (altitude <= 0.5) {
      stage = RecoveryStage.FINAL_DESCENT;
      statusText = "Final descent";
    } else {
      statusText = "Approaching: " + String.format("%.1f", altitude * 1000) + " m";
    }
  }

  // === 最终下降阶段 ===
  void updateFinalDescent(double tickDt) {
    double altitude = spacecraft.getAltitude();

    // 直接向下
    Vector2 radialIn = spacecraft.getRadialIn();
    spacecraft.autoControl.setTargetDirection(radialIn);
    spacecraft.autoControl.targetThrottle = 0.6f;
    if (spacecraft.mainEngine != null) {
      spacecraft.mainEngine.setThrottle(0.6f);
    }

    if (altitude <= 0.05) {
      stage = RecoveryStage.LANDING_BURN;
      statusText = "Touchdown imminent";
    } else {
      statusText = "Final descent: " + String.format("%.0f", altitude * 1000) + " m";
    }
  }

  // === 着陆燃烧阶段 ===
  void updateLandingBurn(double tickDt) {
    double altitude = spacecraft.getAltitude();
    double verticalVel = spacecraft.stateVector.position.dot(spacecraft.stateVector.velocity) / spacecraft.stateVector.position.magnitude();

    // 减小油门，触地关机
    float throttle = 0.3f;
    if (verticalVel > -0.005) { // 下降速度较慢
      throttle = 0.2f;
    }

    spacecraft.autoControl.targetThrottle = throttle;
    if (spacecraft.mainEngine != null) {
      spacecraft.mainEngine.setThrottle(throttle);
    }

    if (altitude <= 0.001) {
      // 触地
      stage = RecoveryStage.LANDED;
      spacecraft.autoControl.targetThrottle = 0.0f;
      if (spacecraft.mainEngine != null) {
        spacecraft.mainEngine.shutdown();
      }
      spacecraft.state = SpacecraftState.LANDED;
      statusText = "LANDING COMPLETE!";
      progress = 1.0;
    }
  }

  // === 着陆状态 ===
  void updateLanded() {
    // 保持关闭
    if (spacecraft.autoControl.targetThrottle > 0.001f) {
      spacecraft.autoControl.targetThrottle = 0.0f;
      spacecraft.autoControl.stop();
      if (spacecraft.mainEngine != null) {
        spacecraft.mainEngine.shutdown();
      }
    }
  }

  // === 更新进度 ===
  void updateProgress(double timeSinceStart) {
    switch (stage) {
      case IDLE:
        progress = 0.0;
        break;
      case PREPARING:
        progress = 0.05;
        break;
      case DEORBIT_BURN:
        progress = 0.1 + 0.1 * (1.0 - spacecraft.autoControl.burnTimeRemaining / deorbitBurnDuration);
        break;
      case COAST_TO_ENTRY:
        progress = 0.2 + 0.1 * Math.min(1.0, (120.0 - spacecraft.getAltitude()) / 400.0);
        break;
      case REENTRY_GUIDANCE:
        progress = 0.3 + 0.2 * Math.min(1.0, (80.0 - spacecraft.getAltitude()) / 80.0);
        break;
      case GLIDE_PHASE:
        progress = 0.5 + 0.15 * Math.min(1.0, (20.0 - spacecraft.getAltitude()) / 20.0);
        break;
      case TURNAROUND_MANEUVER:
        progress = 0.65 + 0.1 * Math.min(1.0, (10.0 - spacecraft.getAltitude()) / 10.0);
        break;
      case HOVER_SLIDE:
        progress = 0.75 + 0.1 * Math.min(1.0, (5.0 - spacecraft.getAltitude()) / 5.0);
        break;
      case FINAL_DESCENT:
        progress = 0.85 + 0.1 * Math.min(1.0, (0.5 - spacecraft.getAltitude()) / 0.5);
        break;
      case LANDING_BURN:
        progress = 0.95 + 0.05 * Math.min(1.0, (0.05 - spacecraft.getAltitude()) / 0.05);
        break;
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
