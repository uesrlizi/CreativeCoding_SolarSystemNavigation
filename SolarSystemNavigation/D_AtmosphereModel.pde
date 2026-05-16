// ============================================================
//  AtmosphereModel — density, drag, and atmosphere boundaries
//  Based on real-world atmospheric profiles (simplified)
// ============================================================

class AtmosphereModel {
  // Atmosphere cutoff heights (km above surface)
  final double EARTH_ATMOSPHERE_HEIGHT = 140.0;
  final double MARS_ATMOSPHERE_HEIGHT   = 80.0;
  final double VENUS_ATMOSPHERE_HEIGHT  = 250.0;

  // Sea-level density (kg/km^3) = kg/m^3 * 1e9
  final double EARTH_RHO0 = 1.225e9;
  final double MARS_RHO0  = 0.020e9;
  final double VENUS_RHO0 = 65.0e9;

  // Scale heights (km)
  final double EARTH_SCALE_HEIGHT = 8.5;
  final double MARS_SCALE_HEIGHT  = 11.1;
  final double VENUS_SCALE_HEIGHT = 15.9;

  // Drag coefficient (dimensionless, ~0.5 for a rocket)
  final double CD = 0.5;

  // Spacecraft properties (km units)
  final double SHIP_DIAMETER_KM = 0.006;
  final double SHIP_CROSS_SECTION_KM2 = Math.PI * (SHIP_DIAMETER_KM/2.0) * (SHIP_DIAMETER_KM/2.0);
  final double SHIP_MASS_KG = 500000.0; // ~500t Falcon 9 class

  // ====================================================================
  //  Get atmosphere height for a specific body
  // ====================================================================

  double atmosphereHeight(CelestialBody body) {
    if (body == null) return 0;
    if (body.name.equals("Earth")) return EARTH_ATMOSPHERE_HEIGHT;
    if (body.name.equals("Mars"))  return MARS_ATMOSPHERE_HEIGHT;
    if (body.name.equals("Venus")) return VENUS_ATMOSPHERE_HEIGHT;
    return 0; // other planets have no atmosphere in this model
  }

  // ====================================================================
  //  Density at given altitude (exponential model, kg/km^3)
  // ====================================================================

  double density(CelestialBody body, double altitudeKm) {
    if (body == null) return 0;

    double rho0, scaleHeight;
    if (body.name.equals("Earth")) {
      rho0 = EARTH_RHO0;
      scaleHeight = EARTH_SCALE_HEIGHT;
    } else if (body.name.equals("Mars")) {
      rho0 = MARS_RHO0;
      scaleHeight = MARS_SCALE_HEIGHT;
    } else if (body.name.equals("Venus")) {
      rho0 = VENUS_RHO0;
      scaleHeight = VENUS_SCALE_HEIGHT;
    } else {
      return 0;
    }

    if (altitudeKm < 0) altitudeKm = 0; // don't go negative (below surface)
    return rho0 * Math.exp(-altitudeKm / scaleHeight);
  }

  // ====================================================================
  //  Drag acceleration (km/s^2) from atmosphere
  //  F_drag = 0.5 * Cd * A * rho * v^2
  //  a_drag = F_drag / mass
  // ====================================================================

  void dragAcceleration(double[] relPos, double[] relVel,
      CelestialBody body, double[] accelOut) {
    double alt = altitudeAboveSurface(relPos, body);
    if (alt >= atmosphereHeight(body)) {
      accelOut[0] = 0;
      accelOut[1] = 0;
      return;
    }

    double vx = relVel[0], vy = relVel[1];
    double v = Math.sqrt(vx * vx + vy * vy);
    if (v < 0.001) {
      accelOut[0] = 0;
      accelOut[1] = 0;
      return;
    }

    double rho = density(body, alt);
    double dragMagnitude = 0.5 * CD * SHIP_CROSS_SECTION_KM2 * rho * v * v;
    dragMagnitude /= SHIP_MASS_KG; // convert force to acceleration

    // Drag opposes velocity
    accelOut[0] = -dragMagnitude * (vx / v);
    accelOut[1] = -dragMagnitude * (vy / v);
  }

  // ====================================================================
  //  Altitude above a planet's surface (km)
  // ====================================================================

  double altitudeAboveSurface(double[] relPos, CelestialBody body) {
    double r = Math.sqrt(relPos[0] * relPos[0] + relPos[1] * relPos[1]);
    return r - body.radius;
  }

  // ====================================================================
  //  Is this altitude inside the atmosphere?
  // ====================================================================

  boolean inAtmosphere(CelestialBody body, double altitudeKm) {
    return altitudeKm < atmosphereHeight(body);
  }
}
