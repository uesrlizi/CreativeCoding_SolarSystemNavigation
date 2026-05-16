// ============================================================
//  PhysicsEngine — Newtonian mechanics integrator
//  Handles semi-implicit Euler with sub-stepping for stable gravity burns
//  Equivalent to KSP's physics integrator when "not on rails"
// ============================================================

class PhysicsEngine {
  // Integration parameters
  static final double FIXED_SUBSTEP = 1.0;   // seconds per physics tick
  static final int MAX_SUBSTEPS = 10000;

  // Event flags
  boolean crashed = false;
  boolean apoPassed = false;

  // ==============================================================
  //  Integrate physics forward by dt (simulated seconds)
  //  Calls forceModel.computeForce(pos, vel, accelOut) each substep
  //  Modifies pos and vel IN-PLACE
  //  Returns number of substeps executed
  // ==============================================================

  int integrate(double[] pos, double[] vel, double dt, ForceModel forceModel) {
    if (dt <= 0) return 0;

    double remainingDt = dt;
    int steps = 0;
    double[] accel = new double[2];

    while (remainingDt > 0 && steps < MAX_SUBSTEPS && !crashed) {
      double step = Math.min(remainingDt, FIXED_SUBSTEP);

      forceModel.computeForce(pos, vel, accel);

      double r = Math.sqrt(pos[0] * pos[0] + pos[1] * pos[1]);
      if (r < 0.5 * forceModel.bodyRadius()) {
        crashed = true;
        break;
      }

      // Semi-implicit Euler: velocity first, then position
      vel[0] += accel[0] * step;
      vel[1] += accel[1] * step;
      pos[0] += vel[0] * step;
      pos[1] += vel[1] * step;

      remainingDt -= step;
      steps++;
    }

    return steps;
  }

  // ==============================================================
  //  Integrate for ascent with apoapsis detection
  //  Stops thrust when target apoapsis is reached
  // ==============================================================

  int integrateAscent(
      double[] pos, double[] vel, double dt,
      ForceModel forceModel, double targetApoAlt, double bodyRadius, double GM,
      FlightComputer flightComputer) {
    if (dt <= 0) return 0;

    double remainingDt = dt;
    int steps = 0;
    double[] accel = new double[2];
    boolean thrustActive = forceModel.thrustActive();

    while (remainingDt > 0 && steps < MAX_SUBSTEPS && !crashed) {
      double step = Math.min(remainingDt, FIXED_SUBSTEP);

      double rx = pos[0], ry = pos[1];
      double vx = vel[0], vy = vel[1];

      if (thrustActive) {
        double currentApo = flightComputer.apoapsisAltitude(rx, ry, vx, vy, bodyRadius, GM);
        if (currentApo >= targetApoAlt) {
          thrustActive = false;
        }
      }

      forceModel.computeForce(pos, vel, accel, thrustActive);

      double r = Math.sqrt(rx * rx + ry * ry);
      if (r < 0.5 * bodyRadius) {
        crashed = true;
        break;
      }

      vel[0] += accel[0] * step;
      vel[1] += accel[1] * step;
      pos[0] += vel[0] * step;
      pos[1] += vel[1] * step;

      remainingDt -= step;
      steps++;
    }

    return steps;
  }

  // ==============================================================
  //  Reset crash flag
  // ==============================================================

  void reset() {
    crashed = false;
    apoPassed = false;
  }
}

// ==============================================================
//  ForceModel — callback to compute forces per substep
//  Subclass to implement different force profiles
// ==============================================================

abstract class ForceModel {
  abstract void computeForce(double[] pos, double[] vel, double[] accelOut);
  abstract void computeForce(double[] pos, double[] vel, double[] accelOut, boolean useThrust);
  abstract double bodyRadius();
  abstract boolean thrustActive();
}
