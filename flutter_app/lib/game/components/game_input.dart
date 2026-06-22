import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../constants.dart';
import '../land_grabber_game.dart';
import '../models.dart';

/// 배치(탭/드래그 후 놓기) + 발사(aiming에서만)
class GameInput extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<LandGrabberGame> {
  GameInput() : super(priority: 100);

  bool _dragging = false;
  bool _placementHandled = false;
  Vector2? _lastPlacePos;

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
        _placementHandled = false;
        _dragging = false;
        _lastPlacePos = event.localPosition.clone();
        game.recordTap(event.localPosition);
        game.previewPlacement(event.localPosition);
      case GameState.aiming:
        game.beginCharge(event.localPosition);
      default:
        break;
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (game.state == GameState.placing) {
      _placementHandled = false;
      _dragging = false;
      return;
    }
    if (_dragging || game.state != GameState.aiming) return;
    game.cancelCharge();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (game.state == GameState.placing) {
      if (!_placementHandled && !game.placementLocked && !_dragging) {
        game.tryPlaceMarble(event.localPosition);
        _placementHandled = true;
      }
      _dragging = false;
      return;
    }
    if (_dragging || game.state != GameState.aiming) return;
    game.endCharge(event.localPosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!game.acceptsHumanInput) return;

    if (game.state == GameState.placing) {
      if (game.placementLocked) return;
      _dragging = true;
      _lastPlacePos = event.localPosition.clone();
      game.previewPlacement(event.localPosition);
      return;
    }

    if (game.state != GameState.aiming) return;
    _dragging = true;
    game.beginCharge(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final pos = event.localStartPosition;

    if (game.state == GameState.placing && !game.placementLocked) {
      _lastPlacePos = pos.clone();
      game.previewPlacement(pos);
      return;
    }

    if (game.state != GameState.aiming) return;
    game.updateChargeFinger(pos);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (game.state == GameState.placing) {
      if (!_placementHandled &&
          !game.placementLocked &&
          _lastPlacePos != null) {
        game.tryPlaceMarble(_lastPlacePos!);
        _placementHandled = true;
      }
      _dragging = false;
      return;
    }

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
    if (game.state == GameState.placing) {
      _dragging = false;
      _placementHandled = false;
      return;
    }
    _dragging = false;
    if (game.state == GameState.aiming) {
      game.cancelCharge();
    }
  }
}
