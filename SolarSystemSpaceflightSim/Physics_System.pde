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

  // 上一帧的物理模式
  PhysicsMode previousMode;

  // 调试信息
  String debugInfo;

  PhysicsSystem(CelestialSystem solarSystem) {
    this.patchedConics = new PatchedConicsSystem(solarSystem);
    this.integrator = new NBodyIntegrator();
    this.forceModel = new SpacecraftForceModel(solarSystem);
    this.collisionDetector = new CollisionDetector(solarSystem);
    this.atmosphereModel = new AtmosphereModel();
    this.previousMode = null;
    this.debugInfo = "";
  }

  // ============================================================
  //  模式判断
  // ============================================================

  PhysicsMode determineMode(Spacecraft ship) {
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
  //  主更新
  // ============================================================

  void update(Spacecraft ship, double simDt, double simTime) {
    PhysicsMode currentMode = determineMode(ship);

    // 处理模式切换
    if (previousMode != currentMode) {
      handleModeSwitch(ship, previousMode, currentMode, simTime);
    }

    // 根据模式更新
    if (currentMode == PhysicsMode.ON_RAILS) {
      updateOnRails(ship, simTime);
    } else {
      updateOffRails(ship, simDt, simTime);
    }

    // 检查SOI穿越（在任何模式下都需要检查）
    patchedConics.checkAndProcessSOICrossing(ship, simTime);

    // 检查碰撞
    CollisionResult collision = collisionDetector.checkCollision(ship);
    if (collision.hasCollision) {
      collisionDetector.handleCollision(ship, collision);
    }

    // 更新调试信息
    updateDebugInfo(ship, currentMode);

    previousMode = currentMode;
  }

  // ============================================================
  //  On-rails更新
  // ============================================================

  void updateOnRails(Spacecraft ship, double simTime) {
    ship.updateOnRails(simTime);
  }

  // ============================================================
  //  Off-rails更新
  // ============================================================

  void updateOffRails(Spacecraft ship, double simDt, double simTime) {
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

    forceModel.setState(
      ship.referenceBody,
      gravityBodies,
      ship.autoControl.targetThrottle > 0.01f,
      ship.autoControl.targetDirection,
      getThrustAcceleration(ship),
      ship.dragCoefficient,
      ship.crossSectionArea,
      ship.getCurrentMass()
    );

    // 更新姿态控制
    updateAttitudeControl(ship, simDt);

    // 数值积分
    integrator.reset();
    integrator.integrateRK4(
      ship.stateVector.position,
      ship.stateVector.velocity,
      simDt,
      forceModel
    );

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

    // 沿速度方向更新姿态
    if (ship.stateVector.velocity.magnitude() > 0.001) {
      ship.attitude = Rotation2D_fromDirection(ship.stateVector.velocity);
    }
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

    double angleDiff = targetAngle - currentAngle;
    while (angleDiff > PI) angleDiff -= TWO_PI;
    while (angleDiff < -PI) angleDiff += TWO_PI;

    // 简单的比例控制
    double desiredAngularVel = angleDiff * 4.0;
    desiredAngularVel = constrainDouble(desiredAngularVel, -Spacecraft.MAX_ANGULAR_VELOCITY, Spacecraft.MAX_ANGULAR_VELOCITY);

    ship.angularVelocity = desiredAngularVel;
    ship.attitude.angle += ship.angularVelocity * simDt;
    ship.attitude.normalize();

    // 如果角度差很小，认为已对准
    if (Math.abs(angleDiff) < 0.01) {
      ship.autoControl.hasTargetDirection = false;
    }
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
    if (oldMode == PhysicsMode.OFF_RAILS && newMode == PhysicsMode.ON_RAILS) {
      // Off-rails -> On-rails：从状态向量计算轨道根数
      if (ship.referenceBody != null) {
        Orbit newOrbit = Orbit_fromStateVector(ship.stateVector.position, ship.stateVector.velocity, ship.referenceBody, simTime);
        if (newOrbit != null) {
          ship.orbit = newOrbit;
        }
      }
      ship.physicsMode = PhysicsMode.ON_RAILS;
    } else if (oldMode == PhysicsMode.ON_RAILS && newMode == PhysicsMode.OFF_RAILS) {
      // On-rails -> Off-rails：确保状态向量是最新的
      ship.physicsMode = PhysicsMode.OFF_RAILS;
    }
  }

  // ============================================================
  //  获取最大允许的时间warp
  // ============================================================

  int getMaxTimeWarp(Spacecraft ship, TimeManager timeManager) {
    if (ship.physicsMode == PhysicsMode.OFF_RAILS) {
      // 物理模式下限制最高warp
      return Math.min(3, timeManager.WARP_LEVELS.length - 1);
    }

    if (ship.referenceBody != null) {
      double alt = atmosphereModel.altitudeAboveSurface(ship.stateVector.position, ship.referenceBody);
      if (atmosphereModel.inAtmosphere(ship.referenceBody, alt)) {
        // 在大气层内限制warp
        return Math.min(4, timeManager.WARP_LEVELS.length - 1);
      }
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

    this.debugInfo = info;
  }
}
