// ========== TRAJECTORY PREDICTION ==========

// 轨迹点（用于需要离散采样的情况，比如可视化精度要求）
class TrajectoryPoint {
  double time;
  Vector2 position;
  Vector2 velocity;
  PhysicsMode sourceMode;

  TrajectoryPoint(double t, Vector2 pos, Vector2 vel, PhysicsMode mode) {
    this.time = t;
    this.position = pos.clone();
    this.velocity = vel.clone();
    this.sourceMode = mode;
  }
}

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

  // 采样点缓存（用于绘制，按需计算）
  private List<TrajectoryPoint> cachedPoints;
  private double cachedPointStep;

  Trajectory() {
    this.segments = new ArrayList<OrbitSegment>();
    this.events = new ArrayList<TrajectoryEvent>();
    this.startTime = 0;
    this.endTime = 0;
    this.primaryBody = null;
    this.cachedPoints = null;
    this.cachedPointStep = 0;
  }

  // 获取采样点（用于绘制）
  List<TrajectoryPoint> getSampledPoints(double step) {
    if (cachedPoints != null && Math.abs(step - cachedPointStep) < 0.1) {
      return cachedPoints;
    }

    cachedPoints = new ArrayList<TrajectoryPoint>();
    cachedPointStep = step;

    for (OrbitSegment seg : segments) {
      if (seg.mode == PhysicsMode.ON_RAILS && seg.orbit != null) {
        // 对On-rails段，用椭圆采样
        for (double t = seg.startTime; t <= seg.endTime; t += step) {
          Vector2 pos = seg.orbit.getPositionAtTime(t);
          Vector2 vel = seg.orbit.getVelocityAtTime(t);
          cachedPoints.add(new TrajectoryPoint(t, pos, vel, PhysicsMode.ON_RAILS));
        }
      }
    }

    return cachedPoints;
  }

  // 标记缓存失效
  void invalidateCache() {
    cachedPoints = null;
  }
}

class TrajectoryPredictor {
  static final double DEFAULT_DURATION = 86400 * 3; // 默认预测3天
  static final double DEFAULT_SAMPLE_STEP = 60; // 默认采样步长60秒（仅用于绘制）

  private Trajectory cachedTrajectory;
  private double lastPredictSimTime;
  private Orbit lastOrbitSnapshot;
  private PhysicsMode lastMode;
  private boolean isDirty;

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

    if (ship.physicsMode == PhysicsMode.ON_RAILS && ship.orbit != null) {
      predictOnRails(ship, simTime, duration, trajectory);
    } else {
      predictOffRailsPlaceholder(ship, simTime, duration, trajectory);
    }

    this.cachedTrajectory = trajectory;
    this.lastPredictSimTime = simTime;
    this.lastMode = ship.physicsMode;
    if (ship.orbit != null) {
      this.lastOrbitSnapshot = new Orbit(ship.orbit.a, ship.orbit.e, ship.orbit.w,
                                         ship.orbit.M0, ship.orbit.period, ship.orbit.referenceBody);
    }
    this.isDirty = false;

    return trajectory;
  }

  private boolean needsRefresh(Spacecraft ship, double simTime) {
    if (this.isDirty) return true;
    if (this.cachedTrajectory == null) return true;
    if (ship.physicsMode != this.lastMode) return true;

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
    Orbit orbit = ship.orbit;
    CelestialBody body = ship.referenceBody;

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

  // Off-rails占位（阶段4实现）
  private void predictOffRailsPlaceholder(Spacecraft ship, double simTime, double duration, Trajectory trajectory) {
    // 占位：阶段4实现数值积分
  }
}
