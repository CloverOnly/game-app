import 'dart:math' as math;
import 'dart:ui';

import 'constants.dart';
import 'corner_geometry.dart';
import 'geometry_utils.dart';
import 'models.dart';

class TerritoryManager {
  TerritoryManager({math.Random? random}) {
    _playfield = GameRect(
      WorldConfig.fieldMargin,
      WorldConfig.fieldMargin,
      WorldConfig.width - WorldConfig.fieldMargin * 2,
      WorldConfig.height - WorldConfig.fieldMargin * 2,
    );
    assignRandomCorners(random);
  }

  late final GameRect _playfield;
  final Map<PlayerId, List<List<GamePoint>>> polygons = {
    PlayerId.p1: [],
    PlayerId.p2: [],
  };

  final Map<PlayerId, FieldCorner> _playerCorners = {};

  GameRect get playfield => _playfield;

  Map<PlayerId, FieldCorner> get playerCorners => Map.unmodifiable(_playerCorners);

  /// 4모서리 중 서로 다른 2곳을 P1·P2 본진으로 랜덤 배정
  void assignRandomCorners([math.Random? random]) {
    final corners = List<FieldCorner>.from(FieldCorner.values)
      ..shuffle(random ?? math.Random());
    _playerCorners[PlayerId.p1] = corners[0];
    _playerCorners[PlayerId.p2] = corners[1];
  }

  CornerGeometry _geometry(PlayerId playerId) =>
      CornerGeometry(_playerCorners[playerId]!);

  /// 모서리 1/4 원의 중심점 (코너 꼭짓점)
  Offset getCornerCenter(PlayerId playerId) {
    return _geometry(playerId).centerOf(_playfield);
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

    final geo = _geometry(playerId);
    final center = geo.centerOf(_playfield);
    final dx = x - center.dx;
    final dy = y - center.dy;
    final r = WorldConfig.cornerZoneRadius + margin;
    if (dx * dx + dy * dy > r * r) return false;

    return geo.isNearQuarter(dx, dy, margin);
  }

  /// 필드 **안쪽** 1/4 원 시작 구역 (코너 꼭짓점 기준)
  bool isInStartZone(double x, double y, PlayerId playerId) {
    if (!isInsidePlayfield(x, y)) return false;

    final geo = _geometry(playerId);
    final center = geo.centerOf(_playfield);
    final r = WorldConfig.cornerZoneRadius;
    final dx = x - center.dx;
    final dy = y - center.dy;

    if (dx * dx + dy * dy > r * r) return false;

    return geo.isInsideQuarter(dx, dy);
  }

  Offset getDefaultPlacement(PlayerId playerId) {
    return getStartZoneAnchor(playerId);
  }

  /// 시작 구역 안쪽 중심 (필드 방향으로 45°)
  Offset getStartZoneAnchor(PlayerId playerId) {
    final geo = _geometry(playerId);
    final center = geo.centerOf(_playfield);
    return _clampInsidePlayfield(geo.inwardAnchor(center));
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
    final geo = _geometry(playerId);
    final center = geo.centerOf(_playfield);
    final r = WorldConfig.cornerZoneRadius - GameConfig.marbleRadius - 2;
    final dx = x - center.dx;
    final dy = y - center.dy;

    final local = geo.clampLocal(r, dx, dy);

    return _clampInsidePlayfield(
      Offset(center.dx + local.dx, center.dy + local.dy),
    );
  }

  void claimTerritory(PlayerId playerId, List<GamePoint> path) {
    if (path.length < 3) return;
    polygons[playerId]!.add(List.of(path));
  }

  bool isOnTerritory(double x, double y, PlayerId playerId) {
    if (isInStartZone(x, y, playerId)) return true;
    return isInClaimedPolygon(x, y, playerId);
  }

  /// 이전 턴에 확보한 영토 폴리곤 안인지 (시작 구역 제외)
  bool isInClaimedPolygon(double x, double y, PlayerId playerId) {
    for (final poly in polygons[playerId]!) {
      if (poly.length >= 3 && _pointInPolygon(x, y, poly)) return true;
    }
    return false;
  }

  /// 궤적 선분이 기존 점령 영토에 닿는지 (내부 진입·경계 교차)
  bool strokeTouchesClaimedTerritory(
    PlayerId playerId,
    GamePoint from,
    GamePoint to,
  ) {
    if (isInClaimedPolygon(to.x, to.y, playerId)) return true;

    for (final poly in polygons[playerId]!) {
      if (poly.length < 2) continue;
      for (var i = 0; i < poly.length; i++) {
        final a = poly[i];
        final b = poly[(i + 1) % poly.length];
        if (segmentsCross(from, to, a, b)) return true;
      }
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
    final geo = _geometry(playerId);
    final center = geo.centerOf(_playfield);
    const r = WorldConfig.cornerZoneRadius;
    const arcSteps = 8;

    for (var i = 0; i <= arcSteps; i++) {
      final angle = geo.arcAngleAt(i / arcSteps);
      points.add(Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      ));
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

    var target = Offset(
      oppCenter.dx * 0.35 + fieldCenter.dx * 0.65,
      oppCenter.dy * 0.35 + fieldCenter.dy * 0.65,
    );

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
    var area =
        math.pi * WorldConfig.cornerZoneRadius * WorldConfig.cornerZoneRadius / 4;
    for (final poly in polygons[playerId]!) {
      area += _polygonArea(poly);
    }
    return (area / totalArea).clamp(0.0, 1.0);
  }

  void paint(Canvas canvas) {
    final f = _playfield;

    canvas.drawRect(
      Offset.zero & const Size(WorldConfig.width, WorldConfig.height),
      Paint()..color = const Color(0xFFD0D0D0),
    );

    canvas.drawRect(
      Rect.fromLTWH(f.x, f.y, f.w, f.h),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    canvas.drawRect(
      Rect.fromLTWH(f.x, f.y, f.w, f.h),
      Paint()
        ..color = const Color(0xFFCCCCCC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (final id in PlayerId.values) {
      _paintCornerZone(canvas, id);
    }

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
    final geo = _geometry(playerId);
    final center = geo.centerOf(_playfield);
    final path = geo.cornerPath(center);
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
