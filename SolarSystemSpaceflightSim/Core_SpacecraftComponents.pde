// ========== STATE VECTOR 2D ==========
class StateVector2D {
  Vector2 position;
  Vector2 velocity;

  StateVector2D() {
    this.position = new Vector2(0, 0);
    this.velocity = new Vector2(0, 0);
  }

  StateVector2D(Vector2 pos, Vector2 vel) {
    this.position = pos.clone();
    this.velocity = vel.clone();
  }
}

// ========== SIMPLE ENGINE ==========
class SimpleEngine {
  double thrust;   // 真空推力（kN）
  double mass;     // 引擎干质量（吨）

  SimpleEngine(double thrust, double mass) {
    this.thrust = thrust;
    this.mass = mass;
  }

  double getCurrentThrust() {
    return thrust;
  }
}

// ========== AUTO CONTROL ==========
class AutoControl {
  boolean isActive;
  boolean hasTargetDirection;
  Vector2 targetDirection;
  float targetThrottle;

  AutoControl() {
    this.isActive = false;
    this.hasTargetDirection = false;
    this.targetDirection = new Vector2(1, 0);
    this.targetThrottle = 0;
  }

  void update(Spacecraft craft, double dt) {
    // 阶段5实现：自动机动控制
    // 包括：姿态调整、引擎节流、机动执行
    // 占位，暂不实现
  }
}
