// ========== LAUNCH CONTROLLER ==========
// 发射控制器 - 作为 MissionExecutor 的辅助类
// 处理发射特有的逻辑：固定在发射场、倒计时、点火、上升剖面

class LaunchController {
  Spacecraft ship;
  LaunchSite site;
  CelestialBody earth;

  // 状态跟踪
  boolean isActive;
  double missionStartTime;

  // 脐带臂展开进度 (0.0 = 未展开, 1.0 = 完全展开)
  float umbilicalDeployProgress;

  // 上升剖面参数
  double pitchOverAltitude;   // 重力转向高度 (km)
  double targetOrbitAltitude; // 目标轨道高度 (km)

  // 制导系统
  FlightComputer flightComputer;
  double circBurnStartTime;   // 圆化燃烧开始时间
  double circBurnDuration;     // 圆化燃烧时长
  boolean apoapsisReached;      // 是否到达远地点
  double lastPeriAlt;           // 上次记录的近地点高度

  LaunchController() {
    this.ship = null;
    this.site = null;
    this.earth = null;
    this.isActive = false;
    this.missionStartTime = 0;
    this.pitchOverAltitude = 10.0;  // 10km 开始重力转向
    this.targetOrbitAltitude = LEO_ALTITUDE_KM;
    this.flightComputer = new FlightComputer();
    this.circBurnStartTime = 0;
    this.circBurnDuration = 0;
    this.apoapsisReached = false;
    this.umbilicalDeployProgress = 0.0f;
  }

  // ========== 初始化 ==========

  void init(Spacecraft ship, LaunchSite site, CelestialBody earth) {
    this.ship = ship;
    this.site = site;
    this.earth = earth;
    this.isActive = false;
  }

  // ========== 开始发射任务 ==========

  void startLaunch(double simTime) {
    if (ship == null || site == null) return;

    this.isActive = true;
    this.missionStartTime = simTime;
    this.apoapsisReached = false;
    this.circBurnStartTime = 0;
    this.circBurnDuration = 0;
    this.lastPeriAlt = -1.0;
    this.umbilicalDeployProgress = 0.0f;

    // 开始倒计时
    ship.launchState = LaunchState.COUNTDOWN;
    ship.countdownStartTime = simTime;
    ship.isFixedToSurface = true;

    // 设置初始姿态
    Vector2 launchDir = site.getLaunchDirection();
    ship.attitude = new Rotation2D(launchDir.angle());

    println("Launch countdown started");
  }

  // ========== 更新发射状态 ==========

  void update(double simTime, double simDt) {
    if (!isActive || ship == null) return;

    switch (ship.launchState) {
      case ON_PAD:
        updateOnPad(simTime, simDt);
        break;
      case COUNTDOWN:
        updateCountdown(simTime, simDt);
        break;
      case IGNITION:
        updateIgnition(simTime, simDt);
        break;
      case LAUNCHING:
        updateLaunching(simTime, simDt);
        break;
      case COAST:
        updateCoast(simTime, simDt);
        break;
      case CIRCULARIZING:
        updateCircularizing(simTime, simDt);
        break;
      case IN_ORBIT:
        updateInOrbit(simTime, simDt);
        break;
    }
  }

  // ========== 状态更新函数 ==========

  void updateOnPad(double simTime, double simDt) {
    // 在发射台等待 - 什么都不做
  }

  void updateCountdown(double simTime, double simDt) {
    double elapsed = simTime - ship.countdownStartTime;
    if (elapsed >= Spacecraft.COUNTDOWN_DURATION) {
      // 倒计时结束，进入点火状态
      ship.launchState = LaunchState.IGNITION;
      ship.ignitionStartTime = simTime;
      println("Ignition!");
    }
  }

  void updateIgnition(double simTime, double simDt) {
    double elapsed = simTime - ship.ignitionStartTime;

    // 点火期间设置姿态为垂直向上，但不点火
    Vector2 launchDir = site.getLaunchDirection();
    if (ship.autoControl != null) {
      ship.autoControl.setTargetDirection(launchDir);
      ship.autoControl.targetThrottle = 0.0f;
    }
    if (ship.mainEngine != null) {
      ship.mainEngine.setThrottle(0.0f);
    }

    // 点火后期开始展开脐带臂（从0到0.3）
    float ignProgress = (float)(elapsed / Spacecraft.IGNITION_DURATION);
    umbilicalDeployProgress = (float)constrainDouble(ignProgress * 0.3f, 0.0f, 0.3f);

    if (elapsed >= Spacecraft.IGNITION_DURATION) {
      // 点火结束，解除固定，开始发射
      ship.launchState = LaunchState.LAUNCHING;
      ship.launchStartTime = simTime;
      ship.isFixedToSurface = false;
      println("Liftoff!");
    }
  }

  void updateLaunching(double simTime, double simDt) {
    if (ship.referenceBody == null) return;

    double burnTime = simTime - ship.launchStartTime;

    // 上升阶段继续展开脐带臂（从0.3到1.0，用2秒完成）
    float deployTime = 2.0f;
    if (burnTime <= deployTime) {
      umbilicalDeployProgress = 0.3f + 0.7f * (float)(burnTime / deployTime);
    } else {
      umbilicalDeployProgress = 1.0f;
    }

    // 确保autoControl是激活的
    if (ship.autoControl != null) {
      ship.autoControl.isActive = true;
    }

    // 检查是否到达目标远地点
    double currentApo = flightComputer.apoapsisAltitude(
      ship.stateVector.position,
      ship.stateVector.velocity,
      EARTH_RADIUS_KM,
      GM_EARTH
    );

    boolean shouldThrust = true;

    if (currentApo >= targetOrbitAltitude) {
      shouldThrust = false;
      apoapsisReached = true;
    }

    // 计算推力方向
    if (shouldThrust) {
      Vector2 thrustDir = flightComputer.ascentThrustDirection(
        ship.stateVector.position,
        burnTime,
        targetOrbitAltitude
      );
      if (ship.autoControl != null) {
        ship.autoControl.setTargetDirection(thrustDir);
        ship.autoControl.targetThrottle = 1.0f;
      }
      if (ship.mainEngine != null) {
        ship.mainEngine.setThrottle(1.0f);
      }
    } else {
      // 关闭引擎
      if (ship.autoControl != null) {
        ship.autoControl.targetThrottle = 0.0f;
      }
      if (ship.mainEngine != null) {
        ship.mainEngine.setThrottle(0.0f);
      }
    }

    // 检查是否进入滑行阶段
    if (!shouldThrust && apoapsisReached) {
      ship.launchState = LaunchState.COAST;
      println("Coasting to apoapsis");
    }
  }

  void updateCoast(double simTime, double simDt) {
    if (ship.referenceBody == null) return;

    // 关闭引擎
    if (ship.autoControl != null) {
      ship.autoControl.targetThrottle = 0.0f;
    }
    if (ship.mainEngine != null) {
      ship.mainEngine.setThrottle(0.0f);
    }

    // 计算到达远地点的时间
    double tta = flightComputer.timeToApoapsis(
      ship.stateVector.position,
      ship.stateVector.velocity,
      GM_EARTH
    );

    // 到达远地点（tta == -1 表示已经过了远地点）
    if (tta <= 0 || tta == -1) {
      // 计算圆化燃烧参数
      double[] circParams = flightComputer.computeCircularizationBurn(
        ship.stateVector.position,
        ship.stateVector.velocity,
        targetOrbitAltitude,
        EARTH_RADIUS_KM,
        GM_EARTH
      );
      circBurnDuration = circParams[1];
      circBurnStartTime = simTime;
      ship.launchState = LaunchState.CIRCULARIZING;
      println("Starting circularization burn, duration: " + circBurnDuration + " s");
    }
  }

  void updateCircularizing(double simTime, double simDt) {
    if (ship.referenceBody == null) return;

    // 计算近地点和远地点高度
    double periAlt = flightComputer.perigeeAltitude(
      ship.stateVector.position,
      ship.stateVector.velocity,
      EARTH_RADIUS_KM,
      GM_EARTH
    );
    double apoAlt = flightComputer.apoapsisAltitude(
      ship.stateVector.position,
      ship.stateVector.velocity,
      EARTH_RADIUS_KM,
      GM_EARTH
    );

    // 计算接近程度：0=刚开始，1=接近完成
    double progress = Math.min(1.0, periAlt / (targetOrbitAltitude * 0.99));

    // 异常保护检查
    boolean abort = false;
    String abortReason = "";

    // 1. 远地点过高保护
    if (apoAlt > targetOrbitAltitude * 1.15) {
      abort = true;
      abortReason = "apoapsis too high";
    }

    // 2. 近地点不升反降保护（已过一段时间后）
    double elapsedBurnTime = simTime - circBurnStartTime;
    if (lastPeriAlt > 0 && elapsedBurnTime > circBurnDuration * 0.5 && periAlt < lastPeriAlt * 0.98) {
      abort = true;
      abortReason = "periapsis decreasing";
    }

    // 更新上次记录的近地点
    lastPeriAlt = periAlt;

    // 始终用PEG制导
    Vector2 thrustDir = flightComputer.pegGuidance(
      ship.stateVector.position,
      ship.stateVector.velocity,
      LEO_RADIUS_KM,
      GM_EARTH
    );

    // 计算节流阀：接近目标时降低推力提高精度
    float throttle = 1.0f;
    if (progress >= 0.85) {
      throttle = 0.7f;
    }
    if (progress >= 0.95) {
      throttle = 0.3f;
    }
    if (progress >= 0.98) {
      throttle = 0.2f;
    }

    // 检查是否完成圆化或异常中止
    boolean timeUp = elapsedBurnTime >= circBurnDuration * 2.0;
    boolean periGood = periAlt >= targetOrbitAltitude * 0.975;
    boolean apoGood = apoAlt <= targetOrbitAltitude * 1.05;
    boolean orbitGood = periGood && apoGood;

    if (orbitGood || timeUp || abort) {
      // 完成圆化或异常中止
      shutdownEngine();
      ship.launchState = LaunchState.IN_ORBIT;
      if (abort) {
        println("Orbit insertion ABORTED (" + abortReason + "), periapsis: " + periAlt + " km, apoapsis: " + apoAlt + " km");
      } else {
        println("Orbit insertion complete, periapsis: " + periAlt + " km, apoapsis: " + apoAlt + " km");
      }
      return;
    }

    // 使用制导方向点火
    if (ship.autoControl != null) {
      ship.autoControl.setTargetDirection(thrustDir);
      ship.autoControl.targetThrottle = throttle;
    }
    if (ship.mainEngine != null) {
      ship.mainEngine.setThrottle(throttle);
    }
  }

  void updateInOrbit(double simTime, double simDt) {
    if (isActive) {
      isActive = false;
      shutdownEngine();
      println("Launch mission complete!");
    }
  }

  void shutdownEngine() {
    if (ship.mainEngine != null) {
      ship.mainEngine.setThrottle(0.0f);
    }
    if (ship.autoControl != null) {
      ship.autoControl.targetThrottle = 0.0f;
    }
  }

  // ========== 辅助函数 ==========

  double getCurrentAltitude() {
    if (ship.referenceBody == null) return 0;
    double r = ship.stateVector.position.magnitude();
    return r - EARTH_RADIUS_KM;
  }

  void performGravityTurn(double altitude) {
    // 简单的重力转向：根据高度逐渐转向
    // 目标是在入轨时达到水平方向

    double progress = (altitude - pitchOverAltitude) / (targetOrbitAltitude - pitchOverAltitude);
    progress = constrainDouble(progress, 0, 1);

    // 从垂直(0)转向水平方向（+PI/2 = 逆时针顺行方向）
    Vector2 radialOut = ship.getRadialOut();

    // 插值计算目标方向：从径向向外转向顺行方向（+PI/2 = 逆时针）
    double targetAngle = radialOut.angle() + progress * Math.PI / 2;
    Vector2 targetDir = new Vector2(Math.cos(targetAngle), Math.sin(targetAngle));

    if (ship.autoControl != null) {
      ship.autoControl.setTargetDirection(targetDir);
    }
  }

  // ========== 检查任务完成 ==========

  boolean isLaunchComplete() {
    return ship.launchState == LaunchState.IN_ORBIT;
  }

  // ========== 获取状态文本 ==========

  String getStatusText(double simTime) {
    switch (ship.launchState) {
      case ON_PAD:
        return "On Launch Pad - Ready";
      case COUNTDOWN:
        double countdownLeft = Spacecraft.COUNTDOWN_DURATION - (simTime - ship.countdownStartTime);
        return String.format("T-%.1f", countdownLeft);
      case IGNITION:
        return "Ignition!";
      case LAUNCHING:
        double alt = getCurrentAltitude();
        return String.format("Launching - Altitude: %.1f km", alt);
      case CIRCULARIZING:
        return "Circularizing Orbit";
      case IN_ORBIT:
        return "In Orbit - Launch Complete";
    }
    return "";
  }

  // 获取脐带臂展开进度 (0.0 = 未展开, 1.0 = 完全展开)
  float getUmbilicalDeployProgress() {
    return umbilicalDeployProgress;
  }

  // 重置脐带臂状态（返回发射台时调用）
  void resetUmbilical() {
    umbilicalDeployProgress = 0.0f;
  }
}
