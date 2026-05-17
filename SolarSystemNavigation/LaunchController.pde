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

  // System references
  FlightComputer flightComputer;
  FlightSystem flightSystem;
  GuidanceSystem guidanceSystem;

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
    flightSystem = null;
    guidanceSystem = null;
  }

  void setFlightSystem(FlightSystem fs) {
    flightSystem = fs;
  }

  void setGuidanceSystem(GuidanceSystem gs) {
    guidanceSystem = gs;
  }

  // ==============================================================
  //  Start a launch from the pad
  // ==============================================================

  void startLaunch() {
    if (state != ShipState.IDLE || currentShip == null) return;
    currentShip.state = ShipState.COUNTDOWN;
    currentShip.countdownStartTime = timeManager.simTime;
    currentShip.thrustActive = false;
    // 保持固定直到发射阶段开始
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

    burnStartTime = timeManager.simTime;
    burnDeltaVNeeded = currentMission.tmiDeltaV;
    burnDeltaVApplied = 0;
    burnDuration = burnDeltaVNeeded / FlightComputer.THRUST_ACCEL;

    // 调用制导系统开始 TMI 燃烧
    if (guidanceSystem != null) {
      guidanceSystem.startTMIBurn(currentMission.tmiDeltaV, selectedTarget);
    }

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
    if (burnDeltaVApplied >= burnDeltaVNeeded) {
      completeTMIBurn();
    }
  }

  // ==============================================================
  //  Complete TMI burn
  // ==============================================================

  void completeTMIBurn() {
    currentShip.thrustActive = false;
    transferStartTime = timeManager.simTime;

    state = ShipState.TRANSFER;
    currentShip.state = ShipState.TRANSFER;

    dbgLog("TMI complete");
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

    if (!inCriticalPhase) {
      double distTo2xSOI = Math.max(0, distance - soiRadius * 2.0);
      double estimatedSimTimeToSOI = distTo2xSOI / 20.0;

      if (estimatedSimTimeToSOI < 30.0) {
        inCriticalPhase = true;
        timeManager.setMaxWarpIndex(0);
        timeManager.forceSetWarpIndex(0);
        dbgLog("TOI approaching: TIME LOCKED to 1x");
      }
    }

    if (distance <= soiRadius * 2.0) {
      startTOIBurn();
    }
  }

  // ==============================================================
  //  Start TOI burn
  // ==============================================================

  void startTOIBurn() {
    state = ShipState.TOI_BURN;
    currentShip.state = ShipState.TOI_BURN;

    currentShip.toiTargetDV = currentMission.toiDeltaV;
    currentShip.toiAccumulatedDV = 0;
    currentShip.lastUpdateTime = timeManager.simTime;

    burnStartTime = timeManager.simTime;
    burnDeltaVNeeded = currentMission.toiDeltaV;
    burnDeltaVApplied = 0;
    burnDuration = burnDeltaVNeeded / FlightComputer.THRUST_ACCEL;

    // 调用制导系统开始 TOI 燃烧
    if (guidanceSystem != null) {
      guidanceSystem.startTOIBurn(currentMission.toiDeltaV);
    }

    dbgLog("TOI burn started: ΔV=" + (float)currentMission.toiDeltaV + " km/s");
  }

  // ==============================================================
  //  Update TOI burn
  // ==============================================================

  void updateTOIBurn() {
    burnDeltaVApplied = currentShip.toiAccumulatedDV;
    if (burnDeltaVApplied >= burnDeltaVNeeded) {
      completeTOIBurn();
    }
  }

  // ==============================================================
  //  Complete TOI burn
  // ==============================================================

  void completeTOIBurn() {
    currentShip.thrustActive = false;

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
          if (flightSystem != null) {
            flightSystem.setFixed(false);  // 通过 FlightSystem 解除固定
          }
          state = ShipState.LAUNCHING;
          dbgLog("Launch: 解除发射台固定，点火起飞");
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
