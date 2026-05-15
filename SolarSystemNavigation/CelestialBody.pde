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

    if (Double.isNaN(screenR) || Double.isInfinite(screenR)) return;

    double cx = sp[0], cy = sp[1];
    boolean centerOnScreen = cx >= 0 && cx <= width && cy >= 0 && cy <= height;

    // Cull — use unclamped radius so near-surface bodies aren't lost
    if (cx + screenR < -10 || cx - screenR > width + 10 ||
        cy + screenR < -10 || cy - screenR > height + 10) return;

    // LOD 4 — body circle contains all four screen corners
    double farCornerSq = 0;
    farCornerSq = Math.max(farCornerSq, cx*cx + cy*cy);
    farCornerSq = Math.max(farCornerSq, (cx-width)*(cx-width) + cy*cy);
    farCornerSq = Math.max(farCornerSq, cx*cx + (cy-height)*(cy-height));
    farCornerSq = Math.max(farCornerSq, (cx-width)*(cx-width) + (cy-height)*(cy-height));
    boolean coversScreen = farCornerSq <= screenR * screenR;

    noStroke();

    if (coversScreen) {
      // LOD 4 — body fills every pixel → single rect
      fill(col);
      rect(0, 0, width, height);
    } else if (centerOnScreen) {
      // LOD 1/2 — centre on screen; clamp radius, min 2 px
      double maxR = Math.max(width, height) * 3.0;
      double drawR = Math.min(screenR, maxR);
      if (drawR < 2) drawR = 2;
      fill(col);
      ellipse((float)cx, (float)cy, (float)(drawR * 2), (float)(drawR * 2));
    } else {
      // LOD 3 — near-surface: centre off screen, render visible arc
      // Scanline fill avoids float-precision artifacts of huge ellipses
      drawGroundScanline(cx, cy, screenR);
    }

    if (showLabels) {
      fill(200, 200, 200, 200);
      textSize(17 * uiScale);
      textAlign(LEFT, CENTER);
      float labelR = centerOnScreen ? (float)Math.min(screenR, Math.max(width, height) * 3.0) : (float)screenR;
      if (labelR < 2) labelR = 2;
      float labelX = (float)(cx + labelR + 5);
      float labelY = (float)cy;
      text(name, labelX, labelY);
    }
  }

  void drawGroundScanline(double cx, double cy, double r) {
    // Fill visible portion of body circle on screen, row by row.
    // All arithmetic in double; output coords clamped to screen bounds.
    noStroke();
    fill(col);
    double rSq = r * r;
    beginShape(QUADS);
    for (int py = 0; py < height; py++) {
      double dy = py - cy;
      double dxSq = rSq - dy * dy;
      if (dxSq <= 0) continue;
      double dx = Math.sqrt(dxSq);
      float sx = (float)Math.max(0.0, cx - dx);
      float ex = (float)Math.min((double)width, cx + dx);
      if (sx < ex) {
        float ny = py + 1.0f;
        vertex(sx, py);
        vertex(ex, py);
        vertex(ex, ny);
        vertex(sx, ny);
      }
    }
    endShape();
  }

  double[] getPosition() {
    return new double[]{px, py, pz};
  }
}
