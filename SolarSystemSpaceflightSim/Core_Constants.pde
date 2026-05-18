// ========== PHYSICAL CONSTANTS ==========

static final double AU_KM       = 1.496e8;
static final double GM_SUN      = 1.327124e11;
static final double DAY_S       = 86400.0;

// ========== Mission & Orbit Constants ==========
static final double GM_EARTH        = 3.986004e5;
static final double EARTH_RADIUS_KM = 6371.0;
static final double LEO_ALTITUDE_KM = 420.0;
static final double LEO_RADIUS_KM   = EARTH_RADIUS_KM + LEO_ALTITUDE_KM;

// ========== HELPER FUNCTIONS ==========

static String formatSimTime(double simSeconds) {
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

static double constrainDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
