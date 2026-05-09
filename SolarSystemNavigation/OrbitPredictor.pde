class OrbitPredictor {
  ArrayList<double[]> predictedPath;
  int maxPoints;
  double predictionTimeSpan;
  PhysicsEngine physics;

  OrbitPredictor() {
    predictedPath = new ArrayList<double[]>();
    maxPoints = 500;
    predictionTimeSpan = 86400 * 2;
    physics = new PhysicsEngine();
  }

  void update(Spacecraft ship) {
    predictedPath.clear();
    if (ship == null || ship.phase != ShipPhase.IN_ORBIT) return;

    double[] pos = ship.position.clone();
    double[] vel = ship.velocity.clone();
    double dt = predictionTimeSpan / maxPoints;

    for (int i = 0; i < maxPoints; i++) {
      predictedPath.add(pos.clone());
      double[] acc = physics.totalGravity(pos);
      vel[0] += acc[0] * dt;
      vel[1] += acc[1] * dt;
      vel[2] += acc[2] * dt;
      pos[0] += vel[0] * dt;
      pos[1] += vel[1] * dt;
      pos[2] += vel[2] * dt;
    }
  }

  void draw(CameraController cam) {
    if (predictedPath.isEmpty()) return;

    noFill();
    stroke(100, 200, 100, 80);
    strokeWeight(1);
    beginShape();
    for (int i = 0; i < predictedPath.size(); i++) {
      double[] p = predictedPath.get(i);
      double[] sp = cam.worldToScreen(p[0] / 1000, p[1] / 1000);
      if (sp[0] >= -50 && sp[0] <= width + 50 && sp[1] >= -50 && sp[1] <= height + 50) {
        vertex((float)sp[0], (float)sp[1]);
      }
    }
    endShape();
  }
}
