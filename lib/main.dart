// main.dart
import 'dart:async';

import 'package:dominoes_note2025/screens/team_name_notifier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // NEW: Import AdMob
import 'package:wakelock_plus/wakelock_plus.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';
import 'services/audio_manager.dart';
import 'services/kapi_cosmetics_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/settings_hub_screen.dart';
import 'screens/game_audio_settings_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/about_screen.dart';
import 'screens/terms_privacy_screen.dart';
import 'screens/game_screen.dart';
import 'screens/legal_acceptance_screen.dart';
import 'screens/fireworks_screen.dart';
import 'screens/start_game_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/audio_test_screen.dart';
import 'screens/player_account_screen.dart';
import 'screens/kapi_store_screen.dart';
import 'screens/block_dominoes/block_domino_game_screen.dart';
import 'screens/domino_cpu_game_screen.dart' hide ClassicDominoGameScreen;
import 'screens/domino_online_game_screen.dart';
import 'screens/domino_teams/domino_teams_cpu_screen.dart';
import 'screens/domino_teams/domino_teams_online_lobby_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/simple_lobby/simple_lobby_screen.dart';
import 'locale_notifier.dart';
import 'theme_notifier.dart';
import 'game_settings_notifier.dart';
import 'font_size_notifier.dart';
import 'legal_acceptance_notifier.dart';
import 'premium_notifier.dart';
import 'widgets/force_update_gate.dart';
import 'widgets/screen_identifier.dart';

final screenIdentifierObserver = ScreenIdentifierObserver();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AnalyticsService.logAppOpen();
  // NEW: Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();
  await AudioManager.instance.initialize();

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
  final legalAcceptanceNotifier = LegalAcceptanceNotifier();
  final cosmeticsService = KapiCosmeticsService.instance;
  await cosmeticsService.load();
  final premiumNotifier = PremiumNotifier(
    coinPurchaseClaimer:
        (claimId, amount) => cosmeticsService.claimPurchasedCoins(
          claimId: claimId,
          amount: amount,
        ),
  );

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
        ChangeNotifierProvider.value(value: cosmeticsService),
      ],
      child: const DominoApp(),
    ),
  );
}

class DominoApp extends StatefulWidget {
  const DominoApp({super.key});

  @override
  State<DominoApp> createState() => _DominoAppState();
}

class _DominoAppState extends State<DominoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(WakelockPlus.disable());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeNotifier = Provider.of<LocaleNotifier>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(context);
    const debugInitialRoute = String.fromEnvironment(
      'KAPI_INITIAL_ROUTE',
      defaultValue: '/',
    );
    const debugOnlineGameId = String.fromEnvironment(
      'KAPI_DEBUG_ONLINE_GAME_ID',
    );
    const debugOnlinePlayerId = String.fromEnvironment(
      'KAPI_DEBUG_ONLINE_PLAYER_ID',
    );
    final debugRouteEnabled = debugInitialRoute != '/';
    Widget buildDebugInitialScreen() {
      switch (debugInitialRoute) {
        case '/home':
          return const HomeScreen();
        case '/legal':
          return const LegalAcceptanceScreen();
        case '/settings':
          return const SettingsHubScreen();
        case '/note-settings':
          return const SettingsScreen();
        case '/game-settings':
          return const GameAudioSettingsScreen();
        case '/premium':
          return const PremiumScreen();
        case '/about':
          return const AboutScreen();
        case '/terms-privacy':
          return const TermsPrivacyScreen();
        case '/game':
          return const GameScreen();
        case '/start-game':
          return const StartGameScreen();
        case '/ranking':
          return const RankingScreen();
        case '/audio-test':
          return const AudioTestScreen();
        case '/player-account':
          return const PlayerAccountScreen();
        case '/kapi-store':
          return const KapiStoreScreen();
        case '/domino-online':
          return const DominoOnlineGameScreen(
            gameId: debugOnlineGameId,
            playerId: debugOnlinePlayerId,
          );
        case '/lobby':
          return const LobbyScreen();
        case '/simple-lobby':
          return const SimpleLobbyScreen();
        case '/domino-classic':
        case '/domino-block':
          return const ClassicDominoGameScreen();
        case '/domino-draw':
          return const DrawDominoGameScreen();
        case '/domino-teams-cpu':
          return const DominoTeamsCpuScreen();
        case '/domino-teams-online-lobby':
          return const DominoTeamsOnlineLobbyScreen();
        default:
          return const SplashScreen();
      }
    }

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
      navigatorObservers: [AnalyticsService.observer, screenIdentifierObserver],
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
      initialRoute: debugRouteEnabled ? null : debugInitialRoute,
      onGenerateInitialRoutes:
          debugRouteEnabled
              ? (_) => [
                MaterialPageRoute<void>(
                  builder: (context) => buildDebugInitialScreen(),
                  settings: RouteSettings(name: debugInitialRoute),
                ),
              ]
              : null,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ScreenIdentifier(
          routeListenable: screenIdentifierObserver.currentRoute,
          child: ForceUpdateGate(child: child),
        );
      },
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/legal': (context) => const LegalAcceptanceScreen(),
        '/settings': (context) => const SettingsHubScreen(),
        '/note-settings': (context) => const SettingsScreen(),
        '/game-settings': (context) => const GameAudioSettingsScreen(),
        '/premium': (context) => const PremiumScreen(),
        '/about': (context) => const AboutScreen(),
        '/terms-privacy': (context) => const TermsPrivacyScreen(),
        '/game': (context) => const GameScreen(),
        '/start-game': (context) => const StartGameScreen(),
        '/ranking': (context) => const RankingScreen(),
        '/audio-test': (context) => const AudioTestScreen(),
        '/player-account': (context) => const PlayerAccountScreen(),
        '/kapi-store': (context) => const KapiStoreScreen(),
        '/lobby': (context) => const LobbyScreen(),
        '/simple-lobby': (context) => const SimpleLobbyScreen(),
        '/domino-block': (context) => const ClassicDominoGameScreen(),
        '/domino-classic': (context) => const ClassicDominoGameScreen(),
        '/domino-draw': (context) => const DrawDominoGameScreen(),
        '/domino-teams-cpu': (context) => const DominoTeamsCpuScreen(),
        '/domino-teams-online-lobby':
            (context) => const DominoTeamsOnlineLobbyScreen(),
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
