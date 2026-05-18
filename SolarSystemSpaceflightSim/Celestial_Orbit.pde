// ========== ORBIT CLASS ==========

class Orbit {
  double a;
  double e;
  double w;
  double M0;
  double period;
  CelestialBody referenceBody;

  Orbit(double a, double e, double w, double M0, double period, CelestialBody referenceBody) {
    this.a = a;
    this.e = e;
    this.w = w;
    this.M0 = M0;
    this.period = period;
    this.referenceBody = referenceBody;
  }

  Vector2 getPositionAtTime(double t) {
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    double E = solveKepler(M, e);
    double nu = trueAnomaly(E, e);
    double[] pos = orbitalToCartesian2D(a, e, w, nu);
    return new Vector2(pos[0], pos[1]);
  }

  Vector2 getVelocityAtTime(double t) {
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    double E = solveKepler(M, e);
    double nu = trueAnomaly(E, e);
    double GM = (referenceBody != null && referenceBody.GM > 0) ? referenceBody.GM : GM_SUN;
    double[] vel = orbitalVelocityToCartesian2D(a, e, w, nu, GM);
    return new Vector2(vel[0], vel[1]);
  }

  double getTrueAnomalyAtTime(double t) {
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    double E = solveKepler(M, e);
    return trueAnomaly(E, e);
  }

  double getMeanAnomalyAtTime(double t) {
    double n = 2.0 * PI / period;
    return (M0 + n * t) % (2.0 * PI);
  }

  double getEccentricAnomalyAtTime(double t) {
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    return solveKepler(M, e);
  }

  double getApoapsisRadius() {
    return a * (1 + e);
  }

  double getPeriapsisRadius() {
    return a * (1 - e);
  }

  double getApoapsisAltitude() {
    if (referenceBody != null) {
      return getApoapsisRadius() - referenceBody.radius;
    }
    return getApoapsisRadius();
  }

  double getPeriapsisAltitude() {
    if (referenceBody != null) {
      return getPeriapsisRadius() - referenceBody.radius;
    }
    return getPeriapsisRadius();
  }

  double getSpecificOrbitalEnergy() {
    double GM = (referenceBody != null && referenceBody.GM > 0) ? referenceBody.GM : GM_SUN;
    return -GM / (2 * a);
  }
}

// ========== Orbit Factory from State Vector ==========

Orbit Orbit_fromStateVector(Vector2 pos, Vector2 vel, CelestialBody body, double t) {
  double GM = (body != null && body.GM > 0) ? body.GM : GM_SUN;

  // Calculate specific mechanical energy
  double r = pos.magnitude();
  double v = vel.magnitude();
  double vSq = v * v;
  double eps = vSq / 2 - GM / r;

  // Semi-major axis
  double a = -GM / (2 * eps);

  // Specific angular momentum
  double h = pos.x * vel.y - pos.y * vel.x;
  double hSq = h * h;

  // Eccentricity
  double eVecX = (vSq - GM / r) * pos.x - (pos.dot(vel)) * vel.x;
  double eVecY = (vSq - GM / r) * pos.y - (pos.dot(vel)) * vel.y;
  double e = Math.sqrt(eVecX * eVecX + eVecY * eVecY) / GM;

  // True anomaly
  double nu;
  if (e < 1e-8) {
    // Circular orbit
    nu = pos.angle();
  } else {
    // Elliptical orbit
    double cosNu = (hSq / (GM * r) - 1) / e;
    double sinNu = (h * pos.dot(vel)) / (GM * e * r);
    cosNu = constrainDouble(cosNu, -1, 1);
    sinNu = constrainDouble(sinNu, -1, 1);
    nu = Math.atan2(sinNu, cosNu);
  }

  // Argument of periapsis (w)
  double w;
  if (e < 1e-8) {
    w = 0;
  } else {
    double wAngle = Math.atan2(eVecY, eVecX);
    w = wAngle; // In 2D, periapsis direction is just e vector direction
  }

  // Eccentric anomaly
  double E = 2 * Math.atan2(Math.sqrt(1 - e) * Math.sin(nu / 2), Math.sqrt(1 + e) * Math.cos(nu / 2));

  // Mean anomaly at t=0
  double M0 = E - e * Math.sin(E);

  // Period
  double period = 2 * PI * Math.sqrt(a * a * a / GM);

  // Create orbit
  Orbit orbit = new Orbit(a, e, w, M0, period, body);
  return orbit;
}

// Helper functions (not private, static)
static double[] orbitalToCartesian2D(double a, double e, double w, double nu) {
  double r = a * (1 - e * e) / (1 + e * Math.cos(nu));
  double theta = w + nu;
  return new double[]{
    r * Math.cos(theta),
    r * Math.sin(theta)
  };
}

static double[] orbitalVelocityToCartesian2D(double a, double e, double w, double nu, double GM) {
  double p = a * (1 - e * e);
  double r = a * (1 - e * e) / (1 + e * Math.cos(nu));
  double h = Math.sqrt(GM * p);
  double vr = (GM * e * Math.sin(nu)) / h;
  double vt = h / r;
  double theta = w + nu;
  return new double[]{
    vr * Math.cos(theta) - vt * Math.sin(theta),
    vr * Math.sin(theta) + vt * Math.cos(theta)
  };
}
