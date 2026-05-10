class LaunchSimulator {
  PhysicsEngine physics;
  CelestialBody launchBody;
  double targetOrbitAltitude;
  double launchAzimuth;
  double initialPitchRate;
  double maxQAltitude;
  double stageSeparationAltitude;

  LaunchSimulator() {
    physics = new PhysicsEngine();
    launchBody = null;
    launchAzimuth = 90;
    targetOrbitAltitude = 400000;
    initialPitchRate = 5.0;
    maxQAltitude = 12000;
    stageSeparationAltitude = 100000;
  }

  void setLaunchBody(CelestialBody body) {
    this.launchBody = body;
  }

  void setTargetOrbit(double altitudeKm) {
    this.targetOrbitAltitude = altitudeKm * 1000;
  }

  void setLaunchAzimuth(double azimuthDeg) {
    this.launchAzimuth = azimuthDeg;
  }

  void executeLaunch(Spacecraft ship) {
    if (ship.phase != ShipPhase.ON_GROUND || launchBody == null) return;

    ship.phase = ShipPhase.POWERED_ASCENT;
    ship.launchPitch = 90.0;
    ship.launchAzimuthAngle = launchAzimuth;
    ship.throttle = 1.0;

    double surfaceSpeed = launchBody.rotationSpeed * launchBody.radius * 1000;
    double[] east = new double[]{0, surfaceSpeed, 0};
    ship.velocity = east.clone();
    ship.position = new double[]{launchBody.radius * 1000, 0, 0};
  }

  void updateLaunch(Spacecraft ship, double dt) {
    if (ship.phase != ShipPhase.POWERED_ASCENT || launchBody == null) return;

    double altitude = ship.altitudeAGL(launchBody);
    double gravity = launchBody.gm / (ship.position[0] * ship.position[0] + ship.position[1] * ship.position[1]);
    double g0 = 9.81;

    double thrust = ship.getThrustMagnitude();
    double massFlow = thrust / (ship.isp * g0);
    double drag = calculateDrag(altitude, ship.speed());

    double pitchOverRate = initialPitchRate * Math.max(0, 1.0 - altitude / maxQAltitude);
    ship.launchPitch = Math.max(0, Math.min(90, ship.launchPitch - pitchOverRate * dt));

    double azimuthRad = Math.toRadians(ship.launchAzimuthAngle);
    double pitchRad = Math.toRadians(ship.launchPitch);
    double thrustFrac = thrust / ship.mass;

    double thrustEast = thrustFrac * Math.cos(pitchRad) * Math.sin(azimuthRad);
    double thrustNorth = thrustFrac * Math.cos(pitchRad) * Math.cos(azimuthRad);
    double thrustUp = thrustFrac * Math.sin(pitchRad);

    ship.velocity[0] += (thrustEast + gravity * ship.position[0] / Math.sqrt(ship.position[0]*ship.position[0] + ship.position[1]*ship.position[1])) * dt;
    ship.velocity[1] += (thrustNorth + gravity * ship.position[1] / Math.sqrt(ship.position[0]*ship.position[0] + ship.position[1]*ship.position[1])) * dt;
    ship.velocity[2] += thrustUp * dt;

    ship.position[0] += ship.velocity[0] * dt;
    ship.position[1] += ship.velocity[1] * dt;
    ship.position[2] += ship.velocity[2] * dt;

    ship.mass -= massFlow * dt;
    ship.consumeFuel(massFlow * dt);

    if (altitude >= targetOrbitAltitude) {
      double targetOrbitalSpeed = physics.orbitalSpeed(launchBody.radius * 1000 + targetOrbitAltitude, launchBody.gm);
      double currentSpeed = ship.speed();

      double[] prograde = normalize(crossProduct(ship.position, new double[]{0, 0, 1}));
      double[] dvNeeded = new double[]{
        prograde[0] * (targetOrbitalSpeed - currentSpeed * Math.abs(ship.velocity[0]) / currentSpeed),
        prograde[1] * (targetOrbitalSpeed - currentSpeed * Math.abs(ship.velocity[1]) / currentSpeed),
        0
      };

      double dvMagnitude = Math.sqrt(dvNeeded[0]*dvNeeded[0] + dvNeeded[1]*dvNeeded[1]);
      if (dvMagnitude > 10) {
        dvNeeded[0] = dvNeeded[0] / dvMagnitude * Math.min(dvMagnitude, 200);
        dvNeeded[1] = dvNeeded[1] / dvMagnitude * Math.min(dvMagnitude, 200);
        ship.applyDeltaV(dvNeeded);
      }

      ship.phase = ShipPhase.IN_ORBIT;
    }
  }

  double calculateDrag(double altitude, double velocity) {
    if (altitude <= 0) return 0;
    double rho = 1.225 * Math.exp(-altitude / 8500.0);
    double Cd = 0.5;
    double A = 10.0;
    return 0.5 * rho * velocity * velocity * Cd * A;
  }

  double[] normalize(double[] v) {
    double mag = Math.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    if (mag < 1e-10) return new double[]{0, 0, 0};
    return new double[]{v[0]/mag, v[1]/mag, v[2]/mag};
  }

  double[] crossProduct(double[] a, double[] b) {
    return new double[]{
      a[1]*b[2] - a[2]*b[1],
      a[2]*b[0] - a[0]*b[2],
      a[0]*b[1] - a[1]*b[0]
    };
  }

  double getRequiredDeltaV() {
    double r = launchBody.radius * 1000;
    double v1 = physics.orbitalSpeed(r, launchBody.gm);
    double v2 = physics.orbitalSpeed(r + targetOrbitAltitude, launchBody.gm);
    return (v2 - v1) * 1.1;
  }
}
