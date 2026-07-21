import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../premium_notifier.dart';
import 'app_version_label.dart';

class AnchoredAdaptiveBannerAd extends StatefulWidget {
  const AnchoredAdaptiveBannerAd({
    super.key,
    required this.adUnitId,
    this.margin = EdgeInsets.zero,
    this.request = const AdRequest(),
  });

  final String adUnitId;
  final EdgeInsetsGeometry margin;
  final AdRequest request;

  @override
  State<AnchoredAdaptiveBannerAd> createState() =>
      _AnchoredAdaptiveBannerAdState();
}

class _AnchoredAdaptiveBannerAdState extends State<AnchoredAdaptiveBannerAd> {
  static const bool _hideForScreenshots = bool.fromEnvironment(
    'KAPI_HIDE_BANNERS',
    // Banners are active by default. They can still be hidden temporarily with
    // --dart-define=KAPI_HIDE_BANNERS=true when clean screenshots are needed.
    defaultValue: false,
  );

  BannerAd? _bannerAd;
  AdSize? _adSize;
  int? _lastRequestedWidth;
  bool _isLoaded = false;
  bool _isLoading = false;
  Timer? _retryTimer;

  bool get _isMobileAdsPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hideForScreenshots || !_isMobileAdsPlatform) {
      _disposeCurrentAd();
      return;
    }
    final premiumNotifier = context.watch<PremiumNotifier>();
    if (premiumNotifier.isPremium) {
      _disposeCurrentAd();
      return;
    }

    _loadAdForCurrentWidth();
  }

  Future<void> _loadAdForCurrentWidth() async {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width.truncate();

    if (width <= 0 || _isLoading || _lastRequestedWidth == width) {
      return;
    }

    _isLoading = true;
    _lastRequestedWidth = width;

    // The Mobile Ads SDK returns the best anchored adaptive size for the
    // current screen width and orientation.
    final AnchoredAdaptiveBannerAdSize? adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (!mounted) {
      return;
    }

    if (adaptiveSize == null) {
      setState(() {
        _lastRequestedWidth = null;
        _isLoaded = false;
        _adSize = null;
      });
      _isLoading = false;
      return;
    }

    await _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      request: widget.request,
      size: adaptiveSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = adaptiveSize;
            _isLoaded = true;
            _isLoading = false;
          });
          _retryTimer?.cancel();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) {
            return;
          }

          debugPrint(
            'Anchored adaptive banner failed to load: '
            '${error.code} ${error.domain} ${error.message}',
          );

          setState(() {
            _bannerAd = null;
            _adSize = null;
            _lastRequestedWidth = null;
            _isLoaded = false;
            _isLoading = false;
          });
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) _loadAdForCurrentWidth();
          });
        },
      ),
    );

    await _bannerAd!.load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _disposeCurrentAd();
    super.dispose();
  }

  void _disposeCurrentAd() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;
    _isLoaded = false;
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hideForScreenshots || !_isMobileAdsPlatform) {
      return const AppVersionLabel(
        padding: EdgeInsets.only(top: 2, bottom: 2),
        fontSize: 10,
      );
    }
    final premiumNotifier = context.watch<PremiumNotifier>();
    if (premiumNotifier.isPremium) {
      return const AppVersionLabel(
        padding: EdgeInsets.only(top: 2, bottom: 2),
        fontSize: 10,
      );
    }

    final bannerAd = _bannerAd;
    final adSize = _adSize;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: adSize?.height.toDouble() ?? 50,
          child:
              _isLoaded && bannerAd != null && adSize != null
                  ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: widget.margin,
                      child: SizedBox(
                        width: adSize.width.toDouble(),
                        height: adSize.height.toDouble(),
                        child: AdWidget(ad: bannerAd),
                      ),
                    ),
                  )
                  : const SizedBox.expand(),
        ),
        const AppVersionLabel(
          padding: EdgeInsets.only(top: 4, bottom: 2),
          fontSize: 10,
        ),
      ],
    );
  }
}
