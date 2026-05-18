// ========== COORDINATE TRANSFORMER ==========

class CoordinateTransformer {

  CoordinateTransformer() {
  }

  Vector2 toBodyCentric(Vector2 heliocentricPos, CelestialBody body, double t) {
    double[] bodyPos = getBodyPositionAtTime(body, t);
    return new Vector2(
      heliocentricPos.x - bodyPos[0],
      heliocentricPos.y - bodyPos[1]
    );
  }

  Vector2 toBodyCentricVelocity(Vector2 heliocentricVel, Vector2 heliocentricPos, CelestialBody body, double t) {
    double[] bodyVel = getBodyVelocityAtTime(body, t);
    return new Vector2(
      heliocentricVel.x - bodyVel[0],
      heliocentricVel.y - bodyVel[1]
    );
  }

  Vector2 toHeliocentric(Vector2 bodyCentricPos, CelestialBody body, double t) {
    double[] bodyPos = getBodyPositionAtTime(body, t);
    return new Vector2(
      bodyCentricPos.x + bodyPos[0],
      bodyCentricPos.y + bodyPos[1]
    );
  }

  Vector2 toHeliocentricVelocity(Vector2 bodyCentricVel, Vector2 bodyCentricPos, CelestialBody body, double t) {
    double[] bodyVel = getBodyVelocityAtTime(body, t);
    return new Vector2(
      bodyCentricVel.x + bodyVel[0],
      bodyCentricVel.y + bodyVel[1]
    );
  }

  Vector2 toBodyFixed(Vector2 bodyCentricPos, CelestialBody body, double t) {
    double rotationAngle = getBodyRotationAngle(body, t);
    return bodyCentricPos.rotate(-rotationAngle);
  }

  Vector2 toBodyCentricFromFixed(Vector2 bodyFixedPos, CelestialBody body, double t) {
    double rotationAngle = getBodyRotationAngle(body, t);
    return bodyFixedPos.rotate(rotationAngle);
  }

  double[] getBodyPositionAtTime(CelestialBody body, double t) {
    if (body.a != 0) {
      double n = 2.0 * PI / body.period;
      double M = (body.M0 + n * t) % (2.0 * PI);
      double E = solveKepler(M, body.e);
      double nu = trueAnomaly(E, body.e);
      double[] pos = orbitalToCartesian2D(body.a, body.e, body.w, nu);
      if (body.parentBody != null) {
        double[] parentPos = getBodyPositionAtTime(body.parentBody, t);
        pos[0] += parentPos[0];
        pos[1] += parentPos[1];
      }
      return pos;
    } else {
      return new double[]{body.px, body.py};
    }
  }

  double[] getBodyVelocityAtTime(CelestialBody body, double t) {
    if (body.a != 0 && body.period > 0) {
      double n = 2.0 * PI / body.period;
      double M = (body.M0 + n * t) % (2.0 * PI);
      double E = solveKepler(M, body.e);
      double nu = trueAnomaly(E, body.e);
      double[] vel = orbitalVelocityToCartesian2D(body.a, body.e, body.w, nu, body.GM > 0 ? body.GM : GM_SUN);
      if (body.parentBody != null && body.parentBody.GM > 0) {
        double[] parentVel = getBodyVelocityAtTime(body.parentBody, t);
        vel[0] += parentVel[0];
        vel[1] += parentVel[1];
      }
      return vel;
    } else {
      return new double[]{0, 0};
    }
  }

  double getBodyRotationAngle(CelestialBody body, double t) {
    double simDays = t / DAY_S;
    double totalRotations = simDays / body.rotationPeriodDays;
    double rotationRad = body.initialRotation + totalRotations * TWO_PI;
    rotationRad = rotationRad % TWO_PI;
    if (rotationRad < 0) rotationRad += TWO_PI;
    return rotationRad;
  }
}
