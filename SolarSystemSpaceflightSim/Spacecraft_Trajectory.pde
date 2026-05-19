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

  // 引用补丁圆锥系统，用于SOI预测
  private PatchedConicsSystem patchedConics;

  // 记录上一次的油门状态，用于检测变化
  private float lastThrottle = -1;

  TrajectoryPredictor() {
    this.cachedTrajectory = null;
    this.lastPredictSimTime = -1;
    this.lastOrbitSnapshot = null;
    this.lastMode = null;
    this.isDirty = true;
    this.patchedConics = null;
  }

  void setPatchedConics(PatchedConicsSystem pc) {
    this.patchedConics = pc;
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

    if (patchedConics != null && ship.referenceBody != null) {
      // 支持SOI预测的多段轨迹
      predictWithSOICheck(ship, simTime, duration, trajectory);
    } else if (ship.referenceBody != null) {
      // 无SOI预测，简单单段轨迹
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

  // 带SOI检测的预测
  private void predictWithSOICheck(Spacecraft ship, double simTime, double duration, Trajectory trajectory) {
    double remainingDuration = duration;
    double currentTime = simTime;

    // 创建临时状态副本，用于预测
    Spacecraft tempShip = createTempShip(ship);

    while (remainingDuration > 0) {
      // 预测当前段的SOI穿越
      SOITraversal traversal = patchedConics.predictSOITraversal(tempShip, remainingDuration, currentTime);

      double segmentDuration = remainingDuration;
      if (traversal.willTraverse && traversal.timeToTraversal <= remainingDuration) {
        segmentDuration = traversal.timeToTraversal;
      }

      // 预测当前轨道段
      if (tempShip.referenceBody != null) {
        Orbit segmentOrbit = Orbit_fromStateVector(
          tempShip.stateVector.position,
          tempShip.stateVector.velocity,
          tempShip.referenceBody,
          currentTime
        );
        if (segmentOrbit != null) {
          predictOnRailsWithOrbit(segmentOrbit, tempShip.referenceBody, currentTime, segmentDuration, trajectory);
        }
      }

      if (traversal.willTraverse && traversal.timeToTraversal <= remainingDuration) {
        // 添加SOI事件
        String eventType = (traversal.enterBody != null) ? "soi_enter" : "soi_exit";
        TrajectoryEvent event = new TrajectoryEvent(traversal.traversalTime, traversal.traversalPosition, eventType);
        event.relatedBody = (traversal.enterBody != null) ? traversal.enterBody : traversal.exitBody;
        trajectory.events.add(event);

        // 切换参考系（模拟SOI穿越后的状态）
        simulateSOITransition(tempShip, traversal, currentTime + segmentDuration);
      }

      currentTime += segmentDuration;
      remainingDuration -= segmentDuration;
    }
  }

  // 创建临时航天器副本（仅包含状态，用于预测）
  private Spacecraft createTempShip(Spacecraft ship) {
    Spacecraft temp = new Spacecraft(ship.name, ship.col);
    temp.referenceBody = ship.referenceBody;
    temp.stateVector.position = new Vector2(ship.stateVector.position.x, ship.stateVector.position.y);
    temp.stateVector.velocity = new Vector2(ship.stateVector.velocity.x, ship.stateVector.velocity.y);
    temp.worldX = ship.worldX;
    temp.worldY = ship.worldY;
    temp.worldVelX = ship.worldVelX;
    temp.worldVelY = ship.worldVelY;
    return temp;
  }

  // 模拟SOI穿越，更新临时航天器状态
  private void simulateSOITransition(Spacecraft tempShip, SOITraversal traversal, double simTime) {
    // 简单模拟：更新参考系，位置/速度使用穿越点的值
    if (traversal.exitBody != null && traversal.enterBody == null) {
      // 离开天体到日心
      Vector2 bodyVel = patchedConics.getBodyVelocity(traversal.exitBody, simTime);
      tempShip.worldX = traversal.exitBody.px + tempShip.stateVector.position.x;
      tempShip.worldY = traversal.exitBody.py + tempShip.stateVector.position.y;
      tempShip.worldVelX = tempShip.stateVector.velocity.x + bodyVel.x;
      tempShip.worldVelY = tempShip.stateVector.velocity.y + bodyVel.y;
      tempShip.referenceBody = null;
    } else if (traversal.enterBody != null) {
      // 进入天体SOI
      Vector2 bodyPos = new Vector2(traversal.enterBody.px, traversal.enterBody.py);
      Vector2 bodyVel = patchedConics.getBodyVelocity(traversal.enterBody, simTime);

      if (traversal.exitBody == null) {
        // 从日心进入
        tempShip.stateVector.position = new Vector2(
          tempShip.worldX - bodyPos.x,
          tempShip.worldY - bodyPos.y
        );
        tempShip.stateVector.velocity = new Vector2(
          tempShip.worldVelX - bodyVel.x,
          tempShip.worldVelY - bodyVel.y
        );
      } else {
        // 从一个天体直接切换到另一个（罕见）
        tempShip.stateVector.position = new Vector2(
          traversal.traversalPosition.x,
          traversal.traversalPosition.y
        );
      }
      tempShip.referenceBody = traversal.enterBody;
    }
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

    // 计算当前和目标的偏近点角
    double currentE = 2 * Math.atan2(
      Math.sqrt(1 - orbit.e) * Math.sin(currentNu / 2),
      Math.sqrt(1 + orbit.e) * Math.cos(currentNu / 2)
    );
    if (currentE < 0) currentE += TWO_PI;

    double targetE = 2 * Math.atan2(
      Math.sqrt(1 - orbit.e) * Math.sin(targetNu / 2),
      Math.sqrt(1 + orbit.e) * Math.cos(targetNu / 2)
    );
    if (targetE < 0) targetE += TWO_PI;

    // 计算平近点角
    double currentM = currentE - orbit.e * Math.sin(currentE);
    double targetM = targetE - orbit.e * Math.sin(targetE);

    // 计算需要增加的平近点角
    double deltaM = targetM - currentM;
    if (deltaM < 0) deltaM += TWO_PI;

    // 计算时间差
    double meanMotion = TWO_PI / orbit.period;
    double time = deltaM / meanMotion;

    // 限制在0~2个周期内
    if (time < 0) time = 0;
    if (time > orbit.period * 2) time = orbit.period * 2;
    return time;
  }

  private double normalizeAngle(double angle) {
    while (angle < 0) angle += TWO_PI;
    while (angle >= TWO_PI) angle -= TWO_PI;
    return angle;
  }
}
