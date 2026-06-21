import 'dart:math' as math;

import 'package:flame/extensions.dart';

import 'constants.dart';
import 'models.dart';
import 'territory_manager.dart';

/// P2 AI — 배치·발사 계획 (고난이도)
class AiController {
  AiController({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;

  static const aiPlayer = PlayerId.p2;
  static const humanPlayer = PlayerId.p1;

  /// 상대 코너 쪽 끝에 배치해 1타 관통 각도 극대화
  Offset planPlacement(TerritoryManager territory) {
    final center = territory.getCornerCenter(aiPlayer);
    final f = territory.playfield;
    final fieldCenter = Offset(f.x + f.w / 2, f.y + f.h / 2);

    // 코너 → 필드 중심 방향으로 최대한 밀착 배치
    final dx = fieldCenter.dx - center.dx;
    final dy = fieldCenter.dy - center.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final dir = len > 0 ? Offset(dx / len, dy / len) : const Offset(-1, 1);

    final reach = WorldConfig.cornerZoneRadius * 0.78;
    final jitter = (_rng.nextDouble() - 0.5) * 6;

    return territory.clampPlacement(
      center.dx + dir.dx * reach + dir.dy * jitter * 0.3,
      center.dy + dir.dy * reach - dir.dx * jitter * 0.3,
      aiPlayer,
    );
  }

  /// 슬링샷 당김 손가락 위치 (launch = marble - finger 방향)
  Vector2 planPullFinger({
    required TerritoryManager territory,
    required Vector2 marblePos,
    required int shotNumber,
    required bool leftStartZone,
  }) {
    final from = Offset(marblePos.x, marblePos.y);
    Offset launchDir;
    double power;

    if (shotNumber == 1 && !leftStartZone) {
      launchDir = _planInvadeDirection(territory, from);
      power = 0.96;
    } else if (shotNumber == 2 && leftStartZone) {
      // 2타: 본진 복귀 (거리 기반 파워)
      launchDir = _planReturnDirection(territory, from);
      power = territory.estimateReturnPower(from, aiPlayer);
    } else {
      // 3타 또는 잔여: 정밀 복귀
      launchDir = _planReturnDirection(territory, from);
      power = territory.estimateReturnPower(from, aiPlayer).clamp(0.7, 0.98);
    }

    // 약간의 오차 (고난이도지만 완벽하지 않게)
    final aimNoise = (shotNumber == 1) ? 0.015 : 0.025;
    launchDir = _rotateDir(launchDir, (_rng.nextDouble() - 0.5) * aimNoise);

    final pullDist = GameConfig.maxPullDistance * power;
    return marblePos -
        Vector2(launchDir.dx * pullDist, launchDir.dy * pullDist);
  }

  Offset _planInvadeDirection(TerritoryManager territory, Offset from) {
    final target = territory.findInvadeTarget(from, humanPlayer);
    var dx = target.dx - from.dx;
    var dy = target.dy - from.dy;
    var len = math.sqrt(dx * dx + dy * dy);

    if (len < 1) {
      return const Offset(-0.7, 0.7);
    }

    // 여러 각도 후보 중 상대 영토 중심을 가장 잘 관통하는 방향 선택
    final baseAngle = math.atan2(dy, dx);
    final oppCenter = territory.getTerritoryCenter(humanPlayer);
    var bestDir = Offset(dx / len, dy / len);
    var bestScore = -double.infinity;

    for (var i = -2; i <= 2; i++) {
      final angle = baseAngle + i * 0.08;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final score = _scoreInvadeAngle(from, dir, oppCenter, territory);
      if (score > bestScore) {
        bestScore = score;
        bestDir = dir;
      }
    }
    return bestDir;
  }

  double _scoreInvadeAngle(
    Offset from,
    Offset dir,
    Offset oppCenter,
    TerritoryManager territory,
  ) {
    // 가상 궤적 샘플 — 상대 영토 관통 깊이 평가
    const steps = 6;
    const stepLen = 55.0;
    var penetrated = 0;
    var distToOppCenter = double.infinity;

    for (var i = 1; i <= steps; i++) {
      final p = Offset(
        from.dx + dir.dx * stepLen * i,
        from.dy + dir.dy * stepLen * i,
      );
      if (territory.isOutOfPlayfield(p.dx, p.dy)) return -1000;
      if (territory.isOnTerritory(p.dx, p.dy, humanPlayer)) {
        penetrated++;
      }
      final d = (p - oppCenter).distance;
      if (d < distToOppCenter) distToOppCenter = d;
    }

    return penetrated * 12.0 - distToOppCenter * 0.05;
  }

  Offset _planReturnDirection(TerritoryManager territory, Offset from) {
    final home = territory.getStartZoneAnchor(aiPlayer);
    var dx = home.dx - from.dx;
    var dy = home.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return const Offset(-1, 1);
    return Offset(dx / len, dy / len);
  }

  Offset _rotateDir(Offset dir, double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Offset(dir.dx * c - dir.dy * s, dir.dx * s + dir.dy * c);
  }
}
