import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';

/// 흙 운동장 배경 — 마른 흙 바닥, 밟힌 질감
class PlaygroundBackground extends PositionComponent {
  PlaygroundBackground({required this.playfield}) : super(priority: -1);

  final GameRect playfield;

  static const _outerDirt = Color(0xFF8B6F52);
  static const _outerDirtDark = Color(0xFF6E5640);
  static const _fieldDirt = Color(0xFFC4A574);
  static const _fieldDirtLight = Color(0xFFD4B88A);
  static const _fieldDirtDark = Color(0xFFA88858);

  @override
  Future<void> onLoad() async {
    size = Vector2(WorldConfig.width, WorldConfig.height);
  }

  Rect get _field => Rect.fromLTWH(
        playfield.x,
        playfield.y,
        playfield.w,
        playfield.h,
      );

  @override
  void render(Canvas canvas) {
    _drawOuterGround(canvas);
    _drawDirtField(canvas);
    _drawDirtTexture(canvas, _field, density: 1.0);
    _drawFieldEdge(canvas);
  }

  void _drawOuterGround(Canvas canvas) {
    final world = Offset.zero & Size(WorldConfig.width, WorldConfig.height);
    canvas.drawRect(
      world,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_outerDirt, _outerDirtDark],
        ).createShader(world),
    );

    _drawDirtTexture(canvas, world, density: 0.55, seed: 17);
  }

  void _drawDirtField(Canvas canvas) {
    final field = _field;
    canvas.drawRect(
      field,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [_fieldDirtLight, _fieldDirt, _fieldDirtDark],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(field),
    );

    // 밟아 납작해진 중앙
    canvas.drawOval(
      field.inflate(-field.width * 0.08),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x18FFFFFF),
            const Color(0x00000000),
          ],
        ).createShader(field),
    );
  }

  void _drawDirtTexture(
    Canvas canvas,
    Rect area, {
    required double density,
    int seed = 0,
  }) {
    final rng = math.Random(seed);
    final speck = Paint()..style = PaintingStyle.fill;
    final count = (area.width * area.height * 0.018 * density).round();

    for (var i = 0; i < count; i++) {
      final x = area.left + rng.nextDouble() * area.width;
      final y = area.top + rng.nextDouble() * area.height;
      final tone = rng.nextDouble();
      final alpha = 0.06 + rng.nextDouble() * 0.14;
      speck.color = tone > 0.5
          ? Color.fromRGBO(90, 60, 30, alpha)
          : Color.fromRGBO(220, 190, 140, alpha * 0.7);
      final r = 0.6 + rng.nextDouble() * 1.8;
      canvas.drawCircle(Offset(x, y), r, speck);
    }

    // 가는 흙 결
    final grain = Paint()
      ..color = const Color(0x0D000000)
      ..strokeWidth = 0.6;
    for (var y = area.top; y < area.bottom; y += 5) {
      final wobble = math.sin((y + seed) * 0.21) * 1.5;
      canvas.drawLine(
        Offset(area.left, y + wobble),
        Offset(area.right, y + wobble + math.sin(y * 0.08) * 0.8),
        grain,
      );
    }
  }

  void _drawFieldEdge(Canvas canvas) {
    final field = _field;

    // 흙 운동장 테두리 — 밟혀 진 경계
    canvas.drawRect(
      field,
      Paint()
        ..color = const Color(0xFF5C452E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    canvas.drawRect(
      field.deflate(3),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 모서리 닳은 흔적
    final wear = Paint()..color = const Color(0x22000000);
    const inset = 6.0;
    for (final corner in [
      field.topLeft,
      field.topRight,
      field.bottomLeft,
      field.bottomRight,
    ]) {
      canvas.drawCircle(corner, 22, wear);
    }

    // 안쪽 살짝 어두운 그림자
    canvas.drawRect(
      Rect.fromLTRB(
        field.left + inset,
        field.top + inset,
        field.right - inset,
        field.bottom - inset,
      ),
      Paint()
        ..color = const Color(0x08000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
  }
}
