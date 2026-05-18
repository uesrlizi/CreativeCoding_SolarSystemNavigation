// ============================================================
//  MISSION EXECUTOR - 任务执行器
//  功能：自动执行机动序列
// ============================================================

enum MissionExecutorState {
  IDLE,
  WAITING_FOR_MANEUVER,
  ORIENTING,
  BURNING,
  COMPLETED,
  FAILED
}

class MissionExecutor {

  MissionExecutorState state;
  MissionTask currentTask;
  List<ManeuverNode> maneuverSequence;
  int currentManeuverIndex;

  Spacecraft assignedCraft;
  CelestialSystem solarSystem;

  double missionStartTime;
  double currentManeuverTime;

  String statusText;
  double progress;

  MissionExecutor() {
    this.state = MissionExecutorState.IDLE;
    this.currentTask = null;
    this.maneuverSequence = new ArrayList<ManeuverNode>();
    this.currentManeuverIndex = 0;
    this.assignedCraft = null;
    this.solarSystem = null;
    this.missionStartTime = 0;
    this.currentManeuverTime = 0;
    this.statusText = "Idle";
    this.progress = 0;
  }

  void startMission(MissionTask task, List<ManeuverNode> maneuvers, Spacecraft craft, CelestialSystem system, double simTime) {
    this.currentTask = task;
    this.maneuverSequence = maneuvers;
    this.assignedCraft = craft;
    this.solarSystem = system;
    this.missionStartTime = simTime;
    this.currentManeuverIndex = 0;

    if (maneuvers == null || maneuvers.size() == 0) {
      this.state = MissionExecutorState.FAILED;
      this.statusText = "No maneuvers to execute";
      return;
    }

    for (ManeuverNode node : maneuvers) {
      node.calculateBurnDuration(craft);
    }

    if (craft.autoControl != null) {
      craft.autoControl.isActive = true;
    }

    this.state = MissionExecutorState.WAITING_FOR_MANEUVER;
    this.statusText = String.format("Waiting for maneuver %d/%d", 1, maneuvers.size());
    updateProgress();

    ManeuverNode firstNode = maneuvers.get(0);
    if (firstNode.time <= 0) {
      startManeuver(firstNode, simTime);
    }
  }

  void update(double simTime, double dt) {
    if (assignedCraft == null) return;
    if (state == MissionExecutorState.IDLE ||
        state == MissionExecutorState.COMPLETED ||
        state == MissionExecutorState.FAILED) {
      return;
    }

    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.update(assignedCraft, dt);
    }

    switch (state) {
      case WAITING_FOR_MANEUVER:
        updateWaiting(simTime);
        break;
      case ORIENTING:
        updateOrienting(simTime);
        break;
      case BURNING:
        updateBurning(simTime, dt);
        break;
      default:
        break;
    }

    updateProgress();
  }

  private void updateWaiting(double simTime) {
    if (currentManeuverIndex >= maneuverSequence.size()) {
      completeMission();
      return;
    }

    ManeuverNode currentNode = maneuverSequence.get(currentManeuverIndex);
    double timeSinceStart = simTime - missionStartTime;
    double timeToManeuver = currentNode.time - timeSinceStart;

    if (timeToManeuver <= 0) {
      startManeuver(currentNode, simTime);
    } else {
      statusText = String.format("T-%s to maneuver %d/%d",
                                formatTime(timeToManeuver),
                                currentManeuverIndex + 1,
                                maneuverSequence.size());
    }
  }

  private void startManeuver(ManeuverNode node, double simTime) {
    currentManeuverTime = simTime;

    Vector2 targetDir = getManeuverDirection(node);

    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.setTargetDirection(targetDir);
    }

    this.state = MissionExecutorState.ORIENTING;
    this.statusText = String.format("Orienting for maneuver %d/%d",
                                   currentManeuverIndex + 1,
                                   maneuverSequence.size());

    assignedCraft.enterOffRails();
  }

  private void updateOrienting(double simTime) {
    if (assignedCraft.autoControl == null) {
      startBurning();
      return;
    }

    if (assignedCraft.autoControl.isOriented()) {
      startBurning();
    } else {
      statusText = String.format("Orienting (%.1f° error)",
                                Math.toDegrees(Math.abs(assignedCraft.autoControl.orientationError)));
    }
  }

  private void startBurning() {
    ManeuverNode node = maneuverSequence.get(currentManeuverIndex);

    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.setBurn(1.0f, node.burnDuration);
    }

    if (assignedCraft.mainEngine != null) {
      assignedCraft.mainEngine.setThrottle(1.0f);
    }

    this.state = MissionExecutorState.BURNING;
    this.statusText = String.format("Burning maneuver %d/%d",
                                   currentManeuverIndex + 1,
                                   maneuverSequence.size());
  }

  private void updateBurning(double simTime, double dt) {
    ManeuverNode node = maneuverSequence.get(currentManeuverIndex);

    boolean burnComplete = false;

    if (assignedCraft.autoControl != null) {
      burnComplete = !assignedCraft.autoControl.isBurning ||
                    assignedCraft.autoControl.burnTimeRemaining <= 0;
    } else {
      double burnTime = simTime - currentManeuverTime;
      burnComplete = burnTime >= node.burnDuration;
    }

    if (burnComplete) {
      completeManeuver(simTime);
    } else {
      double remaining = 0;
      if (assignedCraft.autoControl != null) {
        remaining = assignedCraft.autoControl.burnTimeRemaining;
      }
      statusText = String.format("Burning... %s remaining", formatTime(remaining));
    }
  }

  private void completeManeuver(double simTime) {
    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.targetThrottle = 0;
    }
    if (assignedCraft.mainEngine != null) {
      assignedCraft.mainEngine.shutdown();
    }

    currentManeuverIndex++;

    assignedCraft.enterOnRails();

    if (currentManeuverIndex >= maneuverSequence.size()) {
      completeMission();
    } else {
      this.state = MissionExecutorState.WAITING_FOR_MANEUVER;
      statusText = String.format("Waiting for maneuver %d/%d",
                                currentManeuverIndex + 1,
                                maneuverSequence.size());
    }
  }

  private void completeMission() {
    this.state = MissionExecutorState.COMPLETED;
    this.statusText = "Mission completed!";
    this.progress = 1.0;

    if (currentTask != null) {
      currentTask.state = MissionState.COMPLETED;
    }

    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.stop();
    }
  }

  private Vector2 getManeuverDirection(ManeuverNode node) {
    if (node.direction != null && assignedCraft != null) {
      switch (node.direction) {
        case "prograde":
          return assignedCraft.getPrograde();
        case "retrograde":
          return assignedCraft.getRetrograde();
        case "radial_out":
          return assignedCraft.getRadialOut();
        case "radial_in":
          return assignedCraft.getRadialIn();
      }
    }
    return assignedCraft.getPrograde();
  }

  private void updateProgress() {
    if (maneuverSequence == null || maneuverSequence.size() == 0) {
      progress = 0;
      return;
    }
    progress = (double)currentManeuverIndex / maneuverSequence.size();
  }

  private String formatTime(double seconds) {
    if (seconds < 60) {
      return String.format("%.1fs", seconds);
    } else if (seconds < 3600) {
      double mins = seconds / 60;
      return String.format("%.1fm", mins);
    } else {
      double hours = seconds / 3600;
      return String.format("%.1fh", hours);
    }
  }

  int getRecommendedWarpLevel(TimeManager timeManager) {
    switch (state) {
      case WAITING_FOR_MANEUVER:
        return timeManager.WARP_LEVELS.length - 2;
      case ORIENTING:
      case BURNING:
        return 0;
      default:
        return 0;
    }
  }

  boolean shouldPauseWarp() {
    return state == MissionExecutorState.ORIENTING ||
           state == MissionExecutorState.BURNING;
  }

  void abortMission() {
    if (assignedCraft != null && assignedCraft.autoControl != null) {
      assignedCraft.autoControl.stop();
    }
    if (assignedCraft != null && assignedCraft.mainEngine != null) {
      assignedCraft.mainEngine.shutdown();
    }
    this.state = MissionExecutorState.FAILED;
    this.statusText = "Mission aborted";
  }
}
