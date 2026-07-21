import 'package:flutter/material.dart';

import '../services/kapi_cosmetics_service.dart';

/// Keeps the player's dominoes readable regardless of the equipped skin.
/// The equipped tray changes only the hand panel; tile contrast remains
/// adaptive for every domino style.
class AdaptiveDominoHandTray extends StatefulWidget {
  const AdaptiveDominoHandTray({
    super.key,
    required this.dominoColor,
    required this.child,
    this.borderRadius = 18,
  });

  final Color dominoColor;
  final Widget child;
  final double borderRadius;

  static bool needsLightSurface(Color dominoColor) =>
      dominoColor.computeLuminance() < 0.24;

  @override
  State<AdaptiveDominoHandTray> createState() => _AdaptiveDominoHandTrayState();
}

class _AdaptiveDominoHandTrayState extends State<AdaptiveDominoHandTray>
    with SingleTickerProviderStateMixin {
  late final AnimationController _textureAnimation;

  @override
  void initState() {
    super.initState();
    _textureAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _textureAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lightSurface = AdaptiveDominoHandTray.needsLightSurface(
      widget.dominoColor,
    );
    final radius = BorderRadius.circular(widget.borderRadius);

    return AnimatedBuilder(
      animation: Listenable.merge([
        KapiCosmeticsService.instance,
        _textureAnimation,
      ]),
      child: widget.child,
      builder: (context, child) {
        final trayId =
            KapiCosmeticsService.instance
                .equipped(KapiCosmeticType.handTray)
                .id;
        final scheme = _HandTrayScheme.forItem(trayId, lightSurface);

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: scheme.baseColor,
            border: Border.all(
              color: scheme.borderColor,
              width: lightSurface ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: lightSurface ? 0.24 : 0.18,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (lightSurface)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.32),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: CustomPaint(
                    painter: _HandTrayPatternPainter(
                      lineColor: scheme.patternColor,
                      highlightColor: scheme.highlightColor,
                      grainColor: scheme.grainColor,
                      shimmerProgress: _textureAnimation.value,
                    ),
                  ),
                ),
                child!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HandTrayScheme {
  const _HandTrayScheme({
    required this.baseColor,
    required this.borderColor,
    required this.patternColor,
    required this.highlightColor,
    required this.grainColor,
  });

  final Color baseColor;
  final Color borderColor;
  final Color patternColor;
  final Color highlightColor;
  final Color grainColor;

  static _HandTrayScheme forItem(String id, bool lightSurface) {
    switch (id) {
      case 'tray_midnight':
        return lightSurface
            ? const _HandTrayScheme(
              baseColor: Color(0xFFD4E2F0),
              borderColor: Color(0xFF6CB6FF),
              patternColor: Color(0x14193D63),
              highlightColor: Color(0x29FFFFFF),
              grainColor: Color(0x16102D4A),
            )
            : const _HandTrayScheme(
              baseColor: Color(0xFF0B2238),
              borderColor: Color(0xFF6CB6FF),
              patternColor: Color(0x1786CBFF),
              highlightColor: Color(0x0FFFFFFF),
              grainColor: Color(0x185AB7FF),
            );
      case 'tray_mahogany':
        return lightSurface
            ? const _HandTrayScheme(
              baseColor: Color(0xFFE5C8A4),
              borderColor: Color(0xFFE1B45B),
              patternColor: Color(0x165A241B),
              highlightColor: Color(0x29FFFFFF),
              grainColor: Color(0x1C5A241B),
            )
            : const _HandTrayScheme(
              baseColor: Color(0xFF3D1913),
              borderColor: Color(0xFFE1B45B),
              patternColor: Color(0x13F2C87B),
              highlightColor: Color(0x0FFFFFFF),
              grainColor: Color(0x1DF2C87B),
            );
      case 'tray_caribbean':
        return lightSurface
            ? const _HandTrayScheme(
              baseColor: Color(0xFFC6EAE3),
              borderColor: Color(0xFF48D1C5),
              patternColor: Color(0x13004C50),
              highlightColor: Color(0x29FFFFFF),
              grainColor: Color(0x18004C50),
            )
            : const _HandTrayScheme(
              baseColor: Color(0xFF004A50),
              borderColor: Color(0xFF48D1C5),
              patternColor: Color(0x1474F3DD),
              highlightColor: Color(0x0FFFFFFF),
              grainColor: Color(0x1A74F3DD),
            );
      case 'tray_royal':
        return lightSurface
            ? const _HandTrayScheme(
              baseColor: Color(0xFFE6D9EF),
              borderColor: Color(0xFFE9C66A),
              patternColor: Color(0x133E1C66),
              highlightColor: Color(0x29FFFFFF),
              grainColor: Color(0x193E1C66),
            )
            : const _HandTrayScheme(
              baseColor: Color(0xFF2D154D),
              borderColor: Color(0xFFE9C66A),
              patternColor: Color(0x14F3D67E),
              highlightColor: Color(0x0FFFFFFF),
              grainColor: Color(0x1CF3D67E),
            );
      default:
        return lightSurface
            ? const _HandTrayScheme(
              baseColor: Color(0xFFE6DAC2),
              borderColor: Color(0xFFD8B765),
              patternColor: Color(0x136B5940),
              highlightColor: Color(0x29FFFFFF),
              grainColor: Color(0x176B5940),
            )
            : const _HandTrayScheme(
              baseColor: Color(0xFF141F2A),
              borderColor: Color(0x24FFFFFF),
              patternColor: Color(0x09FFFFFF),
              highlightColor: Color(0x0BFFFFFF),
              grainColor: Color(0x12FFFFFF),
            );
    }
  }
}

class _HandTrayPatternPainter extends CustomPainter {
  const _HandTrayPatternPainter({
    required this.lineColor,
    required this.highlightColor,
    required this.grainColor,
    required this.shimmerProgress,
  });

  final Color lineColor;
  final Color highlightColor;
  final Color grainColor;
  final double shimmerProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 0.8;
    const spacing = 15.0;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        linePaint,
      );
    }

    final grainPaint = Paint()..color = grainColor;
    for (var index = 0; index < 46; index++) {
      final x = ((index * 47) % 101) / 101 * size.width;
      final y = ((index * 71) % 97) / 97 * size.height;
      final radius = 0.45 + (index % 3) * 0.35;
      canvas.drawCircle(Offset(x, y), radius, grainPaint);
    }

    final highlightPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [highlightColor, Colors.transparent],
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, highlightPaint);

    final shimmerX = (size.width + size.height) * shimmerProgress - size.height;
    final shimmerPath =
        Path()
          ..moveTo(shimmerX - 28, size.height)
          ..lineTo(shimmerX + 24, size.height)
          ..lineTo(shimmerX + size.height + 28, 0)
          ..lineTo(shimmerX + size.height - 24, 0)
          ..close();
    final shimmerPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              highlightColor.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size);
    canvas.drawPath(shimmerPath, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _HandTrayPatternPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.highlightColor != highlightColor ||
      oldDelegate.grainColor != grainColor ||
      oldDelegate.shimmerProgress != shimmerProgress;
}
