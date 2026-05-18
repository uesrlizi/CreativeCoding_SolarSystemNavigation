# SolarSystemSpaceflightSim 目标架构文档

## 概述

类KSP太阳系航天模拟游戏的完整架构设计。核心是**真实物理模拟**与**可玩游戏性**的平衡。

## 已确认的设计决策

### 核心功能
- **物理模拟**：完全KSP风格（On-rails + Off-rails双模式）
- **维度**：纯2D（第一版）
- **航天器模型**：第一版用质点模型，不实现部件系统
- **物理引擎**：全手写，不集成第三方库
- **大气模型**：Basic（指数大气模型，只计算密度用于阻力）
- **架构设计**：预留扩展性，质点版可平滑过渡到完整版

### 实现优先级
1. 基础设施重构
2. 航天器质点版
3. 双模式物理系统
4. 轨迹预测与UI
5. 存档系统

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

### 第一版：质点航天器（MVP）
```
SolarSystemSpaceflightSim/
├── TARGET_ARCHITECTURE.md          # 本文档
├── SolarSystemSpaceflightSim.pde   # 主程序入口（精简版）
│
├── Core_*.pde                      # 核心模块
│   ├── Core_Enums.pde              # 枚举定义
│   ├── Core_Constants.pde          # 物理常数
│   ├── Core_Math.pde               # 数学工具库（Vector3, Matrix3）
│   ├── Core_OrbitalMath.pde        # 轨道数学库
│   └── Core_EventSystem.pde        # 事件总线
│
├── Physics_*.pde                   # 物理系统
│   ├── Physics_PatchedConics.pde   # 补丁圆锥系统
│   ├── Physics_NBodyIntegrator.pde # N体数值积分器
│   ├── Physics_ForceSolver.pde     # 受力计算
│   └── Physics_Collision.pde       # 碰撞检测
│
├── Celestial_*.pde                 # 天体系统
│   ├── Celestial_Body.pde          # 天体数据类
│   ├── Celestial_Orbit.pde         # 轨道数据类（从Body拆分）
│   ├── Celestial_Atmosphere.pde    # 大气模型
│   ├── Celestial_SolarSystem.pde   # 太阳系容器
│   ├── Celestial_Renderer.pde      # 天体渲染器
│   └── Celestial_SOISystem.pde     # SOI系统
│
├── Spacecraft_*.pde                # 航天器系统（质点版）
│   ├── Spacecraft_Vehicle.pde      # 飞行器本体（质点）
│   ├── Spacecraft_Engine.pde       # 引擎数据（不连部件）
│   ├── Spacecraft_Resource.pde     # 资源管理（燃料、电力）
│   ├── Spacecraft_Trajectory.pde   # 轨迹预测
│   └── Spacecraft_Maneuver.pde     # 机动节点系统
│
├── Camera_*.pde                    # 摄像机系统
│   ├── Camera_Controller.pde       # 摄像机控制器
│   └── Camera_Modes.pde            # 摄像机模式
│
├── Time_*.pde                      # 时间系统
│   ├── Time_Manager.pde            # 时间管理器
│   ├── Time_WarpController.pde     # 智能时间warp
│   └── Time_Scheduler.pde          # 事件调度器
│
├── UI_*.pde                        # UI系统
│   ├── UI_HUD.pde                  # HUD主界面
│   ├── UI_HeadingIndicator.pde     # 航向指示器（2D替代NavBall）
│   ├── UI_OrbitDisplay.pde         # 轨道信息显示
│   └── UI_ManeuverPlanner.pde      # 机动规划器
│
├── Input_*.pde                     # 输入系统
│   ├── Input_Bindings.pde          # 按键绑定
│   └── Input_Processor.pde         # 输入处理
│
├── SaveLoad_*.pde                  # 存档系统
│   └── SaveLoad_Serializer.pde     # 序列化
│
└── Game_*.pde                      # 游戏逻辑
    └── Game_Scene.pde              # 场景管理
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

// 部件类型
enum PartType {
  COMMAND,      // 指挥舱
  FUEL_TANK,    // 燃料箱
  ENGINE,       // 引擎
  RCS_THRUSTER, // RCS推进器
  DECOUPLER,    // 分离器
  FAIRING,      // 整流罩
  PAYLOAD       // 有效载荷
}

// 资源类型
enum ResourceType {
  LIQUID_FUEL,
  OXIDIZER,
  MONOPROPELLANT,  // RCS燃料
  ELECTRIC_CHARGE,
  SOLID_FUEL
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
// - "collision" { craft, body }
// - "stage_separated" { craft, stage }
// - "fuel_depleted" { craft, resource }
```

---

### 2. 物理系统 (Physics_*)

#### Physics_PatchedConics.pde - 补丁圆锥系统
```java
class PatchedConicsSystem {
  // 判断航天器在哪个SOI内
  CelestialBody findCurrentSOI(Spacecraft craft);
  
  // SOI边界穿越检测
  SOITraversal predictSOITraversal(Spacecraft craft, double dtMax);
  
  // 切换参考系时的速度转换
  void transferSOI(Spacecraft craft, CelestialBody oldBody, CelestialBody newBody);
}

class SOITraversal {
  boolean willTraverse;
  double timeToTraversal;      // 到穿越时刻的秒数
  CelestialBody exitBody;      // 离开的天体
  CelestialBody enterBody;     // 进入的天体
}
```

#### Physics_NBodyIntegrator.pde - 数值积分器
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
  
  // 状态向量：位置+速度
  StateVector getState(Spacecraft craft);
  void setState(Spacecraft craft, StateVector state);
}

class StateVector {
  double x, y, z;    // 位置 (km)
  double vx, vy, vz; // 速度 (km/s)
}
```

#### Physics_ForceSolver.pde - 受力计算
```java
class ForceSolver {
  // 计算合加速度
  Vector3 calculateTotalAcceleration(Spacecraft craft, List<CelestialBody> bodies);
  
  // 各分力
  Vector3 calculateGravity(Spacecraft craft, CelestialBody body);
  Vector3 calculateThrust(Spacecraft craft);
  Vector3 calculateDrag(Spacecraft craft, CelestialBody body);  // 大气阻力
}
```

---

### 3. 天体系统 (Celestial_*)

#### Celestial_Body.pde - 天体数据类（重构）
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
  
  // 获取t时刻位置（解析解）
  Vector3 getPositionAtTime(double t);
  Vector3 getVelocityAtTime(double t);
  
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

#### Celestial_Ephemeris.pde - 星历系统（新增）
```java
class Ephemeris {
  // 缓存天体位置，避免重复计算
  Map<CelestialBody, List<EphemerisPoint>> cache;
  
  // 获取t时刻位置（优先用缓存）
  Vector3 getPosition(CelestialBody body, double t);
  
  // 预计算时间窗口内的位置
  void precompute(CelestialBody body, double startTime, double endTime, double step);
}

class EphemerisPoint {
  double t;
  Vector3 position;
  Vector3 velocity;
}
```

---

### 4. 航天器系统 (Spacecraft_*) - 新增核心模块

---

#### 第一版：质点航天器（简化版）

##### Spacecraft_Vehicle.pde - 飞行器本体（质点，2D）
```java
class Spacecraft {
  String name;
  int id;
  
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
  
  // 引擎（质点版：只有一个主引擎 + RCS）
  Engine mainEngine;
  RCS rcs;
  
  // 资源
  ResourceContainer resources;
  
  // 控制输入
  ControlInput controlInput;
  
  // SAS (稳定辅助系统)
  SASController sas;
  
  // === 核心方法 ===
  
  void updateOnRails(double simTime);    // 轨道模式更新
  void updateOffRails(double dt);        // 物理模式更新
  
  // 执行机动
  void executeManeuver(ManeuverNode node);
  
  // 碰撞检测
  boolean checkCollision(CelestialBody body);
  
  // 获取质量（干质量 + 燃料）
  double getCurrentMass();
  double getDryMass();
  double getFuelMass();
  
  // 切换模式
  void enterOnRails();
  void enterOffRails();
  
  // 轨道坐标系下的方向
  Vector2 getPrograde();
  Vector2 getRetrograde();
  Vector2 getRadialOut();
  Vector2 getRadialIn();
}

class ControlInput {
  // 主引擎节流阀 0..1
  float throttle;
  
  // 姿态控制（旋转力矩）-1..1
  float torque;
  
  // RCS平移控制
  boolean rcsForward, rcsBackward;
  boolean rcsLeft, rcsRight;
  
  // SAS
  boolean sasEnabled;
  SASMode sasMode;  // HOLD_PROGRADE, HOLD_RETROGRADE, HOLD_RADIAL_OUT, HOLD_RADIAL_IN, MANEUVER_NODE
}

class StateVector2D {
  Vector2 position;    // 位置
  Vector2 velocity;    // 速度
}
```

##### Spacecraft_Engine.pde - 引擎数据（不连部件）
```java
class Engine {
  // 引擎属性
  double ispSeaLevel;      // 海平面比冲 (s)
  double ispVacuum;        // 真空比冲 (s)
  double thrustSeaLevel;   // 海平面推力 (kN)
  double thrustVacuum;     // 真空推力 (kN)
  
  // 质量
  double mass;             // 引擎干质量
  
  // 燃料消耗
  double fuelConsumptionRate;  // kg/s（全油门时）
  ResourceType fuelType;
  ResourceType oxidizerType;
  
  // 获取当前比冲（取决于当前大气压强）
  double getCurrentISP(double atmosphericPressure);
  
  // 获取当前推力
  double getCurrentThrust(double atmosphericPressure, float throttle);
  
  // 计算燃料消耗率
  double getFuelConsumptionRate(double atmosphericPressure, float throttle);
}

class RCS {
  double isp;              // 比冲 (s)
  double thrust;           // 推力 (kN)
  double fuelConsumptionRate;
  ResourceType fuelType;   // 通常是MONOPROPELLANT
  
  // 四向推力控制（2D）
  Vector2 calculateThrust(boolean forward, boolean backward,
                           boolean left, boolean right,
                           Rotation2D attitude, double atmosphericPressure);
}
```

##### Spacecraft_Resource.pde - 资源管理（简化版）
```java
class ResourceContainer {
  Map<ResourceType, Double> amounts;
  Map<ResourceType, Double> capacities;
  
  // 增加资源
  double addResource(ResourceType type, double amount);
  
  // 消耗资源（返回实际消耗量）
  double consumeResource(ResourceType type, double amount);
  
  // 获取当前量/最大量/比例
  double getAmount(ResourceType type);
  double getCapacity(ResourceType type);
  double getRatio(ResourceType type);
}
```

---

#### 未来扩展：完整版（带部件系统）

##### Spacecraft_Part.pde - 部件基类
```java
abstract class Part {
  String name;
  PartType type;
  
  // 物理属性
  double dryMass;
  Vector3 position;       // 相对于CoM的位置
  Matrix3 orientation;    // 朝向
  
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
  StateVector state;     // 如果是off-rails
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
  Vector3 deltaV;           // Δv矢量（prograde/radial/normal分量）
  
  // 计算结果
  Orbit orbitAfter;         // 机动后的轨道
  double fuelRequired;      // 预计燃料消耗
  
  // 便捷构造方法
  static ManeuverNode prograde(double time, double dv);
  static ManeuverNode radial(double time, double dv);
  static ManeuverNode normal(double time, double dv);
}
```

---

### 5. 时间系统 (Time_*)

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

### 6. UI系统 (UI_*) - 大幅扩展

#### UI_HeadingIndicator.pde - 航向指示器（2D）
```java
class HeadingIndicator {
  // 圆形表盘
  // 中心：航天器当前朝向指针
  // 标记：Prograde, Retrograde, RadialOut, RadialIn方向
  // 标记：SAS目标方向
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
  // - 轨道倾角
  // - 升交点、近心点幅角等（高级信息）
}
```

#### UI_ManeuverPlanner.pde - 机动规划UI
```java
class ManeuverPlannerUI {
  // 显示当前所有机动节点
  // 可调整节点的prograde/radial/normal分量
  // 显示Δv总量
  // 显示燃料估计
  // 显示机动后的新轨道Ap/Pe
}
```

---

### 7. 输入系统 (Input_*) - 新增

#### Input_Bindings.pde
```java
class InputBindings {
  Map<String, InputBinding> bindings;
  
  void loadDefaults();
  void loadFromFile(String path);
  void saveToFile(String path);
}

class InputBinding {
  String actionName;  // "throttle_up", "stage", "sas_toggle"
  int primaryKey;
  int secondaryKey;
  InputContext context;  // 何时生效（FLIGHT/MAP/ALL）
}
```

---

### 8. 存档系统 (SaveLoad_*) - 新增

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
2. inputProcessor.update()          // 处理输入
3. timeManager.update(dt)           // 推进时间
   - 若有调度事件，触发
   - warp控制：近天体时自动降低warp
4. gameScene.update(simTime, dt)    // 场景更新
   ├─ solarSystem.update(simTime)   // 更新天体位置
   └─ for each craft:
       ├─ if on-rails: craft.updateOnRails(simTime)
       │  └─ 更新轨道位置
       │  └─ 检查SOI穿越
       │  └─ 若穿越，切换参考系
       └─ if off-rails: craft.updateOffRails(dt)
          └─ 计算受力（引力+推力+阻力）
          └─ 数值积分
          └─ 检查碰撞
5. trajectoryPredictor.update()     // 更新轨迹预测（按需）
6. camera.update(dt)                // 摄像机跟随
7. hud.update()                     // UI更新
8. 渲染（背景 → 轨道 → SOI → 天体 → 航天器 → UI）
```

### On-rails vs Off-rails 切换逻辑
```
进入On-rails的条件：
- 不在大气层内
- 不在SOI边界附近
- 没有正在进行的机动
- 用户未强制开启物理模式

进入Off-rails的条件：
- 引擎点火
- 在大气层内
- 用户强制开启物理模式
- 距离天体表面低于某个阈值
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

## 实现路线图

### 阶段 1：基础设施
- 创建Core_Math（Vector2, Rotation2D）
- 拆分Orbit类，重构CelestialBody
- 实现Atmosphere类
- 实现输入系统
- 创建GameScene

### 阶段 2：航天器质点版
- 实现Spacecraft类
- 实现Engine + RCS
- 实现ResourceContainer
- 实现ControlInput + SAS

### 阶段 3：物理系统
- 实现补丁圆锥系统
- 实现数值积分器（RK4）
- 实现受力计算
- SOI切换 + 双模式切换
- 碰撞检测

### 阶段 4：UI与轨迹预测
- 实现TrajectoryPredictor
- 实现ManeuverNode
- 实现HeadingIndicator
- 实现OrbitDisplay
- 实现ManeuverPlannerUI

### 阶段 5：存档
- 实现SaveGameSerializer
- 快速存档/读档

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
