// ========== TIME MANAGER ==========

class TimeManager {
  double simTime;
  double timeWarp;
  double[] WARP_LEVELS;
  String[] WARP_LABELS;
  int warpIndex = 0;

  int maxWarpIndex = 7;
  int minWarpIndex = 0;

  TimeManager() {
    simTime = 0;
    WARP_LEVELS = new double[8];
    WARP_LEVELS[0] = 1.0 / 86400.0;
    WARP_LEVELS[1] = 20.0 / 86400.0;
    WARP_LEVELS[2] = 60.0 / 86400.0;
    WARP_LEVELS[3] = 600.0 / 86400.0;
    WARP_LEVELS[4] = 3600.0 / 86400.0;
    WARP_LEVELS[5] = 1.0;
    WARP_LEVELS[6] = 10.0;
    WARP_LEVELS[7] = 100.0;

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
    int newIndex = min(maxWarpIndex, warpIndex + 1);
    newIndex = min(WARP_LEVELS.length - 1, newIndex);
    if (newIndex != warpIndex) {
      warpIndex = newIndex;
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  void decreaseWarp() {
    int newIndex = max(minWarpIndex, warpIndex - 1);
    newIndex = max(0, newIndex);
    if (newIndex != warpIndex) {
      warpIndex = newIndex;
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  void setMaxWarpIndex(int index) {
    maxWarpIndex = constrain(index, 0, WARP_LEVELS.length - 1);
    if (warpIndex > maxWarpIndex) {
      warpIndex = maxWarpIndex;
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  void clearMaxWarp() {
    maxWarpIndex = WARP_LEVELS.length - 1;
  }

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
