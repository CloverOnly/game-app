import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/land_grabber_game.dart';
import '../game/models.dart';
import '../widgets/adaptive_asset_image.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode});

  final GameMode mode;

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
      gameMode: widget.mode,
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
      onGameOver: (result) {
        if (!mounted) return;
        _showGameOverDialog(result);
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

  PlayerId? get _humanPlayerId {
    return switch (widget.mode) {
      GameMode.ai || GameMode.pvp => PlayerId.p1,
      GameMode.local => null,
    };
  }

  void _showGameOverDialog(GameOverResult result) {
    final scale = adaptiveScale(context);
    final content = _gameOverContent(result);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A1F14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16 * scale),
          side: BorderSide(color: content.accent.withValues(alpha: 0.6), width: 2),
        ),
        title: Row(
          children: [
            Icon(content.icon, color: content.accent, size: 28 * scale),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Text(
                content.title,
                style: TextStyle(
                  color: content.accent,
                  fontSize: adaptiveFont(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          content.message,
          style: TextStyle(
            color: const Color(0xFFFFF3E0),
            fontSize: adaptiveFont(context, 14),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: Text(
              '확인',
              style: TextStyle(
                color: content.accent,
                fontSize: adaptiveFont(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _GameOverContent _gameOverContent(GameOverResult result) {
    if (result.isDraw) {
      return const _GameOverContent(
        title: '무승부',
        message: '점수가 동점입니다!',
        icon: Icons.handshake_outlined,
        accent: Color(0xFFB0BEC5),
      );
    }

    if (widget.mode == GameMode.local) {
      return _GameOverContent(
        title: '${result.winnerName} 승리!',
        message: '경기가 종료되었습니다.',
        icon: Icons.emoji_events_outlined,
        accent: result.winnerId == PlayerId.p1
            ? const Color(0xFF7AB3F0)
            : const Color(0xFFF09090),
      );
    }

    final human = _humanPlayerId;
    if (human != null && result.winnerId == human) {
      return const _GameOverContent(
        title: '승리!',
        message: '축하합니다! 승리했습니다!',
        icon: Icons.emoji_events,
        accent: Color(0xFFFFD54F),
      );
    }

    return const _GameOverContent(
      title: '패배',
      message: '패배했습니다. 다시 도전해 보세요!',
      icon: Icons.sentiment_dissatisfied_outlined,
      accent: Color(0xFFEF9A9A),
    );
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

class _GameOverContent {
  const _GameOverContent({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accent;
}
