// Solar System Spaceflight Simulation - Refactored Version
// Stage 2: Single Spacecraft in LEO

import java.util.ArrayList;
import java.util.List;

// ========== DISPLAY OPTIONS ==========
boolean showOrbits = true;
boolean showLabels = true;
boolean showSOI = false;
boolean showTrajectory = true;
boolean showApoapsis = true;
boolean showPeriapsis = true;

// ========== STARFIELD ==========
int[] starSeed;

// ========== FRAME TIMING ==========
float deltaTime = 1.0f / 60.0f;
int lastFrameMillis;

// ========== GLOBAL SYSTEMS ==========
SolarSystem solarSystem;
CameraController camera;
TimeManager timeManager;
HUD hud;
SOISystem soiSystem;
ViewToggleButton viewToggleButton;
float uiScale;

// ========== SPACECRAFT & RENDERER ==========
SpacecraftRenderer spacecraftRenderer;
TrajectoryPredictor trajectoryPredictor;

// ========== DOUBLE-CLICK / FOCUS ==========
long lastClickTime = 0;
int lastClickX, lastClickY;
static final int DOUBLE_CLICK_MS = 300;
static final int DOUBLE_CLICK_PX = 15;
static final double FOCUS_HIT_RADIUS = 60;

void settings() {
  fullScreen();
}

void setup() {
  uiScale = height / 1080.0f;
  lastFrameMillis = millis();
  textFont(createFont("Segoe UI Semibold", 48));

  // Initialize random seed for stars
  starSeed = new int[1500];
  for (int i = 0; i < starSeed.length; i++) {
    starSeed[i] = (int)random(10000);
  }

  // Initialize systems
  timeManager = new TimeManager();
  camera = new CameraController();
  camera.initialize((width * 0.15) / (1.0 * AU_KM));

  solarSystem = new SolarSystem();
  soiSystem = new SOISystem(solarSystem);
  solarSystem.initialize();

  // Initialize spacecraft renderer and trajectory predictor
  spacecraftRenderer = new SpacecraftRenderer();
  trajectoryPredictor = new TrajectoryPredictor();

  // Initialize spacecraft presets
  if (spacecraftPresets == null) initSpacecraftPresets();

  // Create initial spacecraft in LEO
  createInitialSpacecraft();

  // Focus camera on spacecraft and set as follow target
  if (solarSystem.ships.size() > 0) {
    camera.focusOn(solarSystem.ships.get(0));
    camera.followShip(solarSystem.ships.get(0));
  }

  hud = new HUD();
  viewToggleButton = new ViewToggleButton();
}

void createInitialSpacecraft() {
  CelestialBody earth = solarSystem.getEarth();
  if (earth != null) {
    // 使用预设创建航天器
    Spacecraft ship = createSpacecraftFromPreset(PRESET_LEO_SATELLITE);
    if (ship != null) {
      // Initialize LEO orbit
      ship.initLEO(earth);

      // Add to solar system
      solarSystem.ships.add(ship);
    }
  }
}

void draw() {
  background(5, 5, 15);

  // Calculate delta time
  int now = millis();
  deltaTime = (now - lastFrameMillis) / 1000.0f;
  if (deltaTime <= 0 || deltaTime > 0.5f) deltaTime = 1.0f / 60.0f;
  lastFrameMillis = now;

  // Update systems
  timeManager.update(deltaTime);
  solarSystem.update(timeManager.simTime);
  solarSystem.updateRenderer(deltaTime);

  // Update spacecraft positions
  for (Spacecraft ship : solarSystem.ships) {
    double simDt = timeManager.simTime - ship.lastUpdateTime;
    if (simDt <= 0) simDt = 1.0f / 60.0f;
    if (simDt > 3600) simDt = 3600;
    ship.lastUpdateTime = timeManager.simTime;

    // Update
    if (ship.physicsMode == PhysicsMode.ON_RAILS) {
      ship.updateOnRails(timeManager.simTime);
    } else {
      ship.updateOffRails(simDt);
    }
  }

  camera.update(deltaTime);
  hud.update();
  viewToggleButton.update();

  // Render order: background -> orbits -> SOI -> sun -> planets -> spacecraft -> HUD
  drawStars();

  // Only draw orbits in MAP view
  if (camera.getMode() == ViewMode.MAP_VIEW) {
    drawOrbits();
    if (showSOI) {
      drawSOIBoundaries();
    }
  }

  solarSystem.drawSun(camera);
  solarSystem.drawPlanets(camera);

  // Render spacecraft
  for (Spacecraft ship : solarSystem.ships) {
    spacecraftRenderer.draw(ship, camera);
  }

  // Render trajectories in MAP view
  if (camera.getMode() == ViewMode.MAP_VIEW) {
    for (Spacecraft ship : solarSystem.ships) {
      Trajectory trajectory = trajectoryPredictor.predict(ship, timeManager.simTime);
      spacecraftRenderer.drawTrajectory(ship, trajectory, camera);
    }
  }

  hud.draw(camera, timeManager.simTime, timeManager.timeWarp, timeManager.WARP_LEVELS, timeManager.WARP_LABELS, timeManager.warpIndex, solarSystem.planets, solarSystem.sun, solarSystem.ships);
  viewToggleButton.draw();
}

void drawStars() {
  noStroke();
  drawMilkyWay();

  for (int i = 0; i < starSeed.length; i++) {
    int sx = (starSeed[i] * 7 + 13) % width;
    int sy = (starSeed[i] * 11 + 29) % height;
    int baseBright = 80 + (starSeed[i] * 3) % 120;
    float twinkle = 0.7f + 0.3f * sin(millis() * 0.003f + starSeed[i]);
    int brightness = (int)(baseBright * twinkle);
    int sz = (starSeed[i] % 3 == 0) ? 2 : 1;

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

  for (int layer = 0; layer < 5; layer++) {
    float alpha = 8 - layer * 1.5f;
    for (int i = 0; i < 200; i++) {
      float angle = random(TWO_PI);
      float dist = random(1);
      dist = pow(dist, 0.5f);
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

void drawOrbits() {
  if (!showOrbits) return;
  if (camera.getMode() != ViewMode.MAP_VIEW) return;

  for (CelestialBody p : solarSystem.planets) {
    if (p.a == 0) continue;
    drawOrbitPath(p.a, p.e, p.i, p.omega, p.w, color(60, 60, 80, 100));
  }
  for (CelestialBody moon : solarSystem.moons) {
    if (moon.a == 0 || moon.parentBody == null) continue;
    drawOrbitPath(moon.parentBody.px, moon.parentBody.py, moon.a, moon.e, moon.i, moon.omega, moon.w, color(60, 60, 80, 80));
  }
  // Draw spacecraft orbits
  for (Spacecraft ship : solarSystem.ships) {
    if (ship.referenceBody != null && ship.orbit != null) {
      drawEarthRelOrbit(ship);
    }
  }
}

void drawOrbitPath(double a, double e, double i, double omega, double w, color c) {
  drawOrbitPath(0, 0, a, e, i, omega, w, c);
}

void drawOrbitPath(double centerX, double centerY, double a, double e, double i, double omega, double w, color c) {
  noFill();
  stroke(c);
  strokeWeight(0.8f);
  beginShape();
  int steps = 200;
  for (int j = 0; j <= steps; j++) {
    double nu = 2.0 * PI * j / steps;
    double[] pos = orbitalToCartesian(a, e, i, omega, w, nu);
    double[] sp = camera.worldToScreen(centerX + pos[0], centerY + pos[1]);
    vertex((float)sp[0], (float)sp[1]);
  }
  endShape(CLOSE);
}

void drawEarthRelOrbit(Spacecraft ship) {
  CelestialBody earth = ship.referenceBody;
  Orbit orbit = ship.orbit;
  if (orbit == null) return;

  double centerX = earth.px;
  double centerY = earth.py;

  noFill();
  stroke(red(ship.col), green(ship.col), blue(ship.col));
  strokeWeight(0.8f);
  beginShape();
  int steps = 200;
  for (int j = 0; j <= steps; j++) {
    double nu = 2.0 * PI * j / steps;
    double[] pos = orbitalToCartesian2D(orbit.a, orbit.e, orbit.w, nu);
    double worldX = centerX + pos[0];
    double worldY = centerY + pos[1];
    double[] sp = camera.worldToScreen(worldX, worldY);
    vertex((float)sp[0], (float)sp[1]);
  }
  endShape(CLOSE);
}

void drawSOIBoundaries() {
  if (camera.getMode() != ViewMode.MAP_VIEW) return;

  for (CelestialBody planet : solarSystem.planets) {
    drawSingleSOI(planet);
  }
  for (CelestialBody moon : solarSystem.moons) {
    drawSingleSOI(moon);
  }
}

void drawSingleSOI(CelestialBody body) {
  double soiRadius = soiSystem.calculateSOIRadius(body);
  double screenRadius = soiRadius * camera.scale;
  if (screenRadius < 2) return;

  int soiColor = soiSystem.getSOIColor(body);

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

  if (screenRadius > 30 && showLabels) {
    double[] labelPos = camera.worldToScreen(body.px + soiRadius * 1.05, body.py);
    fill(soiColor);
    textSize(12 * uiScale);
    textAlign(LEFT, CENTER);
    text(body.name + " SOI", (float)labelPos[0], (float)labelPos[1]);
  }
}

void mousePressed() {
  if (viewToggleButton.handleClick(camera, solarSystem.ships)) {
    return;
  }

  if (hud.handleMousePressed(mouseX, mouseY, camera, solarSystem.sun, solarSystem.planets, solarSystem.ships)) {
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
  if (camera.getMode() != ViewMode.MAP_VIEW) return;

  CelestialBody closestBody = null;
  Spacecraft closestShip = null;
  double minDist = FOCUS_HIT_RADIUS;

  // Check for spacecraft first
  for (Spacecraft ship : solarSystem.ships) {
    double[] sp = camera.worldToScreen(ship.worldX, ship.worldY);
    double d = dist((float)sp[0], (float)sp[1], mouseX, mouseY);
    if (d < minDist) { minDist = d; closestBody = null; closestShip = ship; }
  }

  // Check for bodies
  for (CelestialBody p : solarSystem.planets) {
    double[] sp = camera.worldToScreen(p.px, p.py);
    double d = dist((float)sp[0], (float)sp[1], mouseX, mouseY);
    if (d < minDist) { minDist = d; closestBody = p; closestShip = null; }
  }

  double[] sunSp = camera.worldToScreen(0, 0);
  double sunD = dist((float)sunSp[0], (float)sunSp[1], mouseX, mouseY);
  if (sunD < minDist) { minDist = sunD; closestBody = solarSystem.sun; closestShip = null; }

  for (CelestialBody moon : solarSystem.moons) {
    double[] sp = camera.worldToScreen(moon.px, moon.py);
    double d = dist((float)sp[0], (float)sp[1], mouseX, mouseY);
    if (d < minDist) { minDist = d; closestBody = moon; closestShip = null; }
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
  if (key == 'o' || key == 'O') {
    showOrbits = !showOrbits;
  }
  if (key == 'k' || key == 'K') {
    showSOI = !showSOI;
  }
  if (key == 'l' || key == 'L') {
    showLabels = !showLabels;
  }
  if (key == 'f' || key == 'F') {
    camera.snapFocus();
  }
  if (key == 'v' || key == 'V') {
    if (camera.getMode() == ViewMode.MAP_VIEW) {
      if (camera.followTarget == null && solarSystem.ships.size() > 0) {
        camera.followShip(solarSystem.ships.get(0));
      }
      camera.setViewMode(ViewMode.SHIP_VIEW);
    } else {
      camera.setViewMode(ViewMode.MAP_VIEW);
    }
  }
  if (key == 't' || key == 'T') {
    showTrajectory = !showTrajectory;
    if (hud.trajButton != null) hud.trajButton.setToggled(showTrajectory);
  }
  if (key == 'm' || key == 'M') {
    hud.taskMenu.toggle();
  }
}
