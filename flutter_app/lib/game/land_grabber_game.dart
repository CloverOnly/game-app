import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'ai_controller.dart';
import 'components/debug_overlay.dart';
import 'components/marble.dart';
import 'components/marble_visual.dart';
import 'components/game_input.dart';
import 'components/wall.dart';
import 'constants.dart';
import 'debug_log.dart';
import 'geometry_utils.dart';
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
  final debug = GameDebugLog();
  final _ai = AiController();

  /// P2 = AI, P1 = 사람
  bool get isAiTurn => turn.currentPlayer == AiController.aiPlayer;
  bool get acceptsHumanInput =>
      !isAiTurn &&
      state != GameState.resolving &&
      state != GameState.gameOver &&
      state != GameState.moving;

  Vector2? lastTapPos;

  late Marble marble;
  late MarbleVisual marbleVisual;
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

  bool placementLocked = false;

  // 당기기 발사
  bool _fingerDown = false;
  Vector2? _fingerPos;
  double _shotMovingTime = 0;
  /// 이번 발사에서 본진에서 충분히 멀어졌는지 (복귀 보조용)
  bool _strokeFarFromHome = false;
  /// 이번 발사 중 본진에서 가장 멀어진 거리
  double _strokePeakDistFromHome = 0;

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

    final start = territory.getDefaultPlacement(turn.currentPlayer);
    marble = Marble(
      position: Vector2(start.dx, start.dy),
      playerId: turn.currentPlayer,
    );
    await world.add(marble);

    marbleVisual = MarbleVisual(
      getPosition: () => marble.body.position,
      getPlayerId: () => marble.playerId,
      isPreview: () => marble.placementPreview,
    );
    await camera.viewport.add(marbleVisual);

    await camera.viewport.add(aimLayer);
    await camera.viewport.add(DebugOverlay(
      getLastTap: () => lastTapPos,
      getFingerPos: () => _fingerPos,
      getMarblePos: () => marble.body.position,
      isVisible: () => true,
    ));
    await camera.viewport.add(GameInput());

    await _createWalls();

    _startNewTurn();
  }

  Future<void> _createWalls() async {
    final f = territory.playfield;
    const t = WorldConfig.wallThickness;
    const r = GameConfig.marbleRadius;

    // 플레이 필드(흰 네모) 경계에 벽 배치
    final walls = [
      (Vector2(f.x + f.w / 2, f.y - t / 2 + r), Vector2(f.w, t)),
      (Vector2(f.x + f.w / 2, f.y + f.h + t / 2 - r), Vector2(f.w, t)),
      (Vector2(f.x - t / 2 + r, f.y + f.h / 2), Vector2(t, f.h)),
      (Vector2(f.x + f.w + t / 2 - r, f.y + f.h / 2), Vector2(t, f.h)),
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
      _shotMovingTime += dt;
      _updateMoving();
    }
    placementHintLayer.active = state == GameState.placing && !placementLocked;
    placementHintLayer.playerId = turn.currentPlayer;
    placementHintLayer.marblePos = Vector2(
      marble.body.position.x,
      marble.body.position.y,
    );
    if (_fingerDown && state == GameState.aiming && _fingerPos != null) {
      aimLayer.drawSlingshot(
        marble.body.position,
        _fingerPos!,
        players[turn.currentPlayer]!,
      );
    }
  }

  bool _isNearMarble(Vector2 local) {
    return (local - marble.body.position).length <
        GameConfig.marbleRadius * 4;
  }

  void recordTap(Vector2 local) {
    lastTapPos = local.clone();
    _pushDebug();
  }

  void previewPlacement(Vector2 local) {
    if (state != GameState.placing || placementLocked) return;
    final playerId = turn.currentPlayer;
    if (!territory.isInStartZone(local.x, local.y, playerId)) return;
    final pos = territory.clampPlacement(local.x, local.y, playerId);
    marble.moveTo(Vector2(pos.dx, pos.dy));
  }

  void tryPlaceMarble(Vector2 local) {
    if (!acceptsHumanInput) return;

    final x = local.x.toStringAsFixed(0);
    final y = local.y.toStringAsFixed(0);
    debug.log('📍 탭 ($x, $y) | state=$state locked=$placementLocked');

    if (state != GameState.placing) {
      debug.log('❌ 배치 실패: state가 placing이 아님 ($state)');
      _pushDebug();
      return;
    }
    if (placementLocked) {
      debug.log('❌ 배치 실패: 이미 위치 확정됨');
      _pushDebug();
      return;
    }

    final playerId = turn.currentPlayer;
    final inZone = territory.isInStartZone(local.x, local.y, playerId);
    final center = territory.getCornerCenter(playerId);
    final dx = local.x - center.dx;
    final dy = local.y - center.dy;
    debug.log(
      '🔍 구역검사: inZone=$inZone | 코너=(${center.dx.toInt()},${center.dy.toInt()}) offset=(${dx.toInt()},${dy.toInt()})',
    );

    if (!inZone) {
      debug.log('❌ 배치 실패: 시작 구역(1/4원) 밖');
      _pushDebug();
      return;
    }

    final pos = territory.clampPlacement(local.x, local.y, playerId);
    _confirmPlacement(pos);
  }

  void _confirmPlacement(Offset pos) {
    marble.moveTo(Vector2(pos.dx, pos.dy));
    marble.placementPreview = false;
    placementLocked = true;
    state = GameState.aiming;

    debug.log(
      '✅ 배치 성공! 망=(${pos.dx.toInt()}, ${pos.dy.toInt()}) → aiming',
    );
    _updateHud(
      status: isAiTurn
          ? 'AI 조준 중...'
          : '✅ 위치 확정! 망을 드래그해 당겨 발사',
    );
    _pushDebug();

    if (isAiTurn) {
      _scheduleAi(_aiPerformShot, 450);
    }
  }

  void _aiPerformPlacement() {
    if (!isAiTurn || state != GameState.placing || placementLocked) return;
    final pos = _ai.planPlacement(territory);
    debug.log('🤖 AI 배치 (${pos.dx.toInt()}, ${pos.dy.toInt()})');
    _confirmPlacement(pos);
  }

  void _aiPerformShot() {
    if (!isAiTurn || state != GameState.aiming || !placementLocked) return;
    if (!turn.canShootAgain()) return;

    final finger = _ai.planPullFinger(
      territory: territory,
      marblePos: marble.body.position,
      shotNumber: turn.shotCount + 1,
      leftStartZone: turn.leftStartZone,
    );
    debug.log('🤖 AI 발사 #${turn.shotCount + 1}');
    _tryLaunch(finger);
  }

  void _scheduleAi(void Function() action, int delayMs) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (state == GameState.gameOver || !isAiTurn) return;
      action();
    });
  }

  void beginCharge(Vector2 local) {
    if (!acceptsHumanInput) return;

    final x = local.x.toStringAsFixed(0);
    final y = local.y.toStringAsFixed(0);

    if (state != GameState.aiming || !placementLocked) return;

    final dist = (local - marble.body.position).length;
    final near = _isNearMarble(local);

    if (!near) {
      debug.log('❌ 차지 실패: 망에서 너무 멂 (거리 ${dist.toStringAsFixed(0)})');
      _pushDebug();
      return;
    }

    _fingerDown = true;
    _fingerPos = local.clone();
    debug.log(
      '⚡ 조준 시작 ($x,$y) | 망거리=${dist.toStringAsFixed(0)} → 당겨서 발사',
    );
    _updateHud(status: '망을 당긴 뒤 손을 떼세요');
    _pushDebug();
  }

  void updateChargeFinger(Vector2 local) {
    if (!_fingerDown || state != GameState.aiming) return;

    _fingerPos = local.clone();
    final pull = (local - marble.body.position).length;
    if (pull >= GameConfig.minPullDistance) {
      _updateHud(status: '손을 떼면 발사! (${pull.toInt()}px)');
    }
  }

  void endCharge([Vector2? releasePos]) {
    if (!acceptsHumanInput && !_fingerDown) return;

    if (releasePos != null) {
      _fingerPos = releasePos.clone();
    }

    if (_fingerPos != null) {
      final pull = (_fingerPos! - marble.body.position).length;
      debug.log('🚀 발사 시도 pull=${pull.toStringAsFixed(0)}px');

      if (pull < GameConfig.minPullDistance) {
        debug.log(
          '❌ 발사 취소: 당김 ${pull.toStringAsFixed(0)}px < 최소 ${GameConfig.minPullDistance.toInt()}px — 망을 더 당겨보세요',
        );
      } else if (!turn.canShootAgain()) {
        debug.log('❌ 발사 취소: 남은 발사 없음');
      } else {
        _tryLaunch(_fingerPos!);
      }
    } else {
      debug.log('❌ 발사 안 됨: 손가락 위치 없음');
    }

    _cancelCharge();
    _pushDebug();
  }

  void cancelCharge() {
    _cancelCharge();
  }

  void _cancelCharge() {
    _fingerDown = false;
    _fingerPos = null;
    aimLayer.clear();
  }

  void _tryLaunch(Vector2 finger) {
    final marblePos = marble.body.position;
    // 슬링샷: 당긴 방향의 반대로 발사
    final pull = marblePos - finger;
    final pullDist = pull.length;

    if (pullDist < GameConfig.minPullDistance) {
      debug.log('❌ 발사 실패: pull 너무 짧음');
      return;
    }

    final clampedDist = pullDist.clamp(
      GameConfig.minPullDistance,
      GameConfig.maxPullDistance,
    );
    final speed = (clampedDist * GameConfig.launchPowerScale).clamp(
      GameConfig.minLaunchSpeed,
      GameConfig.maxLaunchSpeed,
    );

    debug.log(
      '✅ 발사! 속도=${speed.toStringAsFixed(1)} 방향=(${pull.x.toInt()},${pull.y.toInt()})',
    );
    _launchMarble(pull.normalized() * speed);
    _pushDebug();
  }

  void _launchMarble(Vector2 velocity) {
    if (!turn.canShootAgain()) return;

    state = GameState.moving;
    turn.onShotFired();
    _shotMovingTime = 0;
    _strokeFarFromHome = false;
    final home = territory.getStartZoneAnchor(turn.currentPlayer);
    _strokePeakDistFromHome = _distFromHome(
      marble.body.position,
      home,
    );
    _currentStroke = [
      GamePoint(marble.body.position.x, marble.body.position.y),
    ];
    _syncTrailDisplay();
    marble.launch(velocity);
    _updateHud(status: '발사 ${turn.shotCount}/${GameConfig.maxShotsPerTurn}');
  }

  double _distFromHome(Vector2 pos, Offset home) {
    final dx = pos.x - home.dx;
    final dy = pos.y - home.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 복귀 보조는 되돌아올 때만 (2타 출발·코너 통과 시 오작동 방지)
  bool _isReturningHome(
    Vector2 pos,
    Offset home,
    PlayerId playerId, {
    required double distFromHome,
  }) {
    if (!turn.leftStartZone || !_strokeFarFromHome) return false;

    final closing =
        distFromHome < _strokePeakDistFromHome - GameConfig.homeReturnMinDelta;
    if (!closing) return false;

    if (territory.isInStartZone(pos.x, pos.y, playerId)) return true;

    if (!territory.isNearOwnStartZone(pos.x, pos.y, playerId)) return false;

    final toHome = Vector2(home.dx, home.dy) - pos;
    if (toHome.length2 < 4) return true;

    return marble.velocity.dot(toHome) > 0;
  }

  void _updateMoving() {
    final pos = marble.body.position;
    final x = pos.x;
    final y = pos.y;
    final playerId = turn.currentPlayer;

    if (!territory.isOnTerritory(x, y, playerId)) {
      turn.markLeftStartZone();
    }

    final home = territory.getStartZoneAnchor(playerId);
    final distFromHome = _distFromHome(pos, home);
    if (distFromHome > _strokePeakDistFromHome) {
      _strokePeakDistFromHome = distFromHome;
    }
    if (turn.leftStartZone &&
        distFromHome > GameConfig.minDepartureForReturn) {
      _strokeFarFromHome = true;
    }
    final returningHome = _isReturningHome(
      pos,
      home,
      playerId,
      distFromHome: distFromHome,
    );

    final last = _currentStroke.isNotEmpty ? _currentStroke.last : null;
    if (last == null ||
        math.sqrt((last.x - x) * (last.x - x) + (last.y - y) * (last.y - y)) >
            5) {
      _currentStroke.add(GamePoint(x, y));
      _syncTrailDisplay();

      if (hasSelfIntersection(_turnStrokes, _currentStroke)) {
        marble.stop();
        debug.log('❌ 자기 선 교차! 턴 실패');
        _handleShotEnd(ShotEndResult.failedSelfIntersect);
        return;
      }
    }

    // 복귀 중 시작 구역 진입 → 흡수 정지 (코너 벽 반사로 튕겨 나가는 것 방지)
    if (returningHome &&
        territory.isInStartZone(x, y, playerId) &&
        marble.speed < GameConfig.homeCaptureMaxSpeed) {
      marble.stop();
    }

    if (marble.speed >= GameConfig.marbleStopSpeed) {
      if (territory.isOutOfPlayfield(x, y)) {
        // 코너 벽 반사 직후 playfield 밖 → 아웃 대신 감속
        if (returningHome &&
            territory.isNearOwnStartZone(x, y, playerId)) {
          marble.dampen(GameConfig.homeCornerDamping);
          return;
        }
        marble.stop();
        _returnMarbleToBase();
        _handleShotEnd(ShotEndResult.failedOut);
        return;
      }

      if (returningHome &&
          territory.isNearOwnStartZone(x, y, playerId)) {
        marble.dampen(GameConfig.homeCornerDamping);
      }

      // 저속 구간은 빨리 정지 → 다음 타 준비 시간 단축
      if (marble.speed < 6 && _shotMovingTime > 0.25) {
        marble.stop();
      }
      return;
    }

    marble.stop();

    final travel = strokeTravelDistance(_currentStroke);
    if (travel < GameConfig.minShotTravelDistance ||
        _shotMovingTime < GameConfig.minShotDurationSec) {
      debug.log(
        '⚠️ 짧은 이동 (${travel.toStringAsFixed(0)}px, ${_shotMovingTime.toStringAsFixed(2)}s) — 타수 차감',
      );
    }

    final outOfBounds = territory.isOutOfPlayfield(x, y) &&
        !(returningHome && territory.isNearOwnStartZone(x, y, playerId));

    final onOwnTerritory = territory.isOnTerritory(x, y, playerId) ||
        (returningHome && territory.isInStartZone(x, y, playerId));
    final onOpponentBase = territory.isOnOpponentBase(x, y, playerId);

    final result = turn.evaluateShotEnd(
      onOwnTerritory: onOwnTerritory,
      onOpponentBase: onOpponentBase,
      outOfBounds: outOfBounds,
    );

    if (outOfBounds) {
      _returnMarbleToBase();
    }

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
          status: isAiTurn
              ? 'AI 조준 중...'
              : '발사 ${turn.shotCount}/${GameConfig.maxShotsPerTurn} - 망을 당겨 발사!',
        );
        if (isAiTurn) {
          _scheduleAi(_aiPerformShot, 550);
        }
      case ShotEndResult.failedShots:
        _finishTurn('3번 안에 복귀 실패! 선이 지워집니다', keepLines: false);
      case ShotEndResult.failedOut:
        _finishTurn('아웃! 본진으로 귀환 · 턴 종료', keepLines: false);
      case ShotEndResult.failedPenalty:
        _finishTurn('상대 본진 관통! 패널티', keepLines: false);
      case ShotEndResult.failedSelfIntersect:
        _finishTurn('자기 선 교차! 턴 실패', keepLines: false);
    }
  }

  void _returnMarbleToBase() {
    final pos = territory.getStartZoneAnchor(turn.currentPlayer);
    marble.moveTo(Vector2(pos.dx, pos.dy));
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

    Future.delayed(Duration(milliseconds: GameConfig.turnResolveDelayMs), () {
      if (state == GameState.gameOver) return;
      turn.switchPlayer();
      _startNewTurn();
    });
  }

  void _startNewTurn() {
    turn.startTurn();
    state = GameState.placing;
    placementLocked = false;
    _turnStrokes.clear();
    _currentStroke = [];
    _cancelCharge();
    aimLayer.clear();
    trailLayer.clearTurn();

    final playerId = turn.currentPlayer;
    final pos = territory.getDefaultPlacement(playerId);
    marble.playerId = playerId;
    marble.placementPreview = true;
    marble.moveTo(Vector2(pos.dx, pos.dy));

    _updateHud(
      status: isAiTurn
          ? '🤖 AI 턴 - 자동 플레이 중'
          : '${players[playerId]!.name} - 원 안에서 위치 잡고 손을 떼세요 (1회)',
    );

    if (isAiTurn) {
      _scheduleAi(_aiPerformPlacement, 550);
    }
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

    final chargeInfo = _fingerDown
        ? 'pull=${_fingerPos != null ? (_fingerPos! - marble.body.position).length.toStringAsFixed(0) : "-"}px'
        : '조준:-';

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
        debugLines: List.of(debug.lines),
        debugInfo:
            'state=$state | locked=$placementLocked | $chargeInfo | 망=(${marble.body.position.x.toInt()},${marble.body.position.y.toInt()})',
      ),
    );
  }

  void _pushDebug({String? status}) => _updateHud(status: status);
}

class GameHudState {
  const GameHudState({
    required this.p1Percent,
    required this.p2Percent,
    required this.timeText,
    required this.bounceText,
    this.status,
    this.phase,
    this.debugLines = const [],
    this.debugInfo,
  });

  final String p1Percent;
  final String p2Percent;
  final String timeText;
  final String bounceText;
  final String? status;
  final GameState? phase;
  final List<String> debugLines;
  final String? debugInfo;
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
  double holdProgress = -1;

  @override
  Future<void> onLoad() async {
    size = Vector2(WorldConfig.width, WorldConfig.height);
  }

  void drawHoldProgress(
    Vector2 marble,
    double progress,
    PlayerConfig playerConfig,
  ) {
    marblePos = marble;
    fingerPos = null;
    player = playerConfig;
    holdProgress = progress;
  }

  void clearHoldProgress() {
    if (fingerPos == null) {
      holdProgress = -1;
      marblePos = null;
      player = null;
    }
  }

  void drawSlingshot(
    Vector2 marble,
    Vector2 finger,
    PlayerConfig playerConfig,
  ) {
    marblePos = marble;
    fingerPos = finger;
    player = playerConfig;
    holdProgress = -1;
  }

  void clear() {
    marblePos = null;
    fingerPos = null;
    player = null;
    holdProgress = -1;
  }

  @override
  void render(Canvas canvas) {
    if (marblePos != null && player != null && holdProgress >= 0 && fingerPos == null) {
      final m = marblePos!;
      final gaugeRect = Rect.fromCircle(
        center: Offset(m.x, m.y),
        radius: GameConfig.marbleRadius + 12,
      );
      canvas.drawArc(
        gaugeRect,
        -math.pi / 2,
        math.pi * 2 * holdProgress,
        false,
        Paint()
          ..color = Color(player!.trailColor).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    if (marblePos == null || fingerPos == null || player == null) return;

    final m = marblePos!;
    final f = fingerPos!;
    final drag = f - m; // 당기는 방향
    final pullDist = drag.length.clamp(0.0, GameConfig.maxPullDistance);
    if (pullDist < 4) return;

    final dir = drag / pullDist;
    final power = pullDist / GameConfig.maxPullDistance;

    // 당기는 선
    canvas.drawLine(
      Offset(m.x, m.y),
      Offset(f.x, f.y),
      Paint()
        ..color = Color(player!.trailColor).withValues(alpha: 0.85)
        ..strokeWidth = 3,
    );

    // 발사 방향 예상선 (당긴 방향의 반대)
    final launchEnd = m - dir * (pullDist * 0.9);
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
