// ============================================================
//  FlightComputer - 制导算法库
//  包含上升段制导、PEG圆化制导、轨道计算
// ============================================================

class FlightComputer {
  // 制导常量
  static final double THRUST_ACCEL = 0.025;  // 假设的推力加速度 km/s²
  static final double VERTICAL_RISE_TIME = 10.0;  // 垂直上升时间
  static final double MAX_PITCH_RAD = 1.4835298641951802;  // 最大俯仰角
  static final double PITCH_EXPONENT = 0.7;  // 俯仰角变化指数
  static final double PEG_K_ALT = 0.05;  // PEG高度增益
  static final double PEG_K_VRAD = 3.0;  // PEG径向速度增益
  static final double PEG_MAX_PITCH = 1.2;  // PEG最大俯仰角

  FlightComputer() {
  }

  // ==============================================================
  //  上升段推力方向 - 俯仰程序
  //  返回推力方向单位向量
  // ==============================================================

  Vector2 ascentThrustDirection(Vector2 pos, double burnTime, double targetAltitude) {
    double r = pos.magnitude();
    if (r < 1.0) {
      return new Vector2(1, 0);
    }

    // 计算俯仰角
    double pitchAngle;
    if (burnTime < VERTICAL_RISE_TIME) {
      pitchAngle = 0;  // 垂直上升
    } else {
      double alt = r - EARTH_RADIUS_KM;
      double altFrac = Math.max(0.0, Math.min(1.0, alt / targetAltitude));
      pitchAngle = Math.pow(altFrac, PITCH_EXPONENT) * MAX_PITCH_RAD;
    }

    // 计算推力方向：从径向向外按pitchAngle向切向旋转
    Vector2 radial = pos.normalized();
    Vector2 tangential = new Vector2(-radial.y, radial.x);  // 逆时针切向

    double cosP = Math.cos(pitchAngle);
    double sinP = Math.sin(pitchAngle);

    return new Vector2(
      radial.x * cosP + tangential.x * sinP,
      radial.y * cosP + tangential.y * sinP
    );
  }

  // ==============================================================
  //  PEG 制导 - 远地点圆化
  //  返回推力方向单位向量
  // ==============================================================

  Vector2 pegGuidance(Vector2 pos, Vector2 vel, double targetRadius, double GM) {
    double r = pos.magnitude();
    if (r < 1.0) {
      return new Vector2(1, 0);
    }

    // 计算径向速度
    double vRad = pos.dot(vel) / r;

    // 计算高度误差
    double altError = r - targetRadius;

    // 计算俯仰补偿角
    double pitchOffset = -PEG_K_ALT * altError - PEG_K_VRAD * vRad;
    pitchOffset = constrainDouble(pitchOffset, -PEG_MAX_PITCH, PEG_MAX_PITCH);

    // 计算推力方向：从切向按pitchOffset向径向旋转
    Vector2 radial = pos.normalized();
    Vector2 tangential = new Vector2(-radial.y, radial.x);

    double cosP = Math.cos(pitchOffset);
    double sinP = Math.sin(pitchOffset);

    return new Vector2(
      tangential.x * cosP + radial.x * sinP,
      tangential.y * cosP + radial.y * sinP
    );
  }

  // ==============================================================
  //  计算远地点高度 (km)
  // ==============================================================

  double apoapsisAltitude(Vector2 pos, Vector2 vel, double bodyRadius, double GM) {
    double[] p = osculatingParams(pos, vel, GM);
    if (p[0] >= Double.MAX_VALUE / 2) return Double.MAX_VALUE;
    return p[0] * (1.0 + p[1]) - bodyRadius;
  }

  // ==============================================================
  //  计算近地点高度 (km)
  // ==============================================================

  double perigeeAltitude(Vector2 pos, Vector2 vel, double bodyRadius, double GM) {
    double[] p = osculatingParams(pos, vel, GM);
    if (p[0] >= Double.MAX_VALUE / 2) return Double.MAX_VALUE;
    return p[0] * (1.0 - p[1]) - bodyRadius;
  }

  // ==============================================================
  //  计算到远地点的时间 (秒)，-1表示已过
  // ==============================================================

  double timeToApoapsis(Vector2 pos, Vector2 vel, double GM) {
    double[] p = osculatingParams(pos, vel, GM);
    if (p[3] >= 0) return -1; // 双曲线
    double a = p[0], e = p[1];
    if (e < 0.0001) return Double.MAX_VALUE; // 近圆轨道

    double r = pos.magnitude();
    double vRad = pos.dot(vel) / r;

    double cosNu = (a * (1.0 - e * e) / r - 1.0) / e;
    cosNu = constrainDouble(cosNu, -1.0, 1.0);
    double nu = Math.acos(cosNu);
    if (vRad < 0) nu = 2.0 * PI - nu;

    double cosE = (e + Math.cos(nu)) / (1.0 + e * Math.cos(nu));
    double sinE = Math.sqrt(1.0 - e * e) * Math.sin(nu) / (1.0 + e * Math.cos(nu));
    double E = Math.atan2(sinE, cosE);
    if (E < 0) E += 2.0 * PI;

    double M = E - e * Math.sin(E);
    double n = Math.sqrt(GM / (a * a * a));

    if (M < PI) return (PI - M) / n;
    return -1;
  }

  // ==============================================================
  //  计算圆化燃烧所需的 delta-V 和燃烧时间
  //  返回 [deltaV (km/s), burnDuration (s)]
  // ==============================================================

  double[] computeCircularizationBurn(Vector2 pos, Vector2 vel, double targetApoAlt, double bodyRadius, double GM) {
    double r = pos.magnitude();
    double v2 = vel.magnitudeSq();
    double energy = v2 / 2.0 - GM / r;

    if (energy < 0) {
      double a = -GM / (2.0 * energy);
      double h = pos.x * vel.y - pos.y * vel.x;
      double e2 = 1.0 - h * h / (GM * a);
      double e = Math.sqrt(Math.max(0.0, e2));
      double rApo = a * (1.0 + e);
      double vApo = Math.sqrt(GM * (2.0 / rApo - 1.0 / a));
      double vCirc = Math.sqrt(GM / rApo);
      double dv = vCirc - vApo;
      double burnDuration = Math.max(dv / THRUST_ACCEL, 0.5);
      return new double[]{dv, burnDuration};
    } else {
      return new double[]{0, 5.0};
    }
  }

  // ==============================================================
  //  辅助：计算吻切轨道参数
  //  返回 [a (km), e, h (km^2/s), energy]
  // ==============================================================

  double[] osculatingParams(Vector2 pos, Vector2 vel, double GM) {
    double r = pos.magnitude();
    double v2 = vel.magnitudeSq();
    double energy = v2 / 2.0 - GM / r;
    if (energy >= 0) return new double[]{Double.MAX_VALUE, Double.MAX_VALUE, 0, energy};
    double a = -GM / (2.0 * energy);
    double h = pos.x * vel.y - pos.y * vel.x;
    double e2 = 1.0 - h * h / (GM * a);
    double e = Math.sqrt(Math.max(0.0, e2));
    return new double[]{a, e, h, energy};
  }

  // ==============================================================
  //  估算需要的推力比例（用于上升段提前关机）
  // ==============================================================

  double estimateThrustFraction(
      Vector2 pos, Vector2 vel,
      double thrustAccel, Vector2 thrustDir, double GM,
      double targetApoAlt, double bodyRadius) {
    double currentApo = apoapsisAltitude(pos, vel, bodyRadius, GM);
    if (currentApo >= targetApoAlt) return 0;

    double r = pos.magnitude();
    double gMag = GM / (r * r);
    Vector2 grav = pos.normalized().mul(-gMag);

    Vector2 thr = thrustDir.mul(thrustAccel);
    Vector2 accel = grav.add(thr);

    // 前向欧拉一步预测
    double step = 1.0;
    Vector2 vxFull = vel.add(accel.mul(step));
    Vector2 rxFull = pos.add(vxFull.mul(step));

    double apoFull = apoapsisAltitude(rxFull, vxFull, bodyRadius, GM);

    Vector2 vxGravOnly = vel.add(grav.mul(step));
    Vector2 rxGravOnly = pos.add(vxGravOnly.mul(step));
    double apoGravOnly = apoapsisAltitude(rxGravOnly, vxGravOnly, bodyRadius, GM);

    if (apoFull > apoGravOnly && apoGravOnly < targetApoAlt) {
      double f = (targetApoAlt - apoGravOnly) / (apoFull - apoGravOnly);
      f = constrainDouble(f, 0.0, 1.0);
      return f;
    }
    return 1.0; // 全推力
  }
}
