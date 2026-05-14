class MissionPlanner {
  static final double GM_EARTH = 3.986004e5;
  static final double EARTH_RADIUS_KM = 6371.0;
  static final double LEO_ALTITUDE_KM = 420.0;
  static final double LEO_RADIUS_KM = EARTH_RADIUS_KM + LEO_ALTITUDE_KM;

  double[] calculateHohmannTransfer(double r1_km, double r2_km) {
    double a_transfer = (r1_km + r2_km) / 2.0;
    double e_transfer = Math.abs(r2_km - r1_km) / (r2_km + r1_km);
    return new double[]{a_transfer, e_transfer};
  }

  double calculateTransferTime(double a_km, double GM) {
    return PI * Math.sqrt(Math.pow(a_km, 3) / GM);
  }

  double calculateDeltaV(double r1_km, double r2_km, double GM) {
    double v1 = Math.sqrt(GM / r1_km);
    double v2_transfer = Math.sqrt(GM * (2.0 / r1_km - 1.0 / ((r1_km + r2_km) / 2.0)));
    double v2_insert = Math.sqrt(GM / r2_km);
    return Math.abs(v2_transfer - v1) + Math.abs(v2_insert - v2_transfer);
  }

  double calculateLaunchVelocity(double altitude_km) {
    double r = EARTH_RADIUS_KM + altitude_km;
    return Math.sqrt(GM_EARTH / r);
  }

  double getLEORadius() {
    return LEO_RADIUS_KM;
  }
}
