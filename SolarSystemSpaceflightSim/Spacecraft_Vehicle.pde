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
  double dragCoefficient;   // 阻力系数
  double crossSectionArea;  // 横截面积（m²）

  // === 自动控制 ===
  AutoControl autoControl;

  // === 缓存的世界位置 ===
  double worldX, worldY;
  double worldVelX, worldVelY;

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
    this.dragCoefficient = 0.5;  // 默认阻力系数
    this.crossSectionArea = 4.0;  // 默认横截面积

    this.autoControl = new AutoControl();

    this.worldX = 0;
    this.worldY = 0;
    this.worldVelX = 0;
    this.worldVelY = 0;
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

    this.orbit = new Orbit(a, e, w, M0, 0.0, period, earth);

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

      // 计算世界速度
      if (this.referenceBody.a > 0) {
        // 需要加上天体的速度
        double n = 2.0 * PI / this.referenceBody.period;
        double M = (this.referenceBody.M0 + n * simTime) % (2.0 * PI);
        if (M < 0) M += 2.0 * PI;
        double E = solveKepler(M, this.referenceBody.e);
        double nu = trueAnomaly(E, this.referenceBody.e);
        double r = this.referenceBody.a * (1 - this.referenceBody.e * this.referenceBody.e) / (1 + this.referenceBody.e * Math.cos(nu));
        double GM = GM_SUN;
        double h = Math.sqrt(GM * this.referenceBody.a * (1 - this.referenceBody.e * this.referenceBody.e));
        double v_r = (GM * this.referenceBody.e * Math.sin(nu)) / h;
        double v_t = h / r;
        double theta = this.referenceBody.w + nu;
        this.worldVelX = v.x + v_r * Math.cos(theta) - v_t * Math.sin(theta);
        this.worldVelY = v.y + v_r * Math.sin(theta) + v_t * Math.cos(theta);
      } else {
        this.worldVelX = v.x;
        this.worldVelY = v.y;
      }
    }
  }

  // === Off-rails更新 ===
  // 注意：实际物理更新由PhysicsSystem处理
  void updateOffRails(double dt) {
    // 这里可以添加一些轻量级的更新逻辑
    // 主要的物理更新在PhysicsSystem.update中处理
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
    // 如果开启推力且没有目标方向，自动指向速度方向
    if (throttle > 0.01f && !this.autoControl.hasTargetDirection) {
      Vector2 prograde = getPrograde();
      if (prograde.magnitude() > 0.001) {
        this.autoControl.targetDirection = prograde.clone();
        this.autoControl.hasTargetDirection = true;
      }
    }
  }
}
