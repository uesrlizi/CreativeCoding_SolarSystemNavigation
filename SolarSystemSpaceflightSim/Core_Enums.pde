// ========== ENUMERATIONS ==========

enum ViewMode {
  MAP_VIEW,
  SHIP_VIEW
}

enum BodyType {
  SUN,
  TERRESTRIAL,
  GAS_GIANT,
  ICE_GIANT
}

enum PhysicsMode {
  ON_RAILS,
  OFF_RAILS
}

enum GameState {
  MAIN_MENU,
  FLIGHT,
  MAP_VIEW,
  BUILD,
  PAUSED
}

enum SpacecraftState {
  ACTIVE,
  LANDED,
  SPLASHED,
  DOCKED,
  DESTROYED
}

enum MissionState {
  PENDING,
  IN_PROGRESS,
  COMPLETED,
  FAILED
}
