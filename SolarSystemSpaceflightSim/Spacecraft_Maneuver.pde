// ========== MANEUVER NODES (PLACEHOLDER) ==========

class ManeuverNode {
  double time;           // 执行时刻（simTime）
  Vector2 deltaV;        // Δv矢量
  Orbit orbitAfter;      // 机动后的轨道（预测）

  ManeuverNode(double t, Vector2 dv) {
    this.time = t;
    this.deltaV = dv.clone();
    this.orbitAfter = null;
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
      total += n.deltaV.magnitude();
    }
    return total;
  }
}
