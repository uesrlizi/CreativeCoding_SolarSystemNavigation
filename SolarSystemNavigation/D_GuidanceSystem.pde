// ============================================================
//  GuidanceSystem - 制导系统
//  包含上升段和圆化段的制导状态机，只计算制导命令，不做物理积分
// ============================================================

class GuidanceSystem {
  // 制导阶段状态
  boolean guidanceActive;
  double burnStartTime;
  double circBurnDuration;
  boolean apoapsisReached;
  double estimatedThrustFraction;

  // TMI/TOI 制导状态
  private boolean tmiBurnActive;
  private boolean toiBurnActive;
  private double tmiDeltaVNeeded;
  private double tmiDeltaVApplied;
  private double toiDeltaVNeeded;
  private double toiDeltaVApplied;
  private CelestialBody transferTarget;

  // 子系统引用
  private FlightSystem flightSystem;

  // 引用的系统
  FlightComputer flightComputer;
  AtmosphereModel atmosphereModel;

  GuidanceSystem(FlightSystem flightSystem) {
    this.flightSystem = flightSystem;
    flightComputer = new FlightComputer();
    atmosphereModel = new AtmosphereModel();
    reset();
  }

  void reset() {
    guidanceActive = false;
    burnStartTime = 0;
    circBurnDuration = 0;
    apoapsisReached = false;
    estimatedThrustFraction = 1.0;
    tmiBurnActive = false;
    toiBurnActive = false;
    tmiDeltaVNeeded = 0;
    tmiDeltaVApplied = 0;
    toiDeltaVNeeded = 0;
    toiDeltaVApplied = 0;
    transferTarget = null;
  }

  // ============================================================
  //  TMI 制导接口
  // ============================================================

  void startTMIBurn(double deltaV, CelestialBody target) {
    tmiBurnActive = true;
    tmiDeltaVNeeded = deltaV;
    tmiDeltaVApplied = 0;
    transferTarget = target;
    burnStartTime = 0;
    dbgLog("Guidance: TMI burn started, deltaV=" + (float)deltaV);
  }

  void startTOIBurn(double deltaV) {
    toiBurnActive = true;
    toiDeltaVNeeded = deltaV;
    toiDeltaVApplied = 0;
    burnStartTime = 0;
    dbgLog("Guidance: TOI burn started, deltaV=" + (float)deltaV);
  }

  // ============================================================
  //  主更新方法 - 处理上升段、圆化段、TMI/TOI
  // ============================================================
  void update(Spacecraft ship, double simDt, double simTime) {
    if (ship.state == ShipState.LAUNCHING) {
      updateLaunching(ship, simDt, simTime);
    } else if (ship.state == ShipState.CIRCULARIZING) {
      updateCircularizing(ship, simDt, simTime);
    } else if (ship.state == ShipState.TMI_BURN) {
      updateTMIBurn(ship, simDt, simTime);
    } else if (ship.state == ShipState.TOI_BURN) {
      updateTOIBurn(ship, simDt, simTime);
    }
  }

  // ============================================================
  //  TMI 燃烧制导
  // ============================================================
  private void updateTMIBurn(Spacecraft ship, double simDt, double simTime) {
    if (!tmiBurnActive) {
      flightSystem.setThrustCommand(false, 0.0);
      return;
    }

    // 切向推力（速度方向）
    double[] thrustDir = flightComputer.tangentialThrustDirection(ship.vel, true);
    double thrustAngle = Math.atan2(thrustDir[1], thrustDir[0]);

    // 累加 delta-V
    if (ship.thrustActive) {
      double deltaVThisStep = FlightComputer.THRUST_ACCEL * simDt;
      tmiDeltaVApplied += deltaVThisStep;
      ship.tmiAccumulatedDV = tmiDeltaVApplied;
    }

    // 检查是否完成
    boolean shouldContinue = tmiDeltaVApplied < tmiDeltaVNeeded;
    flightSystem.setThrustCommand(shouldContinue, thrustAngle);

    if (!shouldContinue) {
      tmiBurnActive = false;
      // 状态机转换由 LaunchController 处理
    }
  }

  // ============================================================
  //  TOI 燃烧制导
  // ============================================================
  private void updateTOIBurn(Spacecraft ship, double simDt, double simTime) {
    if (!toiBurnActive) {
      flightSystem.setThrustCommand(false, 0.0);
      return;
    }

    // 切向推力（速度方向）
    double[] thrustDir = flightComputer.tangentialThrustDirection(ship.vel, true);
    double thrustAngle = Math.atan2(thrustDir[1], thrustDir[0]);

    // 累加 delta-V
    if (ship.thrustActive) {
      double deltaVThisStep = FlightComputer.THRUST_ACCEL * simDt;
      toiDeltaVApplied += deltaVThisStep;
      ship.toiAccumulatedDV = toiDeltaVApplied;
    }

    // 检查是否完成
    boolean shouldContinue = toiDeltaVApplied < toiDeltaVNeeded;
    flightSystem.setThrustCommand(shouldContinue, thrustAngle);

    if (!shouldContinue) {
      toiBurnActive = false;
      // 状态机转换由 LaunchController 处理
    }
  }

  // ============================================================
  //  上升段制导
  // ============================================================
  private void updateLaunching(Spacecraft ship, double simDt, double simTime) {
    boolean shouldThrust = true;
    double thrustDir = 0.0;

    double rx = ship.pos[0];
    double ry = ship.pos[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    // 检查是否应该停止推力
    if (ship.thrustActive) {
      double currentApo = flightComputer.apoapsisAltitude(
        rx, ry, ship.vel[0], ship.vel[1],
        MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

      if (currentApo >= MissionPlanner.LEO_ALTITUDE_KM) {
        shouldThrust = false;
        apoapsisReached = true;
      }
    }

    // 计算推力方向
    if (shouldThrust) {
      double burnTime = simTime - ship.launchStartTime;
      thrustDir = flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
    }

    // 发送推力命令
    flightSystem.setThrustCommand(shouldThrust, thrustDir);

    // 检查是否应该进入圆化段
    if (!shouldThrust && apoapsisReached) {
      // 计算圆化燃烧参数
      computeCircularizationBurn(ship, simTime);
      if (circBurnDuration > 0) {
        ship.state = ShipState.CIRCULARIZING;
        burnStartTime = simTime;
        dbgLog("CIRC START: burnDuration=" + circBurnDuration);
      }
    }
  }

  // ============================================================
  //  圆化段制导
  // ============================================================
  private void updateCircularizing(Spacecraft ship, double simDt, double simTime) {
    double rx = ship.pos[0];
    double ry = ship.pos[1];

    // 使用 PEG 制导计算推力方向
    double[] peg = flightComputer.pegGuidance(
      rx, ry, ship.vel[0], ship.vel[1],
      MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);

    if (Double.isNaN(peg[0]) || Double.isNaN(peg[1])) {
      dbgLog("PEG NaN thrust — aborting circularization");
      flightSystem.setThrustCommand(false, 0.0);
      return;
    }

    // 更新燃烧时间
    circBurnDuration -= simDt;

    // 检查是否完成圆化
    double periAlt = flightComputer.perigeeAltitude(
      ship.pos[0], ship.pos[1], ship.vel[0], ship.vel[1],
      MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

    boolean shouldContinue = (periAlt < MissionPlanner.LEO_ALTITUDE_KM - 1.0 && circBurnDuration > 0);

    // 发送推力命令
    flightSystem.setThrustCommand(shouldContinue, peg[1]);

    // 如果完成圆化，设置轨道状态
    if (!shouldContinue) {
      // 初始化轨道参数
      ship.launchPadAngle = Math.atan2(ship.pos[1], ship.pos[0]);
      ship.orbitAngle = ship.launchPadAngle;
      ship.earthOrbitAngle = ship.orbitAngle;
      ship.orbitStartTime = simTime;
      ship.state = ShipState.ORBIT;

      dbgLog("ORBIT INSERTED: finalizing orbit");
    }
  }

  // ============================================================
  //  计算圆化燃烧参数
  // ============================================================
  private void computeCircularizationBurn(Spacecraft ship, double simTime) {
    double rx = ship.pos[0], ry = ship.pos[1];
    double vx = ship.vel[0], vy = ship.vel[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double energy = v2 / 2.0 - MissionPlanner.GM_EARTH / r;

    if (energy < 0) {
      double a = -MissionPlanner.GM_EARTH / (2.0 * energy);
      double h = rx * vy - ry * vx;
      double e2 = 1.0 - h * h / (MissionPlanner.GM_EARTH * a);
      double e = Math.sqrt(Math.max(0.0, e2));
      double rApo = a * (1.0 + e);
      double vApo = Math.sqrt(MissionPlanner.GM_EARTH * (2.0 / rApo - 1.0 / a));
      double vCirc = Math.sqrt(MissionPlanner.GM_EARTH / rApo);
      double dv = vCirc - vApo;
      circBurnDuration = Math.max(dv / FlightComputer.THRUST_ACCEL, 0.5);
    } else {
      circBurnDuration = 5.0;
    }
  }

  // ============================================================
  //  计算目标显示角度
  // ============================================================
  double computeTargetDisplayAngle(Spacecraft ship, double simTime) {
    if (ship.currentCentralBody != null) {
      if (ship.state == ShipState.IDLE ||
          ship.state == ShipState.COUNTDOWN ||
          ship.state == ShipState.IGNITION) {
        return ship.orbitAngle;
      } else if (ship.state == ShipState.LAUNCHING && ship.thrustActive) {
        double rx = ship.pos[0];
        double ry = ship.pos[1];
        double burnTime = simTime - ship.launchStartTime;
        return flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
      } else if (ship.state == ShipState.CIRCULARIZING && ship.thrustActive) {
        double rx = ship.pos[0];
        double ry = ship.pos[1];
        double vx = ship.vel[0];
        double vy = ship.vel[1];
        double[] peg = flightComputer.pegGuidance(rx, ry, vx, vy, MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);
        return peg[1];
      } else {
        return ship.orbitAngle + PI / 2.0;
      }
    } else {
      // 日心模式：速度方向
      return Math.atan2(ship.vel[1], ship.vel[0]);
    }
  }
}
