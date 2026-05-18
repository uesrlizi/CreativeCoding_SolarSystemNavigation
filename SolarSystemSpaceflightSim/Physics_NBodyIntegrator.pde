// ============================================================
//  Physics_NBodyIntegrator - 数值积分器
//  实现RK4积分方法，用于off-rails物理模式
// ============================================================

class NBodyIntegrator {
  static final double FIXED_SUBSTEP = 1.0;
  static final int MAX_SUBSTEPS = 10000;

  boolean crashed = false;

  // ============================================================
  //  RK4积分器
  //  返回执行的子步数
  // ============================================================

  int integrateRK4(Vector2 pos, Vector2 vel, double dt, ForceModel forceModel) {
    if (dt <= 0) return 0;

    double remainingDt = dt;
    int steps = 0;

    Vector2 k1v = new Vector2();
    Vector2 k1x = new Vector2();
    Vector2 k2v = new Vector2();
    Vector2 k2x = new Vector2();
    Vector2 k3v = new Vector2();
    Vector2 k3x = new Vector2();
    Vector2 k4v = new Vector2();
    Vector2 k4x = new Vector2();
    Vector2 tempPos = new Vector2();
    Vector2 tempVel = new Vector2();
    Vector2 accel = new Vector2();

    while (remainingDt > 0 && steps < MAX_SUBSTEPS && !crashed) {
      double step = Math.min(remainingDt, FIXED_SUBSTEP);
      double halfStep = step / 2.0;

      // k1 = f(t, y)
      tempPos.set(pos);
      tempVel.set(vel);
      forceModel.computeForce(tempPos, tempVel, accel);
      k1v.set(accel);
      k1x.set(vel);

      // k2 = f(t + dt/2, y + k1*dt/2)
      tempPos.x = pos.x + k1x.x * halfStep;
      tempPos.y = pos.y + k1x.y * halfStep;
      tempVel.x = vel.x + k1v.x * halfStep;
      tempVel.y = vel.y + k1v.y * halfStep;
      forceModel.computeForce(tempPos, tempVel, accel);
      k2v.set(accel);
      k2x.set(tempVel);

      // k3 = f(t + dt/2, y + k2*dt/2)
      tempPos.x = pos.x + k2x.x * halfStep;
      tempPos.y = pos.y + k2x.y * halfStep;
      tempVel.x = vel.x + k2v.x * halfStep;
      tempVel.y = vel.y + k2v.y * halfStep;
      forceModel.computeForce(tempPos, tempVel, accel);
      k3v.set(accel);
      k3x.set(tempVel);

      // k4 = f(t + dt, y + k3*dt)
      tempPos.x = pos.x + k3x.x * step;
      tempPos.y = pos.y + k3x.y * step;
      tempVel.x = vel.x + k3v.x * step;
      tempVel.y = vel.y + k3v.y * step;
      forceModel.computeForce(tempPos, tempVel, accel);
      k4v.set(accel);
      k4x.set(tempVel);

      // y_new = y + (k1 + 2*k2 + 2*k3 + k4) * dt / 6
      pos.x += (k1x.x + 2*k2x.x + 2*k3x.x + k4x.x) * step / 6.0;
      pos.y += (k1x.y + 2*k2x.y + 2*k3x.y + k4x.y) * step / 6.0;
      vel.x += (k1v.x + 2*k2v.x + 2*k3v.x + k4v.x) * step / 6.0;
      vel.y += (k1v.y + 2*k2v.y + 2*k3v.y + k4v.y) * step / 6.0;

      // 检查碰撞
      double r = pos.magnitude();
      if (r < 0.5 * forceModel.bodyRadius()) {
        crashed = true;
        break;
      }

      remainingDt -= step;
      steps++;
    }

    return steps;
  }

  // ============================================================
  //  简化的欧拉积分（用于快速测试）
  // ============================================================

  int integrateEuler(Vector2 pos, Vector2 vel, double dt, ForceModel forceModel) {
    if (dt <= 0) return 0;

    double remainingDt = dt;
    int steps = 0;
    Vector2 accel = new Vector2();

    while (remainingDt > 0 && steps < MAX_SUBSTEPS && !crashed) {
      double step = Math.min(remainingDt, FIXED_SUBSTEP);

      forceModel.computeForce(pos, vel, accel);

      double r = pos.magnitude();
      if (r < 0.5 * forceModel.bodyRadius()) {
        crashed = true;
        break;
      }

      vel.x += accel.x * step;
      vel.y += accel.y * step;
      pos.x += vel.x * step;
      pos.y += vel.y * step;

      remainingDt -= step;
      steps++;
    }

    return steps;
  }

  // ============================================================
  //  重置碰撞标志
  // ============================================================

  void reset() {
    crashed = false;
  }
}
