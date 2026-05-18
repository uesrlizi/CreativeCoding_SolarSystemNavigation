// ========== SPACECRAFT ==========
class Spacecraft {
  // === 基础信息 ===
  String name;
  int id;
  String presetId;
  color col;

  // === 物理状态 ===
  PhysicsMode physicsMode;
  SpacecraftState state;
  Orbit orbit;                    // On-rails用
  StateVector2D stateVector;      // Off-rails用

  // === 参考系 ===
  CelestialBody referenceBody;

  // === 姿态 ===
  Rotation2D attitude;
  double angularVelocity;

  // === 引擎 ===
  SimpleEngine mainEngine;
  double dryMass;  // 干质量（吨）

  // === 自动控制 ===
  AutoControl autoControl;

  // === 缓存的世界位置 ===
  double worldX, worldY;

  // === 上次更新时间 ===
  double lastUpdateTime;

  // === 常量 ===
  static final double SHIP_LENGTH_KM = 0.08;
  static final double MAX_ANGULAR_VELOCITY = 3.0;
  static final double MAX_ANGULAR_ACCEL = 8.0;

  // === 构造函数 ===
  Spacecraft(String name, color col) {
    this.name = name;
    this.col = col;
    this.id = -1;
    this.presetId = null;

    this.physicsMode = PhysicsMode.ON_RAILS;
    this.state = SpacecraftState.ACTIVE;
    this.orbit = null;
    this.stateVector = new StateVector2D();

    this.referenceBody = null;

    this.attitude = new Rotation2D(0);
    this.angularVelocity = 0;

    this.mainEngine = null;
    this.dryMass = 2.0;  // 默认2吨

    this.autoControl = new AutoControl();

    this.worldX = 0;
    this.worldY = 0;
    this.lastUpdateTime = 0;
  }

  // === 初始化LEO轨道 ===
  void initLEO(CelestialBody earth) {
    this.referenceBody = earth;

    double a = LEO_RADIUS_KM;
    double e = 0.001;
    double w = 0.0;
    double M0 = 0.0;
    double period = 2 * PI * Math.sqrt(a * a * a / GM_EARTH);

    this.orbit = new Orbit(a, e, w, M0, period, earth);

    // 初始化stateVector
    updateOnRails(0);
  }

  // === On-rails更新 ===
  void updateOnRails(double simTime) {
    if (this.orbit != null && this.referenceBody != null) {
      Vector2 p = this.orbit.getPositionAtTime(simTime);
      Vector2 v = this.orbit.getVelocityAtTime(simTime);

      this.stateVector.position = p;
      this.stateVector.velocity = v;

      // 沿速度方向
      this.attitude = Rotation2D_fromDirection(v);

      // 计算世界位置
      this.worldX = this.referenceBody.px + p.x;
      this.worldY = this.referenceBody.py + p.y;
    }
  }

  // === Off-rails更新（阶段4占位）===
  void updateOffRails(double dt) {
    // 阶段4实现：数值积分物理模拟
    // 包括：引力计算、推力应用、碰撞检测
    // 占位，暂不实现
  }

  // === 质量获取 ===
  double getCurrentMass() {
    double mass = this.dryMass;
    if (this.mainEngine != null) {
      mass += this.mainEngine.mass;
    }
    return mass;
  }

  // === 模式切换（占位）===
  void enterOnRails() {
    this.physicsMode = PhysicsMode.ON_RAILS;
  }

  void enterOffRails() {
    this.physicsMode = PhysicsMode.OFF_RAILS;
  }

  // === 轨道坐标系方向 ===
  Vector2 getPrograde() {
    return this.stateVector.velocity.normalized();
  }

  Vector2 getRetrograde() {
    return getPrograde().mul(-1);
  }

  Vector2 getRadialOut() {
    return this.stateVector.position.normalized();
  }

  Vector2 getRadialIn() {
    return getRadialOut().mul(-1);
  }

  // === 自动控制 ===
  void setAutoTargetDirection(Vector2 direction) {
    this.autoControl.targetDirection = direction.clone();
    this.autoControl.hasTargetDirection = true;
  }

  void setEngineThrottle(float throttle) {
    this.autoControl.targetThrottle = throttle;
  }
}
