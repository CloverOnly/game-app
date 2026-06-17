import 'constants.dart';
import 'models.dart';

class TurnManager {
  PlayerId currentPlayer = PlayerId.p1;
  int shotCount = 0;
  bool turnActive = false;
  bool leftStartZone = false;

  void startTurn() {
    shotCount = 0;
    turnActive = true;
    leftStartZone = false;
  }

  void onShotFired() {
    shotCount++;
  }

  void markLeftStartZone() {
    leftStartZone = true;
  }

  bool canShootAgain() => shotCount < GameConfig.maxShotsPerTurn;

  void switchPlayer() {
    currentPlayer = currentPlayer == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
    turnActive = false;
  }

  /// 이번 발사가 끝났을 때 판정 (멈춘 상태에서만 호출)
  ShotEndResult evaluateShotEnd({
    required bool onOwnTerritory,
    required bool onOpponentBase,
    required bool outOfBounds,
  }) {
    if (outOfBounds) return ShotEndResult.failedOut;
    if (onOpponentBase && leftStartZone) return ShotEndResult.failedPenalty;

    if (onOwnTerritory && leftStartZone) {
      return ShotEndResult.claimed;
    }

    if (canShootAgain()) {
      return ShotEndResult.continueTurn;
    }

    return ShotEndResult.failedShots;
  }
}

enum ShotEndResult {
  claimed,
  continueTurn,
  failedShots,
  failedOut,
  failedPenalty,
}
