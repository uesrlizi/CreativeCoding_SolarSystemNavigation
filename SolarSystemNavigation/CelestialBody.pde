class CelestialBody {
  String name;
  double a;
  double e;
  double i;
  double omega;
  double w;
  double M0;
  double period;
  double radius;
  color col;

  double px, py, pz;
  double currentNu;

  CelestialBody(String name, double a_au, double e, double i,
    double omega, double w, double M0, double T_days, double R_km, color col) {
    this.name = name;
    this.a = a_au * AU_KM;
    this.e = e;
    this.i = i;
    this.omega = omega;
    this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = T_days * DAY_S;
    this.radius = R_km;
    this.col = col;
  }

  CelestialBody(String name, double x, double y, double R_km, color col) {
    this.name = name;
    this.a = 0; this.e = 0; this.i = 0;
    this.omega = 0; this.w = 0; this.M0 = 0;
    this.period = 1;
    this.radius = R_km;
    this.col = col;
    this.px = x; this.py = y; this.pz = 0;
  }

  void update(double t) {
    if (a == 0) return;
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    double E = solveKepler(M, e);
    double nu = trueAnomaly(E, e);
    this.currentNu = nu;
    double[] pos = orbitalToCartesian(a, e, i, omega, w, nu);
    px = pos[0]; py = pos[1]; pz = pos[2];
  }

  void draw(CameraController cam) {
    double[] sp = cam.worldToScreen(px, py);

    double screenR = radius * cam.scale;
    int drawR = max((int)screenR, 2);
    if (sp[0] + drawR < -50 || sp[0] - drawR > width + 50 ||
        sp[1] + drawR < -50 || sp[1] - drawR > height + 50) return;

    noStroke();
    for (int g = 3; g >= 1; g--) {
      fill(red(col), green(col), blue(col), 30 / g);
      ellipse((float)sp[0], (float)sp[1], drawR * 2 + g * 4, drawR * 2 + g * 4);
    }

    fill(col);
    noStroke();
    ellipse((float)sp[0], (float)sp[1], drawR * 2, drawR * 2);

    if (showLabels) {
      fill(200, 200, 200, 200);
      textSize(17 * uiScale);
      textAlign(LEFT, CENTER);
      text(name, (float)sp[0] + drawR + 5, (float)sp[1]);
    }
  }

  double[] getPosition() {
    return new double[]{px, py, pz};
  }
}
