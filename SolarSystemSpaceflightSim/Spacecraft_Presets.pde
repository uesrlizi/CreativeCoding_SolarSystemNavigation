// ========== SPACECRAFT PRESETS ==========

class SpacecraftPreset {
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
    Spacecraft craft = new Spacecraft(name, shipColor);
    craft.presetId = this.id;
    craft.dryMass = this.dryMass;
    craft.dragCoefficient = this.dragCoefficient;
    craft.crossSectionArea = this.crossSectionArea;
    craft.mainEngine = new SimpleEngine(this.engineThrust, 0.5);  // 引擎干质量0.5吨
    return craft;
  }
}

// ========== PRESET DATABASE ==========

static final String PRESET_LEO_SATELLITE = "leo_satellite";
static final String PRESET_LUNAR_TRANSFER = "lunar_transfer";

private List<SpacecraftPreset> spacecraftPresets;

void initSpacecraftPresets() {
  spacecraftPresets = new ArrayList<SpacecraftPreset>();

  // LEO 卫星预设
  spacecraftPresets.add(new SpacecraftPreset(
    PRESET_LEO_SATELLITE,
    "LEO Probe",
    "A simple satellite for low Earth orbit operations",
    2.0,          // 2吨干质量
    62.5,         // 62.5kN推力 → 25 m/s² with 2.5 tons
    0.5,          // 阻力系数
    4.0,          // 4m²横截面积
    0xFF00FF96    // 不调用 color() 函数，直接写 AARRGGBB
  ));

  // 月球转移飞行器预设
  spacecraftPresets.add(new SpacecraftPreset(
    PRESET_LUNAR_TRANSFER,
    "Lunar Transfer Vehicle",
    "A spacecraft capable of transferring from Earth to Moon",
    8.0,          // 8吨干质量
    212.5,        // 212.5kN推力 → 25 m/s² with 8.5 tons
    0.6,          // 阻力系数
    10.0,         // 10m²横截面积
    0xFFFFB432    // 不调用 color() 函数，直接写 AARRGGBB
  ));
}

List<SpacecraftPreset> getAllSpacecraftPresets() {
  if (spacecraftPresets == null) initSpacecraftPresets();
  return spacecraftPresets;
}

SpacecraftPreset getSpacecraftPreset(String id) {
  if (spacecraftPresets == null) initSpacecraftPresets();
  for (SpacecraftPreset p : spacecraftPresets) {
    if (p.id.equals(id)) return p;
  }
  return null;
}

Spacecraft createSpacecraftFromPreset(String presetId) {
  SpacecraftPreset preset = getSpacecraftPreset(presetId);
  if (preset != null) {
    return preset.createSpacecraft();
  }
  return null;
}
