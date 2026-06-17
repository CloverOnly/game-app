import Phaser from 'phaser';
import { GAME_CONFIG, PHYSICS, PLAYERS, WORLD } from '../game/constants';
import { TerritoryManager } from '../game/TerritoryManager';
import { TurnManager } from '../game/TurnManager';
import type { PlayerId, Point, TurnResult } from '../types';

type GameState = 'aiming' | 'moving' | 'resolving' | 'gameover';

export class GameScene extends Phaser.Scene {
  private territory!: TerritoryManager;
  private turn!: TurnManager;

  private marble!: Phaser.Physics.Matter.Image;
  private trailGfx!: Phaser.GameObjects.Graphics;
  private aimGfx!: Phaser.GameObjects.Graphics;
  private walls: Phaser.Physics.Matter.Image[] = [];

  private path: Point[] = [];
  private state: GameState = 'aiming';
  private matchTimeLeft = GAME_CONFIG.matchDurationSec;

  private hudText!: Phaser.GameObjects.Text;
  private statusText!: Phaser.GameObjects.Text;
  private bounceText!: Phaser.GameObjects.Text;

  private dragStart: Point | null = null;
  private isDragging = false;

  constructor() {
    super({ key: 'GameScene' });
  }

  create(): void {
    this.territory = new TerritoryManager(this);
    this.turn = new TurnManager();

    this.createWalls();
    this.createMarble();
    this.createUI();

    this.trailGfx = this.add.graphics().setDepth(5);
    this.aimGfx = this.add.graphics().setDepth(10);

    this.setupInput();
    this.setupCollisions();
    this.startNewTurn();

    this.time.addEvent({
      delay: 1000,
      loop: true,
      callback: () => {
        if (this.state === 'gameover') return;
        this.matchTimeLeft--;
        if (this.matchTimeLeft <= 0) this.endMatch();
      },
    });
  }

  private createWalls(): void {
    const { width, height, wallThickness } = WORLD;
    const wallOpts: Phaser.Types.Physics.Matter.MatterBodyConfig = {
      isStatic: true,
      friction: 0.1,
      restitution: 0.8,
      label: 'wall',
    };

    const walls = [
      { x: width / 2, y: -wallThickness / 2, w: width, h: wallThickness },
      { x: width / 2, y: height + wallThickness / 2, w: width, h: wallThickness },
      { x: -wallThickness / 2, y: height / 2, w: wallThickness, h: height },
      { x: width + wallThickness / 2, y: height / 2, w: wallThickness, h: height },
    ];

    for (const w of walls) {
      const wall = this.matter.add.image(w.x, w.y, 'pixel', undefined, wallOpts);
      wall.setDisplaySize(w.w, w.h);
      wall.setVisible(false);
      this.walls.push(wall);
    }
  }

  private createMarble(): void {
    const pos = this.territory.getBaseCenter(1);
    this.marble = this.matter.add.image(pos.x, pos.y, 'marble', undefined, {
      shape: { type: 'circle', radius: GAME_CONFIG.marbleRadius },
      friction: PHYSICS.friction,
      frictionAir: PHYSICS.frictionAir,
      restitution: PHYSICS.restitution,
      density: PHYSICS.density,
      label: 'marble',
    });
    this.marble.setDepth(20);
    this.marble.setCircle(GAME_CONFIG.marbleRadius);
  }

  private createUI(): void {
    const style: Phaser.Types.GameObjects.Text.TextStyle = {
      fontFamily: 'Arial, sans-serif',
      fontSize: '18px',
      color: '#ffffff',
      stroke: '#000000',
      strokeThickness: 3,
    };

    this.hudText = this.add.text(16, 16, '', style).setDepth(100);
    this.statusText = this.add
      .text(WORLD.width / 2, 50, '', { ...style, fontSize: '22px' })
      .setOrigin(0.5, 0)
      .setDepth(100);
    this.bounceText = this.add.text(16, 44, '', style).setDepth(100);

    // 플레이 영역 테두리 장식
    const border = this.add.graphics().setDepth(2);
    border.lineStyle(4, 0x8b6914, 1);
    border.strokeRect(
      WORLD.wallThickness,
      WORLD.wallThickness,
      WORLD.width - WORLD.wallThickness * 2,
      WORLD.height - WORLD.wallThickness * 2,
    );
  }

  private setupInput(): void {
    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      if (this.state !== 'aiming') return;

      const dist = Phaser.Math.Distance.Between(pointer.x, pointer.y, this.marble.x, this.marble.y);
      if (dist < GAME_CONFIG.marbleRadius * 4) {
        this.isDragging = true;
        this.dragStart = { x: pointer.x, y: pointer.y };
      }
    });

    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      if (!this.isDragging || this.state !== 'aiming') return;
      this.drawAim(pointer.x, pointer.y);
    });

    this.input.on('pointerup', (pointer: Phaser.Input.Pointer) => {
      if (!this.isDragging || this.state !== 'aiming') return;
      this.isDragging = false;
      this.aimGfx.clear();

      if (!this.dragStart) return;

      const dx = this.dragStart.x - pointer.x;
      const dy = this.dragStart.y - pointer.y;
      const speed = Phaser.Math.Clamp(
        Math.sqrt(dx * dx + dy * dy) * GAME_CONFIG.launchPowerScale,
        GAME_CONFIG.minLaunchSpeed,
        GAME_CONFIG.maxLaunchSpeed,
      );

      if (speed < GAME_CONFIG.minLaunchSpeed) return;

      const angle = Math.atan2(dy, dx);
      this.launchMarble(Math.cos(angle) * speed, Math.sin(angle) * speed);
      this.dragStart = null;
    });
  }

  private setupCollisions(): void {
    this.matter.world.on('collisionstart', (event: Phaser.Physics.Matter.Events.CollisionStartEvent) => {
      if (this.state !== 'moving') return;

      for (const pair of event.pairs) {
        const labels = [pair.bodyA.label, pair.bodyB.label];
        if (labels.includes('marble') && labels.includes('wall')) {
          this.turn.onBounce();
          this.playBounceEffect();
        }
      }
    });
  }

  private drawAim(pointerX: number, pointerY: number): void {
    if (!this.dragStart) return;

    this.aimGfx.clear();

    const dx = this.dragStart.x - pointerX;
    const dy = this.dragStart.y - pointerY;
    const len = Math.min(Math.sqrt(dx * dx + dy * dy), 120);

    if (len < 5) return;

    const nx = dx / Math.sqrt(dx * dx + dy * dy);
    const ny = dy / Math.sqrt(dx * dx + dy * dy);

    const startX = this.marble.x;
    const startY = this.marble.y;
    const endX = startX + nx * len;
    const endY = startY + ny * len;

    const player = PLAYERS[this.turn.currentPlayer];

    // 조준선
    this.aimGfx.lineStyle(3, player.trailColor, 0.8);
    this.aimGfx.beginPath();
    this.aimGfx.moveTo(startX, startY);
    this.aimGfx.lineTo(endX, endY);
    this.aimGfx.strokePath();

    // 당기는 방향 (반대)
    this.aimGfx.lineStyle(2, 0xffffff, 0.4);
    this.aimGfx.beginPath();
    this.aimGfx.moveTo(startX, startY);
    this.aimGfx.lineTo(startX - nx * len * 0.5, startY - ny * len * 0.5);
    this.aimGfx.strokePath();

    // 파워 링
    const power = len / 120;
    this.aimGfx.lineStyle(2, player.color, 0.5 + power * 0.5);
    this.aimGfx.strokeCircle(startX, startY, GAME_CONFIG.marbleRadius + 4 + power * 10);
  }

  private launchMarble(vx: number, vy: number): void {
    this.state = 'moving';
    this.turn.onLaunch();
    this.path = [{ x: this.marble.x, y: this.marble.y }];

    this.marble.setVelocity(vx, vy);
    this.statusText.setText('날아가는 중...');
  }

  private playBounceEffect(): void {
    this.cameras.main.shake(80, 0.003);
    // TODO: 효과음 - 돌 튕기는 '딱!' 소리
  }

  update(): void {
    this.updateHUD();

    if (this.state === 'moving') {
      this.updateMoving();
    }
  }

  private updateMoving(): void {
    const x = this.marble.x;
    const y = this.marble.y;
    const playerId = this.turn.currentPlayer;

    // 궤적 기록 (일정 간격)
    const last = this.path[this.path.length - 1];
    if (!last || Phaser.Math.Distance.Between(last.x, last.y, x, y) > 6) {
      this.path.push({ x, y });
      this.turn.recordPathPoint();
      this.drawTrail();
    }

    const speed = Math.sqrt(this.marble.body.velocity.x ** 2 + this.marble.body.velocity.y ** 2);
    const isStopped = speed < 0.3;

    const outOfBounds =
      x < -GAME_CONFIG.marbleRadius ||
      x > WORLD.width + GAME_CONFIG.marbleRadius ||
      y < -GAME_CONFIG.marbleRadius ||
      y > WORLD.height + GAME_CONFIG.marbleRadius;

    const onOwnTerritory = this.territory.isOnTerritory(x, y, playerId);
    const onOpponentBase = this.territory.isOnOpponentBase(x, y, playerId);

    // 이동 중 상대 본진 관통 → 즉시 패널티
    if (onOpponentBase && this.turn.leftBase) {
      this.resolveTurn('failed_penalty');
      return;
    }

    // 4번째 튕김 이후 → 실패
    if (this.turn.bounceCount > GAME_CONFIG.maxBounces && !onOwnTerritory) {
      if (isStopped || !this.turn.canStillBounce()) {
        this.resolveTurn('failed_bounces');
        return;
      }
    }

    const result = this.turn.evaluateTurn(onOwnTerritory, onOpponentBase, outOfBounds, isStopped);

    if (result !== 'playing') {
      this.resolveTurn(result);
      return;
    }

    // 3회 튕김 초과 후 아직 멈추지 않음 → 계속 관찰
    if (!this.turn.canStillBounce() && !isStopped && !onOwnTerritory) {
      // 다음 충돌 없이 멈추면 실패 처리됨
    }
  }

  private drawTrail(): void {
    const player = PLAYERS[this.turn.currentPlayer];
    this.trailGfx.clear();
    this.trailGfx.lineStyle(4, player.trailColor, 0.9);

    if (this.path.length < 2) return;

    this.trailGfx.beginPath();
    this.trailGfx.moveTo(this.path[0].x, this.path[0].y);
    for (let i = 1; i < this.path.length; i++) {
      this.trailGfx.lineTo(this.path[i].x, this.path[i].y);
    }
    this.trailGfx.strokePath();
  }

  private resolveTurn(result: TurnResult): void {
    this.state = 'resolving';
    this.marble.setVelocity(0, 0);
    this.marble.setAngularVelocity(0);

    const playerId = this.turn.currentPlayer;

    switch (result) {
      case 'claimed':
        this.territory.claimTerritory(playerId, this.path);
        this.statusText.setText(`${PLAYERS[playerId].name} 땅 확보!`);
        this.cameras.main.flash(200, 255, 255, 200);
        break;
      case 'failed_bounces':
        this.statusText.setText('3번 안에 복귀 실패!');
        break;
      case 'failed_out':
        this.statusText.setText('아웃! 경기장 밖으로 나감');
        break;
      case 'failed_penalty':
        this.statusText.setText('상대 본진 관통! 패널티');
        break;
    }

    this.trailGfx.clear();

    this.time.delayedCall(1200, () => {
      this.turn.switchPlayer();
      this.startNewTurn();
    });
  }

  private startNewTurn(): void {
    if (this.state === 'gameover') return;

    this.turn.startTurn();
    this.state = 'aiming';
    this.path = [];

    const playerId = this.turn.currentPlayer;
    const pos = this.territory.getBaseCenter(playerId);
    this.marble.setPosition(pos.x, pos.y);
    this.marble.setVelocity(0, 0);
    this.marble.setAngularVelocity(0);
    this.marble.setTint(PLAYERS[playerId].color);

    this.statusText.setText(`${PLAYERS[playerId].name} 차례 - 망을 당겨 발사!`);
  }

  private updateHUD(): void {
    const p1 = (this.territory.getTerritoryRatio(1) * 100).toFixed(1);
    const p2 = (this.territory.getTerritoryRatio(2) * 100).toFixed(1);
    const min = Math.floor(this.matchTimeLeft / 60);
    const sec = this.matchTimeLeft % 60;

    this.hudText.setText(`🔵 ${p1}%  |  🔴 ${p2}%  |  ⏱ ${min}:${sec.toString().padStart(2, '0')}`);
    this.bounceText.setText(`튕김: ${this.turn.bounceCount} / ${GAME_CONFIG.maxBounces}`);
  }

  private endMatch(): void {
    this.state = 'gameover';
    const r1 = this.territory.getTerritoryRatio(1);
    const r2 = this.territory.getTerritoryRatio(2);

    let winner: string;
    if (r1 > r2) winner = PLAYERS[1].name;
    else if (r2 > r1) winner = PLAYERS[2].name;
    else winner = '무승부';

    this.statusText.setText(`게임 종료! 승자: ${winner}`);

    this.time.delayedCall(3000, () => {
      this.scene.start('MenuScene');
    });
  }
}
