enum ViewMode {
  MAP_VIEW,
  SHIP_VIEW
}

enum FrameType {
  SURFACE,      // on the surface, coordinates relative to ground
  BODY_ORBIT,   // in orbit around a body, coordinates relative to body
  HELIOCENTRIC  // in orbit around the sun, coordinates are absolute
}

enum ShipState {
  IDLE,
  COUNTDOWN,
  IGNITION,
  LAUNCHING,
  CIRCULARIZING,
  ORBIT,
  WAITING_FOR_WINDOW,
  TMI_BURN,
  TRANSFER,
  APPROACHING_TARGET,
  TOI_BURN,
  CAPTURED
}

enum SOIEventType {
  ENTER_SOI,    // 进入天体SOI
  EXIT_SOI,     // 离开天体SOI
  SWITCH_SOI    // 从一个SOI切换到另一个
}
