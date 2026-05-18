// ========== SOLAR SYSTEM ==========

class SolarSystem {
  CelestialBody sun;
  List<CelestialBody> planets;
  List<CelestialBody> moons;
  List<Spacecraft> ships;      // 航天器列表
  CelestialBodyRenderer renderer;

  SolarSystem() {
    planets = new ArrayList<CelestialBody>();
    moons = new ArrayList<CelestialBody>();
    ships = new ArrayList<Spacecraft>();
    renderer = new CelestialBodyRenderer();
  }

  void initialize() {
    initSolarSystem();
  }

  void initSolarSystem() {
    sun = new CelestialBody("Sun", 0, 0, 696340, color(255, 230, 80), BodyType.SUN);
    sun.setRenderer(renderer);
    sun.rotationPeriodDays = 27.0f;
    sun.setGM(GM_SUN);

    CelestialBody mercury = new CelestialBody("Mercury", 0.38710, 0.20563, 7.005, 48.331, 29.124, 174.796, 87.969, 2439.7, color(180, 160, 140), BodyType.TERRESTRIAL);
    mercury.setRenderer(renderer);
    mercury.hasAtmosphere = true;
    mercury.atmosphereColor = color(200, 180, 160);
    mercury.atmosphere.hasAtmosphere = true;
    mercury.atmosphere.atmosphereColor = color(200, 180, 160);
    mercury.rotationPeriodDays = 58.6f;
    mercury.axialTilt = radians(0.03f);
    mercury.setGM(2.2032e4);
    mercury.setParentBody(sun);
    planets.add(mercury);

    CelestialBody venus = new CelestialBody("Venus", 0.72333, 0.00677, 3.395, 76.680, 54.884, 50.115, 224.701, 6051.8, color(230, 200, 130), BodyType.TERRESTRIAL);
    venus.setRenderer(renderer);
    venus.hasAtmosphere = true;
    venus.atmosphereColor = color(255, 220, 180);
    venus.atmosphere.hasAtmosphere = true;
    venus.atmosphere.atmosphereColor = color(255, 220, 180);
    venus.rotationPeriodDays = -243.0f;
    venus.axialTilt = radians(177.4f);
    venus.setGM(3.2486e5);
    venus.setParentBody(sun);
    planets.add(venus);

    CelestialBody earth = new CelestialBody("Earth", 1.00000, 0.01671, 0.000, 348.739, 114.208, 357.517, 365.256, 6371.0, color(70, 130, 230), BodyType.TERRESTRIAL);
    earth.setRenderer(renderer);
    earth.hasAtmosphere = true;
    earth.atmosphereColor = color(100, 180, 255);
    earth.atmosphere.hasAtmosphere = true;
    earth.atmosphere.atmosphereColor = color(100, 180, 255);
    earth.rotationPeriodDays = 1.0f;
    earth.axialTilt = radians(23.4f);
    earth.setGM(GM_EARTH);
    earth.setParentBody(sun);
    planets.add(earth);

    CelestialBody moon = new CelestialBody("Moon", 0.00257, 0.05490, 5.145, 125.080, 318.063, 135.270, 27.3217, 1737.4, color(200, 200, 210), BodyType.TERRESTRIAL);
    moon.setRenderer(renderer);
    moon.rotationPeriodDays = 27.3217f;
    moon.axialTilt = radians(6.68f);
    moon.setGM(4.90486e3);
    moon.setParentBody(earth);
    moons.add(moon);

    CelestialBody mars = new CelestialBody("Mars", 1.52368, 0.09341, 1.850, 49.558, 286.502, 19.373, 686.980, 3389.5, color(210, 100, 60), BodyType.TERRESTRIAL);
    mars.setRenderer(renderer);
    mars.hasAtmosphere = true;
    mars.atmosphereColor = color(255, 200, 180);
    mars.atmosphere.hasAtmosphere = true;
    mars.atmosphere.atmosphereColor = color(255, 200, 180);
    mars.rotationPeriodDays = 1.027f;
    mars.axialTilt = radians(25.2f);
    mars.setGM(4.2828e4);
    mars.setParentBody(sun);
    planets.add(mars);

    CelestialBody jupiter = new CelestialBody("Jupiter", 5.20260, 0.04839, 1.303, 100.464, 273.867, 20.020, 4332.589, 69911.0, color(210, 180, 140), BodyType.GAS_GIANT);
    jupiter.setRenderer(renderer);
    jupiter.rotationPeriodDays = 0.41f;
    jupiter.axialTilt = radians(3.1f);
    jupiter.setGM(1.26687e8);
    jupiter.setParentBody(sun);
    planets.add(jupiter);

    CelestialBody saturn = new CelestialBody("Saturn", 9.55491, 0.05415, 2.489, 113.664, 339.392, 317.020, 10759.22, 58232.0, color(220, 200, 150), BodyType.GAS_GIANT);
    saturn.setRenderer(renderer);
    saturn.hasRing = true;
    saturn.ringInnerRadius = 1.4f;
    saturn.ringOuterRadius = 2.5f;
    saturn.ringTilt = radians(26.7f);
    saturn.rotationPeriodDays = 0.45f;
    saturn.axialTilt = radians(26.7f);
    saturn.setGM(3.79312e7);
    saturn.setParentBody(sun);
    planets.add(saturn);

    CelestialBody uranus = new CelestialBody("Uranus", 19.21845, 0.04717, 0.773, 74.006, 96.998, 142.238, 30688.50, 25362.0, color(170, 220, 230), BodyType.ICE_GIANT);
    uranus.setRenderer(renderer);
    uranus.hasRing = true;
    uranus.ringInnerRadius = 1.5f;
    uranus.ringOuterRadius = 1.9f;
    uranus.ringTilt = radians(97.8f);
    uranus.ringColor = color(100, 120, 130, 100);
    uranus.rotationPeriodDays = -0.72f;
    uranus.axialTilt = radians(97.8f);
    uranus.setGM(5.79395e6);
    uranus.setParentBody(sun);
    planets.add(uranus);

    CelestialBody neptune = new CelestialBody("Neptune", 30.11039, 0.00859, 1.770, 131.784, 276.336, 256.228, 60182.00, 24622.0, color(60, 100, 230), BodyType.ICE_GIANT);
    neptune.setRenderer(renderer);
    neptune.rotationPeriodDays = 0.67f;
    neptune.axialTilt = radians(28.3f);
    neptune.setGM(6.83653e6);
    neptune.setParentBody(sun);
    planets.add(neptune);
  }

  List<CelestialBody> getAllBodies() {
    List<CelestialBody> all = new ArrayList<CelestialBody>();
    all.add(sun);
    all.addAll(planets);
    all.addAll(moons);
    return all;
  }

  CelestialBody getEarth() {
    for (CelestialBody p : planets) {
      if (p.name.equals("Earth")) return p;
    }
    return null;
  }

  void update(double t) {
    sun.update(t);
    for (CelestialBody p : planets) {
      p.update(t);
    }
    for (CelestialBody moon : moons) {
      moon.update(t);
    }
  }

  void drawSun(CameraController cam) {
    double[] sp = cam.worldToScreen(0, 0);
    double sx = sp[0], sy = sp[1];
    double sR = sun.radius * cam.scale;

    if (Double.isNaN(sR) || Double.isInfinite(sR)) return;

    if (sx + sR < -10 || sx - sR > width + 10 || sy + sR < -10 || sy - sR > height + 10) return;

    double corner1 = sx*sx + sy*sy;
    double corner2 = (sx-width)*(sx-width) + sy*sy;
    double corner3 = sx*sx + (sy-height)*(sy-height);
    double corner4 = (sx-width)*(sx-width) + (sy-height)*(sy-height);
    double farCornerSq = Math.max(Math.max(corner1, corner2), Math.max(corner3, corner4));

    noStroke();

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
    }
  }

  void updateRenderer(float dt) {
    renderer.update(dt);
  }

  void drawPlanets(CameraController cam) {
    for (CelestialBody p : planets) {
      p.draw(cam);
    }
    for (CelestialBody moon : moons) {
      moon.draw(cam);
    }
  }
}
