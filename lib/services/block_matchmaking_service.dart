import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/domino_online_game_screen.dart';
import '../screens/domino_player_profile.dart';
import 'block_room_service.dart';
import 'domino_match_mode.dart';

class BlockMatchmakingService {
  BlockMatchmakingService(this.db, {this.mode = DominoMatchMode.block});

  final FirebaseFirestore db;
  final DominoMatchMode mode;

  static const quickSearchDuration = Duration(seconds: 8);
  static const humanArbitrationGrace = Duration(milliseconds: 750);
  static const cutoffHumanGrace = Duration(seconds: 3);
  static const remoteClockTolerance = Duration(seconds: 5);
  static const searchRecordFreshness = Duration(seconds: 90);
  static const pairingLeaseDuration = Duration(seconds: 12);
  static const fallbackAttemptTimeout = Duration(seconds: 3);
  static const fallbackRetryDelay = Duration(milliseconds: 250);
  static const fallbackWatchdogAttempts = 3;

  static const _fallbackProfiles = [
    (
      name: 'Juan',
      initials: 'JU',
      country: 'DO',
      avatar: 'caribbean_man',
      points: 135,
    ),
    (
      name: 'Sofía',
      initials: 'SO',
      country: 'PR',
      avatar: 'boricua_woman',
      points: 220,
    ),
    (
      name: 'Diego',
      initials: 'DI',
      country: 'MX',
      avatar: 'mexico_man',
      points: 85,
    ),
    (
      name: 'Arjun',
      initials: 'AR',
      country: 'IN',
      avatar: 'india_man',
      points: 165,
    ),
    (
      name: 'Valeria',
      initials: 'VA',
      country: 'ES',
      avatar: 'spanish_woman',
      points: 310,
    ),
    (
      name: 'Aiko',
      initials: 'AI',
      country: 'JP',
      avatar: 'asian_woman',
      points: 145,
    ),
    (
      name: 'Alex',
      initials: 'AL',
      country: 'US',
      avatar: 'person',
      points: 190,
    ),
    (
      name: 'Mohamed',
      initials: 'MO',
      country: 'EG',
      avatar: 'person',
      points: 105,
    ),
  ];
  static const _profileCodeAlphabet = '123456789ABCDEFGHIJKLMNPQRSTUVWXYZ';
  static int _lastSearchTokenMicros = 0;

  CollectionReference<Map<String, dynamic>> get _queue =>
      db.collection('kapi_block_matchmaking');

  DocumentReference<Map<String, dynamic>> get _rendezvousSlot =>
      _queue.doc('MATCH_SLOT_${mode.storageValue.toUpperCase()}');

  bool _matchesMode(Map<String, dynamic>? data) =>
      DominoMatchMode.fromValue(data?['mode']) == mode;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String playerId) =>
      _queue.doc(playerId.toUpperCase()).snapshots();

  static String createSearchToken(String playerId) {
    var micros = DateTime.now().microsecondsSinceEpoch;
    if (micros <= _lastSearchTokenMicros) {
      micros = _lastSearchTokenMicros + 1;
    }
    _lastSearchTokenMicros = micros;
    return '${playerId.toUpperCase()}-$micros';
  }

  static Duration remainingSearchDuration(DateTime deadline, {DateTime? now}) {
    final remaining = deadline.difference(now ?? DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static int pairingLeaseExpiresAt(DateTime now) =>
      now.add(pairingLeaseDuration).millisecondsSinceEpoch;

  static bool isEligibleSearchData(
    Map<String, dynamic>? data, {
    required DominoMatchMode mode,
    required DateTime now,
    Duration deadlineGrace = Duration.zero,
  }) {
    final clientUpdatedAt = (data?['clientUpdatedAt'] as num?)?.toInt() ?? 0;
    final deadlineAt = (data?['deadlineAt'] as num?)?.toInt() ?? 0;
    final searchToken = data?['searchToken'] as String? ?? '';
    final clockDelta = now.millisecondsSinceEpoch - clientUpdatedAt;
    return data?['status'] == 'searching' &&
        DominoMatchMode.fromValue(data?['mode']) == mode &&
        searchToken.isNotEmpty &&
        deadlineAt +
                deadlineGrace.inMilliseconds +
                remoteClockTolerance.inMilliseconds >
            now.millisecondsSinceEpoch &&
        clockDelta >= -remoteClockTolerance.inMilliseconds &&
        clockDelta <= searchRecordFreshness.inMilliseconds;
  }

  static ({DominoPlayerProfile profile, int points})
  fallbackOpponentForSearchToken(String searchToken) {
    final normalizedToken = searchToken.trim().toUpperCase();
    final profileIndex =
        _stableHash('$normalizedToken:PROFILE') % _fallbackProfiles.length;
    final values = _fallbackProfiles[profileIndex];
    return (
      profile: DominoPlayerProfile(
        initials: values.initials,
        displayName: values.name,
        countryCode: values.country,
        code: _stableProfileCode(normalizedToken),
        avatarKey: values.avatar,
      ),
      points: values.points,
    );
  }

  static int _stableHash(String value) {
    // Keep the result identical on iOS, Android and macOS. The modulus also
    // keeps every intermediate value within JavaScript's exact integer range.
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 131 + codeUnit) % 2147483629;
    }
    return hash;
  }

  static String _stableProfileCode(String searchToken) {
    var value = _stableHash('$searchToken:PUBLIC-ID');
    final code = StringBuffer();
    for (var index = 0; index < 6; index++) {
      code.write(_profileCodeAlphabet[value % _profileCodeAlphabet.length]);
      value =
          (value ~/ _profileCodeAlphabet.length +
              _stableHash('$searchToken:$index')) %
          2147483629;
    }
    return code.toString();
  }

  Future<String> start({
    required DominoPlayerProfile profile,
    required int points,
    required String searchToken,
  }) async {
    final playerId = profile.publicId.toUpperCase();
    final now = DateTime.now();
    final deadline = now.add(quickSearchDuration);
    final arbitrationDeadline = deadline.add(humanArbitrationGrace);
    final queueRef = _queue.doc(playerId);
    final publication = await db.runTransaction<_InitialPublication>((
      transaction,
    ) async {
      final queueSnapshot = await transaction.get(queueRef);
      final sessionSnapshot = await transaction.get(
        db.collection(BlockRoomService.sessionsCollection).doc(playerId),
      );
      final slotSnapshot = await transaction.get(_rendezvousSlot);
      final slotData = slotSnapshot.data();
      final slotPlayer =
          (slotData?['playerId'] as String? ?? '').trim().toUpperCase();
      final slotToken = slotData?['searchToken'] as String? ?? '';
      final mayHaveHumanCandidate =
          slotData?['status'] == 'matchSlot' &&
          DominoMatchMode.fromValue(slotData?['mode']) == mode &&
          slotPlayer.isNotEmpty &&
          slotPlayer != playerId &&
          slotToken.isNotEmpty;
      DocumentSnapshot<Map<String, dynamic>>? candidateSnapshot;
      DocumentSnapshot<Map<String, dynamic>>? candidateSession;
      if (mayHaveHumanCandidate) {
        candidateSnapshot = await transaction.get(_queue.doc(slotPlayer));
        candidateSession = await transaction.get(
          db.collection(BlockRoomService.sessionsCollection).doc(slotPlayer),
        );
      }
      if (BlockRoomService.isBusy(sessionSnapshot.data())) {
        throw StateError('You are already playing in another room.');
      }
      final queued = queueSnapshot.data();
      if (queued?['status'] == 'cancelled' &&
          queued?['searchToken'] == searchToken) {
        // Cancel can arrive while the initial session check is still in
        // flight. Its token tombstone must win that race.
        return const _InitialPublication.notPublished();
      }
      final transactionNow = DateTime.now();
      final queueData = <String, dynamic>{
        'playerId': playerId,
        'initials': profile.initials,
        'displayName': profile.effectiveDisplayName,
        'countryCode': profile.countryCode,
        'code': profile.code,
        'avatarKey': profile.avatarKey,
        'points': points,
        'mode': mode.storageValue,
        'status': 'searching',
        'searchToken': searchToken,
        'gameId': FieldValue.delete(),
        'opponentId': FieldValue.delete(),
        'pairingId': FieldValue.delete(),
        'pairingExpiresAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        'searchStartedAt': FieldValue.serverTimestamp(),
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'deadlineAt': deadline.millisecondsSinceEpoch,
      };
      final candidateData = candidateSnapshot?.data();
      final hasHumanCandidate =
          mayHaveHumanCandidate &&
          candidateData?['searchToken'] == slotToken &&
          isEligibleSearchData(
            candidateData,
            mode: mode,
            now: transactionNow,
            deadlineGrace: humanArbitrationGrace,
          ) &&
          !BlockRoomService.isBusy(candidateSession?.data());
      if (hasHumanCandidate) {
        final pairingId = _pairId(playerId, slotPlayer);
        final pairingExpiresAt = pairingLeaseExpiresAt(transactionNow);
        transaction.set(queueRef, {
          ...queueData,
          'status': 'pairing',
          'pairingId': pairingId,
          'opponentId': slotPlayer,
          'pairingExpiresAt': pairingExpiresAt,
        }, SetOptions(merge: true));
        transaction.set(_queue.doc(slotPlayer), {
          'status': 'pairing',
          'pairingId': pairingId,
          'opponentId': playerId,
          'pairingExpiresAt': pairingExpiresAt,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.delete(_rendezvousSlot);
        return _InitialPublication.human(
          opponentId: slotPlayer,
          opponentToken: slotToken,
          opponentData: Map<String, dynamic>.from(candidateData!),
          pairingId: pairingId,
        );
      }
      transaction.set(queueRef, queueData, SetOptions(merge: true));
      transaction.set(_rendezvousSlot, {
        'status': 'matchSlot',
        'mode': mode.storageValue,
        'playerId': playerId,
        'searchToken': searchToken,
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'deadlineAt': deadline.millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const _InitialPublication.searching();
    });
    if (!publication.published) return searchToken;

    if (publication.isHuman) {
      try {
        await OnlineGameFactory.createClassicGame(
          db: db,
          host: profile,
          guestId: publication.opponentId!,
          guestInitials:
              publication.opponentData?['initials'] as String? ?? 'P2',
          guestDisplayName:
              publication.opponentData?['displayName'] is String
                  ? publication.opponentData!['displayName'] as String
                  : null,
          mode: mode,
          expectedHostSearchToken: searchToken,
          expectedGuestSearchToken: publication.opponentToken,
          expectedPairingId: publication.pairingId,
        );
        return searchToken;
      } catch (error) {
        await _restoreHumanReservation(
          playerId: playerId,
          searchToken: searchToken,
          opponentId: publication.opponentId!,
          opponentToken: publication.opponentToken!,
          pairingId: publication.pairingId!,
        );
        if (error is! StateError ||
            !error.message.toString().contains(
              'matchmaking reservation expired',
            )) {
          rethrow;
        }
      }
    }

    // The visible search remains eight seconds. A short arbitration window
    // lets a real-player transaction that is already in flight win before an
    // automatic opponent is allowed to reserve the local queue document.
    final fallbackFuture = _runFallbackWatchdog(
      profile: profile,
      playerId: playerId,
      searchToken: searchToken,
      deadline: arbitrationDeadline,
    );
    unawaited(fallbackFuture);

    // Keep checking briefly because two players can enter the queue at nearly
    // the same time and miss each other on their first snapshots.
    while (DateTime.now().isBefore(arbitrationDeadline)) {
      // Check the tiny per-mode rendezvous document first. This path avoids a
      // collection-query/index delay consuming the entire eight-second window.
      try {
        final slotCandidate = await _loadRendezvousCandidate(
          playerId: playerId,
          searchToken: searchToken,
          deadline: arbitrationDeadline,
        );
        if (slotCandidate != null) {
          final matchedThroughSlot = await _reserveFirstAvailableCandidate(
            profile: profile,
            playerId: playerId,
            searchToken: searchToken,
            candidates: [slotCandidate],
            deadline: arbitrationDeadline,
          );
          if (matchedThroughSlot) return searchToken;
        }
      } on TimeoutException {
        break;
      }
      late final DocumentSnapshot<Map<String, dynamic>> self;
      try {
        self = await _beforeDeadline(
          arbitrationDeadline,
          () =>
              _queue.doc(playerId).get(const GetOptions(source: Source.server)),
        );
      } on TimeoutException {
        break;
      }
      final selfData = self.data();
      if (selfData?['searchToken'] != searchToken) {
        return searchToken;
      }
      final selfStatus = selfData?['status'] as String?;
      if (selfStatus == 'pairing') {
        String? recoveredStatus;
        try {
          recoveredStatus = await _waitForPairingResolution(
            playerId: playerId,
            searchToken: searchToken,
            deadline: arbitrationDeadline,
          );
        } on TimeoutException {
          break;
        }
        if (recoveredStatus != 'searching') return searchToken;
        if (!DateTime.now().isBefore(arbitrationDeadline)) break;
      } else if (selfStatus != 'searching') {
        return searchToken;
      }
      late final QuerySnapshot<Map<String, dynamic>> candidates;
      try {
        candidates = await _loadSearchingCandidates(arbitrationDeadline);
      } on TimeoutException {
        break;
      }
      if (!DateTime.now().isBefore(arbitrationDeadline)) break;
      final matched = await _reserveFirstAvailableCandidate(
        profile: profile,
        playerId: playerId,
        searchToken: searchToken,
        candidates: candidates.docs,
        deadline: arbitrationDeadline,
      );
      if (matched) return searchToken;
      final remaining = arbitrationDeadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 250)
            ? remaining
            : const Duration(milliseconds: 250),
      );
    }

    await fallbackFuture;
    return searchToken;
  }

  Future<T> _beforeDeadline<T>(
    DateTime deadline,
    Future<T> Function() operation,
  ) {
    final timeout = remainingSearchDuration(deadline);
    if (timeout <= Duration.zero) {
      return Future<T>.error(
        TimeoutException('The Block matchmaking deadline elapsed.'),
      );
    }
    return operation().timeout(timeout);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadSearchingCandidates(
    DateTime deadline,
  ) => _beforeDeadline(
    deadline,
    () => _queue
        .where('status', isEqualTo: 'searching')
        .where('mode', isEqualTo: mode.storageValue)
        .limit(24)
        .get(const GetOptions(source: Source.server)),
  );

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadRendezvousCandidate({
    required String playerId,
    required String searchToken,
    required DateTime deadline,
  }) async {
    Future<DocumentSnapshot<Map<String, dynamic>>?> candidateFromSlot(
      Map<String, dynamic>? slotData,
    ) async {
      final candidateId =
          (slotData?['playerId'] as String? ?? '').trim().toUpperCase();
      final candidateToken = slotData?['searchToken'] as String? ?? '';
      if (candidateId.isEmpty ||
          candidateId == playerId ||
          candidateToken.isEmpty) {
        return null;
      }
      final candidate = await _beforeDeadline(
        deadline,
        () => _queue
            .doc(candidateId)
            .get(const GetOptions(source: Source.server)),
      );
      if (candidate.data()?['searchToken'] != candidateToken ||
          !isEligibleSearchData(
            candidate.data(),
            mode: mode,
            now: DateTime.now(),
            deadlineGrace: humanArbitrationGrace,
          )) {
        return null;
      }
      return candidate;
    }

    final firstSlot = await _beforeDeadline(
      deadline,
      () => _rendezvousSlot.get(const GetOptions(source: Source.server)),
    );
    final immediateCandidate = await candidateFromSlot(firstSlot.data());
    if (immediateCandidate != null) return immediateCandidate;

    final selfRef = _queue.doc(playerId);
    await _beforeDeadline(
      deadline,
      () => db.runTransaction<void>((transaction) async {
        final selfSnapshot = await transaction.get(selfRef);
        final slotSnapshot = await transaction.get(_rendezvousSlot);
        final selfData = selfSnapshot.data();
        if (selfData?['searchToken'] != searchToken ||
            !isEligibleSearchData(
              selfData,
              mode: mode,
              now: DateTime.now(),
              deadlineGrace: humanArbitrationGrace,
            )) {
          return;
        }

        final slotData = slotSnapshot.data();
        final currentPlayer =
            (slotData?['playerId'] as String? ?? '').trim().toUpperCase();
        final currentToken = slotData?['searchToken'] as String? ?? '';
        if (currentPlayer.isNotEmpty &&
            currentPlayer != playerId &&
            currentToken.isNotEmpty) {
          final currentCandidate = await transaction.get(
            _queue.doc(currentPlayer),
          );
          if (currentCandidate.data()?['searchToken'] == currentToken &&
              isEligibleSearchData(
                currentCandidate.data(),
                mode: mode,
                now: DateTime.now(),
                deadlineGrace: humanArbitrationGrace,
              )) {
            return;
          }
        }

        transaction.set(_rendezvousSlot, {
          'status': 'matchSlot',
          'mode': mode.storageValue,
          'playerId': playerId,
          'searchToken': searchToken,
          'clientUpdatedAt': selfData?['clientUpdatedAt'],
          'deadlineAt': selfData?['deadlineAt'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
    );

    final refreshedSlot = await _beforeDeadline(
      deadline,
      () => _rendezvousSlot.get(const GetOptions(source: Source.server)),
    );
    return candidateFromSlot(refreshedSlot.data());
  }

  Future<void> _runFallbackWatchdog({
    required DominoPlayerProfile profile,
    required String playerId,
    required String searchToken,
    required DateTime deadline,
  }) async {
    final wait = remainingSearchDuration(deadline);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    await _runFallbackAttempts(
      profile: profile,
      playerId: playerId,
      searchToken: searchToken,
      attempts: fallbackWatchdogAttempts,
    );
  }

  Future<void> _runFallbackAttempts({
    required DominoPlayerProfile profile,
    required String playerId,
    required String searchToken,
    required int attempts,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final reserved = await _reserveFallbackOpponent(
          profile: profile,
          playerId: playerId,
          searchToken: searchToken,
        ).timeout(fallbackAttemptTimeout);
        if (reserved) return;
      } catch (error, stackTrace) {
        developer.log(
          'Block fallback attempt ${attempt + 1} failed.',
          name: 'BlockMatchmakingService',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (attempt + 1 < attempts) {
        await Future<void>.delayed(fallbackRetryDelay);
      }
    }
  }

  Future<bool> _reserveFallbackOpponent({
    required DominoPlayerProfile profile,
    required String playerId,
    required String searchToken,
  }) async {
    final fallback = fallbackOpponentForSearchToken(searchToken);
    final opponent = fallback.profile;
    final queueRef = _queue.doc(playerId);
    final sessionRef = db
        .collection(BlockRoomService.sessionsCollection)
        .doc(playerId);
    final reservation = await db.runTransaction<_CutoffReservation?>((
      transaction,
    ) async {
      final queueSnapshot = await transaction.get(queueRef);
      final sessionSnapshot = await transaction.get(sessionRef);
      final slotSnapshot = await transaction.get(_rendezvousSlot);
      final data = queueSnapshot.data();
      final deadlineAt = (data?['deadlineAt'] as num?)?.toInt() ?? 0;
      final transactionNow = DateTime.now();
      if (data?['status'] != 'searching' ||
          data?['searchToken'] != searchToken ||
          !_matchesMode(data) ||
          deadlineAt <= 0 ||
          transactionNow.millisecondsSinceEpoch <
              deadlineAt + humanArbitrationGrace.inMilliseconds ||
          BlockRoomService.isBusy(sessionSnapshot.data())) {
        return null;
      }

      final slotData = slotSnapshot.data();
      final candidateId =
          (slotData?['playerId'] as String? ?? '').trim().toUpperCase();
      final candidateToken = slotData?['searchToken'] as String? ?? '';
      DocumentSnapshot<Map<String, dynamic>>? candidateSnapshot;
      DocumentSnapshot<Map<String, dynamic>>? candidateSession;
      if (candidateId.isNotEmpty &&
          candidateId != playerId &&
          candidateToken.isNotEmpty) {
        candidateSnapshot = await transaction.get(_queue.doc(candidateId));
        candidateSession = await transaction.get(
          db.collection(BlockRoomService.sessionsCollection).doc(candidateId),
        );
      }

      final candidateData = candidateSnapshot?.data();
      final hasHumanCandidate =
          candidateId.isNotEmpty &&
          candidateId != playerId &&
          candidateToken.isNotEmpty &&
          candidateData?['searchToken'] == candidateToken &&
          isEligibleSearchData(
            candidateData,
            mode: mode,
            now: transactionNow,
            deadlineGrace: cutoffHumanGrace,
          ) &&
          !BlockRoomService.isBusy(candidateSession?.data());
      final pairingExpiresAt = pairingLeaseExpiresAt(transactionNow);
      if (hasHumanCandidate) {
        final pairingId = _pairId(playerId, candidateId);
        transaction.set(_queue.doc(candidateId), {
          'status': 'pairing',
          'pairingId': pairingId,
          'opponentId': playerId,
          'pairingExpiresAt': pairingExpiresAt,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(queueRef, {
          'status': 'pairing',
          'pairingId': pairingId,
          'opponentId': candidateId,
          'pairingExpiresAt': pairingExpiresAt,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.delete(_rendezvousSlot);
        return _CutoffReservation.human(
          opponentId: candidateId,
          opponentToken: candidateToken,
          opponentData: Map<String, dynamic>.from(candidateData!),
          pairingId: pairingId,
        );
      }

      final pairingId = _pairId(playerId, opponent.publicId);
      transaction.set(queueRef, {
        'status': 'pairing',
        'pairingId': pairingId,
        'opponentId': opponent.publicId.toUpperCase(),
        'pairingExpiresAt': pairingExpiresAt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.delete(_rendezvousSlot);
      return _CutoffReservation.fallback(pairingId: pairingId);
    });
    if (reservation == null) return false;

    try {
      if (reservation.isHuman) {
        await OnlineGameFactory.createClassicGame(
          db: db,
          host: profile,
          guestId: reservation.opponentId!,
          guestInitials:
              reservation.opponentData?['initials'] as String? ?? 'P2',
          guestDisplayName:
              reservation.opponentData?['displayName'] is String
                  ? reservation.opponentData!['displayName'] as String
                  : null,
          mode: mode,
          expectedHostSearchToken: searchToken,
          expectedGuestSearchToken: reservation.opponentToken,
          expectedPairingId: reservation.pairingId,
        );
      } else {
        await OnlineGameFactory.createFallbackClassicGame(
          db: db,
          host: profile,
          opponent: opponent,
          opponentPoints: fallback.points,
          mode: mode,
          expectedHostSearchToken: searchToken,
          expectedPairingId: reservation.pairingId,
        );
      }
      return true;
    } catch (_) {
      await db.runTransaction((transaction) async {
        final selfSnapshot = await transaction.get(queueRef);
        DocumentSnapshot<Map<String, dynamic>>? opponentSnapshot;
        if (reservation.isHuman) {
          opponentSnapshot = await transaction.get(
            _queue.doc(reservation.opponentId!),
          );
        }
        final selfData = selfSnapshot.data();
        if (selfData?['status'] == 'pairing' &&
            selfData?['searchToken'] == searchToken &&
            selfData?['pairingId'] == reservation.pairingId) {
          transaction.set(
            queueRef,
            _searchingAfterPairing(),
            SetOptions(merge: true),
          );
        }
        final opponentData = opponentSnapshot?.data();
        if (reservation.isHuman &&
            opponentData?['status'] == 'pairing' &&
            opponentData?['searchToken'] == reservation.opponentToken &&
            opponentData?['pairingId'] == reservation.pairingId) {
          transaction.set(
            _queue.doc(reservation.opponentId!),
            _searchingAfterPairing(),
            SetOptions(merge: true),
          );
        }
      });
      rethrow;
    }
  }

  Future<bool> _reserveFirstAvailableCandidate({
    required DominoPlayerProfile profile,
    required String playerId,
    required String searchToken,
    required List<DocumentSnapshot<Map<String, dynamic>>> candidates,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();
    for (final candidate in candidates) {
      if (!DateTime.now().isBefore(deadline)) return false;
      if (candidate.id.toUpperCase() == playerId) continue;
      final candidateDataAtRead = candidate.data();
      if (!isEligibleSearchData(
        candidateDataAtRead,
        mode: mode,
        now: now,
        deadlineGrace: humanArbitrationGrace,
      )) {
        continue;
      }
      if (candidateDataAtRead == null) continue;

      final pairingId = _pairId(playerId, candidate.id);
      final candidateToken =
          candidateDataAtRead['searchToken'] as String? ?? '';
      final reserved = await db.runTransaction<bool>((transaction) async {
        if (!DateTime.now().isBefore(deadline)) return false;
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
        final slotSnapshot = await transaction.get(_rendezvousSlot);
        final candidateData = candidateSnapshot.data();
        final selfData = selfSnapshot.data();
        final transactionNow = DateTime.now();
        if (!isEligibleSearchData(
              candidateData,
              mode: mode,
              now: transactionNow,
              deadlineGrace: humanArbitrationGrace,
            ) ||
            !isEligibleSearchData(
              selfData,
              mode: mode,
              now: transactionNow,
              deadlineGrace: humanArbitrationGrace,
            ) ||
            candidateData?['searchToken'] != candidateToken ||
            selfData?['searchToken'] != searchToken ||
            BlockRoomService.isBusy(candidateSession.data()) ||
            BlockRoomService.isBusy(selfSession.data())) {
          return false;
        }
        // Calculate the lease after every transaction retry so the game
        // factory always receives the complete reservation window.
        final pairingExpiresAt = pairingLeaseExpiresAt(transactionNow);
        transaction.set(candidate.reference, {
          'status': 'pairing',
          'pairingId': pairingId,
          'opponentId': playerId,
          'pairingExpiresAt': pairingExpiresAt,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(_queue.doc(playerId), {
          'status': 'pairing',
          'pairingId': pairingId,
          'opponentId': candidate.id.toUpperCase(),
          'pairingExpiresAt': pairingExpiresAt,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final slotData = slotSnapshot.data();
        final slotPlayer =
            (slotData?['playerId'] as String? ?? '').toUpperCase();
        final slotToken = slotData?['searchToken'] as String? ?? '';
        final slotBelongsToSelf =
            slotPlayer == playerId && slotToken == searchToken;
        final slotBelongsToCandidate =
            slotPlayer == candidate.id.toUpperCase() &&
            slotToken == candidateToken;
        if (slotBelongsToSelf || slotBelongsToCandidate) {
          transaction.delete(_rendezvousSlot);
        }
        return true;
      });
      if (!reserved) continue;

      try {
        await OnlineGameFactory.createClassicGame(
          db: db,
          host: profile,
          guestId: candidate.id,
          guestInitials: candidateDataAtRead['initials'] as String? ?? 'P2',
          guestDisplayName:
              candidateDataAtRead['displayName'] is String
                  ? candidateDataAtRead['displayName'] as String
                  : null,
          mode: mode,
          expectedHostSearchToken: searchToken,
          expectedGuestSearchToken: candidateToken,
          expectedPairingId: pairingId,
        );
      } catch (error) {
        await db.runTransaction((transaction) async {
          final selfSnapshot = await transaction.get(_queue.doc(playerId));
          final candidateSnapshot = await transaction.get(candidate.reference);
          if (selfSnapshot.data()?['status'] == 'pairing' &&
              selfSnapshot.data()?['searchToken'] == searchToken &&
              selfSnapshot.data()?['pairingId'] == pairingId) {
            transaction.set(_queue.doc(playerId), {
              'status': 'searching',
              'opponentId': FieldValue.delete(),
              'pairingId': FieldValue.delete(),
              'pairingExpiresAt': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          if (candidateSnapshot.data()?['status'] == 'pairing' &&
              candidateSnapshot.data()?['searchToken'] == candidateToken &&
              candidateSnapshot.data()?['pairingId'] == pairingId) {
            transaction.set(candidate.reference, {
              'status': 'searching',
              'opponentId': FieldValue.delete(),
              'pairingId': FieldValue.delete(),
              'pairingExpiresAt': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
        if (error is StateError &&
            error.message.toString().contains(
              'matchmaking reservation expired',
            )) {
          return false;
        }
        rethrow;
      }
      return true;
    }
    return false;
  }

  Future<void> cancel(String playerId, {String? expectedToken}) async {
    final normalizedPlayerId = playerId.toUpperCase();
    final reference = _queue.doc(normalizedPlayerId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final slotSnapshot = await transaction.get(_rendezvousSlot);
      final data = snapshot.data();
      final savedToken = data?['searchToken'] as String?;
      if (expectedToken != null &&
          savedToken != null &&
          savedToken != expectedToken) {
        return;
      }
      final status = data?['status'] as String?;
      final mayWriteTokenTombstone =
          expectedToken != null &&
          (data == null || status == null || status == 'cancelled');
      final canCancelActiveSearch =
          status == 'searching' ||
          (status == 'pairing' && expectedToken != null);
      final slotData = slotSnapshot.data();
      final slotToken = slotData?['searchToken'] as String?;
      final tokenToCancel = expectedToken ?? savedToken;
      final shouldCleanSlot =
          (slotData?['playerId'] as String? ?? '').toUpperCase() ==
              normalizedPlayerId &&
          tokenToCancel != null &&
          slotToken == tokenToCancel;
      if (!canCancelActiveSearch &&
          !mayWriteTokenTombstone &&
          !shouldCleanSlot) {
        return;
      }
      if (canCancelActiveSearch || mayWriteTokenTombstone) {
        transaction.set(reference, {
          'status': 'cancelled',
          'gameId': FieldValue.delete(),
          'opponentId': FieldValue.delete(),
          'pairingId': FieldValue.delete(),
          'pairingExpiresAt': FieldValue.delete(),
          'searchToken': expectedToken ?? FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (shouldCleanSlot) transaction.delete(_rendezvousSlot);
    });
  }

  Future<String?> _waitForPairingResolution({
    required String playerId,
    required String searchToken,
    required DateTime deadline,
  }) async {
    var resolutionDeadline = deadline;
    while (true) {
      final snapshot = await _beforeDeadline(
        resolutionDeadline,
        () => _queue.doc(playerId).get(const GetOptions(source: Source.server)),
      );
      final data = snapshot.data();
      if (data?['searchToken'] != searchToken) return null;
      final status = data?['status'] as String?;
      if (status != 'pairing') return status;
      final expiresAt = (data?['pairingExpiresAt'] as num?)?.toInt() ?? 0;
      final leaseDeadline = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      if (leaseDeadline.isAfter(resolutionDeadline)) {
        resolutionDeadline = leaseDeadline;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (expiresAt <= 0 || now >= expiresAt) {
        await _releaseExpiredPairing(
          playerId: playerId,
          searchToken: searchToken,
          pairingId: data?['pairingId'] as String? ?? '',
          opponentId: data?['opponentId'] as String? ?? '',
        );
        continue;
      }
      final remaining = Duration(milliseconds: expiresAt - now);
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 250)
            ? remaining
            : const Duration(milliseconds: 250),
      );
    }
  }

  Future<void> _releaseExpiredPairing({
    required String playerId,
    required String searchToken,
    required String pairingId,
    required String opponentId,
  }) async {
    if (pairingId.isEmpty) return;
    final selfRef = _queue.doc(playerId.toUpperCase());
    final cleanOpponentId = opponentId.toUpperCase();
    final opponentRef =
        cleanOpponentId.isEmpty ? null : _queue.doc(cleanOpponentId);
    await db.runTransaction((transaction) async {
      final selfSnapshot = await transaction.get(selfRef);
      final opponentSnapshot =
          opponentRef == null ? null : await transaction.get(opponentRef);
      final selfData = selfSnapshot.data();
      final expiresAt = (selfData?['pairingExpiresAt'] as num?)?.toInt() ?? 0;
      final expired =
          expiresAt <= 0 || DateTime.now().millisecondsSinceEpoch >= expiresAt;
      if (!expired ||
          selfData?['status'] != 'pairing' ||
          selfData?['searchToken'] != searchToken ||
          selfData?['pairingId'] != pairingId) {
        return;
      }
      transaction.set(
        selfRef,
        _searchingAfterPairing(),
        SetOptions(merge: true),
      );
      final opponentData = opponentSnapshot?.data();
      if (opponentRef != null &&
          opponentData?['status'] == 'pairing' &&
          opponentData?['pairingId'] == pairingId) {
        transaction.set(
          opponentRef,
          _searchingAfterPairing(),
          SetOptions(merge: true),
        );
      }
    });
  }

  Future<void> _restoreHumanReservation({
    required String playerId,
    required String searchToken,
    required String opponentId,
    required String opponentToken,
    required String pairingId,
  }) async {
    final selfRef = _queue.doc(playerId.toUpperCase());
    final opponentRef = _queue.doc(opponentId.toUpperCase());
    await db.runTransaction((transaction) async {
      final selfSnapshot = await transaction.get(selfRef);
      final opponentSnapshot = await transaction.get(opponentRef);
      final selfData = selfSnapshot.data();
      final opponentData = opponentSnapshot.data();
      if (selfData?['status'] == 'pairing' &&
          selfData?['searchToken'] == searchToken &&
          selfData?['pairingId'] == pairingId) {
        transaction.set(
          selfRef,
          _searchingAfterPairing(),
          SetOptions(merge: true),
        );
      }
      if (opponentData?['status'] == 'pairing' &&
          opponentData?['searchToken'] == opponentToken &&
          opponentData?['pairingId'] == pairingId) {
        transaction.set(
          opponentRef,
          _searchingAfterPairing(),
          SetOptions(merge: true),
        );
      }
    });
  }

  Map<String, dynamic> _searchingAfterPairing() => {
    'status': 'searching',
    'opponentId': FieldValue.delete(),
    'pairingId': FieldValue.delete(),
    'pairingExpiresAt': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static String _pairId(String first, String second) {
    final ids = [first.toUpperCase(), second.toUpperCase()]..sort();
    return '${ids.first}__${ids.last}';
  }
}

class _InitialPublication {
  const _InitialPublication._({
    required this.published,
    required this.isHuman,
    this.pairingId,
    this.opponentId,
    this.opponentToken,
    this.opponentData,
  });

  const _InitialPublication.notPublished()
    : this._(published: false, isHuman: false);

  const _InitialPublication.searching()
    : this._(published: true, isHuman: false);

  const _InitialPublication.human({
    required String opponentId,
    required String opponentToken,
    required Map<String, dynamic> opponentData,
    required String pairingId,
  }) : this._(
         published: true,
         isHuman: true,
         pairingId: pairingId,
         opponentId: opponentId,
         opponentToken: opponentToken,
         opponentData: opponentData,
       );

  final bool published;
  final bool isHuman;
  final String? pairingId;
  final String? opponentId;
  final String? opponentToken;
  final Map<String, dynamic>? opponentData;
}

class _CutoffReservation {
  const _CutoffReservation._({
    required this.isHuman,
    required this.pairingId,
    this.opponentId,
    this.opponentToken,
    this.opponentData,
  });

  const _CutoffReservation.human({
    required String opponentId,
    required String opponentToken,
    required Map<String, dynamic> opponentData,
    required String pairingId,
  }) : this._(
         isHuman: true,
         pairingId: pairingId,
         opponentId: opponentId,
         opponentToken: opponentToken,
         opponentData: opponentData,
       );

  const _CutoffReservation.fallback({required String pairingId})
    : this._(isHuman: false, pairingId: pairingId);

  final bool isHuman;
  final String pairingId;
  final String? opponentId;
  final String? opponentToken;
  final Map<String, dynamic>? opponentData;
}
