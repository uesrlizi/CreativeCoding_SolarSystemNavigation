// ============================================================
//  MISSION VALIDATOR - 任务验证器
//  功能：验证任务是否可行、计算Δv需求
// ============================================================

class MissionValidator {

  static final double MINIMUM_ORBIT_ALTITUDE = 150;

  MissionValidator() {
  }

  MissionValidationResult validateMission(MissionPreset preset, Spacecraft craft, CelestialSystem system) {
    MissionValidationResult result = new MissionValidationResult();

    if (preset == null) {
      result.canExecute = false;
      result.reason = "Mission preset is null";
      return result;
    }

    if (preset.requiredSpacecraftPreset != null && craft.presetId != null) {
      if (!craft.presetId.equals(preset.requiredSpacecraftPreset)) {
        result.canExecute = false;
        result.reason = "Spacecraft preset mismatch";
        return result;
      }
    }

    if (preset.initialOrbit != null) {
      if (!isValidOrbit(preset.initialOrbit)) {
        result.canExecute = false;
        result.reason = "Invalid initial orbit";
        return result;
      }
    }

    switch (preset.goal.type) {
      case REACH_ORBIT:
        result = validateOrbitMission(preset, craft);
        break;
      case TRANSFER_TO_BODY:
        result = validateTransferMission(preset, craft, system);
        break;
      case ORBIT_INSERTION:
        result = validateOrbitInsertion(preset, craft);
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

  MissionValidationResult validateTransferMission(MissionPreset preset, Spacecraft craft, CelestialSystem system) {
    MissionValidationResult result = new MissionValidationResult();

    CelestialBody target = preset.goal.targetBody;
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

    result.canExecute = true;
    result.requiredDeltaV = totalDV;
    result.reason = String.format("Transfer to %s requires %.3f km/s Δv", target.name, totalDV);

    MissionPlanner planner = new MissionPlanner();
    ManeuverNode tli = new ManeuverNode(0, new Vector2(dv1, 0));
    tli.description = "Trans-Lunar Injection";
    tli.direction = "prograde";
    tli.deltaVMagnitude = dv1;
    result.maneuvers = new ArrayList<ManeuverNode>();
    result.maneuvers.add(tli);

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
