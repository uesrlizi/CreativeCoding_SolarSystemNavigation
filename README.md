# Spacecraft Launch Simulator

基于 Processing (Java Mode) 的航天器发射入轨模拟器，使用开普勒轨道力学进行物理计算。支持从地球表面发射航天器至近地轨道（LEO），以及后续的霍曼转移至其他行星。

## 项目结构

```
SolarSystemNavigation/
├── SolarSystemNavigation.pde   # 主程序入口、setup/draw、全局工具函数
├── CelestialBody.pde           # 天体数据模型与绘制
├── SolarSystem.pde             # 太阳系初始化（8大行星数据）
├── Spacecraft.pde              # 航天器物理模拟（上升/圆化/入轨）
├── CameraController.pde        # 摄像机控制（平移/缩放/跟随/双视角）
├── MissionPlanner.pde          # 轨道力学常数与霍曼转移计算
├── LaunchController.pde        # 发射流程状态机
├── LaunchUI.pde                # UI：发射面板/飞船状态/目标选择/弹窗
├── HUD.pde                     # 信息面板/天体列表/飞船视角叠加层
└── SaveDataManager.pde         # 模拟时间存档

docs/specs/
├── 2026-05-08-sun-glow-zoom-design.md
├── 2026-05-09-spacecraft-launch-design.md  # 原始设计文档
```

所有 `.pde` 文件会被 Processing 连接为单一编译单元（按文件名排序），因此跨文件的类和方法可直接引用。

## 核心架构

### 状态机

```
IDLE → LAUNCHING → CIRCULARIZING → ORBIT → TRANSFER → ORBIT (目标行星)
```

| 状态 | 含义 |
|------|------|
| `IDLE` | 无活跃飞船，可发射新飞船 |
| `LAUNCHING` | 主动段上升 + 滑行至远地点 |
| `CIRCULARIZING` | 在远地点附近做圆化机动 |
| `ORBIT` | 圆形 LEO 轨道，可选择目标行星 |
| `TRANSFER` | 霍曼转移至目标行星（无法干预） |

状态管理由 `LaunchController` 负责，航天器内部也有 `ShipState` 用于物理计算分支。

### 坐标系统

- **日心坐标系** (heliocentric)：以太阳为中心，z=0 平面，天体轨道由开普勒元素描述
- **地球相对坐标系** (earth-relative)：发射和圆化阶段使用，以地心为原点，位置和速度均相对于地球

航天器完成圆化并入轨后，切换到纯日心模式。霍曼转移时从地球相对速度叠加地球日心速度，转换为日心开普勒轨道。

## 模块说明

### Spacecraft.pde — 核心物理

航天器类，处理三种运动模式：

**1. 日心轨道运动** (`updateHeliocentric`)

由开普勒元素 `(a, e, i, ω, Ω, M0)` 解析位置。用于转移阶段和在轨阶段。

**2. 地球相对运动** (`updateEarthRelative`) — 发射与圆化

采用半隐式欧拉积分，固定子步长 `FIXED_SUBSTEP = 1s`，每个子步内：

- 计算重力加速度 `g = GM/r²`
- 若推力激活，叠加推力加速度（`THRUST_ACCEL = 0.025 km/s² ≈ 2.5g`）
- 速度更新 → 位置更新

**上升段推力方向** — 基于高度的主动俯仰程序：

```
pitchAngle = (alt / 420)^0.7 × 85°
```

- 0-10s：纯垂直上升（清除大气层）
- 10s+：随高度增加逐渐倾斜，推力方向 = radial × cos(θ) + tangential × sin(θ)

**精确切断** — 当完整推力子步后远地点超过 420km 时，计算分数推力使远地点恰好命中目标。

**圆化段推力方向** — PEG 风格固定目标反馈制导：

```
pitchOffset = -K_ALT × altError - K_VRAD × vRad
thrustDir = tangential × cos(pitchOffset) + radial × sin(pitchOffset)
```

目标是**固定**的 LEO 圆形轨道（半径 6791km），而非"当前高度对应的圆轨道速度"。通过高度误差和径向速度的反馈，主动维持远地点在目标值，避免高度衰减。

**关键方法：**
- `computeApoapsis()` / `computePerigee()` — 用活力公式从瞬时状态计算密切轨道的远/近地点
- `timeToApoapsis()` — 通过偏近点角计算到达远地点的时间，用于确定圆化点火时机
- `finalizeOrbitInsertion()` — 圆化完成时，将速度和位置重置为精确圆形轨道

### SolarSystemNavigation.pde — 主程序

- `setup()`: 全屏模式，初始化所有全局对象，加载存档
- `draw()`: 每帧更新时间 → 太阳系 → 飞船 → 绘制星空/轨道/天体/飞船/HUD
- 轨道力学工具函数：`solveKepler()`, `orbitalToCartesian()`, `cartesianToKepler()`, `orbitalVelocityToCartesian()`
- `TimeManager` 内部类：模拟时间 + 9 级时间加速（1:1 到 1000 天/秒）
- 交互：双击聚焦、拖拽平移、滚轮缩放、键盘快捷键

### LaunchController.pde — 状态流程

- `startLaunch(name)`: 在地球向阳面地表创建飞船，摄像机拉近至地球尺度
- `initiateTransfer()`: 将地球相对运动转换为日心开普勒轨道，计算霍曼转移参数
- `update()`: 同步飞船子状态（LAUNCHING/CIRCULARIZING/ORBIT）到控制器状态；监控转移完成
- 时间加速在近地阶段上限锁为 3 档（10 分钟/秒），防止大时间步长导致积分误差

### CameraController.pde — 摄像机

两种视角模式：
- **MAP_VIEW**: 俯视图，跟随聚焦天体/飞船，支持偏移和缩放
- **SHIP_VIEW**: 以飞船为中心，其他天体相对显示

缓动插值（scale lerp 0.1, offset lerp 0.15）实现平滑过渡。

### HUD.pde — 界面

- 左上角：模拟时间、时间加速、缩放、快捷键提示
- 左下角：天体列表（点击选中，双击聚焦，Snap 按钮重置视角）
- 右侧 Ship View 叠加层：速度表、引擎状态、轨道数据
- 嵌入 `LaunchUI` 组件

### LaunchUI.pde — 发射交互

- 底部面板：发射控制按钮 + 飞船状态
- 右侧面板：飞船实时数据（高度/速度/远地点/近地点进度条）+ 目标行星列表
- 模态弹窗：命名新飞船 + 发射按钮
- 支持鼠标点击和键盘输入

### MissionPlanner.pde — 轨道常数与计算

- 天体常数：`GM_EARTH`, `GM_SUN`, `EARTH_RADIUS_KM = 6371`, `LEO_ALTITUDE_KM = 420`
- 霍曼转移计算：半长轴、离心率、转移时间、Δv

## 发射流程详解

```
1. 用户点击 [+ New Ship] → 弹出命名窗口
2. 输入名称，点击 Launch → IDLE → LAUNCHING
3. LAUNCHING (thrust=true):
   ├─ 0-10s:   纯垂直上升
   ├─ 10s-切断: 高度俯仰程序 (alt/420)^0.7 × 85°
   └─ 远地点=420km → 精确分数子步切断 (thrustActive=false)
4. LAUNCHING (thrust=false): 滑行至远地点
   └─ timeToApoapsis < burnTime/2 → CIRCULARIZING (thrustActive=true)
5. CIRCULARIZING: PEG固定目标反馈制导
   └─ 近地点 ≥ 419km → finalizeOrbitInsertion() → ORBIT
6. ORBIT: 圆形LEO轨道，可选择目标行星
7. 选择目标 + Transfer → 霍曼转移 → 到达目标行星轨道
```

## 物理模型

### 开普勒轨道

行星和日心模式下的飞船按照开普勒轨道运动：

```
M = M₀ + n·t          (平近点角)
M = E - e·sin(E)      (开普勒方程，牛顿法求解)
ν = f(E, e)            (真近点角)
r = a(1-e²)/(1+e·cos(ν))
```

### 密切轨道

发射/圆化阶段通过瞬时位置和速度计算密切开普勒轨道：

```
E = v²/2 - GM/r         (比轨道能量)
a = -GM/(2E)             (半长轴)
h = r × v               (角动量)
e = √(1 - h²/(GM·a))    (离心率)
r_apo = a(1+e)          (远地点)
r_peri = a(1-e)         (近地点)
```

### 上升段俯仰程序

设计原理：主动俯仰程序比纯重力转弯更适合高推重比（TWR ≈ 2.5）的飞行器。重力转弯在高加速度下来不及弯曲弹道，固定时间表俯仰程序参数又难调。高度比例俯仰具有自适应性：

- 低空时接近垂直 → 减少大气阻力和重力损失
- 随高度增加逐渐倾斜 → 积累切向速度
- 指数 0.7 控制弯曲形状（<1 表示早期倾斜更多）

### 圆化段 PEG 反馈制导

不直接切向推进（会导致高度衰减），而是：

- 目标是固定半径的圆形轨道（不是"当前高度对应的圆速度"）
- 高度误差和径向速度反馈产生俯仰修正角
- 推力有径向分量时，主动拉回/推升轨道高度
- 钳位 ±1.2 rad (~69°) 防止反向燃烧

## 快捷键

| 按键 | 功能 |
|------|------|
| `Space` / `P` | 暂停/恢复 |
| `Q` / `E` | 降低/增加时间加速 |
| `V` | 切换 Map View / Ship View |
| `F` | 聚焦重置（第二次回到默认缩放） |
| `O` | 切换轨道线显示 |
| `L` | 切换标签显示 / 打开发射弹窗 |
| `T` | 切换尾迹显示 / 执行转移 |
| `ESC` | 关闭弹窗 |
| 滚轮 | 缩放 |
| 拖拽 | 平移 |
| 双击 | 聚焦点击的天体或飞船 |

## 技术约束

- **不实现**：燃料消耗、助推器分离、多级火箭、大气阻力
- **不实现**：实时姿态控制（RCS）、交会对接、兰伯特问题求解
- **简化**：所有轨道为 2D 平面（z=0），发射场固定在向阳面
- **精度**：固定 1s 子步长，适合实时可视化而非高精度轨道预报
