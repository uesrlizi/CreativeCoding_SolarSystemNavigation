// ============================================================
//  ReferenceFrame — marks which gravitational body dominates
//  the spacecraft's motion and how coordinates are interpreted.
//  Analogous to KSP's reference frame tree.
// ============================================================

class ReferenceFrame {
  FrameType type;
  CelestialBody primaryBody;

  ReferenceFrame(FrameType type, CelestialBody primaryBody) {
    this.type = type;
    this.primaryBody = primaryBody;
  }

  // GM of the dominant body (km^3/s^2)
  double gm() {
    if (primaryBody != null && primaryBody.a == 0) {
      return GM_SUN;
    }
    if (primaryBody == null) return GM_SUN;
    // Planetary GM lookup — currently only Earth matters for body-relative frames
    if (primaryBody.name.equals("Earth"))  return MissionPlanner.GM_EARTH;
    if (primaryBody.name.equals("Mars"))   return MissionPlanner.GM_MARS;
    if (primaryBody.name.equals("Venus"))  return MissionPlanner.GM_VENUS;
    if (primaryBody.name.equals("Mercury")) return MissionPlanner.GM_MERCURY;
    if (primaryBody.name.equals("Jupiter")) return MissionPlanner.GM_JUPITER;
    return MissionPlanner.GM_EARTH; // fallback
  }

  // Radius of the primary body (km)
  double bodyRadius() {
    if (primaryBody == null) return 0;
    return primaryBody.radius;
  }

  // Altitude above the primary's surface (km)
  double altitude(double[] relPos) {
    double r = Math.sqrt(relPos[0] * relPos[0] + relPos[1] * relPos[1]);
    return r - bodyRadius();
  }
}
