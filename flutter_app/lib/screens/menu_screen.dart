import 'package:flutter/material.dart';

import '../widgets/adaptive_asset_image.dart';
import 'game_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const _matColor = Color(0xFF1A3328);
  static const _imageW = 1024.0;
  static const _imageH = 558.0;

  @override
  Widget build(BuildContext context) {
    final scale = adaptiveScale(context);

    return Scaffold(
      backgroundColor: _matColor,
      body: AdaptiveAssetImage(
        asset: 'assets/images/menu_background.png',
        intrinsicWidth: _imageW,
        intrinsicHeight: _imageH,
        backgroundColor: _matColor,
        overlay: Align(
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF1A1008).withValues(alpha: 0.72),
                  const Color(0xFF1A1008).withValues(alpha: 0.92),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.only(bottom: 4 * scale),
              child: Padding(
                padding: adaptivePadding(
                  context,
                  EdgeInsets.fromLTRB(16 * scale, 10 * scale, 16 * scale, 8 * scale),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _RuleChip(
                        scale: scale,
                        icon: '📍',
                        text: '원 안 탭 → 위치 선택 · 당겨서 발사 · 3타 안에 복귀!',
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _WoodStartButton(
                          scale: scale,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GameScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          'Flutter v0.1 프로토타입',
                          style: TextStyle(
                            fontSize: adaptiveFont(context, 10),
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({
    required this.scale,
    required this.icon,
    required this.text,
  });

  final double scale;
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF5C3D2E).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: const Color(0xFF8B6347), width: 1.5),
      ),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 16 * scale)),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFFFFF3E0),
                fontSize: adaptiveFont(context, 12),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WoodStartButton extends StatefulWidget {
  const _WoodStartButton({required this.scale, required this.onPressed});

  final double scale;
  final VoidCallback onPressed;

  @override
  State<_WoodStartButton> createState() => _WoodStartButtonState();
}

class _WoodStartButtonState extends State<_WoodStartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final pulse = 1.0 + _pulse.value * 0.03;
        return Transform.scale(scale: pulse, child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(18 * s),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * s),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF9B6B43),
                  Color(0xFF6B4423),
                  Color(0xFF4A2E14),
                ],
              ),
              border: Border.all(color: const Color(0xFFD4A574), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: const Color(0xFFFFE082),
                    size: 28 * s,
                  ),
                  SizedBox(width: 6 * s),
                  Text(
                    'vs AI 대전 시작',
                    style: TextStyle(
                      fontSize: adaptiveFont(context, 18),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFE082),
                      shadows: const [
                        Shadow(
                          color: Color(0xFF3E2723),
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
