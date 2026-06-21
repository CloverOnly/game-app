import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../constants.dart';
import '../land_grabber_game.dart';
import '../models.dart';

/// 배치(탭) + 발사(탭/드래그) — 단일 입력 컴포넌트
class GameInput extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<LandGrabberGame> {
  GameInput() : super(priority: 100);

  bool _dragging = false;

  @override
  Future<void> onLoad() async {
    _syncSize();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncSize();
  }

  void _syncSize() {
    size = Vector2(WorldConfig.width, WorldConfig.height);
    position = Vector2.zero();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x >= 0 &&
        point.y >= 0 &&
        point.x <= WorldConfig.width &&
        point.y <= WorldConfig.height;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!game.acceptsHumanInput) return;
    switch (game.state) {
      case GameState.placing:
        if (game.placementLocked) return;
        game.recordTap(event.localPosition);
        game.tryPlaceMarble(event.localPosition);
      case GameState.aiming:
        game.beginCharge(event.localPosition);
      default:
        break;
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (_dragging || game.state != GameState.aiming) return;
    game.cancelCharge();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_dragging || game.state != GameState.aiming) return;
    game.endCharge(event.localPosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!game.acceptsHumanInput || game.state != GameState.aiming) return;
    _dragging = true;
    game.beginCharge(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (game.state != GameState.aiming) return;
    game.updateChargeFinger(event.localStartPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (game.state != GameState.aiming) {
      _dragging = false;
      return;
    }
    _dragging = false;
    game.endCharge();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragging = false;
    if (game.state == GameState.aiming) {
      game.cancelCharge();
    }
  }
}
