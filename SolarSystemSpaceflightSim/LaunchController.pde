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

  // 上升剖面参数
  double pitchOverAltitude;   // 重力转向高度 (km)
  double targetOrbitAltitude; // 目标轨道高度 (km)

  LaunchController() {
    this.ship = null;
    this.site = null;
    this.earth = null;
    this.isActive = false;
    this.missionStartTime = 0;
    this.pitchOverAltitude = 10.0;  // 10km 开始重力转向
    this.targetOrbitAltitude = LEO_ALTITUDE_KM;
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

    // 点火期间启动引擎但保持固定
    if (ship.mainEngine != null) {
      ship.mainEngine.setThrottle(1.0f);
    }
    if (ship.autoControl != null) {
      ship.autoControl.targetThrottle = 1.0f;
    }

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

    // 计算当前高度
    double altitude = getCurrentAltitude();

    // 重力转向逻辑
    if (altitude > pitchOverAltitude) {
      // 开始重力转向 - 逐渐转向水平
      performGravityTurn(altitude);
    } else {
      // 保持垂直向上
      Vector2 launchDir = site.getLaunchDirection();
      if (ship.autoControl != null) {
        ship.autoControl.setTargetDirection(launchDir);
      }
    }

    // 检查是否达到远地点（入轨点）
    if (ship.orbit != null) {
      double apoapsisAlt = ship.orbit.getApoapsisAltitude();
      if (apoapsisAlt >= targetOrbitAltitude * 0.9) {
        // 关闭引擎，准备圆化
        if (ship.mainEngine != null) {
          ship.mainEngine.setThrottle(0.0f);
        }
        if (ship.autoControl != null) {
          ship.autoControl.targetThrottle = 0.0f;
        }
        ship.launchState = LaunchState.CIRCULARIZING;
        println("Approaching orbit, preparing for circularization burn");
      }
    }
  }

  void updateCircularizing(double simTime, double simDt) {
    if (ship.orbit == null) return;

    double periapsisAlt = ship.orbit.getPeriapsisAltitude();
    double apoapsisAlt = ship.orbit.getApoapsisAltitude();
    double currentAlt = getCurrentAltitude();

    // If orbit is already good enough, complete the mission
    if (periapsisAlt >= targetOrbitAltitude * 0.8 && ship.orbit.e < 0.05) {
      shutdownEngine();
      ship.launchState = LaunchState.IN_ORBIT;
      return;
    }

    // Burn prograde near apoapsis to raise periapsis (circularization burn)
    boolean nearApoapsis = Math.abs(currentAlt - apoapsisAlt) < 15.0;
    boolean periapsisTooLow = periapsisAlt < targetOrbitAltitude * 0.85;

    if (nearApoapsis && periapsisTooLow) {
      Vector2 prograde = ship.getPrograde();
      if (ship.autoControl != null) {
        ship.autoControl.setTargetDirection(prograde);
        ship.autoControl.targetThrottle = 1.0f;
      }
      if (ship.mainEngine != null) {
        ship.mainEngine.setThrottle(1.0f);
      }
    } else if (!periapsisTooLow) {
      // Periapsis is high enough, complete
      shutdownEngine();
      ship.launchState = LaunchState.IN_ORBIT;
    } else {
      // Coasting, waiting for apoapsis
      shutdownEngine();
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
}
