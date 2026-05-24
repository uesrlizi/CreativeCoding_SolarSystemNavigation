// Solar System Spaceflight Simulation - Refactored Version
// Stage 5: Maneuver Planning & Auto-Execution

import java.util.ArrayList;
import java.util.List;

// ========== DISPLAY OPTIONS ==========
boolean showOrbits = true;
boolean showLabels = true;
boolean showSOI = false;
boolean showTrajectory = true;
boolean showApoapsis = true;
boolean showPeriapsis = true;
boolean showControlsHelp = false;

// ========== LABEL MANAGEMENT ==========
LabelManager labelManager;

// ========== STARFIELD ==========
int[] starSeed;

// ========== FRAME TIMING ==========
float deltaTime = 1.0f / 60.0f;
int lastFrameMillis;

// ========== GLOBAL SYSTEMS ==========
CelestialSystem solarSystem;  // 原来的SolarSystem改名为CelestialSystem
CameraController camera;
TimeManager timeManager;
HUD hud;
PhysicsSystem physicsSystem;  // 新增：物理系统
DebugPanel debugPanel;         // 新增：调试面板
float uiScale;

// ========== MISSION SYSTEMS (Stage 5) ==========
MissionPlanner missionPlanner;
MissionValidator missionValidator;
MissionExecutor missionExecutor;

// ========== SPACECRAFT & RENDERER ==========
SpacecraftRenderer spacecraftRenderer;
TrajectoryPredictor trajectoryPredictor;

// ========== LAUNCH SYSTEM ==========
LaunchSite launchSite;
LaunchSiteRenderer launchSiteRenderer;
WaterSteamManager steamManager;

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
  textFont(createFont("arialbd.ttf", 48));
  labelManager = new LabelManager();

  // Initialize random seed for stars
  starSeed = new int[1500];
  for (int i = 0; i < starSeed.length; i++) {
    starSeed[i] = (int)random(10000);
  }

  // Initialize systems
  timeManager = new TimeManager();
  camera = new CameraController();
  camera.initialize((width * 0.15) / (1.0 * AU_KM));

  solarSystem = new CelestialSystem();  // 使用新的类名
  solarSystem.initialize();

  // Initialize physics system
  physicsSystem = new PhysicsSystem(solarSystem);

  // Initialize spacecraft renderer and trajectory predictor
  spacecraftRenderer = new SpacecraftRenderer();
  trajectoryPredictor = new TrajectoryPredictor();
  trajectoryPredictor.setPatchedConics(physicsSystem.patchedConics);

  // Initialize mission systems (Stage 5)
  missionPlanner = new MissionPlanner();
  missionValidator = new MissionValidator();
  missionExecutor = new MissionExecutor();

  // Initialize debug panel
  debugPanel = new DebugPanel();

  // Initialize spacecraft presets
  if (spacecraftPresets == null) initSpacecraftPresets();

  // Initialize launch site
  CelestialBody earth = solarSystem.getEarth();
  if (earth != null) {
    // 在地球表面0度位置创建发射场
    launchSite = new LaunchSite(earth, 0);
    launchSiteRenderer = new LaunchSiteRenderer();

    // 初始化水雾管理器
    steamManager = new WaterSteamManager();
    launchSiteRenderer.setSteamManager(steamManager);

    // 设置 missionExecutor 的发射场
    missionExecutor.setLaunchSite(launchSite, earth);
  }

  // Create initial spacecraft on launch pad
  createInitialSpacecraft();

  // Focus camera on spacecraft and set as follow target
  if (solarSystem.ships.size() > 0) {
    camera.focusOn(solarSystem.ships.get(0));
    camera.followShip(solarSystem.ships.get(0));
  }

  hud = new HUD();
}

void restartGame() {
  // 重置显示选项
  showOrbits = true;
  showLabels = true;
  showSOI = false;
  showTrajectory = true;
  showApoapsis = true;
  showPeriapsis = true;
  showControlsHelp = false;

  // 重新初始化系统
  timeManager = new TimeManager();
  camera = new CameraController();
  camera.initialize((width * 0.15) / (1.0 * AU_KM));

  solarSystem = new CelestialSystem();
  solarSystem.initialize();

  physicsSystem = new PhysicsSystem(solarSystem);

  spacecraftRenderer = new SpacecraftRenderer();
  trajectoryPredictor = new TrajectoryPredictor();
  trajectoryPredictor.setPatchedConics(physicsSystem.patchedConics);

  missionPlanner = new MissionPlanner();
  missionValidator = new MissionValidator();
  missionExecutor = new MissionExecutor();

  debugPanel = new DebugPanel();

  if (spacecraftPresets == null) initSpacecraftPresets();

  // 重新初始化发射场
  CelestialBody earth = solarSystem.getEarth();
  if (earth != null) {
    launchSite = new LaunchSite(earth, 0);
    launchSiteRenderer = new LaunchSiteRenderer();
    steamManager = new WaterSteamManager();
    launchSiteRenderer.setSteamManager(steamManager);
    missionExecutor.setLaunchSite(launchSite, earth);
  }

  // 创建初始航天器
  solarSystem.ships.clear();
  createInitialSpacecraft();

  // 聚焦摄像机
  if (solarSystem.ships.size() > 0) {
    camera.focusOn(solarSystem.ships.get(0));
    camera.followShip(solarSystem.ships.get(0));
  }

  hud = new HUD();
}

void createInitialSpacecraft() {
  CelestialBody earth = solarSystem.getEarth();
  if (earth != null) {
    // 使用预设创建航天器
    Spacecraft ship = createSpacecraftFromPreset(PRESET_LEO_SATELLITE);
    if (ship != null) {
      if (launchSite != null) {
        // 初始化到发射场
        ship.initOnLaunchPad(earth, launchSite);
      } else {
        // 如果没有发射场，回退到LEO轨道
        ship.initLEO(earth);
      }

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

  // Update systems - 先预判机动（只在高倍速时）
  double timeToNextManeuver = missionExecutor.getTimeToNextManeuver(timeManager.simTime);
  double timeToNextIgnition = missionExecutor.getTimeToNextIgnition(timeManager.simTime);
  boolean jumpedToManeuver = false;

  // 只在 warp >= 10分钟/秒（第3级及以上）时才进行跳转判定
  if (timeToNextIgnition > 0 && timeManager.warpIndex >= 3) {
    // 计算这一帧本来要推进的时间
    double frameAdvance = timeManager.timeWarp * DAY_S * deltaTime;

    if (timeToNextIgnition < frameAdvance) {
      // 会跳过点火，直接跳转到点火前5秒
      double targetSimTime = timeManager.simTime + timeToNextIgnition - 5.0;
      timeManager.simTime = targetSimTime;

      // 强制降到实时
      timeManager.forceSetWarpIndex(0);

      // 更新所有系统到新时间
      solarSystem.update(timeManager.simTime);
      for (Spacecraft ship : solarSystem.ships) {
        ship.lastUpdateTime = timeManager.simTime;
        if (ship.orbit != null && ship.physicsMode == PhysicsMode.ON_RAILS) {
          physicsSystem.updateOnRails(ship, timeManager.simTime);
        }
      }

      jumpedToManeuver = true;
    }
  }

  // 正常推进时间（如果没跳转）
  double frameStartSimTime = timeManager.simTime;
  if (!jumpedToManeuver) {
    timeManager.update(deltaTime);
  }
  double frameSimDt = timeManager.simTime - frameStartSimTime;

  solarSystem.updateRenderer(deltaTime);

  // ========== 判定是否需要物理tick模式 ==========
  boolean needsTickMode = false;

  // 1. 检查MissionExecutor状态
  if (missionExecutor.state == MissionExecutorState.ORIENTING ||
      missionExecutor.state == MissionExecutorState.BURNING) {
    needsTickMode = true;
  }

  // 2. 检查RecoveryController状态（如果是返回任务）
  if (!needsTickMode && missionExecutor.isRecoveryMission && missionExecutor.recoveryController != null) {
    RecoveryStage stage = missionExecutor.recoveryController.stage;
    if (stage == RecoveryStage.DEORBIT_BURN ||
        stage == RecoveryStage.REENTRY_GUIDANCE ||
        stage == RecoveryStage.TURNAROUND_MANEUVER ||
        stage == RecoveryStage.HOVER_SLIDE ||
        stage == RecoveryStage.FINAL_DESCENT ||
        stage == RecoveryStage.LANDING_BURN) {
      needsTickMode = true;
    }
  }

  // 3. 检查每个飞船
  if (!needsTickMode) {
    for (Spacecraft ship : solarSystem.ships) {
      if (physicsSystem.needsPhysicsTick(ship)) {
        needsTickMode = true;
        break;
      }
    }
  }

  // ========== 更新：分两种模式 ==========
  if (frameSimDt > 0 && !jumpedToManeuver) {
    if (needsTickMode) {
      // ========== Tick模式：需要精度 ==========
      physicsSystem.tickSystem.executeTicks(
        null, frameSimDt, frameStartSimTime,
        (unusedShip, tickDt, currentSimTime) -> {
          // 每个tick内的更新
          solarSystem.update(currentSimTime);
          missionExecutor.updateTick(tickDt, currentSimTime);

          for (Spacecraft ship : solarSystem.ships) {
            if (currentSimTime > ship.lastUpdateTime) {
              ship.lastUpdateTime = currentSimTime;

              if (ship.autoControl != null && ship.autoControl.isActive) {
                ship.autoControl.updateTick(ship, tickDt);
              }

              physicsSystem.updateShipInTick(ship, tickDt, currentSimTime);
            }
          }
        }
      );
    } else {
      // ========== 直接跳转模式：不需要精度 ==========
      solarSystem.update(timeManager.simTime);
      missionExecutor.update(timeManager.simTime, deltaTime);

      for (Spacecraft ship : solarSystem.ships) {
        double shipSimDt = timeManager.simTime - ship.lastUpdateTime;
        if (shipSimDt > 0) {
          ship.lastUpdateTime = timeManager.simTime;

          if (ship.physicsMode == PhysicsMode.ON_RAILS && ship.orbit != null) {
            physicsSystem.updateOnRails(ship, timeManager.simTime);
          } else {
            physicsSystem.updateShipInTick(ship, shipSimDt, timeManager.simTime);
          }

          if (ship.autoControl != null && ship.autoControl.isActive) {
            ship.autoControl.updateTick(ship, 0);
          }
        }
      }
    }
  } else {
    // 跳转到机动的情况：直接更新到目标时间
    solarSystem.update(timeManager.simTime);
    for (Spacecraft ship : solarSystem.ships) {
      double shipSimDt = timeManager.simTime - ship.lastUpdateTime;
      if (shipSimDt > 0) {
        ship.lastUpdateTime = timeManager.simTime;
        if (ship.physicsMode == PhysicsMode.ON_RAILS && ship.orbit != null) {
          physicsSystem.updateOnRails(ship, timeManager.simTime);
        } else {
          physicsSystem.updateShipInTick(ship, shipSimDt, timeManager.simTime);
        }
        if (ship.autoControl != null && ship.autoControl.isActive) {
          ship.autoControl.updateTick(ship, 0);
        }
      }
    }
    missionExecutor.update(timeManager.simTime, deltaTime);
  }

  // ========== 更新智能warp限制 ==========
  int globalMaxWarp = timeManager.WARP_LEVELS.length - 1;

  if (needsTickMode) {
    // 需要tick模式时，强制warp 2（1分钟/秒）
    globalMaxWarp = 2;
  } else if (missionExecutor.state != MissionExecutorState.IDLE &&
             missionExecutor.state != MissionExecutorState.COMPLETED &&
             missionExecutor.state != MissionExecutorState.FAILED) {
    // 任务执行中但不需要tick（WAITING_FOR_MANEUVER），用执行器建议
    int executorMaxWarp = missionExecutor.getRecommendedWarpLevel(timeManager);
    if (executorMaxWarp >= 0) {
      globalMaxWarp = executorMaxWarp;
    }
  } else {
    // 普通巡航，用每个飞船的限制（应该都是无限制）
    for (Spacecraft ship : solarSystem.ships) {
      int maxWarp = physicsSystem.getMaxTimeWarp(ship, timeManager);
      if (maxWarp < globalMaxWarp) {
        globalMaxWarp = maxWarp;
      }
    }
  }

  timeManager.setMaxWarpIndex(globalMaxWarp);

  camera.update(deltaTime);
  hud.update();

  // Render order: background -> orbits -> SOI -> sun -> planets -> spacecraft -> UI
  drawStars();

  // Only draw orbits in MAP view
  if (camera.getMode() == ViewMode.MAP_VIEW) {
    drawOrbits();
    if (showSOI) {
      drawSOIBoundaries();
    }
  }


  // Draw celestial bodies (without labels)
  solarSystem.drawSun(camera, false);
  solarSystem.drawPlanets(camera, false);

  // Collect all labels
  labelManager.reset();
  if (showLabels) {
    solarSystem.collectLabels(camera, labelManager);
    // No spacecraft text labels anymore, only the ship icon is shown
  }
  // Collect AP/PE markers if in map view and trajectory is shown
  if (camera.getMode() == ViewMode.MAP_VIEW && showTrajectory && (showApoapsis || showPeriapsis)) {
    float scale = uiScale;
    float markerSize = 6 * scale;
    for (Spacecraft ship : solarSystem.ships) {
      Trajectory trajectory = trajectoryPredictor.predict(ship, timeManager.simTime);
      if (trajectory != null) {
        for (TrajectoryEvent event : trajectory.events) {
          if ((event.type.equals("apoapsis") && showApoapsis) ||
              (event.type.equals("periapsis") && showPeriapsis)) {
            Vector2 bodyPos = getEventBodyPosition(event.referenceBody);
            double worldX = bodyPos.x + event.position.x;
            double worldY = bodyPos.y + event.position.y;
            double[] sp = camera.worldToScreen(worldX, worldY);
            color markerColor = event.type.equals("apoapsis") ?
                color(255, 150, 100) : color(100, 200, 255);
            String label = event.type.equals("apoapsis") ? "AP" : "PE";
            // Priority 10 - low priority, will be hidden first if overlapping
            labelManager.addMarker(label, (float)sp[0], (float)sp[1], markerSize, markerColor, 10);
          }
        }
      }
    }
  }

  // Collect launch site marker if in map view
  if (camera.getMode() == ViewMode.MAP_VIEW && launchSite != null) {
    float scale = uiScale;
    float markerSize = 8 * scale;
    double[] sp = camera.worldToScreen(launchSite.px, launchSite.py);
    color markerColor = color(200, 200, 80);
    String label = "Launch Site";
    // Priority 8 - very low priority, hidden first if overlapping
    labelManager.addMarker(label, (float)sp[0], (float)sp[1], markerSize, markerColor, 8);
  }
  // Sort and resolve collisions
  labelManager.processLabels();
  // Draw labels and markers
  labelManager.drawLabels();

  // Update launch site position to track Earth
  if (launchSite != null) {
    launchSite.update();
  }

  // Update water steam effect
  if (steamManager != null && solarSystem.ships.size() > 0) {
    Spacecraft ship = solarSystem.ships.get(0);

    // 获取发射状态和时间
    LaunchState state = ship.launchState;
    double stateTime = 0;
    switch (state) {
      case COUNTDOWN:
        stateTime = ship.countdownStartTime > 0 ? (timeManager.simTime - ship.countdownStartTime) : 0;
        break;
      case IGNITION:
        stateTime = ship.ignitionStartTime > 0 ? (timeManager.simTime - ship.ignitionStartTime) : 0;
        break;
      case LAUNCHING:
        stateTime = ship.launchStartTime > 0 ? (timeManager.simTime - ship.launchStartTime) : 0;
        break;
    }
    steamManager.update(deltaTime, state, stateTime);
  }

  // Render launch site background
  if (launchSite != null && launchSiteRenderer != null && solarSystem.ships.size() > 0) {
    float deployProgress = missionExecutor.getUmbilicalDeployProgress();
    launchSiteRenderer.drawBackground(launchSite, camera, solarSystem.ships.get(0), deployProgress);
  }

  // Render spacecraft
  for (Spacecraft ship : solarSystem.ships) {
    spacecraftRenderer.draw(ship, camera);
  }

  // Render launch site foreground (supports & baffles to block exhaust)
  if (launchSite != null && launchSiteRenderer != null && solarSystem.ships.size() > 0) {
    float deployProgress = missionExecutor.getUmbilicalDeployProgress();
    launchSiteRenderer.drawForeground(launchSite, camera, solarSystem.ships.get(0), deployProgress);
  }

  // Render trajectories in MAP view
  if (camera.getMode() == ViewMode.MAP_VIEW) {
    for (Spacecraft ship : solarSystem.ships) {
      Trajectory trajectory = trajectoryPredictor.predict(ship, timeManager.simTime);
      spacecraftRenderer.drawTrajectory(ship, trajectory, camera, timeManager.simTime);
    }
  }

  hud.draw(camera, timeManager.simTime, timeManager.timeWarp, timeManager.WARP_LEVELS, timeManager.WARP_LABELS, timeManager.warpIndex, solarSystem.planets, solarSystem.moons, solarSystem.sun, solarSystem.ships);

  // Draw debug panel
  debugPanel.draw(physicsSystem, camera, uiScale);
}

float getSmartLabelDir(float x, float y) {
  float margin = 100 * uiScale;
  if (x < margin) return 0;  // Left side - label to right
  if (x > width - margin) return 2;  // Right side - label to left
  if (y < margin) return 3;  // Top - label below
  if (y > height - margin) return 1;  // Bottom - label above
  return 0;  // Default right
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
    double E = 2.0 * PI * j / steps;  // 偏近点角均匀步进
    double nu = trueAnomaly(E, e);    // 转换为真近点角
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
    double E = 2.0 * PI * j / steps;  // 偏近点角均匀步进
    double nu = trueAnomaly(E, orbit.e);  // 转换为真近点角
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
  double soiRadius = solarSystem.renderer.calculateSOIRadius(body);
  double screenRadius = soiRadius * camera.scale;
  if (screenRadius < 2) return;

  int soiColor = solarSystem.renderer.getSOIColor(body);

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
  if (showControlsHelp) {
    showControlsHelp = false;
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
  for (CelestialBody planet : solarSystem.planets) {
    double[] sp = camera.worldToScreen(planet.px, planet.py);
    double d = dist((float)sp[0], (float)sp[1], mouseX, mouseY);
    if (d < minDist) { minDist = d; closestBody = planet; closestShip = null; }
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
  if (showControlsHelp) return;
  camera.handleMouseDragged();
}

void mouseReleased() {
  if (showControlsHelp) return;
  camera.handleMouseReleased();
}

void mouseWheel(MouseEvent event) {
  if (showControlsHelp) return;
  camera.handleMouseWheel(event);
}

void keyPressed() {
  if (showControlsHelp) {
    if (keyCode == ESC) {
      key = 0;
      showControlsHelp = false;
    }
    return;
  }
  if (keyCode == ESC) {
    timeManager.togglePause();
    key = 0;  // 把 key 置 0 来阻止默认行为
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
    hud.trajIcon.toggled = showTrajectory;
    // 只更新显示状态，不改变用户的开关选择
    if (!showTrajectory) {
      showApoapsis = false;
      showPeriapsis = false;
    } else {
      // 恢复用户之前的选择
      showApoapsis = hud.apsisIcon.toggled;
      showPeriapsis = hud.apsisIcon.toggled;
    }
  }
  if (key == 'd' || key == 'D') {
    debugPanel.toggle();
  }

  // === 测试控制：引擎油门 ===
  if (key == '1') {
    setThrottle(0.0f); // 关闭引擎
  }
  if (key == '2') {
    setThrottle(0.2f); // 20%
  }
  if (key == '3') {
    setThrottle(0.5f); // 50%
  }
  if (key == '4') {
    setThrottle(1.0f); // 100%
  }

  // === 测试控制：朝向 ===
  if (key == 'w' || key == 'W') {
    pointInDirection(OrbitDirection.PROGRADE); // 沿速度方向
  }
  if (key == 's' || key == 'S') {
    pointInDirection(OrbitDirection.RETROGRADE); // 反速度方向
  }
  if (key == 'a' || key == 'A') {
    pointInDirection(OrbitDirection.RADIAL_OUT); // 径向向外
  }
  if (key == 'z' || key == 'Z') {
    pointInDirection(OrbitDirection.RADIAL_IN); // 径向向内
  }
}

Vector2 getEventBodyPosition(CelestialBody body) {
  if (body == null) return new Vector2(0, 0);
  return new Vector2(body.px, body.py);
}

// === 辅助函数：设置油门 ===
void setThrottle(float throttle) {
  if (solarSystem.ships.size() > 0) {
    Spacecraft ship = solarSystem.ships.get(0);
    ship.setEngineThrottle(throttle);
  }
}

// === 辅助函数：朝向控制 ===
enum OrbitDirection { PROGRADE, RETROGRADE, RADIAL_OUT, RADIAL_IN }

void pointInDirection(OrbitDirection dir) {
  if (solarSystem.ships.size() > 0) {
    Spacecraft ship = solarSystem.ships.get(0);
    Vector2 targetDir = new Vector2(0, 0);

    switch (dir) {
      case PROGRADE:
        targetDir = ship.getPrograde();
        break;
      case RETROGRADE:
        targetDir = ship.getRetrograde();
        break;
      case RADIAL_OUT:
        targetDir = ship.getRadialOut();
        break;
      case RADIAL_IN:
        targetDir = ship.getRadialIn();
        break;
    }

    ship.setAutoTargetDirection(targetDir);
  }
}
