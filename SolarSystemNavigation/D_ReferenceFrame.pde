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
    if (primaryBody != null) {
      return primaryBody.GM;
    }
    return GM_SUN;
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

  // 检查是否应该切换到另一个参考系
  // 返回新的主导天体，如果不需要切换则返回null
  CelestialBody checkSOISwitch(double worldX, double worldY, double worldZ) {
    if (primaryBody == null) {
      // 当前是日心参考系，检查是否进入了某个行星的SOI
      for (CelestialBody planet : solarSystem.planets) {
        if (planet.isInSOI(worldX, worldY, worldZ)) {
          return planet;
        }
      }
      return null;
    } else {
      // 当前是行星参考系，检查是否离开了SOI
      if (!primaryBody.isInSOI(worldX, worldY, worldZ)) {
        // 离开SOI，返回父天体（通常是太阳）
        return primaryBody.parent;
      }
      // 同时检查是否进入了其他天体的SOI（比如月球，但这里还没有月球）
      return null;
    }
  }
}
