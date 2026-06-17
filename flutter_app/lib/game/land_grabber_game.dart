import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'components/marble.dart';
import 'components/playfield_input.dart';
import 'components/wall.dart';
import 'constants.dart';
import 'models.dart';
import 'territory_manager.dart';
import 'turn_manager.dart';

class LandGrabberGame extends Forge2DGame {
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
  late PlacementHintLayer placementHintLayer;

  GameState state = GameState.placing;
  int matchTimeLeft = GameConfig.matchDurationSec;

  /// 이번 턴에 완료된 발사 궤적들
  final List<List<GamePoint>> _turnStrokes = [];
  /// 현재 발사 중 궤적
  List<GamePoint> _currentStroke = [];

  Vector2? dragAnchor;
  bool isDragging = false;
  bool marblePlaced = false;

  @override
  Color backgroundColor() => const Color(0xFFE8E8E8);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    territoryLayer = TerritoryLayer(territory);
    trailLayer = TrailLayer();
    aimLayer = AimLayer();
    placementHintLayer = PlacementHintLayer(territory);

    await camera.viewport.add(territoryLayer);
    await camera.viewport.add(trailLayer);
    await camera.viewport.add(placementHintLayer);
    await camera.viewport.add(aimLayer);
    await camera.viewport.add(PlayfieldInput());

    await _createWalls();

    final start = territory.getDefaultPlacement(turn.currentPlayer);
    marble = Marble(
      position: Vector2(start.dx, start.dy),
      playerId: turn.currentPlayer,
    );
    await world.add(marble);

    _startNewTurn();
  }

  Future<void> _createWalls() async {
    final f = territory.playfield;
    const t = WorldConfig.wallThickness;

    final walls = [
      (Vector2(f.x + f.w / 2, f.y - t / 2), Vector2(f.w + t * 2, t)),
      (Vector2(f.x + f.w / 2, f.y + f.h + t / 2), Vector2(f.w + t * 2, t)),
      (Vector2(f.x - t / 2, f.y + f.h / 2), Vector2(t, f.h + t * 2)),
      (Vector2(f.x + f.w + t / 2, f.y + f.h / 2), Vector2(t, f.h + t * 2)),
    ];

    for (final (center, size) in walls) {
      await world.add(Wall(topLeft: center - size / 2, size: size));
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
    placementHintLayer.active = state == GameState.placing;
    placementHintLayer.playerId = turn.currentPlayer;
    placementHintLayer.marblePos = Vector2(
      marble.body.position.x,
      marble.body.position.y,
    );
  }

  void handleTap(Vector2 local) {
    if (state == GameState.placing) {
      final playerId = turn.currentPlayer;
      if (territory.isInStartZone(local.x, local.y, playerId)) {
        final pos = territory.clampPlacement(local.x, local.y, playerId);
        marble.moveTo(Vector2(pos.dx, pos.dy));
        marblePlaced = true;
        _updateHud(status: '돌을 탭하면 발사 준비!');
        return;
      }

      final dist = (local - marble.body.position).length;
      if (marblePlaced && dist < GameConfig.marbleRadius * 3) {
        state = GameState.aiming;
        _updateHud(status: '망을 뒤로 당겨 발사하세요!');
      }
      return;
    }
  }

  bool handleDragStart(Vector2 local) {
    if (state != GameState.aiming) return false;
    final dist = (local - marble.body.position).length;
    if (dist < GameConfig.marbleRadius * 5) {
      isDragging = true;
      dragAnchor = local.clone();
      return true;
    }
    return false;
  }

  void handleDragUpdate(Vector2 local) {
    if (!isDragging || state != GameState.aiming) return;
    dragAnchor = local.clone();
    aimLayer.drawSlingshot(
      marble.body.position,
      local,
      players[turn.currentPlayer]!,
    );
  }

  void handleDragEnd() {
    if (!isDragging || state != GameState.aiming) return;
    isDragging = false;
    aimLayer.clear();

    if (dragAnchor == null) return;

    final marblePos = marble.body.position;
    final pull = marblePos - dragAnchor!;
    final pullDist = pull.length;

    dragAnchor = null;

    if (pullDist < GameConfig.minPullDistance) return;

    final clampedDist = pullDist.clamp(
      GameConfig.minPullDistance,
      GameConfig.maxPullDistance,
    );
    final speed = (clampedDist * GameConfig.launchPowerScale).clamp(
      GameConfig.minLaunchSpeed,
      GameConfig.maxLaunchSpeed,
    );

    _launchMarble(pull.normalized() * speed);
  }

  void handleDragCancel() {
    isDragging = false;
    dragAnchor = null;
    aimLayer.clear();
  }

  void _launchMarble(Vector2 velocity) {
    if (!turn.canShootAgain()) return;

    state = GameState.moving;
    turn.onShotFired();
    _currentStroke = [
      GamePoint(marble.body.position.x, marble.body.position.y),
    ];
    _syncTrailDisplay();
    marble.launch(velocity);
    _updateHud(status: '발사 ${turn.shotCount}/${GameConfig.maxShotsPerTurn}');
  }

  void _updateMoving() {
    final pos = marble.body.position;
    final x = pos.x;
    final y = pos.y;
    final playerId = turn.currentPlayer;
    final f = territory.playfield;

    if (!territory.isOnTerritory(x, y, playerId)) {
      turn.markLeftStartZone();
    }

    final last = _currentStroke.isNotEmpty ? _currentStroke.last : null;
    if (last == null ||
        math.sqrt((last.x - x) * (last.x - x) + (last.y - y) * (last.y - y)) >
            5) {
      _currentStroke.add(GamePoint(x, y));
      _syncTrailDisplay();
    }

    if (marble.speed >= 0.35) return;

    marble.stop();

    final outOfBounds =
        x < f.x - GameConfig.marbleRadius ||
        x > f.x + f.w + GameConfig.marbleRadius ||
        y < f.y - GameConfig.marbleRadius ||
        y > f.y + f.h + GameConfig.marbleRadius;

    final onOwnTerritory = territory.isOnTerritory(x, y, playerId);
    final onOpponentBase = territory.isOnOpponentBase(x, y, playerId);

    final result = turn.evaluateShotEnd(
      onOwnTerritory: onOwnTerritory,
      onOpponentBase: onOpponentBase,
      outOfBounds: outOfBounds,
    );

    _handleShotEnd(result);
  }

  void _handleShotEnd(ShotEndResult result) {
    switch (result) {
      case ShotEndResult.claimed:
        _commitCurrentStroke();
        _claimTurnTerritory();
        _finishTurn(
          '${players[turn.currentPlayer]!.name} 땅 확보!',
          keepLines: true,
        );
      case ShotEndResult.continueTurn:
        _commitCurrentStroke();
        state = GameState.aiming;
        _currentStroke = [];
        _syncTrailDisplay();
        _updateHud(
          status:
              '발사 ${turn.shotCount}/${GameConfig.maxShotsPerTurn} - 다시 당겨 발사!',
        );
      case ShotEndResult.failedShots:
        _finishTurn('3번 안에 복귀 실패! 선이 지워집니다', keepLines: false);
      case ShotEndResult.failedOut:
        _finishTurn('아웃! 경기장 밖으로 나감', keepLines: false);
      case ShotEndResult.failedPenalty:
        _finishTurn('상대 본진 관통! 패널티', keepLines: false);
    }
  }

  void _commitCurrentStroke() {
    if (_currentStroke.length >= 2) {
      _turnStrokes.add(List.of(_currentStroke));
    }
    _currentStroke = [];
  }

  void _claimTurnTerritory() {
    final allPoints = <GamePoint>[];
    for (final stroke in _turnStrokes) {
      allPoints.addAll(stroke);
    }
    if (allPoints.length >= 3) {
      territory.claimTerritory(turn.currentPlayer, allPoints);
      territoryLayer.refresh();
    }
  }

  void _finishTurn(String status, {required bool keepLines}) {
    state = GameState.resolving;
    marble.stop();
    aimLayer.clear();

    if (!keepLines) {
      _turnStrokes.clear();
      _currentStroke = [];
      trailLayer.clearTurn();
    } else {
      trailLayer.clearTurn();
    }

    _updateHud(status: status);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (state == GameState.gameOver) return;
      turn.switchPlayer();
      _startNewTurn();
    });
  }

  void _startNewTurn() {
    turn.startTurn();
    state = GameState.placing;
    _turnStrokes.clear();
    _currentStroke = [];
    marblePlaced = false;
    isDragging = false;
    dragAnchor = null;
    aimLayer.clear();
    trailLayer.clearTurn();

    final playerId = turn.currentPlayer;
    final pos = territory.getDefaultPlacement(playerId);
    marble.playerId = playerId;
    marble.moveTo(Vector2(pos.dx, pos.dy));

    _updateHud(
      status: '${players[playerId]!.name} - 모서리 구역을 탭해 돌 위치 선택',
    );
  }

  void _syncTrailDisplay() {
    trailLayer.setTurnTrails(
      _turnStrokes,
      _currentStroke,
      players[turn.currentPlayer]!.trailColor,
    );
  }

  void _endMatch() {
    state = GameState.gameOver;
    final r1 = territory.getTerritoryRatio(PlayerId.p1);
    final r2 = territory.getTerritoryRatio(PlayerId.p2);

    final winner = r1 > r2
        ? players[PlayerId.p1]!.name
        : r2 > r1
        ? players[PlayerId.p2]!.name
        : '무승부';

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
        bounceText: '발사: ${turn.shotCount} / ${GameConfig.maxShotsPerTurn}',
        status: status,
        phase: state,
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
    this.phase,
  });

  final String p1Percent;
  final String p2Percent;
  final String timeText;
  final String bounceText;
  final String? status;
  final GameState? phase;
}

class TerritoryLayer extends PositionComponent {
  TerritoryLayer(this.territory) : super(priority: 0);

  final TerritoryManager territory;

  @override
  Future<void> onLoad() async {
    size = Vector2(WorldConfig.width, WorldConfig.height);
  }

  void refresh() {}

  @override
  void render(Canvas canvas) {
    territory.paint(canvas);
  }
}

class PlacementHintLayer extends PositionComponent {
  PlacementHintLayer(this.territory) : super(priority: 5);

  final TerritoryManager territory;

  bool active = false;
  PlayerId playerId = PlayerId.p1;
  Vector2? marblePos;

  @override
  Future<void> onLoad() async {
    size = Vector2(WorldConfig.width, WorldConfig.height);
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;

    final center = territory.getCornerCenter(playerId);
    final r = WorldConfig.cornerZoneRadius;

    canvas.drawCircle(
      Offset(center.dx, center.dy),
      r,
      Paint()
        ..color = Color(players[playerId]!.trailColor).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (marblePos != null) {
      canvas.drawCircle(
        Offset(marblePos!.x, marblePos!.y),
        GameConfig.marbleRadius + 6,
        Paint()
          ..color = Color(players[playerId]!.color).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}

class TrailLayer extends PositionComponent {
  TrailLayer() : super(priority: 10);

  List<List<GamePoint>> completedStrokes = [];
  List<GamePoint> activeStroke = [];
  int color = 0xFF7AB3F0;

  @override
  Future<void> onLoad() async {
    size = Vector2(WorldConfig.width, WorldConfig.height);
  }

  void setTurnTrails(
    List<List<GamePoint>> completed,
    List<GamePoint> active,
    int trailColor,
  ) {
    completedStrokes = completed.map(List.of).toList();
    activeStroke = List.of(active);
    color = trailColor;
  }

  void clearTurn() {
    completedStrokes = [];
    activeStroke = [];
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Color(color).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in completedStrokes) {
      _drawStroke(canvas, stroke, paint);
    }
    _drawStroke(canvas, activeStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<GamePoint> stroke, Paint paint) {
    if (stroke.length < 2) return;
    final p = Path()..moveTo(stroke[0].x, stroke[0].y);
    for (var i = 1; i < stroke.length; i++) {
      p.lineTo(stroke[i].x, stroke[i].y);
    }
    canvas.drawPath(p, paint);
  }
}

class AimLayer extends PositionComponent {
  AimLayer() : super(priority: 15);

  Vector2? marblePos;
  Vector2? fingerPos;
  PlayerConfig? player;

  @override
  Future<void> onLoad() async {
    size = Vector2(WorldConfig.width, WorldConfig.height);
  }

  void drawSlingshot(
    Vector2 marble,
    Vector2 finger,
    PlayerConfig playerConfig,
  ) {
    marblePos = marble;
    fingerPos = finger;
    player = playerConfig;
  }

  void clear() {
    marblePos = null;
    fingerPos = null;
    player = null;
  }

  @override
  void render(Canvas canvas) {
    if (marblePos == null || fingerPos == null || player == null) return;

    final m = marblePos!;
    final f = fingerPos!;
    final pull = m - f;
    final pullDist = pull.length.clamp(0.0, GameConfig.maxPullDistance);
    if (pullDist < 4) return;

    final dir = pull / pull.length;
    final power = pullDist / GameConfig.maxPullDistance;

    // 당기는 선 (고무줄)
    canvas.drawLine(
      Offset(m.x, m.y),
      Offset(f.x, f.y),
      Paint()
        ..color = Color(player!.trailColor).withValues(alpha: 0.85)
        ..strokeWidth = 3,
    );

    // 발사 방향 예상선
    final launchEnd = m + dir * (pullDist * 0.9);
    canvas.drawLine(
      Offset(m.x, m.y),
      Offset(launchEnd.x, launchEnd.y),
      Paint()
        ..color = Color(player!.color).withValues(alpha: 0.7)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // 파워 게이지 (망 주변 호)
    final gaugeRect = Rect.fromCircle(
      center: Offset(m.x, m.y),
      radius: GameConfig.marbleRadius + 10,
    );
    canvas.drawArc(
      gaugeRect,
      -math.pi * 0.75,
      math.pi * 1.5 * power,
      false,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF88CC88),
          const Color(0xFFFF6644),
          power,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // 당기는 위치 표시
    canvas.drawCircle(
      Offset(f.x, f.y),
      6,
      Paint()..color = Color(player!.color).withValues(alpha: 0.6),
    );
  }
}
