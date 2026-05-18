# SolarSystemSpaceflightSim 目标架构文档

## 概述

类KSP太阳系航天模拟游戏的完整架构设计。核心是**真实物理模拟**与**可玩游戏性**的平衡。

**玩法特点**：
- 玩家从预设任务菜单选择任务
- 程序自动计算并执行机动（完全自动）
- 任务执行过程中玩家不可干预
- 预设航天器（不需要玩家配置）
- 燃料限制暂不考虑（任务能成才让选）

## 已确认的设计决策

### 核心功能
- **物理模拟**：完全KSP风格（On-rails + Off-rails双模式）
- **维度**：纯2D（第一版）
- **控制方式**：完全自动（程序执行机动，玩家选任务）
- **航天器模型**：第一版用质点模型，不实现部件系统，预设航天器
- **物理引擎**：全手写，不集成第三方库
- **大气模型**：Basic（指数大气模型，只计算密度用于阻力）
- **资源系统**：燃料暂不考虑（第一版）
- **架构设计**：预留扩展性，质点版可平滑过渡到完整版

### 实现优先级
1. 基础设施重构
2. 航天器质点版（预设）
3. 双模式物理系统
4. 任务系统 + 自动机动执行
5. 轨迹预测与UI
6. 存档系统

---

## 核心理念

### 1. 补丁圆锥法 (Patched Conics)
- SOI内：二体问题，中心天体引力
- SOI边界：航天器切换引力参考系
- 轨迹预测：分段圆锥拼接

### 2. 双物理模式
- **轨道模式 (On-rails)**：开普勒轨道解析解，时间warp稳定
- **物理模式 (Off-rails)**：数值积分，实时受力计算，用于机动和近地飞行

---

## 文件结构

### 第一版：自动任务（MVP）
```
SolarSystemSpaceflightSim/
├── TARGET_ARCHITECTURE.md          # 本文档
├── SolarSystemSpaceflightSim.pde   # 主程序入口（精简版）
│
├── Core_*.pde                      # 核心模块
│   ├── Core_Enums.pde              // 枚举定义
│   ├── Core_Constants.pde          // 物理常数
│   ├── Core_Math.pde               // 数学工具库（Vector2, Rotation2D）
│   ├── Core_OrbitalMath.pde        // 轨道数学库
│   ├── Core_CoordinateTransformer.pde // 坐标系统转换器
│   └── Core_EventSystem.pde        // 事件总线
│
├── Physics_*.pde                   // 物理系统
│   ├── Physics_PatchedConics.pde   // 补丁圆锥系统（含SOI检测/切换）
│   ├── Physics_NBodyIntegrator.pde // 数值积分器
│   ├── Physics_ForceSolver.pde     // 受力计算
│   └── Physics_Collision.pde       // 碰撞检测（统一碰撞检测逻辑）
│
├── Celestial_*.pde                 // 天体系统
│   ├── Celestial_Body.pde          // 天体数据类
│   ├── Celestial_Orbit.pde         // 轨道数据类
│   ├── Celestial_Atmosphere.pde    // 大气模型
│   ├── Celestial_SolarSystem.pde   // 太阳系容器
│   ├── Celestial_Renderer.pde      // 天体渲染器
│   └── Celestial_Ephemeris.pde     // 星历系统（位置缓存）
│
├── Spacecraft_*.pde                // 航天器系统（质点版，预设）
│   ├── Spacecraft_Vehicle.pde      // 飞行器本体（质点）
│   ├── Spacecraft_Engine.pde       // 引擎数据
│   ├── Spacecraft_Presets.pde      // 预设航天器定义
│   ├── Spacecraft_Trajectory.pde   // 轨迹预测
│   ├── Spacecraft_Maneuver.pde     // 机动节点系统
│   └── Spacecraft_Renderer.pde     // 航天器渲染器
│
├── Mission_*.pde                   // 任务系统（新增核心）
│   ├── Mission_Task.pde            // 任务基类
│   ├── Mission_Presets.pde         // 预设任务定义
│   ├── Mission_Planner.pde         // 任务规划（计算机动）
│   ├── Mission_Executor.pde        // 任务执行器（自动执行）
│   └── Mission_Validator.pde       // 任务验证器（检查能否完成）
│
├── Camera_*.pde                    // 摄像机系统
│   ├── Camera_Controller.pde       // 摄像机控制器
│   └── Camera_Modes.pde            // 摄像机模式
│
├── Time_*.pde                      // 时间系统
│   ├── Time_Manager.pde            // 时间管理器
│   ├── Time_WarpController.pde     // 智能时间warp
│   └── Time_Scheduler.pde          // 事件调度器
│
├── UI_*.pde                        // UI系统
│   ├── UI_HUD.pde                  // HUD主界面
│   ├── UI_TaskMenu.pde             // 任务菜单（预设任务选择）
│   ├── UI_HeadingIndicator.pde     // 航向指示器
│   ├── UI_OrbitDisplay.pde         // 轨道信息显示
│   └── UI_MissionStatus.pde        // 任务状态显示
│
├── Input_*.pde                     // 输入系统
│   └── Input_Processor.pde         // 输入处理（菜单点击等简单交互）
│
├── SaveLoad_*.pde                  // 存档系统
│   └── SaveLoad_Serializer.pde     // 序列化
│
└── Game_*.pde                      // 游戏逻辑
    ├── Game_Scene.pde              // 场景管理
    └── Game_StateManager.pde       // 游戏状态管理器
```

### 未来扩展：完整版（带部件系统）
```
（在以上基础上新增）
├── Spacecraft_Part.pde             # 部件基类
├── Spacecraft_Parts.pde            # 具体部件
├── Spacecraft_Stage.pde            # 分级系统
├── Spacecraft_ResourceFlow.pde     # 资源流动系统
├── UI_StagePanel.pde               # 分级面板
├── UI_ResourcePanel.pde            # 资源面板
└── ...
```

---

## 模块详解

### 1. 核心模块 (Core_*)

#### Core_Enums.pde
```java
// 物理模式
enum PhysicsMode {
  ON_RAILS,    // 轨道模式（开普勒解析）
  OFF_RAILS    // 物理模式（数值积分）
}

// 游戏状态
enum GameState {
  MAIN_MENU,
  FLIGHT,       // 飞行中
  MAP_VIEW,     // 地图视图
  BUILD,        // 建造（预留）
  PAUSED
}

// 航天器状态
enum SpacecraftState {
  ACTIVE,
  LANDED,       // 着陆在天体表面
  SPLASHED,     // 溅落
  DOCKED,       // 对接
  DESTROYED
}

// 机动执行状态
enum ManeuverState {
  WAITING,      // 等待机动时刻
  ORIENTING,    // 调整朝向
  BURNING,      // 点火中
  COMPLETED     // 机动完成
}
```

#### Core_CoordinateTransformer.pde - 坐标系统转换器（新增）
```java
class CoordinateTransformer {
  // 日心惯性系 → 中心天体惯性系
  Vector2 toBodyCentric(Vector2 heliocentricPos, CelestialBody body, double time);
  Vector2 toBodyCentricVelocity(Vector2 heliocentricVel, Vector2 heliocentricPos, CelestialBody body, double time);

  // 中心天体惯性系 → 日心惯性系
  Vector2 toHeliocentric(Vector2 bodyCentricPos, CelestialBody body, double time);
  Vector2 toHeliocentricVelocity(Vector2 bodyCentricVel, Vector2 bodyCentricPos, CelestialBody body, double time);

  // 中心天体惯性系 → 中心天体固定系
  Vector2 toBodyFixed(Vector2 bodyCentricPos, CelestialBody body, double time);

  // 中心天体固定系 → 中心天体惯性系
  Vector2 toBodyCentricFromFixed(Vector2 bodyFixedPos, CelestialBody body, double time);
}
```

#### Core_EventSystem.pde - 事件总线
```java
// 观察者模式，解耦模块通信
class EventSystem {
  Map<String, List<EventListener>> listeners;

  void subscribe(String event, EventListener callback);
  void emit(String event, Object data);
  void unsubscribe(String event, EventListener callback);
}

// 事件示例：
// - "soi_enter" { craft, body }
// - "soi_exit" { craft, oldBody, newBody }
// - "collision" { craft, body }
// - "maneuver_start" { craft, maneuver }
// - "maneuver_complete" { craft, maneuver }
```

---

### 2. 物理系统 (Physics_*)

#### Physics_PatchedConics.pde - 补丁圆锥系统（含SOI逻辑）
```java
class PatchedConicsSystem {
  // 判断航天器在哪个SOI内
  CelestialBody findCurrentSOI(Spacecraft craft, SolarSystem system);

  // SOI边界穿越检测
  SOITraversal predictSOITraversal(Spacecraft craft, double dtMax, SolarSystem system);

  // 切换参考系时的速度转换
  void transferSOI(Spacecraft craft, CelestialBody oldBody, CelestialBody newBody, double time);
}

class SOITraversal {
  boolean willTraverse;
  double timeToTraversal;      // 到穿越时刻的秒数
  CelestialBody exitBody;      // 离开的天体
  CelestialBody enterBody;     // 进入的天体
}
```

#### Physics_NBodyIntegrator.pde - 数值积分器（2D版本）
```java
class NBodyIntegrator {
  // 积分方法
  enum Integrator {
    EULER,          // 简单欧拉（快但精度差）
    VERLET,         // Verlet（适中）
    RUNGE_KUTTA_4   // RK4（精度高，计算量大）
  }

  // 单次积分步（Off-rails模式用）
  void integrate(Spacecraft craft, List<CelestialBody> bodies, double dt);

  // 状态向量：位置+速度（2D）
  StateVector2D getState(Spacecraft craft);
  void setState(Spacecraft craft, StateVector2D state);
}

class StateVector2D {
  Vector2 position;    // 位置 (km)
  Vector2 velocity;    // 速度 (km/s)
}
```

#### Physics_ForceSolver.pde - 受力计算（2D版本）
```java
class ForceSolver {
  // 计算合加速度
  Vector2 calculateTotalAcceleration(Spacecraft craft, List<CelestialBody> bodies);

  // 各分力
  Vector2 calculateGravity(Spacecraft craft, CelestialBody body);
  Vector2 calculateThrust(Spacecraft craft);
  Vector2 calculateDrag(Spacecraft craft, CelestialBody body);  // 大气阻力
}
```

#### Physics_Collision.pde - 碰撞检测（统一处理）
```java
class CollisionDetector {
  // 检测航天器是否与天体碰撞
  CollisionResult checkCollision(Spacecraft craft, CelestialBody body);

  // 预测近期碰撞
  CollisionPrediction predictCollision(Spacecraft craft, CelestialBody body, double dtMax);
}

class CollisionResult {
  boolean hasCollision;
  CelestialBody body;
  Vector2 collisionPoint;
  double collisionTime;
}

class CollisionPrediction {
  boolean willCollide;
  CelestialBody body;
  double timeToCollision;
}
```

---

### 3. 天体系统 (Celestial_*)

#### Celestial_Body.pde - 天体数据类（重构，2D版本）
```java
class CelestialBody {
  // 轨道数据
  Orbit orbit;  // 封装轨道根数，而不是散变量

  // 物理属性
  double radius;
  double GM;
  double mass;
  double soiRadius;

  // 大气模型（新增）
  Atmosphere atmosphere;

  // 表面数据（新增）
  List<SurfaceFeature> surfaceFeatures;
  double rotationPeriod;
  double axialTilt;

  // 卫星系统
  List<CelestialBody> moons;
  CelestialBody parent;

  // 获取t时刻位置（解析解，2D）
  Vector2 getPositionAtTime(double t);
  Vector2 getVelocityAtTime(double t);

  // 获取当地重力加速度
  double getGravityAtAltitude(double altitude);
}

class Orbit {
  // 2D轨道根数（不需要i, omega）
  double a, e, w, M0;            // 半长轴，偏心率，近心点幅角，初始平近点角
  double period;
  CelestialBody referenceBody;   // 中心天体

  // 核心方法
  Vector2 getPositionAtTime(double t);
  Vector2 getVelocityAtTime(double t);
  double getTrueAnomalyAtTime(double t);
  double getMeanAnomalyAtTime(double t);
  double getEccentricAnomalyAtTime(double t);

  // 轨道特性
  double getApoapsisRadius();
  double getPeriapsisRadius();
  double getApoapsisAltitude();
  double getPeriapsisAltitude();
  double getSpecificOrbitalEnergy();

  // 从状态向量创建轨道
  static Orbit fromStateVector(Vector2 pos, Vector2 vel, CelestialBody body, double t);
}

class Atmosphere {
  boolean hasAtmosphere;
  double scaleHeight;       // 标高 (km)
  double seaLevelPressure;  // 海平面气压 (Pa)
  double seaLevelDensity;   // 海平面密度 (kg/m³)
  double maxAltitude;       // 大气上界 (km)
  color atmosphereColor;

  // Basic指数大气模型
  double getPressureAtAltitude(double altitude);
  double getDensityAtAltitude(double altitude);

  // 计算大气阻力（第一版用简单模型）
  double calculateDrag(double altitude, double speed, double dragCoefficient, double crossSectionalArea);
}
```

#### Celestial_Ephemeris.pde - 星历系统（2D版本）
```java
class Ephemeris {
  // 缓存天体位置，避免重复计算
  Map<CelestialBody, List<EphemerisPoint>> cache;

  // 获取t时刻位置（优先用缓存，2D）
  Vector2 getPosition(CelestialBody body, double t);
  Vector2 getVelocity(CelestialBody body, double t);

  // 预计算时间窗口内的位置
  void precompute(CelestialBody body, double startTime, double endTime, double step);
}

class EphemerisPoint {
  double t;
  Vector2 position;
  Vector2 velocity;
}
```

---

### 4. 航天器系统 (Spacecraft_*) - 新增核心模块

---

#### 第一版：质点航天器（简化版）

##### Spacecraft_Vehicle.pde - 飞行器本体（质点，2D，自动控制版）
```java
class Spacecraft {
  String name;
  int id;
  String presetId;         // 预设ID（比如"lunar_transfer"）

  // 物理状态
  PhysicsMode physicsMode;
  SpacecraftState state;
  Orbit orbit;                     // On-rails用的轨道
  StateVector2D stateVector;       // Off-rails用的状态向量

  // 参考系
  CelestialBody referenceBody;     // 当前主引力天体

  // 姿态（虽然是质点，但有朝向用于推力方向）
  Rotation2D attitude;             // 2D朝向
  double angularVelocity;          // 角速度（rad/s，逆时针为正）

  // 引擎（简化版：只有一个主引擎，无燃料限制）
  SimpleEngine mainEngine;

  // 自动控制状态
  AutoControl autoControl;

  // === 核心方法 ===

  void updateOnRails(double simTime);    // 轨道模式更新
  void updateOffRails(double dt);        // 物理模式更新

  // 获取质量（固定，无燃料）
  double getCurrentMass();

  // 切换模式
  void enterOnRails();
  void enterOffRails();

  // 轨道坐标系下的方向
  Vector2 getPrograde();
  Vector2 getRetrograde();
  Vector2 getRadialOut();
  Vector2 getRadialIn();

  // 自动控制：朝向指定方向
  void setAutoTargetDirection(Vector2 direction);

  // 自动控制：点火，沿当前朝向
  void setEngineThrottle(float throttle);
}

class SimpleEngine {
  double thrust;           // 真空推力 (kN)
  double mass;             // 引擎干质量

  // 第一版简化：不考虑ISP、燃料、大气影响
  double getCurrentThrust();
}

class AutoControl {
  boolean isActive;

  // 目标朝向
  boolean hasTargetDirection;
  Vector2 targetDirection;

  // 引擎状态
  float targetThrottle;

  // 更新（返回当前控制输出）
  void update(Spacecraft craft, double dt);
}
```

##### Spacecraft_Presets.pde - 预设航天器定义
```java
class SpacecraftPreset {
  String id;
  String name;
  String description;

  double dryMass;        // 干质量
  double engineThrust;   // 引擎推力 (kN)
  double dragCoefficient;  // 阻力系数
  double crossSectionalArea;  // 横截面积 (m²)

  // 创建航天器实例
  Spacecraft createSpacecraft();
}

class SpacecraftPresets {
  static List<SpacecraftPreset> getAllPresets();
  static SpacecraftPreset getPreset(String id);

  // 预设定义
  static final String PRESET_SATELLITE = "satellite";
  static final String PRESET_LUNAR_TRANSFER = "lunar_transfer";
}
```

##### Spacecraft_Renderer.pde - 航天器渲染器（新增）
```java
class SpacecraftRenderer {
  void render(Spacecraft craft, Camera camera);
  void renderTrajectory(Spacecraft craft, Camera camera);
}
```

---

### 5. 任务系统 (Mission_*) - 新增核心（第一版）

#### Mission_Task.pde - 任务基类
```java
abstract class MissionTask {
  String id;
  String name;
  String description;

  MissionState state;

  // 检查任务能否执行（验证）
  abstract boolean canExecute(Spacecraft craft, SolarSystem system);

  // 开始执行
  abstract void startExecution(Spacecraft craft, SolarSystem system);

  // 更新执行
  abstract MissionState update(double simTime, double dt);

  // 任务是否完成
  boolean isCompleted();
  boolean isFailed();
}

enum MissionState {
  PENDING,          // 等待开始
  IN_PROGRESS,      // 执行中
  COMPLETED,        // 成功完成
  FAILED            // 失败
}
```

#### Mission_Presets.pde - 预设任务定义
```java
class MissionPreset {
  String id;
  String name;
  String description;

  // 需要的航天器预设ID
  String requiredSpacecraftPreset;

  // 起始条件
  Orbit initialOrbit;      // 起始轨道（相对于某个天体）
  CelestialBody initialBody;

  // 目标条件
  MissionGoal goal;

  // 创建任务实例
  MissionTask createTask();
}

class MissionGoal {
  // 目标类型
  MissionGoalType type;

  // 目标参数
  CelestialBody targetBody;
  Orbit targetOrbit;      // 目标轨道（如果是轨道插入）
  double targetAltitude;  // 目标高度（如果是着陆/撞毁）

  // 容差
  double positionTolerance;
  double velocityTolerance;
}

enum MissionGoalType {
  REACH_ORBIT,        // 进入指定轨道
  TRANSFER_TO_BODY,   // 转移到另一个天体的SOI
  ORBIT_INSERTION,    // 在目标天体插入轨道
  LAND,               // 着陆
  CRASH               // 撞毁（娱乐任务）
}

class MissionPresets {
  static List<MissionPreset> getAllAvailablePresets(Spacecraft craft, SolarSystem system);
  static MissionPreset getPreset(String id);

  // 预设任务ID
  static final String MISSION_LEO = "leo";                // 进入低地球轨道
  static final String MISSION_TRANSFER_MOON = "transfer_moon";  // 转移到月球
  static final String MISSION_LUNAR_ORBIT = "lunar_orbit";    // 进入月球轨道
  static final String MISSION_LUNAR_LANDING = "lunar_landing"; // 月球着陆
}
```

#### Mission_Planner.pde - 任务规划（计算机动）
```java
class MissionPlanner {
  // 为任务计算机动序列
  List<ManeuverNode> planMission(MissionGoal goal, Spacecraft craft, SolarSystem system);

  // 计算霍曼转移（Hohmann Transfer）
  static List<ManeuverNode> planHohmannTransfer(Orbit initialOrbit, Orbit targetOrbit);

  // 计算月球转移窗口
  static double findTransferWindowTime(CelestialBody origin, CelestialBody target, double startTime);

  // 计算平面变化机动
  static ManeuverNode planPlaneChange(Orbit orbit, double newW);
}
```

#### Mission_Executor.pde - 任务执行器（自动执行）
```java
class MissionExecutor {
  MissionTask currentTask;
  List<ManeuverNode> maneuverSequence;
  int currentManeuverIndex;

  // 状态
  MissionExecutorState state;

  // 开始执行任务
  void startMission(MissionTask task, List<ManeuverNode> maneuvers);

  // 更新执行
  void update(Spacecraft craft, SolarSystem system, double simTime, double dt);

  // 执行单个机动
  void executeManeuver(ManeuverNode node, Spacecraft craft, double simTime);

  // 当前状态
  String getCurrentStatusText();
  double getProgress();
}

enum MissionExecutorState {
  IDLE,
  WAITING_FOR_MANEUVER,    // 等待机动时刻到来
  ORIENTING,               // 调整朝向
  BURNING,                 // 点火中
  COMPLETED
}
```

#### Mission_Validator.pde - 任务验证器（检查能否完成）
```java
class MissionValidator {
  // 检查任务是否可用
  MissionValidationResult validateMission(MissionPreset preset, Spacecraft craft, SolarSystem system);

  // 计算所需Δv
  double calculateRequiredDeltaV(MissionGoal goal, Orbit initialOrbit);

  // 检查航天器是否足够完成任务
  boolean checkSpacecraftCapability(SpacecraftPreset craftPreset, double requiredDeltaV);
}

class MissionValidationResult {
  boolean canExecute;
  String reason;           // 如果不能执行，说明原因
  double requiredDeltaV;   // 需要的总Δv
}
```

---

#### 未来扩展：完整版（带部件系统）

##### Spacecraft_Part.pde - 部件基类
```java
// 部件类型（移至此处，第一版不用）
enum PartType {
  COMMAND,      // 指挥舱
  FUEL_TANK,    // 燃料箱
  ENGINE,       // 引擎
  RCS_THRUSTER, // RCS推进器
  DECOUPLER,    // 分离器
  FAIRING,      // 整流罩
  PAYLOAD       // 有效载荷
}

// 资源类型（移至此处，第一版不用）
enum ResourceType {
  LIQUID_FUEL,
  OXIDIZER,
  MONOPROPELLANT,  // RCS燃料
  ELECTRIC_CHARGE,
  SOLID_FUEL
}

abstract class Part {
  String name;
  PartType type;

  // 物理属性
  double dryMass;
  Vector2 position;       // 相对于CoM的位置（2D）
  Rotation2D orientation; // 朝向

  List<AttachNode> attachNodes;
  boolean isActive;

  ResourceContainer resourceCapacity;
  ResourceContainer resourceStorage;

  void update(float dt);
  void draw();

  void onStageSeparation();
  void onAttach();
  void onDetach();
}

class EnginePart extends Part {
  double ispSeaLevel, ispVacuum;
  double thrustSeaLevel, thrustVacuum;
  float throttle;
  boolean isIgnited;
  Map<ResourceType, Double> fuelConsumption;

  double getCurrentISP(double pressure);
  double getCurrentThrust(double pressure);
}

// ... 更多部件类
```

##### Spacecraft_Stage.pde - 分级系统
```java
class Stage {
  int stageNumber;
  List<Part> parts;
  List<Part> decouplers;
  boolean isSeparatorStage;

  void activate();
  void separate();
}

class StageManager {
  List<Stage> stages;
  int currentStageIndex;

  Stage getCurrentStage();
  Stage getNextStage();
  void stage();
}
```

#### Spacecraft_Trajectory.pde - 轨迹预测
```java
class TrajectoryPredictor {
  // 预测航天器未来轨迹
  Trajectory predict(Spacecraft craft, double duration, double stepSize);

  // 预测机动后的轨迹
  Trajectory predictAfterManeuver(Spacecraft craft, ManeuverNode maneuver);

  // 检测未来事件
  List<TrajectoryEvent> detectEvents(Trajectory trajectory);
}

class Trajectory {
  List<TrajectoryPoint> points;
  CelestialBody referenceBody;
}

class TrajectoryPoint {
  double time;
  Orbit orbit;           // 如果是on-rails
  StateVector2D state;   // 如果是off-rails（2D）
}

class TrajectoryEvent {
  double time;
  TrajectoryEventType type;  // SOI_ENTER, SOI_EXIT, COLLISION, PERIAPSIS, APOAPSIS
  CelestialBody relatedBody;
  TrajectoryPoint point;
}
```

#### Spacecraft_Maneuver.pde - 机动节点系统
```java
class ManeuverPlanner {
  List<ManeuverNode> nodes;

  // 添加机动节点（在指定轨道位置）
  void addNode(ManeuverNode node);

  // 移除节点
  void removeNode(ManeuverNode node);

  // 计算Δv总量
  double getTotalDeltaV();

  // 获取完整预测轨迹（含所有机动）
  Trajectory getFullPrediction();
}

class ManeuverNode {
  double time;              // 执行时刻（相对于现在）
  Vector2 deltaV;           // Δv矢量（prograde/radial分量，2D）

  // 计算结果
  Orbit orbitAfter;         // 机动后的轨道

  // 便捷构造方法
  static ManeuverNode prograde(double time, double dv);
  static ManeuverNode radial(double time, double dv);
}
```

---

### 6. 时间系统 (Time_*)

#### Time_WarpController.pde - 智能时间warp
```java
class TimeWarpController {
  static final double[] WARP_LEVELS = {1, 20, 60, 600, 3600, 86400, 864000, 8640000};

  int currentWarpIndex;
  boolean isPaused;

  // 智能限制
  boolean canWarpTo(int index);
  int getMaxAllowedWarp(Spacecraft craft);  // 近地时限制warp等级

  // 请求warp变更（返回是否成功）
  boolean requestWarpUp();
  boolean requestWarpDown();
}
```

#### Time_Scheduler.pde - 事件调度
```java
class EventScheduler {
  List<ScheduledEvent> events;

  // 安排事件
  void scheduleEvent(double time, Runnable action, String description);

  // 安排机动执行
  void scheduleManeuver(ManeuverNode node);

  // 更新（检查并触发到期事件）
  void update(double currentTime);
}

class ScheduledEvent {
  double executeTime;
  Runnable action;
  String description;
  boolean executed;
}
```

---

### 7. 游戏状态管理（新增）

#### Game_StateManager.pde
```java
class GameStateManager {
  GameState currentState;
  GameState previousState;

  // 状态切换
  void changeState(GameState newState);
  void pushState(GameState newState);
  void popState();

  // 状态查询
  boolean isInState(GameState state);
  boolean canTransitionTo(GameState targetState);
}
```

---

### 8. UI系统 (UI_*)

#### UI_TaskMenu.pde - 任务菜单（预设任务选择）
```java
class TaskMenu {
  boolean isVisible;

  // 显示可用的预设任务
  List<MissionPreset> availablePresets;

  // 选中的任务
  MissionPreset selectedPreset;

  // 渲染
  void draw();

  // 交互
  void handleClick(int x, int y);
  void show();
  void hide();
}
```

#### UI_MissionStatus.pde - 任务状态显示
```java
class MissionStatusDisplay {
  // 显示当前任务
  // 显示执行进度
  // 显示当前状态文字（比如"调整朝向中..."、"点火中..."）
  // 显示当前Δv使用情况（如果有）
}
```

#### UI_HeadingIndicator.pde - 航向指示器（2D）
```java
class HeadingIndicator {
  // 圆形表盘
  // 中心：航天器当前朝向指针
  // 标记：Prograde, Retrograde, RadialOut, RadialIn方向
  // 标记：自动控制目标方向
  // 外圈刻度：0°-360°（0°=右，逆时针增加）
}
```

#### UI_OrbitDisplay.pde - 轨道信息
```java
class OrbitDisplay {
  // 显示：
  // - Ap, Pe 高度
  // - 轨道周期
  // - 当前速度
  // - 到Ap/Pe的时间
  // - 轨道倾角（2D中不需要，预留）
  // - 升交点、近心点幅角等（高级信息）
}
```

---

### 9. 输入系统 (Input_*) - 简化版

#### Input_Processor.pde
```java
class InputProcessor {
  // 处理菜单点击等简单交互
  void update();
  boolean wasClicked(int x, int y, int width, int height);
  boolean isKeyPressed(int key);
}
```

---

### 10. 存档系统 (SaveLoad_*)

#### SaveLoad_Serializer.pde
```java
class SaveGameSerializer {
  // 保存整个游戏状态
  String serialize(SolarSystem system, List<Spacecraft> crafts, TimeManager time);

  // 加载
  SaveData deserialize(String data);

  // 格式：JSON或简单文本格式
}

class SaveData {
  double simTime;
  List<CelestialBodyData> celestialBodies;
  List<SpacecraftData> spacecrafts;
  int activeCraftId;
}
```

---

## 数据流与主循环

### 主循环 (draw())
```
每帧：
1. 计算deltaTime
2. inputProcessor.update()          // 处理输入（菜单点击等）
3. timeManager.update(dt)           // 推进时间
   - 若有调度事件，触发
   - warp控制：近天体时自动降低warp
4. gameScene.update(simTime, dt)    // 场景更新
   ├─ solarSystem.update(simTime)   // 更新天体位置
   ├─ missionExecutor.update(...)   // 任务执行器更新
   │  └─ 自动调整朝向、点火等
   └─ for each craft:
       ├─ if on-rails: craft.updateOnRails(simTime)
       │  └─ 更新轨道位置
       │  └─ 检查SOI穿越
       │  └─ 若穿越，切换参考系
       └─ if off-rails: craft.updateOffRails(dt)
          └─ 计算受力（引力+推力）
          └─ 数值积分
          └─ 检查碰撞（通过Physics_Collision）
5. trajectoryPredictor.update()     // 更新轨迹预测（按需）
6. camera.update(dt)                // 摄像机跟随
7. hud.update()                     // UI更新
8. 渲染（背景 → 轨道 → SOI → 天体 → 航天器 → UI）
```

### 游戏流程
```
游戏启动 → 显示初始状态（航天器在地球轨道）
   ↓
玩家点击"选择任务" → 显示任务菜单
   ↓
玩家选择可用任务 → 任务验证器检查能否完成
   ↓
任务规划器计算机动序列 → 显示给玩家确认（可选）
   ↓
玩家确认 → 任务执行器开始执行
   ↓
   ├─ 等待到机动时刻（On-rails，可time warp）
   ├─ 进入Off-rails，调整朝向
   ├─ 点火
   ├─ 回到On-rails，继续等待
   └─ 重复直到任务完成
   ↓
任务完成/失败 → 显示结果 → 返回选择任务或继续观察
```

### On-rails vs Off-rails 切换逻辑（明确定义）
```
进入On-rails的条件：
- 不在大气层内
- 不在SOI边界附近
- 没有正在进行的机动（throttle = 0 且 朝向调整完成）
- 用户未强制开启物理模式

进入Off-rails的条件：
- 引擎点火中（throttle > 0）
- 需要调整朝向（自动控制中）
- 在大气层内
- 用户强制开启物理模式
- 距离天体表面低于某个阈值

"正在进行的机动"定义：
- AutoControl.hasTargetDirection = true，或者
- AutoControl.targetThrottle > 0
```

---

## 坐标系统约定（2D版）

### 单位系统
- 长度：公里 (km)
- 速度：公里/秒 (km/s)
- 质量：吨 (t) 或 千克 (kg)
- 时间：秒 (s)
- GM：km³/s²
- 角度：数学计算用弧度，UI显示用度

### 坐标系
```
日心惯性系 (Heliocentric Inertial):
- 原点：太阳中心
- X轴：向右（屏幕）
- Y轴：向上（屏幕）
- 旋转方向：逆时针为正

中心天体惯性系 (Body-centric Inertial):
- 原点：天体中心
- X轴：向右
- Y轴：向上
- 不随天体自转旋转

中心天体固定系 (Body-fixed):
- 原点：天体中心
- 随天体自转旋转
- 用于计算表面位置和大气层
```

### 初始朝向
- 航天器零朝向：+X轴（向右）
- 轨道运动：逆时针为正
- 姿态旋转：逆时针为正

### 轨道坐标系方向
- Prograde（顺向）：速度方向
- Retrograde（逆向）：速度反方向
- Radial Out（径向向外）：从中心天体指向航天器
- Radial In（径向向内）：从航天器指向中心天体

---

## 性能优化策略

1. **LOD渲染** - 已有，保持
2. **轨迹预测缓存** - 避免每帧重新计算整个预测
3. **星历缓存** - 天体位置预计算
4. **物理步长自适应** - 近天体用小dt，远天体用大dt
5. **视锥体裁剪** - 不渲染屏幕外对象
6. **事件检测优化** - 二分法找SOI穿越/碰撞时间

---

## 分阶段实现路线图

> 注：标注 🔄 的项表示从旧项目（SolarSystemNavigation）移植代码
>
> **移植原则**：
> 1. 只搬算法/数学逻辑，不搬旧架构
> 2. 按目标架构的接口重写/适配
> 3. 验证旧代码的正确性后，按新架构重新组织

### 阶段 1：基础设施整合
- [ ] 创建Core_Math（Vector2, Rotation2D）
- [ ] 创建Core_CoordinateTransformer（坐标转换）
- [ ] 创建Game_StateManager（状态管理）
- [ ] 重构CelestialBody，拆分Orbit类到独立文件
- [ ] 创建Atmosphere类（Basic指数模型，预留）🔄
- [ ] 重命名文件为目标架构格式（Celestial_*, Time_* 等）
- [ ] 整理Core_Enums，添加PhysicsMode、SpacecraftState、MissionState（移走PartType/ResourceType到未来扩展）

### 阶段 2：质点航天器（On-rails仅显示）
- [ ] 实现Spacecraft类（质点，状态容器）🔄
- [ ] 实现Spacecraft_Renderer（航天器渲染）
- [ ] 创建SpacecraftPresets（预设航天器定义）
- [ ] 初始场景：地球轨道放置一艘航天器
- [ ] 摄像机可聚焦航天器
- [ ] HUD显示航天器基本信息

### 阶段 3：任务菜单 + 轨迹预测可视化
- [ ] 实现MissionTask基类、MissionGoal、MissionState
- [ ] 实现MissionPresets基础（显示预设任务，暂不验证）
- [ ] 实现UI_TaskMenu（任务选择菜单）
- [ ] 实现TrajectoryPredictor（仅On-rails预测）
- [ ] 实现ManeuverNode占位（为后续机动预留）
- [ ] 绘制轨迹线（显示未来轨道周期）
- [ ] 标记近心点/远心点

### 阶段 4：双模式物理系统
- [ ] 实现补丁圆锥系统PatchedConics 🔄
- [ ] 实现数值积分器NBodyIntegrator（RK4，2D）🔄
- [ ] 实现受力计算ForceSolver（引力+推力，2D）🔄
- [ ] 实现碰撞检测Physics_Collision（统一处理）
- [ ] 实现SOI穿越检测与参考系切换 🔄
- [ ] 实现On-rails/Off-rails自动切换逻辑 🔄（使用明确定义的条件）
- [ ] 实现TimeWarp智能限制
- [ ] 添加调试面板用于验证

### 阶段 5：机动规划与自动执行
- [ ] 完善MissionPlanner（霍曼转移等机动计算）🔄
- [ ] 实现MissionExecutor（自动执行机动序列）🔄
- [ ] 实现MissionValidator（任务验证，检查能否完成）
- [ ] 实现AutoControl（自动朝向、自动油门）🔄
- [ ] 实现SimpleEngine类（简化版，无燃料）🔄

### 阶段 6：UI完善
- [ ] 实现UI_MissionStatus（任务状态显示）
- [ ] 实现UI_HeadingIndicator（航向指示器）
- [ ] 实现UI_OrbitDisplay（轨道信息面板）
- [ ] 更新摄像机系统（跟随航天器，飞船视图）

### 阶段 7：存档系统
- [ ] 实现SaveGameSerializer
- [ ] 存档文件管理
- [ ] 快速存档/读档（F5/F9）

---

### 未来扩展：完整版（部件系统 + 手动操作）
- [ ] 实现Part基类 + 具体部件类
- [ ] 实现Stage + StageManager
- [ ] 实现Resource系统（燃料）
- [ ] 航天器编辑器（建造模式）
- [ ] 手动操作模式（玩家手操）
- [ ] 实现Input_Bindings（按键绑定）

---

## 核心数学类设计（2D版）

### Core_Math.pde
```java
class Vector2 {
  double x, y;

  Vector2();
  Vector2(double x, double y);

  // 基本运算
  Vector2 add(Vector2 v);
  Vector2 sub(Vector2 v);
  Vector2 mul(double s);
  Vector2 div(double s);

  // 向量运算
  double dot(Vector2 v);
  double cross(Vector2 v);        // 2D叉乘返回标量（z分量）
  double magnitude();
  double magnitudeSq();
  Vector2 normalized();

  // 旋转
  Vector2 rotate(double angle);   // 逆时针旋转angle弧度

  // 距离
  double distance(Vector2 v);

  // 角度
  double angle();                 // 从X轴逆时针转的角度
  double angleTo(Vector2 v);      // 到另一个向量的夹角

  // 工具
  Vector2 clone();
  String toString();

  // 常量
  static Vector2 zero();
  static Vector2 one();
  static Vector2 right();         // (1, 0)
  static Vector2 up();            // (0, 1)
  static Vector2 left();
  static Vector2 down();
}

class Rotation2D {
  // 2D旋转，用角度表示（或用cos/sin缓存优化）
  double angle;  // 弧度，逆时针为正

  Rotation2D();
  Rotation2D(double angle);

  // 构造
  static Rotation2D fromAngle(double angle);
  static Rotation2D fromDirection(Vector2 dir);

  // 运算
  Rotation2D add(Rotation2D r);
  Rotation2D sub(Rotation2D r);
  Rotation2D mul(double s);

  // 旋转向量
  Vector2 rotate(Vector2 v);

  // 获取方向
  Vector2 getForward();           // 旋转后的X轴
  Vector2 getRight();             // = forward
  Vector2 getUp();                // 逆时针90度

  // 插值
  static Rotation2D lerp(Rotation2D a, Rotation2D b, double t);

  // 工具
  Rotation2D normalize();         // 归一化到[0, 2π)
  Rotation2D inverse();           // 反向旋转
}
```

---

## 设计原则

1. **分离关注点** - 数据/逻辑/渲染分离
2. **优先使用组合** - 避免深继承树
3. **纯函数化数学** - 轨道数学无副作用，便于测试
4. **事件解耦** - 模块通过事件通信，不直接依赖
5. **迭代开发** - 每个阶段可运行，逐步添加功能
