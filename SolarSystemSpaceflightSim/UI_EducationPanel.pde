// ========== EDUCATION PANEL - Science Tips Panel ==========

class EducationPanel implements DrawerContent {
  float panelX, panelY, panelW, panelH;
  float panelMargin;

  // Current educational content
  String currentTitle;
  String currentContent;

  // Saved drawer position
  float currentDrawerX = 0;
  float currentDrawerY = 0;
  float currentDrawerW = 0;

  EducationPanel() {
    float scale = uiScale;
    panelW = 290;
    panelMargin = 14 * scale;
    updateContentForState();
  }

  // Update content based on current game state
  void updateContentForState() {
    // Check for active mission first
    if (missionExecutor != null && missionExecutor.hasActiveMission()) {
      updateContentForMission();
    } else {
      updateContentForProgressState();
    }
  }

  // Update content based on mission execution state
  void updateContentForMission() {
    if (missionExecutor.isLaunchMission()) {
      updateLaunchMissionContent();
    } else if (missionExecutor.isRecoveryMission()) {
      updateRecoveryMissionContent();
    } else {
      // Display content based on mission phase
      MissionExecutorState state = missionExecutor.state;
      switch (state) {
        case WAITING_FOR_MANEUVER:
          currentTitle = "Coasting";
          currentContent = "Waiting to reach the correct position in orbit for the next maneuver. Precision timing ensures the burn puts us on the right trajectory.";
          break;
        case ORIENTING:
          currentTitle = "Orienting";
          currentContent = "Rotating the spacecraft to point the engine in the correct direction. Reaction control thrusters make small adjustments.";
          break;
        case BURNING:
          currentTitle = "Burning";
          currentContent = "Main engine firing to change velocity. The duration is carefully calculated to achieve exactly the required orbital change.";
          break;
        default:
          updateContentForProgressState();
          break;
      }
    }
  }

  void updateLaunchMissionContent() {
    LaunchController launch = missionExecutor.getLaunchController();
    if (launch == null || launch.ship == null) {
      currentTitle = "Launch Prep";
      currentContent = "Final checks before launch. The rocket is fueled and ready.";
      return;
    }

    switch (launch.ship.launchState) {
      case ON_PAD:
        currentTitle = "On Pad";
        currentContent = "The rocket is vertical on the launch pad. The umbilical arm connects it to ground support for fuel and data.";
        break;
      case COUNTDOWN:
      case IGNITION:
        currentTitle = "Countdown";
        currentContent = "T-minus! Automatic sequences activating. The rocket transitions to internal power.";
        break;
      case LAUNCHING:
        currentTitle = "Ascent";
        currentContent = "Climbing through the atmosphere. A gravity turn gradually tilts the rocket horizontal to build orbital velocity.";
        break;
      case COAST:
        currentTitle = "Coasting";
        currentContent = "Engine off! Coasting uphill to apoapsis, the highest point of the orbit. This is the most efficient place to circularize.";
        break;
      case CIRCULARIZING:
        currentTitle = "Circularizing";
        currentContent = "Final burn to round out the orbit. Raising periapsis by accelerating prograde at apoapsis.";
        break;
      case IN_ORBIT:
        currentTitle = "In Orbit";
        currentContent = "Welcome to space! We're in a stable Low Earth Orbit, traveling at ~7.8 km/s.";
        break;
    }
  }

  void updateRecoveryMissionContent() {
    RecoveryController recovery = missionExecutor.getRecoveryController();
    if (recovery == null || recovery.stage == null) {
      currentTitle = "Recovery";
      currentContent = "Preparing to return to the launch site.";
      return;
    }

    switch (recovery.stage) {
      case PREPARING:
        currentTitle = "Preparing";
        currentContent = "Waiting for the right orbit position to begin deorbit burn. Timing is critical to land near the launch site.";
        break;
      case DEORBIT_BURN:
        currentTitle = "Deorbit Burn";
        currentContent = "Firing retrograde to lower the orbit's periapsis into the atmosphere. This burn sets us on a path to reentry.";
        break;
      case COAST_TO_ENTRY:
        currentTitle = "Coasting Down";
        currentContent = "Falling towards the atmosphere. The spacecraft is oriented heat-shield first.";
        break;
      case REENTRY_GUIDANCE:
        currentTitle = "Reentry";
        currentContent = "The air is thickening! Air compression creates thousands of degrees of heat. We're pulling Gs as we decelerate.";
        break;
      case GLIDE_PHASE:
        currentTitle = "Gliding";
        currentContent = "Lower atmosphere now. Using aerodynamic lift to steer towards the landing site.";
        break;
      case TURNAROUND_MANEUVER:
        currentTitle = "Turning Around";
        currentContent = "Flipping to tail-first orientation for landing. Landing legs are deploying.";
        break;
      case HOVER_SLIDE:
        currentTitle = "Approaching";
        currentContent = "Engine burning to hover and translate horizontally towards the exact landing point.";
        break;
      case FINAL_DESCENT:
        currentTitle = "Final Descent";
        currentContent = "Descending vertically. The engine throttles to maintain a steady descent rate.";
        break;
      case LANDING_BURN:
        currentTitle = "Landing Burn";
        currentContent = "Final touchdown burn! Reducing vertical speed to nearly zero as the legs touch the pad.";
        break;
      case LANDED:
        currentTitle = "Landed";
        currentContent = "Touchdown confirmed! Welcome back to Earth. The rocket has returned safely.";
        break;
      default:
        currentTitle = "Recovery";
        currentContent = "Returning to Earth.";
        break;
    }
  }

  // Update content based on game progress state
  void updateContentForProgressState() {
    switch (currentGameProgress) {
      case GROUNDED:
        currentTitle = "On the Ground";
        currentContent = "Ready for launch! To reach orbit we need to accelerate to ~7.8 km/s horizontally while gaining altitude.";
        break;
      case IN_LEO:
        currentTitle = "Low Earth Orbit";
        currentContent = "We made it! LEO is the region from ~200-2000 km up. The International Space Station orbits at ~400 km.";
        break;
      case IN_GEO:
        currentTitle = "Geostationary Orbit";
        currentContent = "At ~35,786 km altitude, we orbit Earth exactly once per day, appearing fixed above one location on the equator.";
        break;
      case AT_MOON:
        currentTitle = "At the Moon";
        currentContent = "The Moon is ~384,000 km from Earth. It takes several days to get here using a Hohmann transfer trajectory.";
        break;
      default:
        currentTitle = "Space Exploration";
        currentContent = "Exploring the cosmos, one orbit at a time.";
        break;
    }
  }

  // ========== DrawerContent Interface Implementation ==========

  public void updateContent(float drawerX, float drawerY, float drawerW) {
    // Save drawer position
    this.currentDrawerX = drawerX;
    this.currentDrawerY = drawerY;
    this.currentDrawerW = drawerW;

    float originalX = panelX;
    float originalY = panelY;
    float originalW = panelW;
    panelX = drawerX;
    panelY = drawerY;
    panelW = drawerW;

    // Update educational content based on state
    updateContentForState();

    // Calculate panel height based on content (using actual drawer width)
    panelH = calculatePanelHeight(drawerW);

    panelX = originalX;
    panelY = originalY;
    panelW = originalW;
  }

  float calculatePanelHeight(float useWidth) {
    float scale = uiScale;
    float headerHeight = 48 * scale;
    float contentHeight = estimateTextHeight(currentContent, useWidth - 2 * panelMargin);
    return headerHeight + contentHeight + 20 * scale;
  }

  float estimateTextHeight(String text, float maxWidth) {
    float scale = uiScale;
    pushStyle();
    textSize(12 * scale);
    String[] words = text.split(" ");
    String line = "";
    float lineHeight = 17 * scale;
    int lineCount = 1;

    for (String word : words) {
      String testLine = line.length() > 0 ? line + " " + word : word;
      float w = textWidth(testLine);
      if (w > maxWidth && line.length() > 0) {
        lineCount++;
        line = word;
      } else {
        line = testLine;
      }
    }
    popStyle();
    return lineCount * lineHeight;
  }

  public void drawContent(float drawX, float drawY, float drawW, float drawH) {
    float scale = uiScale;
    float originalX = panelX;
    float originalY = panelY;
    float originalW = panelW;

    // Save drawer position
    currentDrawerX = drawX;
    currentDrawerY = drawY;
    currentDrawerW = drawW;

    panelX = drawX;
    panelY = drawY;
    panelW = drawW;
    panelH = calculatePanelHeight(drawW);

    pushStyle();

    // Draw title
    fill(255, 200, 100);
    textSize(15 * scale);
    textAlign(LEFT, TOP);
    text(currentTitle, panelX + panelMargin, panelY + panelMargin);

    // Draw divider
    stroke(100, 120, 150, 100);
    strokeWeight(1);
    line(panelX + panelMargin, panelY + 38 * scale, panelX + panelW - panelMargin, panelY + 38 * scale);

    // Draw content text
    fill(220, 230, 240);
    textSize(12 * scale);
    textAlign(LEFT, TOP);
    float textY = panelY + 48 * scale;
    float maxWidth = panelW - 2 * panelMargin;
    drawWrappedText(currentContent, panelX + panelMargin, textY, maxWidth, 17 * scale);

    popStyle();

    panelX = originalX;
    panelY = originalY;
    panelW = originalW;
  }

  void drawWrappedText(String text, float x, float y, float maxWidth, float lineHeight) {
    String[] words = text.split(" ");
    String line = "";
    float currentY = y;

    for (String word : words) {
      String testLine = line.length() > 0 ? line + " " + word : word;
      float w = textWidth(testLine);
      if (w > maxWidth && line.length() > 0) {
        text(line, x, currentY);
        currentY += lineHeight;
        line = word;
      } else {
        line = testLine;
      }
    }

    if (line.length() > 0) {
      text(line, x, currentY);
    }
  }

  public boolean handleContentClick(float mx, float my, float contentX, float contentY, float contentW) {
    return false; // No click handling
  }

  public String getContentTooltip() {
    return null; // No tooltip
  }

  public float[] getContentTooltipSource() {
    float useX = (currentDrawerX != 0) ? currentDrawerX : panelX;
    float useY = (currentDrawerY != 0) ? currentDrawerY : panelY;
    float useW = (currentDrawerW != 0) ? currentDrawerW : panelW;
    return new float[] { useX, useY, useW, panelH };
  }

  public float getContentHeight() {
    float useWidth = (currentDrawerW != 0) ? currentDrawerW : panelW;
    return calculatePanelHeight(useWidth);
  }

  public boolean shouldBeVisible() {
    return true; // Always visible
  }
}
