class OrbitalManeuver {
  String name;
  double deltaV;
  double[] burnVector;
  ManeuverType type;

  OrbitalManeuver(String name, double deltaV, double[] burnVector, ManeuverType type) {
    this.name = name;
    this.deltaV = deltaV;
    this.burnVector = burnVector;
    this.type = type;
  }

  double[] calculateDeltaVVVector(double[] velocity, double dvMagnitude) {
    double speed = Math.sqrt(velocity[0]*velocity[0] + velocity[1]*velocity[1] + velocity[2]*velocity[2]);
    if (speed < 1e-10) return new double[]{0, dvMagnitude, 0};

    double[] prograde = normalize(velocity);
    return new double[]{
      prograde[0] * dvMagnitude,
      prograde[1] * dvMagnitude,
      prograde[2] * dvMagnitude
    };
  }

  double getBurnDuration(Spacecraft ship) {
    double thrust = ship.thrust;
    double isp = ship.isp;
    double g0 = 9.81;
    double m0 = ship.mass;
    double mf = m0 / Math.exp(deltaV / (isp * g0));
    return (m0 - mf) / (thrust / (isp * g0));
  }

  OrbitalManeuver createCircularize(double targetAltitude, CelestialBody body) {
    double r = body.radius * 1000 + targetAltitude * 1000;
    double vCircular = Math.sqrt(body.gm / r);
    return new OrbitalManeuver("Circularize", vCircular, new double[]{0, 1, 0}, ManeuverType.CIRCULARIZE);
  }

  OrbitalManeuver createRaiseApogee(double dv) {
    return new OrbitalManeuver("Raise Apogee", dv, new double[]{0, 1, 0}, ManeuverType.RAISE_APOGEE);
  }

  OrbitalManeuver createLowerApogee(double dv) {
    return new OrbitalManeuver("Lower Apogee", -dv, new double[]{0, -1, 0}, ManeuverType.LOWER_APOGEE);
  }

  OrbitalManeuver createEscape(CelestialBody body) {
    double r = body.radius * 1000;
    double vEscape = Math.sqrt(2 * body.gm / r);
    double vOrbital = Math.sqrt(body.gm / r);
    return new OrbitalManeuver("Escape", vEscape - vOrbital, new double[]{0, 1, 0}, ManeuverType.ESCAPE);
  }

  double[] computeHohmannTransfer(double r1, double r2, double gm) {
    double a = (r1 + r2) / 2;
    double v1 = Math.sqrt(gm / r1);
    double vTransfer1 = Math.sqrt(gm * (2.0/r1 - 1.0/a));
    double dv1 = vTransfer1 - v1;
    double v2 = Math.sqrt(gm / r2);
    double vTransfer2 = Math.sqrt(gm * (2.0/r2 - 1.0/a));
    double dv2 = vTransfer2 - v2;
    double transferTime = PI * Math.sqrt(a * a * a / gm);
    return new double[]{dv1, dv2, a, transferTime};
  }

  private double[] normalize(double[] v) {
    double mag = Math.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    if (mag < 1e-10) return new double[]{0, 1, 0};
    return new double[]{v[0]/mag, v[1]/mag, v[2]/mag};
  }
}

enum ManeuverType {
  CIRCULARIZE,
  TRANSFER,
  PLANE_CHANGE,
  RAISE_APOGEE,
  LOWER_APOGEE,
  ESCAPE
}
