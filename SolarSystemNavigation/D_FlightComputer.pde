// ============================================================
//  FlightComputer — guidance algorithms and maneuver planning
//  Extracted from the old Spacecraft class. All algorithms in one place.
// ============================================================

class FlightComputer {
  // ==============================================================
  //  Guidance constants (previously in Spacecraft)
  // ==============================================================

  static final double THRUST_ACCEL = 0.025;
  static final double VERTICAL_RISE_TIME = 10.0;
  static final double MAX_PITCH_RAD = 1.4835298641951802;
  static final double PITCH_EXPONENT = 0.7;
  static final double PEG_K_ALT = 0.02;
  static final double PEG_K_VRAD = 2.0;
  static final double PEG_MAX_PITCH = 1.2;

  // ==============================================================
  //  Ascent thrust direction — pitch program
  //  Returns angle in radians from +X (world space)
  // ==============================================================

  double ascentThrustDirection(double rx, double ry, double burnTime, double targetAltitude) {
    double r = Math.sqrt(rx * rx + ry * ry);
    if (r < 1.0) return 0;

    if (burnTime < VERTICAL_RISE_TIME) {
      return Math.atan2(ry, rx);
    }

    double alt = r - MissionPlanner.EARTH_RADIUS_KM;
    double altFrac = Math.max(0.0, Math.min(1.0, alt / targetAltitude));
    double pitchAngle = Math.pow(altFrac, PITCH_EXPONENT) * MAX_PITCH_RAD;

    double radX = rx / r, radY = ry / r;
    double tanX = -ry / r, tanY = rx / r;
    double thrX = radX * Math.cos(pitchAngle) + tanX * Math.sin(pitchAngle);
    double thrY = radY * Math.cos(pitchAngle) + tanY * Math.sin(pitchAngle);
    return Math.atan2(thrY, thrX);
  }

  // ==============================================================
  //  PEG guidance — circularization at apoapsis
  //  Returns [pitchOffset (rad), thrustAngle (rad)]
  // ==============================================================

  double[] pegGuidance(double rx, double ry, double vx, double vy, double targetRadius, double GM) {
    double r = Math.sqrt(rx * rx + ry * ry);
    if (r < 1.0) {
      return new double[]{0, 0};
    }

    double vRad = (rx * vx + ry * vy) / r;
    double altError = r - targetRadius;
    double pitchOffset = -PEG_K_ALT * altError - PEG_K_VRAD * vRad;
    if (pitchOffset >  PEG_MAX_PITCH) pitchOffset =  PEG_MAX_PITCH;
    if (pitchOffset < -PEG_MAX_PITCH) pitchOffset = -PEG_MAX_PITCH;

    double tanX = -ry / r, tanY = rx / r;
    double radX = rx / r, radY = ry / r;
    double cosP = Math.cos(pitchOffset);
    double sinP = Math.sin(pitchOffset);
    double thrX = tanX * cosP + radX * sinP;
    double thrY = tanY * cosP + radY * sinP;

    return new double[]{pitchOffset, Math.atan2(thrY, thrX)};
  }

  // ==============================================================
  //  Tangential thrust direction (for TMI or TOI burns)
  //  Set prograde = true for CCW direction (prograde for counterclockwise orbits)
  //  Returns unit vector [x, y]
  // ==============================================================

  double[] tangentialThrustDirection(double[] vel, boolean prograde) {
    double vx = vel[0], vy = vel[1];
    double v = Math.sqrt(vx * vx + vy * vy);
    if (v < 0.001) return new double[]{1, 0};
    double dir = prograde ? 1.0 : -1.0;
    return new double[]{dir * vx / v, dir * vy / v};
  }

  double[] tangentialThrustDirection(double rx, double ry, boolean prograde) {
    double r = Math.sqrt(rx * rx + ry * ry);
    if (r < 0.001) return new double[]{1, 0};
    double dir = prograde ? 1.0 : -1.0;
    return new double[]{dir * -ry / r, dir * rx / r};
  }

  // ==============================================================
  //  Compute apoapsis altitude (km above surface)
  // ==============================================================

  double apoapsisAltitude(double rx, double ry, double vx, double vy, double bodyRadius, double GM) {
    double[] p = osculatingParams(rx, ry, vx, vy, GM);
    if (p[0] >= Double.MAX_VALUE / 2) return Double.MAX_VALUE;
    return p[0] * (1.0 + p[1]) - bodyRadius;
  }

  // ==============================================================
  //  Compute perigee altitude (km above surface)
  // ==============================================================

  double perigeeAltitude(double rx, double ry, double vx, double vy, double bodyRadius, double GM) {
    double[] p = osculatingParams(rx, ry, vx, vy, GM);
    if (p[0] >= Double.MAX_VALUE / 2) return Double.MAX_VALUE;
    return p[0] * (1.0 - p[1]) - bodyRadius;
  }

  // ==============================================================
  //  Time until apoapsis (seconds), -1 if already past
  // ==============================================================

  double timeToApoapsis(double rx, double ry, double vx, double vy, double GM) {
    double[] p = osculatingParams(rx, ry, vx, vy, GM);
    if (p[3] >= 0) return -1; // hyperbolic
    double a = p[0], e = p[1];
    if (e < 0.0001) return Double.MAX_VALUE; // near-circular

    double r = Math.sqrt(rx * rx + ry * ry);
    double vRad = (rx * vx + ry * vy) / r;

    double cosNu = (a * (1.0 - e * e) / r - 1.0) / e;
    cosNu = Math.max(-1.0, Math.min(1.0, cosNu));
    double nu = Math.acos(cosNu);
    if (vRad < 0) nu = 2.0 * PI - nu;

    double cosE = (e + Math.cos(nu)) / (1.0 + e * Math.cos(nu));
    double sinE = Math.sqrt(1.0 - e * e) * Math.sin(nu) / (1.0 + e * Math.cos(nu));
    double E = Math.atan2(sinE, cosE);
    if (E < 0) E += 2.0 * PI;

    double M = E - e * Math.sin(E);
    double n = Math.sqrt(GM / (a * a * a));

    if (M < PI) return (PI - M) / n;
    return -1;
  }

  // ==============================================================
  //  Helper: get osculating orbital parameters
  //  Returns [a (km), e, h (km^2/s), energy]
  // ==============================================================

  double[] osculatingParams(double rx, double ry, double vx, double vy, double GM) {
    double r = Math.sqrt(rx * rx + ry * ry);
    double v2 = vx * vx + vy * vy;
    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return new double[]{Double.MAX_VALUE, Double.MAX_VALUE, 0, energy};
    double a = -GM / (2.0 * energy);
    double h = rx * vy - ry * vx;
    double e2 = 1.0 - h * h / (GM * a);
    double e = Math.sqrt(Math.max(0.0, e2));
    return new double[]{a, e, h, energy};
  }

  // ==============================================================
  //  Estimate the thrust fraction needed to hit a target apoapsis
  //  Used in ascent guidance to cut thrust at the right moment
  // ==============================================================

  double estimateThrustFraction(
      double rx, double ry, double vx, double vy,
      double thrustAccel, double[] thrustDir, double GM,
      double targetApoAlt, double bodyRadius) {
    double currentApo = apoapsisAltitude(rx, ry, vx, vy, bodyRadius, GM);
    if (currentApo >= targetApoAlt) return 0;

    double r = Math.sqrt(rx * rx + ry * ry);
    double gMag = GM / (r * r);
    double gravX = -gMag * rx / r;
    double gravY = -gMag * ry / r;

    double thrX = thrustAccel * thrustDir[0];
    double thrY = thrustAccel * thrustDir[1];
    double ax = gravX + thrX;
    double ay = gravY + thrY;

    double preVx = vx, preVy = vy;
    double preRx = rx, preRy = ry;

    double step = 1.0;
    double vxFull = preVx + ax * step;
    double vyFull = preVy + ay * step;
    double rxFull = preRx + vxFull * step;
    double ryFull = preRy + vyFull * step;

    double apoFull = apoapsisAltitude(rxFull, ryFull, vxFull, vyFull, bodyRadius, GM);

    double vxGravOnly = preVx + gravX * step;
    double vyGravOnly = preVy + gravY * step;
    double rxGravOnly = preRx + vxGravOnly * step;
    double ryGravOnly = preRy + vyGravOnly * step;
    double apoGravOnly = apoapsisAltitude(rxGravOnly, ryGravOnly, vxGravOnly, vyGravOnly, bodyRadius, GM);

    if (apoFull > apoGravOnly && apoGravOnly < targetApoAlt) {
      double f = (targetApoAlt - apoGravOnly) / (apoFull - apoGravOnly);
      f = Math.max(0.0, Math.min(1.0, f));
      return f;
    }
    return 1.0; // apply full thrust
  }
}
