// ========== SPACECRAFT PRESETS ==========

static class SpacecraftPreset {
  String id;
  String name;
  String description;

  double dryMass;           // 干质量（吨）
  double engineThrust;      // 推力（kN）
  double dragCoefficient;   // 阻力系数
  double crossSectionArea;  // 横截面积（m²）
  color shipColor;

  SpacecraftPreset(String id, String name, String description,
                   double dryMass, double engineThrust,
                   double dragCoefficient, double crossSectionArea,
                   color shipColor) {
    this.id = id;
    this.name = name;
    this.description = description;
    this.dryMass = dryMass;
    this.engineThrust = engineThrust;
    this.dragCoefficient = dragCoefficient;
    this.crossSectionArea = crossSectionArea;
    this.shipColor = shipColor;
  }

  Spacecraft createSpacecraft() {
    return new Spacecraft(name, shipColor);
  }
}

static class SpacecraftPresets {
  static final String PRESET_LEO_SATELLITE = "leo_satellite";
  static final String PRESET_LUNAR_TRANSFER = "lunar_transfer";

  private static List<SpacecraftPreset> presets;

  static {
    presets = new ArrayList<SpacecraftPreset>();

    // LEO 卫星预设
    presets.add(new SpacecraftPreset(
      PRESET_LEO_SATELLITE,
      "LEO Probe",
      "A simple satellite for low Earth orbit operations",
      2.0,          // 2吨干质量
      5.0,          // 5kN推力
      0.5,          // 阻力系数
      4.0,          // 4m²横截面积
      0xFF00FF96    // 不调用 color() 函数，直接写 AARRGGBB: 0xFF(alpha) + 00(red) + FF(green) + 96(blue)
    ));

    // 月球转移飞行器预设
    presets.add(new SpacecraftPreset(
      PRESET_LUNAR_TRANSFER,
      "Lunar Transfer Vehicle",
      "A spacecraft capable of transferring from Earth to Moon",
      8.0,          // 8吨干质量
      25.0,         // 25kN推力
      0.6,          // 阻力系数
      10.0,         // 10m²横截面积
      0xFFFFB432    // 不调用 color() 函数，直接写 AARRGGBB
    ));
  }

  static List<SpacecraftPreset> getAllPresets() {
    return presets;
  }

  static SpacecraftPreset getPreset(String id) {
    for (SpacecraftPreset p : presets) {
      if (p.id.equals(id)) return p;
    }
    return null;
  }

  static Spacecraft createSpacecraft(String presetId) {
    SpacecraftPreset preset = getPreset(presetId);
    if (preset != null) {
      return preset.createSpacecraft();
    }
    return null;
  }
}
