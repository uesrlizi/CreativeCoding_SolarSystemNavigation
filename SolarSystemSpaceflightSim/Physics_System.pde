// ============================================================
//  Physics_System - 主物理系统
//  处理模式判断、自动切换、统一更新
// ============================================================

class PhysicsSystem {
  // 子系统
  PatchedConicsSystem patchedConics;
  NBodyIntegrator integrator;
  SpacecraftForceModel forceModel;
  CollisionDetector collisionDetector;
  AtmosphereModel atmosphereModel;
  PhysicsTickSystem tickSystem;  // 新增：物理 tick 调度器

  // 上一帧的物理模式
  PhysicsMode previousMode;

  // 调试信息
  String debugInfo;
  int lastNumTicks;  // 调试：上次执行的 tick 数

  PhysicsSystem(CelestialSystem solarSystem) {
    this.patchedConics = new PatchedConicsSystem(solarSystem);
    this.integrator = new NBodyIntegrator();
    this.forceModel = new SpacecraftForceModel(solarSystem);
    this.collisionDetector = new CollisionDetector(solarSystem);
    this.atmosphereModel = new AtmosphereModel();
    this.tickSystem = new PhysicsTickSystem();
    this.previousMode = null;
    this.debugInfo = "";
    this.lastNumTicks = 0;
  }

  // ============================================================
  //  模式判断
  // ============================================================

  PhysicsMode determineMode(Spacecraft ship) {
    // 如果固定在表面，保持Off-rails模式（但物理更新特殊处理）
    if (ship.isFixedToSurface) {
      return PhysicsMode.OFF_RAILS;
    }

    // 如果有推力激活，保持Off-rails
    if (ship.autoControl.targetThrottle > 0.01f) {
      return PhysicsMode.OFF_RAILS;
    }

    // 如果有目标朝向需要调整，保持Off-rails
    if (ship.autoControl.hasTargetDirection) {
      return PhysicsMode.OFF_RAILS;
    }

    // 如果在大气层内，保持Off-rails
    if (ship.referenceBody != null) {
      double alt = atmosphereModel.altitudeAboveSurface(ship.stateVector.position, ship.referenceBody);
      if (atmosphereModel.inAtmosphere(ship.referenceBody, alt)) {
        return PhysicsMode.OFF_RAILS;
      }
    }

    // 否则可以使用On-rails
    return PhysicsMode.ON_RAILS;
  }

  // ============================================================
  //  在物理 tick 内更新单个 spacecraft
  // ============================================================

  void updateShipInTick(Spacecraft ship, double simDt, double simTime) {
    updateShipSingleStep(ship, simDt, simTime);
  }

  void updateShipSingleStep(Spacecraft ship, double simDt, double simTime) {
    PhysicsMode currentMode = determineMode(ship);

    // 检查是否固定在表面
    if (ship.isFixedToSurface) {
      if (previousMode != currentMode) {
        handleModeSwitch(ship, previousMode, currentMode, simTime);
      }
      updateFixedToSurface(ship, simDt, simTime);
      updateDebugInfo(ship, currentMode);
      previousMode = currentMode;
      return;
    }

    // 处理模式切换
    if (previousMode != currentMode) {
      handleModeSwitch(ship, previousMode, currentMode, simTime);
    }

    // 根据模式更新
    if (currentMode == PhysicsMode.ON_RAILS) {
      updateOnRails(ship, simTime);
    } else {
      updateOffRailsSingleStep(ship, simDt, simTime);
    }

    refreshPatchedOrbitIfNeeded(ship, simTime);

    // 检查碰撞
    CollisionResult collision = collisionDetector.checkCollision(ship);
    if (collision.hasCollision) {
      collisionDetector.handleCollision(ship, collision);
    }

    // 更新调试信息
    updateDebugInfo(ship, currentMode);

    previousMode = currentMode;
  }

  // ========== 固定在表面的更新 ==========
  void updateFixedToSurface(Spacecraft ship, double simDt, double simTime) {
    // 飞船固定在表面（发射场或着陆后）
    ship.stateVector.velocity = new Vector2(0, 0);

    // 确保位置始终在表面以上
    if (ship.referenceBody != null) {
      ensureOnSurface(ship);
    }

    // 更新世界坐标（基于参考天体位置）
    if (ship.referenceBody != null) {
      ship.worldX = ship.referenceBody.px + ship.stateVector.position.x;
      ship.worldY = ship.referenceBody.py + ship.stateVector.position.y;
    }

    // 清空轨道
    ship.orbit = null;
    ship.patchedOrbit = null;
  }

  // ========== 确保飞船在表面以上 ==========
  void ensureOnSurface(Spacecraft ship) {
    CelestialBody body = ship.referenceBody;
    Vector2 pos = ship.stateVector.position;
    double currentRadius = pos.magnitude();
    double targetRadius = body.radius + Spacecraft.SHIP_LENGTH_KM * 0.5;

    if (currentRadius < targetRadius - 1e-3) { // 有轻微穿透
      ship.stateVector.position = pos.normalized().mul(targetRadius);
    }
  }

  // ============================================================
  //  原有的主更新 (保持向后兼容)
  // ============================================================

  void update(Spacecraft ship, double simDt, double simTime, MissionExecutor missionExecutor) {
    updateShipInTick(ship, simDt, simTime);
  }

  void update(Spacecraft ship, double simDt, double simTime) {
    updateShipInTick(ship, simDt, simTime);
  }

  // ============================================================
  //  On-rails更新
  // ============================================================

  void updateOnRails(Spacecraft ship, double simTime) {
    if (shouldRefreshPatchedOrbit(ship, simTime)) {
      refreshPatchedOrbit(ship, simTime);
    }
    if (ship.patchedOrbit != null) {
      patchedConics.applyActiveSegment(ship, simTime);
    } else {
      ship.updateOnRails(simTime);
    }
  }

  boolean shouldRefreshPatchedOrbit(Spacecraft ship, double simTime) {
    if (ship.isFixedToSurface) return false;
    if (ship.patchedOrbit == null || ship.patchedOrbit.segments.size() == 0) return true;
    OrbitSegment active = ship.patchedOrbit.getSegmentAt(simTime);
    if (active == null) return true;
    if (simTime < active.startTime || simTime > active.endTime) return true;
    if (ship.orbit != null && patchedConics.isUsablePeriod(ship.orbit.period)) {
      return simTime - ship.lastOrbitUpdateTime >= ship.orbit.period;
    }
    return false;
  }

  void refreshPatchedOrbitIfNeeded(Spacecraft ship, double simTime) {
    if (ship.physicsMode == PhysicsMode.OFF_RAILS && !ship.isFixedToSurface) {
      refreshPatchedOrbit(ship, simTime, false);
    } else if (shouldRefreshPatchedOrbit(ship, simTime)) {
      refreshPatchedOrbit(ship, simTime, true);
    }
  }

  void refreshPatchedOrbit(Spacecraft ship, double simTime) {
    refreshPatchedOrbit(ship, simTime, true);
  }

  void refreshPatchedOrbit(Spacecraft ship, double simTime, boolean applyActiveSegment) {
    Trajectory trajectory = patchedConics.buildPatchedOrbit(ship, simTime, TrajectoryPredictor.DEFAULT_DURATION);
    if (trajectory != null && trajectory.segments.size() > 0) {
      ship.patchedOrbit = trajectory;
      ship.lastOrbitUpdateTime = simTime;
      if (applyActiveSegment) {
        patchedConics.applyActiveSegment(ship, simTime);
      }
    } else {
      ship.patchedOrbit = null;
    }
  }

  // ============================================================
  //  Off-rails更新 (单步版本，在 tick 内被调用)
  // ============================================================

  void updateOffRailsSingleStep(Spacecraft ship, double simDt, double simTime) {
    // 设置力模型
    List<CelestialBody> gravityBodies = new ArrayList<CelestialBody>();
    if (ship.referenceBody != null && ship.referenceBody.parentBody != null) {
      gravityBodies.add(ship.referenceBody.parentBody);
    }
    for (CelestialBody planet : patchedConics.solarSystem.planets) {
      if (ship.referenceBody == null || planet != ship.referenceBody) {
        gravityBodies.add(planet);
      }
    }

    // 更新阻力系数（基于马赫数和高度）
    if (ship.referenceBody != null) {
      double alt = atmosphereModel.altitudeAboveSurface(ship.stateVector.position, ship.referenceBody);
      double speed = ship.stateVector.velocity.magnitude(); // km/s
      double mach = ship.referenceBody.atmosphere.getMachNumber(speed, alt);
      ship.updateDragCoefficient(mach, alt);
    }

    forceModel.setState(
      ship.referenceBody,
      gravityBodies,
      ship.autoControl.targetThrottle > 0.01f,
      ship.autoControl.targetDirection,
      getThrustAcceleration(ship),
      ship.currentDragCoefficient,
      ship.crossSectionArea,
      ship.getCurrentMass()
    );

    // 更新姿态控制 (已有自己的子步)
    updateAttitudeControl(ship, simDt);

    // 数值积分 (RK4)
    integrator.reset();
    integrator.integrateRK4(
      ship.stateVector.position,
      ship.stateVector.velocity,
      simDt,
      forceModel
    );

    // 计算并更新G载荷
    Vector2 accel = new Vector2(0, 0);
    forceModel.computeForce(ship.stateVector.position, ship.stateVector.velocity, accel, false); // 不含推力
    ship.updateGLoad(accel);

    // 更新世界位置
    if (ship.referenceBody != null) {
      ship.worldX = ship.referenceBody.px + ship.stateVector.position.x;
      ship.worldY = ship.referenceBody.py + ship.stateVector.position.y;
      Vector2 bodyVel = patchedConics.getBodyVelocity(ship.referenceBody, simTime);
      ship.worldVelX = ship.stateVector.velocity.x + bodyVel.x;
      ship.worldVelY = ship.stateVector.velocity.y + bodyVel.y;
    } else {
      ship.worldX = ship.stateVector.position.x;
      ship.worldY = ship.stateVector.position.y;
      ship.worldVelX = ship.stateVector.velocity.x;
      ship.worldVelY = ship.stateVector.velocity.y;
    }

    // 更新orbit对象（用于绘制轨道）
    if (ship.referenceBody != null) {
      Orbit newOrbit = Orbit_fromStateVector(
        ship.stateVector.position,
        ship.stateVector.velocity,
        ship.referenceBody,
        simTime
      );
      if (newOrbit != null) {
        ship.orbit = newOrbit;
      }
    }
  }

  // 保持向后兼容
  void updateOffRails(Spacecraft ship, double simDt, double simTime) {
    updateOffRailsSingleStep(ship, simDt, simTime);
  }
  void updateOffRails(Spacecraft ship, double simDt, double simTime, MissionExecutor missionExecutor) {
    updateOffRailsSingleStep(ship, simDt, simTime);
  }

  // ============================================================
  //  姿态控制更新
  // ============================================================

  void updateAttitudeControl(Spacecraft ship, double simDt) {
    if (!ship.autoControl.hasTargetDirection) return;

    Vector2 targetDir = ship.autoControl.targetDirection.normalized();
    Vector2 currentDir = ship.attitude.getForward();

    double targetAngle = targetDir.angle();
    double currentAngle = currentDir.angle();

    // 使用子步长进行平滑更新
    double remainingDt = simDt;
    double maxSubStep = 1.0 / 60.0;

    while (remainingDt > 0) {
      double dt = Math.min(remainingDt, maxSubStep);
      updateAttitudeStep(ship, targetAngle, dt);
      remainingDt -= dt;
    }

    // 检查是否已对准
    double finalAngleDiff = angleDifference(targetAngle, ship.attitude.angle);
    if (Math.abs(finalAngleDiff) < 0.01 && Math.abs(ship.angularVelocity) < 0.01) {
      ship.autoControl.hasTargetDirection = false;
    }
  }

  void updateAttitudeStep(Spacecraft ship, double targetAngle, double dt) {
    double currentAngle = ship.attitude.angle;
    double angleDiff = angleDifference(targetAngle, currentAngle);

    // PD控制
    double desiredAccel = angleDiff * Spacecraft.ANGLE_KP - ship.angularVelocity * Spacecraft.ANGLE_KD;
    ship.angularAcceleration = constrainDouble(desiredAccel, -Spacecraft.MAX_ANGULAR_ACCEL, Spacecraft.MAX_ANGULAR_ACCEL);

    ship.angularVelocity += ship.angularAcceleration * dt;
    ship.angularVelocity = constrainDouble(ship.angularVelocity, -Spacecraft.MAX_ANGULAR_VELOCITY, Spacecraft.MAX_ANGULAR_VELOCITY);

    ship.attitude.angle += ship.angularVelocity * dt;
    ship.attitude.normalize();
  }

  double angleDifference(double target, double current) {
    double diff = ((target - current + 3.0 * PI) % (2.0 * PI)) - PI;
    return diff;
  }

  // ============================================================
  //  计算推力加速度
  // ============================================================

  double getThrustAcceleration(Spacecraft ship) {
    if (ship.mainEngine == null || ship.autoControl.targetThrottle <= 0.01f) {
      return 0;
    }

    double thrust_kN = ship.mainEngine.getCurrentThrust() * ship.autoControl.targetThrottle;
    double mass_kg = ship.getCurrentMass() * 1000; // 吨转千克
    double accel_m_s2 = thrust_kN * 1000 / mass_kg; // kN = kg·m/s²
    double accel_km_s2 = accel_m_s2 / 1000; // 转 km/s²

    return accel_km_s2;
  }

  // ============================================================
  //  处理模式切换
  // ============================================================

  void handleModeSwitch(Spacecraft ship, PhysicsMode oldMode, PhysicsMode newMode, double simTime) {
    if (oldMode == null) {
      ship.physicsMode = newMode;
      ship.patchedOrbit = null;
      return;
    }

    if (oldMode == PhysicsMode.OFF_RAILS && newMode == PhysicsMode.ON_RAILS) {
      // Off-rails -> On-rails：从状态向量计算轨道根数
      if (ship.referenceBody != null) {
        Orbit newOrbit = Orbit_fromStateVector(ship.stateVector.position, ship.stateVector.velocity, ship.referenceBody, simTime);
        if (newOrbit != null) {
          ship.orbit = newOrbit;
        }
      }
      ship.physicsMode = PhysicsMode.ON_RAILS;
      ship.patchedOrbit = null;
    } else if (oldMode == PhysicsMode.ON_RAILS && newMode == PhysicsMode.OFF_RAILS) {
      // On-rails -> Off-rails：确保状态向量是最新的
      ship.physicsMode = PhysicsMode.OFF_RAILS;
      ship.patchedOrbit = null;
    } else {
      ship.physicsMode = newMode;
    }
  }

  // ============================================================
  //  判定单个飞船是否需要物理tick
  // ============================================================

  boolean needsPhysicsTick(Spacecraft ship) {
    // 0. 固定在表面（需要特殊处理）
    if (ship.isFixedToSurface) return true;

    // 1. 有推力在烧
    if (ship.autoControl.targetThrottle > 0.01f) return true;

    // 2. 在大气层内
    if (ship.referenceBody != null) {
      double alt = atmosphereModel.altitudeAboveSurface(ship.stateVector.position, ship.referenceBody);
      if (atmosphereModel.inAtmosphere(ship.referenceBody, alt)) return true;
    }

    // 3. 正在调整姿态
    if (ship.autoControl.hasTargetDirection) return true;

    // 4. OFF-RAILS模式
    if (ship.physicsMode == PhysicsMode.OFF_RAILS) return true;

    return false;
  }

  // ============================================================
  //  获取最大允许的时间warp
  // ============================================================

  int getMaxTimeWarp(Spacecraft ship, TimeManager timeManager) {
    if (needsPhysicsTick(ship)) {
      // 需要tick时，限制到warp 2（1分钟/秒）
      return 2;
    }

    return timeManager.WARP_LEVELS.length - 1;
  }

  // ============================================================
  //  更新调试信息
  // ============================================================

  void updateDebugInfo(Spacecraft ship, PhysicsMode mode) {
    String info = "Mode: " + (mode == PhysicsMode.ON_RAILS ? "ON-RAILS" : "OFF-RAILS") + "\n";

    if (ship.referenceBody != null) {
      info += "Ref: " + ship.referenceBody.name + "\n";
      double alt = atmosphereModel.altitudeAboveSurface(ship.stateVector.position, ship.referenceBody);
      info += String.format("Alt: %.1f km\n", alt);
    }

    if (ship.orbit != null) {
      info += String.format("a: %.0f km, e: %.4f\n", ship.orbit.a, ship.orbit.e);
    }

    double v = ship.stateVector.velocity.magnitude();
    info += String.format("v: %.3f km/s\n", v);

    if (ship.autoControl.targetThrottle > 0.01f || ship.mainEngine != null) {
      info += String.format("Throttle: %.0f%%\n", ship.autoControl.targetThrottle * 100);
      if (ship.mainEngine != null) {
        double thrustAccel = getThrustAcceleration(ship) * 1000; // 转 m/s²
        info += String.format("Thrust: %.1f kN, Accel: %.3f m/s²\n",
                              ship.mainEngine.getCurrentThrust() * ship.autoControl.targetThrottle,
                              thrustAccel * ship.autoControl.targetThrottle);
      }
    }

    if (ship.autoControl.hasTargetDirection) {
      Vector2 currentDir = ship.attitude.getForward();
      double angleDiff = Math.abs(ship.autoControl.targetDirection.angle() - currentDir.angle());
      while (angleDiff > Math.PI) angleDiff = TWO_PI - angleDiff;
      info += String.format("Targeting: %.1f deg err\n", Math.toDegrees(angleDiff));
    }

    // 添加 tick 调试信息
    if (mode == PhysicsMode.OFF_RAILS) {
      info += String.format("Ticks: %d\n", lastNumTicks);
    }

    this.debugInfo = info;
  }
}
