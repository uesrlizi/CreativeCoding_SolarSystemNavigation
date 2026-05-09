class Spacecraft {
  String name;
  double a, e, i, omega, w, M0, period;
  color col;
  color trailColor;

  double px, py, pz;
  double currentNu;

  Spacecraft(String name, double a, double e, double i,
    double omega, double w, double M0, double period, color col) {
    this.name = name;
    this.a = a; this.e = e; this.i = i;
    this.omega = omega; this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = period;
    this.col = col;
    this.trailColor = col;
  }

  void update(double t) {
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    if (M < 0) M += 2.0 * PI;
    double E = solveKepler(M, e);
    currentNu = trueAnomaly(E, e);
    double[] pos = orbitalToCartesian(a, e, i, omega, w, currentNu);
    px = pos[0]; py = pos[1]; pz = pos[2];
  }

  void draw(Camera cam) {
    if (showTrails) {
      drawOrbitHighlight(cam);
    }

    double[] sp = cam.worldToScreen(px, py);
    if (sp[0] < -100 || sp[0] > width + 100 || sp[1] < -100 || sp[1] > height + 100) return;

    pushMatrix();
    translate((float)sp[0], (float)sp[1]);

    float angle = calculateOrientation(cam);
    rotate(angle);

    drawSpacecraftGraphic();

    popMatrix();

    if (showLabels) {
      fill(red(col), green(col), blue(col), 220);
      textSize(15);
      textAlign(LEFT, CENTER);
      text(name, (float)sp[0] + 15, (float)sp[1]);
    }
  }

  void drawSpacecraftGraphic() {
    float bodyLen = 10.0;
    float bodyWid = 5.0;
    
    noStroke();
    
    for (int g = 3; g >= 1; g--) {
      fill(red(col), green(col), blue(col), 30 / g);
      ellipse(0, 0, 18 + g * 4, 18 + g * 4);
    }
    
    fill(red(col) * 0.7, green(col) * 0.7, blue(col) * 0.7);
    beginShape();
    vertex(bodyLen * 0.6, 0);
    vertex(-bodyLen * 0.2, -bodyWid * 0.5);
    vertex(-bodyLen * 0.5, -bodyWid * 0.3);
    vertex(-bodyLen * 0.5, bodyWid * 0.3);
    vertex(-bodyLen * 0.2, bodyWid * 0.5);
    endShape(CLOSE);
    
    fill(col);
    beginShape();
    vertex(bodyLen * 0.5, 0);
    vertex(-bodyLen * 0.3, -bodyWid * 0.4);
    vertex(-bodyLen * 0.5, -bodyWid * 0.25);
    vertex(-bodyLen * 0.5, bodyWid * 0.25);
    vertex(-bodyLen * 0.3, bodyWid * 0.4);
    endShape(CLOSE);
    
    pushMatrix();
    rotate(radians(35));
    fill(red(col) * 0.8, green(col) * 0.8, blue(col) * 0.8);
    beginShape();
    vertex(0, 0);
    vertex(-bodyLen * 0.3, -2);
    vertex(-bodyLen * 0.8, -1.5);
    vertex(-bodyLen * 0.9, 0);
    endShape(CLOSE);
    popMatrix();
    
    pushMatrix();
    rotate(radians(-35));
    fill(red(col) * 0.8, green(col) * 0.8, blue(col) * 0.8);
    beginShape();
    vertex(0, 0);
    vertex(-bodyLen * 0.3, 2);
    vertex(-bodyLen * 0.8, 1.5);
    vertex(-bodyLen * 0.9, 0);
    endShape(CLOSE);
    popMatrix();
    
    fill(255, 140, 30, 150);
    triangle(-bodyLen * 0.5, -2, -bodyLen * 0.5, 2, -bodyLen * 0.5 - 10, 0);
    
    fill(255, 200, 50, 200);
    triangle(-bodyLen * 0.5, -1.5, -bodyLen * 0.5, 1.5, -bodyLen * 0.5 - 7, 0);
    
    fill(255, 255, 200, 230);
    triangle(-bodyLen * 0.5, -0.8, -bodyLen * 0.5, 0.8, -bodyLen * 0.5 - 4, 0);
  }

  void drawOrbitHighlight(Camera cam) {
    double arcLength = 0.3;
    int steps = 60;
    
    noFill();
    stroke(trailColor);
    strokeWeight(2.5);
    beginShape();
    
    for (int j = 0; j <= steps; j++) {
      double nu = currentNu - arcLength + (arcLength * j / steps);
      double[] pos = orbitalToCartesian(a, e, i, omega, w, nu);
      double[] sp = cam.worldToScreen(pos[0], pos[1]);
      vertex((float)sp[0], (float)sp[1]);
    }
    
    endShape();
  }

  float calculateOrientation(Camera cam) {
    double nuForward = currentNu + 0.01;
    double[] posForward = orbitalToCartesian(a, e, i, omega, w, nuForward);
    
    double vx = posForward[0] - px;
    double vy = posForward[1] - py;
    
    return (float)Math.atan2(vy, vx);
  }
}
