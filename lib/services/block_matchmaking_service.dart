import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/domino_online_game_screen.dart';
import '../screens/domino_player_profile.dart';

class BlockMatchmakingService {
  BlockMatchmakingService(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _queue =>
      db.collection('kapi_block_matchmaking');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String playerId) =>
      _queue.doc(playerId.toUpperCase()).snapshots();

  Future<void> start({
    required DominoPlayerProfile profile,
    required int points,
  }) async {
    final playerId = profile.publicId.toUpperCase();
    final now = DateTime.now();
    await _queue.doc(playerId).set({
      'playerId': playerId,
      'initials': profile.initials,
      'countryCode': profile.countryCode,
      'code': profile.code,
      'avatarKey': profile.avatarKey,
      'points': points,
      'status': 'searching',
      'gameId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'clientUpdatedAt': now.millisecondsSinceEpoch,
    }, SetOptions(merge: true));

    final candidates =
        await _queue.where('status', isEqualTo: 'searching').limit(12).get();
    for (final candidate in candidates.docs) {
      if (candidate.id.toUpperCase() == playerId) continue;
      final timestamp = candidate.data()['clientUpdatedAt'] as int? ?? 0;
      if (now.millisecondsSinceEpoch - timestamp > 90000) continue;

      final pairingId = _pairId(playerId, candidate.id);
      final reserved = await db.runTransaction<bool>((transaction) async {
        final candidateSnapshot = await transaction.get(candidate.reference);
        final selfSnapshot = await transaction.get(_queue.doc(playerId));
        if (candidateSnapshot.data()?['status'] != 'searching' ||
            selfSnapshot.data()?['status'] != 'searching') {
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
            'status': 'matched',
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
      return;
    }
  }

  Future<void> cancel(String playerId) =>
      _queue.doc(playerId.toUpperCase()).set({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  static String _pairId(String first, String second) {
    final ids = [first.toUpperCase(), second.toUpperCase()]..sort();
    return '${ids.first}__${ids.last}';
  }
}
