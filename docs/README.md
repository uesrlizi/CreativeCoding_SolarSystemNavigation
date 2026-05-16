# Spacecraft Launch Simulator

基于 Processing (Java Mode) 的航天器发射入轨模拟器，使用开普勒轨道力学进行物理计算。支持从地球表面发射航天器至近地轨道（LEO），以及后续的霍曼转移至其他行星。

## 项目结构

```
SolarSystemNavigation/
├── SolarSystemNavigation.pde   # 主程序入口、setup/draw、全局工具函数
├── A_Enums.pde                 # 枚举定义（ViewMode, ShipState, FrameType, BodyType）
├── B_OrbitalMath.pde           # 开普勒轨道数学（求解/坐标转换）
├── C_TimeManager.pde           # 模拟时间与时间加速
├── D_ReferenceFrame.pde        # 参考系系统（SURFACE/BODY_ORBIT/HELIOCENTRIC）[更新: SOI支持]
├── D_AtmosphereModel.pde       # 大气模型（密度/阻力/截止高度）
├── D_OrbitPropagator.pde       # 开普勒轨道传播器（"on rails"模式）
├── D_FlightComputer.pde        # 飞行计算机/制导算法（重力转弯/PEG/转移燃烧）
├── D_PhysicsEngine.pde         # 牛顿力学积分引擎（"not on rails"模式）
├── CelestialBody.pde           # 天体数据模型与LOD分级绘制[更新: GM/parent/SOI]
├── CelestialBodyRenderer.pde   # 天体细节渲染器（程序化纹理/大气/光环/太阳日珥）
├── SolarSystem.pde             # 太阳系初始化（8大行星 + 太阳）[更新: SOI检测]
├── Spacecraft.pde              # 航天器状态容器 + 调度器[更新: SOI自动切换]
├── SpacecraftRenderer.pde      # 航天器绘制（地图图标 / 飞船视角详细模型）
├── LaunchSite.pde              # 发射场数据模型（地表位置跟踪）
├── LaunchSiteRenderer.pde      # 发射场绘制（发射台/勤务塔/脐带臂/避雷塔/地形）
├── CameraController.pde        # 摄像机控制（平移/缩放/跟随/双视角）
├── MissionPlanner.pde          # 轨道力学常数与霍曼转移计算[更新: 移除硬编码]
├── LaunchController.pde        # 发射流程状态机[更新: SOI集成]
├── E_Button.pde                # 统一按钮组件（hover/点击状态/tooltip）
├── E_Tooltip.pde               # 浮动提示组件（自动定位/文本换行）
├── E_TimeControlPanel.pde      # 左上角时间控制面板
├── E_NavigationFocusPanel.pde  # 左侧导航聚焦面板
├── E_ViewToggleButton.pde      # 右上角视图切换按钮
├── E_ShipStatusPanel.pde       # 右下角飞船状态面板[更新: SOI显示]
└── HUD.pde                     # 总控HUD（编排所有子面板）
```

所有 `.pde` 文件会被 Processing 连接为单一编译单元（按文件名排序），因此跨文件的类和方法可直接引用。

## 核心架构（KSP 风格）

架构设计为类似 Kerbal Space Program 的分层设计，**制导算法与轨道传播分离**：

```
Spacecraft（状态容器 + 调度器）
    ├── [发射/圆化阶段] → 内置子步物理 + 制导状态机
    ├──   ├── 重力转弯（FlightComputer）
    ├──   ├── PEG 圆化（FlightComputer）
    ├──   └── 大气阻力（AtmosphereModel）
    ├── [轨道阶段] → D_OrbitPropagator（开普勒传播）
    └── 显示角度平滑（独立于物理）

LaunchController（纯状态机）
    ├── 任务阶段切换（倒计时→点火→发射→...）
    ├── 时间保护逻辑
    └── 不包含任何物理计算
```

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
| `LAUNCHING` / `CIRCULARIZING` | 内置物理 | 子步迭代，完整制导 |
| `ORBIT` / `TRANSFER` / 其他 | Orbit | 开普勒解析传播 |

### 参考系系统 (FrameType)

- **SURFACE** — 地表坐标系，发射初始阶段
- **BODY_ORBIT** — 行星相对坐标系（地球轨道）
- **HELIOCENTRIC** — 日心坐标系（行星际转移）

### SOI 系统（KSP 风格）

**影响球（Sphere of Influence）**：基于 Hill sphere 近似的物理公式：
```
SOI_radius = a × (m/M)^(2/5)
```
其中：
- `a` — 行星轨道半长轴
- `m` — 行星质量（通过 GM 体现）
- `M` — 太阳质量（GM_SUN）

**SOI 层级**：通过 `CelestialBody.parent` 建立天体父子关系

**SOI 自动切换**：
- `Spacecraft.checkSOISwitch()` — 每帧检测飞船与所有行星的距离
- 进入行星 SOI 时，**自动从日心切换到行星相对坐标系**
- 离开行星 SOI 时，**自动从行星相对切换回日心坐标系**
- 切换时**自动转换位置和速度矢量**（保持轨道一致性）
- 在 `TMI_BURN` / `TOI_BURN` / `LAUNCHING` / `CIRCULARIZING` 燃烧阶段**暂停切换**，避免干扰制导

**HUD 显示**：右下角状态面板显示当前 SOI 主导天体（"SOI: Earth" / "SOI: Sun" / "SOI: Mars" 等）

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
- 渲染器引用：`renderer`（CelestialBodyRenderer实例）

LOD选择完全基于**屏幕半径大小**，不再依赖中心是否在屏幕内，避免平移时跳变。

### D_PhysicsEngine.pde — 牛顿力学积分引擎（预留）

**半隐式欧拉积分**，固定子步长 `FIXED_SUBSTEP = 1s`：

```
每个子步:
1. ForceModel.computeForce(pos, vel) → [gx, gy]
2. vel += accel × step
3. pos += vel × step
```

当前预留用于将来扩展（TMI/TOI 燃烧、行星际物理），**发射/圆化阶段目前直接在 Spacecraft 中实现**（为了精确的每子步制导状态更新）。

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

核心更新逻辑：
- **发射/圆化阶段**：完整的子步物理 + 制导状态机（直接在 Spacecraft 中实现）
  - 主动段重力转弯 + 精确推力切断
  - 远地点检测 + 圆化燃烧中点对齐
  - PEG 制导 + 燃烧计时完成判断
  - 大气阻力计算
- **轨道阶段**：OrbitPropagator 解析圆形轨道传播
- **显示角度平滑**：独立 PD 控制器，使用模拟时间，大时间步长拆分为 60fps 子步确保稳定

```java
void updateBodyRelative(double t, double simDt) {
    if (state == LAUNCHING || state == CIRCULARIZING) {
        // === 物理上升 + 制导状态机 ===
        while (remainingDt > 0) {
            // 重力 + 推力 + 阻力
            // 每子步检查是否开始圆化燃烧
            // 每子步检查是否完成圆化
        }
    } else if (state == ORBIT || state == WAITING_FOR_WINDOW) {
        // === 解析圆形轨道（地球） ===
        orbitPropagator.propagateCircularOrbit(...);
    } else if (state == CAPTURED) {
        // === 解析圆形轨道（目标天体） ===
        orbitPropagator.propagateCircularOrbit(...);
    }
    // === 显示角度更新（与物理同步） ===
    updateDisplayAngle(targetAngle, simDt);  // 内部自动子步
}
```

**关键修复（2026-05-16）**：轨道传播现在完全独立于任务状态——
- `WAITING_FOR_WINDOW` 状态复用 `ORBIT` 逻辑，继续绕地球旋转
- `CAPTURED` 状态使用目标天体 GM 和轨道参数，持续绕目标旋转
- 任何状态下都不会停止轨道传播

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
- **表现层实现**：RCS 姿态控制（角速度/角加速度平滑 + RCS 喷口羽流动画），不影响轨道物理；RCS 羽流采用脉冲喷射模式（小推力：低频短脉冲，大推力：高频长脉冲，尺寸固定清晰可见）
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

## 最近更新

### 2026-05-16 (SOI 系统重构)
- **KSP 风格 SOI 系统完整实现**：
  - `CelestialBody` 新增 `GM`（引力参数）和 `parent`（父天体）字段
  - SOI 半径使用物理公式 `SOI = a * (m/M)^(2/5)`，而非硬编码
  - `SolarSystem.findDominantBody()` — 实时检测给定点在哪个 SOI 内
  - `Spacecraft.checkSOISwitch()` — 每帧检测 SOI 边界，自动切换参考系
  - `Spacecraft.performSOISwitch()` — 执行坐标系转换（位置+速度矢量）
  - SOI 切换在燃烧阶段暂停，避免干扰制导
- **LaunchController 接近阶段优化**：
  - 不再强制在 2xSOI 处切换参考系
  - 等待 Spacecraft 的自动 SOI 切换
  - 进入目标 SOI 后立即开始 TOI 燃烧
- **MissionPlanner 简化**：
  - 所有 GM 值从 `body.GM` 获取，不再硬编码
  - `calculateSOI(body)` 直接调用 `body.getSOIRadius()`
- **ReferenceFrame 更新**：
  - `gm()` 使用 `primaryBody.GM`
  - 支持任意天体的引力计算
- **HUD 显示增强**：
  - 右下角状态面板新增 SOI 信息（"SOI: Earth" / "SOI: Sun" 等）
- **向后兼容**：所有旧接口保持工作

### 2026-05-16 (前半)
- **修复飞船在 WAITING_FOR_WINDOW 和 CAPTURED 状态下停止不动的问题**：
  - 轨道传播与任务状态完全解耦
  - `WAITING_FOR_WINDOW` 复用 `ORBIT` 状态的地球轨道传播逻辑
  - `CAPTURED` 新增目标天体轨道传播（使用目标 GM 和 10x 半径轨道）
  - 任何任务状态下飞船都会持续沿轨道运行
- **天体 LOD 渲染系统重写**：
  - 新增 `CelestialBodyRenderer.pde` 独立渲染模块
  - 完全基于屏幕半径的 LOD 判定（<25/25~90/90~220/>220px）
  - 所有天体使用闭合形状绘制，1.3倍带宽保证重叠无缺口
  - 太阳彻底告别扇形，改用三角形扇形+高细分
  - 超大天体使用扫描线填充避免巨型椭圆性能问题
- **程序化纹理与效果**：
  - 地球：海陆噪点分离 + 大气边缘发光（不遮挡地表）
  - 木星：条纹带 + 大红斑（LOD2+显示）
  - 土星/天王星：三层细节星环系统 + 正确遮挡
  - 太阳：径向噪点 + 日珥脉动 + 多层光晕
- **星环渲染优化**：
  - 统一所有LOD的星环朝向（仅使用ringTilt）
  - 三层细节级别：Simple(LOD0)/Medium(LOD1~2)/Detailed(LOD3)
  - 正确的前后遮挡：先画整环→画行星→画下半圈
  - 星环层使用Perlin噪声实现透明度和颜色变化
- **LOD过渡一致性优化**：
  - 统一所有LOD的行星旋转参数（直接使用 rotation，移除缩放因子）
  - 统一太阳噪声采样坐标（基于角度而非屏幕位置）
  - 增加LOD1/2的条纹带数量（10/14条）
  - LOD0也显示星环和大气（达到阈值后）
- **星空背景优化**：星星数量增加至1500，颜色变异，银河带星云效果
- **修复飞船旋转抖动**：移除 `updateDisplayAngle` 重复调用，统一在 `Spacecraft.update()` 内使用模拟时间更新，大时间步长自动拆分为 60fps 子步保证 PD 控制器稳定
- **优化 RCS 羽流可见性**：从"随推力改变尺寸"改为"脉冲喷射模式"——小推力时低频(2Hz)短脉冲(15%)，大推力时高频(17Hz)长脉冲(90%)，羽流尺寸固定清晰可见
- **修复天体自转跳变**：
  - 移除渲染时 `body.rotation * 0.05` 和 `* 0.1` 的缩放因子
  - 自转现在与公转一样，直接基于 `simTime` 连续计算
  - 符合真实周期数据（地球1天、木星0.41天等）
  - 受时间流速影响，无跳变、无缩放

