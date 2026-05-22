// ============================================================
//  Physics_Collision - 碰撞检测
//  检测与天体表面的碰撞
// ============================================================

class CollisionDetector {
  CelestialSystem solarSystem;

  CollisionDetector(CelestialSystem ss) {
    this.solarSystem = ss;
  }

  // ============================================================
  //  检查航天器是否与天体碰撞
  // ============================================================

  CollisionResult checkCollision(Spacecraft ship) {
    CollisionResult result = new CollisionResult();

    if (ship.referenceBody != null) {
      // 在天体参考系中检查
      double r = ship.stateVector.position.magnitude();
      if (r <= ship.referenceBody.radius) {
        result.hasCollision = true;
        result.body = ship.referenceBody;
        result.collisionPoint = ship.stateVector.position.clone();
        return result;
      }
    } else {
      // 在日心系中检查所有天体
      for (CelestialBody planet : solarSystem.planets) {
        double dx = ship.worldX - planet.px;
        double dy = ship.worldY - planet.py;
        double dist = Math.sqrt(dx*dx + dy*dy);
        if (dist <= planet.radius) {
          result.hasCollision = true;
          result.body = planet;
          result.collisionPoint = new Vector2(dx, dy);
          return result;
        }
      }
      for (CelestialBody moon : solarSystem.moons) {
        double dx = ship.worldX - moon.px;
        double dy = ship.worldY - moon.py;
        double dist = Math.sqrt(dx*dx + dy*dy);
        if (dist <= moon.radius) {
          result.hasCollision = true;
          result.body = moon;
          result.collisionPoint = new Vector2(dx, dy);
          return result;
        }
      }
    }

    return result;
  }

  // ============================================================
  //  预测近期碰撞
  // ============================================================

  CollisionPrediction predictCollision(Spacecraft ship, double dtMax) {
    CollisionPrediction prediction = new CollisionPrediction();

    // 简单预测：检查当前轨道是否会在dtMax时间内碰撞
    if (ship.referenceBody != null && ship.orbit != null) {
      double periapsis = ship.orbit.getPeriapsisRadius();
      if (periapsis <= ship.referenceBody.radius) {
        prediction.willCollide = true;
        prediction.body = ship.referenceBody;
        prediction.timeToCollision = 0; // 需要更精确的计算
      }
    }

    return prediction;
  }

  // ============================================================
  //  处理碰撞结果
  // ============================================================

  void handleCollision(Spacecraft ship, CollisionResult result) {
    if (result.hasCollision && result.body != null) {
      // 检查是否是软着陆场景
      if (isLandingScenario(ship, result)) {
        // 软着陆：约束在表面，不销毁
        handleSoftLanding(ship, result);
      } else {
        // 硬碰撞：销毁
        ship.state = SpacecraftState.DESTROYED;
      }
    }
  }

  // ============================================================
  //  判断是否是着陆场景
  // ============================================================

  boolean isLandingScenario(Spacecraft ship, CollisionResult result) {
    // 如果飞船已经是 LANDED 状态
    if (ship.state == SpacecraftState.LANDED) {
      return true;
    }
    // 如果飞船正对着径向向外（着陆姿态）且高度很低
    if (ship.referenceBody != null && result.body == ship.referenceBody) {
      double alt = ship.getAltitude();
      double shipHeight = Spacecraft.SHIP_LENGTH_KM;
      if (alt < shipHeight * 2.0) { // 2倍箭体高度内认为是着陆阶段
        return true;
      }
    }
    return false;
  }

  // ============================================================
  //  处理软着陆：约束飞船在表面
  // ============================================================

  void handleSoftLanding(Spacecraft ship, CollisionResult result) {
    // 确保状态是 LANDED
    ship.state = SpacecraftState.LANDED;
    // 固定在表面
    ship.isFixedToSurface = true;
    // 校正位置到表面以上
    snapToSurface(ship, result.body);
  }

  // ============================================================
  //  将飞船位置校正到表面以上
  // ============================================================

  void snapToSurface(Spacecraft ship, CelestialBody body) {
    Vector2 pos = ship.stateVector.position;
    double currentRadius = pos.magnitude();
    double targetRadius = body.radius + Spacecraft.SHIP_LENGTH_KM * 0.5;

    if (currentRadius < targetRadius) {
      ship.stateVector.position = pos.normalized().mul(targetRadius);
      ship.stateVector.velocity = new Vector2(0, 0);
    }
  }
}

// ============================================================
//  碰撞结果
// ============================================================

class CollisionResult {
  boolean hasCollision;
  CelestialBody body;
  Vector2 collisionPoint;
  double collisionTime;

  CollisionResult() {
    this.hasCollision = false;
    this.body = null;
    this.collisionPoint = new Vector2(0, 0);
    this.collisionTime = 0;
  }
}

// ============================================================
//  碰撞预测
// ============================================================

class CollisionPrediction {
  boolean willCollide;
  CelestialBody body;
  double timeToCollision;

  CollisionPrediction() {
    this.willCollide = false;
    this.body = null;
    this.timeToCollision = Double.MAX_VALUE;
  }
}
