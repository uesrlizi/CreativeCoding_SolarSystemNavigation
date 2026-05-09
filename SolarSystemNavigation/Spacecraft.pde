enum ShipPhase {
  ON_GROUND,
  POWERED_ASCENT,
  COASTING,
  IN_ORBIT,
  TRANSFER,
  DECOUPLING
}

class Spacecraft {
  String name;
  color col;
  color trailColor;

  double[] position = new double[3];
  double[] velocity = new double[3];
  double mass;
  double fuel;
  double thrust;
  double isp;

  ShipPhase phase;
  double phaseTimer;
  double launchAzimuthAngle;
  double launchPitch;
  double throttle;

  ArrayList<double[]> trajectory;
  ArrayList<double[]> maneuverPlan;

  Spacecraft(String name, color col) {
    this.name = name;
    this.col = col;
    this.trailColor = col;
    this.mass = 1000.0;
    this.fuel = 500.0;
    this.thrust = 1500000.0;
    this.isp = 300.0;
    this.phase = ShipPhase.ON_GROUND;
    this.launchPitch = 90.0;
    this.launchAzimuthAngle = 90.0;
    this.throttle = 1.0;
    this.trajectory = new ArrayList<double[]>();
    this.maneuverPlan = new ArrayList<double[]>();
    for (int i = 0; i < 3; i++) {
      position[i] = 0;
      velocity[i] = 0;
    }
  }

  void setStateVector(double[] pos, double[] vel) {
    position = pos.clone();
    velocity = vel.clone();
  }

  void applyDeltaV(double[] dv) {
    velocity[0] += dv[0];
    velocity[1] += dv[1];
    velocity[2] += dv[2];
  }

  double speed() {
    return Math.sqrt(velocity[0]*velocity[0] + velocity[1]*velocity[1] + velocity[2]*velocity[2]);
  }

  double altitudeAGL(CelestialBody body) {
    double r = Math.sqrt(position[0]*position[0] + position[1]*position[1] + position[2]*position[2]);
    return (r - body.radius * 1000) / 1000.0;
  }

  boolean isInOrbit() {
    return phase == ShipPhase.IN_ORBIT;
  }

  void consumeFuel(double amount) {
    fuel = Math.max(0, fuel - amount);
  }

  double getThrustMagnitude() {
    if (fuel <= 0) return 0;
    return thrust * throttle;
  }

  double getMassFlowRate() {
    double g0 = 9.81;
    return getThrustMagnitude() / (isp * g0);
  }

  double orbitalPeriod(double r, double gm) {
    return 2 * PI * Math.sqrt(r * r * r / gm);
  }

  double orbitalApogee(double a, double e) {
    return a * (1 + e);
  }

  double orbitalPerigee(double a, double e) {
    return a * (1 - e);
  }

  void draw(CameraController cam) {
    double[] sp;
    if (phase == ShipPhase.ON_GROUND) {
      CelestialBody earth = null;
      for (CelestialBody p : solarSystem.planets) {
        if (p.name.equals("Earth")) {
          earth = p;
          break;
        }
      }
      if (earth != null) {
        double[] earthPos = earth.getPosition();
        double[] shipPos = new double[]{position[0] + earthPos[0], position[1] + earthPos[1], position[2] + earthPos[2]};
        sp = cam.worldToScreen(shipPos[0] / 1000, shipPos[1] / 1000);
      } else {
        sp = cam.worldToScreen(position[0] / 1000, position[1] / 1000);
      }
    } else {
      sp = cam.worldToScreen(position[0] / 1000, position[1] / 1000);
    }

    if (sp[0] < -50 || sp[0] > width + 50 || sp[1] < -50 || sp[1] > height + 50) return;

    float size = 6;
    fill(col);
    noStroke();
    ellipse((float)sp[0], (float)sp[1], size, size);

    if (phase == ShipPhase.POWERED_ASCENT) {
      float angle = (float)Math.atan2(-velocity[0], velocity[1]);
      fill(255, 150, 50, 180);
      noStroke();
      pushMatrix();
      translate((float)sp[0], (float)sp[1]);
      rotate(angle);
      triangle(-size * 2, 0, -size * 0.5, -size * 0.5, -size * 0.5, size * 0.5);
      popMatrix();
    }
  }
}
