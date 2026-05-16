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
    double n, M, nu_rad;

    if (ship.e < 1.0) {
      // 椭圆轨道
      n = 2.0 * PI / ship.period;
      M = (ship.M0 + n * t) % (2.0 * PI);
      if (M < 0) M += 2.0 * PI;
      double E = solveKepler(M, ship.e);
      nu_rad = trueAnomaly(E, ship.e);
    } else {
      // 双曲线轨道
      double a_km = ship.a;
      if (a_km >= 0) {
        // 如果 a 不是负数，用之前计算的 period 反推 n
        n = 2.0 * PI / ship.period;
      } else {
        n = 2.0 * PI / Math.sqrt(Math.pow(-a_km, 3) / GM_SUN);
      }

      M = ship.M0 + n * t;

      // 解双曲线开普勒方程：M = e*sinh(F) - F，用牛顿迭代法
      double F = M;
      for (int i = 0; i < 100; i++) {
        double f = ship.e * Math.sinh(F) - F - M;
        double df = ship.e * Math.cosh(F) - 1.0;
        if (Math.abs(df) < 1e-15) break;
        double dF = f / df;
        F -= dF;
        if (Math.abs(dF) < 1e-15) break;
      }

      // 从双曲偏近点角 F 计算真近点角 nu
      double coshF = Math.cosh(F);
      double cos_nu = (coshF - ship.e) / (1.0 - ship.e * coshF);
      double sin_nu = (Math.sqrt(ship.e * ship.e - 1.0) * Math.sinh(F)) / (1.0 - ship.e * coshF);
      nu_rad = Math.atan2(sin_nu, cos_nu);
    }

    ship.currentNu = nu_rad;
    double[] pos = orbitalToCartesian(ship.a, ship.e, ship.i, ship.omega, ship.w, nu_rad);
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
