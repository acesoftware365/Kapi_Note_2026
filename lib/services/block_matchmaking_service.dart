import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/domino_online_game_screen.dart';
import '../screens/domino_player_profile.dart';
import 'block_room_service.dart';

class BlockMatchmakingService {
  BlockMatchmakingService(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _queue =>
      db.collection('kapi_block_matchmaking');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String playerId) =>
      _queue.doc(playerId.toUpperCase()).snapshots();

  static String createSearchToken(String playerId) =>
      '${playerId.toUpperCase()}-${DateTime.now().microsecondsSinceEpoch}';

  Future<String> start({
    required DominoPlayerProfile profile,
    required int points,
    required String searchToken,
  }) async {
    final playerId = profile.publicId.toUpperCase();
    final now = DateTime.now();
    if (await BlockRoomService(db).activeGameId(playerId) != null) {
      throw StateError('You are already playing in another room.');
    }
    await _queue.doc(playerId).set({
      'playerId': playerId,
      'initials': profile.initials,
      'countryCode': profile.countryCode,
      'code': profile.code,
      'avatarKey': profile.avatarKey,
      'points': points,
      'status': 'searching',
      'searchToken': searchToken,
      'gameId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'clientUpdatedAt': now.millisecondsSinceEpoch,
    }, SetOptions(merge: true));

    // Keep checking briefly because two players can enter the queue at nearly
    // the same time and miss each other on their first snapshots.
    for (var attempt = 0; attempt < 30; attempt++) {
      final self = await _queue.doc(playerId).get();
      if (self.data()?['searchToken'] != searchToken ||
          self.data()?['status'] != 'searching') {
        return searchToken;
      }
      final candidates =
          await _queue.where('status', isEqualTo: 'searching').limit(12).get();
      final matched = await _reserveFirstAvailableCandidate(
        profile: profile,
        playerId: playerId,
        searchToken: searchToken,
        candidates: candidates.docs,
      );
      if (matched) return searchToken;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return searchToken;
  }

  Future<bool> _reserveFirstAvailableCandidate({
    required DominoPlayerProfile profile,
    required String playerId,
    required String searchToken,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> candidates,
  }) async {
    final now = DateTime.now();
    for (final candidate in candidates) {
      if (candidate.id.toUpperCase() == playerId) continue;
      final timestamp = candidate.data()['clientUpdatedAt'] as int? ?? 0;
      if (now.millisecondsSinceEpoch - timestamp > 90000) continue;

      final pairingId = _pairId(playerId, candidate.id);
      final candidateToken = candidate.data()['searchToken'] as String? ?? '';
      final reserved = await db.runTransaction<bool>((transaction) async {
        final candidateSnapshot = await transaction.get(candidate.reference);
        final selfSnapshot = await transaction.get(_queue.doc(playerId));
        final candidateSession = await transaction.get(
          db
              .collection(BlockRoomService.sessionsCollection)
              .doc(candidate.id.toUpperCase()),
        );
        final selfSession = await transaction.get(
          db.collection(BlockRoomService.sessionsCollection).doc(playerId),
        );
        if (candidateSnapshot.data()?['status'] != 'searching' ||
            selfSnapshot.data()?['status'] != 'searching' ||
            candidateSnapshot.data()?['searchToken'] != candidateToken ||
            selfSnapshot.data()?['searchToken'] != searchToken ||
            candidateToken.isEmpty ||
            BlockRoomService.isBusy(candidateSession.data()) ||
            BlockRoomService.isBusy(selfSession.data())) {
          return false;
        }
        final values = {
          'status': 'pairing',
          'pairingId': pairingId,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        transaction.set(candidate.reference, values, SetOptions(merge: true));
        transaction.set(_queue.doc(playerId), values, SetOptions(merge: true));
        return true;
      });
      if (!reserved) continue;

      try {
        final candidateData = candidate.data();
        final gameId = await OnlineGameFactory.createClassicGame(
          db: db,
          host: profile,
          guestId: candidate.id,
          guestInitials: candidateData['initials'] as String? ?? 'P2',
        );
        final batch = db.batch();
        for (final id in [playerId, candidate.id.toUpperCase()]) {
          batch.set(_queue.doc(id), {
            'status': 'inGame',
            'gameId': gameId,
            'opponentId': id == playerId ? candidate.id : playerId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {
        await Future.wait([
          _queue.doc(playerId).set({
            'status': 'searching',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
          candidate.reference.set({
            'status': 'searching',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        ]);
        rethrow;
      }
      return true;
    }
    return false;
  }

  Future<void> cancel(String playerId, {String? expectedToken}) async {
    final reference = _queue.doc(playerId.toUpperCase());
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (expectedToken != null &&
          snapshot.data()?['searchToken'] != expectedToken) {
        return;
      }
      transaction.set(reference, {
        'status': 'cancelled',
        'gameId': FieldValue.delete(),
        'opponentId': FieldValue.delete(),
        'pairingId': FieldValue.delete(),
        'searchToken': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static String _pairId(String first, String second) {
    final ids = [first.toUpperCase(), second.toUpperCase()]..sort();
    return '${ids.first}__${ids.last}';
  }
}
