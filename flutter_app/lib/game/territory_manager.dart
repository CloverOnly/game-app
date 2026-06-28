import 'dart:math' as math;
import 'dart:ui';

import 'constants.dart';
import 'corner_geometry.dart';
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
    _initTerritoryPaths();
  }

  late final GameRect _playfield;
  final Map<PlayerId, Path> _cornerPaths = {};
  final Map<PlayerId, Path> _claimedPaths = {};
  final Map<PlayerId, bool> _hasClaims = {
    PlayerId.p1: false,
    PlayerId.p2: false,
  };

  final Map<PlayerId, FieldCorner> _playerCorners = {};

  GameRect get playfield => _playfield;

  Map<PlayerId, FieldCorner> get playerCorners => Map.unmodifiable(_playerCorners);

  void assignRandomCorners([math.Random? random]) {
    final corners = List<FieldCorner>.from(FieldCorner.values)
      ..shuffle(random ?? math.Random());
    _playerCorners[PlayerId.p1] = corners[0];
    _playerCorners[PlayerId.p2] = corners[1];
  }

  void _initTerritoryPaths() {
    for (final id in PlayerId.values) {
      final geo = _geometry(id);
      final center = geo.centerOf(_playfield);
      _cornerPaths[id] = geo.cornerPath(center);
      _claimedPaths[id] = Path();
      _hasClaims[id] = false;
    }
  }

  CornerGeometry _geometry(PlayerId playerId) =>
      CornerGeometry(_playerCorners[playerId]!);

  Offset getCornerCenter(PlayerId playerId) {
    return _geometry(playerId).centerOf(_playfield);
  }

  Path getFullTerritoryPath(PlayerId playerId) {
    if (!_hasClaims[playerId]!) {
      return _cornerPaths[playerId]!;
    }
    return Path.combine(
      PathOperation.union,
      _cornerPaths[playerId]!,
      _claimedPaths[playerId]!,
    );
  }

  bool canPlaceAt(double x, double y, PlayerId playerId) {
    return getFullTerritoryPath(playerId).contains(Offset(x, y));
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
    if (isInStartZone(x, y, playerId)) {
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

    final pos = Offset(x, y);
    if (getFullTerritoryPath(playerId).contains(pos)) {
      return _clampInsidePlayfield(pos);
    }

    return getDefaultPlacement(playerId);
  }

  /// 이번 턴 궤적을 기존 영토와 합쳐 하나의 영토로 병합
  void claimTerritory(PlayerId playerId, List<List<GamePoint>> strokes) {
    final strokePath = _closedPathFromStrokes(strokes);
    if (strokePath == null) return;

    if (!_hasClaims[playerId]!) {
      _claimedPaths[playerId] = strokePath;
      _hasClaims[playerId] = true;
    } else {
      _claimedPaths[playerId] = Path.combine(
        PathOperation.union,
        _claimedPaths[playerId]!,
        strokePath,
      );
    }
  }

  Path? _closedPathFromStrokes(List<List<GamePoint>> strokes) {
    final points = <GamePoint>[];
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (points.isNotEmpty) {
        final last = points.last;
        final first = stroke.first;
        if ((last.x - first.x).abs() > 1 || (last.y - first.y).abs() > 1) {
          points.add(first);
        }
      }
      for (final p in stroke) {
        if (points.isEmpty ||
            (points.last.x - p.x).abs() > 0.5 ||
            (points.last.y - p.y).abs() > 0.5) {
          points.add(p);
        }
      }
    }
    if (points.length < 3) return null;

    final path = Path()..moveTo(points[0].x, points[0].y);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }
    path.close();
    return path;
  }

  bool isOnTerritory(double x, double y, PlayerId playerId) {
    return getFullTerritoryPath(playerId).contains(Offset(x, y));
  }

  /// 시작 구역을 제외한, 이전에 확보한 영토
  bool isInClaimedPolygon(double x, double y, PlayerId playerId) {
    if (isInStartZone(x, y, playerId)) return false;
    if (!_hasClaims[playerId]!) return false;
    return _claimedPaths[playerId]!.contains(Offset(x, y));
  }

  bool strokeTouchesClaimedTerritory(
    PlayerId playerId,
    GamePoint from,
    GamePoint to,
  ) {
    if (isInClaimedPolygon(to.x, to.y, playerId)) return true;

    final dist = math.sqrt(
      (to.x - from.x) * (to.x - from.x) + (to.y - from.y) * (to.y - from.y),
    );
    final steps = (dist / 6).ceil().clamp(1, 40);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final px = from.x + (to.x - from.x) * t;
      final py = from.y + (to.y - from.y) * t;
      if (isInClaimedPolygon(px, py, playerId)) return true;
    }
    return false;
  }

  bool isOnOpponentBase(double x, double y, PlayerId playerId) {
    final opponent = playerId == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
    return isInStartZone(x, y, opponent);
  }

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

    final bounds = getFullTerritoryPath(playerId).getBounds();
    const grid = 10;
    for (var gx = 0; gx <= grid; gx++) {
      for (var gy = 0; gy <= grid; gy++) {
        final p = Offset(
          bounds.left + bounds.width * gx / grid,
          bounds.top + bounds.height * gy / grid,
        );
        if (getFullTerritoryPath(playerId).contains(p)) {
          points.add(p);
        }
      }
    }

    return points;
  }

  Offset getTerritoryCenter(PlayerId playerId) {
    final path = getFullTerritoryPath(playerId);
    final bounds = path.getBounds();
    final center = bounds.center;
    if (path.contains(center)) return center;
    return getStartZoneAnchor(playerId);
  }

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

  double estimateReturnPower(Offset from, PlayerId playerId) {
    final home = getStartZoneAnchor(playerId);
    final dist = (from - home).distance;
    return (dist / GameConfig.maxPullDistance * 1.08).clamp(0.55, 0.98);
  }

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
    final path = getFullTerritoryPath(playerId);
    final f = _playfield;
    const step = 10.0;
    var inside = 0;
    var total = 0;

    for (var x = f.x + step / 2; x < f.x + f.w; x += step) {
      for (var y = f.y + step / 2; y < f.y + f.h; y += step) {
        total++;
        if (path.contains(Offset(x, y))) inside++;
      }
    }

    if (total == 0) return 0;
    return (inside / total).clamp(0.0, 1.0);
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
      final path = getFullTerritoryPath(id);
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
