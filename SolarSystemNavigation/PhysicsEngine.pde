class PhysicsEngine {
  static final double G = 6.67430e-11;
  static final double KM_TO_M = 1000.0;
  static final double EARTH_GM = 3.986004418e14;
  static final double SUN_GM = 1.32712440018e20;

  double[] gravityAt(double[] pos, CelestialBody body) {
    double[] bodyPos = body.getPosition();
    double[] r = new double[]{pos[0] - bodyPos[0], pos[1] - bodyPos[1], pos[2] - bodyPos[2]};
    double rMag = Math.sqrt(r[0]*r[0] + r[1]*r[1] + r[2]*r[2]);
    if (rMag < body.radius * 1000) rMag = body.radius * 1000;
    double gMag = body.gm / (rMag * rMag);
    return new double[]{-gMag * r[0] / rMag, -gMag * r[1] / rMag, -gMag * r[2] / rMag};
  }

  double[] totalGravity(double[] pos) {
    double[] acc = {0, 0, 0};
    for (CelestialBody body : solarSystem.planets) {
      double[] g = gravityAt(pos, body);
      acc[0] += g[0]; acc[1] += g[1]; acc[2] += g[2];
    }
    double[] gSun = gravityAt(pos, solarSystem.sun);
    acc[0] += gSun[0]; acc[1] += gSun[1]; acc[2] += gSun[2];
    return acc;
  }

  double[] integrateRK4(double[] pos, double[] vel, double dt) {
    double[] k1v = totalGravity(pos);
    double[] k1p = vel;

    double[] pos2 = {pos[0]+k1p[0]*dt/2, pos[1]+k1p[1]*dt/2, pos[2]+k1p[2]*dt/2};
    double[] vel2 = {vel[0]+k1v[0]*dt/2, vel[1]+k1v[1]*dt/2, vel[2]+k1v[2]*dt/2};
    double[] k2v = totalGravity(pos2);
    double[] k2p = vel2;

    double[] pos3 = {pos[0]+k2p[0]*dt/2, pos[1]+k2p[1]*dt/2, pos[2]+k2p[2]*dt/2};
    double[] vel3 = {vel[0]+k2v[0]*dt/2, vel[1]+k2v[1]*dt/2, vel[2]+k2v[2]*dt/2};
    double[] k3v = totalGravity(pos3);
    double[] k3p = vel3;

    double[] pos4 = {pos[0]+k3p[0]*dt, pos[1]+k3p[1]*dt, pos[2]+k3p[2]*dt};
    double[] vel4 = {vel[0]+k3v[0]*dt, vel[1]+k3v[1]*dt, vel[2]+k3v[2]*dt};
    double[] k4v = totalGravity(pos4);
    double[] k4p = vel4;

    double[] newPos = {
      pos[0] + (k1p[0] + 2*k2p[0] + 2*k3p[0] + k4p[0]) * dt / 6,
      pos[1] + (k1p[1] + 2*k2p[1] + 2*k3p[1] + k4p[1]) * dt / 6,
      pos[2] + (k1p[2] + 2*k2p[2] + 2*k3p[2] + k4p[2]) * dt / 6
    };
    double[] newVel = {
      vel[0] + (k1v[0] + 2*k2v[0] + 2*k3v[0] + k4v[0]) * dt / 6,
      vel[1] + (k1v[1] + 2*k2v[1] + 2*k3v[1] + k4v[1]) * dt / 6,
      vel[2] + (k1v[2] + 2*k2v[2] + 2*k3v[2] + k4v[2]) * dt / 6
    };
    return new double[]{newPos[0], newPos[1], newPos[2], newVel[0], newVel[1], newVel[2]};
  }

  double orbitalSpeed(double r, double gm) {
    return Math.sqrt(gm / r);
  }

  double escapeVelocity(double r, double gm) {
    return Math.sqrt(2 * gm / r);
  }

  double altitude(double r, double bodyRadius) {
    return (r - bodyRadius) / 1000.0;
  }

  double[] orbitalElements(double[] r, double[] v, double gm) {
    double rMag = Math.sqrt(r[0]*r[0] + r[1]*r[1] + r[2]*r[2]);
    double vMag = Math.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    double mu = gm;
    double specificEnergy = vMag*vMag/2 - mu/rMag;
    double a = -mu / (2 * specificEnergy);
    double hx = r[0]*v[1] - r[1]*v[0];
    double hy = r[1]*v[2] - r[2]*v[1];
    double hz = r[2]*v[0] - r[0]*v[2];
    double h = Math.sqrt(hx*hx + hy*hy + hz*hz);
    double e = Math.sqrt(1 + 2*specificEnergy*h*h/(mu*mu));
    return new double[]{a, e, h};
  }

  double specificAngularMomentum(double[] r, double[] v) {
    return r[0]*v[1] - r[1]*v[0];
  }

  double[] velocityAtPeriapsis(double a, double e, double gm) {
    double v = Math.sqrt(gm * (2/(a*(1-e)) - 1/a));
    return new double[]{v};
  }

  double[] velocityAtApoapsis(double a, double e, double gm) {
    double v = Math.sqrt(gm * (2/(a*(1+e)) - 1/a));
    return new double[]{v};
  }
}
