import Phaser from 'phaser';
import { GAME_CONFIG } from '../game/constants';

export class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: 'BootScene' });
  }

  preload(): void {
    // 1x1 흰 픽셀 (벽 등에 사용)
    const pixel = this.make.graphics({ x: 0, y: 0 });
    pixel.fillStyle(0xffffff, 1);
    pixel.fillRect(0, 0, 1, 1);
    pixel.generateTexture('pixel', 1, 1);
    pixel.destroy();

    // 망(바둑돌) 텍스처
    const r = GAME_CONFIG.marbleRadius;
    const size = r * 2 + 4;
    const marble = this.make.graphics({ x: 0, y: 0 });

    // 그림자
    marble.fillStyle(0x000000, 0.25);
    marble.fillCircle(r + 3, r + 3, r);

    // 본체
    marble.fillStyle(0xf0f0f0, 1);
    marble.fillCircle(r + 1, r + 1, r);

    // 하이라이트
    marble.fillStyle(0xffffff, 0.7);
    marble.fillCircle(r - 4, r - 4, r * 0.35);

    // 테두리
    marble.lineStyle(2, 0x888888, 0.8);
    marble.strokeCircle(r + 1, r + 1, r);

    marble.generateTexture('marble', size, size);
    marble.destroy();
  }

  create(): void {
    this.scene.start('MenuScene');
  }
}
