// lib/screens/home_screen.dart
import 'package:dominoes_note2025/screens/admob_variable.dart';
import 'package:dominoes_note2025/screens/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import 'about_screen.dart';
import 'game_screen.dart';

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
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;
    final contentMaxWidth = isTablet ? 840.0 : double.infinity;
    final horizontalPadding = isTablet ? 56.0 : 24.0;
    final titleFontSize = isTablet ? 110.0 : 56.0;
    final descriptionFontSize = isTablet ? 30.0 : 16.0;
    final primaryButtonFontSize = isTablet ? 32.0 : 16.0;
    final secondaryButtonFontSize = isTablet ? 26.0 : 14.0;
    final primaryButtonIconSize = isTablet ? 42.0 : 22.0;
    final secondaryButtonIconSize = isTablet ? 34.0 : 18.0;
    final primaryButtonVerticalPadding = isTablet ? 30.0 : 16.0;
    final secondaryButtonVerticalPadding = isTablet ? 26.0 : 14.0;
    final buttonRadius = isTablet ? 20.0 : 12.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Color.fromARGB((255 * 0.3).round(), 0, 0, 0),
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
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x66000000)
                      : const Color(0x33FFFFFF),
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xAA000000)
                      : const Color(0x66FFFFFF),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isTablet ? 34.0 : 16.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: isTablet ? 120 : 80),
                      ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFFE53935),
                                Color(0xFF6D6E71),
                                Color(0xFF1E88E5),
                              ],
                            ).createShader(bounds),
                        child: Text(
                          'Kapi Note',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            shadows: const [
                              Shadow(
                                blurRadius: 14,
                                color: Colors.black38,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isTablet ? 24 : 12),
                      Text(
                        appLocalizations.homeScreenDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: descriptionFontSize,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 32 : 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                    ? 0.2
                                    : 0.85,
                          ),
                          borderRadius: BorderRadius.circular(
                            isTablet ? 24 : 16,
                          ),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE53935),
                                      Color(0xFF6D6E71),
                                      Color(0xFF1E88E5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    buttonRadius,
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => const GameScreen(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: primaryButtonVerticalPadding,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        buttonRadius,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        size: primaryButtonIconSize,
                                      ),
                                      SizedBox(width: isTablet ? 12 : 8),
                                      Flexible(
                                        child: Text(
                                          appLocalizations.startGameButton,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontSize: primaryButtonFontSize,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isTablet ? 22 : 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const SettingsScreen(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      side: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical:
                                            secondaryButtonVerticalPadding,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          buttonRadius,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.settings_rounded,
                                          size: secondaryButtonIconSize,
                                        ),
                                        SizedBox(width: isTablet ? 10 : 6),
                                        Flexible(
                                          child: Text(
                                            appLocalizations.settingsButton,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: secondaryButtonFontSize,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: isTablet ? 16 : 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => const AboutScreen(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      side: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical:
                                            secondaryButtonVerticalPadding,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          buttonRadius,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.privacy_tip_rounded,
                                          size: secondaryButtonIconSize,
                                        ),
                                        SizedBox(width: isTablet ? 10 : 6),
                                        Flexible(
                                          child: Text(
                                            appLocalizations.privacyPolicy,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: secondaryButtonFontSize,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isTablet ? 16 : 12),
                      AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
