import type { PlayerId, TurnResult } from '../types';
import { GAME_CONFIG } from './constants';

export class TurnManager {
  currentPlayer: PlayerId = 1;
  bounceCount = 0;
  isLaunched = false;
  turnActive = false;
  leftBase = false;
  pathPointCount = 0;

  startTurn(): void {
    this.bounceCount = 0;
    this.isLaunched = false;
    this.turnActive = true;
    this.leftBase = false;
    this.pathPointCount = 0;
  }

  onLaunch(): void {
    this.isLaunched = true;
    this.leftBase = true;
  }

  onBounce(): void {
    this.bounceCount++;
  }

  canStillBounce(): boolean {
    return this.bounceCount < GAME_CONFIG.maxBounces;
  }

  recordPathPoint(): void {
    this.pathPointCount++;
  }

  switchPlayer(): void {
    this.currentPlayer = this.currentPlayer === 1 ? 2 : 1;
    this.turnActive = false;
  }

  evaluateTurn(
    onOwnTerritory: boolean,
    onOpponentBase: boolean,
    outOfBounds: boolean,
    isStopped: boolean,
  ): TurnResult {
    if (!this.isLaunched) return 'playing';

    if (outOfBounds) return 'failed_out';
    if (onOpponentBase && this.leftBase) return 'failed_penalty';

    if (onOwnTerritory && this.leftBase && isStopped) {
      if (this.bounceCount <= GAME_CONFIG.maxBounces) {
        return 'claimed';
      }
      return 'failed_bounces';
    }

    if (isStopped && this.leftBase) {
      if (this.bounceCount > GAME_CONFIG.maxBounces) return 'failed_bounces';
      if (!onOwnTerritory) return 'failed_bounces';
    }

    return 'playing';
  }
}
