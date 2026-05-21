// ========== MISSION PRESETS ==========

static final String MISSION_PRESET_LAUNCH_TO_LEO = "launch_to_leo";
static final String MISSION_PRESET_GEO = "geo";
static final String MISSION_PRESET_LUNAR_TRANSFER = "lunar_transfer";
static final String MISSION_PRESET_RETURN_TO_LAUNCH_SITE = "return_to_launch_site";

// 游戏进度状态
static GameProgressState currentGameProgress = GameProgressState.GROUNDED;

private List<MissionPreset> missionPresets;

void initMissionPresets(CelestialSystem system) {
  missionPresets = new ArrayList<MissionPreset>();

  CelestialBody earth = system.getEarth();
  CelestialBody moon = null;
  for (CelestialBody m : system.moons) {
    if (m.name.equals("Moon")) {
      moon = m;
      break;
    }
  }

  // 发射到LEO任务
  MissionPreset launchToLeo = new MissionPreset(
    MISSION_PRESET_LAUNCH_TO_LEO,
    "Launch to LEO",
    "Launch from Earth's surface to Low Earth Orbit."
  );
  launchToLeo.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
  launchToLeo.initialBody = earth;
  launchToLeo.initialOrbit = null;  // 从地表开始
  launchToLeo.goal.type = MissionGoalType.LAUNCH_TO_ORBIT;
  launchToLeo.goal.targetBody = earth;
  double leoA = EARTH_RADIUS_KM + LEO_ALTITUDE_KM;
  double leoPeriod = 2 * PI * Math.sqrt(leoA * leoA * leoA / GM_EARTH);
  launchToLeo.goal.targetOrbit = new Orbit(leoA, 0.001, 0.0, 0.0, leoPeriod, earth);
  missionPresets.add(launchToLeo);

  if (earth != null) {
    // GEO任务
    MissionPreset geo = new MissionPreset(
      MISSION_PRESET_GEO,
      "Geostationary Orbit",
      "Hohmann transfer from LEO to geostationary orbit."
    );
    geo.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
    geo.initialBody = earth;
    double aLEO = EARTH_RADIUS_KM + 400;
    double periodLEO = 2 * PI * Math.sqrt(aLEO * aLEO * aLEO / GM_EARTH);
    geo.initialOrbit = new Orbit(aLEO, 0.001, 0.0, 0.0, 0.0, periodLEO, earth);
    geo.goal.type = MissionGoalType.REACH_ORBIT;
    geo.goal.targetBody = earth;
    double aGEO = EARTH_RADIUS_KM + 35786;
    double periodGEO = 2 * PI * Math.sqrt(aGEO * aGEO * aGEO / GM_EARTH);
    geo.goal.targetOrbit = new Orbit(aGEO, 0.001, 0.0, 0.0, 0.0, periodGEO, earth);
    missionPresets.add(geo);

    // 月球转移任务
    if (moon != null) {
      MissionPreset lunar = new MissionPreset(
        MISSION_PRESET_LUNAR_TRANSFER,
        "Lunar Transfer",
        "Start in LEO, perform TLI to transfer to Moon, then LOI to enter lunar orbit."
      );
      lunar.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
      lunar.initialBody = earth;
      double aLunar = EARTH_RADIUS_KM + 400;
      double periodLunar = 2 * PI * Math.sqrt(aLunar * aLunar * aLunar / GM_EARTH);
      lunar.initialOrbit = new Orbit(aLunar, 0.001, 0.0, 0.0, 0.0, periodLunar, earth);
      lunar.goal.type = MissionGoalType.ORBIT_INSERTION;
      lunar.goal.targetBody = moon;
      // 目标：100km环月圆轨道
      double aTarget = moon.radius + 100;
      double periodTarget = 2 * PI * Math.sqrt(aTarget * aTarget * aTarget / moon.GM);
      lunar.goal.targetOrbit = new Orbit(aTarget, 0.001, 0.0, 0.0, 0.0, periodTarget, moon);
      missionPresets.add(lunar);
    }

    // 回收任务
    if (earth != null) {
      MissionPreset recovery = new MissionPreset(
        MISSION_PRESET_RETURN_TO_LAUNCH_SITE,
        "Return to Launch Site",
        "Deorbit from current orbit, reenter atmosphere, and perform propulsive landing at the launch site."
      );
      recovery.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
      recovery.initialBody = earth;
      recovery.goal.type = MissionGoalType.RETURN_TO_LAUNCHSITE;
      recovery.goal.targetBody = earth;
      missionPresets.add(recovery);
    }
  }
}

List<MissionPreset> getAllMissionPresets(CelestialSystem system) {
  if (missionPresets == null) initMissionPresets(system);
  return missionPresets;
}

List<MissionPreset> getAvailableMissionPresets(CelestialSystem system) {
  List<MissionPreset> all = getAllMissionPresets(system);
  List<MissionPreset> available = new ArrayList<MissionPreset>();

  for (MissionPreset p : all) {
    if (!isMissionLocked(p)) {
      available.add(p);
    }
  }
  return available;
}

MissionPreset getMissionPreset(String id, CelestialSystem system) {
  if (missionPresets == null) initMissionPresets(system);
  for (MissionPreset p : missionPresets) {
    if (p.id.equals(id)) return p;
  }
  return null;
}

boolean isMissionLocked(MissionPreset preset) {
  switch (currentGameProgress) {
    case GROUNDED:
      // 地面状态只能选发射任务
      return !preset.id.equals(MISSION_PRESET_LAUNCH_TO_LEO);
    case IN_LEO:
      // LEO状态可以选同步轨道、月球转移或回收任务
      return preset.id.equals(MISSION_PRESET_LAUNCH_TO_LEO);
    case IN_GEO:
    case AT_MOON:
      // 终态，所有任务锁定
      return true;
    default:
      return true;
  }
}
