import 'package:dominoes_note2025/premium_notifier.dart';
import 'package:dominoes_note2025/screens/domino_cpu_game_screen.dart';
import 'package:dominoes_note2025/screens/start_game_screen.dart';
import 'package:dominoes_note2025/services/domino_match_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(_savedProfile);
  });

  testWidgets('Continue opens both Block variants on phone and desktop', (
    tester,
  ) async {
    for (final size in const [Size(320, 720), Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      await _pumpStartGame(tester);
      await tester.tap(find.byKey(const ValueKey('start-game-block-card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('block-variant-sheet')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('start-game-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('block-variant-sheet')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('block-variant-no-draw')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('block-variant-draw')), findsOneWidget);
      expect(find.text('Block without drawing'), findsOneWidget);
      expect(find.text('Draw / Pool'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('block-variant-no-draw')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('block-variant-draw'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Game mode only presents online play copy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStartGame(tester);

    expect(find.text('Team up and find rivals online'), findsOneWidget);
    expect(find.textContaining('CPU'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-game-block-card')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-game-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Available online.'), findsNWidgets(2));
    expect(find.textContaining('CPU'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Draw selection opens the lobby with draw_pool mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    RouteSettings? openedRoute;
    await _pumpStartGame(
      tester,
      onRouteOpened: (settings) => openedRoute = settings,
    );
    await tester.tap(find.byKey(const ValueKey('start-game-block-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('block-variant-sheet')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-game-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('block-variant-draw')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('simple-lobby-route-marker')),
      findsOneWidget,
    );
    expect(openedRoute?.name, '/simple-lobby');
    expect(openedRoute?.arguments, {
      'mode': DominoMatchMode.drawPool.storageValue,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('No-draw selection opens the lobby with block mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    RouteSettings? openedRoute;
    await _pumpStartGame(
      tester,
      onRouteOpened: (settings) => openedRoute = settings,
    );
    await tester.tap(find.byKey(const ValueKey('start-game-block-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('block-variant-sheet')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-game-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('block-variant-no-draw')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('simple-lobby-route-marker')),
      findsOneWidget,
    );
    expect(openedRoute?.name, '/simple-lobby');
    expect(openedRoute?.arguments, {
      'mode': DominoMatchMode.block.storageValue,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('Draw route starts with a fourteen-tile pool', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumNotifier>(
        create: (_) => _PremiumForTest(),
        child: const MaterialApp(home: DrawDominoGameScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final poolCount = find.byKey(const ValueKey('draw-pool-count'));
    expect(poolCount, findsOneWidget);
    expect((tester.widget<Text>(poolCount).data ?? ''), contains('14'));
    expect(find.textContaining('coming soon'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpStartGame(
  WidgetTester tester, {
  ValueChanged<RouteSettings>? onRouteOpened,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<PremiumNotifier>(
      create: (_) => _PremiumForTest(),
      child: MaterialApp(
        home: const StartGameScreen(),
        onGenerateRoute: (settings) {
          if (settings.name != '/simple-lobby') return null;
          onRouteOpened?.call(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder:
                (_) => const Scaffold(
                  body: SizedBox(key: ValueKey('simple-lobby-route-marker')),
                ),
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _PremiumForTest extends PremiumNotifier {
  @override
  bool get isPremium => true;

  @override
  bool get isMacPro => false;
}

const Map<String, Object> _savedProfile = {
  'kapi_player_profile_saved': true,
  'kapi_player_profile_initials': 'JP',
  'kapi_player_profile_display_name': 'Juan',
  'kapi_player_profile_code': 'ABC123',
  'kapi_player_profile_country': 'US',
  'kapi_player_profile_avatar': 'person',
};
