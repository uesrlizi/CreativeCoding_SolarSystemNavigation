// ============================================================
//  Spacecraft Flight Simulator
//  Processing (Java Mode) · Newtonian Physics
//  Launch from Earth · Orbital Maneuvers · Interplanetary
// ============================================================

import java.util.ArrayList;
import java.util.List;

static final double AU_KM = 1.496e8;
static final double GM_SUN = 1.327124e11;
static final double DAY_S = 86400.0;

boolean showOrbits = true;
boolean showLabels = true;
boolean showTrails = true;

int[] starSeed;

CameraController camera;
SolarSystem solarSystem;
HUD hud;
TimeManager timeManager;
SaveDataManager saveManager;
LaunchController launchController;
ManeuverPlanner maneuverPlanner;
OrbitPredictor orbitPredictor;
TelemetryDisplay telemetryDisplay;
PhysicsEngine physics;

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
  physics = new PhysicsEngine();
  orbitPredictor = new OrbitPredictor();
  telemetryDisplay = new TelemetryDisplay();
  launchController = new LaunchController();
  maneuverPlanner = launchController.maneuverPlanner;

  timeManager.timeWarp = timeManager.WARP_LEVELS[0];

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

  drawStars();
  if (showOrbits) drawOrbits();
  solarSystem.drawSun(camera);
  solarSystem.drawPlanets(camera);

  for (Spacecraft s : solarSystem.ships) {
    s.draw(camera);
  }

  orbitPredictor.draw(camera);

  CelestialBody launchBody = launchController.getLaunchBody();
  if (launchBody != null && launchController.currentShip != null) {
    telemetryDisplay.draw(launchController.currentShip, launchBody);
  }

  maneuverPlanner.draw(launchController.currentShip, launchBody);
  hud.draw(camera, timeManager.simTime, timeManager.timeWarp, launchController.getStatusText());
}

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

void drawOrbits() {
  for (CelestialBody p : solarSystem.planets) {
    if (p.a == 0) continue;
    drawOrbitPath(p.a / 1000, p.e, p.i, p.omega, p.w, color(60, 60, 80, 100));
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

double[] orbitalToCartesian(double a, double e, double i_deg,
    double omega_deg, double w_deg, double nu) {
  double r = a * (1.0 - e * e) / (1.0 + e * Math.cos(nu));
  double xOrb = r * Math.cos(nu);
  double yOrb = r * Math.sin(nu);

  double i = Math.toRadians(i_deg);
  double omega = Math.toRadians(omega_deg);
  double w = Math.toRadians(w_deg);

  double cosO = Math.cos(omega), sinO = Math.sin(omega);
  double cosW = Math.cos(w), sinW = Math.sin(w);
  double cosI = Math.cos(i), sinI = Math.sin(i);

  double x = (cosO * cosW - sinO * sinW * cosI) * xOrb + (-cosO * sinW - sinO * cosW * cosI) * yOrb;
  double y = (sinO * cosW + cosO * sinW * cosI) * xOrb + (-sinO * sinW + cosO * cosW * cosI) * yOrb;
  double z = (sinW * sinI) * xOrb + (cosW * sinI) * yOrb;

  return new double[]{x, y, z};
}

class TimeManager {
  double simTime;
  double timeWarp;
  double[] WARP_LEVELS;
  int warpIndex = 0;
  int lastMillis;

  TimeManager() {
    simTime = 0;
    lastMillis = millis();
    WARP_LEVELS = new double[8];
    WARP_LEVELS[0] = 1.0;
    WARP_LEVELS[1] = 60.0;
    WARP_LEVELS[2] = 600.0;
    WARP_LEVELS[3] = 3600.0;
    WARP_LEVELS[4] = 36000.0;
    WARP_LEVELS[5] = 86400.0;
    WARP_LEVELS[6] = 604800.0;
    WARP_LEVELS[7] = 2592000.0;
    timeWarp = WARP_LEVELS[warpIndex];
  }

  void update() {
    if (timeWarp > 0) {
      int currentMillis = millis();
      double realDelta = (currentMillis - lastMillis) / 1000.0;
      simTime += timeWarp * realDelta;
      lastMillis = currentMillis;
    } else {
      lastMillis = millis();
    }
  }

  String getTimeDisplay() {
    int totalSeconds = (int)simTime;
    int days = totalSeconds / 86400;
    int hours = (totalSeconds % 86400) / 3600;
    int minutes = (totalSeconds % 3600) / 60;
    int seconds = totalSeconds % 60;
    return String.format("T+%d d %02d:%02d:%02d", days, hours, minutes, seconds);
  }

  String getWarpDisplay() {
    String[] labels = {"1x", "1m/s", "10m/s", "1h/s", "10h/s", "1d/s", "1w/s", "1mo/s"};
    return labels[warpIndex];
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

void mousePressed() {
  camera.handleMousePressed();
  hud.launchUI.handleClick(mouseX, mouseY);

  CelestialBody launchBody = launchController.getLaunchBody();
  maneuverPlanner.handleClick(mouseX, mouseY, launchController.currentShip, launchBody);
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

  if (key == 'l' || key == 'L') {
    if (launchController.canLaunch() && hud.launchUI.shipName.length() > 0) {
      launchController.startLaunch(hud.launchUI.shipName);
    }
  }

  if (key == 'm' || key == 'M') {
    if (launchController.canManeuver()) {
      maneuverPlanner.toggle();
    }
  }

  if (key == 'x' || key == 'X') {
    if (maneuverPlanner.visible && launchController.currentShip != null) {
      maneuverPlanner.executeNext(launchController.currentShip);
    }
  }

  if (key == 'o' || key == 'O') showOrbits = !showOrbits;
  if (key == 't' || key == 'T') showTrails = !showTrails;

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
    if (launchController.currentShip != null) {
      camera.followShip(launchController.currentShip);
      camera.setViewMode(ViewMode.MAP_VIEW);
    }
  }

  if (key >= '1' && key <= '8') {
    int idx = key - '1';
    if (idx < solarSystem.planets.size()) {
      CelestialBody p = solarSystem.planets.get(idx);
      camera.focusOn(p.px, p.py, (width * 0.2) / (p.a / 1000));
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
  CelestialBody launchBody = launchController.getLaunchBody();
  maneuverPlanner.handleKey(key, launchController.currentShip, launchBody);
}

void saveCurrentState() {
  double saveTimeWarp = timeManager.timeWarp;
  if (saveTimeWarp == 0) {
    saveTimeWarp = timeManager.WARP_LEVELS[timeManager.warpIndex];
  }
  saveManager.save(timeManager.simTime, saveTimeWarp, timeManager.warpIndex);
}
