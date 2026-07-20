import 'package:dominoes_note2025/services/block_room_service.dart';
import 'package:dominoes_note2025/services/block_matchmaking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Block room exclusivity', () {
    test('available and missing sessions can search', () {
      expect(BlockRoomService.isBusy(null), isFalse);
      expect(BlockRoomService.isBusy({'state': 'available'}), isFalse);
    });

    test('a player in a room is busy', () {
      expect(
        BlockRoomService.isBusy({'state': 'inGame', 'activeGameId': 'room-a'}),
        isTrue,
      );
    });

    test('the same room may resume but a different room is blocked', () {
      final session = {'state': 'inGame', 'activeGameId': 'room-a'};
      expect(BlockRoomService.isBusy(session, exceptGameId: 'room-a'), isFalse);
      expect(BlockRoomService.isBusy(session, exceptGameId: 'room-b'), isTrue);
    });
  });

  test('a stale screen cannot abandon a different active room', () {
    const session = {'state': 'inGame', 'activeGameId': 'new-room'};
    expect(BlockRoomService.ownsRoom(session, 'old-room'), isFalse);
    expect(BlockRoomService.ownsRoom(session, 'new-room'), isTrue);
  });

  test('each matchmaking attempt has its own player-scoped token', () async {
    final first = BlockMatchmakingService.createSearchToken('jp.us.abc123');
    await Future<void>.delayed(const Duration(microseconds: 2));
    final second = BlockMatchmakingService.createSearchToken('jp.us.abc123');

    expect(first, startsWith('JP.US.ABC123-'));
    expect(second, isNot(first));
  });
}
