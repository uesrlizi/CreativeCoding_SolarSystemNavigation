class LaunchController {
  ShipPhase phase;
  Spacecraft currentShip;
  CelestialBody selectedTarget;
  CelestialBody launchBody;
  LaunchSimulator launchSim;
  ManeuverPlanner maneuverPlanner;
  PhysicsEngine physics;
  OrbitPredictor orbitPredictor;

  double launchAzimuth;
  double targetOrbitAltitude;
  boolean waitingForLaunch;

  LaunchController() {
    phase = ShipPhase.ON_GROUND;
    currentShip = null;
    selectedTarget = null;
    launchSim = new LaunchSimulator();
    maneuverPlanner = new ManeuverPlanner();
    physics = new PhysicsEngine();
    orbitPredictor = new OrbitPredictor();
    launchAzimuth = 90;
    targetOrbitAltitude = 400;
    waitingForLaunch = false;

    for (CelestialBody p : solarSystem.planets) {
      if (p.name.equals("Earth")) {
        launchBody = p;
        launchSim.setLaunchBody(launchBody);
        break;
      }
    }
  }

  void setLaunchAzimuth(double azimuth) {
    this.launchAzimuth = azimuth;
    launchSim.setLaunchAzimuth(azimuth);
  }

  void setTargetOrbit(double altitudeKm) {
    this.targetOrbitAltitude = altitudeKm;
    launchSim.setTargetOrbit(altitudeKm);
  }

  void startLaunch(String name) {
    if (phase != ShipPhase.ON_GROUND) return;

    currentShip = new Spacecraft(name, color(0, 255, 150));
    launchSim.executeLaunch(currentShip);
    waitingForLaunch = false;
    phase = ShipPhase.POWERED_ASCENT;
    solarSystem.ships.add(currentShip);
  }

  void update() {
    if (currentShip == null) return;

    switch (phase) {
      case ON_GROUND:
        break;
      case POWERED_ASCENT:
        launchSim.updateLaunch(currentShip, 1.0);
        if (currentShip.phase == ShipPhase.IN_ORBIT) {
          phase = ShipPhase.IN_ORBIT;
        }
        break;
      case COASTING:
        updateOrbital(currentShip, 1.0);
        break;
      case IN_ORBIT:
        updateOrbital(currentShip, 1.0);
        break;
      case TRANSFER:
        updateOrbital(currentShip, 1.0);
        break;
      case DECOUPLING:
        updateOrbital(currentShip, 1.0);
        break;
    }

    orbitPredictor.update(currentShip);
  }

  void updateOrbital(Spacecraft ship, double dt) {
    double[] acc = physics.totalGravity(ship.position);
    ship.velocity[0] += acc[0] * dt;
    ship.velocity[1] += acc[1] * dt;
    ship.velocity[2] += acc[2] * dt;
    ship.position[0] += ship.velocity[0] * dt;
    ship.position[1] += ship.velocity[1] * dt;
    ship.position[2] += ship.velocity[2] * dt;
  }

  ShipPhase getState() {
    return phase;
  }

  CelestialBody getSelectedTarget() {
    return selectedTarget;
  }

  Spacecraft getCurrentShip() {
    return currentShip;
  }

  void selectTarget(CelestialBody target) {
    if (phase != ShipPhase.IN_ORBIT) return;
    selectedTarget = target;
  }

  void initiateTransfer() {
    if (phase != ShipPhase.IN_ORBIT || selectedTarget == null) return;

    OrbitalManeuver m = OrbitalManeuver.escape(launchBody);
    maneuverPlanner.addManeuver(m);
    maneuverPlanner.executeNext(currentShip);
    phase = ShipPhase.TRANSFER;
  }

  boolean canLaunch() {
    return phase == ShipPhase.ON_GROUND;
  }

  boolean canManeuver() {
    return phase == ShipPhase.IN_ORBIT && currentShip != null;
  }

  boolean canSelectTarget() {
    return phase == ShipPhase.IN_ORBIT;
  }

  boolean canTransfer() {
    return phase == ShipPhase.IN_ORBIT && selectedTarget != null;
  }

  String getStatusText() {
    if (currentShip == null) return "Ready to Launch";

    switch (phase) {
      case ON_GROUND:
        return "Configure and Launch";
      case POWERED_ASCENT:
        return String.format("Ascent - Alt: %.0f km", currentShip.altitudeAGL(launchBody));
      case IN_ORBIT:
        return String.format("In Orbit - Alt: %.0f km", currentShip.altitudeAGL(launchBody));
      case TRANSFER:
        return "Escape Maneuver";
    }
    return "";
  }

  CelestialBody getLaunchBody() {
    return launchBody;
  }
}
