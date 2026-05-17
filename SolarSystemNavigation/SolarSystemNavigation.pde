// ============================================================
//  Spacecraft Launch Simulator
//  Processing (Java Mode) · Kepler Orbital Mechanics
//  Launch from Earth to orbit · Hohmann Transfer · Multi-view
// ============================================================

import java.util.ArrayList;
import java.util.List;

// ---------- Physical Constants ----------
static final double AU_KM       = 1.496e8;
static final double GM_SUN      = 1.327124e11;
static final double DAY_S       = 86400.0;

// ---------- Helper Functions ----------
// 辅助函数：格式化时间，自动选择合适的单位
String formatSimTime(double simSeconds) {
  if (simSeconds < 60.0) {
    return String.format("%.1f s", simSeconds);
  } else if (simSeconds < 60.0 * 60.0) {
    return String.format("%.1f min", simSeconds / 60.0);
  } else if (simSeconds < 24.0 * 60.0 * 60.0) {
    return String.format("%.1f h", simSeconds / (60.0 * 60.0));
  } else {
    return String.format("%.1f days", simSeconds / DAY_S);
  }
}

// ---------- Display Options ----------
boolean showOrbits = true;
boolean showLabels = true;
boolean showTrails = true;
boolean showSOI = false;       // SOI边界显示开关

// ---------- Double-click / Focus ----------
long lastClickTime = 0;
int lastClickX, lastClickY;
static final int DOUBLE_CLICK_MS = 300;
static final int DOUBLE_CLICK_PX = 15;
static final double FOCUS_HIT_RADIUS = 60;

// ---------- Starfield Background ----------
int[] starSeed;

// ---------- Frame Timing ----------
float deltaTime = 1.0 / 60.0;
int lastFrameMillis;

// ---------- Global Systems (新架构) ----------
FlightSystem flightSystem;
PhysicsSystem physicsSystem;
GuidanceSystem guidanceSystem;
OrbitPropagator orbitPropagator;
FlightComputer flightComputer;
PhysicsEngine physicsEngine;
AtmosphereModel atmosphereModel;
SpacecraftForceModel spacecraftForceModel;

// ---------- Global Objects ----------
CameraController camera;
SolarSystem solarSystem;
HUD hud;
TimeManager timeManager;
LaunchController launchController;
SpacecraftRenderer spacecraftRenderer;
LaunchSite launchSite;
LaunchSiteRenderer launchSiteRenderer;
float uiScale;
SOISystem soiSystem;  // SOI系统

// ============================================================
//  settings / setup / draw
// ============================================================
void settings() {
  fullScreen();
}

void setup() {
  // Clear debug log
  try {
    new java.io.PrintWriter(sketchPath("debug_log.txt")).close();
  } catch (Exception e) { }

  uiScale = height / 1080.0;
  lastFrameMillis = millis();
  textFont(createFont("Segoe UI Semibold", 48));
  camera = new CameraController();
  camera.initialize((width * 0.15) / (1.0 * AU_KM));

  starSeed = new int[1500];
  for (int i = 0; i < starSeed.length; i++) {
    starSeed[i] = (int)random(10000);
  }

  // 初始化新架构的系统
  flightSystem = new FlightSystem();
  physicsSystem = new PhysicsSystem();
  guidanceSystem = new GuidanceSystem(flightSystem);
  orbitPropagator = new OrbitPropagator();
  flightComputer = new FlightComputer();
  physicsEngine = new PhysicsEngine();
  atmosphereModel = new AtmosphereModel();
  spacecraftForceModel = new SpacecraftForceModel();

  timeManager = new TimeManager();
  launchController = new LaunchController();
  launchController.setFlightSystem(flightSystem);
  launchController.setGuidanceSystem(guidanceSystem);

  solarSystem = new SolarSystem();

  // 初始化SOI系统
  soiSystem = new SOISystem(solarSystem, launchController.planner);
  soiSystem.setOrbitPropagator(orbitPropagator);
  solarSystem.initialize();

  // Create default spacecraft on Earth's day-side launch pad
  CelestialBody earth = solarSystem.planets.get(2);
  double launchAngle = Math.atan2(-earth.py, -earth.px);

  Spacecraft defaultShip = new Spacecraft(0, 0, 0, 0, 0, 0, 0, color(0, 255, 150));
  defaultShip.currentCentralBody = earth;
  defaultShip.earthRef = earth;  // 兼容性
  defaultShip.earthRelative = true;  // 兼容性
  defaultShip.launchPadAngle = launchAngle;
  defaultShip.displayAngle = launchAngle;
  defaultShip.launchAltitude = 0.0488;  // ~49m, engines rest on pad surface
  defaultShip.orbitAngle = launchAngle;
  defaultShip.earthOrbitAngle = launchAngle;  // 兼容性
  defaultShip.orbitStartTime = 0;
  double startRadius = MissionPlanner.EARTH_RADIUS_KM + defaultShip.launchAltitude;
  defaultShip.pos[0] = startRadius * Math.cos(launchAngle);
  defaultShip.pos[1] = startRadius * Math.sin(launchAngle);
  defaultShip.pos[2] = 0;
  defaultShip.vel[0] = 0;
  defaultShip.vel[1] = 0;
  defaultShip.vel[2] = 0;
  defaultShip.lastUpdateTime = 0;
  defaultShip.thrustActive = false;
  defaultShip.state = ShipState.IDLE;
  defaultShip.px = earth.px + defaultShip.pos[0];
  defaultShip.py = earth.py + defaultShip.pos[1];

  solarSystem.ships.add(defaultShip);
  launchController.currentShip = defaultShip;
  camera.followShip(defaultShip);

  launchSite = new LaunchSite(earth, launchAngle);
  launchSiteRenderer = new LaunchSiteRenderer();

  hud = new HUD();

  spacecraftRenderer = new SpacecraftRenderer();
}

// DEBUG: trace freeze location — writes to sketch folder / debug_log.txt
void dbgLog(String msg) {
  try {
    java.io.PrintWriter w = new java.io.PrintWriter(
      new java.io.FileWriter(sketchPath("debug_log.txt"), true));
    w.println(frameCount + ": " + msg);
    w.flush();
    w.close();
  } catch (Exception e) { }
}

void draw() {
  try {
    background(5, 5, 15);

    int now = millis();
    deltaTime = (now - lastFrameMillis) / 1000.0;
    if (deltaTime <= 0 || deltaTime > 0.5) deltaTime = 1.0 / 60.0;
    lastFrameMillis = now;

    timeManager.update(deltaTime);
    launchController.update();
    solarSystem.update(timeManager.simTime);
    solarSystem.updateRenderer(deltaTime);

    // 新架构的更新流程
    for (Spacecraft s : solarSystem.ships) {
      double simDt = timeManager.simTime - s.lastUpdateTime;
      if (simDt <= 0) simDt = 1.0 / 60.0;
      if (simDt > 3600) simDt = 3600;
      s.lastUpdateTime = timeManager.simTime;

      // 1. 制导计算（输出推力命令）
      guidanceSystem.update(s, simDt, timeManager.simTime);

      // 2. 飞行系统更新（运动计算）
      flightSystem.update(s, simDt, timeManager.simTime);

      // 3. 显示角度更新
      s.updateDisplayAngleSmooth(timeManager.simTime, simDt);
    }

    camera.update(deltaTime);
    drawStars();
    drawOrbits();
    if (showSOI) {
      drawSOIBoundaries();
    }
    solarSystem.drawSun(camera);
    solarSystem.drawPlanets(camera);

    launchSite.update();
    if (launchController.getCurrentShip() != null) {
      launchSiteRenderer.draw(launchSite, camera, launchController.getCurrentShip());
    }

    for (Spacecraft s : solarSystem.ships) {
      spacecraftRenderer.draw(s, camera);
    }

    hud.update();
    hud.draw(camera, timeManager.simTime, timeManager.timeWarp,
             timeManager.WARP_LEVELS, timeManager.WARP_LABELS,
             timeManager.warpIndex, solarSystem.planets, solarSystem.sun);
  } catch (Exception e) {
    dbgLog("DRAW EXCEPTION: " + e.toString());
    e.printStackTrace();
  }
}

// ============================================================
//  Starfield
// ============================================================
void drawStars() {
  noStroke();
  // Draw milky way band
  drawMilkyWay();
  // Draw stars
  for (int i = 0; i < starSeed.length; i++) {
    int sx = (starSeed[i] * 7 + 13) % width;
    int sy = (starSeed[i] * 11 + 29) % height;
    int baseBright = 80 + (starSeed[i] * 3) % 120;
    float twinkle = 0.7f + 0.3f * sin(millis() * 0.003f + starSeed[i]);
    int brightness = (int)(baseBright * twinkle);
    int sz = (starSeed[i] % 3 == 0) ? 2 : 1;
    // Color variation
    int r = brightness;
    int g = brightness;
    int b = brightness + (starSeed[i] % 40);
    if (starSeed[i] % 17 == 0) {
      r = brightness + 30;
      g = brightness - 10;
      b = brightness - 20;
    } else if (starSeed[i] % 13 == 0) {
      r = brightness - 10;
      g = brightness;
      b = brightness + 30;
    }
    fill(r, g, b);
    ellipse(sx, sy, sz, sz);
  }
}

void drawMilkyWay() {
  float centerX = width * 0.5f;
  float centerY = height * 0.6f;
  float bandWidth = width * 0.8f;
  float bandHeight = height * 0.35f;
  noStroke();
  // Multiple layers for depth
  for (int layer = 0; layer < 5; layer++) {
    float alpha = 8 - layer * 1.5f;
    for (int i = 0; i < 200; i++) {
      float angle = random(TWO_PI);
      float dist = random(1);
      dist = pow(dist, 0.5f); // Concentrate towards center
      float x = centerX + cos(angle) * dist * bandWidth * 0.5f;
      float y = centerY + sin(angle) * dist * bandHeight * 0.5f;
      float size = random(1, 4);
      float n = noise(x * 0.01f, y * 0.01f, layer * 0.5f);
      if (n > 0.4f) {
        fill(80, 90, 120, (int)(alpha * n));
        ellipse(x, y, size, size);
      }
    }
  }
}

// ============================================================
//  Orbit Paths
// ============================================================
void drawOrbits() {
  if (!showOrbits) return;
  if (camera.getMode() == ViewMode.SHIP_VIEW) return;  // orbits meaningless at ship scale
  for (CelestialBody p : solarSystem.planets) {
    if (p.a == 0) continue;
    drawOrbitPath(p.a, p.e, p.i, p.omega, p.w, color(60, 60, 80, 100));
  }
  for (Spacecraft s : solarSystem.ships) {
    if (s.earthRelative && s.earthRef != null) {
      drawEarthRelOrbit(s);
    } else if (!s.earthRelative) {
      drawOrbitPath(s.a, s.e, s.i, s.omega, s.w, color(red(s.col), green(s.col), blue(s.col)));
    }
  }
}

void drawOrbitPath(double a, double e, double i, double omega, double w, color c) {
  noFill();
  stroke(c);
  strokeWeight(0.8);
  beginShape();
  int steps = 200;
  for (int j = 0; j <= steps; j++) {
    double nu = 2.0 * PI * j / steps;
    double[] pos = orbitalToCartesian(a, e, i, omega, w, nu);
    double[] sp = camera.worldToScreen(pos[0], pos[1]);
    vertex((float)sp[0], (float)sp[1]);
  }
  endShape(CLOSE);
}

void drawEarthRelOrbit(Spacecraft s) {
  if (s.state == ShipState.LAUNCHING || s.state == ShipState.CIRCULARIZING || s.state == ShipState.TMI_BURN) {
    double[] ke = cartesianToKepler(
      new double[]{s.earthRelPos[0], s.earthRelPos[1], 0},
      new double[]{s.earthRelVel[0], s.earthRelVel[1], 0},
      MissionPlanner.GM_EARTH);
    double ea = ke[0];
    double ee = ke[1];
    double ei = ke[2];
    double eOmega = ke[3];
    double ew = ke[4];
    double eNu = Math.toRadians(ke[5]);

    double cosNu = Math.cos(eNu);
    double sinNu = Math.sin(eNu);
    double denom = 1.0 + ee * cosNu;
    double cosE = (ee + cosNu) / denom;
    double sinE = Math.sqrt(1.0 - ee * ee) * sinNu / denom;
    double curE = Math.atan2(sinE, cosE);

    double eArc = 1.0;
    int steps = 200;
    double rEarth = MissionPlanner.EARTH_RADIUS_KM;
    color c = color(red(s.col), green(s.col), blue(s.col));

    double[][] pts = new double[steps + 1][2];
    boolean[] above = new boolean[steps + 1];
    for (int j = 0; j <= steps; j++) {
      double E = curE - eArc + (2.0 * eArc * j / steps);
      double nu = trueAnomaly(E, ee);
      double[] pos = orbitalToCartesian(ea, ee, ei, eOmega, ew, nu);
      pts[j][0] = pos[0];
      pts[j][1] = pos[1];
      above[j] = Math.sqrt(pos[0] * pos[0] + pos[1] * pos[1]) >= rEarth;
    }

    noFill();
    stroke(c);
    strokeWeight(0.8);

    boolean inShape = false;
    if (above[0]) {
      beginShape();
      inShape = true;
      double[] sp = camera.worldToScreen(
        s.earthRef.px + pts[0][0], s.earthRef.py + pts[0][1]);
      vertex((float)sp[0], (float)sp[1]);
    }

    for (int j = 1; j <= steps; j++) {
      if (above[j - 1] && above[j]) {
        double[] sp = camera.worldToScreen(
          s.earthRef.px + pts[j][0], s.earthRef.py + pts[j][1]);
        vertex((float)sp[0], (float)sp[1]);
      } else if (above[j - 1] && !above[j]) {
        double[] isect = sphereIntersect(pts[j - 1], pts[j], rEarth);
        if (isect != null) {
          double[] sp = camera.worldToScreen(
            s.earthRef.px + isect[0], s.earthRef.py + isect[1]);
          vertex((float)sp[0], (float)sp[1]);
        }
        endShape();
        inShape = false;
      } else if (!above[j - 1] && above[j]) {
        double[] isect = sphereIntersect(pts[j - 1], pts[j], rEarth);
        beginShape();
        inShape = true;
        if (isect != null) {
          double[] sp = camera.worldToScreen(
            s.earthRef.px + isect[0], s.earthRef.py + isect[1]);
          vertex((float)sp[0], (float)sp[1]);
        }
        double[] sp = camera.worldToScreen(
          s.earthRef.px + pts[j][0], s.earthRef.py + pts[j][1]);
        vertex((float)sp[0], (float)sp[1]);
      }
    }

    if (inShape) {
      endShape();
    }
  } else {
    double radius = MissionPlanner.LEO_RADIUS_KM;
    double cx = s.earthRef.px;
    double cy = s.earthRef.py;

    noFill();
    stroke(red(s.col), green(s.col), blue(s.col));
    strokeWeight(0.8);
    beginShape();
    int steps = 200;
    for (int j = 0; j <= steps; j++) {
      double a = 2.0 * PI * j / steps;
      double[] sp = camera.worldToScreen(
        cx + radius * Math.cos(a),
        cy + radius * Math.sin(a));
      vertex((float)sp[0], (float)sp[1]);
    }
    endShape(CLOSE);
  }
}

double[] sphereIntersect(double[] P, double[] Q, double R) {
  double dx = Q[0] - P[0];
  double dy = Q[1] - P[1];
  double a = dx * dx + dy * dy;
  if (a < 1e-20) return null;
  double b = 2.0 * (P[0] * dx + P[1] * dy);
  double c = (P[0] * P[0] + P[1] * P[1]) - R * R;
  double disc = b * b - 4.0 * a * c;
  if (disc < 0) return null;

  double sqrtDisc = Math.sqrt(disc);
  double t0 = (-b - sqrtDisc) / (2.0 * a);
  double t1 = (-b + sqrtDisc) / (2.0 * a);

  double t = (t0 >= 0.0 && t0 <= 1.0) ? t0 : t1;
  if (t < 0.0 || t > 1.0) return null;

  return new double[]{P[0] + t * dx, P[1] + t * dy};
}

// ============================================================
//  Controls
// ============================================================
void mousePressed() {
  // HUD 面板优先处理
  if (hud.handleMousePressed(mouseX, mouseY, camera, solarSystem.sun, solarSystem.planets)) {
    return;
  }
  // HUD 未消费 -> 地图双击/相机拖拽
  long now = millis();
  if (now - lastClickTime < DOUBLE_CLICK_MS &&
      dist(mouseX, mouseY, lastClickX, lastClickY) < DOUBLE_CLICK_PX) {
    handleDoubleClick();
    lastClickTime = 0;
    return;
  }
  lastClickTime = now;
  lastClickX = mouseX;
  lastClickY = mouseY;
  camera.handleMousePressed();
}

void handleDoubleClick() {
  if (camera.getMode() == ViewMode.SHIP_VIEW) return;

  CelestialBody closestBody = null;
  Spacecraft closestShip = null;
  double minDist = FOCUS_HIT_RADIUS;

  for (CelestialBody p : solarSystem.planets) {
    double[] sp = camera.worldToScreen(p.px, p.py);
    double d = dist((float)sp[0], (float)sp[1], mouseX, mouseY);
    if (d < minDist) { minDist = d; closestBody = p; }
  }

  double[] sunSp = camera.worldToScreen(0, 0);
  double sunD = dist((float)sunSp[0], (float)sunSp[1], mouseX, mouseY);
  if (sunD < minDist) { minDist = sunD; closestBody = solarSystem.sun; }

  for (Spacecraft s : solarSystem.ships) {
    double[] sp = camera.worldToScreen(s.px, s.py);
    double d = dist((float)sp[0], (float)sp[1], mouseX, mouseY);
    if (d < minDist) { minDist = d; closestBody = null; closestShip = s; }
  }

  if (closestShip != null) {
    camera.focusOn(closestShip);
  } else if (closestBody != null) {
    camera.focusOn(closestBody);
  } else {
    camera.focusOn(solarSystem.sun);
  }
}

void mouseDragged() {
  camera.handleMouseDragged();
}

void mouseReleased() {
  camera.handleMouseReleased();
}

void mouseWheel(MouseEvent event) {
  camera.handleMouseWheel(event);
}

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
  if (key == 'k' || key == 'K') {
    showSOI = !showSOI;
    dbgLog("SOI显示: " + (showSOI ? "开启" : "关闭"));
  }
  if (key == 'l' || key == 'L') {
    if (launchController.canLaunch()) {
      launchController.startLaunch();
    } else {
      showLabels = !showLabels;
    }
  }
  if (key == 't' || key == 'T') {
    if (launchController.canTransfer()) {
      launchController.initiateTransfer();
    } else {
      showTrails = !showTrails;
    }
  }

  if (key == 'v' || key == 'V') {
    if (camera.getMode() == ViewMode.MAP_VIEW) {
      if (camera.followTarget == null && launchController.getCurrentShip() != null) {
        camera.followShip(launchController.getCurrentShip());
      }
      camera.setViewMode(ViewMode.SHIP_VIEW);
    } else {
      camera.setViewMode(ViewMode.MAP_VIEW);
    }
  }

  if (key == 'f' || key == 'F') {
    camera.snapFocus();
  }
}

void keyTyped() {
}

// ============================================================
//  SOI Boundaries
// ============================================================
void drawSOIBoundaries() {
  if (camera.getMode() == ViewMode.SHIP_VIEW) return;

  // 绘制行星的SOI
  for (CelestialBody planet : solarSystem.planets) {
    drawSingleSOI(planet);
  }

  // 绘制卫星的SOI
  for (CelestialBody moon : solarSystem.moons) {
    drawSingleSOI(moon);
  }
}

void drawSingleSOI(CelestialBody body) {
  double soiRadius = soiSystem.calculateSOIRadius(body);

  // 如果太小就不绘制（小于1像素）
  double screenRadius = soiRadius * camera.scale;
  if (screenRadius < 2) return;

  // 获取颜色
  int soiColor = soiSystem.getSOIColor(body);

  // 绘制圆
  noFill();
  stroke(soiColor);
  strokeWeight(1.0f);
  ellipseMode(CENTER);

  int steps = 60;
  beginShape();
  for (int i = 0; i <= steps; i++) {
    double angle = 2.0 * PI * i / steps;
    double worldX = body.px + soiRadius * Math.cos(angle);
    double worldY = body.py + soiRadius * Math.sin(angle);
    double[] sp = camera.worldToScreen(worldX, worldY);
    vertex((float)sp[0], (float)sp[1]);
  }
  endShape(CLOSE);

  // 绘制SOI标签（只在足够大时显示）
  if (screenRadius > 30 && showLabels) {
    double[] labelPos = camera.worldToScreen(body.px + soiRadius * 1.05, body.py);
    fill(soiColor);
    textSize(12 * uiScale);
    textAlign(LEFT, CENTER);
    text(body.name + " SOI", (float)labelPos[0], (float)labelPos[1]);
  }
}

