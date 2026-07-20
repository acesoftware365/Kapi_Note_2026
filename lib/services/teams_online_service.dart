import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../screens/domino_player_profile.dart';
import '../screens/domino_teams/team_scoring_rules.dart';
import 'kapi_cosmetics_service.dart';
import 'team_domino_chain_validator.dart';

class TeamsOnlinePlayer {
  const TeamsOnlinePlayer({
    required this.id,
    required this.initials,
    required this.countryCode,
    required this.avatarKey,
    required this.points,
    required this.isCpu,
    this.badgeKey = 'flag_none',
  });

  final String id;
  final String initials;
  final String countryCode;
  final String avatarKey;
  final int points;
  final bool isCpu;
  final String badgeKey;

  factory TeamsOnlinePlayer.fromMap(Map<String, dynamic> map) =>
      TeamsOnlinePlayer(
        id: (map['id'] as String? ?? '').toUpperCase(),
        initials: (map['initials'] as String? ?? 'CPU').toUpperCase(),
        countryCode: (map['countryCode'] as String? ?? 'US').toUpperCase(),
        avatarKey: map['avatarKey'] as String? ?? 'person',
        points: (map['points'] as num?)?.toInt() ?? 0,
        isCpu: map['isCpu'] as bool? ?? false,
        badgeKey: map['badgeKey'] as String? ?? 'flag_none',
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'initials': initials,
    'countryCode': countryCode,
    'avatarKey': avatarKey,
    'points': points,
    'isCpu': isCpu,
    'badgeKey': badgeKey,
  };

  TeamsOnlinePlayer asCpu(int seat, String gameId) => TeamsOnlinePlayer(
    id: 'CPU-$gameId-$seat',
    initials: 'CPU ${seat + 1}',
    countryCode: countryCode,
    avatarKey: 'robot',
    points: points,
    isCpu: true,
    badgeKey: 'flag_none',
  );
}

/// Keeps every lobby seat attached to the same immutable player id while the
/// UI rotates the table so the current player is always shown at the bottom.
///
/// Firestore preserves the room's global seat order. Different devices can be
/// in different global seats, so the UI must never assume that list index 0 is
/// the local player.
class TeamsOnlineRoster {
  const TeamsOnlineRoster._();

  static String normalizeId(String value) => value.trim().toUpperCase();

  /// The six-character profile code is stable even if the player edits their
  /// initials or country later. CPU ids and legacy ids remain unchanged.
  static String identityKey(String value) {
    final normalized = normalizeId(value);
    final parts = normalized.split('.');
    return parts.length == 3 && parts.last.isNotEmpty ? parts.last : normalized;
  }

  static List<TeamsOnlinePlayer?> relativeSeats({
    required List<TeamsOnlinePlayer> players,
    required String currentPlayerId,
  }) {
    final currentId = identityKey(currentPlayerId);
    final globalSeats = List<TeamsOnlinePlayer?>.filled(4, null);
    final seenIds = <String>{};
    for (var seat = 0; seat < players.length && seat < 4; seat++) {
      final player = players[seat];
      final id = identityKey(player.id);
      if (id.isEmpty || !seenIds.add(id)) continue;
      globalSeats[seat] = player;
    }

    final currentSeat = globalSeats.indexWhere(
      (player) => player != null && identityKey(player.id) == currentId,
    );
    if (currentId.isEmpty || currentSeat < 0) {
      // Fail closed: never label another person's profile as "You" while a
      // stale or incomplete lobby snapshot is being reconciled.
      return List<TeamsOnlinePlayer?>.filled(4, null);
    }

    return List<TeamsOnlinePlayer?>.generate(
      4,
      (relativeSeat) => globalSeats[(currentSeat + relativeSeat) % 4],
      growable: false,
    );
  }
}

class TeamsOnlineLobby {
  const TeamsOnlineLobby({
    required this.id,
    required this.status,
    required this.deadlineAt,
    required this.players,
  });

  final String id;
  final String status;
  final int deadlineAt;
  final List<TeamsOnlinePlayer> players;

  int get secondsRemaining => max(
    0,
    ((deadlineAt - DateTime.now().millisecondsSinceEpoch) / 1000).ceil(),
  );

  factory TeamsOnlineLobby.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return TeamsOnlineLobby(
      id: snapshot.id,
      status: data['status'] as String? ?? 'waiting',
      deadlineAt: (data['deadlineAt'] as num?)?.toInt() ?? 0,
      players:
          (data['players'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (map) =>
                    TeamsOnlinePlayer.fromMap(Map<String, dynamic>.from(map)),
              )
              .toList(),
    );
  }
}

class TeamsOnlineTile {
  const TeamsOnlineTile(this.left, this.right);

  final int left;
  final int right;

  int get code => left * 10 + right;
  int get id => min(left, right) * 10 + max(left, right);
  bool get isDouble => left == right;
  int get points => left + right;
}

class TeamsOnlineGame {
  const TeamsOnlineGame({
    required this.id,
    required this.status,
    required this.revision,
    required this.players,
    required this.hands,
    required this.board,
    required this.teamScores,
    required this.targetScore,
    required this.turn,
    required this.round,
    required this.openingPlayer,
    required this.openingTileId,
    required this.consecutivePasses,
    required this.lastPlayerToPlay,
    required this.previousDominator,
    required this.roundOver,
    required this.resultWinnerPlayer,
    required this.resultPoints,
    required this.resultSpecial,
    required this.resultBlocked,
    required this.lastAction,
    required this.quickChat,
  });

  final String id;
  final String status;
  final int revision;
  final List<TeamsOnlinePlayer> players;
  final Map<int, List<TeamsOnlineTile>> hands;
  final List<TeamsOnlineTile> board;
  final List<int> teamScores;
  final int targetScore;
  final int turn;
  final int round;
  final int openingPlayer;
  final int? openingTileId;
  final int consecutivePasses;
  final int? lastPlayerToPlay;
  final int? previousDominator;
  final bool roundOver;
  final int? resultWinnerPlayer;
  final int resultPoints;
  final String? resultSpecial;
  final bool resultBlocked;
  final Map<String, dynamic> lastAction;
  final Map<String, dynamic> quickChat;

  bool get matchOver => status == 'matchOver';

  factory TeamsOnlineGame.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawHands = Map<String, dynamic>.from(
      data['hands'] as Map? ?? const <String, dynamic>{},
    );
    return TeamsOnlineGame(
      id: snapshot.id,
      status: data['status'] as String? ?? 'waiting',
      revision: (data['revision'] as num?)?.toInt() ?? 0,
      players:
          (data['players'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (map) =>
                    TeamsOnlinePlayer.fromMap(Map<String, dynamic>.from(map)),
              )
              .toList(),
      hands: {
        for (var seat = 0; seat < 4; seat++)
          seat: _decodeTiles(rawHands['$seat'] as List<dynamic>? ?? const []),
      },
      board: _decodeTiles(data['board'] as List<dynamic>? ?? const []),
      teamScores: List<int>.from(
        (data['teamScores'] as List<dynamic>? ?? const [0, 0]).map(
          (value) => (value as num).toInt(),
        ),
      ),
      targetScore: (data['targetScore'] as num?)?.toInt() ?? 100,
      turn: (data['turn'] as num?)?.toInt() ?? 0,
      round: (data['round'] as num?)?.toInt() ?? 1,
      openingPlayer: (data['openingPlayer'] as num?)?.toInt() ?? 0,
      openingTileId: (data['openingTileId'] as num?)?.toInt(),
      consecutivePasses: (data['consecutivePasses'] as num?)?.toInt() ?? 0,
      lastPlayerToPlay: (data['lastPlayerToPlay'] as num?)?.toInt(),
      previousDominator: (data['previousDominator'] as num?)?.toInt(),
      roundOver: data['roundOver'] as bool? ?? false,
      resultWinnerPlayer: (data['resultWinnerPlayer'] as num?)?.toInt(),
      resultPoints: (data['resultPoints'] as num?)?.toInt() ?? 0,
      resultSpecial: data['resultSpecial'] as String?,
      resultBlocked: data['resultBlocked'] as bool? ?? false,
      lastAction: Map<String, dynamic>.from(
        data['lastAction'] as Map? ?? const <String, dynamic>{},
      ),
      quickChat: Map<String, dynamic>.from(
        data['quickChat'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  static List<TeamsOnlineTile> _decodeTiles(List<dynamic> values) =>
      values.map((value) {
        final code = (value as num).toInt();
        return TeamsOnlineTile(code ~/ 10, code % 10);
      }).toList();
}

class TeamsOnlineService {
  TeamsOnlineService(this.db);

  final FirebaseFirestore db;

  static const gamesCollection = 'kapi_teams_online_games';
  static const queueCollection = 'kapi_teams_matchmaking';
  static const _bucketId = '_quickplay';
  static const searchDuration = Duration(seconds: 30);
  static const Map<String, String> quickChatEmojis = {
    'wellPlayed': '👏',
    'thanks': '🙏',
    'goodLuck': '🍀',
    'goodGame': '🤝',
    'wow': '😮',
    'oops': '😅',
    'laugh': '😂',
    'fire': '🔥',
  };
  static const _targetScore = int.fromEnvironment(
    'KAPI_TEST_TARGET_SCORE',
    defaultValue: kReleaseMode ? 100 : 30,
  );

  CollectionReference<Map<String, dynamic>> get _games =>
      db.collection(gamesCollection);
  CollectionReference<Map<String, dynamic>> get _queue =>
      db.collection(queueCollection);

  Stream<TeamsOnlineLobby> watchLobby(String gameId) =>
      _games.doc(gameId).snapshots().map(TeamsOnlineLobby.fromSnapshot);

  Stream<TeamsOnlineGame> watchGame(String gameId) =>
      _games.doc(gameId).snapshots().map(TeamsOnlineGame.fromSnapshot);

  Future<String> joinQuickMatch({
    required DominoPlayerProfile profile,
    required int points,
  }) async {
    final playerId = profile.publicId.toUpperCase();
    final playerKey = TeamsOnlineRoster.identityKey(playerId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final newRoom = _games.doc();
    final bucketRef = _queue.doc(_bucketId);
    final playerRef = _queue.doc(playerId);
    final player = TeamsOnlinePlayer(
      id: playerId,
      initials: profile.initials,
      countryCode: profile.countryCode,
      avatarKey: profile.avatarKey,
      points: points,
      isCpu: false,
      badgeKey:
          KapiCosmeticsService.instance.equipped(KapiCosmeticType.flag).id,
    );

    return db.runTransaction<String>((transaction) async {
      final bucket = await transaction.get(bucketRef);
      final activeId = bucket.data()?['activeGameId'] as String? ?? '';
      DocumentSnapshot<Map<String, dynamic>>? activeRoom;
      if (activeId.isNotEmpty) {
        activeRoom = await transaction.get(_games.doc(activeId));
      }

      var roomId = activeId;
      var joinedExisting = false;
      if (activeRoom?.exists ?? false) {
        final data = activeRoom!.data() ?? const <String, dynamic>{};
        final status = data['status'] as String? ?? '';
        final deadline = (data['deadlineAt'] as num?)?.toInt() ?? 0;
        final players = List<dynamic>.from(data['players'] ?? const []);
        final joinedSeat = players.indexWhere(
          (entry) =>
              entry is Map &&
              TeamsOnlineRoster.identityKey(entry['id'] as String? ?? '') ==
                  playerKey,
        );
        final canJoin = joinedSeat >= 0 || players.length < 4;
        if (status == 'waiting' && deadline > now && canJoin) {
          if (joinedSeat >= 0) {
            // Refresh the complete profile in the same seat. Never update a
            // name/avatar separately from the id that owns it.
            players[joinedSeat] = player.toMap();
          } else {
            players.add(player.toMap());
          }
          transaction.update(activeRoom.reference, {
            'players': players,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          joinedExisting = true;
        }
      }

      if (!joinedExisting) {
        roomId = newRoom.id;
        transaction.set(newRoom, {
          'mode': 'teams2v2',
          'status': 'waiting',
          'players': [player.toMap()],
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtMillis': now,
          'deadlineAt': now + searchDuration.inMilliseconds,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(bucketRef, {
          'activeGameId': roomId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      transaction.set(playerRef, {
        'playerId': playerId,
        'gameId': roomId,
        'status': 'waiting',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return roomId;
    });
  }

  Future<bool> finalizeLobby(String gameId) async {
    final roomRef = _games.doc(gameId);
    final bucketRef = _queue.doc(_bucketId);
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      return await db.runTransaction<bool>((transaction) async {
        final roomSnapshot = await transaction.get(roomRef);
        final bucketSnapshot = await transaction.get(bucketRef);
        if (!roomSnapshot.exists) return false;
        final data = roomSnapshot.data() ?? const <String, dynamic>{};
        if (data['status'] != 'waiting') return data['status'] == 'playing';
        final deadline = (data['deadlineAt'] as num?)?.toInt() ?? 0;
        final rawPlayers = List<dynamic>.from(data['players'] ?? const []);
        if (rawPlayers.length < 4 && now < deadline) return false;

        final players =
            rawPlayers
                .whereType<Map>()
                .map(
                  (map) =>
                      TeamsOnlinePlayer.fromMap(Map<String, dynamic>.from(map)),
                )
                .toList();
        while (players.length < 4) {
          final seat = players.length;
          players.add(
            TeamsOnlinePlayer(
              id: 'CPU-$gameId-$seat',
              initials: seat == 2 ? 'Partner CPU' : 'CPU ${seat + 1}',
              countryCode: 'US',
              avatarKey: 'robot',
              points: 0,
              isCpu: true,
            ),
          );
        }
        final initial = _newRound(
          gameId: gameId,
          round: 1,
          scores: const [0, 0],
          previousDominator: null,
        );
        transaction.update(roomRef, {
          'players': players.map((player) => player.toMap()).toList(),
          ...initial,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (bucketSnapshot.data()?['activeGameId'] == gameId) {
          transaction.set(bucketRef, {
            'activeGameId': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        for (final player in players.where((player) => !player.isCpu)) {
          transaction.set(_queue.doc(player.id), {
            'status': 'inGame',
            'gameId': gameId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        return true;
      });
    } on FirebaseException {
      return false;
    }
  }

  Future<void> cancelWaiting({
    required String gameId,
    required String playerId,
  }) async {
    final cleanId = playerId.toUpperCase();
    final playerKey = TeamsOnlineRoster.identityKey(cleanId);
    final roomRef = _games.doc(gameId);
    final bucketRef = _queue.doc(_bucketId);
    await db.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final bucketSnapshot = await transaction.get(bucketRef);
      if (roomSnapshot.data()?['status'] != 'waiting') return;
      final players = List<dynamic>.from(
        roomSnapshot.data()?['players'] as List<dynamic>? ?? const [],
      )..removeWhere(
        (entry) =>
            entry is Map &&
            TeamsOnlineRoster.identityKey(entry['id'] as String? ?? '') ==
                playerKey,
      );
      transaction.update(roomRef, {
        'players': players,
        'status': players.isEmpty ? 'cancelled' : 'waiting',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (players.isEmpty && bucketSnapshot.data()?['activeGameId'] == gameId) {
        transaction.set(bucketRef, {
          'activeGameId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      transaction.set(_queue.doc(cleanId), {
        'status': 'cancelled',
        'gameId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<bool> playTile({
    required String gameId,
    required String playerId,
    required int tileId,
    required String side,
  }) => _updateTurn(
    gameId: gameId,
    playerId: playerId,
    requestedTileId: tileId,
    requestedSide: side,
    cpuOnly: false,
  );

  Future<bool> pass({required String gameId, required String playerId}) =>
      _updateTurn(
        gameId: gameId,
        playerId: playerId,
        requestedTileId: null,
        requestedSide: 'right',
        cpuOnly: false,
      );

  Future<bool> processCpuTurn({
    required String gameId,
    required int expectedRevision,
  }) => _updateTurn(
    gameId: gameId,
    playerId: null,
    requestedTileId: null,
    requestedSide: 'right',
    cpuOnly: true,
    expectedRevision: expectedRevision,
  );

  Future<bool> sendQuickChat({
    required String gameId,
    required String playerId,
    required String messageId,
  }) async {
    final emoji = quickChatEmojis[messageId];
    if (emoji == null) return false;
    final cleanPlayerId = playerId.toUpperCase();
    final playerKey = TeamsOnlineRoster.identityKey(cleanPlayerId);
    final ref = _games.doc(gameId);
    try {
      return await db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        if (data == null) return false;
        final status = data['status'] as String? ?? '';
        if (status == 'waiting' || status == 'cancelled') return false;
        final players =
            (data['players'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList();
        final seat = players.indexWhere(
          (entry) =>
              TeamsOnlineRoster.identityKey(entry['id'] as String? ?? '') ==
              playerKey,
        );
        if (seat < 0 || players[seat]['isCpu'] == true) return false;
        final previous = Map<String, dynamic>.from(
          data['quickChat'] as Map? ?? const <String, dynamic>{},
        );
        final sequence = (previous['sequence'] as num?)?.toInt() ?? 0;
        transaction.update(ref, {
          'quickChat': {
            'sequence': sequence + 1,
            'player': seat,
            'messageId': messageId,
            'emoji': emoji,
            'sentAtMillis': DateTime.now().millisecondsSinceEpoch,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } on FirebaseException {
      return false;
    }
  }

  Future<bool> _updateTurn({
    required String gameId,
    required String? playerId,
    required int? requestedTileId,
    required String requestedSide,
    required bool cpuOnly,
    int? expectedRevision,
  }) async {
    final ref = _games.doc(gameId);
    try {
      return await db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) return false;
        final game = TeamsOnlineGame.fromSnapshot(snapshot);
        if (game.status != 'playing' || game.roundOver) return false;
        if (expectedRevision != null && game.revision != expectedRevision) {
          return false;
        }
        if (game.turn < 0 || game.turn >= game.players.length) return false;
        final active = game.players[game.turn];
        if (cpuOnly != active.isCpu) return false;
        if (!cpuOnly &&
            TeamsOnlineRoster.identityKey(active.id) !=
                TeamsOnlineRoster.identityKey(playerId ?? '')) {
          return false;
        }

        final state = _MutableGame.fromGame(game);
        if (!TeamDominoChainValidator.isValidChain(
          state.board.map((tile) => (left: tile.left, right: tile.right)),
        )) {
          debugPrint(
            'KAPI_TEAMS_ONLINE_CHAIN_REJECTED game=$gameId '
            'revision=${game.revision}',
          );
          return false;
        }
        final hand = state.hands[state.turn]!;
        final playable = <({TeamsOnlineTile tile, List<String> sides})>[];
        for (final tile in hand) {
          final sides = _validSides(state.board, tile);
          if (sides.isNotEmpty) playable.add((tile: tile, sides: sides));
        }

        if (cpuOnly) {
          if (playable.isEmpty) {
            _applyPass(state);
          } else {
            playable.sort((a, b) => b.tile.points.compareTo(a.tile.points));
            final choice = playable.first;
            if (!_applyPlay(
              state,
              choice.tile,
              choice.sides.contains('right') ? 'right' : choice.sides.first,
            )) {
              return false;
            }
          }
        } else if (requestedTileId == null) {
          if (playable.isNotEmpty) return false;
          _applyPass(state);
        } else {
          final tile = hand.cast<TeamsOnlineTile?>().firstWhere(
            (candidate) => candidate?.id == requestedTileId,
            orElse: () => null,
          );
          if (tile == null) return false;
          final sides = _validSides(state.board, tile);
          if (!sides.contains(requestedSide)) return false;
          if (!_applyPlay(state, tile, requestedSide)) return false;
        }

        transaction.update(ref, {
          ...state.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } on FirebaseException {
      return false;
    }
  }

  Future<bool> nextRound(String gameId) async {
    final ref = _games.doc(gameId);
    try {
      return await db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) return false;
        final game = TeamsOnlineGame.fromSnapshot(snapshot);
        if (!game.roundOver) return false;
        final restart = game.matchOver;
        final next = _newRound(
          gameId: gameId,
          round: restart ? 1 : game.round + 1,
          scores: restart ? const [0, 0] : game.teamScores,
          previousDominator: restart ? null : game.resultWinnerPlayer,
          revision: game.revision + 1,
        );
        transaction.update(ref, {
          ...next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } on FirebaseException {
      return false;
    }
  }

  Future<void> replaceWithCpu({
    required String gameId,
    required String playerId,
  }) async {
    final ref = _games.doc(gameId);
    final cleanId = playerId.toUpperCase();
    final playerKey = TeamsOnlineRoster.identityKey(cleanId);
    try {
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        if (data == null || data['status'] == 'waiting') return;
        final players =
            (data['players'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList();
        final seat = players.indexWhere(
          (entry) =>
              TeamsOnlineRoster.identityKey(entry['id'] as String? ?? '') ==
              playerKey,
        );
        if (seat < 0 || players[seat]['isCpu'] == true) return;
        final original = TeamsOnlinePlayer.fromMap(players[seat]);
        players[seat] = original.asCpu(seat, gameId).toMap();
        transaction.update(ref, {
          'players': players,
          'revision': FieldValue.increment(1),
          'lastAction': {'type': 'replacedByCpu', 'player': seat},
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_queue.doc(cleanId), {
          'status': 'cancelled',
          'gameId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on FirebaseException {
      // Another client may have replaced the same seat already.
    }
  }

  Map<String, dynamic> _newRound({
    required String gameId,
    required int round,
    required List<int> scores,
    required int? previousDominator,
    int revision = 1,
  }) {
    final seed = Object.hash(
      gameId,
      round,
      DateTime.now().microsecondsSinceEpoch,
    );
    final deck = <TeamsOnlineTile>[
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++)
          TeamsOnlineTile(left, right),
    ]..shuffle(Random(seed));
    final hands = <int, List<TeamsOnlineTile>>{
      for (var seat = 0; seat < 4; seat++)
        seat: deck.skip(seat * 7).take(7).toList(),
    };
    final board = <TeamsOnlineTile>[];
    var openingPlayer = previousDominator ?? 0;
    var turn = openingPlayer;
    int? openingTileId;
    int? lastPlayerToPlay;
    Map<String, dynamic> lastAction = {
      'type': 'roundStart',
      'player': openingPlayer,
    };
    if (round == 1) {
      const doubleSixId = 66;
      openingPlayer =
          hands.entries
              .firstWhere(
                (entry) => entry.value.any((tile) => tile.id == doubleSixId),
              )
              .key;
      final opening = hands[openingPlayer]!.firstWhere(
        (tile) => tile.id == doubleSixId,
      );
      hands[openingPlayer]!.remove(opening);
      board.add(opening);
      openingTileId = opening.id;
      lastPlayerToPlay = openingPlayer;
      turn = (openingPlayer + 1) % 4;
      lastAction = {
        'type': 'play',
        'player': openingPlayer,
        'tile': opening.code,
        'side': 'right',
        'opening': true,
      };
    }
    return {
      'status': 'playing',
      'revision': revision,
      'hands': {
        for (final entry in hands.entries)
          '${entry.key}': entry.value.map((tile) => tile.code).toList(),
      },
      'board': board.map((tile) => tile.code).toList(),
      'teamScores': scores,
      'targetScore': _targetScore,
      'turn': turn,
      'round': round,
      'openingPlayer': openingPlayer,
      'openingTileId': openingTileId,
      'consecutivePasses': 0,
      'lastPlayerToPlay': lastPlayerToPlay,
      'previousDominator': previousDominator,
      'roundOver': false,
      'resultWinnerPlayer': null,
      'resultPoints': 0,
      'resultSpecial': null,
      'resultBlocked': false,
      'lastAction': lastAction,
    };
  }

  static List<String> _validSides(
    List<TeamsOnlineTile> board,
    TeamsOnlineTile tile,
  ) {
    if (board.isEmpty) return const ['right'];
    final sides = <String>[];
    if (tile.left == board.first.left || tile.right == board.first.left) {
      sides.add('left');
    }
    if (tile.left == board.last.right || tile.right == board.last.right) {
      sides.add('right');
    }
    return sides;
  }

  static void _applyPass(_MutableGame state) {
    final player = state.turn;
    state.consecutivePasses++;
    state.revision++;
    state.lastAction = {'type': 'pass', 'player': player};
    state.turn = (state.turn + 1) % 4;
    if (state.consecutivePasses >= 4) _finishBlocked(state);
  }

  static bool _applyPlay(
    _MutableGame state,
    TeamsOnlineTile tile,
    String requestedSide,
  ) {
    final player = state.turn;
    final sides = _validSides(state.board, tile);
    final capicua =
        state.board.isNotEmpty &&
        state.hands[player]!.length == 1 &&
        !tile.isDouble &&
        state.board.first.left != state.board.last.right &&
        sides.length == 2;
    final chuchazo =
        state.hands[player]!.length == 1 && tile.left == 0 && tile.right == 0;
    final side = capicua ? 'right' : requestedSide;
    final chainSide =
        side == 'right' ? TeamDominoChainSide.right : TeamDominoChainSide.left;
    final proposed = TeamDominoChainValidator.tryPlace(
      board: state.board.map((value) => (left: value.left, right: value.right)),
      tile: (left: tile.left, right: tile.right),
      side: chainSide,
    );
    if (proposed == null) {
      debugPrint(
        'KAPI_TEAMS_ONLINE_PLAY_REJECTED player=$player '
        'tile=${tile.left}-${tile.right} side=$side',
      );
      return false;
    }
    final validatedBoard = [
      for (final value in proposed) TeamsOnlineTile(value.left, value.right),
    ];
    if (!TeamDominoChainValidator.isValidChain(
      validatedBoard.map((value) => (left: value.left, right: value.right)),
    )) {
      debugPrint('KAPI_TEAMS_ONLINE_POST_PLAY_REJECTED player=$player');
      return false;
    }
    final oriented = side == 'right' ? proposed.last : proposed.first;
    final placed = TeamsOnlineTile(oriented.left, oriented.right);
    final roundPassBonus = TeamScoringRules.awardRoundPassBonusForPlay(
      teamScores: state.teamScores,
      consecutivePasses: state.consecutivePasses,
      lastPlayerToPlay: state.lastPlayerToPlay,
      playerPlaying: player,
    );
    state.hands[player]!.removeWhere((candidate) => candidate.id == tile.id);
    state.board = validatedBoard;
    state.openingTileId ??= placed.id;
    if (state.board.length == 1) state.openingPlayer = player;
    state.lastPlayerToPlay = player;
    state.consecutivePasses = 0;
    state.revision++;
    state.lastAction = {
      'type': 'play',
      'player': player,
      'tile': placed.code,
      'side': side,
      'roundPassBonus': roundPassBonus,
    };
    if (state.hands[player]!.isEmpty) {
      _finishDominated(
        state,
        player,
        capicua: capicua,
        chuchazo: chuchazo,
        roundPassBonus: roundPassBonus,
      );
      return true;
    }
    state.turn = (state.turn + 1) % 4;
    return true;
  }

  static void _finishDominated(
    _MutableGame state,
    int player, {
    required bool capicua,
    required bool chuchazo,
    required int roundPassBonus,
  }) {
    final team = player.isEven ? 0 : 1;
    final remaining = state.hands.values
        .expand((hand) => hand)
        .fold<int>(0, (total, tile) => total + tile.points);
    final gained = remaining + (capicua || chuchazo ? 25 : 0);
    state.teamScores[team] += gained;
    state.previousDominator = player;
    state.roundOver = true;
    state.resultWinnerPlayer = player;
    state.resultPoints = gained + roundPassBonus;
    state.resultSpecial = chuchazo ? 'chuchazo' : (capicua ? 'capicua' : null);
    state.resultBlocked = false;
    state.status =
        state.teamScores[team] >= state.targetScore ? 'matchOver' : 'roundOver';
    state.lastAction = {
      'type': 'roundEnd',
      'player': player,
      'points': state.resultPoints,
      'special': state.resultSpecial,
      'blocked': false,
    };
  }

  static void _finishBlocked(_MutableGame state) {
    final handPips = <int>[
      for (var player = 0; player < 4; player++)
        state.hands[player]!.fold<int>(0, (total, tile) => total + tile.points),
    ];
    final blockingPlayer = state.lastPlayerToPlay;
    assert(
      blockingPlayer != null,
      'A blocked hand must remember the player who placed the last tile.',
    );
    final winner = TeamScoringRules.blockedWinnerPlayer(
      blockingPlayer: blockingPlayer ?? 0,
      handPips: handPips,
    );
    final gained = handPips.fold<int>(0, (total, points) => total + points);
    final team = winner.isEven ? 0 : 1;
    state.teamScores[team] += gained;
    state.roundOver = true;
    state.resultWinnerPlayer = winner;
    state.resultPoints = gained;
    state.resultSpecial = null;
    state.resultBlocked = true;
    state.status =
        state.teamScores[team] >= state.targetScore ? 'matchOver' : 'roundOver';
    state.lastAction = {
      'type': 'roundEnd',
      'player': winner,
      'points': gained,
      'special': null,
      'blocked': true,
    };
  }
}

class _MutableGame {
  _MutableGame({
    required this.status,
    required this.revision,
    required this.hands,
    required this.board,
    required this.teamScores,
    required this.targetScore,
    required this.turn,
    required this.round,
    required this.openingPlayer,
    required this.openingTileId,
    required this.consecutivePasses,
    required this.lastPlayerToPlay,
    required this.previousDominator,
    required this.roundOver,
    required this.resultWinnerPlayer,
    required this.resultPoints,
    required this.resultSpecial,
    required this.resultBlocked,
    required this.lastAction,
  });

  String status;
  int revision;
  Map<int, List<TeamsOnlineTile>> hands;
  List<TeamsOnlineTile> board;
  List<int> teamScores;
  int targetScore;
  int turn;
  int round;
  int openingPlayer;
  int? openingTileId;
  int consecutivePasses;
  int? lastPlayerToPlay;
  int? previousDominator;
  bool roundOver;
  int? resultWinnerPlayer;
  int resultPoints;
  String? resultSpecial;
  bool resultBlocked;
  Map<String, dynamic> lastAction;

  factory _MutableGame.fromGame(TeamsOnlineGame game) => _MutableGame(
    status: game.status,
    revision: game.revision,
    hands: {
      for (final entry in game.hands.entries) entry.key: [...entry.value],
    },
    board: [...game.board],
    teamScores: [...game.teamScores],
    targetScore: game.targetScore,
    turn: game.turn,
    round: game.round,
    openingPlayer: game.openingPlayer,
    openingTileId: game.openingTileId,
    consecutivePasses: game.consecutivePasses,
    lastPlayerToPlay: game.lastPlayerToPlay,
    previousDominator: game.previousDominator,
    roundOver: game.roundOver,
    resultWinnerPlayer: game.resultWinnerPlayer,
    resultPoints: game.resultPoints,
    resultSpecial: game.resultSpecial,
    resultBlocked: game.resultBlocked,
    lastAction: {...game.lastAction},
  );

  Map<String, dynamic> toMap() => {
    'status': status,
    'revision': revision,
    'hands': {
      for (final entry in hands.entries)
        '${entry.key}': entry.value.map((tile) => tile.code).toList(),
    },
    'board': board.map((tile) => tile.code).toList(),
    'teamScores': teamScores,
    'targetScore': targetScore,
    'turn': turn,
    'round': round,
    'openingPlayer': openingPlayer,
    'openingTileId': openingTileId,
    'consecutivePasses': consecutivePasses,
    'lastPlayerToPlay': lastPlayerToPlay,
    'previousDominator': previousDominator,
    'roundOver': roundOver,
    'resultWinnerPlayer': resultWinnerPlayer,
    'resultPoints': resultPoints,
    'resultSpecial': resultSpecial,
    'resultBlocked': resultBlocked,
    'lastAction': lastAction,
  };
}
