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

// ---------- Display Options ----------
boolean showOrbits = true;
boolean showLabels = true;
boolean showTrails = true;

// ---------- Double-click / Focus ----------
long lastClickTime = 0;
int lastClickX, lastClickY;
static final int DOUBLE_CLICK_MS = 300;
static final int DOUBLE_CLICK_PX = 15;
static final double FOCUS_HIT_RADIUS = 60;

// ---------- Starfield Background ----------
int[] starSeed;

// ---------- Global Objects ----------
CameraController camera;
SolarSystem solarSystem;
HUD hud;
TimeManager timeManager;
SaveDataManager saveManager;
LaunchController launchController;

// ============================================================
//  setup / draw
// ============================================================
void setup() {
  fullScreen();
  camera = new CameraController();
  camera.initialize((width * 0.15) / (1.0 * AU_KM));

  starSeed = new int[600];
  for (int i = 0; i < starSeed.length; i++) {
    starSeed[i] = (int)random(10000);
  }

  saveManager = new SaveDataManager();
  timeManager = new TimeManager();
  launchController = new LaunchController();

  SaveData saved = saveManager.load();
  if (saved != null) {
    timeManager.simTime = saved.simTime;
    timeManager.warpIndex = saved.warpIndex;
    timeManager.timeWarp = saved.timeWarp;
  }

  timeManager.timeWarp = 0;

  solarSystem = new SolarSystem();
  solarSystem.initialize();

  hud = new HUD();

  Runtime.getRuntime().addShutdownHook(new Thread() {
    public void run() {
      saveCurrentState();
    }
  });
}

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
           timeManager.WARP_LEVELS, timeManager.WARP_LABELS,
           timeManager.warpIndex, solarSystem.planets);
}

// ============================================================
//  Starfield
// ============================================================
void drawStars() {
  noStroke();
  for (int i = 0; i < starSeed.length; i++) {
    int sx = (starSeed[i] * 7 + 13) % width;
    int sy = (starSeed[i] * 11 + 29) % height;
    int brightness = 80 + (starSeed[i] * 3) % 120;
    int sz = (starSeed[i] % 3 == 0) ? 2 : 1;
    fill(brightness, brightness, brightness + 20);
    ellipse(sx, sy, sz, sz);
  }
}

// ============================================================
//  Orbit Paths
// ============================================================
void drawOrbits() {
  if (!showOrbits) return;
  for (CelestialBody p : solarSystem.planets) {
    if (p.a == 0) continue;
    drawOrbitPath(p.a, p.e, p.i, p.omega, p.w, color(60, 60, 80, 100));
  }
  for (Spacecraft s : solarSystem.ships) {
    if (s.earthRelative && s.earthRef != null) {
      drawEarthRelOrbit(s);
    } else if (!s.earthRelative) {
      drawOrbitPath(s.a, s.e, s.i, s.omega, s.w, color(red(s.col), green(s.col), blue(s.col), 40));
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
  double radius = MissionPlanner.LEO_RADIUS_KM;
  double cx = s.earthRef.px;
  double cy = s.earthRef.py;

  noFill();
  stroke(red(s.col), green(s.col), blue(s.col), 50);
  strokeWeight(0.8);
  beginShape();
  int steps = 128;
  for (int j = 0; j <= steps; j++) {
    double a = 2.0 * PI * j / steps;
    double[] sp = camera.worldToScreen(
      cx + radius * Math.cos(a),
      cy + radius * Math.sin(a));
    vertex((float)sp[0], (float)sp[1]);
  }
  endShape(CLOSE);
}

// ============================================================
//  Kepler Equation Solver
// ============================================================
double solveKepler(double M, double e) {
  double E = M;
  for (int i = 0; i < 50; i++) {
    double dE = (E - e * Math.sin(E) - M) / (1.0 - e * Math.cos(E));
    E -= dE;
    if (Math.abs(dE) < 1e-12) break;
  }
  return E;
}

double trueAnomaly(double E, double e) {
  return 2.0 * Math.atan2(Math.sqrt(1.0 + e) * Math.sin(E / 2.0), Math.sqrt(1.0 - e) * Math.cos(E / 2.0));
}

// ============================================================
//  Coordinate Transformation
// ============================================================
double[] orbitalToCartesian(double a, double e, double i_deg,
    double omega_deg, double w_deg, double nu) {
  double r = a * (1.0 - e * e) / (1.0 + e * Math.cos(nu));
  double xOrb = r * Math.cos(nu);
  double yOrb = r * Math.sin(nu);

  double i     = Math.toRadians(i_deg);
  double omega = Math.toRadians(omega_deg);
  double w     = Math.toRadians(w_deg);

  double cosO = Math.cos(omega), sinO = Math.sin(omega);
  double cosW = Math.cos(w),     sinW = Math.sin(w);
  double cosI = Math.cos(i),     sinI = Math.sin(i);

  double x = (cosO * cosW - sinO * sinW * cosI) * xOrb +
             (-cosO * sinW - sinO * cosW * cosI) * yOrb;
  double y = (sinO * cosW + cosO * sinW * cosI) * xOrb +
             (-sinO * sinW + cosO * cosW * cosI) * yOrb;
  double z = (sinW * sinI) * xOrb + (cosW * sinI) * yOrb;

  double[] result = new double[3];
  result[0] = x; result[1] = y; result[2] = z;
  return result;
}

// ============================================================
//  Orbital Velocity: perifocal → Cartesian (same rotation as orbitalToCartesian)
// ============================================================
double[] orbitalVelocityToCartesian(double a, double e, double i_deg,
    double omega_deg, double w_deg, double nu, double GM) {
  double p = a * (1.0 - e * e);
  double factor = Math.sqrt(GM / p);
  double vx_pf = -factor * Math.sin(nu);
  double vy_pf = factor * (e + Math.cos(nu));

  double i     = Math.toRadians(i_deg);
  double omega = Math.toRadians(omega_deg);
  double w     = Math.toRadians(w_deg);

  double cosO = Math.cos(omega), sinO = Math.sin(omega);
  double cosW = Math.cos(w),     sinW = Math.sin(w);
  double cosI = Math.cos(i),     sinI = Math.sin(i);

  double vx = (cosO * cosW - sinO * sinW * cosI) * vx_pf +
              (-cosO * sinW - sinO * cosW * cosI) * vy_pf;
  double vy = (sinO * cosW + cosO * sinW * cosI) * vx_pf +
              (-sinO * sinW + cosO * cosW * cosI) * vy_pf;
  double vz = (sinW * sinI) * vx_pf + (cosW * sinI) * vy_pf;

  double[] result = new double[3];
  result[0] = vx; result[1] = vy; result[2] = vz;
  return result;
}

// ============================================================
//  Cartesian state vector → Kepler elements (2D, i=0, omega=0)
// ============================================================
double[] cartesianToKepler(double[] r, double[] v, double GM) {
  double rx = r[0], ry = r[1];
  double vx = v[0], vy = v[1];

  double rMag = Math.sqrt(rx * rx + ry * ry);
  double vMag2 = vx * vx + vy * vy;

  double a = 1.0 / (2.0 / rMag - vMag2 / GM);

  double hz = rx * vy - ry * vx;
  double p = (hz * hz) / GM;

  double e = Math.sqrt(Math.max(0.0, 1.0 - p / a));
  double ex = (vy * hz) / GM - rx / rMag;
  double ey = (-vx * hz) / GM - ry / rMag;

  double w = Math.atan2(ey, ex);
  double nu = Math.atan2(ry, rx) - w;
  nu = ((nu % (2.0 * PI)) + 2.0 * PI) % (2.0 * PI);

  double[] result = new double[6];
  result[0] = a;
  result[1] = e;
  result[2] = 0.0;       // i = 0 (planar)
  result[3] = 0.0;       // omega = 0
  result[4] = Math.toDegrees(w);
  result[5] = Math.toDegrees(nu);
  return result;
}

// ============================================================
//  Time Manager
// ============================================================
class TimeManager {
  double simTime;
  double timeWarp;
  double[] WARP_LEVELS;
  String[] WARP_LABELS;
  int warpIndex = 4;

  TimeManager() {
    simTime = 0;
    WARP_LEVELS = new double[8];
    // Level 0: 1:1 real time (1 sim sec per real sec)
    WARP_LEVELS[0] = 1.0 / 86400.0;
    // Level 1: 1 sim minute per real second
    WARP_LEVELS[1] = 60.0 / 86400.0;
    // Level 2: 10 sim minutes per real second
    WARP_LEVELS[2] = 600.0 / 86400.0;
    // Level 3: 1 sim hour per real second
    WARP_LEVELS[3] = 3600.0 / 86400.0;
    // Level 4: 1 sim day per real second
    WARP_LEVELS[4] = 1.0;
    // Level 5: 10 sim days per real second
    WARP_LEVELS[5] = 10.0;
    // Level 6: 100 sim days per real second
    WARP_LEVELS[6] = 100.0;
    // Level 7: 1000 sim days per real second
    WARP_LEVELS[7] = 1000.0;

    WARP_LABELS = new String[8];
    WARP_LABELS[0] = "1:1 Real Time";
    WARP_LABELS[1] = "1 min/sec";
    WARP_LABELS[2] = "10 min/sec";
    WARP_LABELS[3] = "1 hour/sec";
    WARP_LABELS[4] = "1 day/sec";
    WARP_LABELS[5] = "10 days/sec";
    WARP_LABELS[6] = "100 days/sec";
    WARP_LABELS[7] = "1000 days/sec";

    timeWarp = WARP_LEVELS[warpIndex];
  }

  void update() {
    double dt = (timeWarp * DAY_S) / 60.0;
    simTime += dt;
  }

  void togglePause() {
    if (timeWarp > 0) {
      timeWarp = 0;
    } else {
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  void increaseWarp() {
    warpIndex = min(WARP_LEVELS.length - 1, warpIndex + 1);
    timeWarp = WARP_LEVELS[warpIndex];
  }

  void decreaseWarp() {
    warpIndex = max(0, warpIndex - 1);
    timeWarp = WARP_LEVELS[warpIndex];
  }
}

// ============================================================
//  Controls
// ============================================================
void mousePressed() {
  hud.launchUI.handleClick(mouseX, mouseY);
  if (!hud.launchUI.isPopupOpen()) {
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
}

void handleDoubleClick() {
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
  if (!hud.launchUI.isPopupOpen()) {
    camera.handleMouseDragged();
  }
}

void mouseReleased() {
  if (!hud.launchUI.isPopupOpen()) {
    camera.handleMouseReleased();
  }
}

void mouseWheel(MouseEvent event) {
  camera.handleMouseWheel(event);
}

void keyPressed() {
  // When popup is open, only popup keys work; block all global shortcuts
  if (hud.launchUI.isPopupOpen()) {
    if (key == ESC) {
      hud.launchUI.keyPressed(ESC);
    } else if (key == BACKSPACE) {
      hud.launchUI.keyPressed(BACKSPACE);
    } else if (key == ENTER || key == RETURN) {
      hud.launchUI.keyPressed(ENTER);
    }
    return;
  }

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
  if (key == 'l' || key == 'L') {
    if (launchController.canLaunch()) {
      hud.launchUI.openPopup();
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

  if (key == 'r' || key == 'R') {
    camera.reset();
    camera.targetScale = (width * 0.15) / AU_KM;
  }

  if (key == 'v' || key == 'V') {
    if (camera.getMode() == ViewMode.MAP_VIEW) {
      camera.setViewMode(ViewMode.SHIP_VIEW);
    } else {
      camera.setViewMode(ViewMode.MAP_VIEW);
    }
  }

  if (key == 'f' || key == 'F') {
    if (launchController.getCurrentShip() != null) {
      camera.focusOn(launchController.getCurrentShip());
    }
  }

  if (key >= '1' && key <= '8') {
    int idx = key - '1';
    if (idx < solarSystem.planets.size()) {
      CelestialBody p = solarSystem.planets.get(idx);
      camera.focusOn(p);
    }
  }
  if (key == '0') {
    camera.focusOn(solarSystem.sun);
  }
}

void keyTyped() {
  hud.launchUI.keyPressed(key);
}

void saveCurrentState() {
  double saveTimeWarp = timeManager.timeWarp;
  if (saveTimeWarp == 0) {
    saveTimeWarp = timeManager.WARP_LEVELS[timeManager.warpIndex];
  }
  saveManager.save(timeManager.simTime, saveTimeWarp, timeManager.warpIndex);
}
