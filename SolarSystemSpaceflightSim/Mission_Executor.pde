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

  private double lastUpdateSimTime;  // 上次更新的模拟时间
  private double currentTickSimTime;  // 当前 tick 的模拟时间 (用于子步)

  // 发射任务支持
  private boolean isLaunchMission;
  private LaunchController launchController;

  MissionExecutor() {
    this.state = MissionExecutorState.IDLE;
    this.currentTask = null;
    this.maneuverSequence = new ArrayList<ManeuverNode>();
    this.currentManeuverIndex = 0;
    this.assignedCraft = null;
    this.solarSystem = null;
    this.missionStartTime = 0;
    this.currentManeuverTime = 0;
    this.lastUpdateSimTime = 0;
    this.currentTickSimTime = 0;
    this.statusText = "Idle";
    this.progress = 0;
    this.isLaunchMission = false;
    this.launchController = new LaunchController();
  }

  // ========== 设置发射场 ==========
  void setLaunchSite(LaunchSite site, CelestialBody earth) {
    this.launchController.init(null, site, earth);
  }

  void startMission(MissionTask task, List<ManeuverNode> maneuvers, Spacecraft craft, CelestialSystem system, double simTime) {
    this.currentTask = task;
    this.maneuverSequence = maneuvers;
    this.assignedCraft = craft;
    this.solarSystem = system;
    this.missionStartTime = simTime;
    this.lastUpdateSimTime = simTime;
    this.currentManeuverIndex = 0;

    // 检查是否是发射任务
    this.isLaunchMission = (task.preset != null &&
                           task.preset.goal.type == MissionGoalType.LAUNCH_TO_ORBIT);

    if (this.isLaunchMission) {
      // 发射任务特殊处理
      startLaunchMission(simTime);
      return;
    }

    // 普通任务处理
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
    double timeSinceStart = 0;  // 刚启动，相对于任务开始时间为0
    double timeToIgnition = firstNode.ignitionTime - timeSinceStart;
    if (timeToIgnition <= 0) {
      startBurningImmediately(firstNode, simTime);
    }
  }

  // ========== 开始发射任务 ==========
  void startLaunchMission(double simTime) {
    // 初始化发射控制器
    launchController.init(assignedCraft, launchController.site, launchController.earth);

    // 启动发射
    launchController.startLaunch(simTime);

    this.state = MissionExecutorState.WAITING_FOR_MANEUVER;  // 使用这个状态表示发射进行中
    this.statusText = launchController.getStatusText(simTime);
    this.progress = 0;
  }

  // ========== 帧级别更新 (保持向后兼容) ==========
  void update(double simTime, double dt) {
    if (assignedCraft == null) return;
    if (state == MissionExecutorState.IDLE ||
        state == MissionExecutorState.COMPLETED ||
        state == MissionExecutorState.FAILED) {
      lastUpdateSimTime = simTime;
      return;
    }

    // 计算模拟时间步长
    double simDt = (lastUpdateSimTime > 0) ? (simTime - lastUpdateSimTime) : 0;
    if (simDt <= 0) simDt = 1.0 / 60.0;
    lastUpdateSimTime = simTime;

    // 直接调用 tick 版本 (统一逻辑)
    updateTick(simDt, simTime);
  }

  // ========== Tick 级别更新 ==========
  void updateTick(double tickDt, double tickSimTime) {
    if (assignedCraft == null) return;
    if (state == MissionExecutorState.IDLE ||
        state == MissionExecutorState.COMPLETED ||
        state == MissionExecutorState.FAILED) {
      return;
    }

    currentTickSimTime = tickSimTime;

    // tick 级别更新 autoControl
    if (assignedCraft.autoControl != null) {
      // assignedCraft.autoControl.updateTick(assignedCraft, tickDt);  // 由主循环统一调用
    }

    // 如果是发射任务，交给 LaunchController 处理
    if (isLaunchMission) {
      updateLaunchMissionTick(tickDt, tickSimTime);
      return;
    }

    // 普通任务处理
    switch (state) {
      case WAITING_FOR_MANEUVER:
        updateWaiting(tickSimTime);
        break;
      case ORIENTING:
        updateOrienting(tickSimTime);
        break;
      case BURNING:
        updateBurningTick(tickDt, tickSimTime);
        break;
      default:
        break;
    }

    updateProgress();
  }

  // ========== 更新发射任务 ==========
  void updateLaunchMissionTick(double tickDt, double tickSimTime) {
    launchController.update(tickSimTime, tickDt);

    // 更新状态文本
    statusText = launchController.getStatusText(tickSimTime);

    // 检查发射是否完成
    if (launchController.isLaunchComplete()) {
      completeLaunchMission(tickSimTime);
    }

    // 更新进度（简单估算：从倒计时到入轨）
    double elapsed = tickSimTime - missionStartTime;
    if (assignedCraft.launchState == LaunchState.ON_PAD) {
      progress = 0;
    } else if (assignedCraft.launchState == LaunchState.COUNTDOWN) {
      progress = 0.05 * (elapsed / Spacecraft.COUNTDOWN_DURATION);
    } else if (assignedCraft.launchState == LaunchState.IGNITION) {
      progress = 0.05 + 0.02 * ((elapsed - Spacecraft.COUNTDOWN_DURATION) / Spacecraft.IGNITION_DURATION);
    } else if (assignedCraft.launchState == LaunchState.LAUNCHING) {
      progress = 0.07 + 0.83 * Math.min(elapsed / 300.0, 1.0);  // 假设上升需要5分钟
    } else if (assignedCraft.launchState == LaunchState.CIRCULARIZING) {
      progress = 0.9;
    } else if (assignedCraft.launchState == LaunchState.IN_ORBIT) {
      progress = 1.0;
    }
  }

  // ========== 完成发射任务 ==========
  void completeLaunchMission(double simTime) {
    // 切换游戏进度到 LEO
    currentGameProgress = GameProgressState.IN_LEO;

    // 完成任务
    this.state = MissionExecutorState.COMPLETED;
    this.statusText = "Launch mission complete!";
    this.progress = 1.0;

    if (currentTask != null) {
      currentTask.state = MissionState.COMPLETED;
    }

    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.stop();
    }

    println("Launch mission complete - now in LEO!");
  }

  private void updateWaiting(double simTime) {
    if (currentManeuverIndex >= maneuverSequence.size()) {
      completeMission();
      return;
    }

    ManeuverNode currentNode = maneuverSequence.get(currentManeuverIndex);
    double timeSinceStart = simTime - missionStartTime;
    double timeToIgnition = currentNode.ignitionTime - timeSinceStart;
    double timeToMidpoint = currentNode.time - timeSinceStart;

    if (timeToIgnition <= 0) {
      // 到达点火时间，直接开始燃烧
      startBurningImmediately(currentNode, simTime);
    } else if (timeToIgnition <= 3.0) {
      // 点火前3秒，开始定向旋转
      startOrientingEarly(currentNode, simTime);
    } else {
      statusText = String.format("T-%s to maneuver %d/%d (burn %.1fs)",
                                formatTime(timeToMidpoint),
                                currentManeuverIndex + 1,
                                maneuverSequence.size(),
                                currentNode.burnDuration);
    }
  }

  private void startOrientingEarly(ManeuverNode node, double simTime) {
    currentManeuverTime = simTime;

    Vector2 targetDir = getManeuverDirection(node);

    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.setTargetDirection(targetDir);
    }

    this.state = MissionExecutorState.ORIENTING;
    this.statusText = String.format("Orienting early for maneuver %d/%d",
                                   currentManeuverIndex + 1,
                                   maneuverSequence.size());

    assignedCraft.enterOffRails();
  }

  private void startBurningImmediately(ManeuverNode node, double simTime) {
    currentManeuverTime = simTime;

    // 设置目标方向（万一还没开始定向）
    Vector2 targetDir = getManeuverDirection(node);
    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.setTargetDirection(targetDir);
    }

    assignedCraft.enterOffRails();

    // 直接开始燃烧，不等待定向完成
    startBurning();
  }

  private void updateOrienting(double simTime) {
    ManeuverNode currentNode = maneuverSequence.get(currentManeuverIndex);
    double timeSinceStart = simTime - missionStartTime;
    double timeToIgnition = currentNode.ignitionTime - timeSinceStart;

    // 持续更新目标方向（因为速度在变，ΔV方向也可能需要微调）
    Vector2 targetDir = getManeuverDirection(currentNode);
    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.setTargetDirection(targetDir);
    }

    if (timeToIgnition <= 0) {
      // 到达点火时间，立即开始燃烧，不管定向是否完成
      startBurning();
    } else {
      statusText = String.format("Orienting (%.1f° error, T-ignition %.1fs)",
                                Math.toDegrees(Math.abs(assignedCraft.autoControl.orientationError)),
                                timeToIgnition);
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

  // ========== 原有 Burning 更新 (保持兼容) ==========
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

  // ========== Tick 级别 Burning 更新 (新) ==========
  private void updateBurningTick(double tickDt, double tickSimTime) {
    ManeuverNode node = maneuverSequence.get(currentManeuverIndex);

    boolean burnComplete = false;

    if (assignedCraft.autoControl != null) {
      // 检查燃烧是否完成 (autoControl.updateTick 已在上层调用)
      burnComplete = !assignedCraft.autoControl.isBurning ||
                    assignedCraft.autoControl.burnTimeRemaining <= 0;
    } else {
      double burnTime = tickSimTime - currentManeuverTime;
      burnComplete = burnTime >= node.burnDuration;
    }

    if (burnComplete) {
      completeManeuver(tickSimTime);
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

      // 根据完成的任务切换游戏进度状态
      if (currentTask.preset != null) {
        String presetId = currentTask.preset.id;
        if (presetId.equals(MISSION_PRESET_GEO)) {
          currentGameProgress = GameProgressState.IN_GEO;
          println("Mission complete - now in Geostationary Orbit!");
        } else if (presetId.equals(MISSION_PRESET_LUNAR_TRANSFER)) {
          currentGameProgress = GameProgressState.AT_MOON;
          println("Mission complete - now at the Moon!");
        }
      }
    }

    if (assignedCraft.autoControl != null) {
      assignedCraft.autoControl.stop();
    }
  }

  private Vector2 getManeuverDirection(ManeuverNode node) {
    if (node.useDeltaVDirection && assignedCraft != null) {
      // 按ΔV矢量方向定向 - 需要从LVLH坐标系转换到惯性坐标系
      if (node.deltaV.magnitudeSq() > 0.0001) {
        // 获取当前轨道坐标系基向量
        Vector2 prograde = assignedCraft.getPrograde();     // LVLH +X
        Vector2 radialOut = assignedCraft.getRadialOut();   // LVLH +Y

        // 将ΔV从LVLH坐标系转换到惯性坐标系
        // deltaV.x = prograde 分量, deltaV.y = radial_out 分量
        Vector2 inertialDir = new Vector2(
          node.deltaV.x * prograde.x + node.deltaV.y * radialOut.x,
          node.deltaV.x * prograde.y + node.deltaV.y * radialOut.y
        );

        if (inertialDir.magnitudeSq() > 0.0001) {
          return inertialDir.normalized();
        }
      }
    }

    // 兼容旧的方向模式
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
        return 2;  // 允许低档加速到1分钟/秒，物理系统有子步保证精度
      default:
        return -1;  // IDLE/COMPLETED/FAILED: no special restriction
    }
  }

  boolean shouldPauseWarp() {
    return state == MissionExecutorState.ORIENTING ||
           state == MissionExecutorState.BURNING;
  }

  // 获取距离下一个机动中点的时间（秒），返回负数表示没有或已错过
  double getTimeToNextManeuver(double currentSimTime) {
    if (state != MissionExecutorState.WAITING_FOR_MANEUVER) {
      return -1;
    }
    if (currentManeuverIndex >= maneuverSequence.size()) {
      return -1;
    }
    ManeuverNode node = maneuverSequence.get(currentManeuverIndex);
    double timeSinceStart = currentSimTime - missionStartTime;
    return node.time - timeSinceStart;  // 返回距离燃烧中点的时间
  }

  // 获取距离下一个点火时间的时间（秒），返回负数表示没有或已错过
  double getTimeToNextIgnition(double currentSimTime) {
    if (state != MissionExecutorState.WAITING_FOR_MANEUVER) {
      return -1;
    }
    if (currentManeuverIndex >= maneuverSequence.size()) {
      return -1;
    }
    ManeuverNode node = maneuverSequence.get(currentManeuverIndex);
    double timeSinceStart = currentSimTime - missionStartTime;
    return node.ignitionTime - timeSinceStart;  // 返回距离点火的时间
  }

  // 辅助函数：规范化角度到[0, TWO_PI)
  double normalizeAngle(double angle) {
    while (angle < 0) angle += TWO_PI;
    while (angle >= TWO_PI) angle -= TWO_PI;
    return angle;
  }

  // Abort disabled - missions cannot be aborted
  void abortMission() {
    // Do nothing - missions must run to completion
  }

  // 获取脐带臂展开进度 (用于渲染)
  float getUmbilicalDeployProgress() {
    if (isLaunchMission && launchController != null) {
      return launchController.getUmbilicalDeployProgress();
    }
    return 0.0f;
  }
}
