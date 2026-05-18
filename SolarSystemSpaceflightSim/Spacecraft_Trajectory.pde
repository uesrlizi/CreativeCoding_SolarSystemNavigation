// ========== TRAJECTORY PREDICTION ==========

// 轨迹事件（AP/PE/SOI改变等）
class TrajectoryEvent {
  double time;
  Vector2 position;
  String type; // "apoapsis", "periapsis", "soi_enter", "soi_exit", "maneuver"
  CelestialBody relatedBody; // 对于SOI事件

  TrajectoryEvent(double t, Vector2 pos, String type) {
    this.time = t;
    this.position = pos.clone();
    this.type = type;
    this.relatedBody = null;
  }
}

// 轨道段（一段连续的轨道，可能是On-rails或Off-rails）
class OrbitSegment {
  Orbit orbit; // 仅On-rails时有值
  PhysicsMode mode;
  double startTime;
  double endTime;
  CelestialBody referenceBody;

  // 对于On-rails段
  OrbitSegment(Orbit orbit, double start, double end, CelestialBody body) {
    this.orbit = orbit;
    this.mode = PhysicsMode.ON_RAILS;
    this.startTime = start;
    this.endTime = end;
    this.referenceBody = body;
  }
}

// 轨迹（包含多段轨道 + 事件）
class Trajectory {
  List<OrbitSegment> segments; // 轨道段（阶段5后可能有多段）
  List<TrajectoryEvent> events; // 事件（AP/PE/SOI变化/机动）
  double startTime;
  double endTime;
  CelestialBody primaryBody; // 主要参考天体

  Trajectory() {
    this.segments = new ArrayList<OrbitSegment>();
    this.events = new ArrayList<TrajectoryEvent>();
    this.startTime = 0;
    this.endTime = 0;
    this.primaryBody = null;
  }
}

class TrajectoryPredictor {
  static final double DEFAULT_DURATION = 86400 * 3; // 默认预测3天

  private Trajectory cachedTrajectory;
  private double lastPredictSimTime;
  private Orbit lastOrbitSnapshot;
  private PhysicsMode lastMode;
  private boolean isDirty;

  // 记录上一次的油门状态，用于检测变化
  private float lastThrottle = -1;

  TrajectoryPredictor() {
    this.cachedTrajectory = null;
    this.lastPredictSimTime = -1;
    this.lastOrbitSnapshot = null;
    this.lastMode = null;
    this.isDirty = true;
  }

  void markDirty() {
    this.isDirty = true;
  }

  // 预测主入口
  Trajectory predict(Spacecraft ship, double simTime) {
    return predict(ship, simTime, DEFAULT_DURATION);
  }

  Trajectory predict(Spacecraft ship, double simTime, double duration) {
    if (!needsRefresh(ship, simTime)) {
      return this.cachedTrajectory;
    }

    Trajectory trajectory = new Trajectory();
    trajectory.startTime = simTime;
    trajectory.endTime = simTime + duration;
    trajectory.primaryBody = ship.referenceBody;

    // 无论什么模式，都用当前状态向量计算轨道，显示椭圆
    if (ship.referenceBody != null) {
      Orbit currentOrbit = Orbit_fromStateVector(
        ship.stateVector.position,
        ship.stateVector.velocity,
        ship.referenceBody,
        simTime
      );
      if (currentOrbit != null) {
        predictOnRailsWithOrbit(currentOrbit, ship.referenceBody, simTime, duration, trajectory);
      }
    }

    this.cachedTrajectory = trajectory;
    this.lastPredictSimTime = simTime;
    this.lastMode = ship.physicsMode;
    this.lastThrottle = ship.autoControl.targetThrottle;
    if (ship.orbit != null) {
      this.lastOrbitSnapshot = new Orbit(ship.orbit.a, ship.orbit.e, ship.orbit.w,
                                         ship.orbit.M0, ship.orbit.epoch, ship.orbit.period, ship.orbit.referenceBody);
    }
    this.isDirty = false;

    return trajectory;
  }

  private boolean needsRefresh(Spacecraft ship, double simTime) {
    if (this.isDirty) return true;
    if (this.cachedTrajectory == null) return true;
    if (ship.physicsMode != this.lastMode) return true;

    // 对于Off-Rails模式，每帧都刷新
    if (ship.physicsMode == PhysicsMode.OFF_RAILS) {
      return true;
    }

    if (ship.orbit != null && this.lastOrbitSnapshot != null) {
      if (Math.abs(ship.orbit.a - this.lastOrbitSnapshot.a) > 0.1) return true;
      if (Math.abs(ship.orbit.e - this.lastOrbitSnapshot.e) > 0.0001) return true;
    } else if (ship.orbit != this.lastOrbitSnapshot) {
      return true;
    }

    return false;
  }

  // On-rails预测：直接用轨道椭圆
  private void predictOnRails(Spacecraft ship, double simTime, double duration, Trajectory trajectory) {
    predictOnRailsWithOrbit(ship.orbit, ship.referenceBody, simTime, duration, trajectory);
  }

  // 使用指定轨道进行预测
  private void predictOnRailsWithOrbit(Orbit orbit, CelestialBody body, double simTime, double duration, Trajectory trajectory) {
    if (orbit == null || body == null) return;

    // 添加轨道段（当前轨道持续整段预测时间）
    OrbitSegment seg = new OrbitSegment(orbit, simTime, simTime + duration, body);
    trajectory.segments.add(seg);

    // 添加AP/PE事件（各一个，下一个遇到的）
    addNextApoapsisPeriapsis(orbit, body, simTime, duration, trajectory);
  }

  // 计算下一个AP/PE事件
  private void addNextApoapsisPeriapsis(Orbit orbit, CelestialBody body, double simTime, double duration, Trajectory trajectory) {
    if (orbit.e < 0.0001) {
      // 近圆轨道，不用标AP/PE
      return;
    }

    double currentNu = orbit.getTrueAnomalyAtTime(simTime);

    // 找下一个近地点（nu从当前增加到2PI后的0点）
    double timeToNextPE = getTimeToTrueAnomaly(orbit, currentNu, 0, simTime);
    if (timeToNextPE > 0 && timeToNextPE <= duration) {
      double peTime = simTime + timeToNextPE;
      Vector2 pePos = orbit.getPositionAtTime(peTime);
      trajectory.events.add(new TrajectoryEvent(peTime, pePos, "periapsis"));
    }

    // 找下一个远地点（nu从当前增加到PI）
    double timeToNextAP = getTimeToTrueAnomaly(orbit, currentNu, PI, simTime);
    if (timeToNextAP > 0 && timeToNextAP <= duration) {
      double apTime = simTime + timeToNextAP;
      Vector2 apPos = orbit.getPositionAtTime(apTime);
      trajectory.events.add(new TrajectoryEvent(apTime, apPos, "apoapsis"));
    }
  }

  // 计算从当前true anomaly到目标true anomaly需要的时间
  private double getTimeToTrueAnomaly(Orbit orbit, double currentNu, double targetNu, double simTime) {
    // 归一化角度到 [0, 2PI)
    currentNu = normalizeAngle(currentNu);
    targetNu = normalizeAngle(targetNu);

    // 计算需要增加的角度
    double deltaNu = targetNu - currentNu;
    if (deltaNu < 0) deltaNu += TWO_PI;

    // 简化估计：用平均角速度（开普勒方程的精确解比较复杂，阶段5再完善）
    double meanMotion = TWO_PI / orbit.period;
    double estTime = deltaNu / meanMotion;

    // 限制在0~2个周期内
    double result = estTime;
    if (result < 0) result = 0;
    if (result > orbit.period * 2) result = orbit.period * 2;
    return result;
  }

  private double normalizeAngle(double angle) {
    while (angle < 0) angle += TWO_PI;
    while (angle >= TWO_PI) angle -= TWO_PI;
    return angle;
  }
}
