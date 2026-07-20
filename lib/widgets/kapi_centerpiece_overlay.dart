import 'package:flutter/material.dart';

import '../services/kapi_cosmetics_service.dart';

/// A decorative, non-interactive layer that sits below the domino chain.
///
/// Centerpieces are deliberately independent from table materials so the
/// player can combine any owned centerpiece with any owned table.
class KapiCenterpieceOverlay extends StatelessWidget {
  const KapiCenterpieceOverlay({
    super.key,
    this.maxFraction = .36,
    this.opacity = .30,
  });

  final double maxFraction;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final store = KapiCosmeticsService.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        final item = store.equipped(KapiCosmeticType.centerpiece);
        final asset = item.previewAsset;
        if (item.id == 'centerpiece_none' || asset == null) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dimension =
                  (constraints.biggest.shortestSide * maxFraction)
                      .clamp(82.0, 210.0)
                      .toDouble();
              return Center(
                child: Opacity(
                  opacity: opacity,
                  child: SizedBox.square(
                    dimension: dimension,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
