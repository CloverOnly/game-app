import 'dart:math' as math;
import 'dart:ui';

import 'constants.dart';
import 'models.dart';

class TerritoryManager {
  TerritoryManager() {
    _playfield = GameRect(
      WorldConfig.fieldMargin,
      WorldConfig.fieldMargin,
      WorldConfig.width - WorldConfig.fieldMargin * 2,
      WorldConfig.height - WorldConfig.fieldMargin * 2,
    );
  }

  late final GameRect _playfield;
  final Map<PlayerId, List<List<GamePoint>>> polygons = {
    PlayerId.p1: [],
    PlayerId.p2: [],
  };

  GameRect get playfield => _playfield;

  /// 모서리 1/4 원의 중심점 (코너 꼭짓점)
  Offset getCornerCenter(PlayerId playerId) {
    final f = _playfield;
    return switch (playerId) {
      PlayerId.p1 => Offset(f.x, f.y + f.h),
      PlayerId.p2 => Offset(f.x + f.w, f.y),
    };
  }

  bool isInStartZone(double x, double y, PlayerId playerId) {
    final center = getCornerCenter(playerId);
    final r = WorldConfig.cornerZoneRadius;
    final dx = x - center.dx;
    final dy = y - center.dy;
    if (dx * dx + dy * dy > r * r) return false;

    return switch (playerId) {
      PlayerId.p1 => dx >= 0 && dy <= 0,
      PlayerId.p2 => dx <= 0 && dy >= 0,
    };
  }

  Offset getDefaultPlacement(PlayerId playerId) {
    final center = getCornerCenter(playerId);
    final d = WorldConfig.cornerZoneRadius * 0.45;
    return switch (playerId) {
      PlayerId.p1 => Offset(center.dx + d, center.dy - d),
      PlayerId.p2 => Offset(center.dx - d, center.dy + d),
    };
  }

  Offset clampPlacement(double x, double y, PlayerId playerId) {
    final center = getCornerCenter(playerId);
    final r = WorldConfig.cornerZoneRadius - GameConfig.marbleRadius - 2;
    var dx = x - center.dx;
    var dy = y - center.dy;

    if (playerId == PlayerId.p1) {
      dx = dx.clamp(0.0, r);
      dy = dy.clamp(-r, 0.0);
    } else {
      dx = dx.clamp(-r, 0.0);
      dy = dy.clamp(0.0, r);
    }

    final len = math.sqrt(dx * dx + dy * dy);
    if (len > r) {
      dx = dx / len * r;
      dy = dy / len * r;
    }

    return Offset(center.dx + dx, center.dy + dy);
  }

  void claimTerritory(PlayerId playerId, List<GamePoint> path) {
    if (path.length < 3) return;
    polygons[playerId]!.add(List.of(path));
  }

  bool isOnTerritory(double x, double y, PlayerId playerId) {
    if (isInStartZone(x, y, playerId)) return true;
    for (final poly in polygons[playerId]!) {
      if (_pointInPolygon(x, y, poly)) return true;
    }
    return false;
  }

  bool isOnOpponentBase(double x, double y, PlayerId playerId) {
    final opponent = playerId == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
    return isInStartZone(x, y, opponent);
  }

  double getTerritoryRatio(PlayerId playerId) {
    final totalArea = _playfield.w * _playfield.h;
    var area = math.pi * WorldConfig.cornerZoneRadius * WorldConfig.cornerZoneRadius / 4;
    for (final poly in polygons[playerId]!) {
      area += _polygonArea(poly);
    }
    return (area / totalArea).clamp(0.0, 1.0);
  }

  void paint(Canvas canvas) {
    final f = _playfield;

    // 흰색 플레이 필드
    canvas.drawRect(
      Rect.fromLTWH(f.x, f.y, f.w, f.h),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // 필드 테두리
    canvas.drawRect(
      Rect.fromLTWH(f.x, f.y, f.w, f.h),
      Paint()
        ..color = const Color(0xFFCCCCCC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 모서리 시작 구역 (1/4 원)
    for (final id in PlayerId.values) {
      _paintCornerZone(canvas, id);
    }

    // 점령한 영토
    for (final id in PlayerId.values) {
      for (final poly in polygons[id]!) {
        if (poly.length < 3) continue;
        final path = Path()..moveTo(poly[0].x, poly[0].y);
        for (var i = 1; i < poly.length; i++) {
          path.lineTo(poly[i].x, poly[i].y);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = Color(players[id]!.color).withValues(alpha: 0.55),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Color(players[id]!.baseColor)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  void _paintCornerZone(Canvas canvas, PlayerId playerId) {
    final center = getCornerCenter(playerId);
    final r = WorldConfig.cornerZoneRadius;
    final color = Color(players[playerId]!.baseColor);

    final path = Path();
    if (playerId == PlayerId.p1) {
      path.moveTo(center.dx, center.dy);
      path.lineTo(center.dx + r, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: r),
        0,
        math.pi / 2,
        false,
      );
      path.close();
    } else {
      path.moveTo(center.dx, center.dy);
      path.lineTo(center.dx, center.dy + r);
      path.arcTo(
        Rect.fromCircle(center: center, radius: r),
        math.pi / 2,
        math.pi / 2,
        false,
      );
      path.close();
    }

    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  bool _pointInPolygon(double x, double y, List<GamePoint> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].x;
      final yi = poly[i].y;
      final xj = poly[j].x;
      final yj = poly[j].y;
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  double _polygonArea(List<GamePoint> poly) {
    var area = 0.0;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      area += (poly[j].x + poly[i].x) * (poly[j].y - poly[i].y);
    }
    return (area / 2).abs();
  }
}
