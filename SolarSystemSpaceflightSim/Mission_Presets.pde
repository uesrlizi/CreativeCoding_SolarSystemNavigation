// ========== MISSION PRESETS ==========

static final String MISSION_PRESET_LEO = "leo";
static final String MISSION_PRESET_GEO = "geo";
static final String MISSION_PRESET_LUNAR_TRANSFER = "lunar_transfer";

static final String MISSION_TEST_LEO_RAISE = "test_leo_raise";
static final String MISSION_TEST_GEO_TRANSFER = "test_geo_transfer";
static final String MISSION_TEST_MOON_FLYBY = "test_moon_flyby";

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

    // 测试任务1：LEO轨道提升
    MissionPreset testLeoRaise = new MissionPreset(
      MISSION_TEST_LEO_RAISE,
      "TEST: LEO Raise",
      "Test mission: Raise orbit from 200 km to 500 km."
    );
    testLeoRaise.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
    testLeoRaise.initialBody = earth;
    double aInit = EARTH_RADIUS_KM + 200;
    double periodInit = 2 * PI * Math.sqrt(aInit * aInit * aInit / GM_EARTH);
    testLeoRaise.initialOrbit = new Orbit(aInit, 0.001, 0.0, 0.0, 0.0, periodInit, earth);
    testLeoRaise.goal.type = MissionGoalType.REACH_ORBIT;
    testLeoRaise.goal.targetBody = earth;
    double aTarget = EARTH_RADIUS_KM + 500;
    double periodTarget = 2 * PI * Math.sqrt(aTarget * aTarget * aTarget / GM_EARTH);
    testLeoRaise.goal.targetOrbit = new Orbit(aTarget, 0.001, 0.0, 0.0, 0.0, periodTarget, earth);
    missionPresets.add(testLeoRaise);

    // 测试任务2：GEO转移
    MissionPreset testGeoTransfer = new MissionPreset(
      MISSION_TEST_GEO_TRANSFER,
      "TEST: GEO Transfer",
      "Test mission: Hohmann transfer to geostationary orbit."
    );
    testGeoTransfer.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
    testGeoTransfer.initialBody = earth;
    double aGeoInit = EARTH_RADIUS_KM + 400;
    double periodGeoInit = 2 * PI * Math.sqrt(aGeoInit * aGeoInit * aGeoInit / GM_EARTH);
    testGeoTransfer.initialOrbit = new Orbit(aGeoInit, 0.001, 0.0, 0.0, 0.0, periodGeoInit, earth);
    testGeoTransfer.goal.type = MissionGoalType.REACH_ORBIT;
    testGeoTransfer.goal.targetBody = earth;
    double aGeoTarget = EARTH_RADIUS_KM + 35786;
    double periodGeoTarget = 2 * PI * Math.sqrt(aGeoTarget * aGeoTarget * aGeoTarget / GM_EARTH);
    testGeoTransfer.goal.targetOrbit = new Orbit(aGeoTarget, 0.001, 0.0, 0.0, 0.0, periodGeoTarget, earth);
    missionPresets.add(testGeoTransfer);

    // 测试任务3：月球飞越（占位）
    if (moon != null) {
      MissionPreset testMoonFlyby = new MissionPreset(
        MISSION_TEST_MOON_FLYBY,
        "TEST: Moon Flyby (Placeholder)",
        "Test mission: Flyby the Moon (placeholder for future implementation)."
      );
      testMoonFlyby.requiredSpacecraftPreset = PRESET_LEO_SATELLITE;
      testMoonFlyby.initialBody = earth;
      double aMoonInit = EARTH_RADIUS_KM + 400;
      double periodMoonInit = 2 * PI * Math.sqrt(aMoonInit * aMoonInit * aMoonInit / GM_EARTH);
      testMoonFlyby.initialOrbit = new Orbit(aMoonInit, 0.001, 0.0, 0.0, 0.0, periodMoonInit, earth);
      testMoonFlyby.goal.type = MissionGoalType.TRANSFER_TO_BODY;
      testMoonFlyby.goal.targetBody = moon;
      missionPresets.add(testMoonFlyby);
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
