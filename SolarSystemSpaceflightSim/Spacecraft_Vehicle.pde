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

  // === 发射状态 ===
  LaunchState launchState;
  boolean isFixedToSurface;       // 是否固定在表面（发射场）
  double countdownStartTime;      // 倒计时开始时间
  double ignitionStartTime;       // 点火开始时间
  double launchStartTime;         // 发射开始时间

  // === 常量 ===
  static final double COUNTDOWN_DURATION = 3.0;   // 倒计时3秒
  static final double IGNITION_DURATION = 1.0;    // 点火1秒

  // === 参考系 ===
  CelestialBody referenceBody;

  // === 姿态 ===
  Rotation2D attitude;
  double angularVelocity;
  double angularAcceleration;
  // PD控制参数（仅用于显示平滑）
  static final double ANGLE_KP = 10.0;
  static final double ANGLE_KD = 6.0;

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

    // 发射相关初始化
    this.launchState = LaunchState.ON_PAD;
    this.isFixedToSurface = false;
    this.countdownStartTime = 0;
    this.ignitionStartTime = 0;
    this.launchStartTime = 0;

    this.referenceBody = null;

    this.attitude = new Rotation2D(0);
    this.angularVelocity = 0;
    this.angularAcceleration = 0;

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

  // === 初始化为发射场状态 ===
  void initOnLaunchPad(CelestialBody earth, LaunchSite site) {
    this.referenceBody = earth;
    this.physicsMode = PhysicsMode.OFF_RAILS;
    this.launchState = LaunchState.ON_PAD;
    this.isFixedToSurface = true;

    // 使用 baseAngle 计算相对地球中心的位置，不依赖 site.px/py（它们可能过期）
    double r = EARTH_RADIUS_KM;
    double angle = site.baseAngle;
    this.stateVector.position = new Vector2(r * Math.cos(angle), r * Math.sin(angle));
    this.stateVector.velocity = new Vector2(0, 0);

    // 设置姿态为径向向外（垂直向上）
    this.attitude = new Rotation2D(angle);

    // 从当前地球位置计算世界坐标
    this.worldX = earth.px + this.stateVector.position.x;
    this.worldY = earth.py + this.stateVector.position.y;
    this.worldVelX = 0;
    this.worldVelY = 0;

    // 清空轨道
    this.orbit = null;
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
  void updateOffRails(double simDt) {
    // 这里可以添加一些轻量级的更新逻辑
    // 主要的物理更新在PhysicsSystem.update中处理

    // 更新自动控制 (Stage 5)
    if (autoControl.isActive) {
      autoControl.update(this, simDt);
    }

    // 更新引擎油门 (Stage 5)
    if (mainEngine != null && autoControl.isActive) {
      mainEngine.setThrottle(autoControl.targetThrottle);
    }
  }

  // === 质量获取 ===
  double getCurrentMass() {
    double mass = this.dryMass;
    if (this.mainEngine != null) {
      mass += this.mainEngine.mass_tons;
    }
    return mass;
  }

  // === 模式切换 ===
  void enterOnRails() {
    this.physicsMode = PhysicsMode.ON_RAILS;

    // 如果正在任务执行中，从状态向量重新计算轨道
    if (this.referenceBody != null) {
      this.orbit = Orbit_fromStateVector(this.stateVector.position, this.stateVector.velocity, this.referenceBody, lastUpdateTime);
    }
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
    this.autoControl.setTargetDirection(direction);
  }

  void setEngineThrottle(float throttle) {
    if (mainEngine != null) {
      mainEngine.setThrottle(throttle);
    }
    this.autoControl.targetThrottle = throttle;
    // 如果开启推力且没有目标方向，自动指向速度方向
    if (throttle > 0.01f && !this.autoControl.hasTargetDirection) {
      Vector2 prograde = getPrograde();
      if (prograde.magnitude() > 0.001) {
        this.autoControl.setTargetDirection(prograde);
      }
    }
  }
}
