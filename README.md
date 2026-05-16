# Spacecraft Launch Simulator

基于 Processing (Java Mode) 的航天器发射入轨模拟器，使用开普勒轨道力学进行物理计算。支持从地球表面发射航天器至近地轨道（LEO），以及后续的霍曼转移至其他行星。

## 项目结构

```
SolarSystemNavigation/
├── SolarSystemNavigation.pde   # 主程序入口、setup/draw、全局工具函数
├── A_Enums.pde                 # 枚举定义（ViewMode, ShipState, FrameType）
├── B_OrbitalMath.pde           # 开普勒轨道数学（求解/坐标转换）
├── C_TimeManager.pde           # 模拟时间与时间加速
├── D_ReferenceFrame.pde        # 参考系系统（SURFACE/BODY_ORBIT/HELIOCENTRIC）
├── D_AtmosphereModel.pde       # 大气模型（密度/阻力/截止高度）
├── D_OrbitPropagator.pde       # 开普勒轨道传播器（"on rails"模式）
├── D_FlightComputer.pde        # 飞行计算机/制导算法（重力转弯/PEG/转移燃烧）
├── D_PhysicsEngine.pde         # 牛顿力学积分引擎（"not on rails"模式）
├── CelestialBody.pde           # 天体数据模型与LOD分级绘制
├── SolarSystem.pde             # 太阳系初始化（8大行星 + 太阳）
├── Spacecraft.pde              # 航天器状态容器 + 调度器
├── SpacecraftRenderer.pde      # 航天器绘制（地图图标 / 飞船视角详细模型）
├── LaunchSite.pde              # 发射场数据模型（地表位置跟踪）
├── LaunchSiteRenderer.pde      # 发射场绘制（发射台/勤务塔/脐带臂/避雷塔/地形）
├── CameraController.pde        # 摄像机控制（平移/缩放/跟随/双视角）
├── MissionPlanner.pde          # 轨道力学常数与霍曼转移计算
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

## 核心架构（KSP 风格）

架构重构为类似 Kerbal Space Program 的分层设计，把**轨迹模拟**与**飞行控制**完全分离：

```
Spacecraft（状态容器 + 调度器）
    ├── D_ReferenceFrame（参考系切换）
    ├── needsPhysics() → 选择模式
    ├── [Physics Mode] → D_PhysicsEngine（牛顿积分）
    ├──   └── SpacecraftForceModel（重力+推力+阻力）
    ├── [Orbit Mode] → D_OrbitPropagator（开普勒传播）
    └── D_FlightComputer（制导算法）

LaunchController（纯状态机）
    ├── 任务阶段切换
    ├── 时间保护逻辑
    └── 不包含任何物理计算
```

### 物理/轨道模式自动切换

飞船根据当前状态和环境自动选择模式：

| 条件 | 模式 | 说明 |
|------|------|------|
| `thrustActive = true` | Physics | 发动机工作，子步积分 |
| `inAtmosphere = true` | Physics | 在大气层内（地球 <140km），有阻力 |
| `state = LAUNCHING` | Physics | 上升段主动控制 |
| `state = CIRCULARIZING` | Physics | 圆化段 PEG 制导 |
| 其他状态（ORBIT/TRANSFER等） | Orbit | 开普勒解析传播，无物理计算开销 |

### 参考系系统 (FrameType)

- **SURFACE** — 地表坐标系，发射初始阶段
- **BODY_ORBIT** — 行星相对坐标系（地球轨道）
- **HELIOCENTRIC** — 日心坐标系（行星际转移）

## 核心模块详解

### D_PhysicsEngine.pde — 牛顿力学积分引擎

**半隐式欧拉积分**，固定子步长 `FIXED_SUBSTEP = 1s`，`maxSubSteps` 防止锁帧：

```
每个子步:
1. ForceModel.computeForce(pos, vel) → [gx, gy]
2. vel += accel × step
3. pos += vel × step
```

- **力模型可配置** — 通过抽象类 `ForceModel` 注入具体计算
- **事件检测** — 子步内可检测坠毁、逃逸等状态变化
- **精度保障** — 固定 1s 子步，适合实时可视化

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

### Spacecraft.pde — 状态容器 + 调度器

重构后精简为约 300 行，核心只有 `update()`：

```java
void update(double t) {
    double simDt = t - lastUpdateTime;
    boolean needsPhysics = thrustActive ||
        (frame != null && frame.inAtmosphere(earthRelPos)) ||
        state == LAUNCHING ||
        state == CIRCULARIZING ||
        state == TMI_BURN;

    if (needsPhysics) {
        physicsEngine.integrate(earthRelPos, earthRelVel, simDt, forceModel);
    } else {
        orbitPropagator.propagateCircularOrbit(...);
    }

    updateDisplayAngle(...);
}
```

### LaunchController.pde — 纯任务状态机

不再包含任何物理计算，只处理：
- 阶段切换
- 事件检测（等待窗口→TMI→接近→TOI）
- 时间保护逻辑（自动降速/跳转/锁定）

状态驱动，每个阶段调用对应的 `monitorXXX()` 或 `updateXXX()`。

## 状态机（未改动）

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

## 时间控制系统（未改动）

三重保护机制确保关键事件不被跳过：

| 保护层 | 机制 | 作用 |
|-------|------|------|
| 第一重 | 事件跳转检测 | 下帧会跳过关键事件时，自动跳至事件前 15 秒并锁住 1x |
| 第二重 | 燃烧阶段解锁 | TMI/TOI 燃烧阶段允许用户自由加速 |
| 第三重 | 子步保护 | 帧级检查确保不会因大时间步长跳过关键事件 |

## 技术约束更新

- **不实现**：燃料消耗、助推器分离、多级火箭
- **不实现**：交会对接、兰伯特问题求解
- **实现**：大气阻力（指数模型）
- **实现**：KSP 风格 "on rails"/"not on rails" 模式切换
- **表现层实现**：RCS 姿态控制（角速度/角加速度平滑 + RCS 喷口羽流动画），不影响轨道物理
- **简化**：所有轨道为 2D 平面（z=0），发射场固定在向阳面
- **精度**：固定 1s 子步长，适合实时可视化而非高精度轨道预报

## 快捷键（未改动）

| 按键 | 功能 |
|------|------|
| `Space` / `P` | 暂停/恢复 |
| `Q` / `E` | 降低/增加时间加速 |
| `V` | 切换 Map View / Ship View |
| `F` | 聚焦重置（目标缩放更小时第一次直接缩放到位） |
| `O` | 切换轨道线显示 |
| `L` | 发射飞船 / 切换标签显示 |
| `T` | 执行转移 / 切换尾迹显示 |
| `ESC` | 关闭弹窗 |
| 滚轮 | 缩放 |
| 拖拽 | 平移 |
| 双击 | 聚焦点击的天体或飞船 |

