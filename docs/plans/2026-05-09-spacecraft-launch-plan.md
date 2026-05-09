# 航天器发射模拟器实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将太阳系导航模拟器改造为航天器发射模拟器，实现从地球地面发射入轨的完整流程。

**Architecture:** 采用状态机驱动的模块化架构，核心模块包括 LaunchController（发射控制）、MissionPlanner（轨道计算）、LaunchUI（用户界面）和 CameraController（视角管理）。各模块职责清晰，通过事件驱动状态转换。

**Tech Stack:** Processing (Java Mode)，使用现有开普勒轨道力学基础。

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|----------|------|
| 创建 | `SolarSystemNavigation/LaunchController.pde` | 发射状态管理和序列控制 |
| 创建 | `SolarSystemNavigation/MissionPlanner.pde` | 霍曼转移和发射轨道计算 |
| 创建 | `SolarSystemNavigation/LaunchUI.pde` | 发射控制面板UI组件 |
| 重构 | `SolarSystemNavigation/Camera.pde` → `CameraController.pde` | 视角控制，支持Map/Ship双模式 |
| 修改 | `SolarSystemNavigation/Spacecraft.pde` | 增加发射状态属性 |
| 修改 | `SolarSystemNavigation/SolarSystem.pde` | 移除预设飞船，清理initSpacecraft |
| 修改 | `SolarSystemNavigation/HUD.pde` | 集成LaunchUI面板 |
| 修改 | `SolarSystemNavigation/SolarSystemNavigation.pde` | 集成新模块，移除旧发射快捷键 |

---

## Task 1: 重构 Camera 为 CameraController

**Files:**
- Rename: `SolarSystemNavigation/Camera.pde` → `SolarSystemNavigation/CameraController.pde`
- Modify: `SolarSystemNavigation/SolarSystemNavigation.pde` (import和实例化)

### Step 1: 重命名文件并添加视角模式枚举

在 `CameraController.pde` 开头添加：

```java
enum ViewMode {
  MAP_VIEW,
  SHIP_VIEW
}
```

### Step 2: 添加Ship View相关属性和方法

在 `CameraController` 类中添加：

```java
class CameraController {
  double camX, camY;
  double scale;
  double targetScale;
  boolean dragging;
  double dragSX, dragSY, dragCX, dragCY;

  ViewMode mode;
  Spacecraft followTarget;

  CameraController() {
    camX = 0;
    camY = 0;
    scale = 1.0;
    targetScale = 1.0;
    dragging = false;
    mode = ViewMode.MAP_VIEW;
    followTarget = null;
  }

  void setViewMode(ViewMode m) {
    mode = m;
    if (m == ViewMode.SHIP_VIEW && followTarget != null) {
      camX = followTarget.px;
      camY = followTarget.py;
      targetScale = calculateShipViewScale();
    }
  }

  void followShip(Spacecraft ship) {
    followTarget = ship;
    if (ship != null) {
      camX = ship.px;
      camY = ship.py;
    }
  }

  double calculateShipViewScale() {
    return 5e-6;
  }

  void update() {
    scale += (targetScale - scale) * 0.1;
    if (mode == ViewMode.SHIP_VIEW && followTarget != null) {
      camX = followTarget.px;
      camY = followTarget.py;
    }
  }

  double[] worldToScreenRelative(double wx, double wy, double refX, double refY) {
    double sx = (wx - refX) * scale + width / 2.0;
    double sy = (refY - wy) * scale + height / 2.0;
    return new double[]{sx, sy};
  }
}
```

### Step 3: 更新 SolarSystemNavigation.pde 中的引用

在 `SolarSystemNavigation.pde` 中：
- 将 `Camera camera;` 改为 `CameraController camera;`
- 将 `camera = new Camera();` 改为 `camera = new CameraController();`
- 将所有 `camera.` 调用保持不变（API兼容）

---

## Task 2: 创建 MissionPlanner

**Files:**
- Create: `SolarSystemNavigation/MissionPlanner.pde`

```java
class MissionPlanner {
  static final double GM_SUN = 1.327124e11;
  static final double GM_EARTH = 3.986004e5;
  static final double EARTH_RADIUS_KM = 6371.0;
  static final double LEO_ALTITUDE_KM = 420.0;
  static final double LEO_RADIUS_KM = EARTH_RADIUS_KM + LEO_ALTITUDE_KM;

  double[] calculateHohmannTransfer(double r1_km, double r2_km) {
    double a_transfer = (r1_km + r2_km) / 2.0;
    double e_transfer = Math.abs(r2_km - r1_km) / (r2_km + r1_km);
    return new double[]{a_transfer, e_transfer};
  }

  double calculateTransferTime(double a_km, double GM) {
    return PI * Math.sqrt(Math.pow(a_km, 3) / GM);
  }

  double calculateDeltaV(double r1_km, double r2_km, double GM) {
    double v1 = Math.sqrt(GM / r1_km);
    double v2_transfer = Math.sqrt(GM * (2.0 / r1_km - 1.0 / ((r1_km + r2_km) / 2.0)));
    double v2_insert = Math.sqrt(GM / r2_km);
    return Math.abs(v2_transfer - v1) + Math.abs(v2_insert - v2_transfer);
  }

  double calculateLaunchVelocity(double altitude_km) {
    double r = EARTH_RADIUS_KM + altitude_km;
    return Math.sqrt(GM_EARTH / r);
  }

  double getLEORadius() {
    return LEO_RADIUS_KM;
  }
}
```

---

## Task 3: 创建 LaunchController

**Files:**
- Create: `SolarSystemNavigation/LaunchController.pde`

```java
enum ShipState {
  IDLE,
  LAUNCHING,
  ORBIT,
  TRANSFER
}

class LaunchController {
  ShipState state;
  Spacecraft currentShip;
  CelestialBody selectedTarget;
  double launchStartTime;
  double transferStartTime;
  double[] transferOrbitParams;
  MissionPlanner planner;

  LaunchController() {
    state = ShipState.IDLE;
    currentShip = null;
    selectedTarget = null;
    planner = new MissionPlanner();
  }

  void startLaunch(String name) {
    if (state != ShipState.IDLE) return;
    state = ShipState.LAUNCHING;
    launchStartTime = timeManager.simTime;

    double leoRadius = planner.getLEORadius() * 1000;
    Spacecraft ship = new Spacecraft(name, leoRadius, 0.0, 0.0, 0.0, 0.0, 0.0,
      2 * PI * Math.sqrt(Math.pow(leoRadius, 3) / GM_SUN), color(0, 255, 150));
    ship.state = ShipState.LAUNCHING;
    ship.launchStartTime = launchStartTime;
    currentShip = ship;
    solarSystem.ships.add(ship);

    camera.followShip(ship);
    camera.setViewMode(ViewMode.MAP_VIEW);
    timeManager.timeWarp = timeManager.WARP_LEVELS[0];
  }

  void selectTarget(CelestialBody target) {
    if (state != ShipState.ORBIT) return;
    selectedTarget = target;
  }

  void initiateTransfer() {
    if (state != ShipState.ORBIT || selectedTarget == null) return;
    if (currentShip == null) return;

    double r1 = currentShip.a;
    double r2 = selectedTarget.a;
    transferOrbitParams = planner.calculateHohmannTransfer(r1 / 1000.0, r2 / 1000.0);

    currentShip.a = transferOrbitParams[0] * 1000.0;
    currentShip.e = transferOrbitParams[1];
    currentShip.w = 0.0;
    currentShip.period = 2 * PI * Math.sqrt(Math.pow(currentShip.a, 3) / GM_SUN);

    state = ShipState.TRANSFER;
    transferStartTime = timeManager.simTime;
    currentShip.state = ShipState.TRANSFER;
  }

  void update() {
    if (currentShip == null) return;

    switch (state) {
      case LAUNCHING:
        if (timeManager.simTime - launchStartTime > 5 * 86400) {
          state = ShipState.ORBIT;
          currentShip.state = ShipState.ORBIT;
        }
        break;
      case TRANSFER:
        double transferTime = planner.calculateTransferTime(transferOrbitParams[0], GM_SUN);
        if (timeManager.simTime - transferStartTime > transferTime) {
          insertIntoTargetOrbit();
        }
        break;
    }
  }

  void insertIntoTargetOrbit() {
    if (selectedTarget == null || currentShip == null) return;

    double targetRadius = selectedTarget.a;
    double captureOrbitRadius = targetRadius * 0.95;
    currentShip.a = captureOrbitRadius;
    currentShip.e = 0.0;
    currentShip.i = selectedTarget.i;
    currentShip.omega = selectedTarget.omega;
    currentShip.w = 0.0;
    currentShip.period = 2 * PI * Math.sqrt(Math.pow(captureOrbitRadius, 3) / GM_SUN);

    state = ShipState.ORBIT;
    currentShip.state = ShipState.ORBIT;
    selectedTarget = null;
  }

  boolean canLaunch() {
    return state == ShipState.IDLE;
  }

  boolean canSelectTarget() {
    return state == ShipState.ORBIT;
  }

  boolean canTransfer() {
    return state == ShipState.ORBIT && selectedTarget != null;
  }

  String getStatusText() {
    switch (state) {
      case IDLE: return "Ready to Launch";
      case LAUNCHING: return "Launching...";
      case ORBIT: return "In Orbit - Select Target";
      case TRANSFER: return "Transfer in Progress";
    }
    return "";
  }
}
```

---

## Task 4: 重构 Spacecraft

**Files:**
- Modify: `SolarSystemNavigation/Spacecraft.pde`

在 `Spacecraft` 类开头添加新属性：

```java
class Spacecraft {
  String name;
  double a, e, i, omega, w, M0, period;
  color col;
  color trailColor;

  double px, py, pz;
  double currentNu;

  ShipState state;
  double launchStartTime;
  double transferStartTime;

  Spacecraft(String name, double a, double e, double i,
    double omega, double w, double M0, double period, color col) {
    this.name = name;
    this.a = a; this.e = e; this.i = i;
    this.omega = omega; this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = period;
    this.col = col;
    this.trailColor = col;
    this.state = ShipState.IDLE;
    this.launchStartTime = 0;
    this.transferStartTime = 0;
  }
}
```

---

## Task 5: 修改 SolarSystem

**Files:**
- Modify: `SolarSystemNavigation/SolarSystem.pde`

移除 `initSpacecraft()` 方法，将 `initialize()` 改为：

```java
void initialize() {
  initSolarSystem();
}
```

移除整个 `initSpacecraft()` 方法。

---

## Task 6: 创建 LaunchUI

**Files:**
- Create: `SolarSystemNavigation/LaunchUI.pde`

```java
class LaunchUI {
  String shipName = "";
  boolean inputFocused = false;
  int nameInputWidth = 150;

  LaunchUI() {
  }

  void draw() {
    drawLaunchPanel();
    drawTargetPanel();
    drawShipStatus();
  }

  void drawLaunchPanel() {
    int panelX = 10;
    int panelY = height - 160;
    int panelW = 200;
    int panelH = 150;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Launch Control", panelX + 10, panelY + 10);

    fill(180);
    textSize(14);
    text("Ship Name:", panelX + 10, panelY + 40);

    drawTextInput(panelX + 10, panelY + 60, nameInputWidth, 30);

    boolean canLaunch = launchController.canLaunch() && shipName.length() > 0;
    drawButton("LAUNCH [L]", panelX + 10, panelY + 100, 80, 35, canLaunch);

    textSize(11);
    fill(150);
    text(launchController.getStatusText(), panelX + 10, panelY + 140);
  }

  void drawTargetPanel() {
    if (launchController.state != ShipState.ORBIT &&
        launchController.state != ShipState.TRANSFER) return;

    int panelX = width - 270;
    int panelY = height - 280;
    int panelW = 260;
    int panelH = 250;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Mission Target", panelX + 10, panelY + 10);

    for (int idx = 0; idx < solarSystem.planets.size(); idx++) {
      CelestialBody p = solarSystem.planets.get(idx);
      int rowY = panelY + 40 + idx * 30;

      boolean isSelected = (launchController.selectedTarget == p);
      if (isSelected) {
        fill(50, 80, 50, 200);
        noStroke();
        rect(panelX + 5, rowY - 3, panelW - 10, 26, 4);
      }

      fill(p.col);
      textSize(14);
      text((idx + 1) + ". " + p.name, panelX + 15, rowY);

      if (isSelected) {
        fill(100, 200, 100);
        textSize(11);
        text("Selected", panelX + 150, rowY + 2);
      }
    }

    boolean canTransfer = launchController.canTransfer();
    drawButton("TRANSFER [T]", panelX + 10, panelY + 220, 100, 25, canTransfer);
  }

  void drawShipStatus() {
    if (launchController.currentShip == null) return;

    int panelX = width - 270;
    int panelY = height - 320;
    int panelW = 260;
    int panelH = 50;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    Spacecraft ship = launchController.currentShip;
    fill(100, 200, 100);
    textSize(14);
    textAlign(LEFT, TOP);
    text("Ship: " + ship.name, panelX + 10, panelY + 8);

    fill(180);
    textSize(12);
    double altitude = (ship.a - 6371000) / 1000.0;
    text(String.format("Alt: %.0f km", altitude), panelX + 10, panelY + 28);
  }

  void drawTextInput(int x, int y, int w, int h) {
    stroke(100);
    strokeWeight(1);
    noFill();
    rect(x, y, w, h, 4);

    fill(inputFocused ? 255 : 200);
    noStroke();
    textSize(14);
    textAlign(LEFT, CENTER);
    String display = shipName;
    if (inputFocused && (frameCount / 30) % 2 == 0) {
      display += "_";
    }
    text(display.length() > 0 ? display : "Enter name...", x + 5, y + h / 2);
  }

  void drawButton(String label, int x, int y, int w, int h, boolean enabled) {
    if (enabled) {
      fill(50, 150, 50);
    } else {
      fill(80, 80, 80);
    }
    noStroke();
    rect(x, y, w, h, 6);

    fill(enabled ? 255 : 150);
    textSize(14);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  boolean isLaunchButtonClicked(int mx, int my) {
    int bx = 10 + 10;
    int by = height - 160 + 100;
    return mx >= bx && mx <= bx + 80 && my >= by && my <= by + 35;
  }

  boolean isTargetClicked(int mx, int my, int idx) {
    int panelX = width - 270;
    int panelY = height - 280;
    int rowY = panelY + 40 + idx * 30;
    return mx >= panelX && mx <= panelX + 260 && my >= rowY && my <= rowY + 26;
  }

  boolean isTransferButtonClicked(int mx, int my) {
    int bx = width - 270 + 10;
    int by = height - 280 + 220;
    return mx >= bx && mx <= bx + 100 && my >= by && my <= by + 25;
  }

  void handleClick(int mx, int my) {
    if (launchController.canLaunch() && shipName.length() > 0) {
      if (isLaunchButtonClicked(mx, my)) {
        launchController.startLaunch(shipName);
        return;
      }
    }

    if (launchController.canSelectTarget()) {
      for (int idx = 0; idx < solarSystem.planets.size(); idx++) {
        if (isTargetClicked(mx, my, idx)) {
          launchController.selectTarget(solarSystem.planets.get(idx));
          return;
        }
      }

      if (isTransferButtonClicked(mx, my) && launchController.canTransfer()) {
        launchController.initiateTransfer();
      }
    }
  }

  void keyPressed(char keyChar) {
    if (key == BACKSPACE) {
      if (shipName.length() > 0) {
        shipName = shipName.substring(0, shipName.length() - 1);
      }
    } else if (key == ENTER || key == RETURN) {
      if (launchController.canLaunch() && shipName.length() > 0) {
        launchController.startLaunch(shipName);
      }
    } else if (key >= 32 && key <= 126) {
      if (shipName.length() < 20) {
        shipName += key;
      }
    }
  }
}
```

---

## Task 7: 重构 HUD

**Files:**
- Modify: `SolarSystemNavigation/HUD.pde`

将 HUD 中的发射相关UI替换为使用 LaunchUI：

```java
class HUD {
  LaunchUI launchUI;

  HUD() {
    launchUI = new LaunchUI();
  }

  void draw(CameraController cam, double simTime, double timeWarp,
            double[] WARP_LEVELS, List<CelestialBody> planets) {
    drawInfoPanel(cam, simTime, timeWarp, WARP_LEVELS);
    drawViewModeIndicator();
    launchUI.draw();
    if (timeWarp == 0) {
      drawPauseIndicator();
    }
  }

  void drawViewModeIndicator() {
    noStroke();
    fill(0, 0, 0, 160);
    rect(width - 130, 10, 120, 35, 8);

    fill(200);
    textSize(14);
    textAlign(LEFT, CENTER);
    String modeText = (camera.mode == ViewMode.MAP_VIEW) ? "MAP VIEW" : "SHIP VIEW";
    text(modeText + " [V]", width - 120, 28);
  }
}
```

---

## Task 8: 更新 SolarSystemNavigation.pde

**Files:**
- Modify: `SolarSystemNavigation/SolarSystemNavigation.pde`

### Step 1: 更新导入和全局变量

```java
CameraController camera;
LaunchController launchController;
```

### Step 2: 在 setup() 中初始化

```java
camera = new CameraController();
camera.initialize((width * 0.15) / (1.0 * AU_KM));
launchController = new LaunchController();
```

### Step 3: 更新 draw() 循环

```java
void draw() {
  background(5, 5, 15);

  camera.update();
  timeManager.update();
  launchController.update();

  solarSystem.update(timeManager.simTime);
  for (Spacecraft s : solarSystem.ships) {
    s.update(timeManager.simTime);
  }

  drawStars();
  drawOrbits();
  solarSystem.drawSun(camera);
  solarSystem.drawPlanets(camera);
  for (Spacecraft s : solarSystem.ships) {
    s.draw(camera);
  }
  hud.draw(camera, timeManager.simTime, timeManager.timeWarp,
           timeManager.WARP_LEVELS, solarSystem.planets);
}
```

### Step 4: 更新 keyPressed()

```java
void keyPressed() {
  if (key == ' ' || key == 'p' || key == 'P') {
    timeManager.togglePause();
  }
  if (key == 'q' || key == 'Q') {
    timeManager.decreaseWarp();
  }
  if (key == 'e' || key == 'E') {
    timeManager.increaseWarp();
  }

  if (key == 'o' || key == 'O') showOrbits = !showOrbits;
  if (key == 'l' || key == 'L') showLabels = !showLabels;
  if (key == 't' || key == 'T') showTrails = !showTrails;

  if (key == 'r' || key == 'R') {
    camera.reset();
    camera.targetScale = (width * 0.15) / AU_KM;
  }

  if (key == 'v' || key == 'V') {
    if (camera.mode == ViewMode.MAP_VIEW) {
      camera.setViewMode(ViewMode.SHIP_VIEW);
    } else {
      camera.setViewMode(ViewMode.MAP_VIEW);
    }
  }

  if (key == 'f' || key == 'F') {
    if (launchController.currentShip != null) {
      camera.followShip(launchController.currentShip);
      camera.setViewMode(ViewMode.MAP_VIEW);
    }
  }

  if (key >= '1' && key <= '8') {
    int idx = key - '1';
    if (idx < solarSystem.planets.size()) {
      CelestialBody p = solarSystem.planets.get(idx);
      camera.focusOn(p.px, p.py, (width * 0.2) / p.a);
      camera.setViewMode(ViewMode.MAP_VIEW);
    }
  }
  if (key == '0') {
    camera.reset();
    camera.targetScale = (width * 0.15) / AU_KM;
  }
}
```

### Step 5: 更新 mousePressed()

```java
void mousePressed() {
  camera.handleMousePressed();
  hud.launchUI.handleClick(mouseX, mouseY);
}
```

### Step 6: 添加文本输入支持

```java
void keyTyped() {
  if (hud.launchUI.inputFocused) {
    hud.launchUI.keyPressed(key);
  }
}
```

---

## Task 9: 最终整合和测试

**Files:**
- All files above

### Step 1: 确保文件结构正确

所有新文件应在 `SolarSystemNavigation/` 目录下：
- `CameraController.pde` (重命名自Camera.pde)
- `MissionPlanner.pde`
- `LaunchController.pde`
- `LaunchUI.pde`

### Step 2: 验证编译

运行 Processing 验证无语法错误。

### Step 3: 功能验证

1. 启动程序，验证IDLE状态正确
2. 输入飞船名称，点击LAUNCH或按L
3. 验证发射动画和状态转换
4. 验证目标选择功能
5. 验证TRANSFER功能和转移过程
6. 验证视角切换(V键)

---

## 自检清单

### Spec 覆盖率检查

| Spec 需求 | 对应 Task |
|----------|-----------|
| 移除预设航天器 | Task 5 |
| 发射命名 | Task 3, Task 6 |
| 发射序列 | Task 3, Task 6 |
| 到达LEO状态转换 | Task 3 |
| 目标行星选择 | Task 3, Task 6 |
| 霍曼转移 | Task 2, Task 3 |
| Map/Ship视角切换 | Task 1, Task 7 |
| 按钮+键盘操作 | Task 6, Task 8 |

### Placeholder 检查

- [x] 无 "TBD" 或 "TODO"
- [x] 无 "实现后续" 或 "待定"
- [x] 所有代码片段完整

### 类型一致性检查

- `ShipState` 枚举在 Task 3 和 Task 4 中一致使用
- `ViewMode` 枚举在 Task 1 和 Task 7 中一致使用
- `CameraController` 替代原 `Camera` 类型
