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
  static final int MAX_PATCHED_SEGMENTS = 8;

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

  Trajectory buildPatchedOrbit(Spacecraft ship, double simTime, double duration) {
    Trajectory trajectory = new Trajectory();
    trajectory.startTime = simTime;
    trajectory.endTime = simTime + duration;

    CelestialBody currentBody = findDominantBody(ship);
    trajectory.primaryBody = currentBody;
    Vector2 worldPos = new Vector2(ship.worldX, ship.worldY);
    Vector2 worldVel = new Vector2(ship.worldVelX, ship.worldVelY);
    double currentTime = simTime;
    double remainingDuration = duration;
    int segmentCount = 0;

    while (remainingDuration > 0 && segmentCount < MAX_PATCHED_SEGMENTS) {
      Vector2 localPos = worldToLocalPosition(worldPos, currentBody, currentTime);
      Vector2 localVel = worldToLocalVelocity(worldVel, currentBody, currentTime);
      Orbit orbit = Orbit_fromStateVector(localPos, localVel, currentBody, currentTime);
      if (orbit == null || !isUsablePeriod(orbit.period)) break;

      Spacecraft tempShip = new Spacecraft(ship.name, ship.col);
      tempShip.referenceBody = currentBody;
      tempShip.orbit = orbit;
      tempShip.stateVector.position = localPos;
      tempShip.stateVector.velocity = localVel;
      tempShip.worldX = worldPos.x;
      tempShip.worldY = worldPos.y;
      tempShip.worldVelX = worldVel.x;
      tempShip.worldVelY = worldVel.y;

      double segmentLimit = Math.min(remainingDuration, orbit.period);
      SOITraversal traversal = predictSOITraversal(tempShip, segmentLimit, currentTime);
      double segmentDuration = segmentLimit;
      if (traversal.willTraverse && traversal.timeToTraversal > 0 && traversal.timeToTraversal < segmentLimit) {
        segmentDuration = traversal.timeToTraversal;
      }
      if (segmentDuration <= 0) break;

      trajectory.segments.add(new OrbitSegment(orbit, currentTime, currentTime + segmentDuration, currentBody));
      addApsideEvents(trajectory, orbit, currentBody, currentTime, segmentDuration);

      if (!traversal.willTraverse || traversal.timeToTraversal > segmentLimit) break;

      double eventTime = currentTime + segmentDuration;
      Vector2 eventLocalPos = orbit.getPositionAtTime(eventTime);
      Vector2 eventWorldPos = localToWorldPosition(eventLocalPos, currentBody, eventTime);
      Vector2 eventWorldVel = localToWorldVelocity(orbit.getVelocityAtTime(eventTime), currentBody, eventTime);
      String eventType = (traversal.enterBody != null) ? "soi_enter" : "soi_exit";
      TrajectoryEvent event = new TrajectoryEvent(eventTime, eventLocalPos, eventType);
      event.relatedBody = (traversal.enterBody != null) ? traversal.enterBody : traversal.exitBody;
      event.referenceBody = currentBody;
      trajectory.events.add(event);

      worldPos = eventWorldPos;
      worldVel = eventWorldVel;
      currentBody = getNextReferenceBodyAfterTraversal(currentBody, traversal);
      currentTime = eventTime;
      remainingDuration -= segmentDuration;
      segmentCount++;
    }

    trajectory.endTime = currentTime;
    if (trajectory.segments.size() > 0) {
      trajectory.endTime = trajectory.segments.get(trajectory.segments.size() - 1).endTime;
    }
    return trajectory;
  }

  void applyActiveSegment(Spacecraft ship, double simTime) {
    if (ship.patchedOrbit == null) return;
    OrbitSegment seg = ship.patchedOrbit.getSegmentAt(simTime);
    if (seg == null || seg.orbit == null) return;

    ship.orbit = seg.orbit;
    ship.referenceBody = seg.referenceBody;
    Vector2 localPos = seg.orbit.getPositionAtTime(simTime);
    Vector2 localVel = seg.orbit.getVelocityAtTime(simTime);
    ship.stateVector.position = localPos;
    ship.stateVector.velocity = localVel;
    Vector2 worldPos = localToWorldPosition(localPos, seg.referenceBody, simTime);
    Vector2 worldVel = localToWorldVelocity(localVel, seg.referenceBody, simTime);
    ship.worldX = worldPos.x;
    ship.worldY = worldPos.y;
    ship.worldVelX = worldVel.x;
    ship.worldVelY = worldVel.y;
  }

  Vector2 worldToLocalPosition(Vector2 worldPos, CelestialBody body, double simTime) {
    if (body == null) return worldPos.clone();
    Vector2 bodyPos = getBodyPositionAtTime(body, simTime);
    return worldPos.sub(bodyPos);
  }

  Vector2 worldToLocalVelocity(Vector2 worldVel, CelestialBody body, double simTime) {
    if (body == null) return worldVel.clone();
    return worldVel.sub(getBodyVelocity(body, simTime));
  }

  Vector2 localToWorldPosition(Vector2 localPos, CelestialBody body, double simTime) {
    if (body == null) return localPos.clone();
    return getBodyPositionAtTime(body, simTime).add(localPos);
  }

  Vector2 localToWorldVelocity(Vector2 localVel, CelestialBody body, double simTime) {
    if (body == null) return localVel.clone();
    return getBodyVelocity(body, simTime).add(localVel);
  }

  boolean isUsablePeriod(double period) {
    return !Double.isNaN(period) && !Double.isInfinite(period) && period > 0;
  }

  CelestialBody getNextReferenceBodyAfterTraversal(CelestialBody currentBody, SOITraversal traversal) {
    if (traversal.enterBody != null) return traversal.enterBody;
    if (currentBody != null && currentBody.parentBody != null && currentBody.parentBody != solarSystem.sun) {
      return currentBody.parentBody;
    }
    return null;
  }

  private void addApsideEvents(Trajectory trajectory, Orbit orbit, CelestialBody body, double simTime, double duration) {
    if (orbit.e < 0.0001) return;

    double timeToPe = orbit.getTimeToPeriapsis(simTime);
    if (timeToPe > 0 && timeToPe <= duration) {
      double peTime = simTime + timeToPe;
      TrajectoryEvent event = new TrajectoryEvent(peTime, orbit.getPositionAtTime(peTime), "periapsis");
      event.referenceBody = body;
      trajectory.events.add(event);
    }

    double timeToAp = orbit.getTimeToApoapsis(simTime);
    if (timeToAp > 0 && timeToAp <= duration) {
      double apTime = simTime + timeToAp;
      TrajectoryEvent event = new TrajectoryEvent(apTime, orbit.getPositionAtTime(apTime), "apoapsis");
      event.referenceBody = body;
      trajectory.events.add(event);
    }
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
    double t = simTime + dt;
    if (ship.orbit != null) {
      Vector2 localPos = ship.orbit.getPositionAtTime(t);
      return localToWorldPosition(localPos, ship.referenceBody, t);
    }

    return new Vector2(
      ship.worldX + ship.worldVelX * dt,
      ship.worldY + ship.worldVelY * dt
    );
  }

  private Vector2 getBodyPositionAtTime(CelestialBody body, double simTime) {
    return new Vector2(body.px, body.py);
  }
}
