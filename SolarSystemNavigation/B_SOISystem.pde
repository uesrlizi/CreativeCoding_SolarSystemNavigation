// SOI系统核心类
class SOISystem {
  SolarSystem solarSystem;
  MissionPlanner planner;
  SOIEventLog eventLog;
  OrbitPropagator orbitPropagator;

  // 缓存的SOI计算结果
  HashMap<String, Double> soiRadiusCache;

  SOISystem(SolarSystem ss, MissionPlanner mp) {
    this.solarSystem = ss;
    this.planner = mp;
    this.eventLog = new SOIEventLog();
    this.soiRadiusCache = new HashMap<String, Double>();
    this.orbitPropagator = null;
  }

  void setOrbitPropagator(OrbitPropagator op) {
    this.orbitPropagator = op;
  }

  // 获取SOI事件日志
  SOIEventLog getEventLog() {
    return eventLog;
  }

  // 计算天体的SOI半径（km）
  double calculateSOIRadius(CelestialBody body) {
    return planner.calculateSOI(body);
  }

  // 计算天体相对于主天体的SOI半径
  double calculateSOIRadius(CelestialBody body, CelestialBody primaryBody) {
    if (body.name.equals("Sun")) return AU_KM * 100;

    double GM_body = planner.getTargetGM(body);
    double GM_primary = (primaryBody != null) ? planner.getTargetGM(primaryBody) : GM_SUN;
    double a = body.a;

    // 如果是卫星且主天体是其父天体，使用相对于父天体的轨道
    if (body.parentBody == primaryBody && primaryBody != null) {
      // a已经是相对于父天体的半长轴
    }

    if (GM_primary <= 0 || a <= 0) return 500000.0;

    double massRatio = GM_body / GM_primary;
    return a * Math.pow(massRatio, 2.0/5.0);
  }

  // 计算航天器到天体的距离（km）
  double getDistanceToBody(Spacecraft ship, CelestialBody body) {
    double dx = ship.px - body.px;
    double dy = ship.py - body.py;
    double dz = ship.pz - body.pz;
    return Math.sqrt(dx*dx + dy*dy + dz*dz);
  }

  // 检查航天器是否在某个天体的SOI内
  boolean isInSOI(Spacecraft ship, CelestialBody body) {
    double dist = getDistanceToBody(ship, body);
    double soiRadius = calculateSOIRadius(body);
    return dist <= soiRadius;
  }

  // 查找当前主导航天器的天体
  // 优先检查卫星的SOI，再检查行星的SOI
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

  // 获取SOI边界的绘制点
  double[][] getSOIBoundaryPoints(CelestialBody body, int numPoints) {
    double soiRadius = calculateSOIRadius(body);
    double[][] points = new double[numPoints][2];

    for (int i = 0; i < numPoints; i++) {
      double angle = 2.0 * PI * i / numPoints;
      points[i][0] = body.px + soiRadius * Math.cos(angle);
      points[i][1] = body.py + soiRadius * Math.sin(angle);
    }

    return points;
  }

  // 检查并处理SOI穿越
  // 返回：是否发生了SOI变化
  boolean checkAndProcessSOICrossing(Spacecraft ship, double simTime) {
    CelestialBody oldDominant = ship.currentCentralBody;
    CelestialBody newDominant = findDominantBody(ship);

    // 没有变化
    if (oldDominant == newDominant) return false;

    // 获取航天器的日心位置和速度
    double[] helioPos = new double[]{ship.px, ship.py, ship.pz};
    double[] helioVel = getSpacecraftHelioVelocity(ship);

    if (oldDominant == null && newDominant != null) {
      // 从日心进入天体SOI
      eventLog.logEnterSOI(simTime, newDominant, helioPos, helioVel);
      switchToBodyCentric(ship, newDominant, simTime);
      return true;
    } else if (oldDominant != null && newDominant == null) {
      // 离开天体SOI回到日心
      eventLog.logExitSOI(simTime, oldDominant, helioPos, helioVel);
      switchToHeliocentric(ship, simTime);
      return true;
    } else if (oldDominant != null && newDominant != null) {
      // 从一个天体SOI切换到另一个
      eventLog.logSwitchSOI(simTime, oldDominant, newDominant, helioPos, helioVel);
      // 先切换回日心，再切换到新天体
      switchToHeliocentric(ship, simTime);
      switchToBodyCentric(ship, newDominant, simTime);
      return true;
    }

    return false;
  }

  // 获取航天器的日心速度
  double[] getSpacecraftHelioVelocity(Spacecraft ship) {
    if (ship.currentCentralBody == null) {
      // 已经是日心坐标，从轨道计算速度
      return calculateHeliocentricVelocity(ship);
    } else {
      // 天体中心坐标，需要加上天体的速度
      double[] bodyVel = calculateBodyVelocity(ship.currentCentralBody);
      double[] relVel = ship.vel.clone();
      return new double[]{
        relVel[0] + bodyVel[0],
        relVel[1] + bodyVel[1],
        relVel[2] + bodyVel[2]
      };
    }
  }

  // 从轨道根数计算日心速度
  double[] calculateHeliocentricVelocity(Spacecraft ship) {
    // 简化：从位置和轨道计算速度
    // 实际应该从开普勒轨道计算
    return ship.vel.clone();
  }

  // 计算天体的日心速度
  double[] calculateBodyVelocity(CelestialBody body) {
    if (body.a == 0) return new double[]{0, 0, 0}; // 太阳

    // 简化的圆轨道近似
    double r = body.a; // 简化为圆轨道

    // 当前角度
    double nu = body.currentNu;
    double vMag = Math.sqrt(GM_SUN / r); // 圆轨道速度

    return new double[]{
      -vMag * Math.sin(nu),
      vMag * Math.cos(nu),
      0
    };
  }

  // 切换到天体中心参考系
  void switchToBodyCentric(Spacecraft ship, CelestialBody body, double simTime) {
    // simTime 保留用于未来扩展
    // 获取当前日心位置和速度
    double[] helioPos = new double[]{ship.px, ship.py, ship.pz};
    double[] helioVel = getSpacecraftHelioVelocity(ship);

    // 计算相对于天体的位置和速度
    double[] bodyVel = calculateBodyVelocity(body);

    ship.pos[0] = helioPos[0] - body.px;
    ship.pos[1] = helioPos[1] - body.py;
    ship.pos[2] = helioPos[2] - body.pz;

    ship.vel[0] = helioVel[0] - bodyVel[0];
    ship.vel[1] = helioVel[1] - bodyVel[1];
    ship.vel[2] = helioVel[2] - bodyVel[2];

    ship.currentCentralBody = body;
    ship.earthRef = body; // 兼容性
    ship.earthRelative = true; // 兼容性

    // 更新相对位置别名（指向pos）
    ship.earthRelPos = ship.pos;
    ship.earthRelVel = ship.vel;

    dbgLog("SOI: 切换到 " + body.name + " 中心参考系");
  }

  // 切换到日心参考系
  void switchToHeliocentric(Spacecraft ship, double simTime) {
    // simTime 保留用于未来扩展
    CelestialBody oldBody = ship.currentCentralBody;
    if (oldBody == null) return;

    // 获取当前相对于天体的位置和速度
    double[] relPos = ship.pos.clone();
    double[] relVel = ship.vel.clone();

    // 计算日心位置和速度
    double[] bodyVel = calculateBodyVelocity(oldBody);

    ship.px = oldBody.px + relPos[0];
    ship.py = oldBody.py + relPos[1];
    ship.pz = oldBody.pz + relPos[2];

    // 保存速度用于轨道传播
    ship.vel[0] = relVel[0] + bodyVel[0];
    ship.vel[1] = relVel[1] + bodyVel[1];
    ship.vel[2] = relVel[2] + bodyVel[2];

    // 从日心位置和速度计算轨道根数
    if (orbitPropagator != null) {
      double[] helioPos = new double[]{ship.px, ship.py, ship.pz};
      double[] elements = orbitPropagator.osculatingElements(helioPos, ship.vel, GM_SUN);
      if (elements[0] < Double.MAX_VALUE) {
        ship.a = elements[0];
        ship.e = elements[1];
        ship.i = elements[2];
        ship.omega = elements[3];
        ship.w = elements[4];
        ship.M0 = elements[5] - Math.sqrt(GM_SUN / (ship.a * ship.a * ship.a)) * simTime;
        ship.period = 2.0 * PI * Math.sqrt(ship.a * ship.a * ship.a / GM_SUN);
      }
    }

    ship.currentCentralBody = null;
    ship.earthRef = null; // 兼容性
    ship.earthRelative = false; // 兼容性

    // 更新相对位置别名（指向pos）
    ship.earthRelPos = ship.pos;
    ship.earthRelVel = ship.vel;

    dbgLog("SOI: 切换到日心参考系");
  }

  // 获取航天器当前的SOI状态描述
  String getSOIStatusString(Spacecraft ship) {
    CelestialBody dominant = ship.currentCentralBody;
    if (dominant == null) {
      return "太阳引力主导区域";
    } else {
      double dist = getDistanceToBody(ship, dominant);
      double soiRadius = calculateSOIRadius(dominant);
      double percent = (dist / soiRadius) * 100.0;
      return String.format("在 %s SOI 内 (%.1f%%)", dominant.name, percent);
    }
  }

  // 获取天体的SOI颜色（用于可视化）
  int getSOIColor(CelestialBody body) {
    if (body.name.equals("Earth")) return color(70, 130, 230, 80);
    if (body.name.equals("Moon")) return color(200, 200, 210, 80);
    if (body.name.equals("Mars")) return color(210, 100, 60, 80);
    if (body.name.equals("Venus")) return color(230, 200, 130, 80);
    if (body.name.equals("Jupiter")) return color(210, 180, 140, 80);
    if (body.name.equals("Saturn")) return color(220, 200, 150, 80);
    if (body.name.equals("Uranus")) return color(170, 220, 230, 80);
    if (body.name.equals("Neptune")) return color(60, 100, 230, 80);
    return color(150, 150, 150, 80);
  }
}
