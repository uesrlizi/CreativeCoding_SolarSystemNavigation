// ============================================================
//  GuidanceSystem - 制导系统
//  包含上升段和圆化段的制导状态机
// ============================================================

class GuidanceSystem {
  // 制导阶段状态
  boolean guidanceActive;
  double burnStartTime;
  double circBurnDuration;
  boolean apoapsisReached;
  double estimatedThrustFraction;

  // 子步积分状态
  private double[] tempPos;
  private double[] tempVel;
  private double[] tempAccel;

  // 引用的系统
  FlightComputer flightComputer;
  AtmosphereModel atmosphereModel;

  GuidanceSystem() {
    flightComputer = new FlightComputer();
    atmosphereModel = new AtmosphereModel();
    tempPos = new double[3];
    tempVel = new double[3];
    tempAccel = new double[3];
    reset();
  }

  void reset() {
    guidanceActive = false;
    burnStartTime = 0;
    circBurnDuration = 0;
    apoapsisReached = false;
    estimatedThrustFraction = 1.0;
  }

  // ============================================================
  //  主更新方法 - 处理上升段和圆化段
  // ============================================================
  void update(Spacecraft ship, double simDt, double simTime) {
    if (ship.state == ShipState.LAUNCHING) {
      updateLaunching(ship, simDt, simTime);
    } else if (ship.state == ShipState.CIRCULARIZING) {
      updateCircularizing(ship, simDt, simTime);
    }
  }

  // ============================================================
  //  上升段制导
  // ============================================================
  private void updateLaunching(Spacecraft ship, double simDt, double simTime) {
    double currentTime = simTime - simDt;
    double remainingDt = simDt;

    while (remainingDt > 0) {
      double step = Math.min(remainingDt, PhysicsEngine.FIXED_SUBSTEP);

      double rx = ship.pos[0];
      double ry = ship.pos[1];
      double r = Math.sqrt(rx * rx + ry * ry);

      if (r < MissionPlanner.EARTH_RADIUS_KM * 0.5) {
        dbgLog("PHYSICS ABORT: r=" + r + " too low");
        remainingDt = 0;
        break;
      }

      // 检查是否应该停止推力
      if (ship.thrustActive) {
        double currentApo = flightComputer.apoapsisAltitude(
          rx, ry, ship.vel[0], ship.vel[1],
          MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

        if (currentApo >= MissionPlanner.LEO_ALTITUDE_KM) {
          // 计算精确的推力分数
          estimatedThrustFraction = estimatePreciseThrustFraction(ship, step);
          if (estimatedThrustFraction <= 0) {
            ship.thrustActive = false;
            apoapsisReached = true;
          }
        }
      }

      // 计算加速度
      computeAcceleration(ship, ship.thrustActive, estimatedThrustFraction, tempAccel);

      // 半隐式欧拉积分
      ship.vel[0] += tempAccel[0] * step;
      ship.vel[1] += tempAccel[1] * step;
      ship.pos[0] += ship.vel[0] * step;
      ship.pos[1] += ship.vel[1] * step;

      currentTime += step;
      remainingDt -= step;

      // 检查是否应该进入圆化段
      if (!ship.thrustActive && apoapsisReached) {
        // 计算圆化燃烧参数
        computeCircularizationBurn(ship, simTime);
        if (circBurnDuration > 0) {
          ship.state = ShipState.CIRCULARIZING;
          ship.thrustActive = true;
          dbgLog("CIRC START: burnDuration=" + circBurnDuration);
        }
      }
    }

    // 重置推力分数用于下一帧
    estimatedThrustFraction = 1.0;
  }

  // ============================================================
  //  圆化段制导
  // ============================================================
  private void updateCircularizing(Spacecraft ship, double simDt, double simTime) {
    double currentTime = simTime - simDt;
    double remainingDt = simDt;

    while (remainingDt > 0) {
      double step = Math.min(remainingDt, PhysicsEngine.FIXED_SUBSTEP);

      double rx = ship.pos[0];
      double ry = ship.pos[1];
      double r = Math.sqrt(rx * rx + ry * ry);

      if (r < MissionPlanner.EARTH_RADIUS_KM * 0.5) {
        dbgLog("PHYSICS ABORT: r=" + r + " too low");
        remainingDt = 0;
        break;
      }

      // 使用 PEG 制导计算推力方向
      double[] peg = flightComputer.pegGuidance(
        rx, ry, ship.vel[0], ship.vel[1],
        MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);

      if (Double.isNaN(peg[0]) || Double.isNaN(peg[1])) {
        dbgLog("PEG NaN thrust — aborting circularization");
        ship.finalizeOrbitInsertion(simTime);
        remainingDt = 0;
        break;
      }

      // 计算加速度
      computeAccelerationPeg(ship, peg[1], tempAccel);

      // 半隐式欧拉积分
      ship.vel[0] += tempAccel[0] * step;
      ship.vel[1] += tempAccel[1] * step;
      ship.pos[0] += ship.vel[0] * step;
      ship.pos[1] += ship.vel[1] * step;

      // 更新燃烧时间
      circBurnDuration -= step;

      currentTime += step;
      remainingDt -= step;

      // 检查是否完成圆化
      double periAlt = flightComputer.perigeeAltitude(
        ship.pos[0], ship.pos[1], ship.vel[0], ship.vel[1],
        MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

      if (periAlt >= MissionPlanner.LEO_ALTITUDE_KM - 1.0 || circBurnDuration <= 0) {
        ship.finalizeOrbitInsertion(simTime);
        remainingDt = 0;
      }
    }
  }

  // ============================================================
  //  计算加速度（上升段）
  // ============================================================
  private void computeAcceleration(Spacecraft ship, boolean thrustActive, double thrustFraction, double[] accelOut) {
    double rx = ship.pos[0];
    double ry = ship.pos[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    // 重力
    double gMag = MissionPlanner.GM_EARTH / (r * r);
    accelOut[0] = -gMag * rx / r;
    accelOut[1] = -gMag * ry / r;
    accelOut[2] = 0;

    // 推力
    if (thrustActive && ship.currentCentralBody != null) {
      double burnTime = (timeManager != null ? timeManager.simTime : 0) - ship.launchStartTime;
      double thrustAngle = flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
      double thrustDirX = Math.cos(thrustAngle);
      double thrustDirY = Math.sin(thrustAngle);

      accelOut[0] += FlightComputer.THRUST_ACCEL * thrustDirX * thrustFraction;
      accelOut[1] += FlightComputer.THRUST_ACCEL * thrustDirY * thrustFraction;
    }

    // 大气阻力
    if (atmosphereModel != null && ship.currentCentralBody != null) {
      double[] dragAccel = new double[2];
      atmosphereModel.dragAcceleration(ship.pos, ship.vel, ship.currentCentralBody, dragAccel);
      accelOut[0] += dragAccel[0];
      accelOut[1] += dragAccel[1];
    }
  }

  // ============================================================
  //  计算加速度（圆化段 PEG 制导）
  // ============================================================
  private void computeAccelerationPeg(Spacecraft ship, double thrustAngle, double[] accelOut) {
    double rx = ship.pos[0];
    double ry = ship.pos[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    // 重力
    double gMag = MissionPlanner.GM_EARTH / (r * r);
    accelOut[0] = -gMag * rx / r;
    accelOut[1] = -gMag * ry / r;
    accelOut[2] = 0;

    // 推力
    if (ship.thrustActive) {
      double thrustDirX = Math.cos(thrustAngle);
      double thrustDirY = Math.sin(thrustAngle);
      accelOut[0] += FlightComputer.THRUST_ACCEL * thrustDirX;
      accelOut[1] += FlightComputer.THRUST_ACCEL * thrustDirY;
    }

    // 大气阻力
    if (atmosphereModel != null && ship.currentCentralBody != null) {
      double[] dragAccel = new double[2];
      atmosphereModel.dragAcceleration(ship.pos, ship.vel, ship.currentCentralBody, dragAccel);
      accelOut[0] += dragAccel[0];
      accelOut[1] += dragAccel[1];
    }
  }

  // ============================================================
  //  估算精确的推力分数，使远地点精确到达目标高度
  // ============================================================
  private double estimatePreciseThrustFraction(Spacecraft ship, double step) {
    double rx = ship.pos[0];
    double ry = ship.pos[1];
    double vx = ship.vel[0];
    double vy = ship.vel[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    // 保存当前状态
    double preRx = rx, preRy = ry;
    double preVx = vx, preVy = vy;

    // 计算重力
    double gMag = MissionPlanner.GM_EARTH / (r * r);
    double gravX = -gMag * rx / r;
    double gravY = -gMag * ry / r;

    // 计算推力方向
    double burnTime = (timeManager != null ? timeManager.simTime : 0) - ship.launchStartTime;
    double thrustAngle = flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
    double thrustDirX = Math.cos(thrustAngle);
    double thrustDirY = Math.sin(thrustAngle);
    double thrustAx = FlightComputer.THRUST_ACCEL * thrustDirX;
    double thrustAy = FlightComputer.THRUST_ACCEL * thrustDirY;

    // 计算全开推力后的状态和远地点
    double tmpVx = preVx + (gravX + thrustAx) * step;
    double tmpVy = preVy + (gravY + thrustAy) * step;
    double tmpRx = preRx + tmpVx * step;
    double tmpRy = preRy + tmpVy * step;
    double apoFull = flightComputer.apoapsisAltitude(tmpRx, tmpRy, tmpVx, tmpVy, MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

    // 计算仅重力的状态和远地点
    double gVx = preVx + gravX * step;
    double gVy = preVy + gravY * step;
    double gRx = preRx + gVx * step;
    double gRy = preRy + gVy * step;
    double apoGrav = flightComputer.apoapsisAltitude(gRx, gRy, gVx, gVy, MissionPlanner.EARTH_RADIUS_KM, MissionPlanner.GM_EARTH);

    // 插值计算推力分数
    double f = 0.0;
    if (apoFull > apoGrav && apoGrav < MissionPlanner.LEO_ALTITUDE_KM) {
      f = (MissionPlanner.LEO_ALTITUDE_KM - apoGrav) / (apoFull - apoGrav);
      f = Math.max(0.0, Math.min(1.0, f));
    }

    return f;
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
