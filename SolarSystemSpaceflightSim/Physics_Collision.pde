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
      ship.state = SpacecraftState.DESTROYED;
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
