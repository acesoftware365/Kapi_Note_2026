// main.dart
import 'package:dominoes_note2025/screens/team_name_notifier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // NEW: Import AdMob

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/about_screen.dart';
import 'screens/game_screen.dart';
import 'screens/legal_acceptance_screen.dart';
import 'screens/fireworks_screen.dart';
import 'screens/start_game_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/domino_cpu_game_screen.dart';
import 'screens/domino_online_game_screen.dart';
import 'screens/lobby_screen.dart';
import 'locale_notifier.dart';
import 'theme_notifier.dart';
import 'game_settings_notifier.dart';
import 'font_size_notifier.dart';
import 'legal_acceptance_notifier.dart';
import 'premium_notifier.dart';
import 'widgets/force_update_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AnalyticsService.logAppOpen();
  // NEW: Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final localeNotifier = LocaleNotifier();
  final themeNotifier = ThemeNotifier();
  final gameSettingsNotifier = GameSettingsNotifier();
  final fontSizeNotifier = FontSizeNotifier();
  final teamNameNotifier = TeamNameNotifier();
  final premiumNotifier = PremiumNotifier();
  final legalAcceptanceNotifier = LegalAcceptanceNotifier();

  await localeNotifier.loadLocale();
  await themeNotifier.loadThemeMode();
  await gameSettingsNotifier.loadSettings();
  await fontSizeNotifier.loadFontSize();
  await teamNameNotifier.loadTeamNames();
  await premiumNotifier.loadPremium();
  await legalAcceptanceNotifier.loadAcceptance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeNotifier),
        ChangeNotifierProvider.value(value: themeNotifier),
        ChangeNotifierProvider.value(value: gameSettingsNotifier),
        ChangeNotifierProvider.value(value: fontSizeNotifier),
        ChangeNotifierProvider.value(value: teamNameNotifier),
        ChangeNotifierProvider.value(value: premiumNotifier),
        ChangeNotifierProvider.value(value: legalAcceptanceNotifier),
      ],
      child: const DominoApp(),
    ),
  );
}

class DominoApp extends StatelessWidget {
  const DominoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeNotifier = Provider.of<LocaleNotifier>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(context);

    return MaterialApp(
      title: AppLocalizations.of(context)?.appTitle ?? 'Domino Scorer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        brightness: Brightness.light,
        textTheme: TextTheme(
          bodyLarge: TextStyle(
            color: Colors.black87,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(16 * fontSizeNotifier.fontSizeScale),
          ),
          bodyMedium: TextStyle(
            color: Colors.black54,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(14 * fontSizeNotifier.fontSizeScale),
          ),
          headlineLarge: TextStyle(
            color: Colors.black87,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(28 * fontSizeNotifier.fontSizeScale),
          ),
          headlineMedium: TextStyle(
            color: Colors.black87,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(20 * fontSizeNotifier.fontSizeScale),
          ),
          titleLarge: TextStyle(
            color: Colors.black87,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(22 * fontSizeNotifier.fontSizeScale),
          ),
          titleMedium: TextStyle(
            color: Colors.black87,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(16 * fontSizeNotifier.fontSizeScale),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        cardColor: Colors.grey[800],
        textTheme: TextTheme(
          bodyLarge: TextStyle(
            color: Colors.white70,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(16 * fontSizeNotifier.fontSizeScale),
          ),
          bodyMedium: TextStyle(
            color: Colors.white54,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(14 * fontSizeNotifier.fontSizeScale),
          ),
          headlineLarge: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(28 * fontSizeNotifier.fontSizeScale),
          ),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(20 * fontSizeNotifier.fontSizeScale),
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(22 * fontSizeNotifier.fontSizeScale),
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(
              context,
            ).textScaler.scale(16 * fontSizeNotifier.fontSizeScale),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      themeMode: themeNotifier.themeMode,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.observer],
      locale: localeNotifier.locale,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        final deviceLanguage = deviceLocale?.languageCode;
        for (final locale in supportedLocales) {
          if (locale.languageCode == deviceLanguage) {
            return locale;
          }
        }
        return const Locale('es');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ForceUpdateGate(child: child);
      },
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/legal': (context) => const LegalAcceptanceScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/premium': (context) => const PremiumScreen(),
        '/about': (context) => const AboutScreen(),
        '/game': (context) => const GameScreen(),
        '/start-game': (context) => const StartGameScreen(),
        '/ranking': (context) => const RankingScreen(),
        '/lobby': (context) => const LobbyScreen(),
        '/domino-classic': (context) => const ClassicDominoGameScreen(),
        '/domino-draw': (context) => const DrawDominoGameScreen(),
        '/domino-online': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final gameId = args is Map ? args['gameId'] as String? : null;
          final playerId = args is Map ? args['playerId'] as String? : null;
          return DominoOnlineGameScreen(
            gameId: gameId ?? '',
            playerId: playerId,
          );
        },
        '/fireworks': (context) => const FireworksScreen(winningTeamName: ''),
      },
    );
  }
}
