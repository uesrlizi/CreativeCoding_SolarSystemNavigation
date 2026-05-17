// ============================================================
//  FlightSystem - 飞行系统
//  存储发射状态，处理推力命令，协调物理系统更新
// ============================================================

class FlightSystem {
  // 发射状态 - 由 FlightSystem 统一管理
  private boolean isFixed;

  // 推力命令（来自制导系统）
  private boolean thrustCommandActive;
  private double thrustCommandDirection;

  // 子系统引用
  private PhysicsSystem physicsSystem;

  FlightSystem() {
    isFixed = true;  // 初始固定在发射台
    thrustCommandActive = false;
    thrustCommandDirection = 0.0;
    physicsSystem = new PhysicsSystem();
  }

  // ============================================================
  //  发射状态控制
  // ============================================================

  void setFixed(boolean fixed) {
    isFixed = fixed;
  }

  boolean isFixed() {
    return isFixed;
  }

  // ============================================================
  //  推力命令（供制导系统调用）
  // ============================================================

  void setThrustCommand(boolean active, double direction) {
    thrustCommandActive = active;
    thrustCommandDirection = direction;
  }

  // ============================================================
  //  主更新入口
  // ============================================================

  void update(Spacecraft ship, double simDt, double simTime) {
    // 将推力命令保存到飞船状态
    ship.thrustActive = thrustCommandActive;
    ship.thrustDirection = thrustCommandDirection;

    // 同步发射状态到飞船
    ship.isFixed = isFixed;

    // 调用物理系统进行运动更新
    physicsSystem.update(ship, simDt, simTime, thrustCommandActive, thrustCommandDirection);
  }
}
