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
  double thrust_kN;   // 真空推力（kN）
  double mass_tons;   // 引擎干质量（吨）
  double isp_vac;     // 真空比冲（秒）
  double isp_sl;      // 海平面比冲（秒）
  boolean isIgnited;  // 是否已点火
  float currentThrottle;  // 当前油门

  SimpleEngine(double thrust, double mass) {
    this.thrust_kN = thrust;
    this.mass_tons = mass;
    this.isp_vac = 320;    // 默认320秒（液体燃料引擎）
    this.isp_sl = 280;     // 默认280秒
    this.isIgnited = false;
    this.currentThrottle = 0;
  }

  SimpleEngine(double thrust, double mass, double ispVac, double ispSl) {
    this.thrust_kN = thrust;
    this.mass_tons = mass;
    this.isp_vac = ispVac;
    this.isp_sl = ispSl;
    this.isIgnited = false;
    this.currentThrottle = 0;
  }

  double getCurrentThrust() {
    return thrust_kN * currentThrottle;
  }

  double getThrust(float throttle) {
    return thrust_kN * constrainDouble(throttle, 0, 1);
  }

  void setThrottle(float throttle) {
    this.currentThrottle = (float)constrainDouble(throttle, 0, 1);
    this.isIgnited = this.currentThrottle > 0.01f;
  }

  double getAcceleration(double shipMassTons, float throttle) {
    double thrust_N = getThrust(throttle) * 1000;  // kN 转 N
    double mass_kg = shipMassTons * 1000;         // 吨转千克
    double accel_m_s2 = thrust_N / mass_kg;
    return accel_m_s2 / 1000;  // 转 km/s²
  }

  void ignite() {
    this.isIgnited = true;
  }

  void shutdown() {
    this.isIgnited = false;
    this.currentThrottle = 0;
  }
}

// ========== AUTO CONTROL ==========
class AutoControl {
  boolean isActive;
  boolean hasTargetDirection;
  Vector2 targetDirection;
  float targetThrottle;

  boolean isOrienting;        // 是否正在调整朝向
  boolean isBurning;          // 是否正在点火
  double orientationError;    // 当前朝向误差（弧度）
  double burnTimeRemaining;   // 剩余点火时间（秒）

  AutoControl() {
    this.isActive = false;
    this.hasTargetDirection = false;
    this.targetDirection = new Vector2(1, 0);
    this.targetThrottle = 0;
    this.isOrienting = false;
    this.isBurning = false;
    this.orientationError = 0;
    this.burnTimeRemaining = 0;
  }

  void update(Spacecraft craft, double dt) {
    if (!isActive) return;

    if (hasTargetDirection) {
      Vector2 currentDir = craft.attitude.getForward();
      double targetAngle = targetDirection.angle();
      double currentAngle = currentDir.angle();
      orientationError = angleDifference(targetAngle, currentAngle);
      isOrienting = Math.abs(orientationError) > 0.01 || Math.abs(craft.angularVelocity) > 0.01;
    } else {
      isOrienting = false;
    }

    isBurning = targetThrottle > 0.01f;

    if (isBurning && burnTimeRemaining > 0) {
      burnTimeRemaining -= dt;
      if (burnTimeRemaining <= 0) {
        burnTimeRemaining = 0;
        targetThrottle = 0;
        isBurning = false;
      }
    }
  }

  void setTargetDirection(Vector2 dir) {
    if (dir.magnitudeSq() > 0.0001) {
      this.targetDirection = dir.normalized();
      this.hasTargetDirection = true;
      this.isOrienting = true;
    }
  }

  void setBurn(float throttle, double durationSeconds) {
    this.targetThrottle = throttle;
    this.burnTimeRemaining = durationSeconds;
    this.isBurning = throttle > 0.01f;
  }

  boolean isOriented() {
    return !hasTargetDirection || !isOrienting;
  }

  void stop() {
    this.targetThrottle = 0;
    this.hasTargetDirection = false;
    this.isOrienting = false;
    this.isBurning = false;
    this.burnTimeRemaining = 0;
  }

  private double angleDifference(double target, double current) {
    double diff = ((target - current + 3 * Math.PI) % (2 * Math.PI)) - Math.PI;
    return diff;
  }
}
