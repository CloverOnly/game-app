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

  bool isOutOfPlayfield(double x, double y) {
    final f = _playfield;
    final r = GameConfig.marbleRadius;
    return x < f.x + r ||
        x > f.x + f.w - r ||
        y < f.y + r ||
        y > f.y + f.h - r;
  }

  bool isInsidePlayfield(double x, double y) => !isOutOfPlayfield(x, y);

  /// 복귀 판정용 — 시작 구역 근처 (코너 밖 살짝 포함)
  bool isNearOwnStartZone(
    double x,
    double y,
    PlayerId playerId, {
    double margin = 28,
  }) {
    if (isInStartZone(x, y, playerId)) return true;

    final center = getCornerCenter(playerId);
    final dx = x - center.dx;
    final dy = y - center.dy;
    final r = WorldConfig.cornerZoneRadius + margin;
    if (dx * dx + dy * dy > r * r) return false;

    return switch (playerId) {
      PlayerId.p1 => dx >= -margin && dy <= margin,
      PlayerId.p2 => dx <= margin && dy >= -margin,
    };
  }

  /// 필드 **안쪽** 1/4 원 시작 구역 (코너 꼭짓점 기준)
  bool isInStartZone(double x, double y, PlayerId playerId) {
    if (!isInsidePlayfield(x, y)) return false;

    final center = getCornerCenter(playerId);
    final r = WorldConfig.cornerZoneRadius;
    final dx = x - center.dx;
    final dy = y - center.dy;

    if (dx * dx + dy * dy > r * r) return false;

    return switch (playerId) {
      // 좌하단 코너 → 안쪽은 오른쪽·위
      PlayerId.p1 => dx >= 0 && dy <= 0,
      // 우상단 코너 → 안쪽은 왼쪽·아래
      PlayerId.p2 => dx <= 0 && dy >= 0,
    };
  }

  Path _cornerPath(PlayerId playerId) {
    final center = getCornerCenter(playerId);
    final r = WorldConfig.cornerZoneRadius;
    final path = Path();

    if (playerId == PlayerId.p1) {
      // 좌하단: 코너 → 위 → 호(오른쪽) — 필드 안쪽
      path.moveTo(center.dx, center.dy);
      path.lineTo(center.dx, center.dy - r);
      path.arcTo(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        math.pi / 2,
        false,
      );
      path.close();
    } else {
      // 우상단: 코너 → 왼쪽 → 호(아래) — 필드 안쪽
      path.moveTo(center.dx, center.dy);
      path.lineTo(center.dx - r, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: r),
        math.pi,
        math.pi / 2,
        false,
      );
      path.close();
    }
    return path;
  }

  Offset getDefaultPlacement(PlayerId playerId) {
    return getStartZoneAnchor(playerId);
  }

  /// 시작 구역 안쪽 중심 (필드 방향으로 45°)
  Offset getStartZoneAnchor(PlayerId playerId) {
    final center = getCornerCenter(playerId);
    final d = WorldConfig.cornerZoneRadius * 0.52;
    final pos = switch (playerId) {
      // 좌하단 → 필드 안쪽(우상)
      PlayerId.p1 => Offset(center.dx + d, center.dy - d),
      // 우상단 → 필드 안쪽(좌하)
      PlayerId.p2 => Offset(center.dx - d, center.dy + d),
    };
    return _clampInsidePlayfield(pos);
  }

  Offset _clampInsidePlayfield(Offset pos) {
    final f = _playfield;
    final m = GameConfig.marbleRadius + 2;
    return Offset(
      pos.dx.clamp(f.x + m, f.x + f.w - m),
      pos.dy.clamp(f.y + m, f.y + f.h - m),
    );
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

    return _clampInsidePlayfield(Offset(center.dx + dx, center.dy + dy));
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

  /// AI용: 플레이어 영토 경계/꼭짓점 샘플
  List<Offset> getTerritoryBoundaryPoints(PlayerId playerId) {
    final points = <Offset>[];

    // 코너 1/4원 아크 샘플
    final center = getCornerCenter(playerId);
    const r = WorldConfig.cornerZoneRadius;
    const arcSteps = 8;
    for (var i = 0; i <= arcSteps; i++) {
      final t = i / arcSteps;
      if (playerId == PlayerId.p1) {
        final angle = -math.pi / 2 + t * (math.pi / 2);
        points.add(Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        ));
      } else {
        final angle = math.pi + t * (math.pi / 2);
        points.add(Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        ));
      }
    }

    for (final poly in polygons[playerId]!) {
      points.addAll(poly.map((p) => Offset(p.x, p.y)));
    }

    return points;
  }

  /// AI용: 영토 중심 (코너 + 점령 폴리곤)
  Offset getTerritoryCenter(PlayerId playerId) {
    final boundary = getTerritoryBoundaryPoints(playerId);
    if (boundary.isEmpty) return getStartZoneAnchor(playerId);

    var sx = 0.0;
    var sy = 0.0;
    for (final p in boundary) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / boundary.length, sy / boundary.length);
  }

  /// AI용: 상대 영토를 깊게 관통할 최적 조준점
  Offset findInvadeTarget(Offset from, PlayerId defender) {
    final f = _playfield;
    final fieldCenter = Offset(f.x + f.w / 2, f.y + f.h / 2);
    final oppCenter = getTerritoryCenter(defender);
    final boundary = getTerritoryBoundaryPoints(defender);

    // 필드 중심 쪽으로 깊게 파고드는 목표 (상대 영토 중심 + 필드 중심 혼합)
    var target = Offset(
      oppCenter.dx * 0.35 + fieldCenter.dx * 0.65,
      oppCenter.dy * 0.35 + fieldCenter.dy * 0.65,
    );

    // 경계점 중 필드 중심에 가장 가까운(=가장 깊은) 점과 비교해 더 좋은 쪽 선택
    if (boundary.isNotEmpty) {
      Offset? deepest;
      var minDistToCenter = double.infinity;
      for (final p in boundary) {
        final d = (p - fieldCenter).distance;
        if (d < minDistToCenter) {
          minDistToCenter = d;
          deepest = p;
        }
      }
      if (deepest != null) {
        target = Offset(
          target.dx * 0.5 + deepest.dx * 0.5,
          target.dy * 0.5 + deepest.dy * 0.5,
        );
      }
    }

    return target;
  }

  /// AI용: 복귀 거리에 맞는 발사 파워 (0~1)
  double estimateReturnPower(Offset from, PlayerId playerId) {
    final home = getStartZoneAnchor(playerId);
    final dist = (from - home).distance;
    return (dist / GameConfig.maxPullDistance * 1.08).clamp(0.55, 0.98);
  }

  /// AI용: 상대 영토를 관통할 발사 방향 후보
  Offset? suggestInvadeDirection(
    Offset from,
    PlayerId attacker,
    PlayerId defender,
  ) {
    final target = findInvadeTarget(from, defender);
    final dx = target.dx - from.dx;
    final dy = target.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return null;
    return Offset(dx / len, dy / len);
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

    // 플레이 필드 밖 (아웃 영역)
    canvas.drawRect(
      Offset.zero & const Size(WorldConfig.width, WorldConfig.height),
      Paint()..color = const Color(0xFFD0D0D0),
    );

    // 흰색 플레이 필드 (경기장)
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
    final path = _cornerPath(playerId);
    final color = Color(players[playerId]!.baseColor);

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
