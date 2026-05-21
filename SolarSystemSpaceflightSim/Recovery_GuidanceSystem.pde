// ========== RECOVERY GUIDANCE SYSTEM ==========
// 回收任务制导算法

class RecoveryGuidanceSystem {
  // === 常量 ===
  static final double DEORBIT_TARGET_PERIAPSIS = -0.05; // 目标近地点（略低于地表）
  static final double MAX_G_LOAD = 4.0; // 最大G载荷
  static final double TARGET_LANDING_ACCURACY = 0.1; // 目标着陆精度（km）

  FlightComputer flightComputer;

  RecoveryGuidanceSystem() {
    this.flightComputer = new FlightComputer();
  }

  // === 寻找当前圈最近的离轨点 ===
  double findNextDeorbitOpportunity(Orbit currentOrbit, CelestialBody earth, LaunchSite site, double currentSimTime) {
    // 简化：寻找轨道上合适的位置来点火
    // 理想情况下，点火后再入点接近发射场

    double orbitPeriod = currentOrbit.period;

    // 快速计算：寻找接下来的0.25个轨道周期内的合适点
    double bestDelay = orbitPeriod * 0.1; // 快速开始
    double bestScore = Double.MAX_VALUE;

    for (double delay = 0; delay < orbitPeriod * 0.5; delay += orbitPeriod * 0.05) {
      double simTimeAtBurn = currentSimTime + delay;
      double score = evaluateDeorbitPoint(currentOrbit, site, simTimeAtBurn);

      if (score < bestScore) {
        bestScore = score;
        bestDelay = delay;
      }
    }

    // 取最早的合理机会
    return bestDelay;
  }

  // 评估离轨点质量（越低越好）
  double evaluateDeorbitPoint(Orbit orbit, LaunchSite site, double simTimeAtBurn) {
    Vector2 burnPos = orbit.getPositionAtTime(simTimeAtBurn);

    // 简化评分：距离发射场的大致距离
    double siteAngle = site.baseAngle;
    double burnAngle = Math.atan2(burnPos.y, burnPos.x);
    double angleDiff = Math.abs(normalizeAngle(burnAngle - siteAngle));

    // 给稍大于90度的相位一点优势（因为需要滑行）
    double idealDiff = PI * 0.75;
    return Math.abs(angleDiff - idealDiff);
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
  GuidanceOutput reentryGuidance(Vector2 position, Vector2 velocity, double GM, double currentG) {
    GuidanceOutput output = new GuidanceOutput();

    double r = position.magnitude();
    double altitude = r - EARTH_RADIUS_KM;

    if (altitude > 80.0) {
      // 高空：保持0度攻角，减少阻力
      output.targetAngleOfAttack = 0.0;
      output.guidanceMode = GuidanceMode.REENTRY_GUIDANCE;
    } else if (altitude > 20.0) {
      // 中低空：调整攻角控制G载荷
      if (currentG > MAX_G_LOAD * 0.8) {
        // G过高，增加阻力（攻角增大）
        output.targetAngleOfAttack = Math.min(currentG * 0.1, PI/6);
      } else {
        // 保持较小攻角
        output.targetAngleOfAttack = 0.05;
      }
      output.guidanceMode = GuidanceMode.REENTRY_GUIDANCE;
    } else {
      // 低空：滑翔到着陆
      output = glideGuidance(position, velocity);
    }

    return output;
  }

  // === 滑翔制导 ===
  GuidanceOutput glideGuidance(Vector2 position, Vector2 velocity) {
    GuidanceOutput output = new GuidanceOutput();
    output.guidanceMode = GuidanceMode.GLIDE_GUIDANCE;
    output.targetAngleOfAttack = 0.1; // 保持一定升力

    return output;
  }

  // === 动力着陆制导 ===
  LandingGuidanceOutput propulsiveLandingGuidance(Vector2 position, Vector2 velocity, Vector2 targetPosition, double altitude, double GM) {
    LandingGuidanceOutput output = new LandingGuidanceOutput();

    double r = position.magnitude();
    double verticalVel = position.dot(velocity) / r;
    Vector2 radialDir = position.normalized();

    if (altitude > 5.0) {
      // 高度较高：主要减速
      double speed = velocity.magnitude();
      if (speed > 0.1) {
        output.targetDirection = velocity.normalized().mul(-1); // 反速度方向
      } else {
        output.targetDirection = radialDir.mul(-1); // 指向地心
      }
      output.targetThrottle = (float)constrainDouble(speed * 5, 0.3, 1.0);
    } else if (altitude > 0.1) {
      // 接近地面：悬停平移
      Vector2 horizontalDiff = computeHorizontalDifference(position, targetPosition);

      if (horizontalDiff.magnitude() > 0.05) {
        output.targetDirection = horizontalDiff.normalized();
        output.targetDirection = output.targetDirection.add(radialDir.mul(-0.5)); // 混合一点向下
        output.targetDirection = output.targetDirection.normalized();
      } else {
        output.targetDirection = radialDir.mul(-1); // 直接向下
      }

      output.targetThrottle = 0.5f;
    } else {
      // 着陆：减速
      output.targetDirection = radialDir.mul(-1);
      if (verticalVel > 0.01) {
        output.targetThrottle = 0.8f;
      } else {
        output.targetThrottle = 0.3f;
      }
    }

    return output;
  }

  // === 计算水平位置差 ===
  Vector2 computeHorizontalDifference(Vector2 position, Vector2 targetPosition) {
    // 简化：2D平面上的差异
    return targetPosition.sub(position);
  }

  // === 预测着陆点（简化）===
  Vector2 predictLandingPosition(Vector2 position, Vector2 velocity, CelestialBody earth, double simTime) {
    // 简化模型：假设自由落体，忽略大气
    double GM = earth.GM;
    double dt = 1.0;
    Vector2 pos = position.clone();
    Vector2 vel = velocity.clone();
    double r = pos.magnitude();

    while (r > earth.radius) {
      Vector2 grav = pos.normalized().mul(-GM / (r * r));
      vel = vel.add(grav.mul(dt));
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
