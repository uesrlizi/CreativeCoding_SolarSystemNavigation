// ========== MANEUVER NODES ==========

class ManeuverNode {
  double time;              // 燃烧中点时刻（相对于任务开始的秒数，或绝对simTime）
  Vector2 deltaV;           // Δv矢量（km/s）
  Orbit orbitAfter;         // 机动后的轨道（预测）

  String direction;         // 机动方向："prograde", "retrograde", "radial_out", "radial_in", "deltaV"
  String description;       // 描述
  double deltaVMagnitude;   // Δv大小（km/s）
  double burnDuration;      // 预计点火时长（秒）
  double ignitionTime;      // 实际点火时刻 = time - burnDuration/2
  boolean isAbsoluteTime;   // time字段是否是绝对simTime
  boolean useDeltaVDirection; // 是否按ΔV矢量方向定向

  ManeuverNode(double t, Vector2 dv) {
    this.time = t;
    this.deltaV = dv.clone();
    this.orbitAfter = null;
    this.direction = "prograde";  // 默认先切向，确保稳定
    this.description = "";
    this.deltaVMagnitude = dv.magnitude();
    this.burnDuration = 0;
    this.ignitionTime = t;
    this.isAbsoluteTime = false;
    this.useDeltaVDirection = false;  // 暂时禁用，先确保方向正确
  }

  void calculateBurnDuration(Spacecraft craft) {
    if (craft == null || craft.mainEngine == null) {
      this.burnDuration = 0;
      this.ignitionTime = this.time;
      return;
    }

    double dv = this.deltaVMagnitude;
    if (dv <= 0) dv = this.deltaV.magnitude();

    double accel = craft.mainEngine.getAcceleration(craft.getCurrentMass(), 1.0f);

    if (accel > 0) {
      this.burnDuration = dv / accel;
    } else {
      this.burnDuration = 0;
    }

    // 计算实际点火时刻 = 燃烧中点 - 燃烧时长/2
    this.ignitionTime = this.time - this.burnDuration / 2.0;
  }

  void predictOrbitAfter(Orbit currentOrbit, Vector2 position, Vector2 velocity, double simTime) {
    if (currentOrbit == null) return;

    Vector2 newVelocity = velocity.add(deltaV);
    this.orbitAfter = Orbit_fromStateVector(position, newVelocity, currentOrbit.referenceBody, simTime);
  }
}

class ManeuverPlanner {
  List<ManeuverNode> nodes;

  ManeuverPlanner() {
    this.nodes = new ArrayList<ManeuverNode>();
  }

  void addNode(ManeuverNode node) {
    this.nodes.add(node);
  }

  void removeNode(ManeuverNode node) {
    this.nodes.remove(node);
  }

  double getTotalDeltaV() {
    double total = 0;
    for (ManeuverNode n : nodes) {
      if (n.deltaVMagnitude > 0) {
        total += n.deltaVMagnitude;
      } else {
        total += n.deltaV.magnitude();
      }
    }
    return total;
  }
}
