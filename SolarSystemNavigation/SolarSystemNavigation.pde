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

// ---------- Frame Timing ----------
float deltaTime = 1.0 / 60.0;
int lastFrameMillis;

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

  starSeed = new int[600];
  for (int i = 0; i < starSeed.length; i++) {
    starSeed[i] = (int)random(10000);
  }

  timeManager = new TimeManager();
  launchController = new LaunchController();

  solarSystem = new SolarSystem();
  solarSystem.initialize();

  // Create default spacecraft on Earth's day-side launch pad
  CelestialBody earth = solarSystem.planets.get(2);
  double launchAngle = Math.atan2(-earth.py, -earth.px);

  Spacecraft defaultShip = new Spacecraft(0, 0, 0, 0, 0, 0, 0, color(0, 255, 150));
  defaultShip.earthRelative = true;
  defaultShip.earthRef = earth;
  defaultShip.launchPadAngle = launchAngle;
  defaultShip.displayAngle = launchAngle;
  defaultShip.launchAltitude = 0.0488;  // ~49m, engines rest on pad surface
  defaultShip.earthOrbitAngle = launchAngle;
  defaultShip.orbitStartTime = 0;
  double startRadius = MissionPlanner.EARTH_RADIUS_KM + defaultShip.launchAltitude;
  defaultShip.earthRelPos = new double[]{
    startRadius * Math.cos(launchAngle),
    startRadius * Math.sin(launchAngle),
    0};
  defaultShip.earthRelVel = new double[]{0, 0, 0};
  defaultShip.lastUpdateTime = 0;
  defaultShip.thrustActive = false;
  defaultShip.state = ShipState.IDLE;
  defaultShip.px = earth.px + defaultShip.earthRelPos[0];
  defaultShip.py = earth.py + defaultShip.earthRelPos[1];

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

    for (Spacecraft s : solarSystem.ships) {
      s.update(timeManager.simTime);
      s.updateDisplayAngle(s.computeTargetWorldAngle(), deltaTime);
    }

    camera.update(deltaTime);
    drawStars();
    drawOrbits();
    solarSystem.drawSun(camera);
    solarSystem.drawPlanets(camera);

    launchSite.update();
    if (launchController.getCurrentShip() != null) {
      launchSiteRenderer.draw(launchSite, camera, launchController.getCurrentShip());
    }

    for (Spacecraft s : solarSystem.ships) {
      spacecraftRenderer.draw(s, camera);
    }

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
  if (s.state == ShipState.LAUNCHING || s.state == ShipState.CIRCULARIZING) {
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
  hud.launchUI.handleClick(mouseX, mouseY);
  if (hud.handleClick(mouseX, mouseY, solarSystem.sun, solarSystem.planets, camera)) {
    return;
  }
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

