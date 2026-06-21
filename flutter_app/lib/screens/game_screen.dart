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
          SafeArea(
            child: Column(
              children: [
                _HudBar(hud: hud),
                const Spacer(),
                _BottomHud(hud: hud),
              ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF444444)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hud.status ?? '',
                    style: const TextStyle(
                      color: Color(0xFF7AB3F0),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  hud.bounceText,
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
                ),
              ],
            ),
            if (hud.debugLines.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                hud.debugLines.first,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(10),
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
    fontSize: 14,
    color: color,
    fontWeight: FontWeight.bold,
    shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
  );
}
