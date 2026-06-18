import 'dart:ui';

import 'package:flame/components.dart';

import '../constants.dart';
import '../models.dart';

/// 물리 바디 위에 그려지는 망 시각 레이어 (뷰포트 최상단)
class MarbleVisual extends PositionComponent {
  MarbleVisual({
    required this.getPosition,
    required this.getPlayerId,
    required this.isPreview,
  }) : super(priority: 8, anchor: Anchor.center);

  final Vector2 Function() getPosition;
  final PlayerId Function() getPlayerId;
  final bool Function() isPreview;

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(getPosition());
  }

  @override
  void render(Canvas canvas) {
    final playerId = getPlayerId();
    final alpha = isPreview() ? 0.55 : 1.0;
    const r = GameConfig.marbleRadius;

    canvas.drawCircle(
      const Offset(2, 2),
      r,
      Paint()..color = const Color(0x40000000).withValues(alpha: alpha),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = const Color(0xFFF0F0F0).withValues(alpha: alpha),
    );
    canvas.drawCircle(
      const Offset(-4, -4),
      r * 0.35,
      Paint()..color = const Color(0xB3FFFFFF).withValues(alpha: alpha),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = Color(players[playerId]!.color).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}
