import type { GameConfig, PlayerConfig } from '../types';

export const GAME_CONFIG: GameConfig = {
  maxBounces: 3,
  matchDurationSec: 180,
  marbleRadius: 14,
  launchPowerScale: 0.08,
  minLaunchSpeed: 3,
  maxLaunchSpeed: 18,
};

export const PLAYERS: Record<1 | 2, PlayerConfig> = {
  1: {
    id: 1,
    name: '플레이어 1',
    color: 0x4a90d9,
    trailColor: 0x7ab3f0,
    baseColor: 0x2d6cb5,
  },
  2: {
    id: 2,
    name: '플레이어 2',
    color: 0xe85d5d,
    trailColor: 0xf09090,
    baseColor: 0xc0392b,
  },
};

/** 논리 해상도 (세로 모바일 비율) */
export const WORLD = {
  width: 540,
  height: 960,
  wallThickness: 20,
  baseSize: 100,
};

export const PHYSICS = {
  friction: 0.02,
  frictionAir: 0.015,
  restitution: 0.75,
  density: 0.004,
};
