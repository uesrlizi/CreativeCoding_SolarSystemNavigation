// ========== SPACECRAFT VEHICLE ==========
// Simplified for Stage 2: Single LEO probe

static class Spacecraft {
  String name;
  color col;

  // Orbit parameters
  double a, e, i, omega, w, M0, period;
  double currentNu;

  // Reference body
  CelestialBody currentCentralBody;

  // Position and velocity (relative to central body)
  double[] pos;
  double[] vel;

  // Compatibility aliases
  double[] earthRelPos;
  double[] earthRelVel;
  CelestialBody earthRef;
  boolean earthRelative;

  // Display and rotation
  double displayAngle;
  double angularVelocity;
  double angularAcceleration;

  // World position (cached)
  double px, py, pz;

  // Last update time
  double lastUpdateTime;

  // Constants (for compatibility with renderer)
  static final double SHIP_LENGTH_KM = 0.08;
  static final double MAX_ANGULAR_VELOCITY = 3.0;
  static final double MAX_ANGULAR_ACCEL = 8.0;

  Spacecraft(String name, color col) {
    this.name = name;
    this.col = col;

    // Initialize arrays
    this.pos = new double[3];
    this.vel = new double[3];
    this.earthRelPos = this.pos;
    this.earthRelVel = this.vel;

    // Default values
    this.a = 0;
    this.e = 0;
    this.i = 0;
    this.omega = 0;
    this.w = 0;
    this.M0 = 0;
    this.period = 1;
    this.currentNu = 0;

    this.px = 0;
    this.py = 0;
    this.pz = 0;

    this.displayAngle = 0;
    this.angularVelocity = 0;
    this.angularAcceleration = 0;
    this.lastUpdateTime = 0;
  }

  // Initialize LEO orbit
  void initLEO(CelestialBody earth) {
    this.currentCentralBody = earth;
    this.earthRef = earth;
    this.earthRelative = true;

    // LEO orbit parameters (420 km altitude)
    this.a = LEO_RADIUS_KM;
    this.e = 0.001;  // Near-circular
    this.i = 0.0;
    this.omega = 0.0;
    this.w = 0.0;
    this.M0 = 0.0;

    // Calculate orbital period
    this.period = 2 * PI * Math.sqrt(this.a * this.a * this.a / GM_EARTH);

    // Initial position
    updateOrbit(0);
  }

  // Update position from orbit
  void updateOrbit(double simTime) {
    if (this.a > 0 && this.currentCentralBody != null) {
      // Calculate true anomaly
      double n = 2.0 * PI / this.period;
      double M = (this.M0 + n * simTime) % (2.0 * PI);
      double E = solveKepler(M, this.e);
      double nu = trueAnomaly(E, this.e);
      this.currentNu = nu;

      // Calculate relative position
      double[] relPos = orbitalToCartesian(this.a, this.e, this.i, this.omega, this.w, nu);
      this.pos[0] = relPos[0];
      this.pos[1] = relPos[1];
      this.pos[2] = relPos[2];

      // Calculate relative velocity
      double[] relVel = orbitalVelocityToCartesian(this.a, this.e, this.i, this.omega, this.w, nu, GM_EARTH);
      this.vel[0] = relVel[0];
      this.vel[1] = relVel[1];
      this.vel[2] = relVel[2];

      // Calculate world position
      this.px = this.currentCentralBody.px + this.pos[0];
      this.py = this.currentCentralBody.py + this.pos[1];
      this.pz = this.currentCentralBody.pz + this.pos[2];

      // Update display angle to point along velocity vector
      this.displayAngle = Math.atan2(this.vel[1], this.vel[0]);
    }
  }

  // Update display angle (smooth)
  void updateDisplayAngleSmooth(double simTime, double dt) {
    // For now, just point along velocity
    if (this.currentCentralBody != null) {
      this.displayAngle = Math.atan2(this.vel[1], this.vel[0]);
    }
  }
}
