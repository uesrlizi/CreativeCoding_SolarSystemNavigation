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

enum MissionGoalType {
  REACH_ORBIT,        // 进入指定轨道
  TRANSFER_TO_BODY,   // 转移到另一个天体的SOI
  ORBIT_INSERTION,    // 在目标天体插入轨道
  LAND,               // 着陆
  CRASH,              // 撞毁（娱乐任务）
  LAUNCH_TO_ORBIT     // 从地表发射到轨道
}

enum LaunchState {
  ON_PAD,             // 在发射台，固定
  COUNTDOWN,          // 倒计时
  IGNITION,           // 点火
  LAUNCHING,          // 上升中
  COAST,              // 滑行到远地点
  CIRCULARIZING,      // 入轨圆化
  IN_ORBIT            // 在轨
}

enum GameProgressState {
  GROUNDED,    // 在地面，可执行发射任务
  IN_LEO,      // 在低地球轨道，可执行同步轨道或月球转移
  IN_GEO,      // 在地球同步轨道（完成状态）
  AT_MOON      // 在月球轨道（完成状态）
}
