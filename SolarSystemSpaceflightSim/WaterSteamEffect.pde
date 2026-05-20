// ========== WATER STEAM EFFECT ==========
// 专门用于火箭发射的冷却水雾特效 - 使用发射场局部坐标系

// 水雾粒子状态
enum SteamPhase {
  INITIAL_SPRAY,    // 初始喷射阶段（向下）
  GROUND_SPREAD,    // 地面扩散阶段（水平向外）
  RISE_AND_FADE     // 上升消散阶段
}

// 单个水雾粒子（局部坐标系：Y向上，地面在Y=0）
class SteamParticle {
  Vector2 position;      // 局部坐标（米）
  Vector2 velocity;      // 速度（米/秒）
  float size;            // 当前大小（米）
  float initialSize;     // 初始大小
  float life;            // 剩余生命 [0,1]
  float maxLife;         // 最大生命时长（秒）
  float age;             // 已存活时间（秒）
  int col;               // 颜色
  float alpha;           // 透明度
  boolean isAlive;
  SteamPhase phase;

  SteamParticle(Vector2 pos, Vector2 vel, float maxLifeTime, float particleSize, int colorVal) {
    this.position = pos.clone();
    this.velocity = vel.clone();
    this.size = particleSize;
    this.initialSize = particleSize;
    this.maxLife = maxLifeTime;
    this.life = 1.0f;
    this.age = 0;
    this.col = colorVal;
    this.alpha = 1.0f;
    this.isAlive = true;
    this.phase = SteamPhase.INITIAL_SPRAY; // 从初始喷射开始
  }

  void updatePhase() {
    float ageNorm = age / maxLife;

    // 初始阶段：水平高速喷出
    if (phase == SteamPhase.INITIAL_SPRAY && ageNorm > 0.2f) {
      phase = SteamPhase.GROUND_SPREAD;
    }

    // 然后开始上升消散
    if (phase == SteamPhase.GROUND_SPREAD && ageNorm > 0.5f) {
      phase = SteamPhase.RISE_AND_FADE;
    }
  }

  void update(double dt) {
    if (!isAlive) return;

    updatePhase();

    // 应用不同阶段的运动
    switch (phase) {
      case INITIAL_SPRAY:
        // 初始喷射：几乎不减速，保持高速
        velocity = velocity.mul(0.995);
        // 添加紊动
        float turbX0 = (float)((Math.random() - 0.5) * 2.0);
        float turbY0 = (float)((Math.random() - 0.5) * 1.5);
        velocity = velocity.add(new Vector2(turbX0 * dt, turbY0 * dt));
        break;

      case GROUND_SPREAD:
        // 地面/空气扩散：轻微减速
        velocity = velocity.mul(0.985);
        // 添加紊动
        float turbX = (float)((Math.random() - 0.5) * 4.0);
        float turbY = (float)((Math.random() - 0.5) * 2.5);
        velocity = velocity.add(new Vector2(turbX * dt, turbY * dt));
        break;

      case RISE_AND_FADE:
        // 上升消散：轻微减速，主要是上升
        Vector2 riseVel = new Vector2(0, 2.0 + life * 4.0);
        velocity = velocity.mul(0.99).add(riseVel.mul(dt));
        // 横向紊动和扩散
        float turbX2 = (float)((Math.random() - 0.5) * 5.0);
        velocity = velocity.add(new Vector2(turbX2 * dt, 0));
        break;
    }

    // 更新位置
    position = position.add(velocity.mul(dt));

    // 更新年龄
    age += dt;
    life = 1.0f - (age / maxLife);

    if (life <= 0) {
      isAlive = false;
    }

    // 更新大小 - 随年龄增大
    float ageNorm = age / maxLife;
    float sizeMult = 1.0f + ageNorm * 2.0f; // 最大变为 3 倍
    size = initialSize * sizeMult;

    // 更新透明度 - 更明显
    if (ageNorm < 0.2f) {
      alpha = 0.8f + ageNorm * 1.0f; // 快速淡入
    } else if (ageNorm > 0.8f) {
      alpha = 1.0f - (ageNorm - 0.8f) * 5.0f; // 后期淡出
    } else {
      alpha = 1.0f;
    }
  }
}

// 水雾特效发射器（局部坐标系）
class WaterSteamEmitter {
  ArrayList<SteamParticle> particles;
  float emissionRate;      // 每秒发射粒子数
  double emissionAccum;    // 累积时间
  float intensity;         // 强度 [0,1]

  WaterSteamEmitter() {
    this.particles = new ArrayList<SteamParticle>();
    this.emissionRate = 100;
    this.emissionAccum = 0;
    this.intensity = 0;
  }

  void setIntensity(float inten) {
    this.intensity = constrain(inten, 0.0f, 1.0f);
    this.emissionRate = 50 + intensity * 180; // 恢复旧的粒子数量
  }

  void emitParticles(double dt) {
    if (intensity <= 0.001f) return;

    emissionAccum += dt;

    float particlesToEmit = emissionRate * (float)emissionAccum;
    int numToEmit = (int)Math.floor(particlesToEmit);

    if (numToEmit > 0) {
      emissionAccum -= numToEmit / (double)emissionRate;

      for (int i = 0; i < numToEmit; i++) {
        emitSingleParticle();
      }
    }
  }

  void emitSingleParticle() {
    // 从左右导流槽发射（局部坐标）
    // 左导流槽：X从-22米到-3米，右导流槽：X从3米到22米
    boolean leftSide = Math.random() > 0.5;
    double slotStartX = leftSide ? -22.0 : 3.0;
    double slotEndX = leftSide ? -3.0 : 22.0;
    double posX = slotStartX + Math.random() * (slotEndX - slotStartX);

    // Y位置在导流槽高度附近（地面是Y=0，发射台在Y=-5米左右，按比例）
    double startY = -2.0 + (Math.random() - 0.5) * 2.0;

    Vector2 pos = new Vector2(posX, startY);

    // 初始速度 - 从水平到斜向上的扇形喷出（左导流槽向左，右导流槽向右）
    double baseSpeed = 10.0 + intensity * 40.0; // 10-50 m/s，随强度变化
    double direction = leftSide ? -1.0 : 1.0;
    // 角度范围：从水平(0度)到斜向上(25度)的扇形
    double angle = Math.random() * radians(25);
    Vector2 vel = new Vector2(
      Math.cos(angle) * baseSpeed * direction,
      Math.sin(angle) * baseSpeed
    );

    // 随机生命周期
    float lifeTime = 2.0f + (float)Math.random() * 2.5f * intensity;

    // 随机大小 (0.5 - 1.5 米，不那么大)
    float size = 0.5f + (float)Math.random() * 1.0f;

    // 颜色 - 白色到灰色
    int grayVal = 200 + (int)(Math.random() * 55);
    int col = color(grayVal, grayVal, grayVal + 10);
    // 初始不透明度 0.8~1
    float initialAlpha = 0.8f + (float)Math.random() * 0.2f;

    SteamParticle p = new SteamParticle(pos, vel, lifeTime, size, col);
    p.alpha = initialAlpha;
    particles.add(p);
  }

  void update(double dt) {
    emitParticles(dt);

    for (int i = particles.size() - 1; i >= 0; i--) {
      SteamParticle p = particles.get(i);
      p.update(dt);
      if (!p.isAlive) {
        particles.remove(i);
      }
    }
  }

  void draw(float scale) {
    noStroke();
    ellipseMode(CENTER);

    // 从后往前绘制（按 Y 排序）
    ArrayList<SteamParticle> sorted = new ArrayList<SteamParticle>(particles);
    sorted.sort((a, b) -> Float.compare((float)b.position.y, (float)a.position.y));

    for (SteamParticle p : sorted) {
      if (!p.isAlive) continue;

      // 计算屏幕大小（局部坐标单位：米，scale: 像素/飞船长度，飞船长度约50米）
      float screenSize = p.size * scale / 50.0f;
      if (screenSize < 1.0f) screenSize = 1.0f;

      float px = (float)p.position.x * scale / 50.0f;
      float py = (float)-p.position.y * scale / 50.0f; // Y轴向上转成Processing向下

      // 计算颜色
      int r = (int)(red(p.col) * p.alpha);
      int g = (int)(green(p.col) * p.alpha);
      int b = (int)(blue(p.col) * p.alpha);
      int a = (int)(255 * p.alpha * intensity);

      // 绘制单个圆形雾效
      fill(r, g, b, a);
      ellipse(px, py, screenSize, screenSize);
    }
  }

  void clear() {
    particles.clear();
  }
}

// 水雾特效管理器
class WaterSteamManager {
  WaterSteamEmitter emitter;
  float currentIntensity;

  WaterSteamManager() {
    this.emitter = new WaterSteamEmitter();
    this.currentIntensity = 0.0f;
  }

  void update(double dt, LaunchState launchState, double stateTime) {
    float targetIntensity = 0.0f;

    switch (launchState) {
      case COUNTDOWN:
        double countdownLeft = Spacecraft.COUNTDOWN_DURATION - stateTime;
        if (countdownLeft < 2.0) {
          targetIntensity = 0.15f + (float)(2.0 - countdownLeft) * 0.15f;
        }
        break;

      case IGNITION:
        targetIntensity = 1.0f;  // 点火瞬间拉满
        break;

      case LAUNCHING:
        if (stateTime < 5.0) {
          targetIntensity = 1.0f;
        } else if (stateTime < 8.0) {
          targetIntensity = 1.0f - (float)((stateTime - 5.0) / 3.0) * 1.0f;
        }
        break;

      default:
        targetIntensity = 0.0f;
        break;
    }

    currentIntensity = lerp(currentIntensity, targetIntensity, (float)(dt * 5.0));
    emitter.setIntensity(currentIntensity);
    emitter.update(dt);
  }

  void draw(float scale) {
    emitter.draw(scale);
  }

  void clear() {
    emitter.clear();
    currentIntensity = 0.0f;
  }
}
