import 'dart:math' as math;

import 'models.dart';

/// 두 선분 (a→b)와 (c→d)가 교차하는지 (끝점 공유 제외)
bool segmentsCross(
  GamePoint a,
  GamePoint b,
  GamePoint c,
  GamePoint d, {
  double epsilon = 1e-6,
}) {
  if (_pointsNear(a, c, epsilon) ||
      _pointsNear(a, d, epsilon) ||
      _pointsNear(b, c, epsilon) ||
      _pointsNear(b, d, epsilon)) {
    return false;
  }

  final o1 = _orientation(a, b, c);
  final o2 = _orientation(a, b, d);
  final o3 = _orientation(c, d, a);
  final o4 = _orientation(c, d, b);

  if (o1 != o2 && o3 != o4) return true;

  if (o1 == 0 && _onSegment(a, c, b)) return true;
  if (o2 == 0 && _onSegment(a, d, b)) return true;
  if (o3 == 0 && _onSegment(c, a, d)) return true;
  if (o4 == 0 && _onSegment(c, b, d)) return true;

  return false;
}

bool _pointsNear(GamePoint p, GamePoint q, double epsilon) {
  return (p.x - q.x).abs() < epsilon && (p.y - q.y).abs() < epsilon;
}

int _orientation(GamePoint a, GamePoint b, GamePoint c) {
  final v = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
  if (v.abs() < 1e-9) return 0;
  return v > 0 ? 1 : 2;
}

bool _onSegment(GamePoint a, GamePoint b, GamePoint c) {
  return b.x <= math.max(a.x, c.x) &&
      b.x >= math.min(a.x, c.x) &&
      b.y <= math.max(a.y, c.y) &&
      b.y >= math.min(a.y, c.y);
}

/// 이번 턴 궤적에서 새 선분이 기존 선과 교차하는지
bool hasSelfIntersection(
  List<List<GamePoint>> completedStrokes,
  List<GamePoint> currentStroke,
) {
  final segments = <(GamePoint, GamePoint)>[];

  void addStroke(List<GamePoint> stroke) {
    for (var i = 0; i < stroke.length - 1; i++) {
      segments.add((stroke[i], stroke[i + 1]));
    }
  }

  for (final stroke in completedStrokes) {
    addStroke(stroke);
  }
  addStroke(currentStroke);

  if (segments.length < 2) return false;

  final newSeg = segments.last;
  for (var i = 0; i < segments.length - 1; i++) {
    if (i == segments.length - 2) continue;
    if (segmentsCross(newSeg.$1, newSeg.$2, segments[i].$1, segments[i].$2)) {
      return true;
    }
  }
  return false;
}

double strokeTravelDistance(List<GamePoint> stroke) {
  if (stroke.length < 2) return 0;
  var dist = 0.0;
  for (var i = 1; i < stroke.length; i++) {
    final dx = stroke[i].x - stroke[i - 1].x;
    final dy = stroke[i].y - stroke[i - 1].y;
    dist += math.sqrt(dx * dx + dy * dy);
  }
  return dist;
}
