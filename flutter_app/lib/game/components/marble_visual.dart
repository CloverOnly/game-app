import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../constants.dart';

/// 말(망) — 나무 디스크 + 별 스프라이트
class MarbleVisual extends PositionComponent {
  MarbleVisual({
    required this.getPosition,
    required this.isPreview,
  }) : super(priority: 8, anchor: Anchor.center);

  final Vector2 Function() getPosition;
  final bool Function() isPreview;

  Sprite? _sprite;

  /// mal_piece.png 목업 (1024×558) — 중앙 디스크 영역
  static const _srcW = 1024.0;
  static const _cropSize = 290.0;
  static const _srcX = (_srcW - _cropSize) / 2;
  static const _srcY = 118.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final image = await findRootGame()!.images.load('mal_piece.png');
    _sprite = Sprite(
      image,
      srcPosition: Vector2(_srcX, _srcY),
      srcSize: Vector2(_cropSize, _cropSize),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(getPosition());
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    if (sprite == null) return;

    final alpha = isPreview() ? 0.55 : 1.0;
    final diameter = GameConfig.marbleRadius * 3.0;

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(2, 4),
        width: diameter * 0.85,
        height: diameter * 0.28,
      ),
      Paint()..color = const Color(0x50000000).withValues(alpha: alpha),
    );

    final paint = Paint()..color = Color.fromRGBO(255, 255, 255, alpha);

    sprite.renderRect(
      canvas,
      Rect.fromCenter(
        center: Offset.zero,
        width: diameter,
        height: diameter,
      ),
      overridePaint: paint,
    );
  }
}
