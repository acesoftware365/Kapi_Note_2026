import 'package:dominoes_note2025/services/teams_online_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TeamsOnlinePlayer display names', () {
    test('legacy records use initials when displayName is absent', () {
      final player = TeamsOnlinePlayer.fromMap({
        'id': 'jp.us.abc123',
        'initials': 'jp',
        'countryCode': 'US',
        'avatarKey': 'person',
        'points': 12,
        'isCpu': false,
      });

      expect(player.initials, 'JP');
      expect(player.displayName, 'JP');
    });

    test('serializes a full display name without changing its spelling', () {
      final player = TeamsOnlinePlayer.fromMap({
        'id': 'jp.dr.abc123',
        'initials': 'jp',
        'displayName': 'Juan Pérez',
        'countryCode': 'DR',
        'avatarKey': 'person',
        'points': 12,
        'isCpu': false,
      });

      expect(player.displayName, 'Juan Pérez');
      expect(player.countryCode, 'DR');
      expect(player.toMap()['displayName'], 'Juan Pérez');
      expect(player.toMap()['countryCode'], 'DR');
    });

    test('CPU replacement keeps the original display name', () {
      const player = TeamsOnlinePlayer(
        id: 'JP.US.ABC123',
        initials: 'JP',
        displayName: 'Juan',
        countryCode: 'US',
        avatarKey: 'person',
        points: 12,
        isCpu: false,
      );

      expect(player.asCpu(2, 'game-1').displayName, 'Juan');
    });
  });

  group('Teams fallback online profiles', () {
    const expectedProfiles = {
      'Juan': ('DO', 'caribbean_man'),
      'Sofía': ('PR', 'boricua_woman'),
      'Diego': ('MX', 'mexico_man'),
      'Arjun': ('IN', 'india_man'),
      'Valeria': ('ES', 'spanish_woman'),
      'Aiko': ('JP', 'asian_woman'),
      'Alex': ('US', 'person'),
      'Mohamed': ('EG', 'person'),
    };

    test('uses four distinct identities in the same match', () {
      final players = TeamsOnlineService.fallbackPlayersForTesting('same-game');

      expect(players, hasLength(4));
      expect(players.map((player) => player.id).toSet(), hasLength(4));
      expect(players.map((player) => player.displayName).toSet(), hasLength(4));
    });

    test('keeps every name, country, avatar, and flag coherent', () {
      final players = TeamsOnlineService.fallbackPlayersForTesting(
        '',
        count: 8,
      );

      expect(
        players.map((player) => player.displayName).toSet(),
        expectedProfiles.keys.toSet(),
      );
      for (final player in players) {
        final expected = expectedProfiles[player.displayName];
        expect(expected, isNotNull);
        expect(player.countryCode, expected!.$1);
        expect(player.avatarKey, expected.$2);
        expect(player.badgeKey, 'flag_${player.countryCode.toLowerCase()}');
        expect(player.isCpu, isTrue);
        expect(player.isFallbackOnlinePlayer, isTrue);
      }
    });
  });
}
