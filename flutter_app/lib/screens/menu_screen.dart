import 'package:flutter/material.dart';

import 'game_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF2D5A27)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                const Text(
                  '대격돌!',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                    shadows: [
                      Shadow(color: Color(0xFF8B4513), blurRadius: 2, offset: Offset(2, 2)),
                    ],
                  ),
                ),
                const Text(
                  '땅따먹기',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Land Grabber Mobile',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                ),
                const Spacer(),
                ...[
                  '🪨 망을 뒤로 당겨 발사 (파워 게이지)',
                  '🔄 턴당 최대 3번 발사',
                  '🗺️ 3번 안에 내 영토로 돌아오면 확보!',
                  '❌ 실패 시 이번 턴 선이 모두 지워짐',
                ].map(
                  (rule) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      rule,
                      style: const TextStyle(fontSize: 17, color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  ),
                  child: const Text(
                    '▶  1:1 대전 시작',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  'Flutter v0.1 프로토타입',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
