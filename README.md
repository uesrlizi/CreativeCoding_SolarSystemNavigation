# Spacecraft Launch Simulator

基于 Processing (Java Mode) 的航天器发射入轨模拟器，使用开普勒轨道力学进行物理计算。支持从地球表面发射航天器至近地轨道（LEO），以及后续的霍曼转移至其他行星。

## 项目结构

```
SolarSystemNavigation/
├── SolarSystemNavigation.pde   # 主程序入口、setup/draw、全局工具函数
├── A_Enums.pde                 # 枚举定义（ViewMode, ShipState, FrameType, BodyType, SOIEventType）
├── B_OrbitalMath.pde           # 开普勒轨道数学（求解/坐标转换）
├── B_SOISystem.pde             # SOI（影响球）系统核心
├── F_SOIEvent.pde              # SOI事件记录系统
├── C_TimeManager.pde           # 模拟时间与时间加速
├── D_ReferenceFrame.pde        # 参考系系统（SURFACE/BODY_ORBIT/HELIOCENTRIC）
├── D_AtmosphereModel.pde       # 大气模型（密度/阻力/截止高度）
├── D_OrbitPropagator.pde       # 开普勒轨道传播器（"on rails"模式）
├── D_FlightComputer.pde        # 飞行计算机/制导算法（重力转弯/PEG/转移燃烧）
├── D_PhysicsEngine.pde         # 牛顿力学积分引擎（"not on rails"模式）
├── D_GuidanceSystem.pde        # 制导系统（上升/圆化状态机）
├── CelestialBody.pde           # 天体数据模型与LOD分级绘制
├── CelestialBodyRenderer.pde   # 天体细节渲染器（程序化纹理/大气/光环/太阳日珥）
├── SolarSystem.pde             # 太阳系初始化（太阳 + 8大行星 + 月球）
├── Spacecraft.pde              # 航天器状态容器
├── SpacecraftRenderer.pde      # 航天器绘制（地图图标 / 飞船视角详细模型）
├── LaunchSite.pde              # 发射场数据模型（地表位置跟踪）
├── LaunchSiteRenderer.pde      # 发射场绘制（发射台/勤务塔/脐带臂/避雷塔/地形）
├── CameraController.pde        # 摄像机控制（平移/缩放/跟随/双视角）
├── MissionPlanner.pde          # 轨道力学常数、霍曼转移、SOI计算
├── LaunchController.pde        # 发射流程状态机
├── E_Button.pde                # 统一按钮组件（hover/点击状态/tooltip）
├── E_Tooltip.pde               # 浮动提示组件（自动定位/文本换行）
├── E_TimeControlPanel.pde      # 左上角时间控制面板
├── E_NavigationFocusPanel.pde  # 左侧导航聚焦面板
├── E_ViewToggleButton.pde      # 右上角视图切换按钮
├── E_ShipStatusPanel.pde       # 右下角飞船状态面板
└── HUD.pde                     # 总控HUD（编排所有子面板）
```

所有 `.pde` 文件会被 Processing 连接为单一编译单元（按文件名排序），因此跨文件的类和方法可直接引用。

## 核心架构

架构设计为类似 Kerbal Space Program 的分层设计，**制导算法与轨道传播分离**，**状态与逻辑分离**：

```
Spacecraft（纯状态容器）
    ├── 状态
    │   ├── pos, vel (唯一状态源，单位: km, km/s)
    │   └── currentCentralBody (CelestialBody)
    ├── [发射/圆化阶段] → GuidanceSystem（制导状态机）
    ├── [轨道阶段] → OrbitPropagator（开普勒传播）
    └── 显示角度平滑（独立于物理）

GuidanceSystem（制导系统）
    ├── 上升段重力转弯（FlightComputer）
    ├── PEG 圆化制导（FlightComputer）
    ├── 远地点检测 + 圆化燃烧中点对齐
    └── 大气阻力（AtmosphereModel）

LaunchController（纯任务状态机）
    ├── 任务阶段切换（倒计时→点火→发射→...）
    ├── 时间保护逻辑
    └── 不包含任何物理计算
```

### 架构详解

```
Spacecraft (纯状态容器)
├── 核心状态
│   ├── pos, vel (唯一状态源，单位: km, km/s)
│   └── currentCentralBody (CelestialBody)
├── OrbitPropagator
│   ├── 从 pos/vel/GM 实时计算密切轨道根数（导出量，非状态）
│   └── 开普勒轨道传播
├── PhysicsEngine
│   └── 用 ForceModel 做子步积分
└── FlightComputer
    └── 纯函数：输入状态 → 输出推力方向（不持有状态）

GuidanceSystem
├── 上升段状态机
├── 圆化段状态机
├── 远地点检测
└── 燃烧时间控制

ForceModel (统一接口)
└── SpacecraftForceModel
    ├── 引力计算
    ├── 推力方向（由 FlightComputer 提供）
    └── 大气阻力
```

### 关键解耦原则
1. **Spacecraft 是纯状态容器** — 不包含物理积分逻辑
2. **状态只有一套** — `(pos, vel)` + `currentCentralBody`
3. **制导算法是纯函数** — FlightComputer 不持有状态，只做计算
4. **GuidanceSystem 处理制导状态机** — 从 Spacecraft 中独立出来

### 发射/圆化制导状态机

完整的 KSP 风格发射流程：

| 阶段 | 制导 | 完成条件 |
|------|------|---------|
| `LAUNCHING` | 重力转弯（10s 垂直后逐渐俯仰） | 远地点 ≥ 420km |
| 滑行 | 无推力 | 到达远地点前 `burnDuration/2` |
| `CIRCULARIZING` | PEG 制导 | 近地点 ≥ 419km 或 燃烧时间耗尽 |
| `ORBIT` | 解析圆形轨道 | — |

### 物理/轨道模式

| 阶段 | 模式 | 说明 |
|------|------|------|
| `LAUNCHING` / `CIRCULARIZING` | GuidanceSystem | 子步迭代，完整制导 |
| `ORBIT` / `TRANSFER` / 其他 | Orbit | 开普勒解析传播 |

### 参考系系统 (FrameType)

- **SURFACE** — 地表坐标系，发射初始阶段
- **BODY_ORBIT** — 行星相对坐标系（地球轨道）
- **HELIOCENTRIC** — 日心坐标系（行星际转移）

## SOI系统

实现了完整的引力影响球（Sphere of Influence）系统，支持真实的 patched conic 轨道转移：

### 核心特性

- **真实SOI计算**：使用标准公式 r_SOI = a * (m/M)^(2/5)，基于天体质量比和轨道半长轴
- **自动参考系切换**：穿越SOI边界时自动切换日心/天体中心参考系
- **多体SOI检测**：同时检测行星和卫星的SOI，优先进入较小天体的SOI
- **事件记录系统**：所有SOI穿越事件记录在日志中
- **可视化支持**：SOI边界显示（按键[K]切换）

### SOI半径

| 天体 | SOI半径 (km) | 说明 |
|------|--------------|------|
| 地球 | ~929,000 | 基于地球-太阳质量比 |
| 月球 | ~66,100 | 基于月球-地球质量比 |
| 火星 | ~578,000 | 基于火星-太阳质量比 |
| 木星 | ~48,200,000 | 基于木星-太阳质量比 |

### SOI系统架构

```
SOISystem
├── calculateSOIRadius(body, primary) → r
├── findDominantBody(ship) → CelestialBody
├── checkAndProcessSOICrossing(ship, t)
│   ├── 检测SOI边界穿越
│   ├── 切换参考系
│   └── 记录SOI事件
├── switchToBodyCentric(ship, body)
│   ├── pos_rel = pos_helio - body_pos
│   └── vel_rel = vel_helio - body_vel
└── switchToHeliocentric(ship)
    ├── pos_helio = body_pos + pos_rel
    └── vel_helio = body_vel + vel_rel

SOIEventLog
├── logEnterSOI(t, body, pos, vel)
├── logExitSOI(t, body, pos, vel)
└── logSwitchSOI(t, from, to, pos, vel)
```

### CelestialBody扩展属性

```java
double GM                // 引力参数 (km³/s²)
double mass              // 质量 (kg)
CelestialBody parentBody // 父天体（用于卫星）
double soiRadius        // 缓存的SOI半径
```

### SOI事件类型 (SOIEventType)

| 事件 | 说明 |
|------|------|
| `ENTER_SOI` | 进入某个天体的SOI |
| `EXIT_SOI` | 离开某个天体的SOI |
| `SWITCH_SOI` | 从一个天体SOI直接切换到另一个 |

### 与现有系统的集成

- **LaunchController**：保留原有的2xSOI检测逻辑（用于TOI触发）
- **Spacecraft**：SOI系统会更新 `currentCentralBody` 来切换参考系
- **HUD**：右下角面板显示当前SOI状态，提示[K]键
- **SolarSystem**：包含月球卫星系统

### 地月系统SOI关系

```
太阳SOI (整个太阳系)
└── 地球SOI (~929,000 km)
    └── 月球SOI (~66,100 km)
```

## 核心模块详解

### CelestialBodyRenderer.pde — 天体细节渲染器

程序化纹理渲染，无外部资源依赖，支持 LOD 分级：

| LOD级别 | 触发条件 | 效果 |
|---------|---------|------|
| LOD0 | 屏幕半径 < 25px | 简单圆形 + 太阳基础光晕 + 星环(>40px) + 大气(>30px) |
| LOD1 | 25~90px | 形状化条纹带(10条) + 中等细节星环 + 大气 |
| LOD2 | 90~220px | 更高细分条纹带(14条) + 大红斑(Jupiter) + 中等细节星环 |
| LOD3 | > 220px | 完整细节(16条带) + 大红斑 + 高细节星环 + 大气 |
| Scanline | 半径 > 屏幕宽高50% | 逐行扫描填充，避免巨型椭圆性能问题 |
| LOD4 | 包含屏幕四角 | 全屏太阳噪点表面 |

**天体特殊效果：**
- **太阳**：径向噪点变化 + 日珥脉动 + 多层光晕
- **地球**：蓝绿海陆噪点分离 + 大气边缘发光
- **火星**：红棕变化表面 + 稀薄大气
- **木星**：条纹带 + 大红斑特征
- **土星/天王星**：光环系统（多层半透明噪点）

**渲染策略（无缺口保证）：**
1. 所有颜色带使用闭合形状
2. 相邻带宽度重叠30%
3. 完整圆周采样（步长0.03弧度）
4. 形状路径：上半圈 + 下半圈反向闭合

**星环渲染策略（正确遮挡+无分割线）：**
1. 先画完整的环（0~TWO_PI）作为后半部分
2. 画行星本体遮挡中间部分
3. 再画环的下半圈（PI~TWO_PI）作为前半部分
4. 星环分三个细节级别：Simple/Medium/Detailed，分别用于LOD0/LOD1~2/LOD3
5. 星环层使用Perlin噪声实现透明度和颜色变化
6. 所有LOD统一使用ringTilt，朝向完全一致

### CelestialBody.pde — 天体数据模型

扩展属性：
- `BodyType`：SUN / TERRESTRIAL / GAS_GIANT / ICE_GIANT
- 光环参数：`hasRing` / `ringInnerRadius` / `ringOuterRadius` / `ringTilt`
- 大气参数：`hasAtmosphere` / `atmosphereColor` / `atmosphereThickness`
- 物理参数：`GM` / `mass` / `parentBody` / `soiRadius`
- 渲染器引用：`renderer`（CelestialBodyRenderer实例）

LOD选择完全基于**屏幕半径大小**，不再依赖中心是否在屏幕内，避免平移时跳变。

卫星支持：月球作为地球的卫星，相对轨道独立计算。

### MissionPlanner.pde — 任务规划与SOI计算

轨道力学常数与霍曼转移计算，新增SOI计算功能：

- **GM常量**：所有行星+月球的GM值 (km³/s²)
- **SOI计算**：使用公式 r_SOI = a * (m/M)^(2/5)，自动缓存结果
- **getTargetGM(body)**：获取任意天体的GM值
- **霍曼转移**：计算ΔV预算、转移时间、发射窗口

GM常量表：
```
GM_SUN     = 1.327124e11
GM_MERCURY = 2.2032e4
GM_VENUS   = 3.2486e5
GM_EARTH   = 3.986004e5
GM_MOON    = 4.90486e3
GM_MARS    = 4.2828e4
GM_JUPITER = 1.26687e8
GM_SATURN  = 3.79312e7
GM_URANUS  = 5.79395e6
GM_NEPTUNE = 6.83653e6
```

### B_SOISystem.pde — SOI系统核心

完整的引力影响球系统实现：

```java
// 核心功能
double calculateSOIRadius(body, primary)      // 计算SOI半径
CelestialBody findDominantBody(ship)         // 查找当前主导天体
boolean checkAndProcessSOICrossing(ship, t)  // 检测并处理SOI穿越
void switchToBodyCentric(ship, body, t)      // 切换到天体中心参考系
void switchToHeliocentric(ship, t)           // 切换到日心参考系

// 辅助功能
double[][] getSOIBoundaryPoints(body, n)     // 获取绘制边界点
String getSOIStatusString(ship)              // 获取SOI状态描述
int getSOIColor(body)                         // 获取SOI颜色
```

### F_SOIEvent.pde — SOI事件系统

记录SOI穿越事件：

```java
SOIEvent {
    double timestamp
    SOIEventType type
    CelestialBody bodyA
    CelestialBody bodyB  // SWITCH事件时使用
    double[] spacecraftPos
    double[] spacecraftVel
}

SOIEventLog {
    void addEvent(event)
    void logEnterSOI(t, body, pos, vel)
    void logExitSOI(t, body, pos, vel)
    void logSwitchSOI(t, from, to, pos, vel)
    List<SOIEvent> getRecentEvents(n)
}
```

### D_PhysicsEngine.pde — 牛顿力学积分引擎

**半隐式欧拉积分**，固定子步长 `FIXED_SUBSTEP = 1s`：

```
每个子步:
1. ForceModel.computeForce(pos, vel) → [gx, gy]
2. vel += accel × step
3. pos += vel × step
```

### D_OrbitPropagator.pde — 开普勒轨道传播器

"On rails"模式，纯解析计算：

- **日心传播** — 标准开普勒方程：`M = M0 + n·t`，`solveKepler(M,e)` 得到 E，转换到 ν 得到位置
- **圆形轨道传播** — 高频优化路径：`orbitAngle = launchPadAngle + ω × (t - orbitStartTime)`
- **密切轨道计算** — 从任意 `(pos, vel)` 反推轨道根数 `(a,e,i,ω,w,M)`

### D_FlightComputer.pde — 飞行计算机/制导算法

所有制导算法集中于此，纯函数式（输入状态，输出方向）：

#### 上升段重力转弯
```
burnTime < 10s:  纯垂直
burnTime > 10s:  pitchAngle = (alt / 420)^0.7 × 85°
```

#### PEG 圆化制导
```
pitchOffset = -K_ALT × altError - K_VRAD × vRad
thrustDir = tangential × cos(pitchOffset) + radial × sin(pitchOffset)
```

#### 转移燃烧方向
- **TMI** — 地球相对切向（顺行）
- **TOI** — 速度矢量方向

#### 辅助计算函数
- `apoapsisAltitude()` / `periapsisAltitude()` — 瞬时轨道计算
- `timeToApoapsis()` — 到达远地点时间估算
- `estimateThrustFraction()` — 上升段精确切断逻辑

### D_GuidanceSystem.pde — 制导系统

从 Spacecraft 中独立出来的制导状态机：

- **上升段制导** — 重力转弯 + 精确推力切断 + 远地点检测
- **圆化段制导** — PEG 制导 + 燃烧计时完成判断
- **显示角度计算** — 为 Spacecraft 提供目标角度

主要方法：
```java
void update(Spacecraft ship, double simDt, double simTime)
double computeTargetDisplayAngle(Spacecraft ship, double simTime)
```

### D_AtmosphereModel.pde — 大气模型

指数密度剖面（地球）：
```
ρ = ρ0 × exp(-alt / H)
ρ0 = 1.225e9 kg/km³  (海平面)
H = 8.5 km            (标高)
```

大气截止高度：
- **地球** — 140 km
- **火星** — 80 km
- **金星** — 250 km

阻力计算：
```
a_drag = 0.5 × Cd × A × ρ × v² / mass
```

参数：
- `Cd = 0.5` (箭体阻力系数)
- `A = π × (3m)^2` (6m 直径火箭横截面积)
- `mass = 500,000 kg` (猎鹰 9 级)

### SolarSystem.pde — 太阳系初始化

包含太阳、8大行星、月球卫星系统：
- **太阳**：中心天体，GM_SUN = 1.327124e11 km³/s²
- **行星**：水星、金星、地球、火星、木星、土星、天王星、海王星
- **卫星**：月球（绕地球运行）

所有天体都配置了GM值用于SOI计算。

```java
List<CelestialBody> getAllBodies()  // 获取太阳+行星+卫星
CelestialBody getEarth()            // 快速获取地球
```

### Spacecraft.pde — 纯状态容器

核心状态：
- **位置速度**：`pos` / `vel` 数组（兼容旧接口：`earthRelPos` / `earthRelVel`）
- **中心天体**：`currentCentralBody`（兼容旧接口：`earthRelative` / `earthRef`）
- **任务状态**：`state`（ShipState 枚举）
- **显示角度**：`displayAngle` / `angularVelocity` / `angularAcceleration`

核心更新逻辑：
- **发射/圆化阶段**：调用 GuidanceSystem 处理制导
- **轨道阶段**：OrbitPropagator 解析圆形轨道传播
- **显示角度平滑**：独立 PD 控制器，使用模拟时间，大时间步长拆分为 60fps 子步确保稳定

```java
void updateBodyRelative(double t, double simDt) {
    if (state == LAUNCHING || state == CIRCULARIZING) {
        guidanceSystem.update(this, simDt, simTime);
    } else if (state == ORBIT) {
        orbitPropagator.propagateCircularOrbit(...);
    }
    updateDisplayAngleSmooth(simTime, simDt);
}
```

### LaunchController.pde — 纯任务状态机

不再包含任何物理计算，只处理：
- 阶段切换
- 事件检测（等待窗口→TMI→接近→TOI）
- 时间保护逻辑（自动降速/跳转/锁定）

状态驱动，每个阶段调用对应的 `monitorXXX()` 或 `updateXXX()`。

## 状态机

```
IDLE → COUNTDOWN → IGNITION → LAUNCHING → CIRCULARIZING → ORBIT
                                                              ↓
                                              WAITING_FOR_WINDOW → TMI_BURN → TRANSFER
                                                                                   ↓
                                                                         APPROACHING_TARGET → TOI_BURN → CAPTURED
```

| 状态 | 说明 |
|------|------|
| `IDLE` | 飞船在发射台待命 |
| `COUNTDOWN` | 发射倒计时（10s） |
| `IGNITION` | 点火（2s） |
| `LAUNCHING` | 主动段上升 + 滑行至远地点 |
| `CIRCULARIZING` | 在远地点附近做圆化机动 |
| `ORBIT` | 圆形 LEO 轨道，可选择目标行星 |
| `WAITING_FOR_WINDOW` | 等待行星际发射窗口，自动降速保护 |
| `TMI_BURN` | 行星际注入燃烧（Trans-Mars Injection） |
| `TRANSFER` | 霍曼转移至目标行星，自动降速至接近段 |
| `APPROACHING_TARGET` | 接近目标行星，自动降速至 TOI |
| `TOI_BURN` | 目标轨道插入燃烧（Target Orbit Insertion） |
| `CAPTURED` | 被目标行星捕获，在目标轨道运行 |

## 时间控制系统

三重保护机制确保关键事件不被跳过：

| 保护层 | 机制 | 作用 |
|-------|------|------|
| 第一重 | 事件跳转检测 | 下帧会跳过关键事件时，自动跳至事件前 15 秒并锁住 1x |
| 第二重 | 燃烧阶段解锁 | TMI/TOI 燃烧阶段允许用户自由加速 |
| 第三重 | 子步保护 | 帧级检查确保不会因大时间步长跳过关键事件 |

## 技术约束

- **不实现**：燃料消耗、助推器分离、多级火箭
- **不实现**：交会对接、兰伯特问题求解
- **实现**：大气阻力（指数模型）
- **实现**：KSP 风格 "on rails"/"not on rails" 模式切换
- **表现层实现**：RCS 姿态控制（角速度/角加速度平滑 + RCS 喷口羽流动画），不影响轨道物理；RCS 羽流采用脉冲喷射模式（小推力：低频短脉冲，大推力：高频长脉冲，尺寸固定清晰可见）
- **简化**：所有轨道为 2D 平面（z=0），发射场固定在向阳面
- **精度**：固定 1s 子步长，适合实时可视化而非高精度轨道预报

## 快捷键

| 按键 | 功能 |
|------|------|
| `Space` / `P` | 暂停/恢复 |
| `Q` / `E` | 降低/增加时间加速 |
| `V` | 切换 Map View / Ship View |
| `F` | 聚焦重置（目标缩放更小时第一次直接缩放到位） |
| `O` | 切换轨道线显示 |
| `K` | 切换SOI边界显示 |
| `L` | 发射飞船 / 切换标签显示 |
| `T` | 执行转移 / 切换尾迹显示 |
| `ESC` | 关闭弹窗 |
| 滚轮 | 缩放 |
| 拖拽 | 平移 |
| 双击 | 聚焦点击的天体或飞船 |
