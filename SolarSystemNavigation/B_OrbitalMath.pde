// ============================================================
//  Kepler Equation Solver
// ============================================================
double solveKepler(double M, double e) {
  double E = M;
  for (int i = 0; i < 50; i++) {
    double dE = (E - e * Math.sin(E) - M) / (1.0 - e * Math.cos(E));
    E -= dE;
    if (Math.abs(dE) < 1e-12) break;
  }
  return E;
}

double trueAnomaly(double E, double e) {
  return 2.0 * Math.atan2(Math.sqrt(1.0 + e) * Math.sin(E / 2.0), Math.sqrt(1.0 - e) * Math.cos(E / 2.0));
}

// ============================================================
//  Coordinate Transformation
// ============================================================
double[] orbitalToCartesian(double a, double e, double i_deg,
    double omega_deg, double w_deg, double nu) {
  double r = a * (1.0 - e * e) / (1.0 + e * Math.cos(nu));
  double xOrb = r * Math.cos(nu);
  double yOrb = r * Math.sin(nu);

  double i     = Math.toRadians(i_deg);
  double omega = Math.toRadians(omega_deg);
  double w     = Math.toRadians(w_deg);

  double cosO = Math.cos(omega), sinO = Math.sin(omega);
  double cosW = Math.cos(w),     sinW = Math.sin(w);
  double cosI = Math.cos(i),     sinI = Math.sin(i);

  double x = (cosO * cosW - sinO * sinW * cosI) * xOrb +
             (-cosO * sinW - sinO * cosW * cosI) * yOrb;
  double y = (sinO * cosW + cosO * sinW * cosI) * xOrb +
             (-sinO * sinW + cosO * cosW * cosI) * yOrb;
  double z = (sinW * sinI) * xOrb + (cosW * sinI) * yOrb;

  double[] result = new double[3];
  result[0] = x; result[1] = y; result[2] = z;
  return result;
}

// ============================================================
//  Orbital Velocity: perifocal → Cartesian (same rotation as orbitalToCartesian)
// ============================================================
double[] orbitalVelocityToCartesian(double a, double e, double i_deg,
    double omega_deg, double w_deg, double nu, double GM) {
  double p = a * (1.0 - e * e);
  double factor = Math.sqrt(GM / p);
  double vx_pf = -factor * Math.sin(nu);
  double vy_pf = factor * (e + Math.cos(nu));

  double i     = Math.toRadians(i_deg);
  double omega = Math.toRadians(omega_deg);
  double w     = Math.toRadians(w_deg);

  double cosO = Math.cos(omega), sinO = Math.sin(omega);
  double cosW = Math.cos(w),     sinW = Math.sin(w);
  double cosI = Math.cos(i),     sinI = Math.sin(i);

  double vx = (cosO * cosW - sinO * sinW * cosI) * vx_pf +
              (-cosO * sinW - sinO * cosW * cosI) * vy_pf;
  double vy = (sinO * cosW + cosO * sinW * cosI) * vx_pf +
              (-sinO * sinW + cosO * cosW * cosI) * vy_pf;
  double vz = (sinW * sinI) * vx_pf + (cosW * sinI) * vy_pf;

  double[] result = new double[3];
  result[0] = vx; result[1] = vy; result[2] = vz;
  return result;
}

// ============================================================
//  Cartesian state vector → Kepler elements (2D, i=0, omega=0)
// ============================================================
double[] cartesianToKepler(double[] r, double[] v, double GM) {
  double rx = r[0], ry = r[1];
  double vx = v[0], vy = v[1];

  double rMag = Math.sqrt(rx * rx + ry * ry);
  double vMag2 = vx * vx + vy * vy;

  double a = 1.0 / (2.0 / rMag - vMag2 / GM);

  double hz = rx * vy - ry * vx;
  double p = (hz * hz) / GM;

  double e = Math.sqrt(Math.max(0.0, 1.0 - p / a));
  double ex = (vy * hz) / GM - rx / rMag;
  double ey = (-vx * hz) / GM - ry / rMag;

  double w = Math.atan2(ey, ex);
  double nu = Math.atan2(ry, rx) - w;
  nu = ((nu % (2.0 * PI)) + 2.0 * PI) % (2.0 * PI);

  double[] result = new double[6];
  result[0] = a;
  result[1] = e;
  result[2] = 0.0;       // i = 0 (planar)
  result[3] = 0.0;       // omega = 0
  result[4] = Math.toDegrees(w);
  result[5] = Math.toDegrees(nu);
  return result;
}
