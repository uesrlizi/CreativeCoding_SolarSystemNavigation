// ========== LAUNCH SITE ==========
// 表示地球表面的发射场位置

class LaunchSite {
  CelestialBody earthRef;
  double baseAngle;     // 固定角度（弧度），相对于地球中心
  double px, py;        // 世界坐标（km）

  LaunchSite(CelestialBody earthRef, double baseAngle) {
    this.earthRef = earthRef;
    this.baseAngle = baseAngle;
    update();
  }

  void update() {
    double r = EARTH_RADIUS_KM;
    px = earthRef.px + r * Math.cos(baseAngle);
    py = earthRef.py + r * Math.sin(baseAngle);
  }

  // 获取发射方向（垂直向上，即径向向外）
  Vector2 getLaunchDirection() {
    return new Vector2(Math.cos(baseAngle), Math.sin(baseAngle));
  }

  // 获取发射场的旋转角度（用于渲染）
  double getRenderAngle() {
    return baseAngle;
  }
}
