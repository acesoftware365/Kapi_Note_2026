// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
// Import generated localizations
import 'package:provider/provider.dart'; // Import provider
import 'package:flutter/foundation.dart'; // NEW: Import for defaultTargetPlatform
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../locale_notifier.dart'; // Import locale notifier
import '../theme_notifier.dart'; // Import theme notifier
import '../game_settings_notifier.dart'; // NEW: Import game settings notifier
import '../font_size_notifier.dart'; // NEW: Import font size notifier
import 'about_screen.dart'; // NEW: Import the about screen
import '../widgets/anchored_adaptive_banner_ad.dart';
import '../widgets/app_footer.dart';

class SettingsScreen extends StatefulWidget {
  // Changed to StatefulWidget to manage ad lifecycle
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// //////////////////////////////////////////////////////////////////////////////////////////////////////////
  // TODO: Replace this test ad unit ID with your own banner ad unit ID.
  final String _adUnitId =
      (defaultTargetPlatform ==
              TargetPlatform.android) // FIXED: Using defaultTargetPlatform
          ? 'ca-app-pub-8588489900323524/2555306020' // Test Android Banner
          : 'ca-app-pub-8588489900323524/9168815834'; // Test iOS Banner

  @override
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context)!;
    final localeNotifier = Provider.of<LocaleNotifier>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final gameSettingsNotifier = Provider.of<GameSettingsNotifier>(context);
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.home_rounded),
          tooltip: appLocalizations.homeScreenTitle,
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.note_rounded),
            tooltip: appLocalizations.gameScreenTitle,
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/game');
            },
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.language,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            appLocalizations.language,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: Theme.of(context).cardColor,
                            ),
                            child: SizedBox(
                              width: 150,
                              child: DropdownButton<Locale>(
                                value: localeNotifier.locale,
                                isExpanded: true,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                iconSize: 28,
                                elevation: 8,
                                style: Theme.of(context).textTheme.titleMedium,
                                underline: Container(),
                                onChanged: (Locale? newLocale) {
                                  if (newLocale != null) {
                                    localeNotifier.setLocale(newLocale);
                                  }
                                },
                                //TODO: add more language
                                items:
                                    AppLocalizations.supportedLocales
                                        .map<DropdownMenuItem<Locale>>((
                                          Locale locale,
                                        ) {
                                          String languageName;
                                          switch (locale.languageCode) {
                                            case 'en':
                                              languageName = 'English';
                                              break;
                                            case 'es':
                                              languageName = 'Español';
                                              break;
                                            case 'pt':
                                              languageName = 'Português';
                                              break;
                                            case 'it':
                                              languageName = 'Italiano';
                                              break;
                                            case 'fr':
                                              languageName = 'Français';
                                              break;
                                            case 'zh':
                                              languageName = '中文';
                                              break;
                                            case 'hi':
                                              languageName = 'हिन्दी';
                                              break;
                                            case 'ar':
                                              languageName = 'العربية';
                                              break;
                                            case 'bn':
                                              languageName = 'বাংলা';
                                              break;
                                            case 'ru':
                                              languageName = 'Русский';
                                              break;
                                            case 'ur':
                                              languageName = 'اردو';
                                              break;
                                            default:
                                              languageName = 'Unknown';
                                          }
                                          return DropdownMenuItem<Locale>(
                                            value: locale,
                                            child: Text(
                                              languageName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        })
                                        .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.brightness_6,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              appLocalizations.theme,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: Theme.of(context).cardColor,
                            ),
                            child: SizedBox(
                              width: 150,
                              child: DropdownButton<ThemeMode>(
                                value: themeNotifier.themeMode,
                                isExpanded: true,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                iconSize: 28,
                                elevation: 8,
                                style: Theme.of(context).textTheme.titleMedium,
                                underline: Container(),
                                onChanged: (ThemeMode? newThemeMode) {
                                  if (newThemeMode != null) {
                                    themeNotifier.setThemeMode(newThemeMode);
                                  }
                                },
                                items: <DropdownMenuItem<ThemeMode>>[
                                  DropdownMenuItem(
                                    value: ThemeMode.light,
                                    child: Text(
                                      appLocalizations.lightTheme,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: ThemeMode.dark,
                                    child: Text(
                                      appLocalizations.darkTheme,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: ThemeMode.system,
                                    child: Text(
                                      appLocalizations.systemTheme,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.score,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${appLocalizations.maxScoreSetting}: ${gameSettingsNotifier.maxScore}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                            ],
                          ),
                          Slider(
                            value: gameSettingsNotifier.maxScore.toDouble(),
                            min: 100,
                            max: 500,
                            divisions: 4,
                            label: gameSettingsNotifier.maxScore.toString(),
                            onChanged: (double value) {
                              gameSettingsNotifier.setMaxScore(value.round());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star_half,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  '${appLocalizations.defaultBonusSetting}: ${gameSettingsNotifier.defaultBonus}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: gameSettingsNotifier.defaultBonus.toDouble(),
                            min: 0,
                            max: 30,
                            divisions: 3,
                            label: gameSettingsNotifier.defaultBonus.toString(),
                            onChanged: (double value) {
                              gameSettingsNotifier.setDefaultBonus(
                                value.round(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.format_size,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${appLocalizations.fontSizeSetting}: ${fontSizeNotifier.fontSizeScale == 0.8 ? appLocalizations.smallFont : (fontSizeNotifier.fontSizeScale == 1.0 ? appLocalizations.mediumFont : appLocalizations.largeFont)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                            ],
                          ),
                          Slider(
                            value: fontSizeNotifier.fontSizeScale,
                            min: 0.8,
                            max: 1.2,
                            divisions: 2,
                            label:
                                fontSizeNotifier.fontSizeScale == 0.8
                                    ? appLocalizations.smallFont
                                    : (fontSizeNotifier.fontSizeScale == 1.0
                                        ? appLocalizations.mediumFont
                                        : appLocalizations.largeFont),
                            onChanged: (double value) {
                              fontSizeNotifier.setFontSizeScale(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.score,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${appLocalizations.scoreSizeSetting}: ${fontSizeNotifier.scoreFontSizeScale == 0.8 ? appLocalizations.smallFont : (fontSizeNotifier.scoreFontSizeScale == 1.0 ? appLocalizations.mediumFont : appLocalizations.largeFont)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                            ],
                          ),
                          Slider(
                            value: fontSizeNotifier.scoreFontSizeScale,
                            min: 0.8,
                            max: 1.6,
                            divisions: 4,
                            label:
                                fontSizeNotifier.scoreFontSizeScale == 0.8
                                    ? appLocalizations.smallFont
                                    : (fontSizeNotifier.scoreFontSizeScale ==
                                            1.0
                                        ? appLocalizations.mediumFont
                                        : appLocalizations.largeFont),
                            onChanged: (double value) {
                              fontSizeNotifier.setScoreFontSizeScale(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (shareContext) {
                      return ListTile(
                        leading: Icon(
                          Icons.share_rounded,
                          color: Theme.of(shareContext).iconTheme.color,
                        ),
                        title: Text(appLocalizations.shareAppTitle),
                        subtitle: Text(appLocalizations.shareAppSubtitle),
                        onTap: () async {
                          final String message =
                              appLocalizations.shareAppMessage;
                          final renderBox =
                              shareContext.findRenderObject() as RenderBox?;
                          try {
                            await Share.share(
                              message,
                              subject: 'Kapi Note',
                              sharePositionOrigin:
                                  renderBox != null
                                      ? renderBox.localToGlobal(Offset.zero) &
                                          renderBox.size
                                      : null,
                            );
                          } catch (e) {
                            debugPrint('Share failed: $e');
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: Icon(
                      Icons.info,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    title: Text(
                      appLocalizations.about,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                  AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                  const SizedBox(height: 12),
                  const AppFooter(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
