class MissionPlanner {
  static final double GM_EARTH = 3.986004e5;
  static final double EARTH_RADIUS_KM = 6371.0;
  static final double LEO_ALTITUDE_KM = 420.0;
  static final double LEO_RADIUS_KM = EARTH_RADIUS_KM + LEO_ALTITUDE_KM;

  // 目标天体 GM 值 (km³/s²)
  static final double GM_MARS = 4.2828e4;
  static final double GM_VENUS = 3.2486e5;
  static final double GM_MERCURY = 2.2032e4;
  static final double GM_JUPITER = 1.26687e8;

  // 计算两个角度的最小差值（归一化到 [-π, π]）
  double angleDifference(double a, double b) {
    double diff = a - b;
    while (diff > PI) diff -= 2*PI;
    while (diff < -PI) diff += 2*PI;
    return diff;
  }

  // 计算某时刻目标相对于原点的相位角
  double calculatePhaseAngle(CelestialBody origin, CelestialBody target, double t) {
    double nuOrigin = getTrueAnomalyAtTime(origin, t);
    double nuTarget = getTrueAnomalyAtTime(target, t);
    return angleDifference(nuTarget, nuOrigin);
  }

  // 寻找下一个发射窗口
  double findNextLaunchWindow(CelestialBody origin, CelestialBody target,
                             double startTime, double searchDurationDays) {
    double searchEnd = startTime + searchDurationDays * DAY_S;
    double r1 = origin.a;
    double r2 = target.a;
    double a_transfer = (r1 + r2) / 2.0;
    double t_transfer = PI * Math.sqrt(Math.pow(a_transfer, 3) / GM_SUN);

    // 计算理想的目标相位角（在发射时）
    // 当航天器到达时，目标应该正好位于相遇点
    double targetMotionDuringTransfer = (t_transfer / target.period) * 2*PI;
    double idealPhaseAngle = PI - targetMotionDuringTransfer;

    // 归一化到 [-π, π]
    while (idealPhaseAngle > PI) idealPhaseAngle -= 2*PI;
    while (idealPhaseAngle < -PI) idealPhaseAngle += 2*PI;

    // 搜索最佳匹配窗口（步长：1 小时）
    double bestTime = startTime;
    double bestError = Double.MAX_VALUE;

    for (double t = startTime; t < searchEnd; t += 3600.0) {
      double currentPhase = calculatePhaseAngle(origin, target, t);
      double error = Math.abs(angleDifference(currentPhase, idealPhaseAngle));
      if (error < bestError) {
        bestError = error;
        bestTime = t;
      }
    }

    return bestTime;
  }

  // 计算霍曼转移轨道参数 [a, e]
  double[] calculateHohmannTransfer(double r1_km, double r2_km) {
    double a_transfer = (r1_km + r2_km) / 2.0;
    double e_transfer = Math.abs(r2_km - r1_km) / (r2_km + r1_km);
    return new double[]{a_transfer, e_transfer};
  }

  // 计算转移时间（半个周期）
  double calculateTransferTime(double a_km, double GM) {
    return PI * Math.sqrt(Math.pow(a_km, 3) / GM);
  }

  // 计算转移所需 ΔV（霍曼转移）
  double calculateDeltaV(double r1_km, double r2_km, double GM) {
    double v1 = Math.sqrt(GM / r1_km);
    double v2_transfer = Math.sqrt(GM * (2.0 / r1_km - 1.0 / ((r1_km + r2_km) / 2.0)));
    double v2_insert = Math.sqrt(GM / r2_km);
    return Math.abs(v2_transfer - v1) + Math.abs(v2_insert - v2_transfer);
  }

  // 计算完整的转移任务参数
  TransferParameters computeTransferMission(CelestialBody origin, CelestialBody target,
                                            double launchTime) {
    TransferParameters params = new TransferParameters();

    double r1 = origin.a;
    double r2 = target.a;
    double a_transfer = (r1 + r2) / 2.0;
    double e_transfer = Math.abs(r2 - r1) / (r2 + r1);

    params.transferTime = PI * Math.sqrt(Math.pow(a_transfer, 3) / GM_SUN);
    params.launchDate = launchTime;
    params.arrivalDate = launchTime + params.transferTime;

    // 计算 TMI ΔV (Trans-Mars Injection / Trans-X Injection)
    double v_earth = Math.sqrt(GM_SUN / r1);
    double v_trans_earth = Math.sqrt(GM_SUN * (2.0/r1 - 1.0/a_transfer));
    params.tmiDeltaV = Math.abs(v_trans_earth - v_earth);

    // 计算到达时的相对速度
    double v_target = Math.sqrt(GM_SUN / r2);
    double v_trans_target = Math.sqrt(GM_SUN * (2.0/r2 - 1.0/a_transfer));
    double arrivalDV = Math.abs(v_target - v_trans_target);

    // 捕获到绕目标的圆轨道（轨道半径 = 10 * 目标半径）
    double rCapture = target.radius * 10.0;
    double GM_target = getTargetGM(target);
    double vCaptureCirc = Math.sqrt(GM_target / rCapture);

    // 简化：TOI ΔV = 到达时相对速度 + 捕获到圆轨道的 ΔV
    params.toiDeltaV = arrivalDV * 0.5 + vCaptureCirc;  // 缩放因子使数值合理

    params.totalDeltaV = params.tmiDeltaV + params.toiDeltaV;
    params.phaseAngleAtLaunch = calculatePhaseAngle(origin, target, launchTime);

    return params;
  }

  // 获取目标天体的 GM 值
  double getTargetGM(CelestialBody body) {
    if (body.name.equals("Mars")) return GM_MARS;
    if (body.name.equals("Venus")) return GM_VENUS;
    if (body.name.equals("Mercury")) return GM_MERCURY;
    if (body.name.equals("Jupiter")) return GM_JUPITER;
    return GM_EARTH;  // 默认地球
  }

  // 计算天体的影响球半径 (km)
  double calculateSOI(CelestialBody body) {
    if (body.name.equals("Mars")) return 578000.0;
    if (body.name.equals("Venus")) return 616000.0;
    if (body.name.equals("Earth")) return 925000.0;
    if (body.name.equals("Mercury")) return 112000.0;
    if (body.name.equals("Jupiter")) return 48200000.0;
    return 500000.0;  // 默认
  }

  double calculateLaunchVelocity(double altitude_km) {
    double r = EARTH_RADIUS_KM + altitude_km;
    return Math.sqrt(GM_EARTH / r);
  }

  double getLEORadius() {
    return LEO_RADIUS_KM;
  }
}

// 转移任务参数类
class TransferParameters {
  double tmiDeltaV;      // TMI ΔV (km/s)
  double toiDeltaV;     // TOI ΔV (km/s)
  double totalDeltaV;   // 总 ΔV
  double transferTime;  // 转移时间 (秒)
  double launchDate;    // 发射日期 (simTime)
  double arrivalDate;   // 到达日期 (simTime)
  double phaseAngleAtLaunch;  // 发射时相位角
}
