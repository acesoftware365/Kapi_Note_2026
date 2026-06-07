// main.dart
import 'package:dominoes_note2025/screens/team_name_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // NEW: Import AdMob

import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/game_screen.dart';
import 'screens/fireworks_screen.dart';
import 'locale_notifier.dart';
import 'theme_notifier.dart';
import 'game_settings_notifier.dart';
import 'font_size_notifier.dart';
import 'widgets/force_update_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NEW: Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final localeNotifier = LocaleNotifier();
  final themeNotifier = ThemeNotifier();
  final gameSettingsNotifier = GameSettingsNotifier();
  final fontSizeNotifier = FontSizeNotifier();
  final teamNameNotifier = TeamNameNotifier();

  await localeNotifier.loadLocale();
  await themeNotifier.loadThemeMode();
  await gameSettingsNotifier.loadSettings();
  await fontSizeNotifier.loadFontSize();
  await teamNameNotifier.loadTeamNames();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeNotifier),
        ChangeNotifierProvider.value(value: themeNotifier),
        ChangeNotifierProvider.value(value: gameSettingsNotifier),
        ChangeNotifierProvider.value(value: fontSizeNotifier),
        ChangeNotifierProvider.value(value: teamNameNotifier),
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
          bodyLarge: TextStyle(color: Colors.black87, fontSize: MediaQuery.of(context).textScaler.scale(16 * fontSizeNotifier.fontSizeScale)),
          bodyMedium: TextStyle(color: Colors.black54, fontSize: MediaQuery.of(context).textScaler.scale(14 * fontSizeNotifier.fontSizeScale)),
          headlineLarge: TextStyle(color: Colors.black87, fontSize: MediaQuery.of(context).textScaler.scale(28 * fontSizeNotifier.fontSizeScale)),
          headlineMedium: TextStyle(color: Colors.black87, fontSize: MediaQuery.of(context).textScaler.scale(20 * fontSizeNotifier.fontSizeScale)),
          titleLarge: TextStyle(color: Colors.black87, fontSize: MediaQuery.of(context).textScaler.scale(22 * fontSizeNotifier.fontSizeScale)),
          titleMedium: TextStyle(color: Colors.black87, fontSize: MediaQuery.of(context).textScaler.scale(16 * fontSizeNotifier.fontSizeScale)),
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
          bodyLarge: TextStyle(color: Colors.white70, fontSize: MediaQuery.of(context).textScaler.scale(16 * fontSizeNotifier.fontSizeScale)),
          bodyMedium: TextStyle(color: Colors.white54, fontSize: MediaQuery.of(context).textScaler.scale(14 * fontSizeNotifier.fontSizeScale)),
          headlineLarge: TextStyle(color: Colors.white, fontSize: MediaQuery.of(context).textScaler.scale(28 * fontSizeNotifier.fontSizeScale)),
          headlineMedium: TextStyle(color: Colors.white, fontSize: MediaQuery.of(context).textScaler.scale(20 * fontSizeNotifier.fontSizeScale)),
          titleLarge: TextStyle(color: Colors.white, fontSize: MediaQuery.of(context).textScaler.scale(22 * fontSizeNotifier.fontSizeScale)),
          titleMedium: TextStyle(color: Colors.white, fontSize: MediaQuery.of(context).textScaler.scale(16 * fontSizeNotifier.fontSizeScale)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      themeMode: themeNotifier.themeMode,
      debugShowCheckedModeBanner: false,
      locale: localeNotifier.locale,
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
        '/settings': (context) => const SettingsScreen(),
        '/about': (context) => const AboutScreen(),
        '/game': (context) => const GameScreen(),
        '/fireworks': (context) => const FireworksScreen(winningTeamName: '',),
      },
    );
  }
}
