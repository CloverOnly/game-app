import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/models.dart';
import '../game/land_grabber_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final LandGrabberGame game;
  GameHudState hud = const GameHudState(
    p1Percent: '0.0',
    p2Percent: '0.0',
    timeText: '3:00',
    bounceText: '발사: 0 / 3',
    status: '',
  );
  Timer? _matchTimer;

  @override
  void initState() {
    super.initState();
    game = LandGrabberGame(
      onHudUpdate: (state) {
        if (!mounted) return;
        setState(() {
          hud = GameHudState(
            p1Percent: state.p1Percent,
            p2Percent: state.p2Percent,
            timeText: state.timeText,
            bounceText: state.bounceText,
            status: state.status ?? hud.status,
            phase: state.phase ?? hud.phase,
          );
        });
      },
      onGameOver: (winner) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pop();
        });
      },
    );

    _matchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      game.tickMatchTimer();
    });
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            _HudBar(hud: hud),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 540 / 960,
                  child: GameWidget(game: game),
                ),
              ),
            ),
            if (hud.status != null && hud.status!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  children: [
                    if (hud.phase == GameState.placing)
                      Text(
                        '① 모서리 탭해 위치 선택 → ② 돌 탭 → ③ 뒤로 당겨 발사 (최대 3회)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      hud.status!,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HudBar extends StatelessWidget {
  const _HudBar({required this.hud});

  final GameHudState hud;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            '🔵 ${hud.p1Percent}%',
            style: _style(const Color(0xFF7AB3F0)),
          ),
          const Spacer(),
          Text('⏱ ${hud.timeText}', style: _style(Colors.white)),
          const Spacer(),
          Text(
            '🔴 ${hud.p2Percent}%',
            style: _style(const Color(0xFFF09090)),
          ),
        ],
      ),
    );
  }

  TextStyle _style(Color color) => TextStyle(
    fontSize: 16,
    color: color,
    fontWeight: FontWeight.bold,
    shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
  );
}
