// ========== GAME STATE MANAGER ==========

class GameStateManager {
  GameState currentState;
  GameState previousState;
  ArrayList<GameState> stateStack;

  GameStateManager() {
    this.currentState = GameState.FLIGHT;
    this.previousState = GameState.FLIGHT;
    this.stateStack = new ArrayList<GameState>();
  }

  void changeState(GameState newState) {
    if (newState == currentState) return;
    previousState = currentState;
    currentState = newState;
  }

  void pushState(GameState newState) {
    stateStack.add(currentState);
    previousState = currentState;
    currentState = newState;
  }

  void popState() {
    if (stateStack.size() > 0) {
      previousState = currentState;
      currentState = stateStack.remove(stateStack.size() - 1);
    }
  }

  boolean isInState(GameState state) {
    return currentState == state;
  }

  boolean canTransitionTo(GameState targetState) {
    return true;
  }

  GameState getCurrentState() {
    return currentState;
  }

  GameState getPreviousState() {
    return previousState;
  }
}
