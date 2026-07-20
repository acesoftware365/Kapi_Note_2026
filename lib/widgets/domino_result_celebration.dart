import 'dart:math' as math;

import 'package:flutter/material.dart';

class DominoResultCelebration extends StatefulWidget {
  const DominoResultCelebration({
    super.key,
    required this.child,
    this.showConfetti = false,
  });

  final Widget child;
  final bool showConfetti;

  @override
  State<DominoResultCelebration> createState() =>
      _DominoResultCelebrationState();
}

class _DominoResultCelebrationState extends State<DominoResultCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, child) => CustomPaint(
              painter: _SplitResultPainter(
                progress: _controller.value,
                showConfetti: widget.showConfetti,
              ),
              child: child,
            ),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.08),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitResultPainter extends CustomPainter {
  const _SplitResultPainter({
    required this.progress,
    required this.showConfetti,
  });

  final double progress;
  final bool showConfetti;

  @override
  void paint(Canvas canvas, Size size) {
    final splitLeft = size.height * 0.43;
    final splitRight = size.height * 0.57;
    final redPath =
        Path()
          ..lineTo(size.width, 0)
          ..lineTo(size.width, splitRight)
          ..lineTo(0, splitLeft)
          ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFE42F36));
    final bluePath =
        Path()
          ..moveTo(0, splitLeft)
          ..lineTo(size.width, splitRight)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF1976D2));

    canvas.save();
    canvas.clipPath(redPath);
    _paintMovingDominoes(
      canvas,
      size,
      dx: -progress * 96,
      dy: -progress * 72,
      color: Colors.white.withValues(alpha: 0.10),
    );
    canvas.restore();

    canvas.save();
    canvas.clipPath(bluePath);
    _paintMovingDominoes(
      canvas,
      size,
      dx: progress * 96,
      dy: -progress * 72,
      color: Colors.white.withValues(alpha: 0.10),
    );
    canvas.restore();

    final divider =
        Path()
          ..moveTo(0, splitLeft)
          ..lineTo(size.width, splitRight);
    canvas.drawPath(
      divider,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    if (showConfetti) _paintConfetti(canvas, size);
  }

  void _paintMovingDominoes(
    Canvas canvas,
    Size size, {
    required double dx,
    required double dy,
    required Color color,
  }) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
    for (var row = -1; row < 10; row++) {
      for (var column = -1; column < 7; column++) {
        final x = (column * 76.0 + dx) % (size.width + 76) - 38;
        final y = (row * 72.0 + dy) % (size.height + 72) - 36;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 24, height: 42),
          const Radius.circular(5),
        );
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate((row + column).isEven ? -0.25 : 0.25);
        canvas.translate(-x, -y);
        canvas.drawRRect(rect, paint);
        canvas.drawLine(Offset(x - 10, y), Offset(x + 10, y), paint);
        canvas.restore();
      }
    }
  }

  void _paintConfetti(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFFD54F),
      Colors.white,
      Color(0xFF69F0AE),
      Color(0xFFFF80AB),
    ];
    double randomUnit(int seed, int salt) {
      final value = math.sin(seed * 12.9898 + salt * 78.233) * 43758.5453;
      return value - value.floorToDouble();
    }

    for (var i = 0; i < 46; i++) {
      final start = randomUnit(i, 1);
      final speed = 0.72 + randomUnit(i, 2) * 0.72;
      final phase = (start + progress * speed) % 1.0;
      final swaySpeed = 0.7 + randomUnit(i, 3) * 1.8;
      final swayAmount = 7.0 + randomUnit(i, 4) * 20.0;
      final sway = math.sin(
        phase * math.pi * 2 * swaySpeed + randomUnit(i, 5) * math.pi * 2,
      );
      final baseX = randomUnit(i, 6) * size.width;
      final sidewaysDrift = (phase - 0.5) * (randomUnit(i, 7) - 0.5) * 54;
      final x = baseX + sway * swayAmount + sidewaysDrift;
      final y = phase * (size.height + 40) - 20;
      final pieceWidth = 3.5 + randomUnit(i, 8) * 4.0;
      final pieceHeight = 7.0 + randomUnit(i, 9) * 8.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, y),
          width: pieceWidth,
          height: pieceHeight,
        ),
        const Radius.circular(2),
      );
      canvas.save();
      canvas.translate(x, y);
      final spinDirection = randomUnit(i, 10) > 0.5 ? 1.0 : -1.0;
      final spinSpeed = 1.0 + randomUnit(i, 11) * 3.5;
      canvas.rotate(
        spinDirection * phase * math.pi * 2 * spinSpeed + sway * 0.35,
      );
      canvas.translate(-x, -y);
      canvas.drawRRect(
        rect,
        Paint()
          ..isAntiAlias = true
          ..color = colors[i % colors.length].withValues(alpha: 0.90),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SplitResultPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      showConfetti != oldDelegate.showConfetti;
}
