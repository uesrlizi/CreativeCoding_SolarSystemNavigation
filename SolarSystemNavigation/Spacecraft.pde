// ============================================================
//  Spacecraft - 纯状态容器
//  物理、制导和轨道传播委托给外部系统
// ============================================================

class Spacecraft {
  // 基本标识
  String name;
  color col;
  color trailColor;

  // 日心轨道根数（用于日心轨道传播）
  double a, e, i, omega, w, M0, period;
  double currentNu;

  // 当前中心天体 - null 表示日心
  CelestialBody currentCentralBody;

  // 位置和速度向量 - 根据 currentCentralBody 解释
  double[] pos;    // [x, y, z] km
  double[] vel;    // [vx, vy, vz] km/s

  // 兼容旧接口的字段名称（内部统一使用 pos/vel）
  double[] earthRelPos;  // 别名，指向 pos
  double[] earthRelVel;  // 别名，指向 vel
  CelestialBody earthRef;  // 别名，指向 currentCentralBody
  boolean earthRelative;  // 兼容字段：currentCentralBody != null

  // 轨道角度和时间（用于轨道模式）
  double launchPadAngle;
  double launchAltitude;
  double orbitAngle;       // 别名
  double earthOrbitAngle;  // 别名
  double orbitStartTime;

  // 兼容性：参考系
  ReferenceFrame frame;

  // 任务状态
  ShipState state;
  double launchStartTime;
  double transferStartTime;
  double countdownStartTime;
  double ignitionStartTime;

  // 推力/燃烧跟踪
  boolean thrustActive;
  double tmiTargetDV;
  double tmiAccumulatedDV;
  double toiTargetDV;
  double toiAccumulatedDV;

  // 上次物理更新时间
  double lastUpdateTime;

  // 仅显示用的角动力学（纯装饰）
  double displayAngle;
  double angularVelocity;
  double angularAcceleration;
  static final double MAX_ANGULAR_VELOCITY = 3.0;
  static final double MAX_ANGULAR_ACCEL = 8.0;
  static final double ANGLE_KP = 10.0;
  static final double ANGLE_KD = 6.0;
  static final double COUNTDOWN_DURATION = 10.0;
  static final double IGNITION_DURATION = 2.0;
  static final double SHIP_LENGTH_KM = 0.08;
  static final double SHIP_WIDTH_KM = 0.006;

  // 世界位置（日心坐标）缓存
  double px, py, pz;

  // ============================================================
  //  构造函数
  // ============================================================

  Spacecraft(double a, double e, double i,
             double omega, double w, double M0, double period, color col) {
    this.name = "Spacecraft";
    this.a = a; this.e = e; this.i = i;
    this.omega = omega; this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = period;
    this.col = col;
    this.trailColor = col;

    // 初始化状态向量
    this.pos = new double[3];
    this.vel = new double[3];

    // 兼容性别名
    this.earthRelPos = this.pos;
    this.earthRelVel = this.vel;

    this.state = ShipState.IDLE;
    this.launchStartTime = 0;
    this.transferStartTime = 0;
    this.countdownStartTime = 0;
    this.ignitionStartTime = 0;

    this.currentCentralBody = null;
    this.earthRef = null;
    this.earthRelative = false;

    this.launchPadAngle = 0;
    this.launchAltitude = 0;
    this.orbitAngle = 0;
    this.earthOrbitAngle = 0;
    this.orbitStartTime = 0;

    this.displayAngle = 0;
    this.angularVelocity = 0;
    this.angularAcceleration = 0;

    this.px = 0;
    this.py = 0;
    this.pz = 0;
  }

  // ============================================================
  //  主更新调度器
  // ============================================================

  void update(double simTime) {
    double simDt = simTime - lastUpdateTime;
    if (simDt <= 0) simDt = 1.0 / 60.0;
    if (simDt > 3600) simDt = 3600;
    lastUpdateTime = simTime;

    // 根据当前中心天体和状态选择更新模式
    if (currentCentralBody != null) {
      updateBodyRelative(simTime, simDt);
    } else {
      updateHeliocentric(simTime, simDt);
    }

    // 更新显示角度
    updateDisplayAngleSmooth(simTime, simDt);
  }

  // ============================================================
  //  中心天体相对模式更新
  // ============================================================

  void updateBodyRelative(double simTime, double simDt) {
    if (state == ShipState.LAUNCHING || state == ShipState.CIRCULARIZING) {
      // 制导物理模式 - 委托给 GuidanceSystem
      if (guidanceSystem != null) {
        guidanceSystem.update(this, simDt, simTime);
      }
      updateDerivedValues();
    } else if (state == ShipState.ORBIT) {
      // 解析轨道模式 - 使用 OrbitPropagator
      double orbitElapsed = simTime - orbitStartTime;
      double angVel = Math.sqrt(MissionPlanner.GM_EARTH / Math.pow(MissionPlanner.LEO_RADIUS_KM, 3));
      orbitAngle = launchPadAngle + angVel * orbitElapsed;
      earthOrbitAngle = orbitAngle;  // 兼容性

      orbitPropagator.propagateCircularOrbit(
        pos, vel,
        currentCentralBody, orbitAngle,
        MissionPlanner.LEO_RADIUS_KM,
        MissionPlanner.GM_EARTH);
      launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;
    }

    // 更新世界位置
    if (currentCentralBody != null) {
      px = currentCentralBody.px + pos[0];
      py = currentCentralBody.py + pos[1];
      pz = currentCentralBody.pz + pos[2];
    }
  }

  // ============================================================
  //  日心模式更新
  // ============================================================

  void updateHeliocentric(double simTime, double simDt) {
    // 使用开普勒轨道传播
    orbitPropagator.propagateHeliocentric(this, simTime);
  }

  // ============================================================
  //  辅助：更新派生值
  // ============================================================

  void updateDerivedValues() {
    if (currentCentralBody != null) {
      double rx = pos[0], ry = pos[1];
      double r = Math.sqrt(rx * rx + ry * ry);
      launchAltitude = r - MissionPlanner.EARTH_RADIUS_KM;
      orbitAngle = Math.atan2(ry, rx);
      earthOrbitAngle = orbitAngle;  // 兼容性
    }
  }

  // ============================================================
  //  完成轨道插入 - 过渡到稳定轨道
  // ============================================================

  void finalizeOrbitInsertion(double simTime) {
    double rx = pos[0], ry = pos[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double radX = rx / r, radY = ry / r;
    double tanX = -ry / r, tanY = rx / r;

    double circSpeed = Math.sqrt(MissionPlanner.GM_EARTH / MissionPlanner.LEO_RADIUS_KM);
    vel[0] = tanX * circSpeed;
    vel[1] = tanY * circSpeed;
    vel[2] = 0;

    pos[0] = MissionPlanner.LEO_RADIUS_KM * radX;
    pos[1] = MissionPlanner.LEO_RADIUS_KM * radY;
    pos[2] = 0;

    launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;
    launchPadAngle = Math.atan2(pos[1], pos[0]);
    orbitAngle = launchPadAngle;
    earthOrbitAngle = orbitAngle;
    orbitStartTime = simTime;
    thrustActive = false;
    state = ShipState.ORBIT;

    dbgLog("ORBIT INSERTED: finalizing orbit");
  }

  // ============================================================
  //  更新显示角度（平滑版本）
  // ============================================================

  void updateDisplayAngleSmooth(double simTime, double simDt) {
    double targetAngle = computeTargetWorldAngle(simTime);
    double remainingDt = simDt;
    double maxSubStep = 1.0 / 60.0;

    while (remainingDt > 0) {
      double dt = Math.min(remainingDt, maxSubStep);
      updateDisplayAngleStep(targetAngle, dt);
      remainingDt -= dt;
    }
  }

  // ============================================================
  //  计算目标世界角度
  // ============================================================

  double computeTargetWorldAngle(double simTime) {
    if (guidanceSystem != null) {
      return guidanceSystem.computeTargetDisplayAngle(this, simTime);
    }
    // 回退到简单实现
    if (currentCentralBody != null) {
      return orbitAngle + PI / 2.0;
    } else {
      return Math.atan2(vel[1], vel[0]);
    }
  }

  // ============================================================
  //  显示角度单步更新
  // ============================================================

  void updateDisplayAngleStep(double targetAngle, double dt) {
    if (dt <= 0 || dt > 0.5) return;
    double error = angleDifference(targetAngle, displayAngle);
    double desiredAccel = error * ANGLE_KP - angularVelocity * ANGLE_KD;
    angularAcceleration = clamp(desiredAccel, -MAX_ANGULAR_ACCEL, MAX_ANGULAR_ACCEL);
    angularVelocity += angularAcceleration * dt;
    angularVelocity = clamp(angularVelocity, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY);
    displayAngle += angularVelocity * dt;
    displayAngle = normalizeAngle(displayAngle);
  }

  // ============================================================
  //  数学辅助函数
  // ============================================================

  double clamp(double v, double min, double max) {
    return Math.max(min, Math.min(max, v));
  }

  double normalizeAngle(double a) {
    return ((a % (2.0 * PI)) + 2.0 * PI) % (2.0 * PI);
  }

  double angleDifference(double target, double current) {
    return ((target - current + 3.0 * PI) % (2.0 * PI)) - PI;
  }

  // ============================================================
  //  向后兼容的辅助方法
  // ============================================================

  double[] getOsculatingOrbitalParams() {
    if (flightComputer != null) {
      return flightComputer.osculatingParams(
        pos[0], pos[1],
        vel[0], vel[1],
        MissionPlanner.GM_EARTH);
    }
    return new double[]{0, 0, 0, 0};
  }

  double computeApoapsis() {
    if (flightComputer != null) {
      return flightComputer.apoapsisAltitude(
        pos[0], pos[1],
        vel[0], vel[1],
        MissionPlanner.EARTH_RADIUS_KM,
        MissionPlanner.GM_EARTH);
    }
    return 0;
  }

  double computePerigee() {
    if (flightComputer != null) {
      return flightComputer.perigeeAltitude(
        pos[0], pos[1],
        vel[0], vel[1],
        MissionPlanner.EARTH_RADIUS_KM,
        MissionPlanner.GM_EARTH);
    }
    return 0;
  }

  double timeToApoapsis() {
    if (flightComputer != null) {
      return flightComputer.timeToApoapsis(
        pos[0], pos[1],
        vel[0], vel[1],
        MissionPlanner.GM_EARTH);
    }
    return 0;
  }
}

// ============================================================
//  SpacecraftForceModel - 力模型实现
//  计算重力 + 推力 + 阻力
// ============================================================

class SpacecraftForceModel extends ForceModel {
  // 通过参数接收状态，不再持有 Spacecraft 引用
  double[] currentPos;
  double[] currentVel;
  boolean currentThrustActive;
  ShipState currentState;
  CelestialBody currentCentralBody;
  double currentSimTime;
  double currentLaunchStartTime;

  // 临时数组
  private double[] tempDrag;

  SpacecraftForceModel() {
    tempDrag = new double[2];
    reset();
  }

  void reset() {
    currentPos = null;
    currentVel = null;
    currentThrustActive = false;
    currentState = ShipState.IDLE;
    currentCentralBody = null;
    currentSimTime = 0;
    currentLaunchStartTime = 0;
  }

  // 设置当前状态（在积分前调用）
  void setState(double[] pos, double[] vel, boolean thrustActive,
                ShipState state, CelestialBody centralBody,
                double simTime, double launchStartTime) {
    this.currentPos = pos;
    this.currentVel = vel;
    this.currentThrustActive = thrustActive;
    this.currentState = state;
    this.currentCentralBody = centralBody;
    this.currentSimTime = simTime;
    this.currentLaunchStartTime = launchStartTime;
  }

  void computeForce(double[] pos, double[] vel, double[] accelOut) {
    computeForce(pos, vel, accelOut, currentThrustActive);
  }

  void computeForce(double[] pos, double[] vel, double[] accelOut, boolean useThrust) {
    double rx = pos[0], ry = pos[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    // 确定 GM
    double GM = MissionPlanner.GM_EARTH;
    if (currentCentralBody != null && currentCentralBody.name.equals("Earth")) {
      GM = MissionPlanner.GM_EARTH;
    }

    // 重力
    double gMag = GM / (r * r);
    accelOut[0] = -gMag * rx / r;
    accelOut[1] = -gMag * ry / r;
    accelOut[2] = 0;

    // 推力
    if (useThrust) {
      double[] thrustDir = getThrustDirection(pos, vel);
      accelOut[0] += FlightComputer.THRUST_ACCEL * thrustDir[0];
      accelOut[1] += FlightComputer.THRUST_ACCEL * thrustDir[1];
    }

    // 大气阻力
    if (atmosphereModel != null && currentCentralBody != null) {
      atmosphereModel.dragAcceleration(pos, vel, currentCentralBody, tempDrag);
      accelOut[0] += tempDrag[0];
      accelOut[1] += tempDrag[1];
    }
  }

  double[] getThrustDirection(double[] pos, double[] vel) {
    double rx = pos[0], ry = pos[1];
    double vx = vel[0], vy = vel[1];

    if (currentState == ShipState.LAUNCHING) {
      double burnTime = currentSimTime - currentLaunchStartTime;
      double angle = flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
      return new double[]{Math.cos(angle), Math.sin(angle)};
    } else if (currentState == ShipState.CIRCULARIZING) {
      double[] peg = flightComputer.pegGuidance(rx, ry, vx, vy, MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);
      return new double[]{Math.cos(peg[1]), Math.sin(peg[1])};
    } else if (currentState == ShipState.TMI_BURN || currentState == ShipState.TOI_BURN) {
      return flightComputer.tangentialThrustDirection(vel, true);
    }
    // 默认：沿速度方向
    double v = Math.sqrt(vx * vx + vy * vy);
    if (v < 0.001) return new double[]{1, 0};
    return new double[]{vx / v, vy / v};
  }

  double bodyRadius() {
    if (currentCentralBody != null) return currentCentralBody.radius;
    return MissionPlanner.EARTH_RADIUS_KM;
  }

  boolean thrustActive() {
    return currentThrustActive;
  }
}
