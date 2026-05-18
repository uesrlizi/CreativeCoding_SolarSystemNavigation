// ========== ATMOSPHERE CLASS ==========

class Atmosphere {
  boolean hasAtmosphere;
  double scaleHeight;
  double seaLevelPressure;
  double seaLevelDensity;
  double maxAltitude;
  color atmosphereColor;

  Atmosphere() {
    this.hasAtmosphere = false;
    this.scaleHeight = 8.5;
    this.seaLevelPressure = 101325;
    this.seaLevelDensity = 1.225;
    this.maxAltitude = 100;
    this.atmosphereColor = color(135, 206, 235, 100);
  }

  double getPressureAtAltitude(double altitude) {
    if (!hasAtmosphere) return 0;
    if (altitude > maxAltitude) return 0;
    return seaLevelPressure * Math.exp(-altitude / scaleHeight);
  }

  double getDensityAtAltitude(double altitude) {
    if (!hasAtmosphere) return 0;
    if (altitude > maxAltitude) return 0;
    return seaLevelDensity * Math.exp(-altitude / scaleHeight);
  }

  double calculateDrag(double altitude, double speed, double dragCoefficient, double crossSectionalArea) {
    double density = getDensityAtAltitude(altitude);
    return 0.5 * density * speed * speed * dragCoefficient * crossSectionalArea;
  }
}
