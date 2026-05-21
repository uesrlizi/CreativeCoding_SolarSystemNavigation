// ============================================================
//  MISSION VALIDATOR - 任务验证器
//  功能：验证任务是否可行、计算Δv需求
// ============================================================

class MissionValidator {

  static final double MINIMUM_ORBIT_ALTITUDE = 150;

  MissionValidator() {
  }

  MissionValidationResult validateMission(MissionPreset preset, Spacecraft craft, CelestialSystem system, double simTime) {
    MissionValidationResult result = new MissionValidationResult();

    println("[MissionValidator] Validating mission: " + (preset != null ? preset.name : "null"));

    if (preset == null) {
      result.canExecute = false;
      result.reason = "Mission preset is null";
      println("[MissionValidator] FAILED: " + result.reason);
      return result;
    }

    println("[MissionValidator] Mission type: " + preset.goal.type);
    println("[MissionValidator] Spacecraft: " + (craft != null ? "exists" : "null"));
    if (craft != null) {
      println("[MissionValidator]   - referenceBody: " + (craft.referenceBody != null ? craft.referenceBody.name : "null"));
      println("[MissionValidator]   - orbit: " + (craft.orbit != null ? "exists" : "null"));
      println("[MissionValidator]   - stateVector: " + (craft.stateVector != null ? "exists" : "null"));
      if (craft.stateVector != null && craft.referenceBody != null) {
        double r = craft.stateVector.position.magnitude();
        double alt = r - craft.referenceBody.radius;
        println("[MissionValidator]   - altitude: " + alt + " km");
      }
    }

    if (preset.requiredSpacecraftPreset != null && craft.presetId != null) {
      if (!craft.presetId.equals(preset.requiredSpacecraftPreset)) {
        result.canExecute = false;
        result.reason = "Spacecraft preset mismatch";
        println("[MissionValidator] FAILED: " + result.reason);
        return result;
      }
    }

    if (preset.initialOrbit != null) {
      if (!isValidOrbit(preset.initialOrbit)) {
        result.canExecute = false;
        result.reason = "Invalid initial orbit";
        println("[MissionValidator] FAILED: " + result.reason);
        return result;
      }
    }

    switch (preset.goal.type) {
      case LAUNCH_TO_ORBIT:
        result = validateLaunchMission(preset, craft);
        break;
      case REACH_ORBIT:
        result = validateOrbitMission(preset, craft);
        break;
      case TRANSFER_TO_BODY:
        result = validateTransferMission(preset, craft, system, simTime);
        break;
      case ORBIT_INSERTION:
        // 如果目标是月球，用专门的地月转移逻辑
        if (preset.goal.targetBody != null && preset.goal.targetBody.name.equals("Moon")) {
          result = validateLunarOrbitInsertionMission(preset, craft, system, simTime);
        } else {
          result = validateOrbitInsertion(preset, craft);
        }
        break;
      case RETURN_TO_LAUNCHSITE:
        result = validateReturnToLaunchSiteMission(preset, craft, system, simTime);
        break;
      case LAND:
      case CRASH:
        result.canExecute = true;
        result.reason = "Landing/crash mission (not validated in Phase 5)";
        break;
      default:
        result.canExecute = false;
        result.reason = "Unknown mission type";
        break;
    }

    println("[MissionValidator] Result: canExecute=" + result.canExecute + ", reason=" + result.reason);
    return result;
  }

  // ========== 验证返回发射场任务 ==========
  MissionValidationResult validateReturnToLaunchSiteMission(MissionPreset preset, Spacecraft craft, CelestialSystem system, double simTime) {
    MissionValidationResult result = new MissionValidationResult();

    println("[ReturnMission] Starting validation...");

    if (craft == null) {
      result.canExecute = false;
      result.reason = "No spacecraft available";
      println("[ReturnMission] FAILED: " + result.reason);
      return result;
    }

    CelestialBody earth = system.getEarth();
    if (earth == null) {
      result.canExecute = false;
      result.reason = "Earth not found";
      println("[ReturnMission] FAILED: " + result.reason);
      return result;
    }

    if (craft.referenceBody == null || !craft.referenceBody.name.equals("Earth")) {
      result.canExecute = false;
      result.reason = "Spacecraft must be orbiting Earth";
      println("[ReturnMission] FAILED: " + result.reason);
      return result;
    }

    // 检查飞船是否有有效的轨道或状态向量
    boolean hasValidState = (craft.orbit != null ||
                            (craft.stateVector != null &&
                             craft.stateVector.position != null &&
                             craft.stateVector.velocity != null));

    if (!hasValidState) {
      result.canExecute = false;
      result.reason = "No valid orbit or state vector available";
      println("[ReturnMission] FAILED: " + result.reason);
      return result;
    }

    // 计算当前高度
    double altitude = -1;
    if (craft.orbit != null) {
      altitude = craft.orbit.getApoapsisAltitude();
    } else if (craft.stateVector != null) {
      double r = craft.stateVector.position.magnitude();
      altitude = r - earth.radius;
    }

    println("[ReturnMission] Current altitude: " + altitude + " km");

    // 只要在地球轨道上就可以执行返回任务
    result.canExecute = true;
    result.requiredDeltaV = 0.15; // 大约需要 150 m/s 进行离轨制动
    result.reason = String.format("Ready to deorbit from %.1f km altitude", altitude);
    result.maneuvers = new ArrayList<ManeuverNode>(); // 返回任务不需要预先规划机动，RecoveryController 会处理

    println("[ReturnMission] SUCCESS: " + result.reason);
    return result;
  }

  MissionValidationResult validateOrbitMission(MissionPreset preset, Spacecraft craft) {
    MissionValidationResult result = new MissionValidationResult();

    if (preset.goal.targetOrbit == null) {
      result.canExecute = true;
      result.requiredDeltaV = 0;
      result.reason = "Orbit maintenance mission";
      return result;
    }

    MissionPlanner planner = new MissionPlanner();
    List<ManeuverNode> maneuvers = planner.planHohmannTransfer(preset.initialOrbit, preset.goal.targetOrbit);
    double dv = planner.getTotalDeltaV(maneuvers);

    result.canExecute = true;
    result.requiredDeltaV = dv;
    result.maneuvers = maneuvers;
    result.reason = String.format("Orbit transfer requires %.3f km/s Δv", dv);

    return result;
  }

  MissionValidationResult validateTransferMission(MissionPreset preset, Spacecraft craft, CelestialSystem system, double simTime) {
    // 如果目标是月球且是ORBIT_INSERTION，使用新的简化方案
    CelestialBody target = preset.goal.targetBody;
    if (target != null && target.name.equals("Moon") && preset.goal.type == MissionGoalType.ORBIT_INSERTION) {
      return validateLunarOrbitInsertionMission(preset, craft, system, simTime);
    }

    // 否则使用原逻辑
    MissionValidationResult result = new MissionValidationResult();

    if (target == null) {
      result.canExecute = false;
      result.reason = "No target body specified";
      return result;
    }

    double r1 = EARTH_RADIUS_KM + 400;
    double r2 = target.a;
    double a_trans = (r1 + r2) / 2;

    double v1 = Math.sqrt(GM_EARTH / r1);
    double v_trans_peri = Math.sqrt(GM_EARTH * (2 / r1 - 1 / a_trans));
    double dv1 = v_trans_peri - v1;

    double dv_capture = 0.5;
    double totalDV = dv1 + dv_capture;

    MissionPlanner planner = new MissionPlanner();
    CelestialBody earth = system.getEarth();
    double waitTime = 0;
    String waitInfo = "";
    if (earth != null && target.name.equals("Moon")) {
      Orbit orbitToUse = (craft.orbit != null) ? craft.orbit : preset.initialOrbit;
      waitTime = planner.calculateSimpleLunarWindow(earth, target, orbitToUse, simTime);
      if (waitTime > 0) {
        waitInfo = String.format(", wait %.1f hours for alignment", waitTime / 3600);
      }
    }

    result.canExecute = true;
    result.requiredDeltaV = totalDV;
    result.reason = String.format("Transfer to %s requires %.3f km/s Δv%s", target.name, totalDV, waitInfo);

    ManeuverNode tli = new ManeuverNode(waitTime, new Vector2(dv1, 0));
    tli.description = "Trans-Lunar Injection";
    tli.direction = "prograde";
    tli.deltaVMagnitude = dv1;
    result.maneuvers = new ArrayList<ManeuverNode>();
    result.maneuvers.add(tli);

    return result;
  }

  // ========== 验证月球轨道插入任务 ==========
  MissionValidationResult validateLunarOrbitInsertionMission(MissionPreset preset, Spacecraft craft,
                                                              CelestialSystem system, double simTime) {
    MissionValidationResult result = new MissionValidationResult();

    CelestialBody earth = system.getEarth();
    CelestialBody moon = preset.goal.targetBody;

    if (earth == null || moon == null) {
      result.canExecute = false;
      result.reason = "Earth or Moon not found";
      return result;
    }

    // 使用飞船当前的实际轨道，而不是 preset 的初始轨道
    Orbit orbitToUse = (craft.orbit != null) ? craft.orbit : preset.initialOrbit;

    // 使用解析法计算窗口
    MissionPlanner planner = new MissionPlanner();
    double waitTime = planner.calculateSimpleLunarWindow(earth, moon, orbitToUse, simTime);

    // 规划完整的双机动任务
    List<ManeuverNode> maneuvers = planner.planLunarMission(earth, moon, orbitToUse, simTime, waitTime);

    // 计算总Δv
    double totalDV = planner.getTotalDeltaV(maneuvers);

    // 构建提示信息
    String waitInfo = "";
    if (waitTime < 60) {
      waitInfo = String.format("wait %.0f seconds", waitTime);
    } else if (waitTime < 3600) {
      waitInfo = String.format("wait %.1f minutes", waitTime / 60);
    } else {
      waitInfo = String.format("wait %.1f hours", waitTime / 3600);
    }

    result.canExecute = true;
    result.requiredDeltaV = totalDV;
    result.reason = String.format("Lunar transfer: TLI + LOI, %.3f km/s total, %s", totalDV, waitInfo);
    result.maneuvers = maneuvers;

    return result;
  }

  MissionValidationResult validateOrbitInsertion(MissionPreset preset, Spacecraft craft) {
    MissionValidationResult result = new MissionValidationResult();

    result.canExecute = true;
    result.requiredDeltaV = 1.0;
    result.reason = "Orbit insertion mission";

    return result;
  }

  boolean isValidOrbit(Orbit orbit) {
    if (orbit == null) return false;
    if (orbit.referenceBody == null) return false;
    if (orbit.a <= 0) return false;
    if (orbit.e < 0 || orbit.e >= 1) return false;

    double peAltitude = orbit.getPeriapsisAltitude();
    if (peAltitude < MINIMUM_ORBIT_ALTITUDE) {
      return false;
    }

    return true;
  }

  // ========== 验证发射任务 ==========
  MissionValidationResult validateLaunchMission(MissionPreset preset, Spacecraft craft) {
    MissionValidationResult result = new MissionValidationResult();

    // 发射任务总是可行（只要飞船在发射场）
    result.canExecute = true;

    // 计算发射到LEO所需的理论Δv
    // 大约需要9.5 km/s（包括重力损失和空气阻力损失）
    double requiredDeltaV = 9.5;

    result.requiredDeltaV = requiredDeltaV;
    result.reason = String.format("Launch to LEO - Estimated Δv: %.1f km/s", requiredDeltaV);

    // 发射任务不需要预先规划机动节点，LaunchController会处理
    result.maneuvers = new ArrayList<ManeuverNode>();

    return result;
  }
}

class MissionValidationResult {
  boolean canExecute;
  String reason;
  double requiredDeltaV;
  List<ManeuverNode> maneuvers;

  MissionValidationResult() {
    this.canExecute = false;
    this.reason = "Unknown";
    this.requiredDeltaV = 0;
    this.maneuvers = null;
  }
}
