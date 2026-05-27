// ========== CELESTIAL BODY ==========

class CelestialBody {
  String name;

  Orbit orbit;

  // 轨道数据 - 向后兼容字段，与orbit同步
  double a;
  double e;
  double i;
  double omega;
  double w;
  double M0;
  double period;
  double px, py, pz;
  double currentNu;

  double radius;
  color col;

  double GM;
  double mass;
  CelestialBody parentBody;
  double soiRadius;

  BodyType type;
  float rotation;
  float rotationRate;
  float rotationPeriodDays;
  float axialTilt;
  float initialRotation;

  boolean hasRing;
  float ringInnerRadius;
  float ringOuterRadius;
  color ringColor;
  float ringTilt;

  boolean hasAtmosphere;
  color atmosphereColor;
  float atmosphereThickness;

  Atmosphere atmosphere;

  CelestialBodyRenderer renderer;

  CelestialBody(String name, double a_au, double e, double i, double omega, double w, double M0, double T_days, double R_km, color col, BodyType type) {
    this.name = name;
    this.a = a_au * AU_KM;
    this.e = e;
    this.i = Math.toRadians(i);
    this.omega = Math.toRadians(omega);
    this.w = Math.toRadians(w);
    this.M0 = Math.toRadians(M0);
    this.period = T_days * DAY_S;
    this.orbit = new Orbit(this.a, this.e, this.w, this.M0, 0.0, this.period, null);
    this.radius = R_km;
    this.col = col;
    this.type = type;
    this.GM = 0;
    this.mass = 0;
    this.parentBody = null;
    this.soiRadius = 0;
    this.atmosphere = new Atmosphere();
    initVisualProperties();
  }

  CelestialBody(String name, double x, double y, double R_km, color col, BodyType type) {
    this.name = name;
    this.a = 0;
    this.e = 0;
    this.i = 0;
    this.omega = 0;
    this.w = 0;
    this.M0 = 0;
    this.period = 1;
    this.orbit = null;
    this.px = x;
    this.py = y;
    this.pz = 0;
    this.radius = R_km;
    this.col = col;
    this.type = type;
    this.GM = 0;
    this.mass = 0;
    this.parentBody = null;
    this.soiRadius = 0;
    this.atmosphere = new Atmosphere();
    initVisualProperties();
  }

  void setGM(double gm) {
    this.GM = gm;
    if (this.orbit != null) {
      this.orbit.referenceBody = this;
    }
  }

  void setMass(double m) {
    this.mass = m;
  }

  void setParentBody(CelestialBody parent) {
    this.parentBody = parent;
    if (this.orbit != null) {
      this.orbit.referenceBody = parent;
    }
  }

  void setSOIRadius(double r) {
    this.soiRadius = r;
  }

  void initVisualProperties() {
    initialRotation = random(TWO_PI);
    rotation = initialRotation;
    rotationRate = 0.005f;
    rotationPeriodDays = 1.0f;
    axialTilt = 0;
    hasRing = false;
    ringInnerRadius = 1.5f;
    ringOuterRadius = 2.5f;
    ringColor = color(200, 180, 140, 150);
    ringTilt = 0.4f;
    hasAtmosphere = false;
    atmosphereColor = col;
    atmosphereThickness = 0.1f;
    atmosphere.hasAtmosphere = false;
    atmosphere.atmosphereColor = col;
    atmosphere.maxAltitude = radius * 0.1;
  }

  void setRenderer(CelestialBodyRenderer r) {
    this.renderer = r;
  }

  void update(double t) {
    if (orbit != null) {
      // 使用Orbit类计算
      double nu = orbit.getTrueAnomalyAtTime(t);
      this.currentNu = nu;
      // 注意：i和omega是Orbit类没有的（3D参数），继续用字段
      double[] pos = orbitalToCartesian(orbit.a, orbit.e, i, omega, orbit.w, nu);
      px = pos[0]; py = pos[1]; pz = pos[2];

      if (parentBody != null) {
        px += parentBody.px;
        py += parentBody.py;
      }
    } else if (a != 0) {
      // 向后兼容：没有orbit时用原方式
      double n = 2.0 * PI / period;
      double M = (M0 + n * t) % (2.0 * PI);
      double E = solveKepler(M, e);
      double nu = trueAnomaly(E, e);
      this.currentNu = nu;
      double[] pos = orbitalToCartesian(a, e, i, omega, w, nu);
      px = pos[0]; py = pos[1]; pz = pos[2];

      if (parentBody != null) {
        px += parentBody.px;
        py += parentBody.py;
      }
    }

    double simDays = t / DAY_S;
    double totalRotations = simDays / rotationPeriodDays;
    double rotationRad = initialRotation + totalRotations * TWO_PI;
    rotation = (float)(rotationRad % TWO_PI);
    if (rotation < 0) rotation += TWO_PI;
  }

  void draw(CameraController cam, boolean drawLabels) {
    double[] sp = cam.worldToScreen(px, py);
    double screenR = radius * cam.scale;

    if (Double.isNaN(screenR) || Double.isInfinite(screenR)) return;

    double cx = sp[0], cy = sp[1];

    if (cx + screenR < -10 || cx - screenR > width + 10 || cy + screenR < -10 || cy - screenR > height + 10) return;

    double farCornerSq = 0;
    farCornerSq = Math.max(farCornerSq, cx*cx + cy*cy);
    farCornerSq = Math.max(farCornerSq, (cx-width)*(cx-width) + cy*cy);
    farCornerSq = Math.max(farCornerSq, cx*cx + (cy-height)*(cy-height));
    farCornerSq = Math.max(farCornerSq, (cx-width)*(cx-width) + (cy-height)*(cy-height));
    boolean coversScreen = farCornerSq <= screenR * screenR;

    noStroke();

    double drawR = screenR;
    if (drawR < 2) drawR = 2;

    if (renderer != null) {
      if (coversScreen) {
        renderer.drawLOD4(this, cx, cy, screenR, cam);
      } else if (drawR > width * 0.5 || drawR > height * 0.5) {
        renderer.drawScanlineLOD(this, cx, cy, screenR, cam);
      } else if (drawR < 20) {
        renderer.drawLOD0(this, cx, cy, drawR, cam);
      } else if (drawR < 80) {
        renderer.drawLOD1(this, cx, cy, drawR, cam);
      } else if (drawR < 250) {
        renderer.drawLOD2(this, cx, cy, drawR, cam);
      } else {
        renderer.drawLOD3(this, cx, cy, drawR, cam);
      }
    } else {
      if (coversScreen) {
        fill(col);
        rect(0, 0, width, height);
      } else {
        drawGroundScanline(cx, cy, screenR);
      }
    }

    // Labels now handled by LabelManager - removed direct drawing
  }

  void drawGroundScanline(double cx, double cy, double r) {
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

  double getGravityAtAltitude(double altitude) {
    double r = radius + altitude;
    return GM / (r * r);
  }
}
