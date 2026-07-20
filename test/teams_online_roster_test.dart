import 'package:flutter_test/flutter_test.dart';
import 'package:dominoes_note2025/services/teams_online_service.dart';

void main() {
  TeamsOnlinePlayer player(String id, String initials) => TeamsOnlinePlayer(
    id: id,
    initials: initials,
    countryCode: 'US',
    avatarKey: 'person',
    points: 0,
    isCpu: false,
  );

  group('TeamsOnlineRoster', () {
    test('each device sees its own profile in the You seat', () {
      final jp = player('JP.US.JP0001', 'JP');
      final mp = player('MP.US.MP0002', 'MP');
      final room = [jp, mp];

      final jpView = TeamsOnlineRoster.relativeSeats(
        players: room,
        currentPlayerId: jp.id,
      );
      final mpView = TeamsOnlineRoster.relativeSeats(
        players: room,
        currentPlayerId: mp.id.toLowerCase(),
      );

      expect(jpView[0]?.initials, 'JP');
      expect(jpView[1]?.initials, 'MP');
      expect(mpView[0]?.initials, 'MP');
      expect(mpView[3]?.initials, 'JP');
    });

    test('keeps partner and rivals relative to the current player', () {
      final room = [
        player('A.US.AAAAA1', 'A0'),
        player('B.US.BBBBB2', 'B1'),
        player('C.US.CCCCC3', 'C2'),
        player('D.US.DDDDD4', 'D3'),
      ];

      final view = TeamsOnlineRoster.relativeSeats(
        players: room,
        currentPlayerId: room[1].id,
      );

      expect(view.map((entry) => entry?.initials), ['B1', 'C2', 'D3', 'A0']);
    });

    test('never labels another profile as You when identity is missing', () {
      final view = TeamsOnlineRoster.relativeSeats(
        players: [player('JP.US.JP0001', 'JP')],
        currentPlayerId: 'MP.US.MP0002',
      );

      expect(view, everyElement(isNull));
    });

    test('does not render a duplicate identity in two seats', () {
      final jp = player('JP.US.JP0001', 'JP');
      final duplicate = player('jp.us.jp0001', 'XX');
      final view = TeamsOnlineRoster.relativeSeats(
        players: [jp, duplicate],
        currentPlayerId: jp.id,
      );

      expect(view.whereType<TeamsOnlinePlayer>().length, 1);
      expect(view[0]?.initials, 'JP');
    });

    test('keeps the same identity after initials or country are edited', () {
      final stored = player('JP.US.ABC123', 'JP');
      final view = TeamsOnlineRoster.relativeSeats(
        players: [stored],
        currentPlayerId: 'MP.DO.ABC123',
      );

      expect(view[0], same(stored));
    });
  });

  group('TeamsInviteCapacity', () {
    test('allows several invited friends until the fourth seat is filled', () {
      expect(
        TeamsInviteCapacity.evaluate(
          status: 'waiting',
          playerIds: const ['A.US.AAAAA1', 'B.US.BBBBB2', 'C.US.CCCCC3'],
          joiningPlayerId: 'D.US.DDDDD4',
        ),
        TeamsInviteJoinResult.joined,
      );
    });

    test('reports room full to a late invited friend', () {
      expect(
        TeamsInviteCapacity.evaluate(
          status: 'waiting',
          playerIds: const [
            'A.US.AAAAA1',
            'B.US.BBBBB2',
            'C.US.CCCCC3',
            'D.US.DDDDD4',
          ],
          joiningPlayerId: 'E.US.EEEEE5',
        ),
        TeamsInviteJoinResult.roomFull,
      );
    });

    test('allows an accepted player to resume the same room', () {
      expect(
        TeamsInviteCapacity.evaluate(
          status: 'waiting',
          playerIds: const ['A.US.AAAAA1'],
          joiningPlayerId: 'A.DO.AAAAA1',
        ),
        TeamsInviteJoinResult.joined,
      );
    });
  });
}
