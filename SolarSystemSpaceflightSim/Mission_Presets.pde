// ========== MISSION PRESETS ==========

static final String MISSION_PRESET_LEO = "leo";
static final String MISSION_PRESET_GEO = "geo";
static final String MISSION_PRESET_LUNAR_TRANSFER = "lunar_transfer";

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
      "Start in a 35786 km geostationary orbit around Earth."
    );
    geo.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
    geo.initialBody = earth;
    double aGeo = EARTH_RADIUS_KM + 35786;
    double periodGeo = 2 * PI * Math.sqrt(aGeo * aGeo * aGeo / GM_EARTH);
    geo.initialOrbit = new Orbit(aGeo, 0.001, 0.0, 0.0, 0.0, periodGeo, earth);
    geo.goal.type = MissionGoalType.REACH_ORBIT;
    geo.goal.targetBody = earth;
    missionPresets.add(geo);

    // 月球转移任务
    if (moon != null) {
      MissionPreset lunar = new MissionPreset(
        MISSION_PRESET_LUNAR_TRANSFER,
        "Lunar Transfer",
        "Start in LEO, goal is to reach the Moon's SOI."
      );
      lunar.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
      lunar.initialBody = earth;
      double aLunar = EARTH_RADIUS_KM + 400;
      double periodLunar = 2 * PI * Math.sqrt(aLunar * aLunar * aLunar / GM_EARTH);
      lunar.initialOrbit = new Orbit(aLunar, 0.001, 0.0, 0.0, 0.0, periodLunar, earth);
      lunar.goal.type = MissionGoalType.TRANSFER_TO_BODY;
      lunar.goal.targetBody = moon;
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
