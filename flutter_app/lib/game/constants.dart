import 'models.dart';

class GameConfig {
  static const maxBounces = 3;
  static const matchDurationSec = 180;
  static const marbleRadius = 14.0;
  static const launchPowerScale = 0.08;
  static const minLaunchSpeed = 3.0;
  static const maxLaunchSpeed = 18.0;
}

class WorldConfig {
  static const width = 540.0;
  static const height = 960.0;
  static const wallThickness = 20.0;
  static const baseSize = 100.0;
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
