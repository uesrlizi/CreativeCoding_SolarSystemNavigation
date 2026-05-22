// ========== RECOVERY GUIDANCE SYSTEM ==========
// 回收任务制导算法

class RecoveryGuidanceSystem {
  // === 常量 ===
  static final double DEORBIT_TARGET_PERIAPSIS = -0.05; // 目标近地点（略低于地表）
  static final double MAX_G_LOAD = 4.0; // 最大G载荷
  static final double TARGET_LANDING_ACCURACY = 0.1; // 目标着陆精度（km）

  // === 着陆PID控制器参数 ===
  double vertPosKp, vertPosKd;  // 垂直位置PID
  double vertVelKp, vertVelKi, vertVelKd;  // 垂直速度PID
  double horizPosKp, horizPosKd;  // 水平位置PID
  double horizVelKp, horizVelKd;  // 水平速度PID

  // === 积分项记忆 ===
  double vertVelIntegral;
  double lastAltitude;
  double lastVerticalVel;

  FlightComputer flightComputer;

  RecoveryGuidanceSystem() {
    this.flightComputer = new FlightComputer();

    // 初始化PID参数（单位要适应km和秒）
    this.vertPosKp = 0.5;      // 垂直位置P
    this.vertPosKd = 0.2;      // 垂直位置D
    this.vertVelKp = 2.0;      // 垂直速度P
    this.vertVelKi = 0.1;      // 垂直速度I
    this.vertVelKd = 0.5;      // 垂直速度D
    this.horizPosKp = 0.8;     // 水平位置P
    this.horizPosKd = 0.3;     // 水平位置D
    this.horizVelKp = 1.5;     // 水平速度P
    this.horizVelKd = 0.4;     // 水平速度D

    this.vertVelIntegral = 0.0;
    this.lastAltitude = -1.0;
    this.lastVerticalVel = 0.0;
  }

  // === 重置PID积分项（每次开始新的着陆时调用）===
  void resetPIDs() {
    vertVelIntegral = 0.0;
    lastAltitude = -1.0;
  }

  // === 寻找当前圈最近的离轨点 ===
  double findNextDeorbitOpportunity(Orbit currentOrbit, CelestialBody earth, LaunchSite site, double currentSimTime) {
    double orbitPeriod = currentOrbit.period;
    println("[RecoveryGuidance] ========== findNextDeorbitOpportunity ==========");
    println("[RecoveryGuidance] orbitPeriod = " + orbitPeriod + "s (" + (orbitPeriod/60) + "m)");
    println("[RecoveryGuidance] currentSimTime = " + currentSimTime);

    // 获取发射场位置
    double siteAngle = site.baseAngle;
    Vector2 sitePos = new Vector2(earth.radius * Math.cos(siteAngle), earth.radius * Math.sin(siteAngle));
    println("[RecoveryGuidance] LaunchSite: angle = " + String.format("%.1f", Math.toDegrees(siteAngle)) + "°");

    // 评估接下来一整圈内的多个点
    double bestDelay = 0.0;
    double bestScore = Double.MAX_VALUE;
    double maxDelay = orbitPeriod; // 评估一整圈

    println("[RecoveryGuidance] Searching deorbit opportunities in next " + (int)(maxDelay/60) + "m");

    for (double delay = 0; delay <= maxDelay; delay += 15.0) { // 每15秒评估一次
      double simTimeAtBurn = currentSimTime + delay;
      double score = evaluateDeorbitPoint(currentOrbit, site, earth, simTimeAtBurn, sitePos);

      if (score < bestScore) {
        bestScore = score;
        bestDelay = delay;
      }

      // 每60秒输出一次日志，避免刷屏
      if ((int)delay % 60 == 0) {
        println("[RecoveryGuidance]   delay=" + (int)delay + "s, score=" + String.format("%.3f", score));
      }
    }

    println("[RecoveryGuidance] SELECTED: delay=" + (int)bestDelay + "s, score=" + String.format("%.3f", bestScore));
    println("[RecoveryGuidance] ===============================================");

    return bestDelay;
  }

  // 评估离轨点质量（越低越好，0=完美）
  double evaluateDeorbitPoint(Orbit orbit, LaunchSite site, CelestialBody earth, double simTimeAtBurn, Vector2 sitePos) {
    Vector2 burnPos = orbit.getPositionAtTime(simTimeAtBurn);
    Vector2 burnVel = orbit.getVelocityAtTime(simTimeAtBurn);

    // 计算燃烧时的位置角度
    double burnAngle = Math.atan2(burnPos.y, burnPos.x);
    double siteAngle = site.baseAngle;

    // 基于轨道高度动态估算飞行时间
    double orbitAlt = (burnPos.magnitude() - earth.radius);
    double estimatedFlightTime = estimateFlightTime(orbitAlt);

    // 考虑地球自转：在飞行时间内，发射场会转动
    double earthRotationRate = 2.0 * PI / (24.0 * 3600.0); // 地球自转角速度（rad/s）
    double siteAngleAtLanding = normalizeAngle(siteAngle + earthRotationRate * estimatedFlightTime);

    // 计算从点火位置到目标位置的角度差
    double angleFromBurnToSite = normalizeAnglePI(siteAngleAtLanding - burnAngle);

    // 轨道是顺时针运动！
    // 理想情况：目标应该在点火位置的运动方向前方约 90-135度
    // 也就是 angleFromBurnToSite 应该为正值（目标在点火位置逆时针方向）
    // 因为顺时针运动时，角度减小的方向是前方
    double idealAngleFromBurnToSite = PI * 0.75; // 理想：目标在点火位置前方135°（逆时针方向）
    double angleError = Math.abs(normalizeAnglePI(angleFromBurnToSite - idealAngleFromBurnToSite));

    // 评分：角度误差越小越好
    double score = angleError / PI; // 0.0 = 完美, 1.0 = 差180度

    return score;
  }

  // === 计算离轨所需的ΔV ===
  Vector2 computeDeorbitDeltaV(Vector2 velocity) {
    // 简化的离轨策略：反速度方向减速
    // 目标：让近地点略低于地表
    // 简化计算：减速约0.1-0.2 km/s
    double deltaVSpeed = 0.15; // km/s

    Vector2 retrograde = velocity.normalized().mul(-1);
    return retrograde.mul(deltaVSpeed);
  }

  // === 再入制导 ===
  GuidanceOutput reentryGuidance(Vector2 position, Vector2 velocity, double GM, double currentG, Vector2 targetPosition, double currentSimTime, CelestialBody earth) {
    GuidanceOutput output = new GuidanceOutput();

    double r = position.magnitude();
    double altitude = r - EARTH_RADIUS_KM;

    if (altitude > 80.0) {
      // 高空：保持0度攻角，减少阻力
      output.targetAngleOfAttack = 0.0;
      output.guidanceMode = GuidanceMode.REENTRY_GUIDANCE;
    } else if (altitude > 20.0) {
      // 中低空：调整攻角控制G载荷 + 位置闭环
      double baseAoA = 0.05;

      // G载荷控制
      if (currentG > MAX_G_LOAD * 0.8) {
        // G过高，增加阻力（攻角增大）
        baseAoA = Math.min(currentG * 0.1, PI/6);
      }

      // 位置闭环控制：根据水平误差调整攻角
      Vector2 radialDir = position.normalized();
      Vector2 tangentDir = new Vector2(-radialDir.y, radialDir.x);
      Vector2 posToTarget = targetPosition.sub(position);
      double horizontalPosError = posToTarget.dot(tangentDir);

      // 每30帧输出一次日志
      if ((int)(currentSimTime * 60) % 30 == 0) {
        double currentHorizontalVel = velocity.dot(tangentDir);
        println("[RecoveryGuidance] REENTRY: alt=" + (int)altitude + "km" +
                ", horizError=" + String.format("%.1f", horizontalPosError) + "km" +
                ", horizVel=" + String.format("%.3f", currentHorizontalVel) + "km/s" +
                ", G=" + String.format("%.1f", currentG));
      }

      // 平滑的位置控制 - 适度增益
      double aoaCorrection = Math.signum(horizontalPosError) * Math.min(Math.abs(horizontalPosError) * 0.0012, 0.15);

      // 确保G载荷控制优先级高于位置控制
      output.targetAngleOfAttack = constrainDouble(baseAoA + aoaCorrection, 0.02, Math.max(PI/6, baseAoA + 0.15));
      output.guidanceMode = GuidanceMode.REENTRY_GUIDANCE;
    } else {
      // 低空：滑翔到着陆
      output = glideGuidance(position, velocity, targetPosition, currentSimTime, earth);
    }

    return output;
  }

  // === 向后兼容：旧版再入制导 ===
  GuidanceOutput reentryGuidance(Vector2 position, Vector2 velocity, double GM, double currentG) {
    GuidanceOutput output = new GuidanceOutput();
    double r = position.magnitude();
    double altitude = r - EARTH_RADIUS_KM;
    if (altitude > 80.0) {
      output.targetAngleOfAttack = 0.0;
    } else if (altitude > 20.0) {
      if (currentG > MAX_G_LOAD * 0.8) {
        output.targetAngleOfAttack = Math.min(currentG * 0.1, PI/6);
      } else {
        output.targetAngleOfAttack = 0.05;
      }
    } else {
      output.targetAngleOfAttack = 0.1;
    }
    output.guidanceMode = GuidanceMode.REENTRY_GUIDANCE;
    return output;
  }

  // === 滑翔制导 ===
  GuidanceOutput glideGuidance(Vector2 position, Vector2 velocity, Vector2 targetPosition, double currentSimTime, CelestialBody earth) {
    GuidanceOutput output = new GuidanceOutput();
    output.guidanceMode = GuidanceMode.GLIDE_GUIDANCE;

    // 计算水平位置误差
    double r = position.magnitude();
    double altitude = r - earth.radius;

    Vector2 radialDir = position.normalized();
    Vector2 tangentDir = new Vector2(-radialDir.y, radialDir.x); // 逆时针切向

    Vector2 posToTarget = targetPosition.sub(position);
    double horizontalPosError = posToTarget.dot(tangentDir);
    double currentHorizontalVel = velocity.dot(tangentDir);

    // 每30帧输出一次日志
    if ((int)(currentSimTime * 60) % 30 == 0) {
      println("[RecoveryGuidance] GLIDE: alt=" + (int)altitude + "km" +
              ", horizError=" + String.format("%.1f", horizontalPosError) + "km" +
              ", horizVel=" + String.format("%.3f", currentHorizontalVel) + "km/s");
    }

    // 调整攻角来控制滑翔轨迹
    // 如果在目标前方（误差为正），增加攻角来增加阻力，缩短航程
    // 如果在目标后方（误差为负），减小攻角来减少阻力，增加航程
    double baseAoA = 0.1;

    // 平滑的比例控制 - 适度增益
    // 低高度时增益更高，因为滑翔时间少了
    double altitudeGain = Math.max(1.0, 3.0 - altitude / 10.0);
    double aoaCorrection = Math.signum(horizontalPosError) * Math.min(Math.abs(horizontalPosError) * 0.003 * altitudeGain, 0.2);

    output.targetAngleOfAttack = constrainDouble(baseAoA + aoaCorrection, 0.02, 0.3);

    return output;
  }

  // === 动力着陆制导 - 完整闭环PID控制 ===
  LandingGuidanceOutput propulsiveLandingGuidance(Vector2 position, Vector2 velocity, Vector2 targetPosition, double altitude, double GM, double currentSimTime) {
    LandingGuidanceOutput output = new LandingGuidanceOutput();

    double r = position.magnitude();
    double earthRadius = r - altitude;
    Vector2 radialDir = position.normalized(); // 向外（头部应该朝这个方向）

    // 计算垂直速度（正=向上，负=向下）
    double verticalVel = position.dot(velocity) / r;

    // 计算切向（水平）方向和速度
    Vector2 tangentDir = new Vector2(-radialDir.y, radialDir.x); // 逆时针切向
    double horizontalVel = velocity.dot(tangentDir);

    // 计算水平位置误差（目标在切向平面上的投影）
    Vector2 posToTarget = targetPosition.sub(position);
    double horizontalPosError = posToTarget.dot(tangentDir);

    // 每30帧输出一次日志
    if ((int)(currentSimTime * 60) % 30 == 0) {
      println("[RecoveryGuidance] LANDING: alt=" + String.format("%.1f", altitude * 1000) + "m" +
              ", horizError=" + String.format("%.1f", horizontalPosError) + "km" +
              ", horizVel=" + String.format("%.3f", horizontalVel) + "km/s" +
              ", vertVel=" + String.format("%.3f", verticalVel) + "km/s");
    }

    // ==================== 垂直速度PID控制（油门） ====================
    double targetVerticalVel;
    if (altitude > 10.0) {
      // 高空：快速下降，目标-0.15 km/s
      targetVerticalVel = -0.15;
    } else if (altitude > 1.0) {
      // 中空：线性减小下降率
      targetVerticalVel = -0.15 * (altitude / 10.0);
    } else if (altitude > 0.1) {
      // 低空：缓慢下降
      targetVerticalVel = -0.02 * (altitude / 0.1);
    } else {
      // 最终：非常缓慢下降
      targetVerticalVel = -0.005;
    }

    // 速度误差
    double vertVelError = targetVerticalVel - verticalVel;

    // 积分项（防积分饱和）
    if (altitude > 0.01) {
      vertVelIntegral += vertVelError * 0.016; // 假设60Hz，dt≈0.016
      vertVelIntegral = constrainDouble(vertVelIntegral, -0.5, 0.5);
    }

    // PID计算基础油门
    double baseThrottle = vertVelKp * vertVelError + vertVelKi * vertVelIntegral;

    // 动态重力补偿前馈（使用1/r²模型）
    double gravityRatio = (earthRadius * earthRadius) / (r * r); // earthRadius已在上方定义
    double gravityCompensation = 0.45 * gravityRatio; // 基于高度调整

    // 总油门 = PID + 重力补偿
    double throttle = baseThrottle + gravityCompensation;
    output.targetThrottle = (float)constrainDouble(throttle, 0.0, 1.0);

    // ==================== 水平位置PID控制（方向） ====================
    // 根据高度调整水平位置增益 - 高度越低越积极
    double horizGainMultiplier = 1.0;
    if (altitude < 5.0) {
      horizGainMultiplier = 2.0; // 低空时加倍努力
    }

    // 目标水平速度： proportional to position error
    double targetHorizontalVel = horizPosKp * horizontalPosError * horizGainMultiplier;
    targetHorizontalVel = constrainDouble(targetHorizontalVel, -0.08, 0.08); // 稍微提高最大水平速度

    // 水平速度误差
    double horizVelError = targetHorizontalVel - horizontalVel;

    // 计算水平加速度需求
    double horizAccelDemand = horizVelKp * horizVelError * horizGainMultiplier;

    // ==================== 合成推力方向 ====================
    // 主要保持radialOut，加上水平修正
    Vector2 horizCorrectionDir = tangentDir.mul(horizAccelDemand);

    // 限制水平修正的幅度 - 保守值
    double maxHorizComponent = (altitude < 1.0) ? 0.5 : 0.35;
    if (horizCorrectionDir.magnitude() > maxHorizComponent) {
      horizCorrectionDir = horizCorrectionDir.normalized().mul(maxHorizComponent);
    }

    // 合成方向：主要向外 + 水平修正
    output.targetDirection = radialDir.add(horizCorrectionDir);
    output.targetDirection = output.targetDirection.normalized();

    // 安全检查：极低高度时，强制完全radialOut，确保发动机朝下
    if (altitude < 0.05) { // 50m以下强制径向
      output.targetDirection = radialDir;
      // 微调油门确保轻柔触地
      if (verticalVel > -0.002) {
        output.targetThrottle = 0.25f;
      } else {
        output.targetThrottle = 0.35f;
      }
    }

    return output;
  }

  // === 计算水平位置差 ===
  Vector2 computeHorizontalDifference(Vector2 position, Vector2 targetPosition) {
    // 简化：2D平面上的差异
    return targetPosition.sub(position);
  }

  // === 向后兼容：旧版glideGuidance ===
  GuidanceOutput glideGuidance(Vector2 position, Vector2 velocity) {
    GuidanceOutput output = new GuidanceOutput();
    output.guidanceMode = GuidanceMode.GLIDE_GUIDANCE;
    output.targetAngleOfAttack = 0.1;
    return output;
  }

  // === 预测着陆点（带简化大气模型）===
  Vector2 predictLandingPosition(Vector2 position, Vector2 velocity, CelestialBody earth) {
    double GM = earth.GM;
    double dt = 1.0;
    Vector2 pos = position.clone();
    Vector2 vel = velocity.clone();
    double r = pos.magnitude();

    while (r > earth.radius) {
      double altitude = r - earth.radius;

      // 重力加速度
      Vector2 grav = pos.normalized().mul(-GM / (r * r));

      // 简化大气阻力（指数模型）
      double rho = 0;
      if (altitude < 100) { // 100km以下才有大气
        rho = Math.exp(-altitude / 10.0); // 标高10km
      }
      double dragAccel = 0.01 * rho * vel.magnitude(); // 简化阻力加速度
      Vector2 drag = vel.normalized().mul(-dragAccel);

      // 积分
      vel = vel.add(grav.mul(dt)).add(drag.mul(dt));
      pos = pos.add(vel.mul(dt));
      r = pos.magnitude();
    }

    return pos;
  }

  // === 规范化角度到0-2PI ===
  double normalizeAngle(double angle) {
    while (angle < 0) angle += 2 * PI;
    while (angle >= 2 * PI) angle -= 2 * PI;
    return angle;
  }

  // === 规范化角度到-PI到PI ===
  double normalizeAnglePI(double angle) {
    while (angle < -PI) angle += 2 * PI;
    while (angle > PI) angle -= 2 * PI;
    return angle;
  }

  // === 基于轨道高度估算再入飞行时间 ===
  double estimateFlightTime(double orbitAltitude) {
    // 经验模型：LEO(200km)约25分钟，更高轨道时间更长
    if (orbitAltitude < 200) return 25 * 60;
    if (orbitAltitude < 400) return 30 * 60;
    if (orbitAltitude < 600) return 35 * 60;
    if (orbitAltitude < 800) return 40 * 60;
    return 45 * 60; // 上限
  }

  // === 计算所需离轨燃烧时长 ===
  double computeDeorbitBurnDuration(Spacecraft craft) {
    if (craft == null || craft.mainEngine == null) return 6.0;

    // 目标ΔV约120m/s（0.12km/s），让近地点降到大气层内
    double targetDeltaV = 0.12; // km/s

    // 使用引擎的getAcceleration方法
    double accel = craft.mainEngine.getAcceleration(craft.getCurrentMass(), 1.0f); // km/s²

    if (accel <= 0) return 6.0;
    return Math.max(4.0, Math.min(10.0, targetDeltaV / accel));
  }
}

// === 制导输出类 ===
class GuidanceOutput {
  GuidanceMode guidanceMode;
  double targetAngleOfAttack;
  Vector2 targetDirection;

  GuidanceOutput() {
    this.guidanceMode = GuidanceMode.REENTRY_GUIDANCE;
    this.targetAngleOfAttack = 0.0;
    this.targetDirection = new Vector2(1, 0);
  }
}

// === 着陆制导输出类 ===
class LandingGuidanceOutput {
  Vector2 targetDirection;
  float targetThrottle;

  LandingGuidanceOutput() {
    this.targetDirection = new Vector2(0, -1);
    this.targetThrottle = 0.0f;
  }
}
