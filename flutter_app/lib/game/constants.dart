import 'models.dart';

class GameConfig {
  static const maxShotsPerTurn = 3;
  static const matchDurationSec = 300;
  static const marbleRadius = 14.0;
  static const marbleVisualScale = 2.0;
  static const launchPowerScale = 0.95;
  static const minLaunchSpeed = 14.0;
  static const maxLaunchSpeed = 150.0;
  /// 구슬이 멈췄다고 판정하는 속도 (이하)
  static const marbleStopSpeed = 4.0;
  /// 턴 종료 메시지 표시 후 다음 턴까지 대기 (ms)
  static const turnResolveDelayMs = 350;
  static const maxPullDistance = 140.0;
  static const minPullDistance = 6.0;
  /// 발사 후 유효 이동으로 인정하는 최소 거리 (미만이어도 타수 차감)
  static const minShotTravelDistance = 10.0;
  /// 발사 후 즉시 정지 판정 시간 (초)
  static const minShotDurationSec = 0.08;
  /// 복귀 시 시작 구역에서 흡수(정지)하는 최대 속도
  static const homeCaptureMaxSpeed = 28.0;
  /// 저속 구간 조기 정지 속도·시간
  static const earlyStopSpeed = 9.0;
  static const earlyStopMinTimeSec = 0.12;
  /// 이 거리 이상 벗어난 뒤에만 복귀(홈) 보조 적용
  static const minDepartureForReturn = 55.0;
  /// 복귀 판정: 최대 이탈 거리 대비 이만큼 가까워져야 '되돌아옴'
  static const homeReturnMinDelta = 20.0;
  /// 상대 시작 본진(코너) 면적의 이 비율 이상 점령 시 즉시 승리
  static const opponentStartZoneCaptureWinRatio = 0.5;
}

class WorldConfig {
  /// 가로 모드 (landscape)
  static const width = 960.0;
  static const height = 540.0;
  /// 모서리 시작 구역(1/4 원) 반지름
  static const cornerZoneRadius = 84.0;
  static const fieldMargin = 36.0;
}

class PhysicsConfig {
  static const friction = 0.02;
  static const linearDamping = 0.48;
  static const restitution = 0.38;
  static const density = 1.0;
}

const players = <PlayerId, PlayerConfig>{
  PlayerId.p1: PlayerConfig(
    id: PlayerId.p1,
    name: '플레이어 1',
    color: 0xFF4A90D9,
    trailColor: 0xFF7AB3F0,
    baseColor: 0xFF2D6CB5,
  ),
  PlayerId.p2: PlayerConfig(
    id: PlayerId.p2,
    name: '플레이어 2',
    color: 0xFFE85D5D,
    trailColor: 0xFFF09090,
    baseColor: 0xFFC0392B,
  ),
};
