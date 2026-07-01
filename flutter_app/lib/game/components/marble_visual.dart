import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../constants.dart';

/// 말(돌) 시각 레이어 — 배경 없이 Canvas로 자연 돌맹이를 그립니다.
class MarbleVisual extends PositionComponent {
  MarbleVisual({
    required this.getPosition,
    required this.isPreview,
  }) : super(priority: 18);

  final Vector2 Function() getPosition;
  final bool Function() isPreview;

  static const _radius = GameConfig.marbleRadius * GameConfig.marbleVisualScale;

  /// 돌맹이 실루엣 — 매번 동일한 불규칙 형태
  static const _radiusScale = <double>[
    1.00, 0.93, 0.97, 0.88, 0.95, 0.90, 0.98, 0.92,
    0.96, 0.91, 0.99, 0.94,
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(WorldConfig.width, WorldConfig.height);
    position = Vector2.zero();
  }

  Path _pebblePath(Offset center, double radius) {
    final path = Path();
    final count = _radiusScale.length;
    for (var i = 0; i < count; i++) {
      final theta = i * math.pi * 2 / count - math.pi / 2;
      final r = radius * _radiusScale[i];
      final x = center.dx + math.cos(theta) * r;
      final y = center.dy + math.sin(theta) * r * 0.94;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prev = i - 1;
        final t0 = prev * math.pi * 2 / count - math.pi / 2;
        final r0 = radius * _radiusScale[prev];
        final midT = (t0 + theta) / 2;
        final midR = radius * (r0 / radius + r / radius) / 2 * 1.02;
        final cpx = center.dx + math.cos(midT) * midR;
        final cpy = center.dy + math.sin(midT) * midR * 0.94;
        path.quadraticBezierTo(cpx, cpy, x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void render(Canvas canvas) {
    final pos = getPosition();
    final alpha = isPreview() ? 0.55 : 1.0;
    final center = Offset(pos.x, pos.y);
    final r = _radius;

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(2, r * 0.14),
        width: r * 1.35,
        height: r * 0.32,
      ),
      Paint()..color = Color(0x55000000).withValues(alpha: alpha * 0.85),
    );

    final pebble = _pebblePath(center, r);
    final bounds = Rect.fromCircle(center: center, radius: r * 1.05);

    canvas.drawPath(
      pebble,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.42),
          radius: 1.0,
          colors: [
            Color(0xFFD8D2C8).withValues(alpha: alpha),
            const Color(0xFF9A948A).withValues(alpha: alpha),
            const Color(0xFF6E6860).withValues(alpha: alpha),
            const Color(0xFF4A4540).withValues(alpha: alpha),
          ],
          stops: const [0.0, 0.38, 0.78, 1.0],
        ).createShader(bounds),
    );

    // 흙밭에 어울리는 갈색 기미
    canvas.drawPath(
      pebble,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.55, 0.45),
          radius: 0.7,
          colors: [
            const Color(0x00000000),
            const Color(0xFF6B5A48).withValues(alpha: 0.22 * alpha),
          ],
        ).createShader(bounds),
    );

    _drawStoneSpeckles(canvas, pebble, center, r, alpha);

    canvas.drawPath(
      pebble,
      Paint()
        ..color = const Color(0xFF3A3632).withValues(alpha: 0.45 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-r * 0.28, -r * 0.32),
        width: r * 0.42,
        height: r * 0.24,
      ),
      Paint()..color = const Color(0x88FFFFFF).withValues(alpha: alpha),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-r * 0.12, -r * 0.18),
        width: r * 0.12,
        height: r * 0.08,
      ),
      Paint()..color = const Color(0xAAFFFFFF).withValues(alpha: alpha),
    );
  }

  void _drawStoneSpeckles(
    Canvas canvas,
    Path clip,
    Offset center,
    double r,
    double alpha,
  ) {
    canvas.save();
    canvas.clipPath(clip);

    final specks = <(double, double, double)>[
      (0.15, 0.10, 1.2),
      (-0.22, 0.18, 0.9),
      (0.30, -0.12, 1.0),
      (-0.08, -0.25, 0.8),
      (0.05, 0.28, 0.7),
    ];

    final dark = Paint()..style = PaintingStyle.fill;
    final light = Paint()..style = PaintingStyle.fill;

    for (final (nx, ny, size) in specks) {
      final p = center + Offset(nx * r, ny * r);
      dark.color = const Color(0xFF3E3A36).withValues(alpha: 0.18 * alpha);
      canvas.drawCircle(p, size, dark);
      light.color = const Color(0xFFE8E4DC).withValues(alpha: 0.12 * alpha);
      canvas.drawCircle(p + const Offset(0.4, -0.4), size * 0.55, light);
    }

    canvas.restore();
  }
}
