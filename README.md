# Spacecraft Launch Simulator

基于 Processing (Java Mode) 的航天器发射入轨模拟器，使用开普勒轨道力学进行物理计算。支持从地球表面发射航天器至近地轨道（LEO），以及后续的霍曼转移至其他行星。

## 项目结构

```
SolarSystemNavigation/
├── SolarSystemNavigation.pde   # 主程序入口、setup/draw、全局工具函数
├── A_Enums.pde                 # 枚举定义（ViewMode, ShipState）
├── B_OrbitalMath.pde           # 开普勒轨道数学（求解/坐标转换）
├── C_TimeManager.pde           # 模拟时间与时间加速
├── CelestialBody.pde           # 天体数据模型与LOD分级绘制
├── SolarSystem.pde             # 太阳系初始化（8大行星 + 太阳）
├── Spacecraft.pde              # 航天器物理模拟（上升/圆化/入轨）
├── SpacecraftRenderer.pde      # 航天器绘制（地图图标 / 飞船视角详细模型）
├── LaunchSite.pde              # 发射场数据模型（地表位置跟踪）
├── LaunchSiteRenderer.pde      # 发射场绘制（发射台/勤务塔/脐带臂/避雷塔/地形）
├── CameraController.pde        # 摄像机控制（平移/缩放/跟随/双视角）
├── MissionPlanner.pde          # 轨道力学常数与霍曼转移计算
├── LaunchController.pde        # 发射流程状态机
├── LaunchUI.pde                # 发射面板交互逻辑
├── LaunchPanels.pde            # 发射面板UI绘制
├── D_ShipViewHUD.pde           # 飞船视角HUD叠加层
└── HUD.pde                     # 主HUD（信息面板/天体列表/动态缩放单位）
```

所有 `.pde` 文件会被 Processing 连接为单一编译单元（按文件名排序），因此跨文件的类和方法可直接引用。

## 核心架构

### 状态机

```
IDLE → COUNTDOWN → IGNITION → LAUNCHING → CIRCULARIZING → ORBIT → TRANSFER → ORBIT (目标行星)
```

| 状态 | 含义 |
|------|------|
| `IDLE` | 飞船在发射台待命 |
| `COUNTDOWN` | 发射倒计时（10s） |
| `IGNITION` | 点火（2s） |
| `LAUNCHING` | 主动段上升 + 滑行至远地点 |
| `CIRCULARIZING` | 在远地点附近做圆化机动 |
| `ORBIT` | 圆形 LEO 轨道，可选择目标行星 |
| `TRANSFER` | 霍曼转移至目标行星（无法干预） |

状态管理由 `LaunchController` 负责，航天器内部也有 `ShipState` 用于物理计算分支。

### 坐标系统

- **日心坐标系** (heliocentric)：以太阳为中心，z=0 平面，天体轨道由开普勒元素描述
- **地球相对坐标系** (earth-relative)：发射和圆化阶段使用，以地心为原点，位置和速度均相对于地球

航天器完成圆化并入轨后，切换到纯日心模式。霍曼转移时从地球相对速度叠加地球日心速度，转换为日心开普勒轨道。

### 天体 LOD 渲染

天体根据摄像机距离采用四级 LOD 策略，在性能和视觉之间平衡：

| LOD | 条件 | 绘制方式 | 说明 |
|-----|------|----------|------|
| 0 — 微小 | 视半径极小 | 最小 2px 椭圆 | 远距离仍可见，不丢失 |
| 1/2 — 常规 | 圆心在屏幕内 | 单层椭圆 + clamp 半径（≤ 3×屏幕尺寸） | 无光晕，减少填充 |
| 3 — 近地表 | 圆心在屏幕外，圆与屏幕相交 | **逐行扫描填充** | 飞船贴地视角的关键优化 |
| 4 — 覆盖全屏 | 屏幕四角均在圆内 | `rect(0,0,w,h)` 单矩形 | 开销最低 |

**LOD 3 详情（`drawGroundScanline`）：**

当摄像机接近天体表面时（如飞船视角贴地飞行），天体圆心会偏离屏幕极远（百万像素级），同时视半径极大。此时若直接画椭圆，`Ellipse2D.Float` 的 float 精度在极端坐标下会产生斑马纹状撕裂伪影。

解决方案：逐行扫描屏幕每一行像素，用 **double** 精度计算该行被圆覆盖的 x 范围，clamp 到屏幕宽度后以 `QUADS` 绘制。所有输出坐标均在屏幕范围内，彻底规避大数值 float 精度问题。扫描结果合并到单个 `beginShape(QUADS)` 调用，N 行屏幕仅产生一次 GPU/渲染管线提交。

### 帧率无关设计

所有实时动画和插值通过 `deltaTime`（墙钟秒数）驱动，而非 `frameCount`：

- **摄像机平滑**：平移和缩放采用 `1 - exp(-speed × dt)` 指数衰减，任意帧率下收敛速度一致
- **模拟时间推进**：`simTime += timeWarp × DAY_S × dt`，时间加速倍率基于真实秒而非帧数
- **动画效果**：引擎火焰抖动、IGNITION 文字脉冲等改用 `millis() / 1000.0` 计时

`dt` 在每帧 `draw()` 开头由 `(millis() - lastFrameMillis) / 1000.0` 计算，钳制在 0~0.5s 防止切窗回来时的大跳跃。

### 动态缩放单位

HUD 缩放显示根据当前比例尺自动切换单位（`formatScale`）：

| 范围 | 单位 | 场景 |
|------|------|------|
| ≥ 10⁶ km/px | AU/px | 太阳系尺度 |
| ≥ 1 km/px | km/px | 行星尺度 |
| ≥ 0.001 km/px | m/px | 飞船贴地尺度 |
| < 0.001 km/px | mm/px | 极近距离 |

避免在飞船视角下看到 `0.0000 AU/px` 的无意义读数。

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

**表现层角动态** — 不影响物理，仅用于平滑显示：

飞船实际指向由 `displayAngle` 驱动，通过 PD 控制器跟踪物理目标角度：
- 角加速度（`MAX_ANGULAR_ACCEL = 8 rad/s²`）和角速度（`MAX_ANGULAR_VELOCITY = 3 rad/s`）钳制，模拟 RCS 的物理限制
- `ANGLE_KP = 10.0`（位置增益）、`ANGLE_KD = 6.0`（速度阻尼），到达目标时自动减速无超调
- `computeTargetWorldAngle()` — 根据当前飞行状态计算物理目标指向（IDLE 时指向地心径向，LAUNCHING 时跟随俯仰程序，ORBIT 时指向切向）
- `updateDisplayAngle()` — 每帧用真实 `deltaTime` 驱动，时间加速下平滑度不变

### SpacecraftRenderer.pde — 航天器绘制

两种绘制模式，根据当前视角自动切换：

**地图图标** (`drawMapIcon`)：居中箭头（chevron）图标，范围 ±0.8s（s=9px），原点在图标几何中心。无光晕，简洁清晰。

**飞船视角模型** (`drawShipViewModel`)：详细的多级火箭侧视图，原点在飞船几何中心（发动机喷口 X=-0.45bl 到整流罩尖 X=0.57bl，中心 X=0.06bl）。

绘制顺序（从尾到头）：
1. 发动机尾焰（5 个喷口，带动画马赫环）
2. 发动机喷管（5 个，梅花布局）
3. 发动机舱段（锥形推力结构）
4. 一级箭体（圆柱段 + 彩色装饰带）
5. 格栅翼（4 片展开状态）
6. 级间段（锥形适配器）
7. 二级箭体（圆柱段 + 装饰带）
8. 整流罩（ogive 曲线，24 段拟合）
9. 箭体面板线
10. **RCS 喷口**（4 组：前/后 × 上/下，外壳始终可见 + 羽流仅机动时显示）
11. 导航灯（红/绿/白频闪）

**RCS 喷口机制：**
- 4 组喷口外壳始终可见（暗灰色矩形凸起 + 喷嘴黑点），分布在整流罩前段和一级箭体中段
- 羽流仅在角活动量超过阈值时显示：活动量 = `|角加速度|/MAX + |角速度|/MAX`
- 激活规则：`accel > 0`（加速顺时针）→ 前-上 + 后-下喷口；`accel < 0`（加速逆时针）→ 前-下 + 后-上喷口
- 羽流采用三级渲染（外层冷蓝白 / 中层 / 内核亮点），sqrt 曲线使微弱修正也能看到小 puff，强机动时羽流更大更亮
- 用 `millis()` 驱动的振荡动画，各喷口相位不同避免同步脉冲

飞船原点（世界坐标 `px,py` 在绘图中的位置）通过 `translate(-bl*0.06, 0)` 对齐到几何中心，使摄像机聚焦在飞船中部而非尾焰。

### LaunchSite.pde — 发射场数据

发射场位于地球向阳面表面，角度 `baseAngle` 由初始化时太阳方向决定：

```
px = earth.px + EARTH_RADIUS * cos(baseAngle)
py = earth.py + EARTH_RADIUS * sin(baseAngle)
```

每帧 `update()` 跟随地球轨道运动，确保发射场始终锚定在地表。

### LaunchSiteRenderer.pde — 发射场绘制

仅在飞船视角（SHIP_VIEW）下绘制。坐标系经过旋转使 +X=地表切向，-Y=径向向外（上方）。

发射场设施层次：
- 地形（地层纹理、草皮、砾石护堤）
- 通道（路面 + 路肩 + 中心虚线）
- 火焰导流槽（楔形偏转板 + 烧蚀痕迹）
- 混凝土发射台（斜面/高光/伸缩缝/支柱）
- 勤务塔（柱体 + X 撑 + 电梯井 + 6 层平台 + 天线）
- 脐带臂（4 个可摆动臂 + 尾部服务桅杆 cryo 软管）
- 固定臂（4 个，钳制在发射台表面）
- 避雷系统（两座高塔 + 悬链线 + 接地缆）
- 附属建筑（掩体/设备间/燃料储罐/水塔）
- 排焰管道（台面以下）

发射台表面高度 `padSurfY = -bl*0.10`（地表以上），与飞船发动机喷口位置对齐。飞船初始 `launchAltitude = 0.0488 km` 使发动机精确落在台面上。

### SolarSystemNavigation.pde — 主程序

- `settings()`: 全屏 JAVA2D 渲染模式
- `setup()`: 初始化所有全局对象（摄像机/太阳系/飞船/HUD），每次启动从 simTime=0 开始
- `draw()`: 每帧更新时间 → 太阳系 → 飞船 → 绘制星空/轨道/天体（LOD）/飞船/HUD
- 轨道力学拆分至 `B_OrbitalMath.pde`：`solveKepler()`, `orbitalToCartesian()`, `cartesianToKepler()`, `orbitalVelocityToCartesian()`
- 时间管理拆分至 `C_TimeManager.pde`：模拟时间 + 8 级时间加速（1:1 到 100 天/秒），基于真实墙钟 deltaTime 推进，帧率无关
- 交互：双击聚焦、拖拽平移、滚轮缩放、键盘快捷键

### LaunchController.pde — 状态流程

- `startLaunch()`: 启动发射倒计时，不改变飞船位置和摄像机视角
- `initiateTransfer()`: 将地球相对运动转换为日心开普勒轨道，计算霍曼转移参数
- `update()`: 同步飞船子状态到控制器状态，监控转移完成
- 时间加速仅在主动物理阶段（LAUNCHING/CIRCULARIZING）上限锁为 3 档（10 分钟/秒），防止大时间步长导致积分误差

### CameraController.pde — 摄像机

两种视角模式：
- **MAP_VIEW**: 2D 正交俯视图，跟随聚焦天体/飞船，支持偏移和缩放
- **SHIP_VIEW**: 以飞船为中心自动放大至飞船尺度，其他天体相对显示

缓动插值使用指数衰减公式 `1 - exp(-speed × dt)` 实现平滑过渡（scale speed=6.0, offset speed=10.0，等价于 60fps 下的 0.1/0.15 lerp），帧率无关。模式切换时保存/恢复各自的缩放状态。天体 LOD 层级由摄像机距离和 scale 决定。

### HUD.pde — 界面

- 左上角：模拟时间、时间加速、**动态缩放单位**（AU/km/m/mm 自动切换）、快捷键提示
- 左下角：天体列表（点击选中，双击聚焦，Snap 按钮重置视角）
- 右侧 Ship View 叠加层（`D_ShipViewHUD.pde`）：速度表、引擎状态、轨道数据
- 嵌入 `LaunchUI` 组件
- `formatScale()`: 根据 `kmPerPixel` 值自动选择最佳显示单位

### LaunchUI.pde — 发射交互

- 底部面板：发射控制按钮 + 飞船状态显示
- 右侧面板：飞船实时数据（高度/速度/远地点/近地点进度条）+ 目标行星列表
- 支持鼠标点击和键盘快捷键（L 发射 / T 转移）

### MissionPlanner.pde — 轨道常数与计算

- 天体常数：`GM_EARTH`, `GM_SUN`, `EARTH_RADIUS_KM = 6371`, `LEO_ALTITUDE_KM = 420`
- 霍曼转移计算：半长轴、离心率、转移时间、Δv

## 发射流程详解

```
1. 用户按 L 键 → COUNTDOWN (10s)
2. IGNITION (2s): 显示点火特效
3. LAUNCHING (thrust=true):
   ├─ 0-10s:   纯垂直上升
   ├─ 10s-切断: 高度俯仰程序 (alt/420)^0.7 × 85°
   └─ 远地点=420km → 精确分数子步切断 (thrustActive=false)
4. LAUNCHING (thrust=false): 滑行至远地点
   └─ timeToApoapsis < burnTime/2 → CIRCULARIZING (thrustActive=true)
5. CIRCULARIZING: PEG固定目标反馈制导
   └─ 近地点 ≥ 419km → finalizeOrbitInsertion() → ORBIT
6. ORBIT: 圆形LEO轨道，可选择目标行星
7. 选择目标 + T 键 → 霍曼转移 → 到达目标行星轨道
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
| `L` | 发射飞船 / 切换标签显示 |
| `T` | 执行转移 / 切换尾迹显示 |
| `ESC` | 关闭弹窗 |
| 滚轮 | 缩放 |
| 拖拽 | 平移 |
| 双击 | 聚焦点击的天体或飞船 |

## 技术约束

- **不实现**：燃料消耗、助推器分离、多级火箭、大气阻力
- **不实现**：交会对接、兰伯特问题求解
- **表现层实现**：RCS 姿态控制（角速度/角加速度平滑 + RCS 喷口羽流动画），不影响轨道物理
- **简化**：所有轨道为 2D 平面（z=0），发射场固定在向阳面
- **精度**：固定 1s 子步长，适合实时可视化而非高精度轨道预报
