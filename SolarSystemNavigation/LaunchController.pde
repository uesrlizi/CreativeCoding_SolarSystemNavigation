class LaunchController {
  ShipState state;
  Spacecraft currentShip;
  CelestialBody selectedTarget;
  double launchStartTime;
  double transferStartTime;
  double[] transferOrbitParams;
  MissionPlanner planner;

  // 新增：任务参数
  TransferParameters currentMission;
  double burnStartTime;
  double burnDeltaVNeeded;
  double burnDeltaVApplied;
  double burnDuration;

  // 新增：目标接近参数
  CelestialBody approachTarget;
  double closestApproachDistance;

  LaunchController() {
    state = ShipState.IDLE;
    currentShip = null;
    selectedTarget = null;
    planner = new MissionPlanner();
    currentMission = null;
  }

  void startLaunch() {
    if (state != ShipState.IDLE || currentShip == null) return;

    currentShip.state = ShipState.COUNTDOWN;
    currentShip.countdownStartTime = timeManager.simTime;
    currentShip.thrustActive = false;

    state = ShipState.COUNTDOWN;
    launchStartTime = timeManager.simTime;
  }

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

  void selectTarget(CelestialBody target) {
    if (state != ShipState.ORBIT) return;
    selectedTarget = target;
    // 清除旧的任务规划
    currentMission = null;
  }

  // 规划行星际任务
  void planInterplanetaryMission() {
    if (selectedTarget == null) return;

    CelestialBody earth = getEarth();

    // 寻找发射窗口（搜索未来2年）
    double nextLaunchWindow = planner.findNextLaunchWindow(
      earth, selectedTarget, timeManager.simTime, 365 * 2);

    // 计算转移参数
    currentMission = planner.computeTransferMission(
      earth, selectedTarget, nextLaunchWindow);

    // 切换到等待窗口状态
    state = ShipState.WAITING_FOR_WINDOW;
    currentShip.state = ShipState.WAITING_FOR_WINDOW;

    dbgLog("Mission planned: Launch at simTime=" + nextLaunchWindow +
           " (+" + (float)((nextLaunchWindow - timeManager.simTime)/DAY_S) + " days)");
  }

  // 取消任务规划
  void cancelMissionPlanning() {
    currentMission = null;
    state = ShipState.ORBIT;
    currentShip.state = ShipState.ORBIT;
    dbgLog("Mission planning cancelled");
  }

  // 检查发射窗口是否到达
  void checkLaunchWindow() {
    if (currentMission == null) return;

    double timeToWindow = currentMission.launchDate - timeManager.simTime;

    if (timeToWindow <= 0) {
      // 开始 TMI 燃烧
      startTMIBurn();
    }
  }

  // 开始 TMI 燃烧
  void startTMIBurn() {
    state = ShipState.TMI_BURN;
    currentShip.state = ShipState.TMI_BURN;

    // 计算燃烧参数
    burnDeltaVNeeded = currentMission.tmiDeltaV;
    burnDeltaVApplied = 0;
    burnStartTime = timeManager.simTime;
    burnDuration = burnDeltaVNeeded / Spacecraft.THRUST_ACCEL;

    currentShip.thrustActive = true;

    dbgLog("TMI burn started: ΔV=" + (float)burnDeltaVNeeded +
           " km/s, duration=" + (float)burnDuration + "s");
  }

  // 更新 TMI 燃烧
  void updateTMIBurn() {
    double elapsed = timeManager.simTime - burnStartTime;
    double fraction = Math.min(elapsed / burnDuration, 1.0);
    burnDeltaVApplied = fraction * burnDeltaVNeeded;

    if (fraction >= 1.0) {
      completeTMIBurn();
    }
  }

  // 完成 TMI 燃烧
  void completeTMIBurn() {
    currentShip.thrustActive = false;

    CelestialBody earth = getEarth();
    double r1 = earth.a;
    double r2 = selectedTarget.a;
    double a_transfer = (r1 + r2) / 2.0;
    double e_transfer = Math.abs(r2 - r1) / (r2 + r1);

    // 获取目标在到达时刻的位置
    double[] targetPosAtArrival = getPositionAtTime(
      selectedTarget, timeManager.simTime + currentMission.transferTime);

    // 计算转移轨道的近地点辐角（指向目标方向）
    double w_transfer = Math.atan2(targetPosAtArrival[1], targetPosAtArrival[0]);

    // 获取当前航天器日心位置
    double[] shipHelioPos = new double[3];
    shipHelioPos[0] = earth.px + currentShip.earthRelPos[0];
    shipHelioPos[1] = earth.py + currentShip.earthRelPos[1];

    // 切换到日心模式
    currentShip.earthRelative = false;
    currentShip.earthRef = null;

    // 设置转移轨道
    currentShip.a = a_transfer;
    currentShip.e = e_transfer;
    currentShip.i = 0;  // 简化：共面
    currentShip.omega = 0;
    currentShip.w = Math.toDegrees(w_transfer);
    currentShip.M0 = 0;  // 从近地点出发
    currentShip.period = 2 * PI * Math.sqrt(Math.pow(currentShip.a, 3) / GM_SUN);

    // 强制更新位置
    currentShip.px = shipHelioPos[0];
    currentShip.py = shipHelioPos[1];

    state = ShipState.TRANSFER;
    currentShip.state = ShipState.TRANSFER;
    transferStartTime = timeManager.simTime;

    // 保存向后兼容的转移参数
    transferOrbitParams = new double[]{a_transfer / 1000.0, e_transfer};

    dbgLog("TMI complete: Transfer orbit a=" + (float)(currentShip.a / AU_KM) + " AU");
  }

  // 监控转移轨道
  void monitorTransfer() {
    double elapsed = timeManager.simTime - transferStartTime;
    double remaining = currentMission.transferTime - elapsed;

    // 当剩余 10 天时自动降回 1x（如果还没降的话）
    if (remaining <= 10 * DAY_S && timeManager.warpIndex > 0) {
      timeManager.warpIndex = 0;
      timeManager.timeWarp = timeManager.WARP_LEVELS[0];
      dbgLog("Approaching target, time warp set to 1x");
    }

    // 检查是否接近目标（剩余 3 天）
    if (remaining <= 3 * DAY_S) {
      startApproach();
    }
  }

  // 开始接近目标
  void startApproach() {
    state = ShipState.APPROACHING_TARGET;
    currentShip.state = ShipState.APPROACHING_TARGET;
    approachTarget = selectedTarget;
    dbgLog("Starting approach to " + approachTarget.name);
  }

  // 更新接近过程
  void updateApproach() {
    // 计算相对位置
    double dx = currentShip.px - approachTarget.px;
    double dy = currentShip.py - approachTarget.py;
    double distance = Math.sqrt(dx*dx + dy*dy);

    closestApproachDistance = distance;

    // 当进入目标 SOI 的 2 倍范围内时开始 TOI 燃烧
    double soiRadius = planner.calculateSOI(approachTarget);
    if (distance <= soiRadius * 2.0) {
      startTOIBurn();
    }
  }

  // 开始 TOI 燃烧
  void startTOIBurn() {
    state = ShipState.TOI_BURN;
    currentShip.state = ShipState.TOI_BURN;

    burnDeltaVNeeded = currentMission.toiDeltaV;
    burnDeltaVApplied = 0;
    burnStartTime = timeManager.simTime;
    burnDuration = burnDeltaVNeeded / Spacecraft.THRUST_ACCEL;

    currentShip.thrustActive = true;
    dbgLog("TOI burn started: ΔV=" + (float)burnDeltaVNeeded + " km/s");
  }

  // 更新 TOI 燃烧
  void updateTOIBurn() {
    double elapsed = timeManager.simTime - burnStartTime;
    double fraction = Math.min(elapsed / burnDuration, 1.0);
    burnDeltaVApplied = fraction * burnDeltaVNeeded;

    if (fraction >= 1.0) {
      completeTOIBurn();
    }
  }

  // 完成 TOI 燃烧
  void completeTOIBurn() {
    currentShip.thrustActive = false;

    // 设置一个与目标同轨道的日心轨道，稍微偏移以模拟环绕
    double captureOffset = selectedTarget.radius * 50;  // 视觉偏移

    // 获取目标当前真近点角
    double targetNu = selectedTarget.currentNu;

    // 设置航天器轨道与目标完全相同
    currentShip.a = selectedTarget.a;
    currentShip.e = selectedTarget.e;
    currentShip.i = selectedTarget.i;
    currentShip.omega = selectedTarget.omega;
    currentShip.w = selectedTarget.w;
    currentShip.period = selectedTarget.period;

    // 设置 M0 使航天器稍微滞后于目标
    double n = 2 * PI / selectedTarget.period;
    double currentM = selectedTarget.M0 + n * timeManager.simTime;
    currentShip.M0 = currentM - 0.02;  // 稍微滞后

    state = ShipState.CAPTURED;
    currentShip.state = ShipState.CAPTURED;

    dbgLog("TOI complete: Captured by " + selectedTarget.name);
  }

  void initiateTransfer() {
    // 保留旧接口用于向后兼容，但实际上现在会触发任务规划
    if (state != ShipState.ORBIT || selectedTarget == null) return;
    if (currentMission == null) {
      planInterplanetaryMission();
    }
  }

  void insertIntoTargetOrbit() {
    // 旧接口，不再使用
  }

  // 记录上一个状态，用于检测状态切换
  ShipState previousState = ShipState.IDLE;

  void update() {
    if (currentShip == null) return;

    // 检测状态切换，在关键阶段自动降回 1x 时间流速
    if (previousState != state) {
      // 进入燃烧阶段或接近阶段时，强制降回 1x
      if (state == ShipState.TMI_BURN ||
          state == ShipState.APPROACHING_TARGET ||
          state == ShipState.TOI_BURN) {
        if (timeManager.warpIndex > 0) {
          timeManager.warpIndex = 0;
          timeManager.timeWarp = timeManager.WARP_LEVELS[0];
          dbgLog("Approaching critical phase, time warp set to 1x");
        }
      }
      previousState = state;
    }

    // 限制燃烧期间的时间加速
    if ((state == ShipState.TMI_BURN || state == ShipState.TOI_BURN) &&
        timeManager.warpIndex > 0) {
      timeManager.warpIndex = 0;
      timeManager.timeWarp = timeManager.WARP_LEVELS[0];
    }

    switch (state) {
      case COUNTDOWN:
        {
          double elapsed = timeManager.simTime - currentShip.countdownStartTime;
          if (elapsed >= Spacecraft.COUNTDOWN_DURATION) {
            currentShip.state = ShipState.IGNITION;
            currentShip.ignitionStartTime = timeManager.simTime;
            state = ShipState.IGNITION;
          }
        }
        break;
      case IGNITION:
        {
          double elapsed = timeManager.simTime - currentShip.ignitionStartTime;
          if (elapsed >= Spacecraft.IGNITION_DURATION) {
            currentShip.state = ShipState.LAUNCHING;
            currentShip.launchStartTime = timeManager.simTime;
            currentShip.lastUpdateTime = timeManager.simTime;
            currentShip.thrustActive = true;
            state = ShipState.LAUNCHING;
          }
        }
        break;
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
        // 如果已选目标且未规划任务，开始规划
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
        updateApproach();
        break;
      case TOI_BURN:
        updateTOIBurn();
        break;
      case CAPTURED:
        // 在目标轨道运行，无需操作
        break;
    }
  }

  boolean canLaunch() {
    return state == ShipState.IDLE && currentShip != null;
  }

  boolean canSelectTarget() {
    return state == ShipState.ORBIT;
  }

  boolean canTransfer() {
    return state == ShipState.ORBIT && selectedTarget != null;
  }

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
          double daysToWindow = (currentMission.launchDate - timeManager.simTime) / DAY_S;
          if (daysToWindow > 0) {
            return "Waiting for Launch Window: T-" + (float)daysToWindow + " days";
          } else {
            return "Launch Window Now!";
          }
        }
        return "Waiting for Launch Window";
      case TMI_BURN:
        int tmiPercent = (int)(burnDeltaVApplied / burnDeltaVNeeded * 100);
        return "TMI Burn: " + tmiPercent + "%";
      case TRANSFER:
        double elapsedDays = (timeManager.simTime - transferStartTime) / DAY_S;
        double totalDays = currentMission.transferTime / DAY_S;
        return "Transfer: Day " + (float)elapsedDays + "/" + (float)totalDays;
      case APPROACHING_TARGET:
        double distMKm = closestApproachDistance / 1e6;
        return "Approaching " + approachTarget.name + ": " + (float)distMKm + " M km";
      case TOI_BURN:
        int toiPercent = (int)(burnDeltaVApplied / burnDeltaVNeeded * 100);
        return "TOI Burn: " + toiPercent + "%";
      case CAPTURED:
        return "Orbiting " + selectedTarget.name;
    }
    return "";
  }

  // 获取当前任务（用于 HUD 显示）
  TransferParameters getCurrentMission() {
    return currentMission;
  }
}
