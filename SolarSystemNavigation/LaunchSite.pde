class LaunchSite {
  CelestialBody earthRef;
  double baseAngle;     // fixed angle on Earth surface (radians)
  double px, py;        // world coordinates (km)

  LaunchSite(CelestialBody earthRef, double baseAngle) {
    this.earthRef = earthRef;
    this.baseAngle = baseAngle;
    update();
  }

  void update() {
    double r = MissionPlanner.EARTH_RADIUS_KM;
    px = earthRef.px + r * Math.cos(baseAngle);
    py = earthRef.py + r * Math.sin(baseAngle);
  }
}
