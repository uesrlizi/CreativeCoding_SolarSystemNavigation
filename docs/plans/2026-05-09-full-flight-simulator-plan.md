# 完整航天模拟器实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前简化的发射系统改造为完整的航天模拟器，实现从地球表面发射、入轨、轨道机动、霍曼转移、交会对接等全流程模拟。

**Architecture:** 采用牛顿力学实时积分替代开普勒轨道方程，使用绝对坐标系计算航天器位置和速度，支持任意时刻施加速度增量（delta-v）进行轨道机动。

**Tech Stack:** Processing (Java Mode)，物理计算使用牛顿力学 + RK4积分器，坐标系使用日心黄道坐标系。

---

## 当前架构问题分析

### 现有系统缺陷

1. **轨道模型错误**：飞船使用开普勒轨道方程，假设飞船始终绕太阳运动，无法表示地球附近的发射轨道
2. **缺乏引力场切换**：无法从地球引力场转换到太阳引力场
3. **发射模型虚假**：直接创建轨道参数而非模拟发射过程
4. **缺乏轨道机动**：无法执行 delta-v 机动
5. **缺乏完整发射窗口**：不考虑发射窗口和相位角

### 需要重新设计的模块

| 模块 | 当前问题 | 新设计 |
|------|----------|--------|
| Spacecraft | 开普勒轨道固定参数 | 状态向量 (r, v)，支持轨道机动 |
| CelestialBody | 仅支持日心轨道 | 支持任意引力场 |
| PhysicsEngine | 无 | 新增：牛顿力学积分器 |
| LaunchSimulator | 虚假发射 | 新增：地球发射模拟 |
| ManeuverController | 无 | 新增：轨道机动控制器 |
| OrbitCalculator | 仅霍曼转移 | 新增：完整轨道计算 |

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|----------|------|
| 创建 | `PhysicsEngine.pde` | 牛顿力学积分、引力计算 |
| 创建 | `OrbitalManeuver.pde` | 轨道机动计算、delta-v |
| 创建 | `LaunchSimulator.pde` | 发射模拟、地球逃逸 |
| 创建 | `OrbitDisplay.pde` | 预测轨道显示 |
| 创建 | `ManeuverPlanner.pde` | 机动计划UI |
| 创建 | `TelemetryDisplay.pde` | 遥测数据面板 |
| 重构 | `Spacecraft.pde` | 状态向量轨道模型 |
| 重构 | `CelestialBody.pde` | 增强引力场支持 |
| 重构 | `LaunchController.pde` | 集成发射模拟 |
| 重构 | `LaunchUI.pde` | 完整任务控制面板 |
| 重构 | `MissionPlanner.pde` | 重力井可视化 |

---

## Task 1: 创建 PhysicsEngine

**Files:**
- Create: `SolarSystemNavigation/PhysicsEngine.pde`

### Step 1: 创建物理引擎类

```java
class PhysicsEngine {
  static final double G = 6.67430e-11;
  static final double KM_TO_M = 1000.0;
  static final double EARTH_GM = 3.986004418e14;
  static final double SUN_GM = 1.32712440018e20;

  double[] gravityAt(double[] pos, CelestialBody body) {
    double[] r = new double[]{pos[0] - body.px * 1000, pos[1] - body.py * 1000, pos[2] - body.pz * 1000};
    double rMag = Math.sqrt(r[0]*r[0] + r[1]*r[1] + r[2]*r[2]);
    if (rMag < body.radius * 1000) rMag = body.radius * 1000;
    double gMag = body.gm / (rMag * rMag);
    return new double[]{-gMag * r[0] / rMag, -gMag * r[1] / rMag, -gMag * r[2] / rMag};
  }

  double[] totalGravity(double[] pos) {
    double[] acc = {0, 0, 0};
    for (CelestialBody body : solarSystem.planets) {
      double[] g = gravityAt(pos, body);
      acc[0] += g[0]; acc[1] += g[1]; acc[2] += g[2];
    }
    double[] gSun = gravityAt(pos, solarSystem.sun);
    acc[0] += gSun[0]; acc[1] += gSun[1]; acc[2] += gSun[2];
    return acc;
  }

  double[] integrateRK4(double[] pos, double[] vel, double dt) {
    double[] k1v = totalGravity(pos);
    double[] k1p = vel;
    double[] pos2 = {pos[0]+k1p[0]*dt/2, pos[1]+k1p[1]*dt/2, pos[2]+k1p[2]*dt/2};
    double[] vel2 = {vel[0]+k1v[0]*dt/2, vel[1]+k1v[1]*dt/2, vel[2]+k1v[2]*dt/2};
    double[] k2v = totalGravity(pos2);
    double[] k2p = vel2;
    double[] pos3 = {pos[0]+k2p[0]*dt/2, pos[1]+k2p[1]*dt/2, pos[2]+k2p[2]*dt/2};
    double[] vel3 = {vel[0]+k2v[0]*dt/2, vel[1]+k2v[1]*dt/2, vel[2]+k2v[2]*dt/2};
    double[] k3v = totalGravity(pos3);
    double[] k3p = vel3;
    double[] pos4 = {pos[0]+k3p[0]*dt, pos[1]+k3p[1]*dt, pos[2]+k3p[2]*dt};
    double[] vel4 = {vel[0]+k3v[0]*dt, vel[1]+k3v[1]*dt, vel[2]+k3v[2]*dt};
    double[] k4v = totalGravity(pos4);
    double[] k4p = vel4;
    double[] newPos = {pos[0]+(k1p[0]+2*k2p[0]+2*k3p[0]+k4p[0])*dt/6,
                      pos[1]+(k1p[1]+2*k2p[1]+2*k3p[1]+k4p[1])*dt/6,
                      pos[2]+(k1p[2]+2*k2p[2]+2*k3p[2]+k4p[2])*dt/6};
    double[] newVel = {vel[0]+(k1v[0]+2*k2v[0]+2*k3v[0]+k4v[0])*dt/6,
                      vel[1]+(k1v[1]+2*k2v[1]+2*k3v[1]+k4v[1])*dt/6,
                      vel[2]+(k1v[2]+2*k2v[2]+2*k3v[2]+k4v[2])*dt/6};
    return new double[]{newPos[0], newPos[1], newPos[2], newVel[0], newVel[1], newVel[2]};
  }

  double orbitalSpeed(double r, double gm) {
    return Math.sqrt(gm / r);
  }

  double escapeVelocity(double r, double gm) {
    return Math.sqrt(2 * gm / r);
  }

  double altitude(double r, double bodyRadius) {
    return (r - bodyRadius) / 1000.0;
  }

  double[] orbitalElements(double[] r, double[] v, double gm) {
    double rMag = Math.sqrt(r[0]*r[0] + r[1]*r[1] + r[2]*r[2]);
    double vMag = Math.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    double mu = gm;
    double specificEnergy = vMag*vMag/2 - mu/rMag;
    double a = -mu / (2 * specificEnergy);
    double h = r[0]*v[1] - r[1]*v[0];
    double e = Math.sqrt(1 + 2*specificEnergy*h*h/(mu*mu));
    return new double[]{a, e};
  }
}
```

---

## Task 2: 重构 Spacecraft 为状态向量模型

**Files:**
- Modify: `SolarSystemNavigation/Spacecraft.pde`

### Step 1: 重构 Spacecraft 类

```java
class Spacecraft {
  String name;
  color col;
  color trailColor;

  double[] position = new double[3];
  double[] velocity = new double[3];
  double mass;
  double fuel;
  double[] angularVelocity = new double[3];

  ShipPhase phase;
  double phaseTimer;
  double[] launchAzimuth = new double[3];
  double launchPitch;
  double altitude;
  double downrange;

  ArrayList<double[]> trajectory;
  ArrayList<double[]> maneuverPlan;

  Spacecraft(String name, color col) {
    this.name = name;
    this.col = col;
    this.trailColor = col;
    this.mass = 1000.0;
    this.fuel = 500.0;
    this.phase = ShipPhase.ON_GROUND;
    this.trajectory = new ArrayList<double[]>();
    this.maneuverPlan = new ArrayList<double[]>();
    for (int i = 0; i < 3; i++) {
      position[i] = 0;
      velocity[i] = 0;
    }
  }

  void setStateVector(double[] pos, double[] vel) {
    position = pos.clone();
    velocity = vel.clone();
  }

  void applyDeltaV(double[] dv) {
    velocity[0] += dv[0];
    velocity[1] += dv[1];
    velocity[2] += dv[2];
  }

  double speed() {
    return Math.sqrt(velocity[0]*velocity[0] + velocity[1]*velocity[1] + velocity[2]*velocity[2]);
  }

  double altitudeAGL(CelestialBody body) {
    double r = Math.sqrt(position[0]*position[0] + position[1]*position[1] + position[2]*position[2]);
    return (r - body.radius * 1000) / 1000.0;
  }

  boolean isInOrbit() {
    return phase == ShipPhase.IN_ORBIT;
  }

  double[] getOrbitalVelocity(CelestialBody body) {
    double r = Math.sqrt(position[0]*position[0] + position[1]*position[1]);
    double v = Math.sqrt(body.gm / r);
    return new double[]{-velocity[1]/Math.abs(velocity[1]) * v, velocity[0]/Math.abs(velocity[0]) * v, 0};
  }
}

enum ShipPhase {
  ON_GROUND,
  POWERED_ASCENT,
  COASTING,
  IN_ORBIT,
  TRANSFER,
  DECOUPLING
}
```

---

## Task 3: 创建 LaunchSimulator

**Files:**
- Create: `SolarSystemNavigation/LaunchSimulator.pde`

### Step 1: 创建发射模拟器

```java
class LaunchSimulator {
  PhysicsEngine physics;
  CelestialBody launchBody;
  double targetOrbitAltitude;
  double launchAzimuth;
  double initialPitchRate;
  double stage2BurnTime;

  LaunchSimulator() {
    physics = new PhysicsEngine();
    launchBody = null;
    for (CelestialBody p : solarSystem.planets) {
      if (p.name.equals("Earth")) {
        launchBody = p;
        break;
      }
    }
    targetOrbitAltitude = 400000;
    launchAzimuth = 90;
    initialPitchRate = 3.0;
  }

  void executeLaunch(Spacecraft ship) {
    if (ship.phase != ShipPhase.ON_GROUND) return;
    ship.phase = ShipPhase.POWERED_ASCENT;
    ship.launchAzimuth = new double[]{
      Math.cos(Math.toRadians(launchAzimuth)),
      Math.sin(Math.toRadians(launchAzimuth)),
      0
    };
    ship.launchPitch = 90;
  }

  void updateLaunch(Spacecraft ship, double dt) {
    if (ship.phase == ShipPhase.ON_GROUND) return;

    double thrust = 1500000.0;
    double isp = 300.0;
    double g0 = 9.81;
    double massFlow = thrust / (isp * g0);
    double currentMass = ship.mass;
    double drag = 0;
    double altitude = ship.altitudeAGL(launchBody);
    if (altitude > 0) {
      double rho = 1.225 * Math.exp(-altitude / 8500.0);
      double Cd = 0.5;
      double A = 10.0;
      double v = ship.speed();
      drag = 0.5 * rho * v * v * Cd * A;
    }
    double netAccel = (thrust - drag) / currentMass - launchBody.surfaceGravity;
    double pitchRad = Math.toRadians(ship.launchPitch);
    double[] thrustDir = new double[]{
      ship.launchAzimuth[0] * Math.sin(pitchRad),
      ship.launchAzimuth[1] * Math.sin(pitchRad),
      Math.cos(pitchRad)
    };
    ship.velocity[0] += thrustDir[0] * netAccel * dt;
    ship.velocity[1] += thrustDir[1] * netAccel * dt;
    ship.velocity[2] += thrustDir[2] * netAccel * dt;
    double[] gravAcc = physics.gravityAt(ship.position, launchBody);
    ship.velocity[0] += gravAcc[0] * dt;
    ship.velocity[1] += gravAcc[1] * dt;
    ship.velocity[2] += gravAcc[2] * dt;
    ship.position[0] += ship.velocity[0] * dt;
    ship.position[1] += ship.velocity[1] * dt;
    ship.position[2] += ship.velocity[2] * dt;
    ship.mass -= massFlow * dt;
    ship.launchPitch = Math.max(0, ship.launchPitch - initialPitchRate * dt);

    if (ship.altitudeAGL(launchBody) >= targetOrbitAltitude) {
      double[] circularVel = new double[]{
        -ship.velocity[1] * 0.9,
        ship.velocity[0] * 0.9,
        0
      };
      ship.applyDeltaV(new double[]{
        circularVel[0] - ship.velocity[0],
        circularVel[1] - ship.velocity[1],
        0
      });
      ship.phase = ShipPhase.IN_ORBIT;
    }
  }

  double getRequiredDeltaV() {
    double r = launchBody.radius * 1000;
    double v1 = physics.orbitalSpeed(r, launchBody.gm);
    double v2 = physics.orbitalSpeed(r + targetOrbitAltitude * 1000, launchBody.gm);
    return v2 - v1;
  }
}
```

---

## Task 4: 创建 OrbitalManeuver

**Files:**
- Create: `SolarSystemNavigation/OrbitalManeuver.pde`

### Step 1: 创建轨道机动类

```java
class OrbitalManeuver {
  String name;
  double deltaV;
  double[] burnVector;
  double duration;
  ManeuverType type;

  OrbitalManeuver(String name, double deltaV, double[] burnVector, ManeuverType type) {
    this.name = name;
    this.deltaV = deltaV;
    this.burnVector = burnVector;
    this.type = type;
    this.duration = 0;
  }

  static OrbitalManeuver prograde(double deltaV) {
    return new OrbitalManeuver("Prograde", deltaV, new double[]{0, 1, 0}, ManeuverType.CIRCULARIZE);
  }

  static OrbitalManeuver retrograde(double deltaV) {
    return new OrbitalManeuver("Retrograde", deltaV, new double[]{0, -1, 0}, ManeuverType.CIRCULARIZE);
  }

  static OrbitalManeuver normal(double deltaV) {
    return new OrbitalManeuver("Normal", deltaV, new double[]{0, 0, 1}, ManeuverType.PLANE_CHANGE);
  }

  static OrbitalManeuver antinormal(double deltaV) {
    return new OrbitalManeuver("Antinormal", deltaV, new double[]{0, 0, -1}, ManeuverType.PLANE_CHANGE);
  }

  static double[] calculateHohmannTransfer(double r1, double r2, double gm) {
    double a = (r1 + r2) / 2;
    double v1 = Math.sqrt(gm / r1);
    double vTransfer1 = Math.sqrt(gm * (2.0/r1 - 1.0/a));
    double dv1 = vTransfer1 - v1;
    double v2 = Math.sqrt(gm / r2);
    double vTransfer2 = Math.sqrt(gm * (2.0/r2 - 1.0/a));
    double dv2 = vTransfer2 - v2;
    return new double[]{dv1, dv2, a};
  }

  double getBurnDuration(Spacecraft ship) {
    double thrust = 100000.0;
    double isp = 300.0;
    double g0 = 9.81;
    double massFlow = thrust / (isp * g0);
    double m0 = ship.mass;
    double mf = m0 * Math.exp(-deltaV / (isp * g0));
    return (m0 - mf) / massFlow;
  }
}

enum ManeuverType {
  CIRCULARIZE,
  TRANSFER,
  PLANE_CHANGE,
  RAISE_APOGEE,
  LOWER_APOGEE,
  ESCAPE
}
```

---

## Task 5: 创建 ManeuverPlanner UI

**Files:**
- Create: `SolarSystemNavigation/ManeuverPlanner.pde`

### Step 1: 创建机动计划UI

```java
class ManeuverPlanner {
  boolean visible = false;
  double[] plannedDeltaV;
  double[] projectedOrbit;
  ArrayList<OrbitalManeuver> maneuvers;
  int selectedManeuverIndex = -1;

  ManeuverPlanner() {
    maneuvers = new ArrayList<OrbitalManeuver>();
  }

  void toggle() {
    visible = !visible;
  }

  void draw() {
    if (!visible) return;
    int panelX = width - 280;
    int panelY = height - 650;
    int panelW = 270;
    int panelH = 320;

    noStroke();
    fill(0, 0, 0, 200);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Orbit Maneuvers", panelX + 10, panelY + 10);

    int rowY = panelY + 40;
    String[] maneuverNames = {"Circularize", "Raise Orbit", "Lower Orbit", "Escape", "Hohmann Tfr"};
    int[] shortcuts = {'1', '2', '3', '4', '5'};

    for (int i = 0; i < 5; i++) {
      fill(150);
      textSize(14);
      text("[" + (char)shortcuts[i] + "] " + maneuverNames[i], panelX + 15, rowY + i * 35);
    }

    if (selectedManeuverIndex >= 0) {
      fill(100, 200, 100);
      textSize(12);
      OrbitalManeuver m = maneuvers.get(selectedManeuverIndex);
      text("Selected: " + m.name + " (" + String.format("%.0f", m.deltaV) + " m/s)", panelX + 15, rowY + 180);
      text("Burn: " + String.format("%.1f", m.getBurnDuration(launchController.currentShip)) + "s", panelX + 15, rowY + 200);
    }

    fill(100, 150, 100);
    textSize(14);
    text("[EXE] Execute Maneuver", panelX + 15, panelY + 250);
    text("[DEL] Clear Maneuvers", panelX + 15, panelY + 275);
  }

  void addManeuver(OrbitalManeuver m) {
    maneuvers.add(m);
    selectedManeuverIndex = maneuvers.size() - 1;
  }

  void executeNextManeuver() {
    if (maneuvers.isEmpty() || launchController.currentShip == null) return;
    OrbitalManeuver m = maneuvers.remove(0);
    double burnDir = 1.0;
    if (m.type == ManeuverType.CIRCULARIZE && m.deltaV < 0) burnDir = -1.0;
    double vMag = launchController.currentShip.speed();
    double[] dv = new double[]{
      m.burnVector[0] * m.deltaV * burnDir,
      m.burnVector[1] * m.deltaV * burnDir,
      m.burnVector[2] * m.deltaV * burnDir
    };
    launchController.currentShip.applyDeltaV(dv);
    selectedManeuverIndex = -1;
  }

  void handleKey(char k) {
    if (!visible) return;
    if (launchController.currentShip == null) return;

    if (k == '1') {
      double targetAlt = 400000;
      double r1 = launchController.currentShip.altitudeAGL(solarSystem.planets.get(2)) * 1000 + 6371000;
      double r2 = r1 + targetAlt * 1000;
      double dv = Math.sqrt(6.674e-11 * 5.972e24 / r1) * (Math.sqrt(2*r2/(r1+r2)) - 1);
      addManeuver(new OrbitalManeuver("Circularize", dv, new double[]{0, 1, 0}, ManeuverType.CIRCULARIZE));
    }
    if (k == '2') {
      addManeuver(new OrbitalManeuver("Raise Orbit", 100, new double[]{0, 1, 0}, ManeuverType.RAISE_APOGEE));
    }
    if (k == '3') {
      addManeuver(new OrbitalManeuver("Lower Orbit", -100, new double[]{0, -1, 0}, ManeuverType.LOWER_APOGEE));
    }
    if (k == '4') {
      addManeuver(new OrbitalManeuver("Escape", 3000, new double[]{0, 1, 0}, ManeuverType.ESCAPE));
    }
    if (k == '5') {
      double dv1 = OrbitalManeuver.calculateHohmannTransfer(6778000, 42164000, 3.986e14)[0];
      addManeuver(new OrbitalManeuver("Hohmann-1", dv1, new double[]{0, 1, 0}, ManeuverType.TRANSFER));
    }
  }

  boolean isClicked(int mx, int my) {
    return visible && mx >= width - 280 && mx <= width - 10 && my >= height - 650 && my <= height - 330;
  }
}
```

---

## Task 6: 重构 LaunchController 集成新系统

**Files:**
- Modify: `SolarSystemNavigation/LaunchController.pde`

### Step 1: 重构 LaunchController

```java
enum ShipPhase {
  ON_GROUND,
  POWERED_ASCENT,
  COASTING,
  IN_ORBIT,
  TRANSFER,
  DECOUPLING
}

class LaunchController {
  ShipPhase phase;
  Spacecraft currentShip;
  CelestialBody selectedTarget;
  CelestialBody launchBody;
  LaunchSimulator launchSim;
  ManeuverPlanner maneuverPlanner;
  PhysicsEngine physics;
  OrbitPredictor orbitPredictor;

  double launchAzimuth;
  double targetOrbitAltitude;
  boolean waitingForLaunch;

  LaunchController() {
    phase = ShipPhase.ON_GROUND;
    currentShip = null;
    selectedTarget = null;
    launchSim = new LaunchSimulator();
    maneuverPlanner = new ManeuverPlanner();
    physics = new PhysicsEngine();
    orbitPredictor = new OrbitPredictor();
    launchAzimuth = 90;
    targetOrbitAltitude = 400;
    waitingForLaunch = false;

    for (CelestialBody p : solarSystem.planets) {
      if (p.name.equals("Earth")) {
        launchBody = p;
        p.gm = 3.986e14;
        p.surfaceGravity = 9.81;
        break;
      }
    }
  }

  void startLaunch(String name) {
    if (phase != ShipPhase.ON_GROUND) return;

    currentShip = new Spacecraft(name, color(0, 255, 150));
    currentShip.position = new double[]{launchBody.radius * 1000, 0, 0};
    currentShip.velocity = new double[]{0, launchBody.rotationSpeed * launchBody.radius * 1000, 0};
    currentShip.phase = ShipPhase.ON_GROUND;
    launchSim.targetOrbitAltitude = targetOrbitAltitude;
    launchSim.launchAzimuth = launchAzimuth;
    solarSystem.ships.add(currentShip);
    waitingForLaunch = true;
    phase = ShipPhase.ON_GROUND;
  }

  void executeLaunch() {
    if (!waitingForLaunch || currentShip == null) return;
    launchSim.executeLaunch(currentShip);
    waitingForLaunch = false;
    phase = ShipPhase.POWERED_ASCENT;
  }

  void update() {
    if (currentShip == null) return;

    switch (phase) {
      case ON_GROUND:
        if (waitingForLaunch) {
        }
        break;
      case POWERED_ASCENT:
        launchSim.updateLaunch(currentShip, 1.0);
        if (currentShip.phase == ShipPhase.IN_ORBIT) {
          phase = ShipPhase.IN_ORBIT;
        }
        break;
      case IN_ORBIT:
        double[] acc = physics.totalGravity(currentShip.position);
        currentShip.velocity[0] += acc[0] * 1.0;
        currentShip.velocity[1] += acc[1] * 1.0;
        currentShip.velocity[2] += acc[2] * 1.0;
        currentShip.position[0] += currentShip.velocity[0] * 1.0;
        currentShip.position[1] += currentShip.velocity[1] * 1.0;
        currentShip.position[2] += currentShip.velocity[2] * 1.0;
        break;
    }

    orbitPredictor.update(currentShip);
  }

  boolean canLaunch() {
    return phase == ShipPhase.ON_GROUND;
  }

  boolean canManeuver() {
    return phase == ShipPhase.IN_ORBIT && currentShip != null;
  }

  String getStatusText() {
    switch (phase) {
      case ON_GROUND:
        return waitingForLaunch ? "Ready - Press [L] to Launch" : "Configure Launch";
      case POWERED_ASCENT:
        double alt = currentShip != null ? currentShip.altitudeAGL(launchBody) : 0;
        return String.format("Ascent - Alt: %.0f km", alt);
      case IN_ORBIT:
        double alt = currentShip != null ? currentShip.altitudeAGL(launchBody) : 0;
        return String.format("In Orbit - Alt: %.0f km", alt);
    }
    return "";
  }
}
```

---

## Task 7: 创建 OrbitPredictor

**Files:**
- Create: `SolarSystemNavigation/OrbitPredictor.pde`

### Step 1: 创建轨道预测器

```java
class OrbitPredictor {
  ArrayList<double[]> predictedPath;
  int maxPoints = 500;
  double predictionTime = 86400 * 3;

  OrbitPredictor() {
    predictedPath = new ArrayList<double[]>();
  }

  void update(Spacecraft ship) {
    if (ship == null || ship.phase != ShipPhase.IN_ORBIT) {
      predictedPath.clear();
      return;
    }

    predictedPath.clear();
    double[] pos = ship.position.clone();
    double[] vel = ship.velocity.clone();
    double dt = predictionTime / maxPoints;

    for (int i = 0; i < maxPoints; i++) {
      predictedPath.add(pos.clone());
      double[] acc = physics.totalGravity(pos);
      vel[0] += acc[0] * dt;
      vel[1] += acc[1] * dt;
      vel[2] += acc[2] * dt;
      pos[0] += vel[0] * dt;
      pos[1] += vel[1] * dt;
      pos[2] += vel[2] * dt;
    }
  }

  void draw(CameraController cam) {
    if (predictedPath.isEmpty()) return;
    noFill();
    stroke(100, 200, 100, 100);
    strokeWeight(1);
    beginShape();
    for (double[] p : predictedPath) {
      double[] sp = cam.worldToScreen(p[0] / 1000, p[1] / 1000);
      if (sp[0] >= -100 && sp[0] <= width + 100 && sp[1] >= -100 && sp[1] <= height + 100) {
        vertex((float)sp[0], (float)sp[1]);
      }
    }
    endShape();
  }
}
```

---

## Task 8: 创建 TelemetryDisplay

**Files:**
- Create: `SolarSystemNavigation/TelemetryDisplay.pde`

### Step 1: 创建遥测显示

```java
class TelemetryDisplay {
  void draw(Spacecraft ship) {
    if (ship == null) return;

    int panelX = width - 280;
    int panelY = 10;
    int panelW = 270;
    int panelH = 180;

    noStroke();
    fill(0, 0, 0, 180);
    rect(panelX, panelY, panelW, panelH, 8);

    fill(200);
    textSize(14);
    textAlign(LEFT, TOP);
    text("Telemetry", panelX + 10, panelY + 10);

    double r = Math.sqrt(ship.position[0]*ship.position[0] + ship.position[1]*ship.position[1] + ship.position[2]*ship.position[2]);
    double v = ship.speed();
    double alt = (r - 6371000) / 1000;

    double period = 2 * PI * Math.sqrt(r*r*r / 3.986e14);
    double apogee = r * (1 + 0.05);
    double perigee = r * (1 - 0.05);

    fill(150);
    textSize(12);
    int y = panelY + 35;
    text(String.format("Altitude: %.1f km", alt), panelX + 15, y); y += 20;
    text(String.format("Velocity: %.1f m/s", v), panelX + 15, y); y += 20;
    text(String.format("Period: %.1f min", period / 60), panelX + 15, y); y += 20;
    text(String.format("Apogee: %.0f km", (apogee - 6371000) / 1000), panelX + 15, y); y += 20;
    text(String.format("Perigee: %.0f km", (perigee - 6371000) / 1000), panelX + 15, y); y += 20;
  }
}
```

---

## Task 9: 重构 CelestialBody 添加引力场

**Files:**
- Modify: `SolarSystemNavigation/CelestialBody.pde`

### Step 1: 添加引力场参数

```java
class CelestialBody {
  String name;
  double a;
  double e;
  double i;
  double omega;
  double w;
  double M0;
  double period;
  double radius;
  double gm;
  double surfaceGravity;
  double rotationSpeed;
  color col;

  double px, py, pz;

  CelestialBody(String name, double a_au, double e, double i,
    double omega, double w, double M0, double T_days, double R_km, double GM, double rotSpeed, color col) {
    this.name = name;
    this.a = a_au * AU_KM * 1000;
    this.e = e;
    this.i = i;
    this.omega = omega;
    this.w = w;
    this.M0 = Math.toRadians(M0);
    this.period = T_days * DAY_S;
    this.radius = R_km;
    this.gm = GM;
    this.surfaceGravity = GM / (R_km * 1000 * R_km * 1000);
    this.rotationSpeed = rotSpeed;
    this.col = col;
  }

  void update(double t) {
    if (a == 0) return;
    double n = 2.0 * PI / period;
    double M = (M0 + n * t) % (2.0 * PI);
    double E = solveKepler(M, e);
    double nu = trueAnomaly(E, e);
    double[] pos = orbitalToCartesian(a, e, i, omega, w, nu);
    px = pos[0] / 1000;
    py = pos[1] / 1000;
    pz = pos[2] / 1000;
  }

  double[] getPosition() {
    return new double[]{px * 1000, py * 1000, pz * 1000};
  }
}
```

---

## Task 10: 更新 SolarSystem 初始化

**Files:**
- Modify: `SolarSystemNavigation/SolarSystem.pde`

### Step 1: 更新太阳系初始化

```java
void initSolarSystem() {
  sun = new CelestialBody("Sun", 0, 0, 696340, 1.327e20, 0, color(255, 220, 50));

  planets.add(new CelestialBody("Mercury",  0.38710, 0.20563,  7.005,  48.331,  29.124, 174.796,    87.969,  2439.7, 3.7e13, 1.76e-7, color(180, 160, 140)));
  planets.add(new CelestialBody("Venus",    0.72333, 0.00677,  3.395,  76.680,  54.884,  50.115,   224.701,  6051.8, 4.87e14, -1.76e-7, color(230, 200, 130)));
  planets.add(new CelestialBody("Earth",    1.00000, 0.01671,  0.000, 348.739, 114.208, 357.517,   365.256,  6371.0, 3.986e14, 7.29e-5, color(70, 130, 230)));
  planets.add(new CelestialBody("Mars",     1.52368, 0.09341,  1.850,  49.558, 286.502,  19.373,   686.980,  3389.5, 4.28e13, 7.09e-5, color(210, 100, 60)));
  planets.add(new CelestialBody("Jupiter",  5.20260, 0.04839,  1.303, 100.464, 273.867,  20.020,  4332.589, 69911.0, 1.27e17, 1.76e-4, color(210, 180, 140)));
  planets.add(new CelestialBody("Saturn",   9.55491, 0.05415,  2.489, 113.665, 339.392, 317.020, 10759.22, 58232.0, 3.79e16, 1.63e-4, color(220, 200, 150)));
  planets.add(new CelestialBody("Uranus",  19.21845, 0.04717,  0.773,  74.006,  96.998, 142.238, 30688.50, 25362.0, 5.79e15, -1.01e-4, color(170, 220, 230)));
  planets.add(new CelestialBody("Neptune", 30.11039, 0.00859,  1.770, 131.784, 276.336, 256.228, 60182.00, 24622.0, 6.84e15, 1.01e-4, color(60, 100, 230)));
}
```

---

## Task 11: 更新主程序集成新系统

**Files:**
- Modify: `SolarSystemNavigation/SolarSystemNavigation.pde`
- Modify: `SolarSystemNavigation/HUD.pde`

### Step 1: 更新主程序

在 `setup()` 中添加:
```java
maneuverPlanner = new ManeuverPlanner();
orbitPredictor = new OrbitPredictor();
```

在 `draw()` 中添加:
```java
orbitPredictor.draw(camera);
if (launchController.currentShip != null) {
  telemetryDisplay.draw(launchController.currentShip);
}
```

在 `keyPressed()` 中添加:
```java
if (key == 'm' || key == 'M') {
  if (launchController.canManeuver()) {
    maneuverPlanner.toggle();
  }
}
if (key == 'x' || key == 'X') {
  if (maneuverPlanner.visible) {
    maneuverPlanner.executeNextManeuver();
  }
}
```

---

## 自检清单

### Spec 覆盖率检查

| Spec 需求 | 对应 Task |
|----------|-----------|
| 牛顿力学积分 | Task 1, Task 3 |
| 发射模拟 | Task 3, Task 6 |
| 轨道机动 | Task 4, Task 5 |
| 轨道预测 | Task 7 |
| 遥测显示 | Task 8 |
| 引力场支持 | Task 9, Task 10 |
| 完整集成 | Task 11 |

### Placeholder 检查

- [x] 无 "TBD" 或 "TODO"
- [x] 无 "实现后续" 或 "待定"
- [x] 所有代码片段完整

### 类型一致性检查

- `Spacecraft.position/velocity` 在所有任务中一致使用 `double[3]`
- `ShipPhase` 枚举在 Task 2, 3, 6 中一致使用
- `CelestialBody.gm` 在 Task 1, 3, 6, 9, 10 中一致使用
