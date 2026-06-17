import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'components/marble.dart';
import 'components/wall.dart';
import 'constants.dart';
import 'models.dart';
import 'territory_manager.dart';
import 'turn_manager.dart';

class LandGrabberGame extends Forge2DGame
    with TapCallbacks, DragCallbacks, HasCollisionDetection {
  LandGrabberGame({required this.onHudUpdate, required this.onGameOver})
    : super(
        gravity: Vector2.zero(),
        camera: CameraComponent.withFixedResolution(
          width: WorldConfig.width,
          height: WorldConfig.height,
        ),
      );

  final void Function(GameHudState hud) onHudUpdate;
  final void Function(String winner) onGameOver;

  final territory = TerritoryManager();
  final turn = TurnManager();

  late Marble marble;
  late TerritoryLayer territoryLayer;
  late TrailLayer trailLayer;
  late AimLayer aimLayer;

  GameState state = GameState.aiming;
  int matchTimeLeft = GameConfig.matchDurationSec;
  List<GamePoint> path = [];

  Vector2? dragStart;
  Vector2? dragCurrent;
  bool isDragging = false;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    territoryLayer = TerritoryLayer(territory);
    trailLayer = TrailLayer();
    aimLayer = AimLayer();

    await world.add(territoryLayer);
    await _createWalls();

    final startPos = territory.getBaseCenter(turn.currentPlayer);
    marble = Marble(
      position: Vector2(startPos.dx, startPos.dy),
      playerId: turn.currentPlayer,
      onWallBounce: _onWallBounce,
    );
    await world.add(marble);

    await world.add(trailLayer);
    await world.add(aimLayer);

    _startNewTurn();

    _updateHud(status: '${players[turn.currentPlayer]!.name} 차례 - 망을 당겨 발사!');
  }

  Future<void> _createWalls() async {
    const t = WorldConfig.wallThickness;
    const w = WorldConfig.width;
    const h = WorldConfig.height;

    final walls = [
      (Vector2(w / 2, -t / 2), Vector2(w, t)),
      (Vector2(w / 2, h + t / 2), Vector2(w, t)),
      (Vector2(-t / 2, h / 2), Vector2(t, h)),
      (Vector2(w + t / 2, h / 2), Vector2(t, h)),
    ];

    for (final (center, size) in walls) {
      await world.add(Wall(topLeft: center - size / 2, size: size));
    }
  }

  void _onWallBounce() {
    if (state == GameState.moving) {
      turn.onBounce();
      _updateHud();
    }
  }

  void tickMatchTimer() {
    if (state == GameState.gameOver) return;
    matchTimeLeft--;
    _updateHud();
    if (matchTimeLeft <= 0) _endMatch();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state == GameState.moving) {
      _updateMoving();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (state != GameState.aiming) return;
    final local = event.localPosition;
    final dist = (local - marble.body.position).length;
    if (dist < GameConfig.marbleRadius * 4) {
      isDragging = true;
      dragStart = local.clone();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!isDragging || state != GameState.aiming || dragStart == null) return;
    dragCurrent = event.localEndPosition.clone();
    aimLayer.drawAim(
      marble.body.position,
      dragStart!,
      dragCurrent!,
      players[turn.currentPlayer]!,
    );
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!isDragging || state != GameState.aiming) return;
    isDragging = false;
    aimLayer.clear();

    if (dragStart == null || dragCurrent == null) return;

    final end = dragCurrent!;
    final dx = dragStart!.x - end.x;
    final dy = dragStart!.y - end.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    final speed = (dist * GameConfig.launchPowerScale).clamp(
      GameConfig.minLaunchSpeed,
      GameConfig.maxLaunchSpeed,
    );

    dragStart = null;
    dragCurrent = null;
    if (speed < GameConfig.minLaunchSpeed) return;

    final angle = math.atan2(dy, dx);
    _launchMarble(Vector2(math.cos(angle), math.sin(angle)) * speed);
  }

  void _launchMarble(Vector2 velocity) {
    state = GameState.moving;
    turn.onLaunch();
    path = [
      GamePoint(marble.body.position.x, marble.body.position.y),
    ];
    marble.launch(velocity);
    _updateHud(status: '날아가는 중...');
  }

  void _updateMoving() {
    final pos = marble.body.position;
    final x = pos.x;
    final y = pos.y;
    final playerId = turn.currentPlayer;

    final last = path.isNotEmpty ? path.last : null;
    if (last == null ||
        math.sqrt((last.x - x) * (last.x - x) + (last.y - y) * (last.y - y)) >
            6) {
      path.add(GamePoint(x, y));
      trailLayer.setPath(path, players[playerId]!.trailColor);
    }

    final isStopped = marble.speed < 0.3;
    final outOfBounds =
        x < -GameConfig.marbleRadius ||
        x > WorldConfig.width + GameConfig.marbleRadius ||
        y < -GameConfig.marbleRadius ||
        y > WorldConfig.height + GameConfig.marbleRadius;

    final onOwnTerritory = territory.isOnTerritory(x, y, playerId);
    final onOpponentBase = territory.isOnOpponentBase(x, y, playerId);

    if (onOpponentBase && turn.leftBase) {
      _resolveTurn(TurnResult.failedPenalty);
      return;
    }

    if (turn.bounceCount > GameConfig.maxBounces && !onOwnTerritory) {
      if (isStopped || !turn.canStillBounce()) {
        _resolveTurn(TurnResult.failedBounces);
        return;
      }
    }

    final result = turn.evaluateTurn(
      onOwnTerritory: onOwnTerritory,
      onOpponentBase: onOpponentBase,
      outOfBounds: outOfBounds,
      isStopped: isStopped,
    );

    if (result != TurnResult.playing) {
      _resolveTurn(result);
    }
  }

  void _resolveTurn(TurnResult result) {
    state = GameState.resolving;
    marble.stop();

    final playerId = turn.currentPlayer;
    String status;

    switch (result) {
      case TurnResult.claimed:
        territory.claimTerritory(playerId, path);
        territoryLayer.refresh();
        status = '${players[playerId]!.name} 땅 확보!';
      case TurnResult.failedBounces:
        status = '3번 안에 복귀 실패!';
      case TurnResult.failedOut:
        status = '아웃! 경기장 밖으로 나감';
      case TurnResult.failedPenalty:
        status = '상대 본진 관통! 패널티';
      case TurnResult.playing:
        status = '';
    }

    trailLayer.clear();
    _updateHud(status: status);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (state == GameState.gameOver) return;
      turn.switchPlayer();
      _startNewTurn();
    });
  }

  void _startNewTurn() {
    turn.startTurn();
    state = GameState.aiming;
    path = [];

    final playerId = turn.currentPlayer;
    final center = territory.getBaseCenter(playerId);
    marble.playerId = playerId;
    marble.moveTo(Vector2(center.dx, center.dy));

    _updateHud(status: '${players[playerId]!.name} 차례 - 망을 당겨 발사!');
  }

  void _endMatch() {
    state = GameState.gameOver;
    final r1 = territory.getTerritoryRatio(PlayerId.p1);
    final r2 = territory.getTerritoryRatio(PlayerId.p2);

    final String winner;
    if (r1 > r2) {
      winner = players[PlayerId.p1]!.name;
    } else if (r2 > r1) {
      winner = players[PlayerId.p2]!.name;
    } else {
      winner = '무승부';
    }

    _updateHud(status: '게임 종료! 승자: $winner');
    onGameOver(winner);
  }

  void _updateHud({String? status}) {
    final min = matchTimeLeft ~/ 60;
    final sec = (matchTimeLeft % 60).toString().padLeft(2, '0');
    onHudUpdate(
      GameHudState(
        p1Percent: (territory.getTerritoryRatio(PlayerId.p1) * 100)
            .toStringAsFixed(1),
        p2Percent: (territory.getTerritoryRatio(PlayerId.p2) * 100)
            .toStringAsFixed(1),
        timeText: '$min:$sec',
        bounceText: '튕김: ${turn.bounceCount} / ${GameConfig.maxBounces}',
        status: status,
      ),
    );
  }
}

class GameHudState {
  const GameHudState({
    required this.p1Percent,
    required this.p2Percent,
    required this.timeText,
    required this.bounceText,
    this.status,
  });

  final String p1Percent;
  final String p2Percent;
  final String timeText;
  final String bounceText;
  final String? status;
}

class TerritoryLayer extends Component {
  TerritoryLayer(this.territory);

  final TerritoryManager territory;

  void refresh() {}

  @override
  void render(Canvas canvas) {
    territory.paint(canvas);
  }
}

class TrailLayer extends Component {
  List<GamePoint> path = [];
  int color = 0xFF7AB3F0;

  void setPath(List<GamePoint> newPath, int trailColor) {
    path = List.of(newPath);
    color = trailColor;
  }

  void clear() => path = [];

  @override
  void render(Canvas canvas) {
    if (path.length < 2) return;
    final paint = Paint()
      ..color = Color(color).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final p = Path()..moveTo(path[0].x, path[0].y);
    for (var i = 1; i < path.length; i++) {
      p.lineTo(path[i].x, path[i].y);
    }
    canvas.drawPath(p, paint);
  }
}

class AimLayer extends Component {
  Vector2? start;
  Vector2? dragFrom;
  Vector2? dragTo;
  PlayerConfig? player;

  void drawAim(
    Vector2 marblePos,
    Vector2 dragStart,
    Vector2 pointer,
    PlayerConfig playerConfig,
  ) {
    start = marblePos;
    dragFrom = dragStart;
    dragTo = pointer;
    player = playerConfig;
  }

  void clear() {
    start = null;
    dragFrom = null;
    dragTo = null;
    player = null;
  }

  @override
  void render(Canvas canvas) {
    if (start == null || dragFrom == null || dragTo == null || player == null) {
      return;
    }

    final dx = dragFrom!.x - dragTo!.x;
    final dy = dragFrom!.y - dragTo!.y;
    final len = math.min(math.sqrt(dx * dx + dy * dy), 120.0);
    if (len < 5) return;

    final nx = dx / len;
    final ny = dy / len;
    final endX = start!.x + nx * len;
    final endY = start!.y + ny * len;

    canvas.drawLine(
      Offset(start!.x, start!.y),
      Offset(endX, endY),
      Paint()
        ..color = Color(player!.trailColor).withValues(alpha: 0.8)
        ..strokeWidth = 3,
    );

    canvas.drawLine(
      Offset(start!.x, start!.y),
      Offset(start!.x - nx * len * 0.5, start!.y - ny * len * 0.5),
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 2,
    );

    final power = len / 120;
    canvas.drawCircle(
      Offset(start!.x, start!.y),
      GameConfig.marbleRadius + 4 + power * 10,
      Paint()
        ..color = Color(player!.color).withValues(alpha: 0.5 + power * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
