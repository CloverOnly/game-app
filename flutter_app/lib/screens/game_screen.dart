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
            _DebugPanel(hud: hud),
          ],
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.hud});

  final GameHudState hud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF444444)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hud.status != null && hud.status!.isNotEmpty)
            Text(
              hud.status!,
              style: const TextStyle(
                color: Color(0xFF7AB3F0),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          if (hud.debugInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              hud.debugInfo!,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
            ),
          ],
          if (hud.debugLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              '🐛 디버그 로그',
              style: TextStyle(color: Color(0xFFFFCC00), fontSize: 11),
            ),
            ...hud.debugLines.take(5).map(
              (line) => Text(
                line,
                style: const TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
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
