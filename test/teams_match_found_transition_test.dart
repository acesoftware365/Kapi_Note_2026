import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:dominoes_note2025/screens/domino_teams/teams_match_found_transition_screen.dart';
import 'package:dominoes_note2025/services/teams_online_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TeamsOnlinePlayer player({
    required String id,
    required String name,
    required String country,
    required String avatar,
  }) => TeamsOnlinePlayer(
    id: id,
    initials: name.substring(0, 2).toUpperCase(),
    displayName: name,
    countryCode: country,
    avatarKey: avatar,
    badgeKey: 'flag_${country.toLowerCase()}',
    points: 120,
    isCpu: false,
  );

  final players = <TeamsOnlinePlayer>[
    player(
      id: 'JU.DO.READY1',
      name: 'Juan',
      country: 'DO',
      avatar: 'caribbean_man',
    ),
    player(
      id: 'SO.PR.READY2',
      name: 'Sofía',
      country: 'PR',
      avatar: 'boricua_woman',
    ),
    player(
      id: 'AI.JP.READY3',
      name: 'Aiko',
      country: 'JP',
      avatar: 'asian_woman',
    ),
    player(
      id: 'MO.EG.READY4',
      name: 'Mohamed',
      country: 'EG',
      avatar: 'person',
    ),
  ];

  for (final width in const [320.0, 400.0, 440.0]) {
    testWidgets(
      'TEAMS READY keeps every flag, avatar and label visible at ${width.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: TeamsMatchFoundTransitionScreen(
              gameId: 'ready-layout-test',
              playerId: players.first.id,
              players: players,
            ),
          ),
        );
        // Finish the entrance animation but stop before the 3.8-second route
        // transition into the game.
        await tester.pump(const Duration(milliseconds: 3500));

        expect(find.text('TEAMS READY'), findsOneWidget);
        final screenRect = Offset.zero & Size(width, 720);

        for (final value in players) {
          final card = find.byKey(
            ValueKey('teams-ready-player-card-${value.id}'),
          );
          final flag = find.byKey(
            ValueKey('teams-ready-player-flag-${value.id}'),
          );
          final avatar = find.byKey(
            ValueKey('teams-ready-player-avatar-${value.id}'),
          );
          final text = find.byKey(
            ValueKey('teams-ready-player-text-${value.id}'),
          );

          expect(card, findsOneWidget);
          expect(flag, findsOneWidget);
          expect(avatar, findsOneWidget);
          expect(text, findsOneWidget);
          expect(find.text(value.displayName), findsOneWidget);

          final avatarVisual = find.descendant(
            of: avatar,
            matching: find.byType(DominoAvatarVisual),
          );
          expect(avatarVisual, findsOneWidget);
          expect(
            tester.widget<DominoAvatarVisual>(avatarVisual).avatarKey,
            value.avatarKey,
          );

          final cardRect = tester.getRect(card);
          final flagRect = tester.getRect(flag);
          final avatarRect = tester.getRect(avatar);
          final textRect = tester.getRect(text);

          for (final rect in [cardRect, flagRect, avatarRect, textRect]) {
            expect(rect.left, greaterThanOrEqualTo(screenRect.left));
            expect(rect.top, greaterThanOrEqualTo(screenRect.top));
            expect(rect.right, lessThanOrEqualTo(screenRect.right));
            expect(rect.bottom, lessThanOrEqualTo(screenRect.bottom));
          }
          for (final rect in [flagRect, avatarRect, textRect]) {
            expect(rect.left, greaterThanOrEqualTo(cardRect.left));
            expect(rect.top, greaterThanOrEqualTo(cardRect.top));
            expect(rect.right, lessThanOrEqualTo(cardRect.right));
            expect(rect.bottom, lessThanOrEqualTo(cardRect.bottom));
          }

          expect(flagRect.width, greaterThanOrEqualTo(18));
          expect(flagRect.height, greaterThanOrEqualTo(16));
          expect(
            flagRect.left,
            greaterThanOrEqualTo(avatarRect.right),
            reason:
                '${value.displayName} flag must remain fully visible beside the avatar.',
          );
          final fittedFlag = find.descendant(
            of: flag,
            matching: find.byType(FittedBox),
          );
          expect(fittedFlag, findsOneWidget);
          expect(
            tester.widget<FittedBox>(fittedFlag).fit,
            BoxFit.contain,
            reason: 'The complete flag must fit without being cropped.',
          );
        }

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
