import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../constants.dart';

/// 망(돌) 시각 레이어 — 투명 배경 이미지를 돌 실루엣 그대로 그립니다.
class MarbleVisual extends PositionComponent {
  MarbleVisual({
    required this.image,
    required this.getPosition,
    required this.isPreview,
  }) : super(priority: 18);

  final ui.Image image;
  final Vector2 Function() getPosition;
  final bool Function() isPreview;

  static const _maxSize = GameConfig.marbleRadius * 4.2;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(WorldConfig.width, WorldConfig.height);
    position = Vector2.zero();
  }

  Rect _dstRect(Offset center) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = _maxSize / math.max(iw, ih);
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromCenter(center: center, width: w, height: h);
  }

  @override
  void render(Canvas canvas) {
    final pos = getPosition();
    final alpha = isPreview() ? 0.55 : 1.0;
    final center = Offset(pos.x, pos.y);
    final dst = _dstRect(center);

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(2, dst.height * 0.12),
        width: dst.width * 0.72,
        height: dst.height * 0.18,
      ),
      Paint()..color = const Color(0x45000000).withValues(alpha: alpha),
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
  }
}
