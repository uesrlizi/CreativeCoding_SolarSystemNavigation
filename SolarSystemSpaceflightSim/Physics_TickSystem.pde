// ============================================================
//  PHYSICS TICK SYSTEM - 物理 tick 调度器
//  功能：将大时间步长切分为固定步长的 tick 循环
// ============================================================

// Tick 回调接口
interface PhysicsTickCallback {
  void onTick(Spacecraft ship, double tickDt, double currentSimTime);
}

// Tick 执行结果
class PhysicsTickResult {
  int numTicks;           // 执行的完整 tick 数量
  double remainingDt;     // 剩余未执行的时间 (< PHYSICS_TICK)
  double finalSimTime;    // 最终的模拟时间

  PhysicsTickResult(int ticks, double remaining, double finalTime) {
    this.numTicks = ticks;
    this.remainingDt = remaining;
    this.finalSimTime = finalTime;
  }
}

class PhysicsTickSystem {
  // 物理 tick 步长 - 平衡精度与性能
  static final double PHYSICS_TICK = 0.5;  // 0.5 秒

  // 最小 tick 步长 (防止极端情况)
  static final double MIN_TICK = 0.001;

  PhysicsTickSystem() {
  }

  // ============================================================
  //  执行 tick 循环
  // ============================================================
  PhysicsTickResult executeTicks(Spacecraft ship, double simDt,
                                  double startSimTime,
                                  PhysicsTickCallback callback) {
    if (simDt <= 0) {
      return new PhysicsTickResult(0, 0, startSimTime);
    }

    double currentSimTime = startSimTime;
    double remainingTime = simDt;
    int numTicks = 0;

    // 执行完整的 tick
    while (remainingTime >= PHYSICS_TICK - 1e-9) {
      double tickDt = PHYSICS_TICK;
      currentSimTime += tickDt;
      remainingTime -= tickDt;

      // 执行回调
      if (callback != null) {
        callback.onTick(ship, tickDt, currentSimTime);
      }

      numTicks++;
    }

    // 处理剩余的小片段 (如果需要高精度，可以选择执行或累积到下一帧)
    // 当前策略：如果剩余时间 > MIN_TICK，也作为一个 tick 执行
    if (remainingTime > MIN_TICK) {
      if (callback != null) {
        callback.onTick(ship, remainingTime, currentSimTime + remainingTime);
      }
      currentSimTime += remainingTime;
      remainingTime = 0;
    }

    return new PhysicsTickResult(numTicks, remainingTime, currentSimTime);
  }

  // ============================================================
  //  获取推荐的最高 warp 级别
  // ============================================================
  int getRecommendedMaxWarpIndex(TimeManager timeManager) {
    // 在 tick 模式下，仍然可以使用较高 warp
    // 因为物理精度由 tick 保证，不由帧步长保证
    return Math.min(4, timeManager.WARP_LEVELS.length - 1);  // warp 4 = 1小时/秒
  }
}
