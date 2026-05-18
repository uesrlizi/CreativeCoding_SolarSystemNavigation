# SolarSystemSpaceflightSim 架构文档

## 概述

太阳系航天模拟游戏重构版本。当前实现：太阳系渲染、摄像机控制、时间流速和UI系统。

## 文件结构

```
SolarSystemSpaceflightSim/
├── ARCHITECTURE.md                    # 本文档
├── SolarSystemSpaceflightSim.pde       # 主程序入口
│
├── Core_*.pde                          # 核心模块
│   ├── Core_Enums.pde                 # 枚举定义
│   ├── Core_Constants.pde             # 物理常数和辅助函数
│   └── Core_OrbitalMath.pde           # 轨道数学库
│
├── SolarSystem_*.pde                   # 太阳系系统
│   ├── SolarSystem_CelestialBody.pde   # 天体数据类
│   ├── SolarSystem_SolarSystem.pde     # 太阳系容器和初始化
│   ├── SolarSystem_CelestialBodyRenderer.pde  # 天体渲染器
│   └── SolarSystem_SOISystem.pde       # SOI（引力影响球）系统
│
├── Camera_*.pde                        # 摄像机系统
│   └── Camera_CameraController.pde     # 摄像机控制器
│
├── Time_*.pde                          # 时间系统
│   └── Time_TimeManager.pde            # 时间管理器
│
└── UI_*.pde                            # UI系统
    ├── UI_Button.pde                  # 通用按钮组件
    ├── UI_Tooltip.pde                 # 工具提示
    ├── UI_TimeControlPanel.pde        # 时间控制面板
    ├── UI_NavigationFocusPanel.pde    # 导航聚焦面板
    └── UI_HUD.pde                     # HUD主控
```

## 模块职责

### 1. 主程序 (SolarSystemSpaceflightSim.pde)

**职责：**
- Processing 标准 setup() / draw() 循环
- 全局系统初始化和管理
- 输入事件处理（鼠标、键盘）
- 渲染管线协调

**主要数据：**
```java
// 全局系统实例
SolarSystem solarSystem;
CameraController camera;
TimeManager timeManager;
HUD hud;
SOISystem soiSystem;

// 显示选项
boolean showOrbits = true;
boolean showLabels = true;
boolean showSOI = false;
```

**渲染顺序：**
1. 星空背景 (drawStars / drawMilkyWay)
2. 行星轨道 (drawOrbits)
3. SOI边界 (drawSOIBoundaries)
4. 太阳 (solarSystem.drawSun)
5. 行星和卫星 (solarSystem.drawPlanets)
6. UI (hud.draw)

### 2. 核心模块 (Core_*)

#### Core_Enums.pde
```java
enum ViewMode { MAP_VIEW, SHIP_VIEW }      // 视图模式
enum BodyType { SUN, TERRESTRIAL, GAS_GIANT, ICE_GIANT }  // 天体类型
```

#### Core_Constants.pde
物理常数定义：
- `AU_KM` - 天文单位（公里）
- `GM_SUN` - 太阳重力参数
- `DAY_S` - 一天的秒数

辅助函数：
- `formatSimTime()` - 格式化模拟时间显示
- `constrainDouble()` - 双精度数范围限制

#### Core_OrbitalMath.pde
轨道数学函数：
- `solveKepler(M, e)` - 解开普勒方程（牛顿迭代法）
- `trueAnomaly(E, e)` - 计算真近点角
- `orbitalToCartesian(a, e, i, Ω, ω, ν)` - 轨道根数转笛卡尔坐标
- `getPositionAtTime(body, t)` - 获取天体在时刻t的位置
- `getVelocityAtTime(body, t)` - 获取天体在时刻t的速度

**轨道根数说明：**
- `a` - 半长轴 (Semi-major axis)
- `e` - 偏心率 (Eccentricity)
- `i` - 轨道倾角 (Inclination)
- `Ω` - 升交点赤经 (Longitude of ascending node)
- `ω` - 近心点幅角 (Argument of periapsis)
- `M0` - 初始平近点角 (Mean anomaly at epoch)

### 3. 太阳系系统 (SolarSystem_*)

#### SolarSystem_CelestialBody.pde
天体数据类，包含：

**轨道属性：**
- 轨道根数 (a, e, i, Ω, ω, M0)
- 轨道周期 (period)
- 当前位置 (px, py, pz)
- 当前真近点角 (currentNu)
- 父天体 (parentBody) - 用于卫星

**物理属性：**
- 半径 (radius)
- 重力参数 (GM)
- 质量 (mass)
- SOI半径 (soiRadius)

**视觉属性：**
- 颜色 (col)
- 类型 (type)
- 自转相关 (rotation, rotationPeriodDays, axialTilt)
- 光环 (hasRing, ringInnerRadius, ringOuterRadius, ringColor, ringTilt)
- 大气层 (hasAtmosphere, atmosphereColor, atmosphereThickness)

**主要方法：**
- `update(t)` - 更新天体位置和自转
- `draw(cam)` - 渲染天体（委托给渲染器）
- `getPosition()` - 获取当前位置

#### SolarSystem_SolarSystem.pde
太阳系容器类，管理所有天体：

**成员：**
```java
CelestialBody sun;
List<CelestialBody> planets;  // 8大行星
List<CelestialBody> moons;    // 卫星
CelestialBodyRenderer renderer;
```

**主要方法：**
- `initialize()` - 初始化整个太阳系
- `initSolarSystem()` - 创建所有天体并设置轨道参数
- `update(t)` - 更新所有天体位置
- `drawSun(cam)` / `drawPlanets(cam)` - 渲染
- `updateRenderer(dt)` - 更新渲染器动画

**初始化的天体：**
1. 太阳
2. 水星
3. 金星
4. 地球 + 月球
5. 火星
6. 木星
7. 土星（有光环）
8. 天王星（有光环）
9. 海王星

#### SolarSystem_CelestialBodyRenderer.pde
天体渲染器，实现 LOD (Level of Detail) 系统：

**LOD等级：**
- `LOD0` - 小尺寸：简单圆形 + 发光
- `LOD1` - 中等尺寸：形状分层着色
- `LOD2` - 大尺寸：更多细节（如木星大红斑）
- `LOD3` - 超大尺寸：完全细节 + 太阳日珥
- `LOD4` - 屏幕级别：扫描线渲染
- `ScanlineLOD` - 介于LOD3和LOD4之间

**特殊效果：**
- 太阳光晕
- 太阳日珥
- 行星光环（含遮挡逻辑）
- 大气层边缘发光
- 带噪声的表面纹理

#### SolarSystem_SOISystem.pde
引力影响球系统：

**主要方法：**
- `calculateSOIRadius(body)` - 计算SOI半径
  - 公式：SOI = a × (GM_body / GM_primary)^(2/5)
- `getSOIColor(body)` - 获取SOI可视化颜色

### 4. 摄像机系统 (Camera_*)

#### Camera_CameraController.pde
摄像机控制器，支持平移、缩放、聚焦：

**状态：**
```java
ViewMode mode;           // 视图模式（MAP_VIEW）
double camX, camY;      // 摄像机位置
double scale;           // 当前缩放
double targetScale;     // 目标缩放（平滑过渡）

// 地图视图状态
double offsetX, offsetY;
double targetOffsetX, targetOffsetY;
CelestialBody focusBody;
```

**主要方法：**
- `initialize(initialScale)` - 初始化
- `update(dt)` - 平滑插值到目标状态
- `focusOn(body)` - 聚焦到指定天体
- `snapFocus()` - 自动缩放和居中到当前聚焦目标
- `worldToScreen(wx, wy)` - 世界坐标转屏幕坐标
- `screenToWorld(sx, sy)` - 屏幕坐标转世界坐标
- `handleMousePressed/Released/Dragged/Wheel()` - 输入处理

### 5. 时间系统 (Time_*)

#### Time_TimeManager.pde
时间管理器，支持时间warp：

**Warp档位：**
```java
0: 1:1 实时
1: 20秒/秒
2: 1分钟/秒
3: 10分钟/秒
4: 1小时/秒
5: 1天/秒
6: 10天/秒
7: 100天/秒
```

**主要方法：**
- `update(dt)` - 推进模拟时间
- `togglePause()` - 暂停/继续
- `increaseWarp()` / `decreaseWarp()` - 调整warp速度
- `formatWarp()` - 格式化warp显示

**数据：**
```java
double simTime;        // 当前模拟时间（秒）
double timeWarp;      // 当前warp倍率
int warpIndex;        // 当前档位索引
```

### 6. UI系统 (UI_*)

#### UI_Button.pde
通用按钮组件：

**特性：**
- 4种视觉状态：normal, hovered, pressed, disabled
- 工具提示支持（延迟显示）
- 点击去重（handledClick标志）

**主要方法：**
- `update()` - 更新状态
- `draw()` - 渲染
- `consumeClick()` - 消费点击事件
- `shouldShowTooltip()` - 是否显示工具提示
- `getTooltipText()` - 获取工具提示文本

#### UI_Tooltip.pde
工具提示组件：

**特性：**
- 自动定位（优先放元素右侧，放不下放左侧）
- 文本自动换行
- 半透明背景

#### UI_TimeControlPanel.pde
时间控制面板（左上角）：

**组件：**
- 暂停/播放按钮
- Warp减速/加速按钮
- 8档时间warp指示器（横向色条）
- 当前warp文本显示

**快捷键：**
- Space - 暂停/继续
- Q - 减速
- E - 加速

#### UI_NavigationFocusPanel.pde
导航聚焦面板（左侧）：

**功能：**
- 显示天体列表（太阳 + 8大行星）
- 显示当前聚焦目标
- 支持单选/双击聚焦
- 支持"Focus"按钮聚焦
- Snap按钮自动缩放

#### UI_HUD.pde
HUD主控，组合所有UI面板：

**职责：**
- 更新所有子面板
- 绘制所有子面板
- 处理鼠标点击（优先级：子面板）
- 管理工具提示显示

**暂停指示：**
- 屏幕底部中心显示红色"PAUSED"

## 数据流

### 主循环 (draw())
```
每帧：
1. 计算deltaTime
2. timeManager.update(dt) - 推进模拟时间
3. solarSystem.update(t) - 更新所有天体位置
4. solarSystem.updateRenderer(dt) - 更新渲染动画
5. camera.update(dt) - 平滑摄像机运动
6. hud.update() - 更新UI状态
7. 渲染所有元素（星空 → 轨道 → SOI → 太阳 → 行星 → UI）
```

### 位置更新 (solarSystem.update(t))
```
太阳：
  - 更新自转（从初始角度计算，无累积误差）

行星：
  - 解开普勒方程求E
  - 计算真近点角ν
  - 转换到笛卡尔坐标
  - 更新自转

卫星：
  - 相对于父天体计算轨道位置
  - 加上父天体位置得到世界坐标
  - 更新自转
```

## 输入处理

### 键盘快捷键
- `Space` - 暂停/继续
- `Q` - 减小时间warp
- `E` - 增加时间warp
- `O` - 切换轨道显示
- `K` - 切换SOI边界显示
- `L` - 切换标签显示
- `F` - Snap摄像机到当前焦点

### 鼠标操作
- `左键拖拽` - 平移地图
- `滚轮` - 缩放
- `双击` - 聚焦到点击的天体
- `UI按钮点击` - 优先由UI消费

## 设计决策

### 1. 文件命名约定
- 使用 `模块名_类名.pde` 格式
- 替代原有的 `A_*`, `B_*` 字母前缀
- 更清晰表达模块归属

### 2. 责任分离
- 数据和渲染分离（CelestialBody vs CelestialBodyRenderer）
- UI组件独立，通过HUD协调
- 数学函数纯函数化，放在Core模块

### 3. 保留的优秀特性
- LOD渲染系统（性能优化）
- 平滑插值摄像机（视觉体验）
- 时间warp系统（游戏性）
- SOI可视化（教学/辅助）

### 4. 视图模式处理
- 保留 ViewMode 枚举定义
- 但暂时不实现视图切换按钮
- 摄像机仍有双视图状态保存，为未来预留

## 常量和单位

**距离单位：** 公里 (km)
- 轨道半径使用公里
- 缩放参数与原始代码一致

**时间单位：** 秒 (s)
- 内部模拟用秒
- UI显示可转换为分/时/天

**角度单位：** 弧度 (rad)
- 内部计算用弧度
- 初始化参数可能用度（转换后存储）

**重力参数 GM：** km³/s²

## 坐标系约定

**日心坐标系：**
- 原点在太阳中心
- XY平面为黄道面
- X轴指向春分点方向

**屏幕坐标系：**
- 原点在屏幕左上角
- X轴向右，Y轴向下
- 中心点在 (width/2, height/2)

## 性能考量

1. **LOD系统** - 根据距离自动切换细节等级
2. **视锥体裁剪** - 不渲染屏幕外的天体
3. **缓存计算** - 开普勒方程结果缓存
4. **扫描线渲染** - 超大天体使用逐行渲染
