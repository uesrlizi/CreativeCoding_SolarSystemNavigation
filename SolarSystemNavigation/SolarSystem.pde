class SolarSystem {
  CelestialBody sun;
  List<CelestialBody> planets;
  List<Spacecraft> ships;
  CelestialBodyRenderer renderer;

  SolarSystem() {
    planets = new ArrayList<CelestialBody>();
    ships = new ArrayList<Spacecraft>();
    renderer = new CelestialBodyRenderer();
  }

  void initialize() {
    initSolarSystem();
  }

  void initSolarSystem() {
    sun = new CelestialBody("Sun", 0, 0, 696340, GM_SUN, color(255, 230, 80), BodyType.SUN);
    sun.setRenderer(renderer);
    sun.rotationPeriodDays = 27.0f;

    CelestialBody mercury = new CelestialBody("Mercury",  0.38710, 0.20563,  7.005,  48.331,  29.124, 174.796,    87.969,  2439.7, 2.2032e4, color(180, 160, 140), BodyType.TERRESTRIAL);
    mercury.setRenderer(renderer);
    mercury.rotationPeriodDays = 58.6f;
    mercury.axialTilt = radians(0.03f);
    mercury.parent = sun;
    planets.add(mercury);

    CelestialBody venus = new CelestialBody("Venus",    0.72333, 0.00677,  3.395,  76.680,  54.884,  50.115,   224.701,  6051.8, 3.2486e5, color(230, 200, 130), BodyType.TERRESTRIAL);
    venus.setRenderer(renderer);
    venus.hasAtmosphere = true;
    venus.atmosphereColor = color(255, 220, 180);
    venus.rotationPeriodDays = -243.0f; // negative = retrograde
    venus.axialTilt = radians(177.4f);
    venus.parent = sun;
    planets.add(venus);

    CelestialBody earth = new CelestialBody("Earth",    1.00000, 0.01671,  0.000, 348.739, 114.208, 357.517,   365.256,  6371.0, 3.986004e5, color(70, 130, 230), BodyType.TERRESTRIAL);
    earth.setRenderer(renderer);
    earth.hasAtmosphere = true;
    earth.atmosphereColor = color(100, 180, 255);
    earth.rotationPeriodDays = 1.0f;
    earth.axialTilt = radians(23.4f);
    earth.parent = sun;
    planets.add(earth);

    CelestialBody mars = new CelestialBody("Mars",     1.52368, 0.09341,  1.850,  49.558, 286.502,  19.373,   686.980,  3389.5, 4.2828e4, color(210, 100, 60), BodyType.TERRESTRIAL);
    mars.setRenderer(renderer);
    mars.hasAtmosphere = true;
    mars.atmosphereColor = color(255, 200, 180);
    mars.rotationPeriodDays = 1.027f;
    mars.axialTilt = radians(25.2f);
    mars.parent = sun;
    planets.add(mars);

    CelestialBody jupiter = new CelestialBody("Jupiter",  5.20260, 0.04839,  1.303, 100.464, 273.867,  20.020,  4332.589, 69911.0, 1.26687e8, color(210, 180, 140), BodyType.GAS_GIANT);
    jupiter.setRenderer(renderer);
    jupiter.rotationPeriodDays = 0.41f;
    jupiter.axialTilt = radians(3.1f);
    jupiter.parent = sun;
    planets.add(jupiter);

    CelestialBody saturn = new CelestialBody("Saturn",   9.55491, 0.05415,  2.489, 113.665, 339.392, 317.020, 10759.22, 58232.0, 3.7931e7, color(220, 200, 150), BodyType.GAS_GIANT);
    saturn.setRenderer(renderer);
    saturn.hasRing = true;
    saturn.ringInnerRadius = 1.4f;
    saturn.ringOuterRadius = 2.5f;
    saturn.ringTilt = radians(26.7f);
    saturn.rotationPeriodDays = 0.45f;
    saturn.axialTilt = radians(26.7f);
    saturn.parent = sun;
    planets.add(saturn);

    CelestialBody uranus = new CelestialBody("Uranus",  19.21845, 0.04717,  0.773,  74.006,  96.998, 142.238, 30688.50, 25362.0, 5.7940e6, color(170, 220, 230), BodyType.ICE_GIANT);
    uranus.setRenderer(renderer);
    uranus.hasRing = true;
    uranus.ringInnerRadius = 1.5f;
    uranus.ringOuterRadius = 1.9f;
    uranus.ringTilt = radians(97.8f);
    uranus.rotationPeriodDays = -0.72f; // negative = retrograde
    uranus.axialTilt = radians(97.8f);
    uranus.parent = sun;
    planets.add(uranus);

    CelestialBody neptune = new CelestialBody("Neptune", 30.11039, 0.00859,  1.770, 131.784, 276.336, 256.228, 60182.00, 24622.0, 6.8365e6, color(60, 100, 230), BodyType.ICE_GIANT);
    neptune.setRenderer(renderer);
    neptune.rotationPeriodDays = 0.67f;
    neptune.axialTilt = radians(28.3f);
    neptune.parent = sun;
    planets.add(neptune);
  }

  // 查找主导给定点的天体（SOI检测）
  CelestialBody findDominantBody(double x, double y, double z) {
    // 先检查行星（从内到外）
    for (CelestialBody planet : planets) {
      if (planet.isInSOI(x, y, z)) {
        return planet;
      }
    }
    // 不在任何行星SOI内，返回太阳
    return sun;
  }

  void update(double t) {
    sun.update(t);
    for (CelestialBody p : planets) {
      p.update(t);
    }
  }

  void drawSun(CameraController cam) {
    double[] sp = cam.worldToScreen(0, 0);
    double sx = sp[0], sy = sp[1];
    double sR = sun.radius * cam.scale;

    if (Double.isNaN(sR) || Double.isInfinite(sR)) return;

    // Cull — use unclamped radius
    if (sx + sR < -10 || sx - sR > width + 10 ||
        sy + sR < -10 || sy - sR > height + 10) return;

    // LOD 4 — sun circle contains all four screen corners
    double farCornerSq = Math.max(
      Math.max(sx*sx + sy*sy, (sx-width)*(sx-width) + sy*sy),
      Math.max(sx*sx + (sy-height)*(sy-height), (sx-width)*(sx-width) + (sy-height)*(sy-height))
    );

    noStroke();

    // 完全按屏幕半径判定LOD
    double drawR = sR;
    if (drawR < 2) drawR = 2;

    if (renderer != null) {
      if (farCornerSq <= sR * sR) {
        renderer.drawLOD4(sun, sx, sy, sR);
      } else if (drawR > width * 0.5 || drawR > height * 0.5) {
        renderer.drawScanlineLOD(sun, sx, sy, sR);
      } else if (drawR < 20) {
        renderer.drawLOD0(sun, sx, sy, drawR);
      } else if (drawR < 80) {
        renderer.drawLOD1(sun, sx, sy, drawR);
      } else if (drawR < 250) {
        renderer.drawLOD2(sun, sx, sy, drawR);
      } else {
        renderer.drawLOD3(sun, sx, sy, drawR);
      }
    } else {
      if (farCornerSq <= sR * sR) {
        fill(sun.col);
        rect(0, 0, width, height);
      } else {
        fill(sun.col);
        ellipse((float)sx, (float)sy, (float)(sR * 2), (float)(sR * 2));
      }
    }

    if (showLabels) {
      fill(255, 230, 100, 220);
      textSize(18 * uiScale);
      textAlign(LEFT, CENTER);
      text("Sun", (float)(sx + drawR + 5), (float)sy);

      // LOD 级别提示
      String lodStr;
      if (farCornerSq <= sR * sR) lodStr = "LOD: 4";
      else if (drawR > width * 0.5 || drawR > height * 0.5) lodStr = "LOD: Scanline";
      else if (drawR < 20) lodStr = "LOD: 0";
      else if (drawR < 80) lodStr = "LOD: 1";
      else if (drawR < 250) lodStr = "LOD: 2";
      else lodStr = "LOD: 3";
      fill(80, 200, 120, 200);
      textSize(12 * uiScale);
      text(lodStr, (float)(sx + drawR + 5), (float)sy + 18 * uiScale);
    }
  }

  void updateRenderer(float dt) {
    renderer.update(dt);
  }

  void drawPlanets(CameraController cam) {
    for (CelestialBody p : planets) {
      p.draw(cam);
    }
  }
}
