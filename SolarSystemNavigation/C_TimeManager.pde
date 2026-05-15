// ============================================================
//  Time Manager
// ============================================================
class TimeManager {
  double simTime;
  double timeWarp;
  double[] WARP_LEVELS;
  String[] WARP_LABELS;
  int warpIndex = 0;

  int maxWarpIndex = 7;  // 档位上限，7=100days（无限制）
  int minWarpIndex = 0;  // 档位下限，0=1x

  TimeManager() {
    simTime = 0;
    WARP_LEVELS = new double[8];
    WARP_LEVELS[0] = 1.0 / 86400.0;       // 1:1 real time
    WARP_LEVELS[1] = 20.0 / 86400.0;      // 20 sim sec per real sec
    WARP_LEVELS[2] = 60.0 / 86400.0;      // 1 sim min per real sec
    WARP_LEVELS[3] = 600.0 / 86400.0;     // 10 sim min per real sec
    WARP_LEVELS[4] = 3600.0 / 86400.0;    // 1 sim hour per real sec
    WARP_LEVELS[5] = 1.0;                 // 1 sim day per real sec
    WARP_LEVELS[6] = 10.0;                // 10 sim days per real sec
    WARP_LEVELS[7] = 100.0;               // 100 sim days per real sec

    WARP_LABELS = new String[8];
    WARP_LABELS[0] = "1:1 Real Time";
    WARP_LABELS[1] = "20 sec/sec";
    WARP_LABELS[2] = "1 min/sec";
    WARP_LABELS[3] = "10 min/sec";
    WARP_LABELS[4] = "1 hour/sec";
    WARP_LABELS[5] = "1 day/sec";
    WARP_LABELS[6] = "10 days/sec";
    WARP_LABELS[7] = "100 days/sec";

    timeWarp = WARP_LEVELS[warpIndex];
  }

  void update(float dt) {
    simTime += timeWarp * DAY_S * dt;
  }

  void togglePause() {
    if (timeWarp > 0) {
      timeWarp = 0;
    } else {
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  void increaseWarp() {
    int newIndex = min(maxWarpIndex, warpIndex + 1);  // 不超过上限
    newIndex = min(WARP_LEVELS.length - 1, newIndex);
    if (newIndex != warpIndex) {
      warpIndex = newIndex;
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  void decreaseWarp() {
    int newIndex = max(minWarpIndex, warpIndex - 1);  // 不低于下限
    newIndex = max(0, newIndex);
    if (newIndex != warpIndex) {
      warpIndex = newIndex;
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  // 设置档位上限
  void setMaxWarpIndex(int index) {
    maxWarpIndex = constrain(index, 0, WARP_LEVELS.length - 1);
    // 如果当前档位超过上限，强制降到上限
    if (warpIndex > maxWarpIndex) {
      warpIndex = maxWarpIndex;
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  // 清除档位上限
  void clearMaxWarp() {
    maxWarpIndex = WARP_LEVELS.length - 1;
  }

  // 强制设置档位（不受上限限制）
  void forceSetWarpIndex(int index) {
    warpIndex = constrain(index, 0, WARP_LEVELS.length - 1);
    timeWarp = WARP_LEVELS[warpIndex];
  }

  String formatWarp(double w, String[] WARP_LABELS, int warpIndex) {
    if (w == 0) return "Paused";
    if (warpIndex >= 0 && warpIndex < WARP_LABELS.length) {
      return WARP_LABELS[warpIndex];
    }
    return String.format("%.0f x", w);
  }
}
