import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ScreenIdentifierObserver extends NavigatorObserver {
  ScreenIdentifierObserver() : currentRoute = ValueNotifier<String>('/');

  final ValueNotifier<String> currentRoute;

  void _setRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty || currentRoute.value == name) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentRoute.value != name) currentRoute.value = name;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setRoute(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _setRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class ScreenIdentifier extends StatelessWidget {
  const ScreenIdentifier({
    super.key,
    required this.routeListenable,
    required this.child,
  });

  final ValueListenable<String> routeListenable;
  final Widget child;

  static const bool _showDevelopmentLabels = bool.fromEnvironment(
    'KAPI_SHOW_SCREEN_LABELS',
    defaultValue: false,
  );

  static const Map<String, String> labels = {
    '/': 'Screen 00 - Splash',
    '/home': 'Screen 01 - Home',
    '/start-game': 'Screen 02 - Game Mode',
    '/simple-lobby': 'Screen 03 - Simple Lobby',
    '/simple-friends': 'Screen 04 - Friends',
    '/domino-block': 'Screen 05 - Block CPU',
    '/domino-teams-cpu': 'Screen 07 - Teams 2v2 CPU',
    '/domino-teams-online-lobby': 'Screen 07 - Teams Online Lobby',
    '/domino-teams-online': 'Screen 07 - Teams 2v2 Online',
    '/domino-classic': 'Screen 05 - Block CPU',
    '/domino-online': 'Screen 06 - Block Online',
    '/game': 'Screen 07 - Notes',
    '/settings': 'Screen 08 - Settings',
    '/game-settings': 'Screen 09 - Game Settings',
    '/note-settings': 'Screen 10 - Note Settings',
    '/profile': 'Screen 11 - Profile',
    '/ranking': 'Screen 12 - Ranking',
    '/premium': 'Screen 13 - Pro',
    '/legal': 'Screen 14 - Legal Acceptance',
    '/terms-privacy': 'Screen 15 - Terms & Privacy',
    '/about': 'Screen 16 - About',
    '/domino-draw': 'Screen 17 - Draw',
    '/audio-test': 'Screen 18 - Audio Test',
    '/fireworks': 'Screen 19 - Celebration',
    '/lobby': 'Screen 20 - Legacy Lobby',
    '/player-account': 'Screen 21 - Player Account',
    '/player-account-recovery': 'Screen 21 - Recover Profile',
  };

  @override
  Widget build(BuildContext context) {
    // Screen labels are only a development aid. They must never cover the
    // player's hand in APK/TestFlight builds.
    if (kReleaseMode || !_showDevelopmentLabels) return child;
    return ValueListenableBuilder<String>(
      valueListenable: routeListenable,
      builder: (context, route, _) {
        final label =
            labels[route] ?? 'Screen -- - ${route.isEmpty ? 'Route' : route}';
        return Stack(
          children: [
            child,
            Positioned(
              left: 4,
              bottom: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE6000000),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
