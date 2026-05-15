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

  void startLaunch() {
    if (state != ShipState.IDLE || currentShip == null) return;

    CelestialBody earth = getEarth();

    // Launch pad on day side (toward Sun)
    double launchAngle = Math.atan2(-earth.py, -earth.px);

    currentShip.launchPadAngle = launchAngle;
    currentShip.launchAltitude = 0.0;
    currentShip.earthOrbitAngle = launchAngle;
    currentShip.orbitStartTime = 0;
    currentShip.earthRelPos = new double[]{
      MissionPlanner.EARTH_RADIUS_KM * Math.cos(launchAngle),
      MissionPlanner.EARTH_RADIUS_KM * Math.sin(launchAngle),
      0};
    currentShip.earthRelVel = new double[]{0, 0, 0};
    currentShip.px = earth.px + currentShip.earthRelPos[0];
    currentShip.py = earth.py + currentShip.earthRelPos[1];

    currentShip.state = ShipState.COUNTDOWN;
    currentShip.countdownStartTime = timeManager.simTime;
    currentShip.thrustActive = false;

    state = ShipState.COUNTDOWN;
    launchStartTime = timeManager.simTime;

    camera.focusOn(currentShip);
    camera.followShip(currentShip);
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
      case COUNTDOWN:
        {
          double elapsed = timeManager.simTime - currentShip.countdownStartTime;
          if (elapsed >= Spacecraft.COUNTDOWN_DURATION) {
            currentShip.state = ShipState.IGNITION;
            currentShip.ignitionStartTime = timeManager.simTime;
            currentShip.thrustActive = true;
            state = ShipState.IGNITION;
          }
        }
        break;
      case IGNITION:
        {
          double elapsed = timeManager.simTime - currentShip.ignitionStartTime;
          if (elapsed >= Spacecraft.IGNITION_DURATION) {
            currentShip.state = ShipState.LAUNCHING;
            currentShip.launchStartTime = timeManager.simTime;
            currentShip.lastUpdateTime = timeManager.simTime;
            state = ShipState.LAUNCHING;
          }
        }
        break;
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
    return state == ShipState.IDLE && currentShip != null;
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
      case COUNTDOWN: return "Countdown...";
      case IGNITION: return "Ignition!";
      case LAUNCHING: return "Launching...";
      case CIRCULARIZING: return "Circularizing Orbit...";
      case ORBIT: return "In Orbit - Select Target";
      case TRANSFER: return "Transfer in Progress";
    }
    return "";
  }
}
