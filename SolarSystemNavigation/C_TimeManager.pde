// ============================================================
//  Time Manager
// ============================================================
class TimeManager {
  double simTime;
  double timeWarp;
  double[] WARP_LEVELS;
  String[] WARP_LABELS;
  int warpIndex = 5;

  TimeManager() {
    simTime = 0;
    WARP_LEVELS = new double[9];
    WARP_LEVELS[0] = 1.0 / 86400.0;       // 1:1 real time
    WARP_LEVELS[1] = 20.0 / 86400.0;      // 20 sim sec per real sec
    WARP_LEVELS[2] = 60.0 / 86400.0;      // 1 sim min per real sec
    WARP_LEVELS[3] = 600.0 / 86400.0;     // 10 sim min per real sec
    WARP_LEVELS[4] = 3600.0 / 86400.0;    // 1 sim hour per real sec
    WARP_LEVELS[5] = 1.0;                 // 1 sim day per real sec
    WARP_LEVELS[6] = 10.0;                // 10 sim days per real sec
    WARP_LEVELS[7] = 100.0;               // 100 sim days per real sec
    WARP_LEVELS[8] = 1000.0;              // 1000 sim days per real sec

    WARP_LABELS = new String[9];
    WARP_LABELS[0] = "1:1 Real Time";
    WARP_LABELS[1] = "20 sec/sec";
    WARP_LABELS[2] = "1 min/sec";
    WARP_LABELS[3] = "10 min/sec";
    WARP_LABELS[4] = "1 hour/sec";
    WARP_LABELS[5] = "1 day/sec";
    WARP_LABELS[6] = "10 days/sec";
    WARP_LABELS[7] = "100 days/sec";
    WARP_LABELS[8] = "1000 days/sec";

    timeWarp = WARP_LEVELS[warpIndex];
  }

  void update() {
    double dt = (timeWarp * DAY_S) / 60.0;
    simTime += dt;
  }

  void togglePause() {
    if (timeWarp > 0) {
      timeWarp = 0;
    } else {
      timeWarp = WARP_LEVELS[warpIndex];
    }
  }

  void increaseWarp() {
    warpIndex = min(WARP_LEVELS.length - 1, warpIndex + 1);
    timeWarp = WARP_LEVELS[warpIndex];
  }

  void decreaseWarp() {
    warpIndex = max(0, warpIndex - 1);
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
