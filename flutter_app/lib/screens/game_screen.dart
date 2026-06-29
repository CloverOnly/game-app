import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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
    timeText: '5:00',
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
            debugLines: state.debugLines,
            debugInfo: state.debugInfo ?? hud.debugInfo,
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
      backgroundColor: const Color(0xFF1A3328),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: GameWidget(game: game)),

          // 맨 위: 점수 · 타이머
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              minimum: EdgeInsets.zero,
              child: _HudBar(hud: hud),
            ),
          ),

          // 맨 아래: 턴 안내 · 발사 횟수
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: _BottomHud(hud: hud),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.hud});

  final GameHudState hud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xCC000000),
        border: Border(
          top: BorderSide(color: Color(0xFF333333)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hud.status ?? '',
              style: const TextStyle(
                color: Color(0xFF7AB3F0),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hud.bounceText,
            style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HudBar extends StatelessWidget {
  const _HudBar({required this.hud});

  final GameHudState hud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xCC000000),
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333)),
        ),
      ),
      child: Row(
        children: [
          Text('🔵 ${hud.p1Percent}%', style: _style(const Color(0xFF7AB3F0))),
          const Spacer(),
          Text('⏱ ${hud.timeText}', style: _style(Colors.white)),
          const Spacer(),
          Text('🔴 ${hud.p2Percent}%', style: _style(const Color(0xFFF09090))),
        ],
      ),
    );
  }

  TextStyle _style(Color color) => TextStyle(
    fontSize: 13,
    color: color,
    fontWeight: FontWeight.bold,
    shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
  );
}
