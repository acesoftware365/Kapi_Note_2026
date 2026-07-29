import 'package:cloud_firestore/cloud_firestore.dart';

class BlockRoomService {
  BlockRoomService(this.db);

  final FirebaseFirestore db;

  static const sessionsCollection = 'kapi_block_player_sessions';

  static bool isBusy(Map<String, dynamic>? data, {String? exceptGameId}) {
    if (data == null || data['state'] != 'inGame') return false;
    final activeGameId = data['activeGameId'] as String? ?? '';
    return activeGameId.isNotEmpty && activeGameId != exceptGameId;
  }

  static bool ownsRoom(Map<String, dynamic>? data, String gameId) {
    if (data == null || data['state'] != 'inGame') return false;
    return (data['activeGameId'] as String? ?? '') == gameId;
  }

  Future<String?> activeGameId(String playerId) async {
    final snapshot =
        await db
            .collection(sessionsCollection)
            .doc(playerId.toUpperCase())
            .get();
    final data = snapshot.data();
    return isBusy(data) ? (data?['activeGameId'] as String?) : null;
  }

  Future<bool> canEnterRoom({
    required String playerId,
    required String gameId,
  }) async {
    final cleanPlayerId = playerId.toUpperCase();
    final snapshots = await Future.wait([
      db.collection(sessionsCollection).doc(cleanPlayerId).get(),
      db.collection('kapi_online_games').doc(gameId).get(),
    ]);
    final session = snapshots.first.data();
    final game = snapshots.last.data();
    if (!ownsRoom(session, gameId) || game == null) return false;
    final players = (game['players'] as List<dynamic>? ?? const []).map(
      (value) => value.toString().toUpperCase(),
    );
    final status = game['status'] as String? ?? '';
    return players.contains(cleanPlayerId) &&
        status != 'abandoned' &&
        status != 'matchOver';
  }

  Future<bool> waitUntilReleased({
    required String playerId,
    required String gameId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final cleanPlayerId = playerId.toUpperCase();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final snapshot = await db
          .collection(sessionsCollection)
          .doc(cleanPlayerId)
          .get(const GetOptions(source: Source.server));
      if (!ownsRoom(snapshot.data(), gameId)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> leaveGame({
    required String playerId,
    required String gameId,
    String reason = 'userRequested',
  }) async {
    final cleanPlayerId = playerId.toUpperCase();
    final gameRef = db.collection('kapi_online_games').doc(gameId);

    await db.runTransaction((transaction) async {
      final gameSnapshot = await transaction.get(gameRef);
      if (!gameSnapshot.exists) {
        _releasePlayer(transaction, cleanPlayerId);
        return;
      }

      final data = gameSnapshot.data() ?? <String, dynamic>{};
      final players =
          (data['players'] as List<dynamic>? ?? const [])
              .map((value) => value.toString().toUpperCase())
              .toList();
      final sessionSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in players) {
        sessionSnapshots[id] = await transaction.get(
          db.collection(sessionsCollection).doc(id),
        );
      }
      if (!ownsRoom(sessionSnapshots[cleanPlayerId]?.data(), gameId)) {
        return;
      }
      final otherPlayer = players.firstWhere(
        (id) => id != cleanPlayerId,
        orElse: () => '',
      );
      if (data['status'] != 'matchOver') {
        transaction.set(gameRef, {
          'status': 'abandoned',
          'matchOver': true,
          'abandonedBy': cleanPlayerId,
          'abandonmentReason': reason,
          'winnerId': otherPlayer,
          'message': '$cleanPlayerId left the room',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      for (final id in players) {
        final activeGameId =
            sessionSnapshots[id]?.data()?['activeGameId'] as String? ?? '';
        if (activeGameId == gameId) {
          _releasePlayer(transaction, id);
        }
      }
    });
  }

  Future<void> releaseCompletedGame({
    required List<String> players,
    required String gameId,
  }) async {
    await db.runTransaction((transaction) async {
      final ids = players.map((id) => id.toUpperCase()).toList();
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in ids) {
        snapshots.add(
          await transaction.get(db.collection(sessionsCollection).doc(id)),
        );
      }
      for (var index = 0; index < ids.length; index++) {
        final activeGameId =
            snapshots[index].data()?['activeGameId'] as String? ?? '';
        if (activeGameId == gameId) {
          _releasePlayer(transaction, ids[index]);
        }
      }
    });
  }

  void _releasePlayer(Transaction transaction, String playerId) {
    transaction.set(db.collection(sessionsCollection).doc(playerId), {
      'state': 'available',
      'activeGameId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    transaction.set(
      db.collection('kapi_block_matchmaking').doc(playerId),
      {
        'status': 'cancelled',
        'gameId': FieldValue.delete(),
        'opponentId': FieldValue.delete(),
        'pairingId': FieldValue.delete(),
        'searchToken': FieldValue.delete(),
        'mode': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    transaction.set(db.collection('kapi_lobby_profiles').doc(playerId), {
      'availability': 'available',
      'activeGameId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
