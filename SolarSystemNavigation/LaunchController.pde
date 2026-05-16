// ============================================================
//  LaunchController — refactored to be pure mission state machine
//  No physics logic here; that's handled by Spacecraft now
// ============================================================

class LaunchController {
  // Mission state
  ShipState state;
  Spacecraft currentShip;
  CelestialBody selectedTarget;

  // Timing
  double launchStartTime;
  double transferStartTime;
  double burnStartTime;

  // Transfer mission parameters
  MissionPlanner planner;
  TransferParameters currentMission;

  // Burn tracking (backward compatibility)
  double burnDeltaVApplied = 0;
  double burnDeltaVNeeded = 0;
  double burnDuration = 0;
  double[] transferOrbitParams = null;

  // Approach tracking
  CelestialBody approachTarget;
  double closestApproachDistance;

  // Auto warp management
  boolean autoWarpActive = false;
  boolean inCriticalPhase = false;

  // Previous state for transition detection
  ShipState previousState = ShipState.IDLE;

  // FlightComputer instance
  FlightComputer flightComputer;

  // ==============================================================
  //  Constructor
  // ==============================================================

  LaunchController() {
    state = ShipState.IDLE;
    currentShip = null;
    selectedTarget = null;
    planner = new MissionPlanner();
    currentMission = null;
    flightComputer = new FlightComputer();
  }

  // ==============================================================
  //  Start a launch from the pad
  // ==============================================================

  void startLaunch() {
    if (state != ShipState.IDLE || currentShip == null) return;
    currentShip.state = ShipState.COUNTDOWN;
    currentShip.countdownStartTime = timeManager.simTime;
    currentShip.thrustActive = false;
    state = ShipState.COUNTDOWN;
    launchStartTime = timeManager.simTime;
  }

  // ==============================================================
  //  Getters
  // ==============================================================

  CelestialBody getEarth() {
    return solarSystem.planets.get(2);
  }

  Spacecraft getCurrentShip() {
    return currentShip;
  }

  CelestialBody getSelectedTarget() {
    return selectedTarget;
  }

  ShipState getState() {
    return state;
  }

  // ==============================================================
  //  Select a target planet
  // ==============================================================

  void selectTarget(CelestialBody target) {
    if (state != ShipState.ORBIT) return;
    selectedTarget = target;
    currentMission = null;
  }

  // ==============================================================
  //  Plan the interplanetary mission
  // ==============================================================

  void planInterplanetaryMission() {
    if (selectedTarget == null) return;

    CelestialBody earth = getEarth();

    double nextLaunchWindow = planner.findNextLaunchWindow(
      earth, selectedTarget, timeManager.simTime, 365 * 2);

    currentMission = planner.computeTransferMission(
      earth, selectedTarget, nextLaunchWindow);

    state = ShipState.WAITING_FOR_WINDOW;
    currentShip.state = ShipState.WAITING_FOR_WINDOW;

    dbgLog("Mission planned: Launch at simTime=" + nextLaunchWindow +
      " (+" + (float)((nextLaunchWindow - timeManager.simTime)/DAY_S) + " days)");
  }

  // ==============================================================
  //  Cancel mission planning
  // ==============================================================

  void cancelMissionPlanning() {
    currentMission = null;
    state = ShipState.ORBIT;
    currentShip.state = ShipState.ORBIT;
    dbgLog("Mission planning cancelled");
  }

  // ==============================================================
  //  Check and jump to event (time warp management)
  // ==============================================================

  boolean checkAndJumpToEvent(double targetSimTime, String eventName) {
    if (inCriticalPhase) return false;

    double remaining = targetSimTime - timeManager.simTime;
    if (remaining <= 0) return false;

    double currentWarp = Math.max(timeManager.timeWarp, 1e-6);
    double nextFrameSimTime = timeManager.simTime + currentWarp * DAY_S * deltaTime;

    double thresholdSimTime = 15.0;

    if (remaining <= thresholdSimTime || nextFrameSimTime >= targetSimTime) {
      double jumpToTime = targetSimTime - thresholdSimTime;
      if (jumpToTime > timeManager.simTime) {
        timeManager.simTime = jumpToTime;
        dbgLog("Jumped to 15s before " + eventName);
      }

      inCriticalPhase = true;
      timeManager.setMaxWarpIndex(0);
      timeManager.forceSetWarpIndex(0);
      dbgLog(eventName + " approaching: TIME LOCKED to 1x");
      return true;
    }

    return false;
  }

  // ==============================================================
  //  Check if launch window is here
  // ==============================================================

  void checkLaunchWindow() {
    if (currentMission == null) return;

    checkAndJumpToEvent(currentMission.launchDate, "launch window");

    double timeToWindow = currentMission.launchDate - timeManager.simTime;

    if (timeToWindow <= 0) {
      // 到达发射窗口时重新计算任务参数，确保使用当前地球位置
      CelestialBody earth = getEarth();
      currentMission = planner.computeTransferMission(earth, selectedTarget, timeManager.simTime);
      startTMIBurn();
    }
  }

  // ==============================================================
  //  Start TMI burn
  // ==============================================================

  void startTMIBurn() {
    state = ShipState.TMI_BURN;
    currentShip.state = ShipState.TMI_BURN;

    currentShip.tmiTargetDV = currentMission.tmiDeltaV;
    currentShip.tmiAccumulatedDV = 0;
    currentShip.lastUpdateTime = timeManager.simTime;
    currentShip.thrustActive = true;

    burnStartTime = timeManager.simTime;
    burnDeltaVNeeded = currentMission.tmiDeltaV;
    burnDeltaVApplied = 0;
    burnDuration = burnDeltaVNeeded / FlightComputer.THRUST_ACCEL;

    if (currentMission.tmiDeltaV <= 0) {
      completeTMIBurn();
      return;
    }

    dbgLog("TMI burn started: ΔV=" + (float)currentMission.tmiDeltaV + " km/s");
  }

  // ==============================================================
  //  Update TMI burn progress
  // ==============================================================

  void updateTMIBurn() {
    burnDeltaVApplied = currentShip.tmiAccumulatedDV;
    if (!currentShip.thrustActive || currentShip.tmiAccumulatedDV >= currentShip.tmiTargetDV) {
      completeTMIBurn();
    }
  }

  // ==============================================================
  //  Complete TMI burn
  // ==============================================================

  void completeTMIBurn() {
    currentShip.thrustActive = false;

    CelestialBody earth = getEarth();
    double t = timeManager.simTime;

    // 1. 获取地球当前的日心位置和速度
    double[] earthPos = getPositionAtTime(earth, t);
    double[] earthVel = getVelocityAtTime(earth, t);

    // 2. 计算飞船当前的日心位置和速度 = 地球位置 + 飞船相对位置
    double[] helioPos = new double[3];
    double[] helioVel = new double[3];
    helioPos[0] = earthPos[0] + currentShip.earthRelPos[0];
    helioPos[1] = earthPos[1] + currentShip.earthRelPos[1];
    helioPos[2] = 0;
    helioVel[0] = earthVel[0] + currentShip.earthRelVel[0];
    helioVel[1] = earthVel[1] + currentShip.earthRelVel[1];
    helioVel[2] = 0;

    // 3. 从日心笛卡尔坐标转换为开普勒轨道元素
    double[] kepler = cartesianToKepler(helioPos, helioVel, GM_SUN);

    // 4. 切换到日心坐标系
    currentShip.earthRelative = false;
    currentShip.earthRef = null;

    // 5. 设置轨道元素（注意 cartesianToKepler 返回的 w 是角度，M0 需要计算）
    currentShip.a = kepler[0];
    currentShip.e = kepler[1];
    currentShip.i = kepler[2];
    currentShip.omega = kepler[3];
    currentShip.w = kepler[4]; // 已经是角度

    // 6. 计算平近点角 M0: M = M0 + n*t = nu - E + e*sinE（反向计算）
    double a_km = currentShip.a;
    double n;
    if (a_km > 0) {
      n = 2 * PI / Math.sqrt(Math.pow(a_km, 3) / GM_SUN);
    } else {
      // 对于双曲线轨道，使用伪周期
      n = 2 * PI / Math.sqrt(Math.pow(-a_km, 3) / GM_SUN);
    }

    double nu_rad = Math.toRadians(kepler[5]); // true anomaly in radians
    double E, M;

    if (currentShip.e < 1.0) {
      // 椭圆轨道：使用标准的偏近点角计算
      E = 2 * Math.atan2(Math.sqrt(1 - currentShip.e) * Math.sin(nu_rad / 2),
                         Math.sqrt(1 + currentShip.e) * Math.cos(nu_rad / 2));
      M = E - currentShip.e * Math.sin(E);
    } else {
      // 双曲线轨道：使用双曲偏近点角
      double coshF = (currentShip.e + Math.cos(nu_rad)) / (1 + currentShip.e * Math.cos(nu_rad));
      E = Math.log(coshF + Math.sqrt(coshF * coshF - 1));
      if (Math.sin(nu_rad) < 0) E = -E;
      M = currentShip.e * Math.sinh(E) - E;
    }

    currentShip.M0 = M - n * t; // 这样在时间 t 时 M = M0 + n*t 成立
    currentShip.period = (currentShip.e < 1.0) ? (2 * PI / n) : Double.MAX_VALUE;

    // 7. 直接设置当前的日心位置，确保轨道传播从正确位置开始
    currentShip.px = helioPos[0];
    currentShip.py = helioPos[1];
    currentShip.pz = helioPos[2];
    currentShip.currentNu = nu_rad;

    // 8. 更新状态机
    transferStartTime = t;
    state = ShipState.TRANSFER;
    currentShip.state = ShipState.TRANSFER;

    // Backward compatibility: set the transferOrbitParams
    transferOrbitParams = new double[]{currentShip.a / 1000.0, currentShip.e};

    dbgLog("TMI complete: Transfer orbit a=" + (float)(currentShip.a / AU_KM) + " AU, e=" + (float)currentShip.e);
  }

  // ==============================================================
  //  Monitor transfer progress
  // ==============================================================

  void monitorTransfer() {
    if (currentMission == null) return;

    double targetTime = transferStartTime + currentMission.transferTime;

    checkAndJumpToEvent(targetTime, "transfer end");

    double elapsed = timeManager.simTime - transferStartTime;
    double remaining = targetTime - timeManager.simTime;

    if (remaining <= 3 * DAY_S) {
      startApproach();
    }
  }

  // ==============================================================
  //  Start approach phase
  // ==============================================================

  void startApproach() {
    state = ShipState.APPROACHING_TARGET;
    currentShip.state = ShipState.APPROACHING_TARGET;
    approachTarget = selectedTarget;
    dbgLog("Starting approach to " + approachTarget.name);
  }

  // ==============================================================
  //  Monitor approach phase
  // ==============================================================

  void monitorApproach() {
    double dx = currentShip.px - approachTarget.px;
    double dy = currentShip.py - approachTarget.py;
    double distance = Math.sqrt(dx*dx + dy*dy);

    closestApproachDistance = distance;

    double soiRadius = planner.calculateSOI(approachTarget);

    // 检查是否已经通过SOI切换进入了目标天体参考系
    if (currentShip.earthRelative && currentShip.earthRef == approachTarget) {
      // 已经在目标SOI内，开始TOI燃烧
      startTOIBurn();
      return;
    }

    if (!inCriticalPhase) {
      // 使用1.5xSOI作为临界边界
      double distTo15xSOI = Math.max(0, distance - soiRadius * 1.5);
      double estimatedSimTimeToSOI = distTo15xSOI / 20.0;

      if (estimatedSimTimeToSOI < 30.0) {
        inCriticalPhase = true;
        timeManager.setMaxWarpIndex(0);
        timeManager.forceSetWarpIndex(0);
        dbgLog("Approaching " + approachTarget.name + " SOI: TIME LOCKED to 1x");
      }
    }

    // 在SOI边界时，等待Spacecraft的自动SOI切换
    // 这里不强制切换，让checkSOISwitch处理
  }

  // ==============================================================
  //  Start TOI burn
  // ==============================================================

  void startTOIBurn() {
    state = ShipState.TOI_BURN;
    currentShip.state = ShipState.TOI_BURN;

    double t = timeManager.simTime;

    // 确保已经在目标相对坐标系中（SOI切换应该已经处理了）
    if (!currentShip.earthRelative || currentShip.earthRef != approachTarget) {
      // 备用切换逻辑
      currentShip.earthRelative = true;
      currentShip.earthRef = approachTarget;

      // Initialize position relative to target
      double dx = currentShip.px - approachTarget.px;
      double dy = currentShip.py - approachTarget.py;
      currentShip.earthRelPos = new double[]{dx, dy, 0};

      // Initialize velocity relative to target - use exact calculation
      double[] targetVel = getVelocityAtTime(approachTarget, t);

      // Calculate spacecraft velocity from its orbital elements
      double n_ship = 2 * PI / currentShip.period;
      double M_ship = currentShip.M0 + n_ship * t;
      double E_ship = solveKepler(M_ship, currentShip.e);
      double nu_ship = trueAnomaly(E_ship, currentShip.e);
      double[] shipVel = orbitalVelocityToCartesian(
          currentShip.a, currentShip.e, currentShip.i,
          currentShip.omega, currentShip.w, nu_ship, GM_SUN);

      currentShip.earthRelVel = new double[]{shipVel[0] - targetVel[0], shipVel[1] - targetVel[1], 0};
    }

    currentShip.toiTargetDV = currentMission.toiDeltaV;
    currentShip.toiAccumulatedDV = 0;
    currentShip.lastUpdateTime = timeManager.simTime;
    currentShip.thrustActive = true;

    burnStartTime = timeManager.simTime;
    burnDeltaVNeeded = currentMission.toiDeltaV;
    burnDeltaVApplied = 0;
    burnDuration = burnDeltaVNeeded / FlightComputer.THRUST_ACCEL;

    dbgLog("TOI burn started: ΔV=" + (float)currentMission.toiDeltaV + " km/s");
  }

  // ==============================================================
  //  Update TOI burn
  // ==============================================================

  void updateTOIBurn() {
    burnDeltaVApplied = currentShip.toiAccumulatedDV;
    if (!currentShip.thrustActive || currentShip.toiAccumulatedDV >= currentShip.toiTargetDV) {
      completeTOIBurn();
    }
  }

  // ==============================================================
  //  Complete TOI burn
  // ==============================================================

  void completeTOIBurn() {
    currentShip.thrustActive = false;

    // Stay in target-relative coordinates, set up a stable circular orbit
    double rCapture = approachTarget.radius * 10.0;
    double GM_target = planner.getTargetGM(approachTarget);
    double vCaptureCirc = Math.sqrt(GM_target / rCapture);

    // Set up circular orbit
    double angle = Math.atan2(currentShip.earthRelPos[1], currentShip.earthRelPos[0]);
    currentShip.earthRelPos[0] = rCapture * Math.cos(angle);
    currentShip.earthRelPos[1] = rCapture * Math.sin(angle);
    currentShip.earthRelVel[0] = -vCaptureCirc * Math.sin(angle);
    currentShip.earthRelVel[1] =  vCaptureCirc * Math.cos(angle);

    currentShip.launchPadAngle = angle;
    currentShip.earthOrbitAngle = angle;
    currentShip.orbitStartTime = timeManager.simTime;
    currentShip.launchAltitude = rCapture - approachTarget.radius;

    state = ShipState.CAPTURED;
    currentShip.state = ShipState.CAPTURED;

    dbgLog("TOI complete: Captured by " + selectedTarget.name);
  }

  // ==============================================================
  //  Start transfer (backward compatibility)
  // ==============================================================

  void initiateTransfer() {
    if (state != ShipState.ORBIT || selectedTarget == null) return;
    if (currentMission == null) {
      planInterplanetaryMission();
    }
  }

  // ==============================================================
  //  Main update — state machine
  // ==============================================================

  void update() {
    if (currentShip == null) return;

    if (previousState != state) {
      if (state == ShipState.WAITING_FOR_WINDOW ||
          state == ShipState.TRANSFER ||
          state == ShipState.APPROACHING_TARGET) {
        autoWarpActive = true;
        inCriticalPhase = false;
        timeManager.clearMaxWarp();
        dbgLog("Entering auto warp phase");
      }

      if (state == ShipState.TMI_BURN ||
          state == ShipState.TOI_BURN) {
        inCriticalPhase = false;
        timeManager.clearMaxWarp();
        dbgLog("BURN PHASE: Manual warp control allowed");
      }

      if (state == ShipState.IDLE || state == ShipState.ORBIT || state == ShipState.CAPTURED) {
        autoWarpActive = false;
        inCriticalPhase = false;
        timeManager.clearMaxWarp();
        dbgLog("Auto warp control released");
      }

      previousState = state;
    }

    switch (state) {
      case COUNTDOWN: {
        double elapsed = timeManager.simTime - currentShip.countdownStartTime;
        if (elapsed >= Spacecraft.COUNTDOWN_DURATION) {
          currentShip.state = ShipState.IGNITION;
          currentShip.ignitionStartTime = timeManager.simTime;
          state = ShipState.IGNITION;
        }
        break;
      }

      case IGNITION: {
        double elapsed = timeManager.simTime - currentShip.ignitionStartTime;
        if (elapsed >= Spacecraft.IGNITION_DURATION) {
          currentShip.state = ShipState.LAUNCHING;
          currentShip.launchStartTime = timeManager.simTime;
          currentShip.lastUpdateTime = timeManager.simTime;
          currentShip.thrustActive = true;
          state = ShipState.LAUNCHING;
        }
        break;
      }

      case LAUNCHING:
        if (currentShip.state == ShipState.CIRCULARIZING) {
          state = ShipState.CIRCULARIZING;
        } else if (currentShip.state == ShipState.ORBIT) {
          state = ShipState.ORBIT;
        }
        break;

      case CIRCULARIZING:
        if (currentShip.state == ShipState.ORBIT) {
          state = ShipState.ORBIT;
        }
        break;

      case ORBIT:
        if (selectedTarget != null && currentMission == null) {
          planInterplanetaryMission();
        }
        break;

      case WAITING_FOR_WINDOW:
        checkLaunchWindow();
        break;

      case TMI_BURN:
        updateTMIBurn();
        break;

      case TRANSFER:
        monitorTransfer();
        break;

      case APPROACHING_TARGET:
        monitorApproach();
        break;

      case TOI_BURN:
        updateTOIBurn();
        break;

      case CAPTURED:
        break;
    }
  }

  // ==============================================================
  //  Checks
  // ==============================================================

  boolean canLaunch() {
    return state == ShipState.IDLE && currentShip != null;
  }

  boolean canSelectTarget() {
    return state == ShipState.ORBIT;
  }

  boolean canTransfer() {
    return state == ShipState.ORBIT && selectedTarget != null;
  }

  // ==============================================================
  //  Status text for HUD
  // ==============================================================

  String getStatusText() {
    switch (state) {
      case IDLE: return "Ready to Launch";
      case COUNTDOWN: return "Countdown...";
      case IGNITION: return "Ignition!";
      case LAUNCHING: return "Launching...";
      case CIRCULARIZING: return "Circularizing Orbit...";
      case ORBIT:
        if (selectedTarget != null) {
          return "In Orbit - Target: " + selectedTarget.name;
        } else {
          return "In Orbit - Select Target";
        }
      case WAITING_FOR_WINDOW:
        if (currentMission != null) {
          double secToWindow = currentMission.launchDate - timeManager.simTime;
          if (secToWindow > 0) {
            return "Waiting for Launch Window: T-" + formatSimTime(secToWindow);
          } else {
            return "Launch Window Now!";
          }
        }
        return "Waiting for Launch Window";
      case TMI_BURN:
        int tmiPercent = (int)(currentShip.tmiAccumulatedDV / currentShip.tmiTargetDV * 100);
        if (Double.isNaN(tmiPercent) || currentShip.tmiTargetDV <= 0) tmiPercent = 100;
        return "TMI Burn: " + tmiPercent + "%";
      case TRANSFER:
        double elapsedSec = timeManager.simTime - transferStartTime;
        double totalSec = currentMission.transferTime;
        double remainingSec = totalSec - elapsedSec;
        if (remainingSec > 0) {
          return "Transfer: ETA " + formatSimTime(remainingSec);
        } else {
          double elapsedDays = elapsedSec / DAY_S;
          double totalDays = totalSec / DAY_S;
          return "Transfer: Day " + (float)elapsedDays + "/" + (float)totalDays;
        }
      case APPROACHING_TARGET:
        double distMKm = closestApproachDistance / 1e6;
        return "Approaching " + approachTarget.name + ": " + (float)distMKm + " M km";
      case TOI_BURN:
        int toiPercent = (int)(currentShip.toiAccumulatedDV / currentShip.toiTargetDV * 100);
        if (Double.isNaN(toiPercent) || currentShip.toiTargetDV <= 0) toiPercent = 100;
        return "TOI Burn: " + toiPercent + "%";
      case CAPTURED:
        return "Orbiting " + selectedTarget.name;
    }
    return "";
  }

  // ==============================================================
  //  Get current mission for HUD
  // ==============================================================

  TransferParameters getCurrentMission() {
    return currentMission;
  }
}
