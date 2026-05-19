// ============================================================
//  MISSION PLANNER - 任务规划器
//  功能：计算霍曼转移、变轨机动、转移窗口
// ============================================================

class MissionPlanner {

  MissionPlanner() {
  }

  List<ManeuverNode> planHohmannTransfer(Orbit initialOrbit, Orbit targetOrbit) {
    List<ManeuverNode> maneuvers = new ArrayList<ManeuverNode>();

    if (initialOrbit == null || targetOrbit == null) return maneuvers;
    if (initialOrbit.referenceBody != targetOrbit.referenceBody) return maneuvers;

    CelestialBody body = initialOrbit.referenceBody;
    double GM = body.GM;

    double r1_initial = initialOrbit.getPeriapsisRadius();
    double r1_apo = initialOrbit.getApoapsisRadius();
    double r2_initial = targetOrbit.getPeriapsisRadius();
    double r2_apo = targetOrbit.getApoapsisRadius();

    double r1 = (r1_initial + r1_apo) / 2;
    double r2 = (r2_initial + r2_apo) / 2;

    double a_trans = (r1 + r2) / 2;

    double v1 = Math.sqrt(GM / r1);
    double v_trans_peri = Math.sqrt(GM * (2 / r1 - 1 / a_trans));
    double dv1 = v_trans_peri - v1;

    double v_trans_apo = Math.sqrt(GM * (2 / r2 - 1 / a_trans));
    double v2 = Math.sqrt(GM / r2);
    double dv2 = v2 - v_trans_apo;

    double transferTime = PI * Math.sqrt(a_trans * a_trans * a_trans / GM);

    ManeuverNode node1 = new ManeuverNode(0, new Vector2(dv1, 0));
    node1.direction = "prograde";
    node1.description = "Hohmann burn 1 at periapsis";
    node1.deltaVMagnitude = Math.abs(dv1);
    maneuvers.add(node1);

    ManeuverNode node2 = new ManeuverNode(transferTime, new Vector2(dv2, 0));
    node2.direction = "prograde";
    node2.description = "Hohmann burn 2 at apoapsis";
    node2.deltaVMagnitude = Math.abs(dv2);
    maneuvers.add(node2);

    return maneuvers;
  }

  ManeuverNode planSimpleOrbitChange(Orbit currentOrbit, double newA, double newE, double simTime) {
    if (currentOrbit == null) return null;

    CelestialBody body = currentOrbit.referenceBody;
    double GM = body.GM;

    double r_pe = currentOrbit.getPeriapsisRadius();

    double v_pe = Math.sqrt(GM * (2 / r_pe - 1 / currentOrbit.a));
    double v_pe_target = Math.sqrt(GM * (2 / r_pe - 1 / newA));
    double dv = v_pe_target - v_pe;

    double currentNu = currentOrbit.getTrueAnomalyAtTime(simTime);
    double timeToPe = getTimeToTrueAnomaly(currentOrbit, currentNu, 0, simTime);

    ManeuverNode node = new ManeuverNode(timeToPe, new Vector2(dv, 0));
    node.direction = "prograde";
    node.description = "Orbit change burn at periapsis";
    node.deltaVMagnitude = Math.abs(dv);

    return node;
  }


  // 计算飞船在时刻t的位置角度（惯性系，弧度）
  double getSpacecraftAngleAtTime(Orbit orbit, double t) {
    // 直接计算位置，然后从位置得到角度（与月球计算方式一致）
    Vector2 pos = orbit.getPositionAtTime(t);
    return Math.atan2(pos.y, pos.x);
  }

  // 计算月球在时刻t的角度（惯性系，弧度）
  double getMoonAngleAtTime(CelestialBody moon, double t) {
    // 计算月球相对于地球的位置角度（地球参考系！）
    double[] posRel = getMoonPositionRelativeToEarthAtTime(moon, t);
    return Math.atan2(posRel[1], posRel[0]);
  }

  // 计算月球在时刻t相对于地球的位置（地球参考系，km）
  // 与CelestialBody.update中计算方式完全一致
  double[] getMoonPositionRelativeToEarthAtTime(CelestialBody moon, double t) {
    if (moon.orbit != null) {
      // ========== 完全照搬 CelestialBody.update 中的逻辑 ==========
      double nu = moon.orbit.getTrueAnomalyAtTime(t);

      // 关键！orbitalToCartesian实际期望i, omega, w都是弧度！
      // 虽然参数名叫i_deg，但看getPositionAtTime函数，传的就是弧度！
      double[] pos3D = orbitalToCartesian(moon.orbit.a, moon.orbit.e, moon.i, moon.omega, moon.orbit.w, nu);

      // 返回2D位置（相对于地球，不加parentBody位置）
      return new double[]{ pos3D[0], pos3D[1] };
    } else {
      // 备用逻辑
      double n = TWO_PI / moon.period;
      double M = (moon.M0 + n * t) % TWO_PI;
      if (M < 0) M += TWO_PI;
      double E = solveKepler(M, moon.e);
      double nu = trueAnomaly(E, moon.e);

      // 直接传弧度！
      double[] pos3D = orbitalToCartesian(moon.a, moon.e, moon.i, moon.omega, moon.w, nu);
      return new double[]{ pos3D[0], pos3D[1] };
    }
  }

  private double getMoonTrueAnomaly(CelestialBody moon, double simTime) {
    double n = 2.0 * PI / moon.period;
    double M = (moon.M0 + n * simTime) % (2.0 * PI);
    if (M < 0) M += 2.0 * PI;
    double E = solveKepler(M, moon.e);
    return trueAnomaly(E, moon.e);
  }

  private double getTimeToTrueAnomaly(Orbit orbit, double currentNu, double targetNu, double simTime) {
    currentNu = normalizeAngle(currentNu);
    targetNu = normalizeAngle(targetNu);

    double currentE = 2 * Math.atan2(
      Math.sqrt(1 - orbit.e) * Math.sin(currentNu / 2),
      Math.sqrt(1 + orbit.e) * Math.cos(currentNu / 2)
    );
    if (currentE < 0) currentE += TWO_PI;

    double targetE = 2 * Math.atan2(
      Math.sqrt(1 - orbit.e) * Math.sin(targetNu / 2),
      Math.sqrt(1 + orbit.e) * Math.cos(targetNu / 2)
    );
    if (targetE < 0) targetE += TWO_PI;

    double currentM = currentE - orbit.e * Math.sin(currentE);
    double targetM = targetE - orbit.e * Math.sin(targetE);

    double deltaM = targetM - currentM;
    if (deltaM < 0) deltaM += TWO_PI;

    double meanMotion = TWO_PI / orbit.period;
    return deltaM / meanMotion;
  }

  private double normalizeAngle(double angle) {
    while (angle < 0) angle += TWO_PI;
    while (angle >= TWO_PI) angle -= TWO_PI;
    return angle;
  }

  double getTotalDeltaV(List<ManeuverNode> maneuvers) {
    double total = 0;
    for (ManeuverNode node : maneuvers) {
      if (node.deltaVMagnitude > 0) {
        total += node.deltaVMagnitude;
      } else {
        total += node.deltaV.magnitude();
      }
    }
    return total;
  }

  // ========== 简化地月转移窗口计算（解析法）==========
  double calculateSimpleLunarWindow(CelestialBody earth, CelestialBody moon,
                                    Orbit leoOrbit, double simTime) {
    // 计算转移轨道参数
    double r_leo = EARTH_RADIUS_KM + 400;
    double r_moon = moon.a;
    double a_trans = (r_leo + r_moon) / 2;
    double transferTime = PI * Math.sqrt(a_trans * a_trans * a_trans / GM_EARTH);

    // 计算TLI的Δv
    double v1 = Math.sqrt(GM_EARTH / r_leo);
    double v_trans_peri = Math.sqrt(GM_EARTH * (2 / r_leo - 1 / a_trans));
    double dv_tli = v_trans_peri - v1;

    // 计算角速度
    double n_leo = TWO_PI / leoOrbit.period;  // LEO角速度 (rad/s)
    double n_moon = TWO_PI / moon.period;     // 月球角速度 (rad/s)

    // 计算当前时刻的角度
    double shipAngle0 = getSpacecraftAngleAtTime(leoOrbit, simTime);
    double moonAngle0 = getMoonAngleAtTime(moon, simTime);

    // 解析求解 t_wait
    // 方程：shipAngle0 + n_leo*t_wait + PI = moonAngle0 + n_moon*(t_wait + transferTime) + k*2π
    // 整理：t_wait = [moonAngle0 - shipAngle0 - PI + n_moon*transferTime + k*2π] / (n_leo - n_moon)
    // 我们搜索 k 的多个值，找到误差最小的解

    double baseAngleDiff = moonAngle0 - shipAngle0 - PI;
    double denominator = n_leo - n_moon;

    // 窗口周期是 LEO 周期 —— 每圈我们都有一次窗口机会
    double windowPeriod = leoOrbit.period;

    // 搜索 k 在合理范围内，找到误差最小的解
    double bestWait = 1e10;
    double bestError = 1e10;
    double bestTburn = 0, bestTarrival = 0, bestTargetAngle = 0, bestMoonAngle = 0;
    int bestK = 0;

    for (int k = -20; k <= 20; k++) { // 搜索足够宽的范围
      double angleDiff = baseAngleDiff + k * TWO_PI;
      double numerator = angleDiff + n_moon * transferTime;
      double t_wait_candidate = numerator / denominator;

      // 调整到 [0, windowPeriod) 范围
      double t_wait = t_wait_candidate;
      while (t_wait < 0) t_wait += windowPeriod;
      while (t_wait >= windowPeriod) t_wait -= windowPeriod;

      // 保证至少有10秒准备时间
      if (t_wait < 10) t_wait += windowPeriod;

      // 验证这个候选解的误差
      double t_burn = simTime + t_wait;
      double t_arrival = t_burn + transferTime;

      // ============ 正确方法：直接模拟转移轨道 ============
      // 1. 计算t_burn时刻飞船的状态
      Vector2 pos_burn = leoOrbit.getPositionAtTime(t_burn);
      Vector2 vel_burn = leoOrbit.getVelocityAtTime(t_burn);

      // 2. 计算prograde方向的单位向量
      Vector2 prograde = vel_burn.normalized();

      // 3. 计算TLI后的速度
      Vector2 vel_after = vel_burn.add(prograde.mul(dv_tli));

      // 4. 解析计算转移轨道
      Orbit transferOrbit = Orbit_fromStateVector(pos_burn, vel_after, earth, t_burn);

      // 5. 解析计算t_arrival时刻飞船的位置（远地点）
      Vector2 pos_arrival = transferOrbit.getPositionAtTime(t_arrival);
      double targetAngle = Math.atan2(pos_arrival.y, pos_arrival.x);

      // 6. 计算月球在t_arrival时刻的角度
      double moonAngle = getMoonAngleAtTime(moon, t_arrival);

      // 7. 计算误差
      double delta = normalizeAngle(moonAngle - targetAngle);
      double error = Math.min(delta, TWO_PI - delta);

      if (error < bestError) {
        bestError = error;
        bestWait = t_wait;
        bestTburn = t_burn;
        bestTarrival = t_arrival;
        bestTargetAngle = targetAngle;
        bestMoonAngle = moonAngle;
        bestK = k;
      }
    }

    return bestWait;
  }

  // ========== 规划月球轨道捕获（LOI）机动 ==========
  List<ManeuverNode> planLunarMission(CelestialBody earth, CelestialBody moon,
                                       Orbit leoOrbit, double simTime, double t_wait) {
    List<ManeuverNode> maneuvers = new ArrayList<ManeuverNode>();

    // --- TLI机动 ---
    double r_leo = EARTH_RADIUS_KM + 400;
    double r_moon = moon.a;
    double a_trans = (r_leo + r_moon) / 2;
    double transferTime = PI * Math.sqrt(a_trans * a_trans * a_trans / GM_EARTH);

    double v1 = Math.sqrt(GM_EARTH / r_leo);
    double v_trans_peri = Math.sqrt(GM_EARTH * (2 / r_leo - 1 / a_trans));
    double dv_tli = v_trans_peri - v1;

    ManeuverNode tli = new ManeuverNode(t_wait, new Vector2(dv_tli, 0));
    tli.description = "Trans-Lunar Injection";
    tli.direction = "prograde";
    tli.deltaVMagnitude = dv_tli;
    maneuvers.add(tli);

    // --- LOI机动（预计在转移时间后执行） ---
    // 注意：这是基于地球参考系的预估，进入月球SOI后需要重新计算
    // 这里先预留一个位置，LOI的具体参数会在SOI切换时重新规划
    double t_loi_est = t_wait + transferTime;

    // 简化计算LOI的Δv（实际在月球参考系中计算更准确）
    double r_moon_soi = calculateSOIRadius(moon, earth);
    double v_approach_est = Math.sqrt(GM_EARTH * (2 / r_moon - 1 / a_trans));  // 相对于地球
    // 这是一个近似值，仅用于Δv预估
    double dv_loi_est = 0.6;  // km/s，经验近似值

    ManeuverNode loi = new ManeuverNode(t_loi_est, new Vector2(-dv_loi_est, 0));
    loi.description = "Lunar Orbit Insertion";
    loi.direction = "retrograde";
    loi.deltaVMagnitude = dv_loi_est;
    maneuvers.add(loi);

    return maneuvers;
  }

  // 辅助：计算SOI半径
  private double calculateSOIRadius(CelestialBody body, CelestialBody primary) {
    double massRatio = body.GM / primary.GM;
    return body.a * Math.pow(massRatio, 2.0/5.0);
  }
}
