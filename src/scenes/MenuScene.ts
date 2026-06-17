import Phaser from 'phaser';
import { WORLD } from '../game/constants';

export class MenuScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MenuScene' });
  }

  create(): void {
    const { width, height } = WORLD;

    // 배경 그라데이션 느낌
    const bg = this.add.graphics();
    bg.fillGradientStyle(0x1a1a2e, 0x1a1a2e, 0x2d5a27, 0x2d5a27, 1);
    bg.fillRect(0, 0, width, height);

    // 타이틀
    this.add
      .text(width / 2, height * 0.22, '대격돌!', {
        fontFamily: 'Arial, sans-serif',
        fontSize: '52px',
        color: '#ffd700',
        stroke: '#8b4513',
        strokeThickness: 6,
      })
      .setOrigin(0.5);

    this.add
      .text(width / 2, height * 0.32, '땅따먹기', {
        fontFamily: 'Arial, sans-serif',
        fontSize: '40px',
        color: '#ffffff',
        stroke: '#333333',
        strokeThickness: 4,
      })
      .setOrigin(0.5);

    this.add
      .text(width / 2, height * 0.42, 'Land Grabber Mobile', {
        fontFamily: 'Arial, sans-serif',
        fontSize: '16px',
        color: '#aaaaaa',
      })
      .setOrigin(0.5);

    // 규칙 요약
    const rules = [
      '🪨 망을 당겨 발사하세요 (알까기 방식)',
      '🔄 최대 3번 튕길 수 있어요',
      '🗺️ 내 땅으로 돌아오면 영토 확보!',
      '⚠️ 상대 본진 관통 = 패널티',
    ];

    rules.forEach((rule, i) => {
      this.add
        .text(width / 2, height * 0.52 + i * 32, rule, {
          fontFamily: 'Arial, sans-serif',
          fontSize: '17px',
          color: '#e0e0e0',
        })
        .setOrigin(0.5);
    });

    // 시작 버튼
    const btnY = height * 0.78;
    const btn = this.add
      .text(width / 2, btnY, '▶  1:1 대전 시작', {
        fontFamily: 'Arial, sans-serif',
        fontSize: '28px',
        color: '#ffffff',
        backgroundColor: '#4a90d9',
        padding: { x: 32, y: 16 },
      })
      .setOrigin(0.5)
      .setInteractive({ useHandCursor: true });

    btn.on('pointerover', () => btn.setStyle({ backgroundColor: '#5aa0e9' }));
    btn.on('pointerout', () => btn.setStyle({ backgroundColor: '#4a90d9' }));
    btn.on('pointerdown', () => {
      this.cameras.main.fadeOut(300, 0, 0, 0);
      this.time.delayedCall(300, () => this.scene.start('GameScene'));
    });

    this.add
      .text(width / 2, height * 0.88, 'v0.1 프로토타입', {
        fontFamily: 'Arial, sans-serif',
        fontSize: '13px',
        color: '#666666',
      })
      .setOrigin(0.5);

    this.cameras.main.fadeIn(500);
  }
}
