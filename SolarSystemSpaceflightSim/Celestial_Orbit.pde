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

// Helper functions (not private, not static)
double[] orbitalToCartesian2D(double a, double e, double w, double nu) {
  double r = a * (1 - e * e) / (1 + e * Math.cos(nu));
  double theta = w + nu;
  return new double[]{
    r * Math.cos(theta),
    r * Math.sin(theta)
  };
}

double[] orbitalVelocityToCartesian2D(double a, double e, double w, double nu, double GM) {
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
