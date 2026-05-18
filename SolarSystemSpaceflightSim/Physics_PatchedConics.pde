// ============================================================
//  Physics_PatchedConics - 补丁圆锥系统
//  处理SOI检测、参考系切换、轨道根数与状态向量转换
// ============================================================

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
      ship.orbit = new Orbit(0, 0, 0, 0, 0, null);
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
}
