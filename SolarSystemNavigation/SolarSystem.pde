class SolarSystem {
  CelestialBody sun;
  List<CelestialBody> planets;
  List<Spacecraft> ships;

  SolarSystem() {
    planets = new ArrayList<CelestialBody>();
    ships = new ArrayList<Spacecraft>();
  }

  void initialize() {
    initSolarSystem();
  }

  void initSolarSystem() {
    sun = new CelestialBody("Sun", 0, 0, 696340, 1.327e20, 0, color(255, 220, 50));

    planets.add(new CelestialBody("Mercury",  0.38710, 0.20563,  7.005,  48.331,  29.124, 174.796,    87.969,  2439.7, 3.7e13, 1.76e-7, color(180, 160, 140)));
    planets.add(new CelestialBody("Venus",    0.72333, 0.00677,  3.395,  76.680,  54.884,  50.115,   224.701,  6051.8, 4.87e14, -1.76e-7, color(230, 200, 130)));
    planets.add(new CelestialBody("Earth",   1.00000, 0.01671,  0.000, 348.739, 114.208, 357.517,   365.256,  6371.0, 3.986e14, 7.29e-5, color(70, 130, 230)));
    planets.add(new CelestialBody("Mars",    1.52368, 0.09341,  1.850,  49.558, 286.502,  19.373,   686.980,  3389.5, 4.28e13, 7.09e-5, color(210, 100, 60)));
    planets.add(new CelestialBody("Jupiter",  5.20260, 0.04839,  1.303, 100.464, 273.867,  20.020,  4332.589, 69911.0, 1.27e17, 1.76e-4, color(210, 180, 140)));
    planets.add(new CelestialBody("Saturn",   9.55491, 0.05415,  2.489, 113.665, 339.392, 317.020, 10759.22, 58232.0, 3.79e16, 1.63e-4, color(220, 200, 150)));
    planets.add(new CelestialBody("Uranus",  19.21845, 0.04717,  0.773,  74.006,  96.998, 142.238, 30688.50, 25362.0, 5.79e15, -1.01e-4, color(170, 220, 230)));
    planets.add(new CelestialBody("Neptune", 30.11039, 0.00859,  1.770, 131.784, 276.336, 256.228, 60182.00, 24622.0, 6.84e15, 1.01e-4, color(60, 100, 230)));
  }

  void update(double t) {
    for (CelestialBody p : planets) {
      p.update(t);
    }
  }

  void drawSun(CameraController cam) {
    double[] sp = cam.worldToScreen(0, 0);
    float sx = (float)sp[0], sy = (float)sp[1];

    fill(255, 230, 80);
    noStroke();
    float sunR = max((float)(sun.radius * cam.scale), 4);
    ellipse(sx, sy, sunR * 2, sunR * 2);

    if (showLabels) {
      fill(255, 230, 100, 220);
      textSize(18);
      textAlign(LEFT, CENTER);
      text("Sun", sx + sunR + 5, sy);
    }
  }

  void drawPlanets(CameraController cam) {
    for (CelestialBody p : planets) {
      p.draw(cam);
    }
  }
}
