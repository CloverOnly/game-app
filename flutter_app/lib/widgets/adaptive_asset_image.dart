import 'package:flutter/material.dart';

/// 기기 화면 비율에 맞춰 에셋 이미지를 contain 방식으로 배치합니다.
///
/// - 이미지 원본 비율 유지
/// - 화면보다 넓거나 좁은 기기 모두 대응
/// - [overlay]는 이미지 영역 안에 배치
class AdaptiveAssetImage extends StatelessWidget {
  const AdaptiveAssetImage({
    super.key,
    required this.asset,
    required this.intrinsicWidth,
    required this.intrinsicHeight,
    this.backgroundColor = Colors.black,
    this.alignment = Alignment.center,
    this.overlay,
  });

  final String asset;
  final double intrinsicWidth;
  final double intrinsicHeight;
  final Color backgroundColor;
  final Alignment alignment;
  final Widget? overlay;

  double get aspectRatio => intrinsicWidth / intrinsicHeight;

  /// constraints 안에서 contain 되었을 때의 표시 Rect
  static Rect fitRect(
    BoxConstraints constraints,
    double imageAspect, {
    Alignment alignment = Alignment.center,
  }) {
    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight;
    final screenAspect = maxW / maxH;

    late final double w;
    late final double h;
    if (screenAspect > imageAspect) {
      h = maxH;
      w = h * imageAspect;
    } else {
      w = maxW;
      h = w / imageAspect;
    }

    final freeW = maxW - w;
    final freeH = maxH - h;
    final left = freeW / 2 * (1 + alignment.x);
    final top = freeH / 2 * (1 + alignment.y);

    return Rect.fromLTWH(left, top, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = fitRect(constraints, aspectRatio, alignment: alignment);

        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: backgroundColor)),
            Positioned.fromRect(
              rect: rect,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Image.asset(
                    asset,
                    fit: BoxFit.fill,
                    width: intrinsicWidth,
                    height: intrinsicHeight,
                  ),
                  ?overlay,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 짧은 화면·긴 화면 모두 읽기 좋게 스케일
double adaptiveScale(BuildContext context, {double base = 1.0}) {
  final shortest = MediaQuery.sizeOf(context).shortestSide;
  return base * (shortest / 400).clamp(0.85, 1.15);
}

double adaptiveFont(BuildContext context, double size) {
  return size * adaptiveScale(context);
}

EdgeInsets adaptivePadding(BuildContext context, EdgeInsets base) {
  final s = adaptiveScale(context);
  return EdgeInsets.fromLTRB(
    base.left * s,
    base.top * s,
    base.right * s,
    base.bottom * s,
  );
}
