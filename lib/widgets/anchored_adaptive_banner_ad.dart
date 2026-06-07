import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  BannerAd? _bannerAd;
  AdSize? _adSize;
  int? _lastRequestedWidth;
  bool _isLoaded = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
        },
      ),
    );

    await _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    final adSize = _adSize;

    if (!_isLoaded || bannerAd == null || adSize == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: widget.margin,
        child: SizedBox(
          width: adSize.width.toDouble(),
          height: adSize.height.toDouble(),
          child: AdWidget(ad: bannerAd),
        ),
      ),
    );
  }
}
