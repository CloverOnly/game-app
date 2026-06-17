import 'models.dart';

class GameConfig {
  static const maxShotsPerTurn = 3;
  static const matchDurationSec = 180;
  static const marbleRadius = 14.0;
  static const launchPowerScale = 0.12;
  static const minLaunchSpeed = 2.0;
  static const maxLaunchSpeed = 22.0;
  static const maxPullDistance = 140.0;
  static const minPullDistance = 12.0;
}

class WorldConfig {
  static const width = 540.0;
  static const height = 960.0;
  static const wallThickness = 20.0;
  /// 모서리 시작 구역(1/4 원) 반지름
  static const cornerZoneRadius = 72.0;
  static const fieldMargin = 36.0;
}

class PhysicsConfig {
  static const friction = 0.02;
  static const linearDamping = 1.2;
  static const restitution = 0.75;
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
