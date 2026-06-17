# 대격돌! 땅따먹기 (Land Grabber Mobile)

모바일 캐주얼 물리 대전 게임 프로토타입입니다.

## 현재 구현 (v0.1)

- **핵심 메커니즘**: 터치 드래그로 망 발사 (알까기 방식)
- **3회 튕김** 제한 및 실패 조건 (아웃, 본진 관통 패널티)
- **영토 점령**: 궤적이 자기 땅으로 복귀 시 폐곡선 영역 확보
- **1:1 로컬 대전** (3분 제한, 점유율 승패)
- **세로 모바일 비율** (540×960) 화면 최적화

## Flutter (모바일 테스트)

```bash
cd flutter_app
flutter pub get
flutter run
```

- Android 에뮬레이터 / iOS 시뮬레이터 / 실제 기기에서 실행
- Windows: `flutter run -d windows`
- Chrome: `flutter run -d chrome`

## 웹 프로토타입 (Phaser)

```bash
npm install
npm run dev
```

## 조작법

1. 자신의 망 근처를 터치
2. 당기는 방향 반대로 드래그 (파워 조절)
3. 손을 떼면 발사
4. 3번 튕기기 전에 내 땅(파란/빨간 영역)으로 돌아오면 영토 확보

## 기술 스택

- **Phaser 3** + Matter.js (2D 물리)
- **TypeScript** + **Vite**
- 향후 **Capacitor**로 Android/iOS 빌드 예정

## 로드맵

| 단계 | 내용 |
|------|------|
| v0.1 ✅ | 핵심 메커니즘 프로토타입 |
| v0.2 | 맵 오브젝트 (웅덩이, 모래밭, 유리) |
| v0.3 | 망 스킨 & 스탯 (무게/마찰력) |
| v0.4 | 온라인 1:1 매칭 |
| v0.5 | Capacitor 모바일 빌드 |

## 프로젝트 구조

```
src/
├── main.ts              # 게임 엔트리
├── types/               # 타입 정의
├── game/
│   ├── constants.ts     # 게임 설정
│   ├── TerritoryManager.ts  # 영토 시스템
│   └── TurnManager.ts       # 턴/튕김 관리
└── scenes/
    ├── BootScene.ts     # 에셋 로드
    ├── MenuScene.ts     # 메인 메뉴
    └── GameScene.ts     # 게임플레이
```
