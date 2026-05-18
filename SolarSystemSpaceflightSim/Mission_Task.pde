// ========== TASK & GOAL ==========

class MissionGoal {
  MissionGoalType type;
  CelestialBody targetBody;
  Orbit targetOrbit;
  double targetAltitude;
  double positionTolerance;
  double velocityTolerance;

  MissionGoal() {
    this.type = MissionGoalType.REACH_ORBIT;
    this.targetBody = null;
    this.targetOrbit = null;
    this.targetAltitude = 0;
    this.positionTolerance = 100; // km
    this.velocityTolerance = 0.1; // km/s
  }
}

class MissionPreset {
  String id;
  String name;
  String description;
  String requiredSpacecraftPreset;
  Orbit initialOrbit;
  CelestialBody initialBody;
  MissionGoal goal;

  MissionPreset(String id, String name, String description) {
    this.id = id;
    this.name = name;
    this.description = description;
    this.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
    this.initialOrbit = null;
    this.initialBody = null;
    this.goal = new MissionGoal();
  }
}

class MissionTask {
  String id;
  String name;
  MissionState state;
  MissionPreset preset;
  Spacecraft assignedCraft;
  double startTime;

  MissionTask(MissionPreset preset) {
    this.id = preset.id + "_" + System.currentTimeMillis();
    this.name = preset.name;
    this.preset = preset;
    this.state = MissionState.PENDING;
    this.assignedCraft = null;
    this.startTime = 0;
  }

  boolean canExecute(Spacecraft craft, CelestialSystem system) {
    return true; // 阶段3暂不验证
  }

  void startExecution(Spacecraft craft, CelestialSystem system, double simTime) {
    this.assignedCraft = craft;
    this.startTime = simTime;
    this.state = MissionState.IN_PROGRESS;
  }

  MissionState update(double simTime, double dt) {
    return this.state; // 阶段3暂不更新任务状态
  }

  boolean isCompleted() {
    return this.state == MissionState.COMPLETED;
  }

  boolean isFailed() {
    return this.state == MissionState.FAILED;
  }
}
