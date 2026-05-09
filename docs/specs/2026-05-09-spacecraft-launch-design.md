# 航天器发射模拟器设计文档

> **日期:** 2026-05-09
> **项目:** Solar System Navigation Simulator - 发射系统扩展

## 1. 概述

将现有的太阳系导航模拟器改造为航天器发射模拟器，实现从地球地面发射航天器入轨的全过程。玩家不实际操控飞船，只在关键时刻发送指令。

### 核心流程

1. **发射阶段** → 从地球发射到近地轨道（LEO）
2. **轨道阶段** → 在轨道上选择目的地行星
3. **转移阶段** → 霍曼转移执行中（无法干预）
4. **入轨阶段** → 到达目的地，进入新轨道

## 2. 状态机设计

```
┌──────────────────────────────────────────────────────────┐
│                        IDLE                               │
│              (无飞船发射，可发射新飞船)                     │
└─────────────────────┬────────────────────────────────────┘
                      │ [命名 + LAUNCH]
                      ▼
┌──────────────────────────────────────────────────────────┐
│                     LAUNCHING                             │
│           (发射动画，视距跟随飞船上升)                      │
└─────────────────────┬────────────────────────────────────┘
                      │ [到达LEO轨道]
                      ▼
┌──────────────────────────────────────────────────────────┐
│                       ORBIT                              │
│     (显示飞船状态，可选择目标行星)                          │
│                    ┌─┴─┐                                 │
│                    │   │ [选择目标 + TRANSFER]           │
│                    └───┘                                 │
└─────────────────────┬────────────────────────────────────┘
                      │ [开始霍曼转移]
                      ▼
┌──────────────────────────────────────────────────────────┐
│                     TRANSFER                             │
│           (霍曼转移中，摄像机跟随飞船)                      │
│              (禁止发送任何指令)                            │
└─────────────────────┬────────────────────────────────────┘
                      │ [到达目标轨道]
                      ▼
┌──────────────────────────────────────────────────────────┐
│                       ORBIT                              │
│            (进入目标行星轨道，可继续操作)                   │
└──────────────────────────────────────────────────────────┘
```

## 3. 模块架构

```
SolarSystemNavigation.pde (主程序)
├── LaunchController.pde      [新增] 发射状态管理
├── MissionPlanner.pde        [新增] 轨道计算、霍曼转移
├── LaunchUI.pde              [新增] 发射控制面板
├── CameraController.pde      [重构] 视角控制
├── Spacecraft.pde            [重构] 增加发射状态属性
├── SolarSystem.pde           [重构] 移除预设飞船
├── HUD.pde                   [重构] 集成新UI
└── CelestialBody.pde         [保持] 无变化
```

### 3.1 LaunchController

**职责：** 管理发射序列和状态切换

```java
class LaunchController {
  ShipState state;           // IDLE, LAUNCHING, ORBIT, TRANSFER

  void startLaunch(String name);
  void initiateTransfer(CelestialBody target);
  void update();
  boolean canInitiateTransfer();
}
```

**状态转换规则：**
- IDLE → LAUNCHING：玩家命名并点击发射
- LAUNCHING → ORBIT：飞船达到LEO高度（~420km）
- ORBIT → TRANSFER：玩家选择目标并确认
- TRANSFER → ORBIT：霍曼转移完成

### 3.2 MissionPlanner

**职责：** 轨道力学计算

```java
class MissionPlanner {
  // 霍曼转移轨道计算
  double[] calculateHohmannTransfer(double r1, double r2);
  double calculateTransferTime(double a, double GM);

  // 轨道插入
  void insertIntoOrbit(Spacecraft ship, CelestialBody target);

  // 发射轨道计算（地表到LEO）
  void calculateLaunchTrajectory();
}
```

**霍曼转移参数：**
- 转移轨道半长轴：`a = (r1 + r2) / 2`
- 转移轨道离心率：`e = |r2 - r1| / (r2 + r1)`
- 转移时间：`T = π * sqrt(a³ / GM)`

### 3.3 LaunchUI

**职责：** 用户交互界面

**组件布局：**
```
┌────────────────────────────────────────┐
│           MAP VIEW / SHIP VIEW          │  ← 视角切换 (V)
├────────────────────────────────────────┤
│                                        │
│              [主视图区]                 │
│                                        │
├────────────────────────────────────────┤
│ ┌──────────────┐  ┌──────────────────┐ │
│ │  LAUNCH PANEL │  │   TARGET LIST    │ │
│ │  [名称输入___] │  │   [Earth] 1-8    │ │
│ │  [LAUNCH] L   │  │   [Mars]         │ │
│ │               │  │   [Jupiter]       │ │
│ └──────────────┘  │   [TRANSFER] T    │ │
│                   └──────────────────┘ │
└────────────────────────────────────────┘
```

### 3.4 CameraController (重构自Camera)

**职责：** 视角管理

```java
class CameraController {
  ViewMode mode;              // MAP_VIEW, SHIP_VIEW

  void setViewMode(ViewMode m);
  void followShip(Spacecraft ship);
  void showSolarSystemOverview();

  double[] worldToScreen(double wx, double wy, Spacecraft reference);
}
```

**视角模式：**
- **MAP_VIEW**：俯视太阳系，摄像机跟随选中的飞船
- **SHIP_VIEW**：以飞船为中心，其他天体显示相对位置和距离

## 4. 交互设计

### 4.1 发射控制

| 操作 | 按钮 | 键盘 | 条件 |
|------|------|------|------|
| 输入飞船名称 | 文本框 | - | IDLE状态 |
| 发射 | LAUNCH按钮 | L | IDLE状态，已命名 |
| 选择目标行星 | 行星列表 | 1-8 | ORBIT状态 |
| 确认转移 | TRANSFER按钮 | T | ORBIT状态，已选目标 |
| 切换视角 | VIEW按钮 | V | 任意状态 |
| 跟随飞船 | - | F | 任意状态 |

### 4.2 发射序列（自动执行）

1. 玩家输入名称，点击LAUNCH
2. 时间加速到1x，显示发射动画
3. 飞船沿发射轨道上升（~5分钟模拟时间）
4. 到达LEO轨道，自动切换到ORBIT状态
5. 显示轨道参数面板

### 4.3 转移序列（自动执行）

1. 玩家选择目标行星，点击TRANSFER
2. 系统计算霍曼转移轨道
3. 飞船进入转移轨道，时间加速
4. 转移过程中UI禁用，显示进度
5. 到达目标轨道，自动切入ORBIT状态

## 5. 数据模型

### 5.1 Spacecraft 扩展

```java
class Spacecraft {
  // 现有属性
  String name;
  double a, e, i, omega, w, M0, period;
  color col;
  double px, py, pz;
  double currentNu;

  // 新增属性
  ShipState state;
  CelestialBody originBody;    // 发射源天体
  CelestialBody targetBody;   // 目标天体（转移时）
  double launchStartTime;     // 发射开始时间
  double transferStartTime;    // 转移开始时间
  double leoAltitude;         // 近地轨道高度 (km)
}
```

### 5.2 轨道参数

```java
static final double LEO_RADIUS_KM = 6578.0;      // 地球LEO半径 (6371 + 207)
static final double LAUNCH_ORBIT_ALT = 200.0;   // 停泊轨道高度
```

## 6. 代码重构要点

### 6.1 重构现有代码

| 文件 | 问题 | 解决方案 |
|------|------|----------|
| SolarSystem.pde | initSpacecraft()预设飞船 | 移除，改为空列表 |
| SolarSystemNavigation.pde | 全局变量混乱 | 提取到 LaunchController |
| HUD.pde | 硬编码UI | 改为 LaunchUI 组件 |

### 6.2 代码组织原则

- **单一职责**：每个类有明确职责
- **接口清晰**：组件间通过方法调用通信
- **状态隔离**：状态机管理状态转换

## 7. 视觉效果

### 7.1 发射动画

- 飞船从地球表面升起
- 尾焰效果（橙色渐变）
- 摄像机跟随视角

### 7.2 轨道高亮

- 当前轨道：实线
- 目标转移轨道：虚线
- 转移进度：弧形高亮

### 7.3 Ship View 视角

- 飞船位于屏幕中心
- 其他天体显示为小圆点+名称+距离
- 背景星空旋转表示相对运动

## 8. 验收标准

1. ✅ 移除所有预设航天器
2. ✅ 玩家可命名并发射新航天器
3. ✅ 发射过程自动完成（约5分钟模拟时间）
4. ✅ 到达LEO后玩家可选择目标行星
5. ✅ 霍曼转移自动执行
6. ✅ 支持 Map View / Ship View 切换
7. ✅ 所有操作有按钮和键盘两种方式
8. ✅ 代码结构清晰，可维护

## 9. 技术约束

- **不实现**：燃料消耗、助推器分离、多级火箭
- **不实现**：实时姿态控制、交会对接
- **简化**：发射轨道为固定抛物线，转移轨道为标准霍曼转移
