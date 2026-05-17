// ============================================================
//  PhysicsSystem - 物理系统
//  计算受力，根据状态决定运动模式，统一处理三种运动模式
// ============================================================

// 运动模式枚举
enum MotionMode { FIXED, ORBITAL, INTEGRATED }

class PhysicsSystem {
  // 子系统
  private PhysicsEngine physicsEngine;
  private OrbitPropagator orbitPropagator;
  private AtmosphereModel atmosphereModel;
  private SpacecraftForceModel forceModel;

  // 轨道传播状态
  private double orbitStartTime;
  private double orbitAngle;

  // 上一帧的运动模式，用于检测切换
  private MotionMode previousMode;

  PhysicsSystem() {
    physicsEngine = new PhysicsEngine();
    orbitPropagator = new OrbitPropagator();
    atmosphereModel = new AtmosphereModel();
    forceModel = new SpacecraftForceModel();
    orbitStartTime = 0;
    orbitAngle = 0;
    previousMode = null;
  }

  // ============================================================
  //  模式判定
  // ============================================================

  MotionMode determineMotionMode(Spacecraft ship) {
    if (ship.isFixed) {
      return MotionMode.FIXED;
    }

    if (ship.thrustActive || hasAtmosphericDrag(ship)) {
      return MotionMode.INTEGRATED;
    }

    return MotionMode.ORBITAL;
  }

  private boolean hasAtmosphericDrag(Spacecraft ship) {
    if (ship.currentCentralBody == null) return false;
    double alt = atmosphereModel.altitudeAboveSurface(ship.pos, ship.currentCentralBody);
    return atmosphereModel.inAtmosphere(ship.currentCentralBody, alt);
  }

  // ============================================================
  //  主更新
  // ============================================================

  void update(Spacecraft ship, double simDt, double simTime,
              boolean thrustActive, double thrustDirection) {
    MotionMode mode = determineMotionMode(ship);

    // 处理模式切换：INTEGRATED → ORBITAL 时计算轨道根数
    if (previousMode == MotionMode.INTEGRATED && mode == MotionMode.ORBITAL) {
      if (ship.currentCentralBody != null) {
        // 天体中心模式 - 计算轨道根数并存入 ship
        double GM = ship.currentCentralBody.name.equals("Earth") ? MissionPlanner.GM_EARTH : GM_SUN;
        double[] elements = orbitPropagator.osculatingElements(ship.pos, ship.vel, GM);
        if (elements[0] < Double.MAX_VALUE) {
          ship.a = elements[0];
          ship.e = elements[1];
          ship.orbitAngle = Math.atan2(ship.pos[1], ship.pos[0]);
          ship.launchPadAngle = ship.orbitAngle;
          ship.orbitStartTime = simTime;
        }
      } else {
        // 日心模式
        double[] helioPos = new double[]{ship.px, ship.py, ship.pz};
        double[] elements = orbitPropagator.osculatingElements(helioPos, ship.vel, GM_SUN);
        if (elements[0] < Double.MAX_VALUE) {
          ship.a = elements[0];
          ship.e = elements[1];
          ship.i = elements[2];
          ship.omega = elements[3];
          ship.w = elements[4];
          double n = Math.sqrt(GM_SUN / (ship.a * ship.a * ship.a));
          ship.M0 = elements[5] - n * simTime;
          ship.period = 2.0 * PI / n;
        }
      }
      dbgLog("Physics: INTEGRATED→ORBITAL, a=" + (float)(ship.a - MissionPlanner.EARTH_RADIUS_KM) +
             "km alt, e=" + (float)ship.e);
    }
    previousMode = mode;

    switch (mode) {
      case FIXED:
        updateFixed(ship, simTime);
        break;
      case ORBITAL:
        updateOrbital(ship, simDt, simTime);
        break;
      case INTEGRATED:
        updateIntegrated(ship, simDt, simTime, thrustActive, thrustDirection);
        break;
    }

    // 在所有模式下都检查 SOI 切换
    if (soiSystem != null) {
      soiSystem.checkAndProcessSOICrossing(ship, simTime);
    }
  }

  // ============================================================
  //  FIXED 模式：位置固定在发射台，随地球自转
  // ============================================================

  private void updateFixed(Spacecraft ship, double simTime) {
    // 速度为0
    ship.vel[0] = 0;
    ship.vel[1] = 0;
    ship.vel[2] = 0;

    // 随地球自转而转动（保持固定在发射台位置）
    if (ship.currentCentralBody != null) {
      double angle = ship.launchPadAngle;

      double startRadius = MissionPlanner.EARTH_RADIUS_KM + ship.launchAltitude;
      ship.pos[0] = startRadius * Math.cos(angle);
      ship.pos[1] = startRadius * Math.sin(angle);
      ship.pos[2] = 0;
      ship.orbitAngle = angle;
      ship.earthOrbitAngle = angle;

      // 更新世界位置
      ship.px = ship.currentCentralBody.px + ship.pos[0];
      ship.py = ship.currentCentralBody.py + ship.pos[1];
      ship.pz = ship.currentCentralBody.pz + ship.pos[2];
    }
  }

  // ============================================================
  //  ORBITAL 模式：轨道传播
  // ============================================================

  private void updateOrbital(Spacecraft ship, double simDt, double simTime) {
    if (ship.currentCentralBody != null) {
      // 天体相对模式：使用 ship 中存储的轨道参数传播
      double GM = MissionPlanner.GM_EARTH;

      // 如果 orbitStartTime 为 0，初始化一下（防止直接进入 ORBITAL 状态）
      if (ship.orbitStartTime == 0) {
        ship.orbitStartTime = simTime;
        ship.orbitAngle = Math.atan2(ship.pos[1], ship.pos[0]);
        ship.launchPadAngle = ship.orbitAngle;
      }

      double elapsed = simTime - ship.orbitStartTime;
      double n = Math.sqrt(GM / (ship.a * ship.a * ship.a)); // 平均角速度

      // 计算切换时刻的平近点角 M0
      // 先算切换时刻的真近点角和偏近点角
      double r0 = Math.sqrt(ship.pos[0] * ship.pos[0] + ship.pos[1] * ship.pos[1]);
      double cosNu0 = (ship.a * (1 - ship.e * ship.e) / r0 - 1) / ship.e;
      cosNu0 = Math.max(-1, Math.min(1, cosNu0)); // 限制范围防止数值问题
      double sinNu0 = Math.sqrt(1 - cosNu0 * cosNu0);
      // 确定正确的符号
      double v_r0 = (ship.pos[0] * ship.vel[0] + ship.pos[1] * ship.vel[1]) / r0;
      if (v_r0 < 0) sinNu0 = -sinNu0;
      double nu0 = Math.atan2(sinNu0, cosNu0);
      // 偏近点角
      double cosE0 = (ship.e + cosNu0) / (1 + ship.e * cosNu0);
      double sinE0 = (Math.sqrt(1 - ship.e * ship.e) * sinNu0) / (1 + ship.e * cosNu0);
      double E0 = Math.atan2(sinE0, cosE0);
      // 平近点角
      double M0 = E0 - ship.e * Math.sin(E0);

      // 当前平近点角
      double M = M0 + n * elapsed;

      // 求解偏近点角（牛顿-拉夫逊法）
      double E = M;
      for (int iter = 0; iter < 10; iter++) {
        double dE = (M - E + ship.e * Math.sin(E)) / (1 - ship.e * Math.cos(E));
        E += dE;
        if (Math.abs(dE) < 1e-12) break;
      }

      // 真近点角
      double cosNu = (Math.cos(E) - ship.e) / (1 - ship.e * Math.cos(E));
      double sinNu = (Math.sqrt(1 - ship.e * ship.e) * Math.sin(E)) / (1 - ship.e * Math.cos(E));
      double nu = Math.atan2(sinNu, cosNu);

      // 当前距离
      double r = ship.a * (1 - ship.e * Math.cos(E));

      // 轨道角度 = 初始角度 + 真近点角变化
      orbitAngle = ship.launchPadAngle + (nu - nu0);
      ship.orbitAngle = orbitAngle;
      ship.earthOrbitAngle = orbitAngle;

      // 更新位置
      ship.pos[0] = r * Math.cos(orbitAngle);
      ship.pos[1] = r * Math.sin(orbitAngle);
      ship.pos[2] = 0;

      // 计算速度
      double h = Math.sqrt(GM * ship.a * (1 - ship.e * ship.e)); // 角动量
      double v_r = (GM * ship.e * Math.sin(E)) / h; // 径向速度
      double v_t = h / r; // 切向速度
      ship.vel[0] = v_r * Math.cos(orbitAngle) - v_t * Math.sin(orbitAngle);
      ship.vel[1] = v_r * Math.sin(orbitAngle) + v_t * Math.cos(orbitAngle);
      ship.vel[2] = 0;

      // 更新高度
      ship.launchAltitude = r - MissionPlanner.EARTH_RADIUS_KM;

      // 更新世界位置
      ship.px = ship.currentCentralBody.px + ship.pos[0];
      ship.py = ship.currentCentralBody.py + ship.pos[1];
      ship.pz = ship.currentCentralBody.pz + ship.pos[2];
    } else {
      // 日心模式：使用开普勒轨道传播
      orbitPropagator.propagateHeliocentric(ship, simTime);
    }
  }

  // ============================================================
  //  INTEGRATED 模式：物理积分
  // ============================================================

  private void updateIntegrated(Spacecraft ship, double simDt, double simTime,
                                boolean thrustActive, double thrustDirection) {
    // 设置力模型状态
    forceModel.setState(ship.pos, ship.vel, thrustActive,
                        ship.state, ship.currentCentralBody,
                        simTime, ship.launchStartTime);

    // 使用物理引擎积分
    physicsEngine.integrate(ship.pos, ship.vel, simDt, forceModel);

    // 更新派生值
    if (ship.currentCentralBody != null) {
      double rx = ship.pos[0], ry = ship.pos[1];
      double r = Math.sqrt(rx * rx + ry * ry);
      ship.launchAltitude = r - MissionPlanner.EARTH_RADIUS_KM;
      ship.orbitAngle = Math.atan2(ry, rx);
      ship.earthOrbitAngle = ship.orbitAngle;
    }

    // 更新世界位置
    if (ship.currentCentralBody != null) {
      ship.px = ship.currentCentralBody.px + ship.pos[0];
      ship.py = ship.currentCentralBody.py + ship.pos[1];
      ship.pz = ship.currentCentralBody.pz + ship.pos[2];
    }

    // 重置轨道传播时间戳，以便切回 ORBITAL 模式时能正确同步
    orbitStartTime = 0;
  }

  // ============================================================
  //  重置轨道传播状态
  // ============================================================

  void resetOrbitPropagation() {
    orbitStartTime = 0;
  }
}
