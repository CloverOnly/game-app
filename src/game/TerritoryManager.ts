import Phaser from 'phaser';
import type { PlayerId, Point } from '../types';
import { PLAYERS, WORLD } from './constants';

interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/**
 * 영토를 RenderTexture(시각) + 폴리곤/사각형(판정)으로 관리.
 */
export class TerritoryManager {
  private scene: Phaser.Scene;
  private rt: Phaser.GameObjects.RenderTexture;
  private width: number;
  private height: number;

  private bases: Record<PlayerId, Rect>;
  private polygons: Record<PlayerId, Point[][]>;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    this.width = WORLD.width;
    this.height = WORLD.height;
    this.polygons = { 1: [], 2: [] };

    const margin = WORLD.wallThickness + 8;
    const size = WORLD.baseSize;
    this.bases = {
      1: { x: margin, y: this.height - margin - size, w: size, h: size },
      2: { x: this.width - margin - size, y: margin, w: size, h: size },
    };

    this.rt = scene.add.renderTexture(0, 0, this.width, this.height).setOrigin(0, 0);
    this.rt.setDepth(0);
    this.rt.fill(0xf5e6c8, 1);
    this.drawBases();
  }

  private drawBases(): void {
    for (const id of [1, 2] as PlayerId[]) {
      const b = this.bases[id];
      this.fillRect(b.x, b.y, b.w, b.h, PLAYERS[id].baseColor);
    }
  }

  private fillRect(x: number, y: number, w: number, h: number, color: number): void {
    const g = this.scene.make.graphics({ x: 0, y: 0 });
    g.fillStyle(color, 0.85);
    g.fillRect(x, y, w, h);
    this.rt.draw(g, 0, 0);
    g.destroy();
  }

  claimTerritory(playerId: PlayerId, path: Point[]): void {
    if (path.length < 3) return;

    this.polygons[playerId].push([...path]);

    const color = PLAYERS[playerId].color;
    const g = this.scene.make.graphics({ x: 0, y: 0 });

    g.fillStyle(color, 0.75);
    g.beginPath();
    g.moveTo(path[0].x, path[0].y);
    for (let i = 1; i < path.length; i++) {
      g.lineTo(path[i].x, path[i].y);
    }
    g.closePath();
    g.fillPath();

    g.lineStyle(3, PLAYERS[playerId].baseColor, 0.9);
    g.beginPath();
    g.moveTo(path[0].x, path[0].y);
    for (let i = 1; i < path.length; i++) {
      g.lineTo(path[i].x, path[i].y);
    }
    g.closePath();
    g.strokePath();

    this.rt.draw(g, 0, 0);
    g.destroy();
  }

  isOnTerritory(x: number, y: number, playerId: PlayerId): boolean {
    const base = this.bases[playerId];
    if (pointInRect(x, y, base)) return true;

    for (const poly of this.polygons[playerId]) {
      if (pointInPolygon(x, y, poly)) return true;
    }
    return false;
  }

  isOnOpponentBase(x: number, y: number, playerId: PlayerId): boolean {
    const opponent: PlayerId = playerId === 1 ? 2 : 1;
    return pointInRect(x, y, this.bases[opponent]);
  }

  getTerritoryRatio(playerId: PlayerId): number {
    const totalArea = this.width * this.height;
    let area = this.bases[playerId].w * this.bases[playerId].h;

    for (const poly of this.polygons[playerId]) {
      area += polygonArea(poly);
    }

    return Math.min(area / totalArea, 1);
  }

  getBaseCenter(playerId: PlayerId): Point {
    const b = this.bases[playerId];
    return { x: b.x + b.w / 2, y: b.y + b.h / 2 };
  }
}

function pointInRect(x: number, y: number, r: Rect): boolean {
  return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
}

function pointInPolygon(x: number, y: number, poly: Point[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const xi = poly[i].x;
    const yi = poly[i].y;
    const xj = poly[j].x;
    const yj = poly[j].y;
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

function polygonArea(poly: Point[]): number {
  let area = 0;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    area += (poly[j].x + poly[i].x) * (poly[j].y - poly[i].y);
  }
  return Math.abs(area / 2);
}
