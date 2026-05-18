// ============================================================
//  Physics_ForceSolver - 受力计算
//  计算引力、推力、大气阻力
// ============================================================

// ============================================================
//  ForceModel — 力模型抽象基类
// ============================================================

abstract class ForceModel {
  abstract void computeForce(Vector2 pos, Vector2 vel, Vector2 accelOut);
  abstract void computeForce(Vector2 pos, Vector2 vel, Vector2 accelOut, boolean useThrust);
  abstract double bodyRadius();
  abstract boolean thrustActive();
}

// ============================================================
//  SpacecraftForceModel — 航天器力模型
// ============================================================

class SpacecraftForceModel extends ForceModel {
  CelestialBody referenceBody;
  List<CelestialBody> gravityBodies;
  CelestialSystem solarSystem;
  boolean thrustActive;
  Vector2 thrustDirection;
  double thrustAccel;
  double dragCoeff;
  double crossSection;
  double shipMass;

  AtmosphereModel atmosphere;

  SpacecraftForceModel(CelestialSystem ss) {
    this.solarSystem = ss;
    this.atmosphere = new AtmosphereModel();
    this.thrustActive = false;
    this.thrustDirection = new Vector2(0, 0);
    this.thrustAccel = 0;
    this.dragCoeff = 0.5;
    this.crossSection = 4.0; // 4 m² default
    this.shipMass = 2000.0; // 2吨 default
  }

  void setState(CelestialBody refBody, List<CelestialBody> bodies,
                boolean thrust, Vector2 thrustDir, double thrustAcc,
                double dragCoeff, double crossSection, double shipMass) {
    this.referenceBody = refBody;
    this.gravityBodies = bodies;
    this.thrustActive = thrust;
    this.thrustDirection = thrustDir;
    this.thrustAccel = thrustAcc;
    this.dragCoeff = dragCoeff;
    this.crossSection = crossSection;
    this.shipMass = shipMass * 1000.0; // 吨转千克
  }

  void computeForce(Vector2 pos, Vector2 vel, Vector2 accelOut) {
    computeForce(pos, vel, accelOut, thrustActive);
  }

  void computeForce(Vector2 pos, Vector2 vel, Vector2 accelOut, boolean useThrust) {
    // 重置加速度
    accelOut.x = 0;
    accelOut.y = 0;

    // 计算引力
    computeGravity(pos, accelOut);

    // 计算大气阻力
    if (referenceBody != null) {
      computeDrag(pos, vel, accelOut);
    }

    // 计算推力
    if (useThrust && thrustAccel > 0) {
      double dirMag = thrustDirection.magnitude();
      if (dirMag > 0.0001) {
        accelOut.x += thrustDirection.x / dirMag * thrustAccel;
        accelOut.y += thrustDirection.y / dirMag * thrustAccel;
      }
    }
  }

  void computeGravity(Vector2 pos, Vector2 accelOut) {
    if (referenceBody != null) {
      // 相对于中心天体的引力
      double r = pos.magnitude();
      if (r > 0.001) {
        double GM = referenceBody.GM;
        double accMag = -GM / (r * r);
        accelOut.x += pos.x / r * accMag;
        accelOut.y += pos.y / r * accMag;
      }

      // 其他天体的摄动
      for (CelestialBody body : gravityBodies) {
        if (body == referenceBody) continue;
        if (body.name.equals("Sun")) continue; // 中心天体系统中太阳不计算摄动

        // 计算天体相对于参考天体的位置
        double bx = body.px;
        double by = body.py;
        if (referenceBody.parentBody != null) {
          bx -= referenceBody.px;
          by -= referenceBody.py;
        }

        double dx = bx - pos.x;
        double dy = by - pos.y;
        double distSq = dx*dx + dy*dy;
        double dist = Math.sqrt(distSq);

        if (dist > 0.001) {
          double acc = body.GM / distSq;
          accelOut.x += dx / dist * acc;
          accelOut.y += dy / dist * acc;
        }
      }
    } else {
      // 日心模式：所有天体的引力
      for (CelestialBody body : gravityBodies) {
        double dx = body.px - pos.x;
        double dy = body.py - pos.y;
        double distSq = dx*dx + dy*dy;
        double dist = Math.sqrt(distSq);

        if (dist > 0.001) {
          double acc = body.GM / distSq;
          accelOut.x += dx / dist * acc;
          accelOut.y += dy / dist * acc;
        }
      }

      // 太阳的引力
      double dx = -pos.x;
      double dy = -pos.y;
      double distSq = dx*dx + dy*dy;
      double dist = Math.sqrt(distSq);
      if (dist > 0.001) {
        double acc = GM_SUN / distSq;
        accelOut.x += dx / dist * acc;
        accelOut.y += dy / dist * acc;
      }
    }
  }

  void computeDrag(Vector2 pos, Vector2 vel, Vector2 accelOut) {
    if (referenceBody == null) return;

    double alt = atmosphere.altitudeAboveSurface(pos, referenceBody);
    if (alt >= atmosphere.atmosphereHeight(referenceBody)) {
      return;
    }

    double vx = vel.x, vy = vel.y;
    double v = Math.sqrt(vx * vx + vy * vy);
    if (v < 0.001) {
      return;
    }

    double rho = atmosphere.density(referenceBody, alt);
    double dragMagnitude = 0.5 * dragCoeff * crossSection * rho * v * v;
    dragMagnitude /= shipMass;

    accelOut.x += -dragMagnitude * (vx / v);
    accelOut.y += -dragMagnitude * (vy / v);
  }

  double bodyRadius() {
    return referenceBody != null ? referenceBody.radius : 696340.0;
  }

  boolean thrustActive() {
    return thrustActive;
  }
}

// ============================================================
//  AtmosphereModel — 大气模型
// ============================================================

class AtmosphereModel {
  final double EARTH_ATMOSPHERE_HEIGHT = 140.0;
  final double MARS_ATMOSPHERE_HEIGHT   = 80.0;
  final double VENUS_ATMOSPHERE_HEIGHT  = 250.0;

  final double EARTH_RHO0 = 1.225e9;
  final double MARS_RHO0  = 0.020e9;
  final double VENUS_RHO0 = 65.0e9;

  final double EARTH_SCALE_HEIGHT = 8.5;
  final double MARS_SCALE_HEIGHT  = 11.1;
  final double VENUS_SCALE_HEIGHT = 15.9;

  double atmosphereHeight(CelestialBody body) {
    if (body == null) return 0;
    if (body.name.equals("Earth")) return EARTH_ATMOSPHERE_HEIGHT;
    if (body.name.equals("Mars"))  return MARS_ATMOSPHERE_HEIGHT;
    if (body.name.equals("Venus")) return VENUS_ATMOSPHERE_HEIGHT;
    return 0;
  }

  double density(CelestialBody body, double altitudeKm) {
    if (body == null) return 0;

    double rho0, scaleHeight;
    if (body.name.equals("Earth")) {
      rho0 = EARTH_RHO0;
      scaleHeight = EARTH_SCALE_HEIGHT;
    } else if (body.name.equals("Mars")) {
      rho0 = MARS_RHO0;
      scaleHeight = MARS_SCALE_HEIGHT;
    } else if (body.name.equals("Venus")) {
      rho0 = VENUS_RHO0;
      scaleHeight = VENUS_SCALE_HEIGHT;
    } else {
      return 0;
    }

    if (altitudeKm < 0) altitudeKm = 0;
    return rho0 * Math.exp(-altitudeKm / scaleHeight);
  }

  double altitudeAboveSurface(Vector2 relPos, CelestialBody body) {
    double r = relPos.magnitude();
    return r - body.radius;
  }

  boolean inAtmosphere(CelestialBody body, double altitudeKm) {
    return altitudeKm < atmosphereHeight(body);
  }

  boolean inAtmosphere(Vector2 relPos, CelestialBody body) {
    return inAtmosphere(body, altitudeAboveSurface(relPos, body));
  }
}
