import 'constants.dart';
import 'models.dart';

class TurnManager {
  PlayerId currentPlayer = PlayerId.p1;
  int bounceCount = 0;
  bool isLaunched = false;
  bool turnActive = false;
  bool leftBase = false;

  void startTurn() {
    bounceCount = 0;
    isLaunched = false;
    turnActive = true;
    leftBase = false;
  }

  void onLaunch() {
    isLaunched = true;
    leftBase = true;
  }

  void onBounce() {
    bounceCount++;
  }

  bool canStillBounce() => bounceCount < GameConfig.maxBounces;

  void switchPlayer() {
    currentPlayer = currentPlayer == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
    turnActive = false;
  }

  TurnResult evaluateTurn({
    required bool onOwnTerritory,
    required bool onOpponentBase,
    required bool outOfBounds,
    required bool isStopped,
  }) {
    if (!isLaunched) return TurnResult.playing;
    if (outOfBounds) return TurnResult.failedOut;
    if (onOpponentBase && leftBase) return TurnResult.failedPenalty;

    if (onOwnTerritory && leftBase && isStopped) {
      return bounceCount <= GameConfig.maxBounces
          ? TurnResult.claimed
          : TurnResult.failedBounces;
    }

    if (isStopped && leftBase) {
      if (bounceCount > GameConfig.maxBounces) return TurnResult.failedBounces;
      if (!onOwnTerritory) return TurnResult.failedBounces;
    }

    return TurnResult.playing;
  }
}
