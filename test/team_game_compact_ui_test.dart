import 'package:dominoes_note2025/premium_notifier.dart';
import 'package:dominoes_note2025/screens/domino_cpu_game_screen.dart';
import 'package:dominoes_note2025/screens/domino_teams/domino_teams_cpu_screen.dart';
import 'package:dominoes_note2025/services/domino_display_settings.dart';
import 'package:dominoes_note2025/widgets/anchored_adaptive_banner_ad.dart';
import 'package:dominoes_note2025/widgets/app_version_label.dart';
import 'package:dominoes_note2025/widgets/game_audio_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Teams 2v2 never permits reset for an online match', () {
    expect(
      DominoTeamsCpuScreen.resetAllowedFor(onlineGameId: 'online-game'),
      isFalse,
    );
    expect(DominoTeamsCpuScreen.resetAllowedFor(onlineGameId: null), isTrue);
  });

  test('CPU reacts only sometimes to a genuine round pass', () {
    final reaction = DominoTeamsCpuScreen.cpuRoundPassReactionFor(
      scoringPlayer: 0,
      chanceRoll: 0.2,
      messageVariant: 0,
      useLeftRival: true,
    );
    expect(reaction, isNotNull);
    expect(reaction!.player, 1);
    expect(reaction.messageId, 'wellPlayed');

    final quiet = DominoTeamsCpuScreen.cpuRoundPassReactionFor(
      scoringPlayer: 0,
      chanceRoll: 0.9,
      messageVariant: 0,
      useLeftRival: true,
    );
    expect(quiet, isNull);
  });

  test('CPU that completes a round pass speaks for itself', () {
    final reaction = DominoTeamsCpuScreen.cpuRoundPassReactionFor(
      scoringPlayer: 2,
      chanceRoll: 0.1,
      messageVariant: 1,
      useLeftRival: false,
    );
    expect(reaction, isNotNull);
    expect(reaction!.player, 2);
    expect(reaction.messageId, 'laugh');
  });

  testWidgets(
    'Teams colored board preview accepts taps across its full painted area',
    (tester) async {
      var taps = 0;
      const targetKey = ValueKey('test-colored-board-preview');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TeamsSideChoiceTapTarget(
                key: targetKey,
                visualWidth: 72,
                visualHeight: 116,
                semanticsLabel: 'Play on the red tile',
                onTap: () => taps++,
                child: const SizedBox(width: 72, height: 116),
              ),
            ),
          ),
        ),
      );

      final target = find.byKey(targetKey);
      expect(tester.getSize(target), const Size(100, 144));
      await tester.tapAt(tester.getBottomRight(target) - const Offset(2, 2));
      await tester.pump();
      expect(taps, 1);
    },
  );

  testWidgets(
    'Block colored board preview accepts taps across its full painted area',
    (tester) async {
      var taps = 0;
      const targetKey = ValueKey('test-block-colored-board-preview');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BlockSideChoiceTapTarget(
                key: targetKey,
                visualWidth: 72,
                visualHeight: 116,
                semanticsLabel: 'Play on the blue tile',
                onTap: () => taps++,
                child: const SizedBox(width: 72, height: 116),
              ),
            ),
          ),
        ),
      );

      final target = find.byKey(targetKey);
      expect(tester.getSize(target), const Size(96, 140));
      await tester.tapAt(tester.getBottomRight(target) - const Offset(2, 2));
      await tester.pump();
      expect(taps, 1);
    },
  );

  testWidgets('Block paints profile cards above the gold table frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumNotifier>(
        create: (_) => PremiumNotifier(),
        child: const MaterialApp(
          home: DominoCpuGameScreen(mode: DominoCpuMode.classic),
        ),
      ),
    );
    await tester.pump();

    const frameKey = ValueKey('block-table-frame-layer');
    const profileKey = ValueKey('block-table-profile-layer');
    final stackFinder =
        find
            .ancestor(of: find.byKey(frameKey), matching: find.byType(Stack))
            .first;
    final stack = tester.widget<Stack>(stackFinder);
    final frameIndex = stack.children.indexWhere(
      (child) => child.key == frameKey,
    );
    final profileIndex = stack.children.indexWhere(
      (child) => child.key == profileKey,
    );

    expect(frameIndex, greaterThanOrEqualTo(0));
    expect(profileIndex, greaterThan(frameIndex));
    expect(find.byKey(const ValueKey('block-profile-player')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-profile-cpu')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Teams 2v2 header fits a narrow phone without UI overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumNotifier>(
        create: (_) => PremiumNotifier(),
        child: const MaterialApp(home: DominoTeamsCpuScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Teams 2 vs 2'), findsNothing);
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    expect(find.byTooltip('Notes'), findsOneWidget);
    expect(find.byType(AnchoredAdaptiveBannerAd), findsOneWidget);
    expect(find.byType(AppVersionLabel), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Dispose the game and let an already scheduled CPU think timer finish.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Teams 2v2 applies hand-size settings immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    DominoDisplaySettings.handTileScale.value = 1.0;
    DominoDisplaySettings.playedTileScale.value = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumNotifier>(
        create: (_) => PremiumNotifier(),
        child: const MaterialApp(home: DominoTeamsCpuScreen()),
      ),
    );
    await tester.pump();

    final normalHeight =
        tester.getSize(find.byKey(const ValueKey('teams-hand-area'))).height;
    await DominoDisplaySettings.saveHandTileScale(1.3);
    await tester.pump();
    final largerHeight =
        tester.getSize(find.byKey(const ValueKey('teams-hand-area'))).height;

    expect(largerHeight, greaterThan(normalHeight));
    expect(largerHeight, closeTo(normalHeight * 1.3, 0.01));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Teams 2v2 settings button opens working game controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumNotifier>(
        create: (_) => PremiumNotifier(),
        child: MaterialApp(
          home: const DominoTeamsCpuScreen(),
          routes: {
            '/game-settings':
                (_) => const Scaffold(body: Text('Full game settings')),
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GameAudioControls), findsOneWidget);
    expect(find.text('Game settings'), findsOneWidget);

    await tester.tap(find.text('Game settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Full game settings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Teams 2v2 keeps profile quick messages available in CPU mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumNotifier>(
        create: (_) => PremiumNotifier(),
        child: const MaterialApp(home: DominoTeamsCpuScreen()),
      ),
    );
    await tester.pump();

    final profileButton = find.byKey(
      const ValueKey('teams-quick-chat-profile'),
    );
    expect(profileButton, findsOneWidget);
    await tester.tap(profileButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byKey(const ValueKey('teams-player-profile-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('teams-player-avatar-large')),
      findsOneWidget,
    );
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Quick messages'), findsOneWidget);
    expect(find.text('Well played!'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('quick-chat-message-wellPlayed')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Well played!'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Teams 2v2 opens a large profile for the partner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumNotifier>(
        create: (_) => PremiumNotifier(),
        child: const MaterialApp(home: DominoTeamsCpuScreen()),
      ),
    );
    await tester.pump();

    final partnerProfile = find.byKey(const ValueKey('teams-player-profile-2'));
    expect(partnerProfile, findsOneWidget);
    await tester.tap(partnerProfile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('teams-player-profile-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('teams-player-avatar-large')),
      findsOneWidget,
    );
    expect(find.text('Player profile'), findsOneWidget);
    expect(find.text('Our team'), findsOneWidget);
    expect(find.text('Quick messages'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
