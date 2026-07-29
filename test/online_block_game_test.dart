import 'package:dominoes_note2025/screens/domino_online_game_screen.dart';
import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:dominoes_note2025/services/domino_match_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Block online keeps matching tips and round rules', () {
    expect(OnlineGameFactory.debugValidateBlockRules(), isTrue);
  });

  test(
    'Draw Pool online keeps the turn while drawing and preserves 28 tiles',
    () {
      expect(OnlineGameFactory.debugValidateDrawPoolRules(), isTrue);
    },
  );

  test('Block online board rectangles stay connected through turns', () {
    expect(OnlineGameFactory.debugValidateBoardGeometry(), isTrue);
  });

  test('Block online survives forty rapid deterministic games', () {
    expect(OnlineGameFactory.debugValidateRapidGames(), isTrue);
  });

  test('Block online keeps a valid full display name', () {
    expect(
      OnlineGameFactory.debugSafeDisplayName(
        '  María   José  ',
        fallback: 'MJ',
      ),
      'María José',
    );
  });

  test('Block online falls back to initials for old or invalid profiles', () {
    expect(OnlineGameFactory.debugSafeDisplayName(null, fallback: 'JP'), 'JP');
    expect(
      OnlineGameFactory.debugSafeDisplayName('Juan123', fallback: 'JP'),
      'JP',
    );
    expect(
      OnlineGameFactory.debugSafeDisplayName(
        <String, Object>{},
        fallback: 'AA',
      ),
      'AA',
    );
  });

  test('Fallback Block profile is coherent and explicitly non-human', () {
    const opponent = DominoPlayerProfile(
      initials: 'DI',
      displayName: 'Diego',
      countryCode: 'MX',
      code: 'BT1111',
      avatarKey: 'mexico_man',
    );
    final data = OnlineGameFactory.fallbackProfileDataForTesting(
      opponent: opponent,
      opponentPoints: 142,
    );

    expect(data['displayName'], 'Diego');
    expect(data['countryCode'], 'MX');
    expect(data['avatarKey'], 'mexico_man');
    expect(data['badgeKey'], 'flag_mx');
    expect(data['totalPoints'], 142);
    expect(data['isCpu'], isTrue);
    expect(data['isFallbackOnlinePlayer'], isTrue);
    expect(data['rankingEligible'], isFalse);
    expect(OnlineGameFactory.fallbackPlayerIdFor(opponent), 'DI.MX.BT1111');
    expect(
      DominoPlayerProfile.avatarAssetForKey(data['avatarKey'] as String),
      isNotNull,
    );
  });

  test('Fallback Block turn is legal and advances one revision', () {
    expect(OnlineGameFactory.debugValidateFallbackTurnProcessing(), isTrue);
  });

  test('Matchmaking factory accepts only the exact live reservation', () {
    const reservation = <String, dynamic>{
      'status': 'pairing',
      'searchToken': 'HOST-TOKEN',
      'pairingId': 'HOST__GUEST',
      'opponentId': 'BB.US.GUEST1',
      'pairingExpiresAt': 2000,
    };

    expect(
      OnlineGameFactory.matchmakingReservationValidForTesting(
        reservation,
        expectedSearchToken: 'HOST-TOKEN',
        expectedPairingId: 'HOST__GUEST',
        expectedOpponentId: 'bb.us.guest1',
        nowMillis: 1999,
      ),
      isTrue,
    );
    expect(
      OnlineGameFactory.matchmakingReservationValidForTesting(
        reservation,
        expectedSearchToken: 'OTHER-TOKEN',
        expectedPairingId: 'HOST__GUEST',
        expectedOpponentId: 'BB.US.GUEST1',
        nowMillis: 1999,
      ),
      isFalse,
    );
    expect(
      OnlineGameFactory.matchmakingReservationValidForTesting(
        reservation,
        expectedSearchToken: 'HOST-TOKEN',
        expectedPairingId: 'HOST__GUEST',
        expectedOpponentId: 'BB.US.GUEST1',
        nowMillis: 2000,
      ),
      isFalse,
    );
  });

  test('Matchmaking never pairs Block with Draw Pool', () {
    const drawReservation = <String, dynamic>{
      'status': 'pairing',
      'mode': 'draw_pool',
      'searchToken': 'DRAW-TOKEN',
      'pairingId': 'HOST__GUEST',
      'opponentId': 'BB.US.GUEST1',
      'pairingExpiresAt': 2000,
    };

    expect(
      OnlineGameFactory.matchmakingReservationValidForTesting(
        drawReservation,
        expectedSearchToken: 'DRAW-TOKEN',
        expectedPairingId: 'HOST__GUEST',
        expectedOpponentId: 'BB.US.GUEST1',
        expectedMode: DominoMatchMode.drawPool,
        nowMillis: 1999,
      ),
      isTrue,
    );
    expect(
      OnlineGameFactory.matchmakingReservationValidForTesting(
        drawReservation,
        expectedSearchToken: 'DRAW-TOKEN',
        expectedPairingId: 'HOST__GUEST',
        expectedOpponentId: 'BB.US.GUEST1',
        expectedMode: DominoMatchMode.block,
        nowMillis: 1999,
      ),
      isFalse,
    );
  });

  test('Fallback Block uses a natural but bounded turn delay', () {
    final first = OnlineGameFactory.fallbackTurnDelayFor('game-a', 4);
    final repeated = OnlineGameFactory.fallbackTurnDelayFor('game-a', 4);
    final next = OnlineGameFactory.fallbackTurnDelayFor('game-a', 5);

    expect(first, repeated);
    expect(first.inMilliseconds, inInclusiveRange(1200, 2599));
    expect(next.inMilliseconds, inInclusiveRange(1200, 2599));
  });

  test('Fallback reactions are occasional and match the game event', () {
    expect(
      OnlineGameFactory.fallbackReactionFor(
        actionType: 'pass',
        blocked: false,
        special: null,
        chanceRoll: 0.1,
        messageVariant: 0,
      ),
      'oops',
    );
    expect(
      OnlineGameFactory.fallbackReactionFor(
        actionType: 'roundEnd',
        blocked: true,
        special: null,
        chanceRoll: 0.1,
        messageVariant: 0,
      ),
      'wow',
    );
    expect(
      OnlineGameFactory.fallbackReactionFor(
        actionType: 'roundEnd',
        blocked: false,
        special: 'capicua',
        chanceRoll: 0.1,
        messageVariant: 1,
      ),
      'fire',
    );
    expect(
      OnlineGameFactory.fallbackReactionFor(
        actionType: 'roundEnd',
        blocked: false,
        special: null,
        chanceRoll: 0.9,
        messageVariant: 0,
      ),
      isNull,
    );
    expect(
      OnlineGameFactory.fallbackReactionFor(
        actionType: 'play',
        blocked: false,
        special: null,
        chanceRoll: 0,
        messageVariant: 0,
      ),
      isNull,
    );
  });

  test('Quick chat advances only its own sequence, not game revision', () {
    final update = OnlineGameFactory.quickChatUpdateForTesting(
      previous: const {'sequence': 4},
      playerId: 'fallback-game',
      messageId: 'wellPlayed',
      sentAtMillis: 1234,
      sourceRevision: 9,
    );
    final quickChat = update['quickChat'] as Map<String, dynamic>;

    expect(update, isNot(contains('revision')));
    expect(quickChat['sequence'], 5);
    expect(quickChat['playerId'], 'FALLBACK-GAME');
    expect(quickChat['messageId'], 'wellPlayed');
    expect(quickChat['emoji'], '👏');
    expect(quickChat['sentAtMillis'], 1234);
    expect(update['fallbackReactionRevision'], 9);
  });

  test('Fallback reaction revision is consumed only once', () {
    expect(
      OnlineGameFactory.fallbackReactionAvailableForTesting(const {
        'fallbackReactionRevision': 8,
      }, expectedRevision: 9),
      isTrue,
    );
    expect(
      OnlineGameFactory.fallbackReactionAvailableForTesting(const {
        'fallbackReactionRevision': 9,
      }, expectedRevision: 9),
      isFalse,
    );
  });
}
