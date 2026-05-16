class MissionPlanner {
  static final double GM_EARTH = 3.986004e5;
  static final double EARTH_RADIUS_KM = 6371.0;
  static final double LEO_ALTITUDE_KM = 420.0;
  static final double LEO_RADIUS_KM = EARTH_RADIUS_KM + LEO_ALTITUDE_KM;

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
    double t_transfer = PI * Math.sqrt(Math.pow(a_transfer, 3.0) / GM_SUN);

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

    params.transferTime = PI * Math.sqrt(Math.pow(a_transfer, 3.0) / GM_SUN);
    params.launchDate = launchTime;
    params.arrivalDate = launchTime + params.transferTime;

    // ========== 使用 patched conic 方法计算 TMI ΔV ==========
    // 1. 计算日心霍曼转移在地球轨道处的速度
    double v_earth = Math.sqrt(GM_SUN / r1);
    double v_trans_earth = Math.sqrt(GM_SUN * (2.0 / r1 - 1.0 / a_transfer));

    // 2. 计算需要的双曲线过剩速度 v∞ (日心坐标系中的速度差)
    double v_infinity = Math.abs(v_trans_earth - v_earth);

    // 3. 计算地球相对坐标系中从 LEO 到该逃逸双曲线所需的 ΔV
    double r_leo = LEO_RADIUS_KM;
    double v_leo = Math.sqrt(origin.GM / r_leo);

    // 双曲线轨道在 r_leo 处的速度
    double v_esc_infty = Math.sqrt(2 * origin.GM / r_leo + v_infinity * v_infinity);

    // TMI ΔV = 双曲线速度 - LEO 圆轨道速度
    params.tmiDeltaV = Math.max(0.0, v_esc_infty - v_leo);

    // ========== 计算 TOI ΔV ==========
    // 1. 计算到达目标天体时的日心相对速度
    double v_target = Math.sqrt(GM_SUN / r2);
    double v_trans_target = Math.sqrt(GM_SUN * (2.0 / r2 - 1.0 / a_transfer));
    double arrival_v_infinity = Math.abs(v_target - v_trans_target);

    // 2. 计算目标天体捕获 ΔV (使用 patched conic)
    double rCapture = target.radius * 10.0;

    // 双曲线接近时的近心点速度
    double v_approach_periapsis = Math.sqrt(2 * target.GM / rCapture + arrival_v_infinity * arrival_v_infinity);

    // 目标圆轨道速度
    double vCaptureCirc = Math.sqrt(target.GM / rCapture);

    // TOI ΔV = 近心点速度 - 目标圆轨道速度
    params.toiDeltaV = Math.max(0.0, v_approach_periapsis - vCaptureCirc);

    params.totalDeltaV = params.tmiDeltaV + params.toiDeltaV;
    params.phaseAngleAtLaunch = calculatePhaseAngle(origin, target, launchTime);

    return params;
  }

  // 获取目标天体的 GM 值（向后兼容）
  double getTargetGM(CelestialBody body) {
    return body.GM;
  }

  // 计算天体的影响球半径 (km) — 使用物理公式
  double calculateSOI(CelestialBody body) {
    return body.getSOIRadius();
  }

  double calculateLaunchVelocity(double altitude_km) {
    double r = EARTH_RADIUS_KM + altitude_km;
    return Math.sqrt(GM_EARTH / r);
  }

  double getLEORadius() {
    return LEO_RADIUS_KM;
  }

  // 计算转移时间（开普勒第三定律）
  double calculateTransferTime(double a, double GM) {
    return PI * Math.sqrt(Math.pow(a, 3.0) / GM);
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
