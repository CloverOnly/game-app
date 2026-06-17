import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../land_grabber_game.dart';

/// 뷰포트 전체를 덮어 터치/드래그 입력을 받는 레이어
class PlayfieldInput extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<LandGrabberGame> {
  PlayfieldInput() : super(priority: 100);

  bool _dragging = false;

  @override
  Future<void> onLoad() async {
    size = game.camera.viewport.virtualSize;
    position = Vector2.zero();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = game.camera.viewport.virtualSize;
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.handleTap(event.localPosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragging = game.handleDragStart(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_dragging) return;
    game.handleDragUpdate(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_dragging) return;
    _dragging = false;
    game.handleDragEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragging = false;
    game.handleDragCancel();
  }
}
