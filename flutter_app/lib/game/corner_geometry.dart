import 'dart:math' as math;
import 'dart:ui';

import 'constants.dart';
import 'models.dart';

/// 모서리 1/4원 시작 구역의 기하학 (필드 안쪽 기준)
class CornerGeometry {
  const CornerGeometry(this.corner);

  final FieldCorner corner;

  Offset centerOf(GameRect field) {
    return switch (corner) {
      FieldCorner.bottomLeft => Offset(field.x, field.y + field.h),
      FieldCorner.bottomRight => Offset(field.x + field.w, field.y + field.h),
      FieldCorner.topLeft => Offset(field.x, field.y),
      FieldCorner.topRight => Offset(field.x + field.w, field.y),
    };
  }

  bool isInsideQuarter(double dx, double dy) {
    return switch (corner) {
      FieldCorner.bottomLeft => dx >= 0 && dy <= 0,
      FieldCorner.bottomRight => dx <= 0 && dy <= 0,
      FieldCorner.topLeft => dx >= 0 && dy >= 0,
      FieldCorner.topRight => dx <= 0 && dy >= 0,
    };
  }

  bool isNearQuarter(double dx, double dy, double margin) {
    return switch (corner) {
      FieldCorner.bottomLeft => dx >= -margin && dy <= margin,
      FieldCorner.bottomRight => dx <= margin && dy <= margin,
      FieldCorner.topLeft => dx >= -margin && dy >= -margin,
      FieldCorner.topRight => dx <= margin && dy >= -margin,
    };
  }

  /// 시작 구역 안쪽 중심 (필드 방향 45°)
  Offset inwardAnchor(Offset center) {
    final d = WorldConfig.cornerZoneRadius * 0.52;
    return switch (corner) {
      FieldCorner.bottomLeft => Offset(center.dx + d, center.dy - d),
      FieldCorner.bottomRight => Offset(center.dx - d, center.dy - d),
      FieldCorner.topLeft => Offset(center.dx + d, center.dy + d),
      FieldCorner.topRight => Offset(center.dx - d, center.dy + d),
    };
  }

  Offset clampLocal(double r, double dx, double dy) {
    var cx = dx;
    var cy = dy;
    switch (corner) {
      case FieldCorner.bottomLeft:
        cx = cx.clamp(0.0, r);
        cy = cy.clamp(-r, 0.0);
      case FieldCorner.bottomRight:
        cx = cx.clamp(-r, 0.0);
        cy = cy.clamp(-r, 0.0);
      case FieldCorner.topLeft:
        cx = cx.clamp(0.0, r);
        cy = cy.clamp(0.0, r);
      case FieldCorner.topRight:
        cx = cx.clamp(-r, 0.0);
        cy = cy.clamp(0.0, r);
    }
    final len = math.sqrt(cx * cx + cy * cy);
    if (len > r) {
      cx = cx / len * r;
      cy = cy / len * r;
    }
    return Offset(cx, cy);
  }

  Path cornerPath(Offset center) {
    final r = WorldConfig.cornerZoneRadius;
    final path = Path()..moveTo(center.dx, center.dy);

    switch (corner) {
      case FieldCorner.bottomLeft:
        path.lineTo(center.dx, center.dy - r);
        path.arcTo(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2,
          math.pi / 2,
          false,
        );
      case FieldCorner.bottomRight:
        path.lineTo(center.dx, center.dy - r);
        path.arcTo(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2,
          -math.pi / 2,
          false,
        );
      case FieldCorner.topLeft:
        path.lineTo(center.dx + r, center.dy);
        path.arcTo(
          Rect.fromCircle(center: center, radius: r),
          0,
          math.pi / 2,
          false,
        );
      case FieldCorner.topRight:
        path.lineTo(center.dx - r, center.dy);
        path.arcTo(
          Rect.fromCircle(center: center, radius: r),
          math.pi,
          -math.pi / 2,
          false,
        );
    }
    return path..close();
  }

  /// AI·영토 경계용 아크 샘플 각도
  double arcAngleAt(double t) {
    return switch (corner) {
      FieldCorner.bottomLeft => -math.pi / 2 + t * (math.pi / 2),
      FieldCorner.bottomRight => -math.pi / 2 - t * (math.pi / 2),
      FieldCorner.topLeft => t * (math.pi / 2),
      FieldCorner.topRight => math.pi - t * (math.pi / 2),
    };
  }
}
