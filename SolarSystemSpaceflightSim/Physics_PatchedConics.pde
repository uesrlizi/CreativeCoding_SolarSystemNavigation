// ============================================================
//  Physics_PatchedConics - 补丁圆锥系统
//  处理SOI检测、参考系切换、轨道根数与状态向量转换
// ============================================================

class SOITraversal {
  boolean willTraverse;
  double timeToTraversal;
  double traversalTime;
  CelestialBody exitBody;
  CelestialBody enterBody;
  Vector2 traversalPosition;

  SOITraversal() {
    this.willTraverse = false;
    this.timeToTraversal = Double.MAX_VALUE;
    this.traversalTime = Double.MAX_VALUE;
    this.exitBody = null;
    this.enterBody = null;
    this.traversalPosition = null;
  }
}

class PatchedConicsSystem {
  CelestialSystem solarSystem;

  PatchedConicsSystem(CelestialSystem ss) {
    this.solarSystem = ss;
  }

  // ============================================================
  //  计算SOI半径
  // ============================================================

  double calculateSOIRadius(CelestialBody body) {
    if (body.name.equals("Sun")) return AU_KM * 100;

    double GM_body = body.GM;
    double GM_primary = GM_SUN;
    double a = body.a;

    if (body.parentBody != null && body.parentBody != solarSystem.sun) {
      GM_primary = body.parentBody.GM;
    }

    if (GM_primary <= 0 || a <= 0) return 500000.0;

    double massRatio = GM_body / GM_primary;
    return a * Math.pow(massRatio, 2.0/5.0);
  }

  // ============================================================
  //  查找主导天体
  // ============================================================

  CelestialBody findDominantBody(Spacecraft ship) {
    CelestialBody dominantBody = null;
    double minDistRatio = Double.MAX_VALUE;

    // 先检查所有卫星（更小的SOI优先）
    for (CelestialBody moon : solarSystem.moons) {
      double dist = getDistanceToBody(ship, moon);
      double soiRadius = calculateSOIRadius(moon);
      if (dist <= soiRadius) {
        double distRatio = dist / soiRadius;
        if (distRatio < minDistRatio) {
          minDistRatio = distRatio;
          dominantBody = moon;
        }
      }
    }

    // 如果不在任何卫星SOI内，检查行星
    if (dominantBody == null) {
      for (CelestialBody planet : solarSystem.planets) {
        double dist = getDistanceToBody(ship, planet);
        double soiRadius = calculateSOIRadius(planet);
        if (dist <= soiRadius) {
          double distRatio = dist / soiRadius;
          if (distRatio < minDistRatio) {
            minDistRatio = distRatio;
            dominantBody = planet;
          }
        }
      }
    }

    return dominantBody; // null表示在太阳引力主导区域
  }

  double getDistanceToBody(Spacecraft ship, CelestialBody body) {
    double dx = ship.worldX - body.px;
    double dy = ship.worldY - body.py;
    return Math.sqrt(dx*dx + dy*dy);
  }

  // ============================================================
  //  检查并处理SOI穿越
  //  返回：是否发生了SOI变化
  // ============================================================

  boolean checkAndProcessSOICrossing(Spacecraft ship, double simTime) {
    CelestialBody oldDominant = ship.referenceBody;
    CelestialBody newDominant = findDominantBody(ship);

    // 没有变化
    if (oldDominant == newDominant) return false;

    if (oldDominant == null && newDominant != null) {
      // 从日心进入天体SOI
      switchToBodyCentric(ship, newDominant, simTime);
      return true;
    } else if (oldDominant != null && newDominant == null) {
      // 离开天体SOI回到日心
      switchToHeliocentric(ship, simTime);
      return true;
    } else if (oldDominant != null && newDominant != null) {
      // 从一个天体SOI切换到另一个
      switchToHeliocentric(ship, simTime);
      switchToBodyCentric(ship, newDominant, simTime);
      return true;
    }

    return false;
  }

  // ============================================================
  //  切换到天体中心参考系
  // ============================================================

  void switchToBodyCentric(Spacecraft ship, CelestialBody body, double simTime) {
    Vector2 bodyVel = getBodyVelocity(body, simTime);

    ship.stateVector.position.x = ship.worldX - body.px;
    ship.stateVector.position.y = ship.worldY - body.py;
    ship.stateVector.velocity.x = ship.worldVelX - bodyVel.x;
    ship.stateVector.velocity.y = ship.worldVelY - bodyVel.y;

    ship.referenceBody = body;

    // 从状态向量计算轨道根数
    if (ship.orbit == null) {
      ship.orbit = new Orbit(0, 0, 0, 0, 0.0, 0, null);
    }
    Orbit newOrbit = Orbit_fromStateVector(ship.stateVector.position, ship.stateVector.velocity, body, simTime);
    if (newOrbit != null) {
      ship.orbit = newOrbit;
    }
  }

  // ============================================================
  //  切换到日心参考系
  // ============================================================

  void switchToHeliocentric(Spacecraft ship, double simTime) {
    CelestialBody oldBody = ship.referenceBody;
    if (oldBody == null) return;

    Vector2 bodyVel = getBodyVelocity(oldBody, simTime);

    ship.worldX = oldBody.px + ship.stateVector.position.x;
    ship.worldY = oldBody.py + ship.stateVector.position.y;
    ship.worldVelX = ship.stateVector.velocity.x + bodyVel.x;
    ship.worldVelY = ship.stateVector.velocity.y + bodyVel.y;

    ship.referenceBody = null;
  }

  // ============================================================
  //  计算天体的日心速度
  // ============================================================

  Vector2 getBodyVelocity(CelestialBody body, double simTime) {
    if (body.a == 0) return new Vector2(0, 0);

    double n = 2.0 * PI / body.period;
    double M = (body.M0 + n * simTime) % (2.0 * PI);
    if (M < 0) M += 2.0 * PI;

    double E = solveKepler(M, body.e);
    double nu = trueAnomaly(E, body.e);

    double r = body.a * (1 - body.e * body.e) / (1 + body.e * Math.cos(nu));
    double GM = (body.parentBody != null) ? body.parentBody.GM : GM_SUN;
    double h = Math.sqrt(GM * body.a * (1 - body.e * body.e));
    double v_r = (GM * body.e * Math.sin(nu)) / h;
    double v_t = h / r;
    double theta = body.w + nu;

    Vector2 vel = new Vector2(
      v_r * Math.cos(theta) - v_t * Math.sin(theta),
      v_r * Math.sin(theta) + v_t * Math.cos(theta)
    );

    if (body.parentBody != null && body.parentBody != solarSystem.sun) {
      Vector2 parentVel = getBodyVelocity(body.parentBody, simTime);
      vel = vel.add(parentVel);
    }

    return vel;
  }

  // ============================================================
  //  从状态向量计算轨道根数
  //  返回 [a (km), e, w (rad), M0 (rad)]
  // ============================================================

  double[] stateToOsculatingElements(Vector2 pos, Vector2 vel, double GM) {
    double rx = pos.x, ry = pos.y;
    double vx = vel.x, vy = vel.y;
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double energy = v2 / 2.0 - GM / r;

    if (energy >= 0) {
      return new double[]{Double.MAX_VALUE, Double.MAX_VALUE, 0, 0};
    }

    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    double e2 = 1.0 - h * h / (GM * a);
    double e = Math.sqrt(Math.max(0.0, e2));

    double vRad = (rx * vx + ry * vy) / r;
    double cosNu = (a * (1.0 - e * e) / r - 1.0) / e;
    cosNu = Math.max(-1.0, Math.min(1.0, cosNu));
    double nu = Math.acos(cosNu);
    if (vRad < 0) nu = 2.0 * PI - nu;

    double w = Math.atan2(ry, rx) - nu;
    while (w < 0) w += 2.0 * PI;
    while (w >= 2.0 * PI) w -= 2.0 * PI;

    double E = 2 * Math.atan2(Math.sqrt(1 - e) * Math.sin(nu / 2), Math.sqrt(1 + e) * Math.cos(nu / 2));
    double M0 = E - e * Math.sin(E);

    return new double[]{a, e, w, M0};
  }

  // ============================================================
  //  从轨道根数计算状态向量
  // ============================================================

  void osculatingElementsToState(double[] elements, double GM, double simTime,
                                  Vector2 posOut, Vector2 velOut) {
    double a = elements[0];
    double e = elements[1];
    double w = elements[2];
    double M0 = elements[3];

    double period = 2.0 * PI * Math.sqrt(a * a * a / GM);
    double n = 2.0 * PI / period;
    double M = (M0 + n * simTime) % (2.0 * PI);
    if (M < 0) M += 2.0 * PI;

    double E = solveKepler(M, e);
    double nu = trueAnomaly(E, e);

    double r = a * (1 - e * e) / (1 + e * Math.cos(nu));
    double theta = w + nu;
    posOut.x = r * Math.cos(theta);
    posOut.y = r * Math.sin(theta);

    double h = Math.sqrt(GM * a * (1 - e * e));
    double v_r = (GM * e * Math.sin(nu)) / h;
    double v_t = h / r;
    velOut.x = v_r * Math.cos(theta) - v_t * Math.sin(theta);
    velOut.y = v_r * Math.sin(theta) + v_t * Math.cos(theta);
  }

  // ============================================================
  //  SOI穿越预测
  // ============================================================

  SOITraversal predictSOITraversal(Spacecraft ship, double dtMax, double simTime) {
    SOITraversal result = new SOITraversal();

    CelestialBody currentBody = ship.referenceBody;
    double earliestTime = Double.MAX_VALUE;
    CelestialBody earliestEnterBody = null;

    // 收集候选天体
    List<CelestialBody> candidates = new ArrayList<CelestialBody>();

    if (currentBody == null) {
      // 当前在日心，检查所有行星和卫星
      for (CelestialBody planet : solarSystem.planets) {
        candidates.add(planet);
      }
      for (CelestialBody moon : solarSystem.moons) {
        candidates.add(moon);
      }
    } else {
      // 当前在天体SOI内，检查：
      // 1. 该天体的卫星（如果有的话）
      for (CelestialBody moon : solarSystem.moons) {
        if (moon.parentBody == currentBody) {
          candidates.add(moon);
        }
      }
      // 2. 检查是否会离开到日心（用null表示太阳）
      candidates.add(null);
    }

    // 对每个候选计算穿越时间
    for (CelestialBody candidate : candidates) {
      double time = calculateTimeToSOIBoundary(ship, currentBody, candidate, dtMax, simTime);
      if (time > 0 && time < earliestTime && time <= dtMax) {
        earliestTime = time;
        earliestEnterBody = candidate;
      }
    }

    if (earliestTime < Double.MAX_VALUE) {
      result.willTraverse = true;
      result.timeToTraversal = earliestTime;
      result.traversalTime = simTime + earliestTime;
      result.exitBody = currentBody;
      result.enterBody = earliestEnterBody;

      // 计算穿越位置
      result.traversalPosition = calculatePositionAtTime(ship, earliestTime, simTime);
    }

    return result;
  }

  private double calculateTimeToSOIBoundary(Spacecraft ship, CelestialBody currentBody,
                                             CelestialBody targetBody, double dtMax, double simTime) {
    // 先检查端点是否有穿越
    boolean startInside = isInsideSOIAtTime(ship, currentBody, targetBody, 0, simTime);
    boolean endInside = isInsideSOIAtTime(ship, currentBody, targetBody, dtMax, simTime);

    if (startInside == endInside) {
      return Double.MAX_VALUE; // 没有穿越
    }

    // 使用二分法精确求解
    double low = 0;
    double high = dtMax;
    double tolerance = 1.0; // 1秒容差

    for (int i = 0; i < 50; i++) {
      double mid = (low + high) / 2;
      boolean midInside = isInsideSOIAtTime(ship, currentBody, targetBody, mid, simTime);

      if (midInside != startInside) {
        high = mid;
      } else {
        low = mid;
      }

      if (high - low < tolerance) {
        break;
      }
    }

    return (low + high) / 2;
  }

  private boolean isInsideSOIAtTime(Spacecraft ship, CelestialBody currentBody,
                                     CelestialBody targetBody, double dt, double simTime) {
    Vector2 shipPos = calculatePositionAtTime(ship, dt, simTime);

    if (targetBody == null) {
      // 检查是否离开到日心
      if (currentBody == null) return true; // 已经在日心
      double soi = calculateSOIRadius(currentBody);
      Vector2 bodyPos = getBodyPositionAtTime(currentBody, simTime + dt);
      double dist = shipPos.distance(bodyPos);
      return dist > soi; // 离开SOI = "在太阳引力主导区域内"
    } else {
      // 检查是否进入目标天体SOI
      double soi = calculateSOIRadius(targetBody);
      Vector2 bodyPos = getBodyPositionAtTime(targetBody, simTime + dt);
      double dist = shipPos.distance(bodyPos);
      return dist <= soi;
    }
  }

  private Vector2 calculatePositionAtTime(Spacecraft ship, double dt, double simTime) {
    if (ship.orbit != null && ship.referenceBody != null) {
      // 使用轨道预测
      return ship.orbit.getPositionAtTime(simTime + dt);
    } else {
      // 简单线性外推（仅用于Off-rails模式的粗略预测）
      return new Vector2(
        ship.worldX + ship.worldVelX * dt,
        ship.worldY + ship.worldVelY * dt
      );
    }
  }

  private Vector2 getBodyPositionAtTime(CelestialBody body, double simTime) {
    // 获取天体在指定时间的位置
    if (body.orbit != null && body.parentBody != null) {
      Vector2 pos = body.orbit.getPositionAtTime(simTime);
      return new Vector2(
        body.parentBody.px + pos.x,
        body.parentBody.py + pos.y
      );
    } else {
      // 使用当前位置作为近似（对于太阳或无轨道的天体）
      return new Vector2(body.px, body.py);
    }
  }
}
