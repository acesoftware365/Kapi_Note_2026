import 'dart:math' as math;

import 'package:flutter/material.dart';

class DrawPoolActionButton extends StatelessWidget {
  const DrawPoolActionButton({
    super.key,
    required this.remaining,
    required this.isSpanish,
    required this.onPressed,
    this.compact = false,
    this.fillWidth = false,
    this.feedbackText,
  });

  final int remaining;
  final bool isSpanish;
  final VoidCallback? onPressed;
  final bool compact;
  final bool fillWidth;
  final String? feedbackText;

  bool get _enabled => onPressed != null && remaining > 0;

  @override
  Widget build(BuildContext context) {
    final label =
        isSpanish
            ? 'Tomar ficha del pozo, $remaining restantes'
            : 'Draw tile from pool, $remaining remaining';
    final feedback = feedbackText?.trim();
    final primaryText =
        feedback != null && feedback.isNotEmpty
            ? feedback
            : (isSpanish ? 'Tomar ficha' : 'Draw tile');
    final secondaryText =
        fillWidth
            ? (isSpanish
                ? '$remaining en el pozo · Toca para tomar'
                : '$remaining in pool · Tap to draw')
            : (isSpanish ? '$remaining en el pozo' : '$remaining in pool');

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFFFD36B).withValues(alpha: 0.24),
          highlightColor: const Color(0xFFFFD36B).withValues(alpha: 0.10),
          child: Ink(
            width: fillWidth ? double.infinity : (compact ? 132 : 158),
            padding: EdgeInsets.symmetric(
              horizontal: fillWidth ? 14 : (compact ? 8 : 10),
              vertical: fillWidth ? 8 : 6,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    _enabled
                        ? (fillWidth
                            ? const [Color(0xF0142028), Color(0xF0551719)]
                            : const [Color(0xFF8B211D), Color(0xFF3D1014)])
                        : const [Color(0xFF343A43), Color(0xFF171D24)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _enabled
                        ? const Color(0xFFFFD36B)
                        : Colors.white.withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow:
                  _enabled
                      ? [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD36B,
                          ).withValues(alpha: 0.22),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                      : const [],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: fillWidth ? 58 : (compact ? 40 : 46),
              ),
              child: Row(
                mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  KapiPoolStackIcon(size: fillWidth ? 38 : (compact ? 30 : 34)),
                  SizedBox(width: fillWidth ? 11 : (compact ? 6 : 8)),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fillWidth ? 15 : (compact ? 11 : 13),
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          secondaryText,
                          key: const ValueKey('draw-pool-count'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(
                              0xFFFFD36B,
                            ).withValues(alpha: _enabled ? 1 : 0.62),
                            fontSize: fillWidth ? 11 : (compact ? 9 : 10),
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.add_circle_rounded,
                    color: _enabled ? const Color(0xFFFFD36B) : Colors.white38,
                    size: fillWidth ? 25 : (compact ? 18 : 21),
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

class KapiPoolStackIcon extends StatelessWidget {
  const KapiPoolStackIcon({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tileWidth = size * 0.48;
    final tileHeight = size * 0.76;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -math.pi / 13,
            child: _PoolTileBack(
              width: tileWidth,
              height: tileHeight,
              opacity: 0.70,
            ),
          ),
          Transform.translate(
            offset: Offset(size * 0.12, size * 0.05),
            child: _PoolTileBack(
              width: tileWidth,
              height: tileHeight,
              opacity: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoolTileBack extends StatelessWidget {
  const _PoolTileBack({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C93E6), Color(0xFF0A4B8E)],
          ),
          borderRadius: BorderRadius.circular(width * 0.22),
          border: Border.all(color: const Color(0xFFFFD36B), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ),
            Align(
              alignment: const Alignment(0, -0.52),
              child: _PoolPip(size: width * 0.12),
            ),
            Align(
              alignment: const Alignment(0, 0.52),
              child: _PoolPip(size: width * 0.12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolPip extends StatelessWidget {
  const _PoolPip({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
