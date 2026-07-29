import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:dominoes_note2025/screens/domino_teams/teams_match_found_transition_screen.dart';
import 'package:dominoes_note2025/services/teams_online_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const localPlayer = TeamsOnlinePlayer(
    id: 'AA.PR.LOCAL1',
    initials: 'AA',
    displayName: 'AA',
    countryCode: 'PR',
    avatarKey: 'person',
    points: 279,
    isCpu: false,
    badgeKey: 'flag_pr',
  );

  group('Teams quick-match fallback', () {
    test('starts filling missing seats after exactly eight seconds', () {
      expect(
        TeamsOnlineService.quickSearchDuration,
        const Duration(seconds: 8),
      );
    });

    test(
      'one human plus three fallback players makes a complete 4/4 table',
      () {
        final fallbackPlayers = TeamsOnlineService.fallbackPlayersForTesting(
          'lobby-fill-test',
          count: 3,
        );
        final waitingSeats = TeamsOnlineRoster.relativeSeats(
          players: const [localPlayer],
          currentPlayerId: localPlayer.id,
        );
        final completePlayers = <TeamsOnlinePlayer>[
          localPlayer,
          ...fallbackPlayers,
        ];
        final completeSeats = TeamsOnlineRoster.relativeSeats(
          players: completePlayers,
          currentPlayerId: localPlayer.id,
        );

        expect(waitingSeats.whereType<TeamsOnlinePlayer>(), hasLength(1));
        expect(completePlayers, hasLength(4));
        expect(completeSeats.whereType<TeamsOnlinePlayer>(), hasLength(4));
        expect(
          fallbackPlayers.every((player) => player.isFallbackOnlinePlayer),
          isTrue,
        );
        expect(
          fallbackPlayers.map((player) => player.id).toSet(),
          hasLength(3),
        );
        expect(
          fallbackPlayers.map((player) => player.displayName).toSet(),
          hasLength(3),
        );

        for (final player in fallbackPlayers) {
          expect(player.displayName, isNotEmpty);
          expect(player.countryCode, matches(RegExp(r'^[A-Z]{2}$')));
          expect(player.badgeKey, 'flag_${player.countryCode.toLowerCase()}');
          expect(
            DominoPlayerProfile.avatarAssetForKey(player.avatarKey),
            isNotNull,
            reason: '${player.displayName} needs a real avatar asset.',
          );
        }
      },
    );

    test('reveals the confirmed fallback roster one seat at a time', () {
      final completePlayers = <TeamsOnlinePlayer>[
        localPlayer,
        ...TeamsOnlineService.fallbackPlayersForTesting(
          'progressive-lobby-test',
          count: 3,
        ),
      ];

      final steps = TeamsOnlineRoster.revealSteps(
        currentPlayers: const [localPlayer],
        finalPlayers: completePlayers,
      );

      expect(steps.map((step) => step.length), [1, 2, 3, 4]);
      expect(steps.last, orderedEquals(completePlayers));
      for (final step in steps) {
        expect(
          step
              .map((player) => TeamsOnlineRoster.identityKey(player.id))
              .toSet(),
          hasLength(step.length),
          reason: 'Every visible seat must belong to a unique player.',
        );
      }
      expect(
        TeamsOnlineRoster.isConfirmed(
          players: steps[steps.length - 2],
          currentPlayerId: localPlayer.id,
        ),
        isFalse,
      );
      expect(
        TeamsOnlineRoster.isConfirmed(
          players: steps.last,
          currentPlayerId: localPlayer.id,
        ),
        isTrue,
      );
    });

    test(
      'keeps fallback names, flags and avatars through storage round-trip',
      () {
        final generated = TeamsOnlineService.fallbackPlayersForTesting(
          'round-trip-test',
          count: 3,
        );
        final restored = generated
            .map((player) => TeamsOnlinePlayer.fromMap(player.toMap()))
            .toList(growable: false);

        expect(
          restored.map((player) => TeamsOnlineRoster.identityKey(player.id)),
          generated.map((p) => TeamsOnlineRoster.identityKey(p.id)),
        );
        expect(
          restored.map((player) => player.displayName),
          generated.map((p) => p.displayName),
        );
        expect(
          restored.map((player) => player.countryCode),
          generated.map((p) => p.countryCode),
        );
        expect(
          restored.map((player) => player.avatarKey),
          generated.map((p) => p.avatarKey),
        );
        expect(
          restored.map((player) => player.badgeKey),
          generated.map((p) => p.badgeKey),
        );
        expect(
          restored.every((player) => player.isFallbackOnlinePlayer),
          isTrue,
        );
      },
    );

    test('does not confirm an invalid or foreign four-player roster', () {
      final fallbackPlayers = TeamsOnlineService.fallbackPlayersForTesting(
        'confirmation-test',
        count: 4,
      );
      final duplicatePlayers = <TeamsOnlinePlayer>[
        fallbackPlayers[0],
        fallbackPlayers[0],
        fallbackPlayers[2],
        fallbackPlayers[3],
      ];

      expect(
        TeamsOnlineRoster.isConfirmed(
          players: fallbackPlayers,
          currentPlayerId: localPlayer.id,
        ),
        isFalse,
        reason: 'The local player must be part of the confirmed match.',
      );
      expect(
        TeamsOnlineRoster.isConfirmed(
          players: duplicatePlayers,
          currentPlayerId: fallbackPlayers.first.id,
        ),
        isFalse,
        reason: 'A duplicated identity cannot occupy two seats.',
      );
      expect(
        TeamsOnlineRoster.revealSteps(
          currentPlayers: const [localPlayer],
          finalPlayers: duplicatePlayers,
        ),
        isEmpty,
      );
    });
  });

  testWidgets(
    'TEAMS READY receives and renders the complete four-player roster',
    (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final players = <TeamsOnlinePlayer>[
        localPlayer,
        ...TeamsOnlineService.fallbackPlayersForTesting(
          'transition-roster-test',
          count: 3,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: TeamsMatchFoundTransitionScreen(
            gameId: 'transition-roster-test',
            playerId: localPlayer.id,
            players: players,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      final transition = tester.widget<TeamsMatchFoundTransitionScreen>(
        find.byType(TeamsMatchFoundTransitionScreen),
      );
      expect(transition.players, hasLength(4));
      expect(
        TeamsOnlineRoster.relativeSeats(
          players: transition.players,
          currentPlayerId: transition.playerId,
        ).whereType<TeamsOnlinePlayer>(),
        hasLength(4),
      );

      for (final player in players) {
        expect(
          find.byKey(ValueKey('teams-ready-player-card-${player.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('teams-ready-player-avatar-${player.id}')),
          findsOneWidget,
        );
        expect(find.text(player.displayName), findsOneWidget);
      }

      expect(find.text('TEAMS READY'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
