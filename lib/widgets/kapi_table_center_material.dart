import 'package:flutter/material.dart';

/// Paints only the playable center material from a full square table preview.
///
/// Shop previews include rails, corners and trays. Game boards already provide
/// their own border and controls, so the preview is deliberately zoomed and
/// clipped here to keep only the central playing surface behind the dominoes.
class KapiTableCenterMaterial extends StatelessWidget {
  const KapiTableCenterMaterial({
    super.key,
    required this.fallbackColor,
    this.assetPath,
    this.opacity = 0.72,
    this.cropScale = 1.75,
  });

  static const imageKey = ValueKey<String>('kapi-table-center-material-image');

  final Color fallbackColor;
  final String? assetPath;
  final double opacity;
  final double cropScale;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    return ColoredBox(
      color: fallbackColor,
      child:
          path == null
              ? const SizedBox.expand()
              : ClipRect(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    key: imageKey,
                    scale: cropScale,
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
    );
  }
}
