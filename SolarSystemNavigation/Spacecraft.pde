// ============================================================
//  Spacecraft — refactored to be a state container + scheduler
//  Physics, guidance, and orbit propagation delegated to new classes
// ============================================================

class Spacecraft {
  // Basic identity
  String name;
  color col;
  color trailColor;

  // Orbital elements (for heliocentric Keplerian propagation)
  double a, e, i, omega, w, M0, period;
  double px, py, pz;
  double currentNu;

  // Reference frame
  ReferenceFrame frame;

  // Earth-relative tracking (preserved for backward compatibility)
  boolean earthRelative;
  CelestialBody earthRef;
  double launchPadAngle;
  double launchAltitude;
  double earthOrbitAngle;
  double orbitStartTime;
  double[] earthRelPos;
  double[] earthRelVel;

  // Mission state
  ShipState state;
  double launchStartTime;
  double transferStartTime;
  double countdownStartTime;
  double ignitionStartTime;

  // Thrust/burn tracking
  boolean thrustActive;
  double circBurnDuration;
  double tmiTargetDV = 0;
  double tmiAccumulatedDV = 0;
  double toiTargetDV = 0;
  double toiAccumulatedDV = 0;

  // Last physics update time
  double lastUpdateTime;

  // Display-only angular dynamics (cosmetic only)
  double displayAngle;
  double angularVelocity;
  double angularAcceleration;
  static final double MAX_ANGULAR_VELOCITY = 3.0;
  static final double MAX_ANGULAR_ACCEL = 8.0;
  static final double ANGLE_KP = 10.0;
  static final double ANGLE_KD = 6.0;
  static final double COUNTDOWN_DURATION = 10.0;
  static final double IGNITION_DURATION = 2.0;
  static final double SHIP_LENGTH_KM = 0.08;
  static final double SHIP_WIDTH_KM = 0.006;

  // External systems (instance fields)
  OrbitPropagator orbitPropagator;
  FlightComputer flightComputer;
  PhysicsEngine physicsEngine;
  AtmosphereModel atmosphereModel;

  // ==============================================================
  //  Constructor
  // ==============================================================

  Spacecraft(double a, double e, double i,
      double omega, double w, double M0, double period, color col) {
    this.name = "Spacecraft";
    this.a = a; this.e = e; this.i = i;
    this.omega = omega; this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = period;
    this.col = col;
    this.trailColor = col;

    // Initialize external systems
    this.orbitPropagator = new OrbitPropagator();
    this.flightComputer = new FlightComputer();
    this.physicsEngine = new PhysicsEngine();
    this.atmosphereModel = new AtmosphereModel();

    this.state = ShipState.IDLE;
    this.launchStartTime = 0;
    this.transferStartTime = 0;
    this.countdownStartTime = 0;
    this.ignitionStartTime = 0;

    this.earthRelative = false;
    this.earthRef = null;
    this.launchPadAngle = 0;
    this.launchAltitude = 0;
    this.earthOrbitAngle = 0;
    this.orbitStartTime = 0;
    this.earthRelPos = new double[]{0, 0, 0};
    this.earthRelVel = new double[]{0, 0, 0};

    this.displayAngle = 0;
    this.angularVelocity = 0;
    this.angularAcceleration = 0;
  }

  // ==============================================================
  //  Main update dispatcher — heart of the new architecture
  //  Decides whether to use PhysicsEngine or OrbitPropagator
  // ==============================================================

  void update(double t) {
    double simDt = t - lastUpdateTime;
    if (simDt <= 0) simDt = 1.0 / 60.0;
    if (simDt > 3600) simDt = 3600; // max 1 hour to prevent skipping too much
    lastUpdateTime = t;

    if (earthRelative && earthRef != null) {
      updateBodyRelative(t, simDt);
    } else {
      updateHeliocentric(t, simDt);
    }

    // Update display angle (cosmetic, always happens)
    updateDisplayAngle(computeTargetWorldAngle(), simDt);
  }

  // ==============================================================
  //  Body-relative mode (Earth orbit)
  // ==============================================================

  void updateBodyRelative(double t, double simDt) {
    boolean inAtmosphere = (frame != null && earthRef != null) ?
        atmosphereModel.inAtmosphere(earthRef, atmosphereModel.altitudeAboveSurface(earthRelPos, earthRef)) : false;
    boolean needsPhysics = thrustActive || inAtmosphere ||
        state == ShipState.LAUNCHING || state == ShipState.CIRCULARIZING ||
        state == ShipState.TMI_BURN;

    if (needsPhysics) {
      // Use PhysicsEngine
      physicsEngine.reset();
      SpacecraftForceModel forceModel = new SpacecraftForceModel(this);
      physicsEngine.integrate(earthRelPos, earthRelVel, simDt, forceModel);
      updateDerivedValues();
    } else {
      // Use OrbitPropagator — analytic circular orbit
      double orbitElapsed = t - orbitStartTime;
      double angVel = Math.sqrt(MissionPlanner.GM_EARTH /
        Math.pow(MissionPlanner.LEO_RADIUS_KM, 3));
      earthOrbitAngle = launchPadAngle + angVel * orbitElapsed;
      orbitPropagator.propagateCircularOrbit(
        earthRelPos, earthRelVel,
        earthRef, earthOrbitAngle,
        MissionPlanner.LEO_RADIUS_KM,
        MissionPlanner.GM_EARTH);
      launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;
    }

    // Update world position
    px = earthRef.px + earthRelPos[0];
    py = earthRef.py + earthRelPos[1];
    pz = 0;
  }

  // ==============================================================
  //  Heliocentric mode (interplanetary transfer)
  // ==============================================================

  void updateHeliocentric(double t, double simDt) {
    boolean needsPhysics = thrustActive || state == ShipState.APPROACHING_TARGET || state == ShipState.TOI_BURN;

    if (needsPhysics && earthRelative == false) {
      // TODO: full heliocentric physics not needed yet
      orbitPropagator.propagateHeliocentric(this, t);
    } else {
      orbitPropagator.propagateHeliocentric(this, t);
    }
  }

  // ==============================================================
  //  Helper: update derived values after physics
  // ==============================================================

  void updateDerivedValues() {
    if (earthRelPos != null) {
      double rx = earthRelPos[0], ry = earthRelPos[1];
      double r = Math.sqrt(rx * rx + ry * ry);
      launchAltitude = r - MissionPlanner.EARTH_RADIUS_KM;
      earthOrbitAngle = Math.atan2(ry, rx);
    }
  }

  // ==============================================================
  //  Finalize orbit insertion — clean transition to stable orbit
  // ==============================================================

  void finalizeOrbitInsertion() {
    double rx = earthRelPos[0], ry = earthRelPos[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double radX = rx / r, radY = ry / r;
    double tanX = -ry / r, tanY = rx / r;

    double circSpeed = Math.sqrt(MissionPlanner.GM_EARTH / MissionPlanner.LEO_RADIUS_KM);
    earthRelVel[0] = tanX * circSpeed;
    earthRelVel[1] = tanY * circSpeed;
    earthRelVel[2] = 0;

    earthRelPos[0] = MissionPlanner.LEO_RADIUS_KM * radX;
    earthRelPos[1] = MissionPlanner.LEO_RADIUS_KM * radY;
    earthRelPos[2] = 0;

    launchAltitude = MissionPlanner.LEO_ALTITUDE_KM;
    launchPadAngle = Math.atan2(earthRelPos[1], earthRelPos[0]);
    earthOrbitAngle = launchPadAngle;
    orbitStartTime = lastUpdateTime;
    thrustActive = false;
    state = ShipState.ORBIT;
  }

  // ==============================================================
  //  Target display angle — copied verbatim from old code
  // ==============================================================

  double computeTargetWorldAngle() {
    if (earthRelative && earthRef != null) {
      if (state == ShipState.IDLE ||
          state == ShipState.COUNTDOWN ||
          state == ShipState.IGNITION) {
        return earthOrbitAngle;
      } else if (state == ShipState.LAUNCHING && thrustActive) {
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double burnTime = (timeManager != null ? timeManager.simTime : 0) - launchStartTime;
        return flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
      } else if (state == ShipState.CIRCULARIZING && thrustActive) {
        double rx = earthRelPos[0], ry = earthRelPos[1];
        double vx = earthRelVel[0], vy = earthRelVel[1];
        double[] peg = flightComputer.pegGuidance(rx, ry, vx, vy, MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);
        return peg[1];
      } else {
        return earthOrbitAngle + PI / 2.0;
      }
    } else {
      double nuForward = currentNu + 0.01;
      double[] posForward = orbitalToCartesian(a, e, i, omega, w, nuForward);
      double vx = posForward[0] - px;
      double vy = posForward[1] - py;
      return Math.atan2(vy, vx);
    }
  }

  // ==============================================================
  //  Display angle update — copied verbatim from old code
  // ==============================================================

  void updateDisplayAngle(double targetAngle, double dt) {
    if (dt <= 0 || dt > 0.5) return;
    double error = angleDifference(targetAngle, displayAngle);
    double desiredAccel = error * ANGLE_KP - angularVelocity * ANGLE_KD;
    angularAcceleration = clamp(desiredAccel, -MAX_ANGULAR_ACCEL, MAX_ANGULAR_ACCEL);
    angularVelocity += angularAcceleration * dt;
    angularVelocity = clamp(angularVelocity, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY);
    displayAngle += angularVelocity * dt;
    displayAngle = normalizeAngle(displayAngle);
  }

  // ==============================================================
  //  Math helpers — preserved from old code
  // ==============================================================

  double clamp(double v, double min, double max) {
    return Math.max(min, Math.min(max, v));
  }

  double normalizeAngle(double a) {
    return ((a % (2.0 * PI)) + 2.0 * PI) % (2.0 * PI);
  }

  double angleDifference(double target, double current) {
    return ((target - current + 3.0 * PI) % (2.0 * PI)) - PI;
  }

  // ==============================================================
  //  Backward compatibility: old method signatures preserved
  // ==============================================================

  double[] getOsculatingOrbitalParams() {
    return flightComputer.osculatingParams(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.GM_EARTH);
  }

  double computeApoapsis() {
    return flightComputer.apoapsisAltitude(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.EARTH_RADIUS_KM,
      MissionPlanner.GM_EARTH);
  }

  double computePerigee() {
    return flightComputer.perigeeAltitude(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.EARTH_RADIUS_KM,
      MissionPlanner.GM_EARTH);
  }

  double timeToApoapsis() {
    return flightComputer.timeToApoapsis(
      earthRelPos[0], earthRelPos[1],
      earthRelVel[0], earthRelVel[1],
      MissionPlanner.GM_EARTH);
  }
}

// ==============================================================
//  SpacecraftForceModel — concrete ForceModel implementation
//  Computes gravity + thrust + drag
// ==============================================================

class SpacecraftForceModel extends ForceModel {
  Spacecraft ship;
  double[] tempDrag = new double[2];

  SpacecraftForceModel(Spacecraft ship) {
    this.ship = ship;
  }

  void computeForce(double[] pos, double[] vel, double[] accelOut) {
    computeForce(pos, vel, accelOut, ship.thrustActive);
  }

  void computeForce(double[] pos, double[] vel, double[] accelOut, boolean useThrust) {
    double rx = pos[0], ry = pos[1];
    double r = Math.sqrt(rx * rx + ry * ry);

    double GM = MissionPlanner.GM_EARTH;
    if (ship.frame != null) GM = ship.frame.gm();

    // Gravity
    double gMag = GM / (r * r);
    double gravX = -gMag * rx / r;
    double gravY = -gMag * ry / r;

    accelOut[0] = gravX;
    accelOut[1] = gravY;

    // Thrust
    if (useThrust) {
      double[] thrustDir = getThrustDirection(pos, vel);
      accelOut[0] += FlightComputer.THRUST_ACCEL * thrustDir[0];
      accelOut[1] += FlightComputer.THRUST_ACCEL * thrustDir[1];
    }

    // Drag
    if (ship.frame != null && ship.earthRef != null) {
      ship.atmosphereModel.dragAcceleration(pos, vel, ship.earthRef, tempDrag);
      accelOut[0] += tempDrag[0];
      accelOut[1] += tempDrag[1];
    }
  }

  double[] getThrustDirection(double[] pos, double[] vel) {
    double rx = pos[0], ry = pos[1];
    double vx = vel[0], vy = vel[1];

    if (ship.state == ShipState.LAUNCHING) {
      double burnTime = (timeManager != null ? timeManager.simTime : 0) - ship.launchStartTime;
      double angle = ship.flightComputer.ascentThrustDirection(rx, ry, burnTime, MissionPlanner.LEO_ALTITUDE_KM);
      return new double[]{Math.cos(angle), Math.sin(angle)};
    } else if (ship.state == ShipState.CIRCULARIZING) {
      double[] peg = ship.flightComputer.pegGuidance(rx, ry, vx, vy, MissionPlanner.LEO_RADIUS_KM, MissionPlanner.GM_EARTH);
      return new double[]{Math.cos(peg[1]), Math.sin(peg[1])};
    } else if (ship.state == ShipState.TMI_BURN) {
      return ship.flightComputer.tangentialThrustDirection(rx, ry, true);
    } else if (ship.state == ShipState.TOI_BURN) {
      return ship.flightComputer.tangentialThrustDirection(vel, true);
    }
    // Default: thrust in velocity direction
    double v = Math.sqrt(vx * vx + vy * vy);
    if (v < 0.001) return new double[]{1, 0};
    return new double[]{vx / v, vy / v};
  }

  double bodyRadius() {
    if (ship.frame != null) return ship.frame.bodyRadius();
    if (ship.earthRef != null) return ship.earthRef.radius;
    return MissionPlanner.EARTH_RADIUS_KM;
  }

  boolean thrustActive() {
    return ship.thrustActive;
  }
}
