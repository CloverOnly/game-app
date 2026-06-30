enum PlayerId { p1, p2 }

enum GameMode {
  /// 플레이어 vs AI
  ai,
  /// 같은 기기에서 2인 로컬 대전
  local,
  /// 온라인 PVP (준비 중)
  pvp,
}

/// 경기장 네 모서리
enum FieldCorner {
  bottomLeft,
  bottomRight,
  topLeft,
  topRight,
}

enum TurnResult { playing, claimed, failedShots, failedOut, failedPenalty }

enum GameState { placing, aiming, moving, resolving, gameOver }

class GamePoint {
  const GamePoint(this.x, this.y);
  final double x;
  final double y;
}

class PlayerConfig {
  const PlayerConfig({
    required this.id,
    required this.name,
    required this.color,
    required this.trailColor,
    required this.baseColor,
  });

  final PlayerId id;
  final String name;
  final int color;
  final int trailColor;
  final int baseColor;
}

class GameRect {
  const GameRect(this.x, this.y, this.w, this.h);
  final double x;
  final double y;
  final double w;
  final double h;
}

class GameOverResult {
  const GameOverResult({
    required this.winnerName,
    this.winnerId,
  });

  final String winnerName;
  final PlayerId? winnerId;

  bool get isDraw => winnerId == null;
}
