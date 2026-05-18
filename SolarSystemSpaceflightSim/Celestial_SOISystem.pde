// ========== SOI SYSTEM ==========

class SOISystem {
  SolarSystem solarSystem;

  SOISystem(SolarSystem ss) {
    this.solarSystem = ss;
  }

  double calculateSOIRadius(CelestialBody body) {
    if (body.name.equals("Sun")) return AU_KM * 100;

    double GM_body = body.GM;
    double GM_primary = GM_SUN;
    double a = body.a;

    if (body.parentBody != null && body.parentBody != solarSystem.sun) {
      GM_primary = body.parentBody.GM;
    }

    if (GM_primary <= 0 || a <= 0) return 500000.0;

    double massRatio = GM_body / GM_primary;
    return a * Math.pow(massRatio, 2.0/5.0);
  }

  int getSOIColor(CelestialBody body) {
    if (body.name.equals("Earth")) return color(70, 130, 230, 80);
    if (body.name.equals("Moon")) return color(200, 200, 210, 80);
    if (body.name.equals("Mars")) return color(210, 100, 60, 80);
    if (body.name.equals("Venus")) return color(230, 200, 130, 80);
    if (body.name.equals("Jupiter")) return color(210, 180, 140, 80);
    if (body.name.equals("Saturn")) return color(220, 200, 150, 80);
    if (body.name.equals("Uranus")) return color(170, 220, 230, 80);
    if (body.name.equals("Neptune")) return color(60, 100, 230, 80);
    return color(150, 150, 150, 80);
  }
}
