// ========== MISSION PRESETS ==========

static final String MISSION_PRESET_LAUNCH_TO_LEO = "launch_to_leo";
static final String MISSION_PRESET_LEO = "leo";
static final String MISSION_PRESET_GEO = "geo";
static final String MISSION_PRESET_LUNAR_TRANSFER = "lunar_transfer";

// 任务解锁状态
static boolean hasCompletedLaunchMission = false;

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

  // LEO任务
  if (earth != null) {
    MissionPreset leo = new MissionPreset(
      MISSION_PRESET_LEO,
      "Low Earth Orbit",
      "Start in a 400 km circular orbit around Earth."
    );
    leo.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
    leo.initialBody = earth;
    double a = EARTH_RADIUS_KM + 400;
    double e = 0.001;
    double w = 0.0;
    double M0 = 0.0;
    double period = 2 * PI * Math.sqrt(a * a * a / GM_EARTH);
    leo.initialOrbit = new Orbit(a, e, w, M0, 0.0, period, earth);
    leo.goal.type = MissionGoalType.REACH_ORBIT;
    leo.goal.targetBody = earth;
    missionPresets.add(leo);

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

  }
}

List<MissionPreset> getAllMissionPresets(CelestialSystem system) {
  if (missionPresets == null) initMissionPresets(system);
  return missionPresets;
}

MissionPreset getMissionPreset(String id, CelestialSystem system) {
  if (missionPresets == null) initMissionPresets(system);
  for (MissionPreset p : missionPresets) {
    if (p.id.equals(id)) return p;
  }
  return null;
}
