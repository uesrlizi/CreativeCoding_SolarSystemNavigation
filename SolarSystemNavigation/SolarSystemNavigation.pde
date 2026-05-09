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
           timeManager.WARP_LEVELS, solarSystem.planets);
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
    drawOrbitPath(s.a, s.e, s.i, s.omega, s.w, color(red(s.col), green(s.col), blue(s.col), 40));
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
//  Time Manager
// ============================================================
class TimeManager {
  double simTime;
  double timeWarp;
  double[] WARP_LEVELS;
  int warpIndex = 3;

  TimeManager() {
    simTime = 0;
    WARP_LEVELS = new double[8];
    WARP_LEVELS[0] = 1;
    WARP_LEVELS[1] = 10;
    WARP_LEVELS[2] = 100;
    WARP_LEVELS[3] = 1000;
    WARP_LEVELS[4] = 10000;
    WARP_LEVELS[5] = 100000;
    WARP_LEVELS[6] = 1e6;
    WARP_LEVELS[7] = 1e7;
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
  camera.handleMousePressed();
  hud.launchUI.handleClick(mouseX, mouseY);
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
  if (hud.launchUI.inputFocused) {
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
    showLabels = !showLabels;
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
      camera.followShip(launchController.getCurrentShip());
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

void keyTyped() {
  if (hud.launchUI.inputFocused) {
    hud.launchUI.keyPressed(key);
  }
}

void saveCurrentState() {
  double saveTimeWarp = timeManager.timeWarp;
  if (saveTimeWarp == 0) {
    saveTimeWarp = timeManager.WARP_LEVELS[timeManager.warpIndex];
  }
  saveManager.save(timeManager.simTime, saveTimeWarp, timeManager.warpIndex);
}
