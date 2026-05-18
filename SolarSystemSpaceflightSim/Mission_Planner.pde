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

  double calculateLunarTransferWindow(CelestialBody earth, CelestialBody moon, double simTime) {
    double T_moon = moon.period;

    double r_earth = EARTH_RADIUS_KM + 400;
    double r_moon = moon.a;
    double a_trans = (r_earth + r_moon) / 2;
    double T_trans = 2 * PI * Math.sqrt(a_trans * a_trans * a_trans / GM_EARTH);
    double transferTime = T_trans / 2;

    double phaseAngle = PI * (1 - T_trans / T_moon);

    double moonNu = getMoonTrueAnomaly(moon, simTime);
    double angleToWait = phaseAngle - moonNu;
    while (angleToWait < 0) angleToWait += TWO_PI;
    while (angleToWait > TWO_PI) angleToWait -= TWO_PI;

    double waitTime = angleToWait * T_moon / TWO_PI;

    return waitTime;
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
}
