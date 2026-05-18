// ========== PHYSICAL CONSTANTS ==========

static final double AU_KM       = 1.496e8;
static final double GM_SUN      = 1.327124e11;
static final double DAY_S       = 86400.0;

// ========== HELPER FUNCTIONS ==========

String formatSimTime(double simSeconds) {
  if (simSeconds < 60.0) {
    return String.format("%.1f s", simSeconds);
  } else if (simSeconds < 60.0 * 60.0) {
    return String.format("%.1f min", simSeconds / 60.0);
  } else if (simSeconds < 24.0 * 60.0 * 60.0) {
    return String.format("%.1f h", simSeconds / (60.0 * 60.0));
  } else {
    return String.format("%.1f days", simSeconds / DAY_S);
  }
}

double constrainDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
