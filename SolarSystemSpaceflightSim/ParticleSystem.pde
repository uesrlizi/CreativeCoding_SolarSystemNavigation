// ========== PARTICLE SYSTEM ==========
// 通用粒子系统框架 - 用于各种特效

import java.util.ArrayList;
import java.util.List;

// 单个粒子
class Particle {
  Vector2 position;      // 位置（世界坐标 km）
  Vector2 velocity;      // 速度（km/s）
  Vector2 acceleration;  // 加速度（km/s²）

  float size;           // 当前大小
  float initialSize;    // 初始大小
  float life;           // 剩余生命 [0,1]
  float maxLife;        // 最大生命时长（秒）
  float age;            // 已存活时间（秒）

  int col;              // 颜色
  float alpha;          // 透明度

  boolean isAlive;

  Particle(Vector2 pos, Vector2 vel, float maxLifeTime, float particleSize, int colorVal) {
    this.position = pos.clone();
    this.velocity = vel.clone();
    this.acceleration = new Vector2(0, 0);
    this.size = particleSize;
    this.initialSize = particleSize;
    this.maxLife = maxLifeTime;
    this.life = 1.0f;
    this.age = 0;
    this.col = colorVal;
    this.alpha = 1.0f;
    this.isAlive = true;
  }

  void applyForce(Vector2 force) {
    acceleration = acceleration.add(force);
  }

  void update(double dt) {
    if (!isAlive) return;

    // 更新速度
    velocity = velocity.add(acceleration.mul(dt));

    // 更新位置
    position = position.add(velocity.mul(dt));

    // 重置加速度
    acceleration = new Vector2(0, 0);

    // 更新年龄
    age += dt;
    life = 1.0f - (age / maxLife);

    if (life <= 0) {
      isAlive = false;
    }
  }

  float getNormalizedAge() {
    return age / maxLife;
  }
}

// 粒子发射器基类
abstract class ParticleEmitter {
  List<Particle> particles;
  Vector2 position;
  boolean isActive;
  float emissionRate;  // 每秒发射粒子数
  double emissionAccum; // 累积时间，用于发射

  ParticleEmitter(Vector2 pos, float rate) {
    this.position = pos.clone();
    this.particles = new ArrayList<Particle>();
    this.isActive = true;
    this.emissionRate = rate;
    this.emissionAccum = 0;
  }

  void setPosition(Vector2 pos) {
    this.position = pos.clone();
  }

  void setActive(boolean active) {
    this.isActive = active;
  }

  abstract void emitParticles(double dt);

  void update(double dt, Vector2 gravity) {
    // 发射新粒子
    if (isActive) {
      emitParticles(dt);
    }

    // 更新现有粒子
    for (int i = particles.size() - 1; i >= 0; i--) {
      Particle p = particles.get(i);

      // 应用重力
      if (gravity != null) {
        p.applyForce(gravity);
      }

      // 更新粒子
      p.update(dt);

      // 移除死亡粒子
      if (!p.isAlive) {
        particles.remove(i);
      }
    }
  }

  void draw(CameraController cam) {
    // 由子类实现具体的渲染
  }

  void clear() {
    particles.clear();
  }
}

// 简单的 Perlin 噪声生成器（用于自然运动）
class PerlinNoise {
  int[] perm;

  PerlinNoise(long seed) {
    perm = new int[512];
    int[] p = new int[256];
    for (int i = 0; i < 256; i++) p[i] = i;

    // 用种子洗牌
    java.util.Random rand = new java.util.Random(seed);
    for (int i = 255; i > 0; i--) {
      int j = rand.nextInt(i + 1);
      int temp = p[i];
      p[i] = p[j];
      p[j] = temp;
    }

    // 重复两次
    for (int i = 0; i < 512; i++) perm[i] = p[i & 255];
  }

  float noise(float x, float y) {
    int X = (int)Math.floor(x) & 255;
    int Y = (int)Math.floor(y) & 255;

    x -= Math.floor(x);
    y -= Math.floor(y);

    float u = fade(x);
    float v = fade(y);

    int A = perm[X] + Y;
    int B = perm[X + 1] + Y;

    return lerp(v,
      lerp(u, grad(perm[A], x, y), grad(perm[B], x - 1, y)),
      lerp(u, grad(perm[A + 1], x, y - 1), grad(perm[B + 1], x - 1, y - 1))
    );
  }

  private float fade(float t) {
    return t * t * t * (t * (t * 6 - 15) + 10);
  }

  private float lerp(float t, float a, float b) {
    return a + t * (b - a);
  }

  private float grad(int hash, float x, float y) {
    int h = hash & 3;
    float u = h < 2 ? x : y;
    float v = h < 2 ? y : x;
    return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
  }
}
