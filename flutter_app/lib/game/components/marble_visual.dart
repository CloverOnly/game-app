import 'package:flame/components.dart';
import 'package:flutter/material.dart';

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
    final r = GameConfig.marbleRadius;
    final color = Color(players[playerId]!.color).withValues(alpha: alpha);

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(2, 4),
        width: r * 2 * 0.85,
        height: r * 0.56,
      ),
      Paint()..color = const Color(0x50000000).withValues(alpha: alpha),
    );

    canvas.drawCircle(Offset.zero, r, Paint()..color = color);

    canvas.drawCircle(
      Offset(-r * 0.25, -r * 0.25),
      r * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.45 * alpha),
    );

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
