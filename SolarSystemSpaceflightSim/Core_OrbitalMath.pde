// ========== ORBITAL MATH ==========

static double solveKepler(double M, double e) {
  double E = M;
  for (int i = 0; i < 50; i++) {
    double dE = (E - e * Math.sin(E) - M) / (1.0 - e * Math.cos(E));
    E -= dE;
    if (Math.abs(dE) < 1e-12) break;
  }
  return E;
}

static double trueAnomaly(double E, double e) {
  return 2.0 * Math.atan2(Math.sqrt(1.0 + e) * Math.sin(E / 2.0), Math.sqrt(1.0 - e) * Math.cos(E / 2.0));
}

static double[] orbitalToCartesian(double a, double e, double i_deg, double omega_deg, double w_deg, double nu) {
  double r = a * (1.0 - e * e) / (1.0 + e * Math.cos(nu));
  double xOrb = r * Math.cos(nu);
  double yOrb = r * Math.sin(nu);

  double i = Math.toRadians(i_deg);
  double omega = Math.toRadians(omega_deg);
  double w = Math.toRadians(w_deg);

  double cosO = Math.cos(omega), sinO = Math.sin(omega);
  double cosW = Math.cos(w), sinW = Math.sin(w);
  double cosI = Math.cos(i), sinI = Math.sin(i);

  double x = (cosO * cosW - sinO * sinW * cosI) * xOrb + (-cosO * sinW - sinO * cosW * cosI) * yOrb;
  double y = (sinO * cosW + cosO * sinW * cosI) * xOrb + (-sinO * sinW + cosO * cosW * cosI) * yOrb;
  double z = (sinW * sinI) * xOrb + (cosW * sinI) * yOrb;

  double[] result = new double[3];
  result[0] = x; result[1] = y; result[2] = z;
  return result;
}

static double[] orbitalVelocityToCartesian(double a, double e, double i_deg, double omega_deg, double w_deg, double nu, double GM) {
  double p = a * (1.0 - e * e);
  double factor = Math.sqrt(GM / p);
  double vx_pf = -factor * Math.sin(nu);
  double vy_pf = factor * (e + Math.cos(nu));

  double i = Math.toRadians(i_deg);
  double omega = Math.toRadians(omega_deg);
  double w = Math.toRadians(w_deg);

  double cosO = Math.cos(omega), sinO = Math.sin(omega);
  double cosW = Math.cos(w), sinW = Math.sin(w);
  double cosI = Math.cos(i), sinI = Math.sin(i);

  double vx = (cosO * cosW - sinO * sinW * cosI) * vx_pf + (-cosO * sinW - sinO * cosW * cosI) * vy_pf;
  double vy = (sinO * cosW + cosO * sinW * cosI) * vx_pf + (-sinO * sinW + cosO * cosW * cosI) * vy_pf;
  double vz = (sinW * sinI) * vx_pf + (cosW * sinI) * vy_pf;

  double[] result = new double[3];
  result[0] = vx; result[1] = vy; result[2] = vz;
  return result;
}

static double getTrueAnomalyAtTime(CelestialBody body, double t) {
  double n = 2.0 * PI / body.period;
  double M = (body.M0 + n * t) % (2.0 * PI);
  if (M < 0) M += 2.0 * PI;
  double E = solveKepler(M, body.e);
  return trueAnomaly(E, body.e);
}

static double[] getPositionAtTime(CelestialBody body, double t) {
  double n = 2.0 * PI / body.period;
  double M = (body.M0 + n * t) % (2.0 * PI);
  if (M < 0) M += 2.0 * PI;
  double E = solveKepler(M, body.e);
  double nu = trueAnomaly(E, body.e);
  return orbitalToCartesian(body.a, body.e, body.i, body.omega, body.w, nu);
}

static double[] getVelocityAtTime(CelestialBody body, double t) {
  double n = 2.0 * PI / body.period;
  double M = (body.M0 + n * t) % (2.0 * PI);
  if (M < 0) M += 2.0 * PI;
  double E = solveKepler(M, body.e);
  double nu = trueAnomaly(E, body.e);
  return orbitalVelocityToCartesian(body.a, body.e, body.i, body.omega, body.w, nu, GM_SUN);
}
