// lib/screens/home_screen.dart
import 'dart:async';

import 'package:dominoes_note2025/screens/admob_variable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../premium_notifier.dart';
import '../services/analytics_service.dart';
import '../services/audio_manager.dart';
import '../services/kapi_cosmetics_service.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _adUnitId =
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioManager.instance.stopAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context)!;
    final premiumNotifier = context.watch<PremiumNotifier>();
    final isPremium = premiumNotifier.isPremium;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/premium');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: 0.28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_open_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPremium ? 'Premium' : 'Go Premium',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Color.fromARGB((255 * 0.48).round(), 0, 0, 0),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0x99000000), const Color(0xCC081524)],
              ),
            ),
          ),
          SafeArea(
            // The footer already contains the banner/version spacing. Keeping
            // the iPhone bottom inset here added a second large empty area
            // below it and pushed the main controls unnecessarily upward.
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 720;
                final horizontalPadding = isTablet ? 48.0 : 20.0;
                final contentWidth = isTablet ? 840.0 : double.infinity;
                final verticalPadding = isTablet ? 36.0 : 18.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    4,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, contentConstraints) {
                            return SingleChildScrollView(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: contentWidth,
                                    minHeight: contentConstraints.maxHeight,
                                  ),
                                  child:
                                      isTablet
                                          ? _buildTabletHome(
                                            context,
                                            appLocalizations,
                                          )
                                          : _buildPhoneHome(
                                            context,
                                            appLocalizations,
                                          ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(height: 4),
                        AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneHome(
    BuildContext context,
    AppLocalizations appLocalizations,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroBlock(context, appLocalizations, false),
        _buildActionPanel(context, appLocalizations, false),
      ],
    );
  }

  Widget _buildTabletHome(
    BuildContext context,
    AppLocalizations appLocalizations,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroBlock(context, appLocalizations, true),
        _buildActionPanel(context, appLocalizations, true),
      ],
    );
  }

  Widget _buildHeroBlock(
    BuildContext context,
    AppLocalizations appLocalizations,
    bool isTablet,
  ) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
      color: Colors.white,
      fontSize: isTablet ? 74 : 50,
      fontWeight: FontWeight.w900,
      height: 0.98,
      letterSpacing: 0,
      shadows: const [
        Shadow(blurRadius: 18, color: Colors.black54, offset: Offset(0, 8)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Kapi Note', textAlign: TextAlign.center, style: titleStyle),
        SizedBox(height: isTablet ? 16 : 12),
        Text(
          isSpanish
              ? 'Juega en línea, lleva tus apuntes y disfruta 4 juegos de dominó en un solo lugar.'
              : 'Play online, keep your notes, and enjoy 4 domino games in one place.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionPanel(
    BuildContext context,
    AppLocalizations appLocalizations,
    bool isTablet,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 22 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPrimaryButton(
            context,
            label: appLocalizations.startGameButton,
            icon: Icons.play_arrow_rounded,
            onPressed: () => Navigator.pushNamed(context, '/start-game'),
            isTablet: isTablet,
          ),
          SizedBox(height: isTablet ? 14 : 12),
          _buildPrimaryButton(
            context,
            label: _notesButtonText(context),
            icon: Icons.edit_note_rounded,
            onPressed: () {
              unawaited(AnalyticsService.logGameStarted());
              Navigator.pushNamed(context, '/game');
            },
            isTablet: isTablet,
            outlined: true,
          ),
          SizedBox(height: isTablet ? 14 : 12),
          _buildShopFeatureButton(context, isTablet: isTablet),
          SizedBox(height: isTablet ? 14 : 12),
          _buildPremiumFeatureButton(context, isTablet: isTablet),
          SizedBox(height: isTablet ? 14 : 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniButton(
                  context,
                  icon: Icons.settings_rounded,
                  label: appLocalizations.settingsButton,
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  isTablet: isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniButton(
                  context,
                  icon: Icons.ios_share_rounded,
                  label: _shareButtonText(context),
                  onPressed: () => _sharePromotion(context),
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 14 : 12),
          _buildMiniButton(
            context,
            icon: Icons.privacy_tip_rounded,
            label: appLocalizations.privacyPolicy,
            onPressed: () => Navigator.pushNamed(context, '/terms-privacy'),
            isTablet: isTablet,
          ),
          SizedBox(height: isTablet ? 16 : 14),
        ],
      ),
    );
  }

  Widget _buildShopFeatureButton(
    BuildContext context, {
    required bool isTablet,
  }) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final store = context.watch<KapiCosmeticsService>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/kapi-store'),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: isTablet ? 80 : 68,
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF18374A), Color(0xFF0A2028)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD6B56B), width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isTablet ? 48 : 42,
                height: isTablet ? 48 : 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF241E14),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD6B56B)),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFFF1D99C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSpanish ? 'Tienda Kapi' : 'Kapi Shop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 20 : 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      isSpanish
                          ? 'Mesas, centros, perfiles y más'
                          : 'Tables, centerpieces, profiles & more',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFF1D99C),
                        fontSize: isTablet ? 13 : 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xCC08121C),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0x88D6B56B)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFFE6C66E),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${store.balance} KC',
                      style: const TextStyle(
                        color: Color(0xFFF1D99C),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFF1D99C)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isTablet,
    bool outlined = false,
  }) {
    return SizedBox(
      height: isTablet ? 78 : 62,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: isTablet ? 34 : 28),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isTablet ? 24 : 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              outlined
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE53935),
          foregroundColor: Colors.white,
          side:
              outlined
                  ? const BorderSide(color: Color(0xFFE57373), width: 1.6)
                  : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumFeatureButton(
    BuildContext context, {
    required bool isTablet,
  }) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    return SizedBox(
      height: isTablet ? 82 : 68,
      child: FilledButton(
        onPressed: () => Navigator.pushNamed(context, '/premium'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium_rounded, size: isTablet ? 34 : 28),
            SizedBox(width: isTablet ? 13 : 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _premiumButtonText(context),
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    isSpanish
                        ? 'Sin anuncios y beneficios exclusivos'
                        : 'No ads and exclusive benefits',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: isTablet ? 14 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool filled,
    required bool isTablet,
  }) {
    return SizedBox(
      height: isTablet ? 68 : 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: isTablet ? 26 : 22),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: isTablet ? 18 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor:
              filled
                  ? const Color(0xFF1E88E5)
                  : Colors.white.withValues(alpha: 0.08),
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: filled ? 0 : 0.26),
          ),
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isTablet,
  }) {
    return SizedBox(
      height: isTablet ? 58 : 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: isTablet ? 22 : 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: isTablet ? 15 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.92),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 18 : 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  String _premiumButtonText(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'es'
        ? 'Hazte Premium'
        : 'Go Premium';
  }

  String _shareButtonText(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'es'
        ? 'Compartir app'
        : 'Share App';
  }

  String _notesButtonText(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'es'
        ? 'Abrir apuntes'
        : 'Open Notes';
  }

  Future<void> _sharePromotion(BuildContext context) async {
    const androidLink =
        'https://play.google.com/store/apps/details?id=com.liisgo.kapi.note';
    const iosLink = 'https://apps.apple.com/us/app/kapi-note/id6752557170';
    final appLink =
        defaultTargetPlatform == TargetPlatform.android ? androidLink : iosLink;
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final message =
        isSpanish
            ? 'Prueba Kapi Note: la forma fácil de llevar los puntos del dominó. Descárgala aquí: $appLink'
            : 'Try Kapi Note: the easy way to track domino scores. Download it here: $appLink';

    final renderBox = context.findRenderObject() as RenderBox?;
    await Share.share(
      message,
      subject: 'Kapi Note',
      sharePositionOrigin:
          renderBox != null
              ? renderBox.localToGlobal(Offset.zero) & renderBox.size
              : null,
    );
  }
}
