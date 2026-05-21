// ========== ATMOSPHERE CLASS ==========

class Atmosphere {
  boolean hasAtmosphere;
  double scaleHeight;
  double seaLevelPressure;
  double seaLevelDensity;
  double maxAltitude;
  double seaLevelTemperature; // 海平面温度（开尔文）
  double temperatureLapseRate; // 温度递减率（K/km）
  color atmosphereColor;

  Atmosphere() {
    this.hasAtmosphere = false;
    this.scaleHeight = 8.5;
    this.seaLevelPressure = 101325;
    this.seaLevelDensity = 1.225;
    this.maxAltitude = 120; // 提高到120km以支持再入
    this.seaLevelTemperature = 288.15; // 15摄氏度
    this.temperatureLapseRate = 6.5; // 6.5K/km
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

  // 获取指定高度的温度（简化的标准大气模型）
  double getTemperature(double altitude) {
    if (!hasAtmosphere) return seaLevelTemperature;
    double alt = Math.min(Math.max(altitude, 0), maxAltitude);

    // 简化模型：对流层温度线性下降，平流层恒温
    if (alt < 11.0) {
      return seaLevelTemperature - temperatureLapseRate * alt;
    } else if (alt < 47.0) {
      return 216.65; // 平流层底部恒温
    } else if (alt < 51.0) {
      return 216.65;
    } else {
      return 216.65 + 2.8 * (alt - 51.0);
    }
  }

  // 获取指定高度的声速（基于理想气体公式）
  double getSpeedOfSound(double altitude) {
    double temp = getTemperature(altitude);
    double gamma = 1.4; // 空气的绝热指数
    double R = 287.0; // 空气的气体常数
    return Math.sqrt(gamma * R * temp) / 1000.0; // 转换为 km/s
  }

  // 计算马赫数（速度单位 km/s）
  double getMachNumber(double speed, double altitude) {
    double sos = getSpeedOfSound(altitude);
    if (sos <= 0) return 0;
    return speed / sos;
  }

  // 计算动压（帕斯卡），速度单位 km/s
  double getDynamicPressure(double speed, double altitude) {
    double density = getDensityAtAltitude(altitude);
    double speedMeters = speed * 1000.0; // 转换为 m/s
    return 0.5 * density * speedMeters * speedMeters;
  }
}
