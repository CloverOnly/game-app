export type PlayerId = 1 | 2;

export type TurnResult =
  | 'playing'
  | 'claimed'
  | 'failed_bounces'
  | 'failed_out'
  | 'failed_penalty';

export interface PlayerConfig {
  id: PlayerId;
  name: string;
  color: number;
  trailColor: number;
  baseColor: number;
}

export interface GameConfig {
  maxBounces: number;
  matchDurationSec: number;
  marbleRadius: number;
  launchPowerScale: number;
  minLaunchSpeed: number;
  maxLaunchSpeed: number;
}

export interface Point {
  x: number;
  y: number;
}
