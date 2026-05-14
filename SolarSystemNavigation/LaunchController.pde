class LaunchController {
  ShipState state;
  Spacecraft currentShip;
  CelestialBody selectedTarget;
  double launchStartTime;
  double transferStartTime;
  double[] transferOrbitParams;
  MissionPlanner planner;

  LaunchController() {
    state = ShipState.IDLE;
    currentShip = null;
    selectedTarget = null;
    planner = new MissionPlanner();
  }

  void startLaunch(String name) {
    if (state != ShipState.IDLE) return;
    state = ShipState.LAUNCHING;
    launchStartTime = timeManager.simTime;

    CelestialBody earth = getEarth();

    // Launch pad on day side (toward Sun)
    double launchAngle = Math.atan2(-earth.py, -earth.px);

    // Create spacecraft at Earth's surface
    Spacecraft ship = new Spacecraft(name, 0, 0, 0, 0, 0, 0, 0, color(0, 255, 150));
    ship.earthRelative = true;
    ship.earthRef = earth;
    ship.launchPadAngle = launchAngle;
    ship.launchAltitude = 0.0;
    ship.earthOrbitAngle = launchAngle;
    ship.orbitStartTime = 0;
    // Initialize position at Earth's surface on the launch pad
    ship.earthRelPos = new double[]{
      MissionPlanner.EARTH_RADIUS_KM * Math.cos(launchAngle),
      MissionPlanner.EARTH_RADIUS_KM * Math.sin(launchAngle),
      0};
    ship.earthRelVel = new double[]{0, 0, 0};
    ship.lastUpdateTime = launchStartTime;
    ship.thrustActive = true;
    ship.state = ShipState.LAUNCHING;
    ship.launchStartTime = launchStartTime;
    ship.px = earth.px + ship.earthRelPos[0];
    ship.py = earth.py + ship.earthRelPos[1];

    currentShip = ship;
    solarSystem.ships.add(ship);

    camera.focusOn(ship);
    camera.followShip(ship);
    camera.targetScale = 0.4 * height / (2.0 * MissionPlanner.EARTH_RADIUS_KM);
    camera.setViewMode(ViewMode.MAP_VIEW);
    timeManager.timeWarp = timeManager.WARP_LEVELS[0];
  }

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

  void selectTarget(CelestialBody target) {
    if (state != ShipState.ORBIT) return;
    selectedTarget = target;
  }

  void initiateTransfer() {
    if (state != ShipState.ORBIT || selectedTarget == null) return;
    if (currentShip == null || currentShip.earthRef == null) return;

    CelestialBody earth = currentShip.earthRef;

    // Earth's heliocentric velocity at current simTime
    double[] earthVel = orbitalVelocityToCartesian(
      earth.a, earth.e, earth.i, earth.omega, earth.w,
      earth.currentNu, GM_SUN);

    // Spacecraft heliocentric position = Earth pos + Earth-relative pos
    double[] helioPos = new double[3];
    helioPos[0] = earth.px + currentShip.earthRelPos[0];
    helioPos[1] = earth.py + currentShip.earthRelPos[1];
    helioPos[2] = 0;

    // Spacecraft heliocentric velocity = Earth vel + Earth-relative vel
    double[] helioVel = new double[3];
    helioVel[0] = earthVel[0] + currentShip.earthRelVel[0];
    helioVel[1] = earthVel[1] + currentShip.earthRelVel[1];
    helioVel[2] = 0;

    // Convert to Kepler elements
    double[] ke = cartesianToKepler(helioPos, helioVel, GM_SUN);
    double transferA = ke[0];
    double transferE = ke[1];
    double transferI = ke[2];      // 0
    double transferOmega = ke[3];  // 0
    double transferW = ke[4];      // degrees
    double transferNu = ke[5];     // degrees

    // Assign Kepler elements to spacecraft
    currentShip.a = transferA;
    currentShip.e = transferE;
    currentShip.i = transferI;
    currentShip.omega = transferOmega;
    currentShip.w = transferW;
    currentShip.M0 = Math.toRadians(transferNu);  // M0 ≈ nu for circular-ish start
    currentShip.period = 2 * PI * Math.sqrt(Math.pow(transferA, 3) / GM_SUN);

    // Switch to heliocentric mode
    currentShip.earthRelative = false;
    currentShip.earthRef = null;

    // Compute Hohmann transfer to target
    double r1_km = transferA / 1000.0;
    double r2_km = selectedTarget.a / 1000.0;
    transferOrbitParams = planner.calculateHohmannTransfer(r1_km, r2_km);

    currentShip.a = transferOrbitParams[0] * 1000.0;
    currentShip.e = transferOrbitParams[1];
    currentShip.w = selectedTarget.w;
    currentShip.period = 2 * PI * Math.sqrt(Math.pow(currentShip.a, 3) / GM_SUN);

    state = ShipState.TRANSFER;
    transferStartTime = timeManager.simTime;
    currentShip.state = ShipState.TRANSFER;

    // Zoom out to see the transfer orbit
    camera.targetScale = (width * 0.15) / AU_KM;
    camera.followShip(currentShip);
  }

  void update() {
    if (currentShip == null) return;

    // Cap time warp during Earth-relative phases to prevent excessive sub-steps
    if (currentShip.earthRelative) {
      if (timeManager.warpIndex > 3) {
        timeManager.warpIndex = 3;
        timeManager.timeWarp = timeManager.WARP_LEVELS[3];
      }
    }

    switch (state) {
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
      case TRANSFER:
        double transferTime = planner.calculateTransferTime(transferOrbitParams[0], GM_SUN);
        if (timeManager.simTime - transferStartTime > transferTime) {
          insertIntoTargetOrbit();
        }
        break;
    }
  }

  void insertIntoTargetOrbit() {
    if (selectedTarget == null || currentShip == null) return;

    double targetRadius = selectedTarget.a;
    double captureOrbitRadius = targetRadius * 0.95;
    currentShip.a = captureOrbitRadius;
    currentShip.e = 0.0;
    currentShip.i = selectedTarget.i;
    currentShip.omega = selectedTarget.omega;
    currentShip.w = 0.0;
    currentShip.period = 2 * PI * Math.sqrt(Math.pow(captureOrbitRadius, 3) / GM_SUN);

    state = ShipState.ORBIT;
    currentShip.state = ShipState.ORBIT;
    selectedTarget = null;
  }

  boolean canLaunch() {
    return state == ShipState.IDLE;
  }

  boolean canSelectTarget() {
    return state == ShipState.ORBIT;
  }

  boolean canTransfer() {
    return state == ShipState.ORBIT && selectedTarget != null;
  }

  String getStatusText() {
    switch (state) {
      case IDLE: return "Ready to Launch";
      case LAUNCHING: return "Launching...";
      case CIRCULARIZING: return "Circularizing Orbit...";
      case ORBIT: return "In Orbit - Select Target";
      case TRANSFER: return "Transfer in Progress";
    }
    return "";
  }
}
