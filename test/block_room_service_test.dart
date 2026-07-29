import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dominoes_note2025/services/block_room_service.dart';
import 'package:dominoes_note2025/services/block_matchmaking_service.dart';
import 'package:dominoes_note2025/services/domino_match_mode.dart';
import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Block quick-match fallback', () {
    test('starts a fallback match after exactly eight seconds', () {
      expect(
        BlockMatchmakingService.quickSearchDuration,
        const Duration(seconds: 8),
      );
      expect(BlockMatchmakingService.fallbackWatchdogAttempts, greaterThan(1));
      expect(
        BlockMatchmakingService.fallbackAttemptTimeout,
        greaterThan(Duration.zero),
      );
      expect(
        BlockMatchmakingService.pairingLeaseDuration,
        greaterThan(Duration.zero),
      );
      expect(
        BlockMatchmakingService.pairingLeaseDuration,
        lessThanOrEqualTo(const Duration(seconds: 12)),
      );
    });

    test('remote reads are bounded by the search deadline', () {
      final now = DateTime(2026, 7, 28, 12);
      final deadline = now.add(const Duration(seconds: 8));

      expect(
        BlockMatchmakingService.remainingSearchDuration(deadline, now: now),
        const Duration(seconds: 8),
      );
      expect(
        BlockMatchmakingService.remainingSearchDuration(
          deadline,
          now: deadline.add(const Duration(milliseconds: 1)),
        ),
        Duration.zero,
      );
    });

    test('a future client clock cannot leave a search eligible forever', () {
      final now = DateTime(2026, 7, 28, 12);
      final validSearch = <String, dynamic>{
        'status': 'searching',
        'mode': 'block',
        'searchToken': 'AA.PR.ABC123-1',
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'deadlineAt':
            now
                .add(BlockMatchmakingService.quickSearchDuration)
                .millisecondsSinceEpoch,
      };
      expect(
        BlockMatchmakingService.isEligibleSearchData(
          validSearch,
          mode: DominoMatchMode.block,
          now: now,
        ),
        isTrue,
      );

      final futureClockSearch = Map<String, dynamic>.from(validSearch)
        ..['clientUpdatedAt'] =
            now
                .add(
                  BlockMatchmakingService.remoteClockTolerance +
                      const Duration(milliseconds: 1),
                )
                .millisecondsSinceEpoch;
      expect(
        BlockMatchmakingService.isEligibleSearchData(
          futureClockSearch,
          mode: DominoMatchMode.block,
          now: now,
        ),
        isFalse,
      );
    });

    test('the same search token always produces the same opponent', () {
      const token = 'AA.PR.ABC123-1722191234567';
      final first = BlockMatchmakingService.fallbackOpponentForSearchToken(
        token,
      );
      final second = BlockMatchmakingService.fallbackOpponentForSearchToken(
        token,
      );

      expect(second.profile.publicId, first.profile.publicId);
      expect(
        second.profile.effectiveDisplayName,
        first.profile.effectiveDisplayName,
      );
      expect(second.profile.avatarKey, first.profile.avatarKey);
      expect(second.points, first.points);
    });

    test('different searches receive unique real-style profile ids', () {
      final first = BlockMatchmakingService.fallbackOpponentForSearchToken(
        'AA.PR.ABC123-1722191234567',
      );
      final second = BlockMatchmakingService.fallbackOpponentForSearchToken(
        'AA.PR.ABC123-1722191234568',
      );

      expect(first.profile.publicId, isNot(second.profile.publicId));
      for (final fallback in [first, second]) {
        final profile = fallback.profile;
        expect(profile.initials, matches(RegExp(r'^[A-Z]{2}$')));
        expect(profile.countryCode, matches(RegExp(r'^[A-Z]{2}$')));
        expect(profile.code, matches(RegExp(r'^[A-NP-Z1-9]{6}$')));
        expect(
          profile.publicId,
          '${profile.initials}.${profile.countryCode}.${profile.code}',
        );
        expect(
          DominoPlayerProfile.isValidDisplayName(profile.effectiveDisplayName),
          isTrue,
        );
        expect(
          DominoPlayerProfile.avatarAssetForKey(profile.avatarKey),
          isNotNull,
        );
        expect(fallback.points, greaterThanOrEqualTo(0));
      }
    });
  });

  group('Block real-player concurrency', () {
    late FirebaseApp app;
    late FirebaseFirestore db;

    setUpAll(() async {
      if (!kIsWeb) return;
      app = await Firebase.initializeApp(
        name: 'block-matchmaking-concurrency',
        options: const FirebaseOptions(
          apiKey: 'local-emulator-key',
          appId: '1:123456789:web:block-matchmaking-test',
          messagingSenderId: '123456789',
          projectId: 'demo-kapi-block-matchmaking',
        ),
      );
      db = FirebaseFirestore.instanceFor(app: app);
      db.settings = const Settings(persistenceEnabled: false);
      db.useFirestoreEmulator('127.0.0.1', 8080);
    });

    tearDownAll(() async {
      if (kIsWeb) await app.delete();
    });

    test(
      'two simultaneous real searches share one room before fallback',
      () async {
        const firstProfile = DominoPlayerProfile(
          initials: 'TA',
          displayName: 'Test Alice',
          countryCode: 'US',
          code: 'A1B2C3',
          avatarKey: 'person',
        );
        const secondProfile = DominoPlayerProfile(
          initials: 'TB',
          displayName: 'Test Bruno',
          countryCode: 'PR',
          code: 'D4E5F6',
          avatarKey: 'caribbean_man',
        );
        final firstId = firstProfile.publicId.toUpperCase();
        final secondId = secondProfile.publicId.toUpperCase();
        final queue = db.collection('kapi_block_matchmaking');
        final sessions = db.collection(BlockRoomService.sessionsCollection);
        final lobbyProfiles = db.collection('kapi_lobby_profiles');

        Future<void> clearKnownState() async {
          final queueSnapshots = await Future.wait([
            queue.doc(firstId).get(),
            queue.doc(secondId).get(),
          ]);
          final gameIds =
              queueSnapshots
                  .map((snapshot) => snapshot.data()?['gameId'])
                  .whereType<String>()
                  .where((id) => id.isNotEmpty)
                  .toSet();
          final batch = db.batch();
          for (final id in [firstId, secondId]) {
            batch.delete(queue.doc(id));
            batch.delete(sessions.doc(id));
            batch.delete(lobbyProfiles.doc(id));
          }
          for (final gameId in gameIds) {
            batch.delete(db.collection('kapi_online_games').doc(gameId));
          }
          await batch.commit();
        }

        await clearKnownState();
        String? createdGameId;
        try {
          await Future.wait([
            lobbyProfiles.doc(firstId).set({
              ...firstProfile.toAccountMap(),
              'totalPoints': 120,
            }),
            lobbyProfiles.doc(secondId).set({
              ...secondProfile.toAccountMap(),
              'totalPoints': 180,
            }),
          ]);

          final firstService = BlockMatchmakingService(db);
          final secondService = BlockMatchmakingService(db);
          final stopwatch = Stopwatch()..start();
          await Future.wait([
            firstService.start(
              profile: firstProfile,
              points: 120,
              searchToken: BlockMatchmakingService.createSearchToken(firstId),
            ),
            secondService.start(
              profile: secondProfile,
              points: 180,
              searchToken: BlockMatchmakingService.createSearchToken(secondId),
            ),
          ]);
          stopwatch.stop();

          final queueSnapshots = await Future.wait([
            queue.doc(firstId).get(),
            queue.doc(secondId).get(),
          ]);
          final firstQueue = queueSnapshots[0].data();
          final secondQueue = queueSnapshots[1].data();
          expect(firstQueue?['status'], 'inGame');
          expect(secondQueue?['status'], 'inGame');
          expect(firstQueue?['opponentId'], secondId);
          expect(secondQueue?['opponentId'], firstId);
          expect(firstQueue?['gameId'], isNotEmpty);
          expect(secondQueue?['gameId'], firstQueue?['gameId']);
          createdGameId = firstQueue?['gameId'] as String?;
          expect(
            stopwatch.elapsed,
            lessThan(BlockMatchmakingService.quickSearchDuration),
            reason:
                'Two real clients must pair before the eight-second '
                'automatic-player fallback.',
          );

          final results = await Future.wait([
            db.collection('kapi_online_games').doc(createdGameId).get(),
            sessions.doc(firstId).get(),
            sessions.doc(secondId).get(),
          ]);
          final game = results[0].data();
          expect((game?['players'] as List<dynamic>?)?.toSet(), {
            firstId,
            secondId,
          });
          expect(game?['rankingEligible'], isTrue);
          final profiles = Map<String, dynamic>.from(
            game?['profiles'] as Map? ?? const <String, dynamic>{},
          );
          for (final playerId in [firstId, secondId]) {
            final profile = Map<String, dynamic>.from(
              profiles[playerId] as Map? ?? const <String, dynamic>{},
            );
            expect(profile['isCpu'], isFalse);
            expect(profile['isFallbackOnlinePlayer'], isFalse);
          }
          expect(results[1].data()?['activeGameId'], createdGameId);
          expect(results[2].data()?['activeGameId'], createdGameId);
        } finally {
          if (createdGameId != null) {
            await db
                .collection('kapi_online_games')
                .doc(createdGameId)
                .delete();
          }
          await clearKnownState();
        }
      },
      skip:
          !kIsWeb ? 'Run with Chrome and the local Firestore emulator.' : false,
    );
  });
}
