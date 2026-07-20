import 'package:flutter/material.dart';

import '../services/kapi_cosmetics_service.dart';

/// Keeps the player's dominoes readable regardless of the equipped skin.
/// The equipped tray changes only the hand panel; tile contrast remains
/// adaptive for every domino style.
class AdaptiveDominoHandTray extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final lightSurface = needsLightSurface(dominoColor);
    final radius = BorderRadius.circular(borderRadius);

    return AnimatedBuilder(
      animation: KapiCosmeticsService.instance,
      builder: (context, _) {
        final trayId =
            KapiCosmeticsService.instance
                .equipped(KapiCosmeticType.handTray)
                .id;
        final scheme = _HandTrayScheme.forItem(trayId, lightSurface);

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: scheme.colors,
            ),
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
                    ),
                  ),
                ),
                child,
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
    required this.colors,
    required this.borderColor,
    required this.patternColor,
    required this.highlightColor,
  });

  final List<Color> colors;
  final Color borderColor;
  final Color patternColor;
  final Color highlightColor;

  static _HandTrayScheme forItem(String id, bool lightSurface) {
    switch (id) {
      case 'tray_midnight':
        return lightSurface
            ? const _HandTrayScheme(
              colors: [Color(0xFFE8F2FC), Color(0xFFC0D1E3)],
              borderColor: Color(0xFF6CB6FF),
              patternColor: Color(0x14193D63),
              highlightColor: Color(0x29FFFFFF),
            )
            : const _HandTrayScheme(
              colors: [Color(0xFF102D4A), Color(0xFF071827)],
              borderColor: Color(0xFF6CB6FF),
              patternColor: Color(0x1786CBFF),
              highlightColor: Color(0x0FFFFFFF),
            );
      case 'tray_mahogany':
        return lightSurface
            ? const _HandTrayScheme(
              colors: [Color(0xFFF7E8D2), Color(0xFFD7B089)],
              borderColor: Color(0xFFE1B45B),
              patternColor: Color(0x165A241B),
              highlightColor: Color(0x29FFFFFF),
            )
            : const _HandTrayScheme(
              colors: [Color(0xFF5A241B), Color(0xFF24100C)],
              borderColor: Color(0xFFE1B45B),
              patternColor: Color(0x13F2C87B),
              highlightColor: Color(0x0FFFFFFF),
            );
      case 'tray_caribbean':
        return lightSurface
            ? const _HandTrayScheme(
              colors: [Color(0xFFE8FBF7), Color(0xFFA9DCD4)],
              borderColor: Color(0xFF48D1C5),
              patternColor: Color(0x13004C50),
              highlightColor: Color(0x29FFFFFF),
            )
            : const _HandTrayScheme(
              colors: [Color(0xFF005C64), Color(0xFF00383D)],
              borderColor: Color(0xFF48D1C5),
              patternColor: Color(0x1474F3DD),
              highlightColor: Color(0x0FFFFFFF),
            );
      case 'tray_royal':
        return lightSurface
            ? const _HandTrayScheme(
              colors: [Color(0xFFF7EFFA), Color(0xFFD8C7E8)],
              borderColor: Color(0xFFE9C66A),
              patternColor: Color(0x133E1C66),
              highlightColor: Color(0x29FFFFFF),
            )
            : const _HandTrayScheme(
              colors: [Color(0xFF3E1C66), Color(0xFF1C0C37)],
              borderColor: Color(0xFFE9C66A),
              patternColor: Color(0x14F3D67E),
              highlightColor: Color(0x0FFFFFFF),
            );
      default:
        return lightSurface
            ? const _HandTrayScheme(
              colors: [Color(0xFFF4EBD8), Color(0xFFD8C9AE)],
              borderColor: Color(0xFFD8B765),
              patternColor: Color(0x136B5940),
              highlightColor: Color(0x29FFFFFF),
            )
            : const _HandTrayScheme(
              colors: [Color(0xFF1A2632), Color(0xFF101822)],
              borderColor: Color(0x24FFFFFF),
              patternColor: Color(0x09FFFFFF),
              highlightColor: Color(0x0BFFFFFF),
            );
    }
  }
}

class _HandTrayPatternPainter extends CustomPainter {
  const _HandTrayPatternPainter({
    required this.lineColor,
    required this.highlightColor,
  });

  final Color lineColor;
  final Color highlightColor;

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

    final highlightPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [highlightColor, Colors.transparent],
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _HandTrayPatternPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.highlightColor != highlightColor;
}
