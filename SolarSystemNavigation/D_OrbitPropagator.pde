// ============================================================
//  OrbitPropagator — Keplerian orbital element propagation
//  and osculating orbit calculation.
//  This replaces the old `updateHeliocentric` and analytic circular logic.
// ============================================================

class OrbitPropagator {
  // ==============================================================
  //  Propagate a heliocentric orbit with Keplerian elements to time t
  //  Updates position (km) in sun-relative coordinates on the ship
  // ==============================================================

  void propagateHeliocentric(Spacecraft ship, double t) {
    double n = 2.0 * PI / ship.period;
    double M = (ship.M0 + n * t) % (2.0 * PI);
    if (M < 0) M += 2.0 * PI;
    double E = solveKepler(M, ship.e);
    ship.currentNu = trueAnomaly(E, ship.e);
    double[] pos = orbitalToCartesian(ship.a, ship.e, ship.i, ship.omega, ship.w, ship.currentNu);
    ship.px = pos[0];
    ship.py = pos[1];
    ship.pz = pos[2];
  }

  // ==============================================================
  //  Propagate a stable circular orbit around a planet (analytic)
  //  Updates outPos and outVel in-place
  // ==============================================================

  void propagateCircularOrbit(
      double[] outPos, double[] outVel,
      CelestialBody body, double orbitAngle,
      double radius, double GM) {
    double angVel = Math.sqrt(GM / (radius * radius * radius));
    outPos[0] = radius * Math.cos(orbitAngle);
    outPos[1] = radius * Math.sin(orbitAngle);
    outPos[2] = 0;
    outVel[0] = -radius * angVel * Math.sin(orbitAngle);
    outVel[1] =  radius * angVel * Math.cos(orbitAngle);
    outVel[2] = 0;
  }

  // ==============================================================
  //  Get osculating orbital elements from Cartesian state vector
  //  Returns [a (km), e, i, omega (rad), w (rad), nu (rad)]
  // ==============================================================

  double[] osculatingElements(double[] pos, double[] vel, double GM) {
    double rx = pos[0], ry = pos[1];
    double vx = vel[0], vy = vel[1];
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double energy = v2 / 2.0 - GM / r;

    if (energy >= 0) {
      // Hyperbolic or escape — return sentinel values
      return new double[]{Double.MAX_VALUE, Double.MAX_VALUE, 0, 0, 0, 0};
    }

    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx; // angular momentum
    double e2 = 1.0 - h * h / (GM * a);
    double e = Math.sqrt(Math.max(0.0, e2));

    // Simplified planar case: i=0, omega=0, w computed from position
    double i = 0;
    double omega = 0;

    // Compute argument of periapsis w and true anomaly nu
    double vRad = (rx * vx + ry * vy) / r;
    double cosNu = (a * (1.0 - e * e) / r - 1.0) / e;
    cosNu = Math.max(-1.0, Math.min(1.0, cosNu));
    double nu = Math.acos(cosNu);
    if (vRad < 0) nu = 2.0 * PI - nu;

    // Position of periapsis: true anomaly 0 is along +X in orbit plane
    // The current position is at true anomaly nu from periapsis
    double w = Math.atan2(ry, rx) - nu;
    w = normalizeAngleRad(w);

    return new double[]{a, e, i, omega, w, nu};
  }

  // ==============================================================
  //  Helper: normalize angle to [0, 2pi)
  // ==============================================================

  double normalizeAngleRad(double a) {
    a = a % (2.0 * PI);
    if (a < 0) a += 2.0 * PI;
    return a;
  }

  // ==============================================================
  //  Helper: get position at a specific true anomaly
  // ==============================================================

  double[] positionAtTrueAnomaly(double a, double e, double w, double nu) {
    double r = a * (1.0 - e * e) / (1.0 + e * Math.cos(nu));
    double theta = w + nu;
    return new double[]{
      r * Math.cos(theta),
      r * Math.sin(theta),
      0
    };
  }
}
