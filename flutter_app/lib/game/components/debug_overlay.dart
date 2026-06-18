import 'dart:ui';

import 'package:flame/components.dart';

import '../constants.dart';

/// 마지막 탭 위치 / 발사 조준 디버그 시각화
class DebugOverlay extends PositionComponent {
  DebugOverlay({
    required this.getLastTap,
    required this.getFingerPos,
    required this.getMarblePos,
    required this.isVisible,
  }) : super(priority: 200);

  final Vector2? Function() getLastTap;
  final Vector2? Function() getFingerPos;
  final Vector2 Function() getMarblePos;
  final bool Function() isVisible;

  @override
  Future<void> onLoad() async {
    size = Vector2(WorldConfig.width, WorldConfig.height);
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible()) return;

    final tap = getLastTap();
    if (tap != null) {
      canvas.drawCircle(
        Offset(tap.x, tap.y),
        8,
        Paint()..color = const Color(0xAAFF00FF),
      );
      canvas.drawCircle(
        Offset(tap.x, tap.y),
        12,
        Paint()
          ..color = const Color(0xAAFF00FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final finger = getFingerPos();
    if (finger != null) {
      final marble = getMarblePos();
      canvas.drawLine(
        Offset(marble.x, marble.y),
        Offset(finger.x, finger.y),
        Paint()
          ..color = const Color(0xAAFFFF00)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(finger.x, finger.y),
        7,
        Paint()..color = const Color(0xAAFFFF00),
      );
    }
  }
}
