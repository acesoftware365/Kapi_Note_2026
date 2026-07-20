import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../constants/audio_assets.dart';
import '../../services/audio_manager.dart';
import '../domino_player_profile.dart';

class MatchFoundTransitionScreen extends StatefulWidget {
  const MatchFoundTransitionScreen({
    super.key,
    required this.gameId,
    required this.player,
    required this.playerPoints,
    required this.opponent,
    required this.opponentPoints,
  });

  final String gameId;
  final DominoPlayerProfile player;
  final int playerPoints;
  final DominoPlayerProfile opponent;
  final int opponentPoints;

  @override
  State<MatchFoundTransitionScreen> createState() =>
      _MatchFoundTransitionScreenState();
}

class _MatchFoundTransitionScreenState extends State<MatchFoundTransitionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _openTimer;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..forward();
    unawaited(AudioManager.instance.initialize());
    unawaited(AudioManager.instance.playSfx(AudioAssets.playerJoined));
    Future<void>.delayed(const Duration(milliseconds: 1450), () {
      if (mounted) {
        unawaited(AudioManager.instance.playSfx(AudioAssets.gameStart));
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 2750), () {
      if (mounted) {
        unawaited(AudioManager.instance.playSfx(AudioAssets.success));
      }
    });
    _openTimer = Timer(const Duration(milliseconds: 4100), _openGame);
  }

  @override
  void dispose() {
    _openTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openGame() async {
    if (_opened || !mounted) return;
    _opened = true;
    unawaited(AudioManager.instance.playSfx(AudioAssets.dominoShuffle));
    await Navigator.pushNamed(
      context,
      '/domino-online',
      arguments: {
        'gameId': widget.gameId,
        'playerId': widget.player.publicId.toUpperCase(),
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      backgroundColor: const Color(0xFF071524),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final panels = Curves.easeOutCubic.transform(
            (progress / 0.35).clamp(0.0, 1.0),
          );
          final impact = Curves.elasticOut.transform(
            ((progress - 0.28) / 0.30).clamp(0.0, 1.0),
          );
          final impactFlash = sin(
            (((progress - 0.30) / 0.20).clamp(0.0, 1.0)) * pi,
          );
          final cards = Curves.easeOutBack.transform(
            ((progress - 0.40) / 0.34).clamp(0.0, 1.0),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: Transform.translate(
                        offset: Offset((1 - panels) * 260, 0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF8E0D0A), Color(0xFF4B0706)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: Offset((panels - 1) * 260, 0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF123B66), Color(0xFF071524)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ElectricSeamPainter(
                    progress: progress,
                    impactFlash: impactFlash,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        spanish ? 'JUGADOR ENCONTRADO' : 'PLAYER FOUND',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: cards.clamp(0, 1),
                        child: Transform.translate(
                          offset: Offset((1 - cards) * -90, 0),
                          child: _PlayerVersusCard(
                            profile: widget.player,
                            points: widget.playerPoints,
                            alignment: CrossAxisAlignment.start,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Transform.scale(
                        scale: max(0.01, impact),
                        child: Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            color: const Color(0xFF101820),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFD36B),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xAA63E6FF),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: cards.clamp(0, 1),
                        child: Transform.translate(
                          offset: Offset((1 - cards) * 90, 0),
                          child: _PlayerVersusCard(
                            profile: widget.opponent,
                            points: widget.opponentPoints,
                            alignment: CrossAxisAlignment.end,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        spanish
                            ? 'PREPARANDO PARTIDA...'
                            : 'PREPARING MATCH...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: progress,
                        color: const Color(0xFFFFD36B),
                        backgroundColor: Colors.white24,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlayerVersusCard extends StatelessWidget {
  const _PlayerVersusCard({
    required this.profile,
    required this.points,
    required this.alignment,
  });

  final DominoPlayerProfile profile;
  final int points;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final tier = DominoTierVisual.fromScore(points);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xE6101820),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tier.frameColor(active: true), width: 2),
        boxShadow: tier.shadows(active: true),
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment:
                alignment == CrossAxisAlignment.start
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
            children: [
              CircleAvatar(
                backgroundColor: tier.deep,
                child: Text(
                  profile.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  profile.publicId,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${profile.countryCode} · ${tier.label} · $points pts',
            style: TextStyle(color: tier.accent, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ElectricSeamPainter extends CustomPainter {
  const _ElectricSeamPainter({
    required this.progress,
    required this.impactFlash,
  });

  final double progress;
  final double impactFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = ((progress - 0.22) / 0.45).clamp(0.0, 1.0);
    if (visible <= 0) return;
    final random = Random(24);
    final path = Path()..moveTo(0, size.height / 2);
    for (var x = 0.0; x <= size.width; x += 18) {
      final y = size.height / 2 + (random.nextDouble() - 0.5) * 22 * visible;
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF75F4FF).withValues(alpha: visible)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: visible)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    if (impactFlash > 0) {
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(
        center,
        58 + (42 * impactFlash),
        Paint()
          ..color = const Color(
            0xFF75F4FF,
          ).withValues(alpha: 0.20 * impactFlash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
      final rayPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85 * impactFlash)
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round;
      for (var index = 0; index < 14; index++) {
        final angle = (pi * 2 * index / 14) + 0.12;
        final start = 54.0 + (8 * (index % 3));
        final end = start + 34 + (22 * impactFlash);
        canvas.drawLine(
          center + Offset(cos(angle) * start, sin(angle) * start),
          center + Offset(cos(angle) * end, sin(angle) * end),
          rayPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ElectricSeamPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.impactFlash != impactFlash;
}
