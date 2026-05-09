enum ShipState {
  IDLE,
  LAUNCHING,
  ORBIT,
  TRANSFER
}

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

    double leoRadius = planner.getLEORadius() * 1000;
    Spacecraft ship = new Spacecraft(name, leoRadius, 0.0, 0.0, 0.0, 0.0, 0.0,
      2 * PI * Math.sqrt(Math.pow(leoRadius, 3) / GM_SUN), color(0, 255, 150));
    ship.state = ShipState.LAUNCHING;
    ship.launchStartTime = launchStartTime;
    currentShip = ship;
    solarSystem.ships.add(ship);

    camera.followShip(ship);
    camera.setViewMode(ViewMode.MAP_VIEW);
    timeManager.timeWarp = timeManager.WARP_LEVELS[0];
  }

  void selectTarget(CelestialBody target) {
    if (state != ShipState.ORBIT) return;
    selectedTarget = target;
  }

  void initiateTransfer() {
    if (state != ShipState.ORBIT || selectedTarget == null) return;
    if (currentShip == null) return;

    double r1 = currentShip.a;
    double r2 = selectedTarget.a;
    transferOrbitParams = planner.calculateHohmannTransfer(r1 / 1000.0, r2 / 1000.0);

    currentShip.a = transferOrbitParams[0] * 1000.0;
    currentShip.e = transferOrbitParams[1];
    currentShip.w = selectedTarget.w;
    currentShip.period = 2 * PI * Math.sqrt(Math.pow(currentShip.a, 3) / GM_SUN);

    state = ShipState.TRANSFER;
    transferStartTime = timeManager.simTime;
    currentShip.state = ShipState.TRANSFER;
  }

  void update() {
    if (currentShip == null) return;

    switch (state) {
      case LAUNCHING:
        if (timeManager.simTime - launchStartTime > 5 * 86400) {
          state = ShipState.ORBIT;
          currentShip.state = ShipState.ORBIT;
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
      case ORBIT: return "In Orbit - Select Target";
      case TRANSFER: return "Transfer in Progress";
    }
    return "";
  }
}
