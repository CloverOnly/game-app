import 'dart:ui';

import 'constants.dart';
import 'models.dart';

class TerritoryManager {
  TerritoryManager() {
    final margin = WorldConfig.wallThickness + 8;
    final size = WorldConfig.baseSize;
    bases = {
      PlayerId.p1: GameRect(margin, WorldConfig.height - margin - size, size, size),
      PlayerId.p2: GameRect(WorldConfig.width - margin - size, margin, size, size),
    };
  }

  late final Map<PlayerId, GameRect> bases;
  final Map<PlayerId, List<List<GamePoint>>> polygons = {
    PlayerId.p1: [],
    PlayerId.p2: [],
  };

  void claimTerritory(PlayerId playerId, List<GamePoint> path) {
    if (path.length < 3) return;
    polygons[playerId]!.add(List.of(path));
  }

  bool isOnTerritory(double x, double y, PlayerId playerId) {
    if (_pointInRect(x, y, bases[playerId]!)) return true;
    for (final poly in polygons[playerId]!) {
      if (_pointInPolygon(x, y, poly)) return true;
    }
    return false;
  }

  bool isOnOpponentBase(double x, double y, PlayerId playerId) {
    final opponent = playerId == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
    return _pointInRect(x, y, bases[opponent]!);
  }

  double getTerritoryRatio(PlayerId playerId) {
    final totalArea = WorldConfig.width * WorldConfig.height;
    final base = bases[playerId]!;
    var area = base.w * base.h;
    for (final poly in polygons[playerId]!) {
      area += _polygonArea(poly);
    }
    return (area / totalArea).clamp(0.0, 1.0);
  }

  Offset getBaseCenter(PlayerId playerId) {
    final b = bases[playerId]!;
    return Offset(b.x + b.w / 2, b.y + b.h / 2);
  }

  void paint(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & const Size(WorldConfig.width, WorldConfig.height),
      Paint()..color = const Color(0xFFF5E6C8),
    );

    for (final id in PlayerId.values) {
      final base = bases[id]!;
      canvas.drawRect(
        Rect.fromLTWH(base.x, base.y, base.w, base.h),
        Paint()..color = Color(players[id]!.baseColor).withValues(alpha: 0.85),
      );

      for (final poly in polygons[id]!) {
        if (poly.length < 3) continue;
        final path = Path()..moveTo(poly[0].x, poly[0].y);
        for (var i = 1; i < poly.length; i++) {
          path.lineTo(poly[i].x, poly[i].y);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = Color(players[id]!.color).withValues(alpha: 0.75),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Color(players[id]!.baseColor)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }

    final border = Paint()
      ..color = const Color(0xFF8B6914)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(
      Rect.fromLTWH(
        WorldConfig.wallThickness,
        WorldConfig.wallThickness,
        WorldConfig.width - WorldConfig.wallThickness * 2,
        WorldConfig.height - WorldConfig.wallThickness * 2,
      ),
      border,
    );
  }

  bool _pointInRect(double x, double y, GameRect r) {
    return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
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
