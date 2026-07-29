import 'dart:math';

import 'package:dominoes_note2025/premium_notifier.dart';
import 'package:dominoes_note2025/screens/domino_cpu_game_screen.dart';
import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:dominoes_note2025/screens/domino_teams/domino_teams_cpu_screen.dart';
import 'package:dominoes_note2025/services/domino_display_settings.dart';
import 'package:dominoes_note2025/services/teams_online_service.dart';
import 'package:dominoes_note2025/widgets/anchored_adaptive_banner_ad.dart';
import 'package:dominoes_note2025/widgets/app_version_label.dart';
import 'package:dominoes_note2025/widgets/game_audio_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Teams results keep the real avatar for every online seat', (
    tester,
  ) async {
    final players = TeamsOnlineService.fallbackPlayersForTesting(
      'result-avatar-test',
      count: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var player = 0; player < players.length; player++)
                TeamsResultPlayerAvatar(
                  player: player,
                  avatarKey: players[player].avatarKey,
                  fallbackIcon: Icons.person_rounded,
                  size: 38,
                ),
            ],
          ),
        ),
      ),
    );

    for (var player = 0; player < players.length; player++) {
      final holder = find.byKey(ValueKey('teams-result-player-avatar-$player'));
      final avatar = find.descendant(
        of: holder,
        matching: find.byType(DominoAvatarVisual),
      );

      expect(holder, findsOneWidget);
      expect(avatar, findsOneWidget);
      expect(
        tester.widget<DominoAvatarVisual>(avatar).avatarKey,
        players[player].avatarKey,
      );
      expect(
        DominoPlayerProfile.avatarAssetForKey(players[player].avatarKey),
        isNotNull,
      );
    }
  });

  test('Only one human client coordinates fallback reactions', () {
    TeamsOnlinePlayer human(String id) => TeamsOnlinePlayer(
      id: id,
      initials: id.substring(0, 2),
      countryCode: 'US',
      avatarKey: 'person',
      points: 0,
      isCpu: false,
    );

    final first = human('AA.US.AAAAA1');
    final second = human('ZZ.US.ZZZZZ9');
    final fallback = TeamsOnlinePlayer(
      id: 'ONLINE-GAME-2',
      initials: 'MO',
      displayName: 'Mohamed',
      countryCode: 'EG',
      avatarKey: 'person',
      points: 0,
      isCpu: true,
      isFallbackOnlinePlayer: true,
    );
    final players = [second, fallback, first];

    expect(
      DominoTeamsCpuScreen.coordinatesFallbackReactions(
        currentPlayerId: first.id,
        players: players,
      ),
      isTrue,
    );
    expect(
      DominoTeamsCpuScreen.coordinatesFallbackReactions(
        currentPlayerId: second.id,
        players: players,
      ),
      isFalse,
    );
  });

  test('Teams 2v2 never permits reset for an online match', () {
    expect(
      DominoTeamsCpuScreen.resetAllowedFor(onlineGameId: 'online-game'),
      isFalse,
    );
    expect(DominoTeamsCpuScreen.resetAllowedFor(onlineGameId: null), isTrue);
  });

  test('Completed Teams match returns to the game-mode selector', () {
    expect(DominoTeamsCpuScreen.completedMatchGameModeRoute, '/start-game');
    expect(
      DominoTeamsCpuScreen.completedMatchGameModeRoute,
      isNot('/domino-teams-online-lobby'),
    );
  });

  test('Completed Teams match never applies the abandonment penalty', () {
    expect(
      DominoTeamsCpuScreen.shouldApplyAbandonmentPenalty(matchFinished: true),
      isFalse,
    );
    expect(
      DominoTeamsCpuScreen.shouldApplyAbandonmentPenalty(matchFinished: false),
      isTrue,
    );
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

  for (final viewport in const [Size(400, 529), Size(320, 720)]) {
    testWidgets('Teams 2v2 keeps slim mirrored CPU rails inside $viewport', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = viewport;
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

      final tableRect = tester.getRect(
        find.byKey(const ValueKey('teams-board-table')),
      );
      for (final player in [1, 2, 3]) {
        final profileRect = tester.getRect(
          find.byKey(ValueKey('teams-player-profile-$player')),
        );
        expect(profileRect.left, greaterThanOrEqualTo(tableRect.left));
        expect(profileRect.top, greaterThanOrEqualTo(tableRect.top));
        expect(profileRect.right, lessThanOrEqualTo(tableRect.right));
        expect(profileRect.bottom, lessThanOrEqualTo(tableRect.bottom));
      }

      Rect profileRect(int player) =>
          tester.getRect(find.byKey(ValueKey('teams-player-profile-$player')));
      Rect panelRect(int player) => tester.getRect(
        find.byKey(ValueKey('teams-player-side-panel-$player')),
      );
      Rect avatarRect(int player) => tester.getRect(
        find.byKey(ValueKey('teams-player-side-avatar-$player')),
      );
      Rect nameRect(int player) => tester.getRect(
        find.byKey(ValueKey('teams-player-side-name-$player')),
      );
      Rect rackRect(int player) => tester.getRect(
        find.byKey(ValueKey('teams-player-side-rack-$player')),
      );

      final leftProfile = profileRect(3);
      final rightProfile = profileRect(1);
      final leftPanel = panelRect(3);
      final rightPanel = panelRect(1);
      // The touch target sits against the visible green surface. The painted
      // pill is inset so the larger domino backs can visibly overhang it.
      expect(leftProfile.left, closeTo(tableRect.left + 6, 1));
      expect(rightProfile.right, closeTo(tableRect.right - 6, 1));
      expect(leftPanel.left, greaterThan(leftProfile.left));
      expect(rightPanel.right, lessThan(rightProfile.right));
      expect(
        leftPanel.left - leftProfile.left,
        closeTo(rightProfile.right - rightPanel.right, 1),
      );
      expect(leftProfile.center.dy, closeTo(tableRect.center.dy, 1));
      expect(rightProfile.center.dy, closeTo(tableRect.center.dy, 1));
      expect(
        find.byKey(const ValueKey('teams-player-tile-count-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('teams-player-tile-count-3')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('teams-player-side-flag-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('teams-player-side-flag-3')),
        findsNothing,
      );
      expect(find.byType(TeamsHiddenDominoBack), findsWidgets);

      for (final player in [1, 3]) {
        final avatarFinder = find.byKey(
          ValueKey('teams-player-side-avatar-$player'),
        );
        expect(avatarFinder, findsOneWidget);
        expect(
          find.descendant(
            of: avatarFinder,
            matching: find.byType(DominoAvatarVisual),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<DominoAvatarVisual>(
                find.descendant(
                  of: avatarFinder,
                  matching: find.byType(DominoAvatarVisual),
                ),
              )
              .avatarKey,
          'robot',
        );

        final content = find.byKey(
          ValueKey('teams-player-side-content-$player'),
        );
        final rack = find.byKey(ValueKey('teams-player-side-rack-$player'));
        final hiddenTiles = find.descendant(
          of: rack,
          matching: find.byType(TeamsHiddenDominoBack),
        );
        expect(content, findsOneWidget);
        expect(hiddenTiles, findsAtLeastNWidgets(6));

        final avatar = avatarRect(player);
        final name = nameRect(player);
        final rackBounds = rackRect(player);
        final panel = panelRect(player);
        expect(avatar.center.dx, closeTo(name.center.dx, 1));
        expect(name.center.dx, closeTo(rackBounds.center.dx, 1));

        if (player == 3) {
          expect(avatar.bottom, lessThanOrEqualTo(name.top));
          expect(name.bottom, lessThanOrEqualTo(rackBounds.top));
        } else {
          expect(rackBounds.bottom, lessThanOrEqualTo(name.top));
          expect(name.bottom, lessThanOrEqualTo(avatar.top));
        }

        for (final tile in hiddenTiles.evaluate()) {
          final tileRect = tester.getRect(find.byWidget(tile.widget));
          expect(tileRect.width, greaterThan(panel.width));
          expect(tileRect.left, greaterThanOrEqualTo(tableRect.left));
          expect(tileRect.top, greaterThanOrEqualTo(tableRect.top));
          expect(tileRect.right, lessThanOrEqualTo(tableRect.right));
          expect(tileRect.bottom, lessThanOrEqualTo(tableRect.bottom));
        }
      }

      expect(
        tester
            .widget<RotatedBox>(
              find.byKey(const ValueKey('teams-player-rotated-name-3')),
            )
            .quarterTurns,
        1,
      );
      expect(
        tester
            .widget<RotatedBox>(
              find.byKey(const ValueKey('teams-player-rotated-name-1')),
            )
            .quarterTurns,
        3,
      );

      final partnerProfile = find.byKey(
        const ValueKey('teams-player-profile-2'),
      );
      final partnerPanel = find.byKey(
        const ValueKey('teams-player-partner-panel'),
      );
      final partnerContent = find.byKey(
        const ValueKey('teams-player-partner-content'),
      );
      final partnerAvatar = find.byKey(
        const ValueKey('teams-player-partner-avatar'),
      );
      final partnerName = find.byKey(
        const ValueKey('teams-player-partner-name'),
      );
      final partnerRack = find.byKey(
        const ValueKey('teams-player-partner-rack'),
      );
      final partnerTiles = find.descendant(
        of: partnerRack,
        matching: find.byType(TeamsHiddenDominoBack),
      );

      expect(partnerPanel, findsOneWidget);
      expect(partnerContent, findsOneWidget);
      expect(partnerAvatar, findsOneWidget);
      expect(partnerName, findsOneWidget);
      expect(partnerRack, findsOneWidget);
      expect(partnerTiles, findsAtLeastNWidgets(6));
      final partnerAvatarVisual = find.descendant(
        of: partnerAvatar,
        matching: find.byType(DominoAvatarVisual),
      );
      expect(partnerAvatarVisual, findsOneWidget);
      expect(
        tester.widget<DominoAvatarVisual>(partnerAvatarVisual).avatarKey,
        'robot',
      );

      final partnerProfileRect = tester.getRect(partnerProfile);
      final partnerPanelRect = tester.getRect(partnerPanel);
      final partnerAvatarRect = tester.getRect(partnerAvatar);
      final partnerNameRect = tester.getRect(partnerName);
      final partnerRackRect = tester.getRect(partnerRack);

      expect(
        partnerAvatarRect.center.dy,
        closeTo(partnerNameRect.center.dy, 1),
      );
      expect(partnerNameRect.center.dy, closeTo(partnerRackRect.center.dy, 1));
      expect(partnerAvatarRect.right, lessThanOrEqualTo(partnerNameRect.left));
      expect(partnerNameRect.right, lessThanOrEqualTo(partnerRackRect.left));
      expect(partnerPanelRect.height, lessThan(partnerAvatarRect.height));
      expect(partnerAvatarRect.top, lessThan(partnerPanelRect.top));
      expect(partnerAvatarRect.bottom, greaterThan(partnerPanelRect.bottom));

      for (final rect in [
        partnerProfileRect,
        partnerPanelRect,
        partnerAvatarRect,
        partnerNameRect,
        partnerRackRect,
      ]) {
        expect(rect.left, greaterThanOrEqualTo(tableRect.left));
        expect(rect.top, greaterThanOrEqualTo(tableRect.top));
        expect(rect.right, lessThanOrEqualTo(tableRect.right));
        expect(rect.bottom, lessThanOrEqualTo(tableRect.bottom));
      }
      for (final tile in partnerTiles.evaluate()) {
        final tileRect = tester.getRect(find.byWidget(tile.widget));
        expect(tileRect.height, greaterThan(partnerPanelRect.height));
        expect(tileRect.top, lessThan(partnerPanelRect.top));
        expect(tileRect.bottom, greaterThan(partnerPanelRect.bottom));
        expect(tileRect.left, greaterThanOrEqualTo(tableRect.left));
        expect(tileRect.top, greaterThanOrEqualTo(tableRect.top));
        expect(tileRect.right, lessThanOrEqualTo(tableRect.right));
        expect(tileRect.bottom, lessThanOrEqualTo(tableRect.bottom));
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  for (final viewport in const [
    Size(320, 720),
    Size(400, 844),
    Size(440, 956),
  ]) {
    testWidgets(
      'Partner, CPU L and CPU R hidden tiles share one visual footprint at ${viewport.width.toInt()} px',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = viewport;
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

        Finder hiddenTilesIn(Finder rack) => find.descendant(
          of: rack,
          matching: find.byType(TeamsHiddenDominoBack),
        );

        final partnerTiles = hiddenTilesIn(
          find.byKey(const ValueKey('teams-player-partner-rack')),
        );
        final leftTiles = hiddenTilesIn(
          find.byKey(const ValueKey('teams-player-side-rack-3')),
        );
        final rightTiles = hiddenTilesIn(
          find.byKey(const ValueKey('teams-player-side-rack-1')),
        );

        expect(partnerTiles, findsWidgets);
        expect(leftTiles, findsWidgets);
        expect(rightTiles, findsWidgets);

        final partner = tester.widget<TeamsHiddenDominoBack>(
          partnerTiles.first,
        );
        final left = tester.widget<TeamsHiddenDominoBack>(leftTiles.first);
        final right = tester.widget<TeamsHiddenDominoBack>(rightTiles.first);
        final partnerSize = tester.getSize(partnerTiles.first);
        final leftSize = tester.getSize(leftTiles.first);
        final rightSize = tester.getSize(rightTiles.first);

        double shortEdge(Size size) => min(size.width, size.height);
        double longEdge(Size size) => max(size.width, size.height);
        double area(Size size) => size.width * size.height;

        expect(
          leftSize,
          rightSize,
          reason: 'CPU L and CPU R must be mirrored.',
        );
        expect(
          shortEdge(partnerSize),
          closeTo(shortEdge(leftSize), .01),
          reason: 'Partner and side dominoes need the same short edge.',
        );
        expect(
          longEdge(partnerSize),
          closeTo(longEdge(leftSize), .01),
          reason: 'Partner and side dominoes need the same long edge.',
        );
        expect(
          area(partnerSize),
          closeTo(area(leftSize), .01),
          reason: 'Rotating a hidden domino must not change its footprint.',
        );
        expect(partner.opacity, left.opacity);
        expect(left.opacity, right.opacity);

        for (final tile in [
          partnerTiles.first,
          leftTiles.first,
          rightTiles.first,
        ]) {
          expect(
            find.descendant(
              of: tile,
              matching: find.byKey(
                const ValueKey('teams-hidden-domino-divider'),
              ),
            ),
            findsOneWidget,
            reason: 'All three racks must use the same detailed domino back.',
          );
        }

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final viewport in const [
    Size(320, 720),
    Size(400, 844),
    Size(440, 956),
  ]) {
    testWidgets(
      'Partner shows complete 12- and 16-character names without touching its rack at ${viewport.width.toInt()} px',
      (tester) async {
        const shortName = 'Jo';
        const longName = 'Juan Alberto';
        const maxName = 'Maximiliano Jose';
        expect(longName.length, 12);
        expect(maxName.length, 16);

        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Widget gameWithPartnerName(String name) =>
            ChangeNotifierProvider<PremiumNotifier>(
              key: ValueKey('partner-name-$name'),
              create: (_) => PremiumNotifier(),
              child: MaterialApp(
                home: DominoTeamsCpuScreen(partnerDisplayNameForTesting: name),
              ),
            );

        double verifyPartnerLayout(String expectedName) {
          final panel = find.byKey(
            const ValueKey('teams-player-partner-panel'),
          );
          final profile = find.byKey(const ValueKey('teams-player-profile-2'));
          final avatar = find.byKey(
            const ValueKey('teams-player-partner-avatar'),
          );
          final name = find.byKey(const ValueKey('teams-player-partner-name'));
          final rack = find.byKey(const ValueKey('teams-player-partner-rack'));

          expect(find.text(expectedName), findsOneWidget);
          expect(name, findsOneWidget);
          final nameText = tester.widget<Text>(name);
          expect(nameText.data, expectedName);
          expect(nameText.data, isNot(contains('…')));
          expect(nameText.data, isNot(contains('...')));
          expect(nameText.maxLines, 1);
          expect(nameText.softWrap, isFalse);
          expect(nameText.overflow, isNot(TextOverflow.ellipsis));

          final nameScaler = find.ancestor(
            of: name,
            matching: find.byType(FittedBox),
          );
          expect(nameScaler, findsOneWidget);
          expect(tester.widget<FittedBox>(nameScaler).fit, BoxFit.scaleDown);

          final profileRect = tester.getRect(profile);
          final avatarRect = tester.getRect(avatar);
          final nameRect = tester.getRect(name);
          final rackRect = tester.getRect(rack);
          expect(nameRect.width, greaterThan(0));
          expect(nameRect.height, greaterThanOrEqualTo(8));
          expect(
            nameRect.left,
            greaterThanOrEqualTo(avatarRect.right),
            reason: 'The complete Partner name must start after the avatar.',
          );
          expect(
            nameRect.right,
            lessThanOrEqualTo(rackRect.left),
            reason: 'The complete Partner name must not overlap hidden tiles.',
          );
          for (final rect in [avatarRect, nameRect, rackRect]) {
            expect(rect.left, greaterThanOrEqualTo(profileRect.left));
            expect(rect.top, greaterThanOrEqualTo(profileRect.top));
            expect(rect.right, lessThanOrEqualTo(profileRect.right));
            expect(rect.bottom, lessThanOrEqualTo(profileRect.bottom));
          }
          return tester.getSize(panel).width;
        }

        await tester.pumpWidget(gameWithPartnerName(shortName));
        await tester.pump();
        final shortPanelWidth =
            tester
                .getSize(
                  find.byKey(const ValueKey('teams-player-partner-panel')),
                )
                .width;

        await tester.pumpWidget(gameWithPartnerName(longName));
        await tester.pump();
        final longPanelWidth = verifyPartnerLayout(longName);
        expect(
          longPanelWidth,
          greaterThan(shortPanelWidth),
          reason: 'The Partner panel must grow to preserve a longer name.',
        );

        await tester.pumpWidget(gameWithPartnerName(maxName));
        await tester.pump();
        final maxPanelWidth = verifyPartnerLayout(maxName);
        expect(
          maxPanelWidth,
          greaterThan(shortPanelWidth),
          reason:
              'The 16-character name must preserve more room than a short name.',
        );

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final viewport in const [Size(320, 720), Size(400, 844)]) {
    testWidgets('Online side names and large outer flags remain visible at '
        '${viewport.width.toInt()} px', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget rack(int player) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var tile = 0; tile < 7; tile++) ...[
            if (tile > 0) const SizedBox(height: 1),
            TeamsHiddenDominoBack(
              key: ValueKey('test-online-rack-$player-$tile'),
              width: 24,
              height: 13,
              opacity: 0.8,
            ),
          ],
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: viewport.width,
                height: 260,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 70,
                        child: TeamsSideRivalIdentity(
                          player: 3,
                          isLeft: true,
                          compact: true,
                          showOnlineAvatar: true,
                          name: 'Mateo Santiago',
                          avatarKey: 'caribbean_man',
                          flagEmoji: '🇵🇷',
                          rack: rack(3),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 70,
                        child: TeamsSideRivalIdentity(
                          player: 1,
                          isLeft: false,
                          compact: true,
                          showOnlineAvatar: true,
                          name: 'Aiko Nakamura',
                          avatarKey: 'asian_woman',
                          flagEmoji: '🇯🇵',
                          rack: rack(1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final player in [1, 3]) {
        final expectedName = player == 3 ? 'Mateo Santiago' : 'Aiko Nakamura';
        final content = find.byKey(
          ValueKey('teams-player-side-content-$player'),
        );
        final avatar = find.byKey(ValueKey('teams-player-side-avatar-$player'));
        final name = find.byKey(ValueKey('teams-player-side-name-$player'));
        final rotatedName = find.byKey(
          ValueKey('teams-player-rotated-name-$player'),
        );
        final rackFinder = find.byKey(
          ValueKey('teams-player-side-rack-$player'),
        );
        final flag = find.byKey(ValueKey('teams-player-side-flag-$player'));

        expect(content, findsOneWidget);
        expect(avatar, findsOneWidget);
        expect(name, findsOneWidget);
        expect(rotatedName, findsOneWidget);
        expect(rackFinder, findsOneWidget);
        expect(flag, findsOneWidget);
        expect(find.text(expectedName), findsOneWidget);

        final nameText = tester.widget<Text>(
          find.descendant(of: rotatedName, matching: find.byType(Text)),
        );
        expect(nameText.data, expectedName);
        expect(nameText.maxLines, 1);
        expect(nameText.softWrap, isNot(true));
        expect(nameText.overflow, isNot(TextOverflow.ellipsis));
        expect(
          tester.widget<RotatedBox>(rotatedName).quarterTurns,
          player == 3 ? 1 : 3,
        );
        final nameScaler = find.ancestor(
          of: rotatedName,
          matching: find.byType(FittedBox),
        );
        expect(nameScaler, findsOneWidget);
        expect(tester.widget<FittedBox>(nameScaler).fit, BoxFit.scaleDown);

        final contentRect = tester.getRect(content);
        final avatarRect = tester.getRect(avatar);
        final nameRect = tester.getRect(name);
        final rackRect = tester.getRect(rackFinder);
        final flagRect = tester.getRect(flag);
        final flagWidget = tester.widget(flag);
        final flagText =
            flagWidget is Text
                ? flagWidget
                : tester.widget<Text>(
                  find.descendant(of: flag, matching: find.byType(Text)),
                );

        expect(flagText.data, player == 3 ? '🇵🇷' : '🇯🇵');
        expect(
          find.ancestor(of: flag, matching: find.byType(RotatedBox)),
          findsNothing,
        );
        expect(
          flagRect.width,
          inInclusiveRange(avatarRect.width * 0.75, avatarRect.width * 1.25),
        );
        expect(
          flagRect.height,
          inInclusiveRange(avatarRect.height * 0.75, avatarRect.height * 1.25),
        );
        expect(flagRect.center.dx, closeTo(rackRect.center.dx, 1));

        if (player == 3) {
          expect(avatarRect.bottom, lessThanOrEqualTo(nameRect.top));
          expect(nameRect.bottom, lessThanOrEqualTo(rackRect.top));
          expect(rackRect.bottom, lessThanOrEqualTo(flagRect.top));
          expect(flagRect.bottom, closeTo(contentRect.bottom, 1));
        } else {
          expect(flagRect.bottom, lessThanOrEqualTo(rackRect.top));
          expect(rackRect.bottom, lessThanOrEqualTo(nameRect.top));
          expect(nameRect.bottom, lessThanOrEqualTo(avatarRect.top));
          expect(flagRect.top, closeTo(contentRect.top, 1));
        }

        for (final rect in [avatarRect, nameRect, rackRect, flagRect]) {
          expect(rect.left, greaterThanOrEqualTo(contentRect.left));
          expect(rect.top, greaterThanOrEqualTo(contentRect.top));
          expect(rect.right, lessThanOrEqualTo(contentRect.right));
          expect(rect.bottom, lessThanOrEqualTo(contentRect.bottom));
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Hidden domino relief preserves the compact tile footprint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TeamsHiddenDominoBack(
              key: ValueKey('compact-hidden-domino'),
              width: 24,
              height: 13,
              opacity: 0.8,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('compact-hidden-domino'))),
      const Size(24, 13),
    );
    expect(
      find.byKey(const ValueKey('teams-hidden-domino-divider')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
