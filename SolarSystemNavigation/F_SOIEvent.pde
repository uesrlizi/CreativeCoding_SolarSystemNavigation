// SOI事件类 - 记录SOI穿越事件
class SOIEvent {
  double timestamp;         // 事件发生时间（simTime）
  SOIEventType type;       // 事件类型
  CelestialBody bodyA;     // 相关天体A（进入的天体或离开的天体）
  CelestialBody bodyB;     // 相关天体B（仅在切换时使用）
  double[] spacecraftPos;  // 航天器位置（日心坐标）
  double[] spacecraftVel;  // 航天器速度（日心坐标）
  String description;      // 事件描述

  SOIEvent(double t, SOIEventType evtType, CelestialBody bA, CelestialBody bB,
           double[] pos, double[] vel, String desc) {
    this.timestamp = t;
    this.type = evtType;
    this.bodyA = bA;
    this.bodyB = bB;
    this.spacecraftPos = (pos != null) ? pos.clone() : null;
    this.spacecraftVel = (vel != null) ? vel.clone() : null;
    this.description = desc;
  }

  // 获取事件描述字符串
  String getDescription() {
    if (description != null) return description;
    switch (type) {
      case ENTER_SOI:
        return "进入 " + bodyA.name + " SOI";
      case EXIT_SOI:
        return "离开 " + bodyA.name + " SOI";
      case SWITCH_SOI:
        return "从 " + bodyA.name + " SOI 切换到 " + bodyB.name + " SOI";
      default:
        return "未知SOI事件";
    }
  }

  // 格式化时间显示
  String getTimeString() {
    return formatSimTime(timestamp);
  }
}

// SOI事件日志类 - 管理SOI事件记录
class SOIEventLog {
  List<SOIEvent> events;
  int maxEvents;          // 最大记录事件数

  SOIEventLog() {
    this.events = new ArrayList<SOIEvent>();
    this.maxEvents = 100;
  }

  SOIEventLog(int max) {
    this.events = new ArrayList<SOIEvent>();
    this.maxEvents = max;
  }

  // 添加事件
  void addEvent(SOIEvent evt) {
    events.add(evt);
    // 如果超过最大数量，删除最早的
    while (events.size() > maxEvents) {
      events.remove(0);
    }
    // 记录日志
    dbgLog("SOI Event: " + evt.getDescription() + " at " + evt.getTimeString());
  }

  // 快捷方法：记录进入SOI事件
  void logEnterSOI(double t, CelestialBody body, double[] pos, double[] vel) {
    addEvent(new SOIEvent(t, SOIEventType.ENTER_SOI, body, null, pos, vel, null));
  }

  // 快捷方法：记录离开SOI事件
  void logExitSOI(double t, CelestialBody body, double[] pos, double[] vel) {
    addEvent(new SOIEvent(t, SOIEventType.EXIT_SOI, body, null, pos, vel, null));
  }

  // 快捷方法：记录SOI切换事件
  void logSwitchSOI(double t, CelestialBody fromBody, CelestialBody toBody,
                    double[] pos, double[] vel) {
    addEvent(new SOIEvent(t, SOIEventType.SWITCH_SOI, fromBody, toBody, pos, vel, null));
  }

  // 获取所有事件
  List<SOIEvent> getEvents() {
    return events;
  }

  // 获取最近的N个事件
  List<SOIEvent> getRecentEvents(int n) {
    int start = Math.max(0, events.size() - n);
    List<SOIEvent> recent = new ArrayList<SOIEvent>();
    for (int i = start; i < events.size(); i++) {
      recent.add(events.get(i));
    }
    return recent;
  }

  // 清空日志
  void clear() {
    events.clear();
  }

  // 获取事件数量
  int size() {
    return events.size();
  }
}
