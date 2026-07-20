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
import '../widgets/anchored_adaptive_banner_ad.dart';

class SettingsScreen extends StatefulWidget {
  // Changed to StatefulWidget to manage ad lifecycle
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-8588489900323524/2555306020'
          : 'ca-app-pub-8588489900323524/9168815834';

  @override
  Widget build(BuildContext outerContext) {
    final AppLocalizations appLocalizations =
        AppLocalizations.of(outerContext)!;
    final localeNotifier = Provider.of<LocaleNotifier>(outerContext);
    final themeNotifier = Provider.of<ThemeNotifier>(outerContext);
    final gameSettingsNotifier = Provider.of<GameSettingsNotifier>(
      outerContext,
    );
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(outerContext);
    final currentLocale =
        localeNotifier.locale ??
        _supportedLocaleFor(Localizations.localeOf(outerContext));

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF071524),
        cardColor: const Color(0xEE171C24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD36A),
          secondary: Color(0xFFF13A37),
          surface: Color(0xEE171C24),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      child: Builder(
        builder:
            (context) => Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: Text(
                  Localizations.localeOf(context).languageCode == 'es'
                      ? 'Configuracion de apuntes'
                      : 'Note Settings',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                centerTitle: true,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip:
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'Volver'
                          : 'Back',
                  onPressed: () => _goBack(context),
                ),
                backgroundColor: const Color(0xFF720B09),
                foregroundColor: Colors.white,
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
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF720B09),
                          Color(0xFF171C24),
                          Color(0xFF071524),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
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
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Spacer(),
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      canvasColor: Theme.of(context).cardColor,
                                    ),
                                    child: SizedBox(
                                      width: 150,
                                      child: DropdownButton<Locale>(
                                        value: currentLocale,
                                        isExpanded: true,
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                        iconSize: 28,
                                        elevation: 8,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
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
                                                      languageName =
                                                          'Português';
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
                                                  return DropdownMenuItem<
                                                    Locale
                                                  >(
                                                    value: locale,
                                                    child: Text(
                                                      languageName,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
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
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                        iconSize: 28,
                                        elevation: 8,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                        underline: Container(),
                                        onChanged: (ThemeMode? newThemeMode) {
                                          if (newThemeMode != null) {
                                            themeNotifier.setThemeMode(
                                              newThemeMode,
                                            );
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
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${appLocalizations.maxScoreSetting}: ${gameSettingsNotifier.maxScore}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                      const Spacer(),
                                    ],
                                  ),
                                  Slider(
                                    value:
                                        gameSettingsNotifier.maxScore
                                            .toDouble(),
                                    min: 100,
                                    max: 500,
                                    divisions: 4,
                                    label:
                                        gameSettingsNotifier.maxScore
                                            .toString(),
                                    onChanged: (double value) {
                                      gameSettingsNotifier.setMaxScore(
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
                                        Icons.star_half,
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          '${appLocalizations.defaultBonusSetting}: ${gameSettingsNotifier.defaultBonus}',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value:
                                        gameSettingsNotifier.defaultBonus
                                            .toDouble(),
                                    min: 0,
                                    max: 30,
                                    divisions: 3,
                                    label:
                                        gameSettingsNotifier.defaultBonus
                                            .toString(),
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
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${appLocalizations.fontSizeSetting}: ${fontSizeNotifier.fontSizeScale == 0.8 ? appLocalizations.smallFont : (fontSizeNotifier.fontSizeScale == 1.0 ? appLocalizations.mediumFont : appLocalizations.largeFont)}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
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
                                            : (fontSizeNotifier.fontSizeScale ==
                                                    1.0
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
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${appLocalizations.scoreSizeSetting}: ${fontSizeNotifier.scoreFontSizeScale == 0.8 ? appLocalizations.smallFont : (fontSizeNotifier.scoreFontSizeScale == 1.0 ? appLocalizations.mediumFont : appLocalizations.largeFont)}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
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
                                        fontSizeNotifier.scoreFontSizeScale ==
                                                0.8
                                            ? appLocalizations.smallFont
                                            : (fontSizeNotifier
                                                        .scoreFontSizeScale ==
                                                    1.0
                                                ? appLocalizations.mediumFont
                                                : appLocalizations.largeFont),
                                    onChanged: (double value) {
                                      fontSizeNotifier.setScoreFontSizeScale(
                                        value,
                                      );
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
                                subtitle: Text(
                                  appLocalizations.shareAppSubtitle,
                                ),
                                onTap: () async {
                                  final String message = _platformShareMessage(
                                    currentLocale.languageCode,
                                  );
                                  final renderBox =
                                      shareContext.findRenderObject()
                                          as RenderBox?;
                                  try {
                                    await Share.share(
                                      message,
                                      subject: 'Kapi Note',
                                      sharePositionOrigin:
                                          renderBox != null
                                              ? renderBox.localToGlobal(
                                                    Offset.zero,
                                                  ) &
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
                          const SizedBox(height: 18),
                          AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Locale _supportedLocaleFor(Locale locale) {
    for (final supportedLocale in AppLocalizations.supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
    return const Locale('es');
  }

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/home');
  }

  String _platformShareMessage(String languageCode) {
    final link =
        defaultTargetPlatform == TargetPlatform.android
            ? 'https://play.google.com/store/apps/details?id=com.liisgo.kapi.note'
            : 'https://apps.apple.com/us/app/kapi-note/id6752557170';

    return languageCode == 'es'
        ? 'Prueba Kapi Note: la forma fácil de llevar los puntos del dominó. Descárgala aquí: $link'
        : 'Try Kapi Note: the easy way to track domino scores. Download it here: $link';
  }
}
