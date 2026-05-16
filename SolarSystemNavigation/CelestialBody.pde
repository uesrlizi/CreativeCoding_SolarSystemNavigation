enum BodyType { SUN, TERRESTRIAL, GAS_GIANT, ICE_GIANT }

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

  // Visual properties
  BodyType type;
  float rotation;           // current rotation angle
  float rotationRate;       // rotation speed
  float axialTilt;          // axial tilt in radians

  // Ring system
  boolean hasRing;
  float ringInnerRadius;
  float ringOuterRadius;
  color ringColor;
  float ringTilt;

  // Atmosphere
  boolean hasAtmosphere;
  color atmosphereColor;
  float atmosphereThickness;

  // For rendering access
  CelestialBodyRenderer renderer;

  CelestialBody(String name, double a_au, double e, double i,
    double omega, double w, double M0, double T_days, double R_km, color col, BodyType type) {
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
    this.type = type;
    initVisualProperties();
  }

  CelestialBody(String name, double x, double y, double R_km, color col, BodyType type) {
    this.name = name;
    this.a = 0; this.e = 0; this.i = 0;
    this.omega = 0; this.w = 0; this.M0 = 0;
    this.period = 1;
    this.radius = R_km;
    this.col = col;
    this.px = x; this.py = y; this.pz = 0;
    this.type = type;
    initVisualProperties();
  }

  void initVisualProperties() {
    rotation = random(TWO_PI);
    rotationRate = 0.005f;
    axialTilt = 0;
    hasRing = false;
    ringInnerRadius = 1.5f;
    ringOuterRadius = 2.5f;
    ringColor = color(200, 180, 140, 150);
    ringTilt = 0.4f;
    hasAtmosphere = false;
    atmosphereColor = col;
    atmosphereThickness = 0.1f;
  }

  void setRenderer(CelestialBodyRenderer r) {
    this.renderer = r;
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
    rotation += rotationRate;
  }

  void draw(CameraController cam) {
    double[] sp = cam.worldToScreen(px, py);
    double screenR = radius * cam.scale;

    if (Double.isNaN(screenR) || Double.isInfinite(screenR)) return;

    double cx = sp[0], cy = sp[1];

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

    // 完全按屏幕半径判定LOD，不看中心位置
    double drawR = screenR;
    if (drawR < 2) drawR = 2;

    if (renderer != null) {
      if (coversScreen) {
        renderer.drawLOD4(this, cx, cy, screenR);
      } else if (drawR > width * 0.5 || drawR > height * 0.5) {
        // 特别大时用扫描线方式避免巨形
        renderer.drawScanlineLOD(this, cx, cy, screenR);
      } else if (drawR < 20) {
        renderer.drawLOD0(this, cx, cy, drawR);
      } else if (drawR < 80) {
        renderer.drawLOD1(this, cx, cy, drawR);
      } else if (drawR < 250) {
        renderer.drawLOD2(this, cx, cy, drawR);
      } else {
        renderer.drawLOD3(this, cx, cy, drawR);
      }
    } else {
      // Fallback simple rendering
      if (coversScreen) {
        fill(col);
        rect(0, 0, width, height);
      } else {
        drawGroundScanline(cx, cy, screenR);
      }
    }

    if (showLabels) {
      fill(200, 200, 200, 200);
      textSize(17 * uiScale);
      textAlign(LEFT, CENTER);
      float labelR = (float)drawR;
      if (labelR < 2) labelR = 2;
      float labelX = (float)(cx + labelR + 5);
      float labelY = (float)cy;
      text(name, labelX, labelY);

      // LOD 级别提示
      String lodStr = getLODString(drawR, coversScreen);
      fill(80, 200, 120, 200);
      textSize(12 * uiScale);
      text(lodStr, labelX, labelY + 18 * uiScale);
    }
  }

  String getLODString(double drawR, boolean coversScreen) {
    if (coversScreen) return "LOD: 4 (Scanline)";
    if (drawR > width * 0.5 || drawR > height * 0.5) return "LOD: Scanline";
    if (drawR < 20) return "LOD: 0";
    if (drawR < 80) return "LOD: 1";
    if (drawR < 250) return "LOD: 2";
    return "LOD: 3";
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
