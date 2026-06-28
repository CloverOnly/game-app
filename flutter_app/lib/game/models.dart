enum PlayerId { p1, p2 }

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
