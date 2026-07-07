import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'domino_player_profile.dart';

class DominoOnlineGameScreen extends StatefulWidget {
  const DominoOnlineGameScreen({
    super.key,
    required this.gameId,
    this.playerId,
  });

  final String gameId;
  final String? playerId;

  @override
  State<DominoOnlineGameScreen> createState() => _DominoOnlineGameScreenState();
}

class _DominoOnlineGameScreenState extends State<DominoOnlineGameScreen> {
  static const Color _redTop = Color(0xFF6D0907);
  static const Color _navyBottom = Color(0xFF071524);
  static const Color _tableGreen = Color(0xFF063D2D);
  static const Color _gold = Color(0xFFFFD36B);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ScrollController _onlineHandScrollController = ScrollController();
  String? _lastOnlineHandFocusSignature;
  DominoPlayerProfile _profile = const DominoPlayerProfile(
    initials: 'JP',
    countryCode: 'US',
    code: '000000',
    avatarKey: 'person',
  );
  bool _profileReady = false;
  bool _isSpanish = false;

  String _myPlayerId(_OnlineGame game) {
    final routePlayerId = widget.playerId?.toUpperCase();
    if (routePlayerId != null && game.players.contains(routePlayerId)) {
      return routePlayerId;
    }
    return game.playerIdForProfile(_profile);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _onlineHandScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isSpanish = Localizations.localeOf(context).languageCode == 'es';
  }

  Future<void> _loadProfile() async {
    final profile = await DominoPlayerProfile.load();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profileReady = true;
    });
  }

  Future<void> _playTile(_OnlineGame game, _DominoTile tile) async {
    final myPlayerId = _myPlayerId(game);
    if (!game.isMyTurn(myPlayerId) || game.roundOver) return;
    final sides = game.validSides(tile);
    if (sides.isEmpty) {
      _showMessage(_isSpanish ? 'Ficha invalida' : 'Invalid tile');
      return;
    }
    final side = sides.length == 1 ? sides.first : await _askSideForTile(tile);
    if (side == null || !sides.contains(side)) return;

    await _db.runTransaction((transaction) async {
      final ref = _db.collection('kapi_online_games').doc(widget.gameId);
      final snapshot = await transaction.get(ref);
      final fresh = _OnlineGame.fromSnapshot(snapshot);
      final freshPlayerId = _myPlayerId(fresh);
      if (!fresh.isMyTurn(freshPlayerId) || fresh.roundOver) return;
      if (!fresh.handFor(freshPlayerId).contains(tile)) return;
      if (!fresh.validSides(tile).contains(side)) return;

      final next = fresh.playTile(
        playerId: freshPlayerId,
        tile: tile,
        side: side,
      );
      transaction.set(ref, next.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> _pass(_OnlineGame game) async {
    final myPlayerId = _myPlayerId(game);
    if (!game.isMyTurn(myPlayerId) ||
        game.roundOver ||
        game.hasMove(myPlayerId)) {
      return;
    }
    await _db.runTransaction((transaction) async {
      final ref = _db.collection('kapi_online_games').doc(widget.gameId);
      final snapshot = await transaction.get(ref);
      final fresh = _OnlineGame.fromSnapshot(snapshot);
      final freshPlayerId = _myPlayerId(fresh);
      if (!fresh.isMyTurn(freshPlayerId) ||
          fresh.roundOver ||
          fresh.hasMove(freshPlayerId)) {
        return;
      }
      final next = fresh.pass(freshPlayerId);
      transaction.set(ref, next.toMap(), SetOptions(merge: true));
    });
  }

  Future<_BoardSide?> _askSideForTile(_DominoTile tile) {
    return showDialog<_BoardSide>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF101820),
            title: Text(
              _isSpanish
                  ? 'Donde quieres poner ${tile.label}?'
                  : 'Where do you want to play ${tile.label}?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _BoardSide.left),
                child: Text(_isSpanish ? 'Izquierda' : 'Left'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _BoardSide.right),
                child: Text(_isSpanish ? 'Derecha' : 'Right'),
              ),
            ],
          ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_redTop, _navyBottom],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                _db
                    .collection('kapi_online_games')
                    .doc(widget.gameId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildError(snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.data!.exists) {
                return _buildError(
                  _isSpanish
                      ? 'Esta partida ya no existe.'
                      : 'This game no longer exists.',
                );
              }
              final game = _OnlineGame.fromSnapshot(snapshot.data!);
              return _buildGame(game);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildTopBar(title: _isSpanish ? 'Online' : 'Online'),
          const Spacer(),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildGame(_OnlineGame game) {
    final myPlayerId = _myPlayerId(game);
    final myHand = game.handFor(myPlayerId);
    final otherId = game.otherPlayerId(myPlayerId);
    final otherHandCount = game.handFor(otherId).length;
    final myTurn = game.isMyTurn(myPlayerId);
    final canPass = myTurn && !game.hasMove(myPlayerId) && !game.roundOver;
    _scrollOnlineHandToPlayableStart(game, myPlayerId, myHand);
    final status =
        game.roundOver
            ? game.message
            : myTurn
            ? (_isSpanish ? 'Tu turno' : 'Your turn')
            : (_isSpanish ? 'Esperando al amigo...' : 'Waiting for friend...');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          _buildTopBar(title: _isSpanish ? 'Online clasico' : 'Online Classic'),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _tableGreen,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  final tight = constraints.maxWidth < 370;
                  final boardTop = tight ? 68.0 : (compact ? 76.0 : 96.0);
                  final handHeight = tight ? 58.0 : (compact ? 64.0 : 78.0);
                  final statusBottom = handHeight + (tight ? 10 : 16);
                  return Stack(
                    children: [
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildProfileCard(
                                  initials: _profile.initials,
                                  label: _isSpanish ? 'Tu' : 'You',
                                  subtitle:
                                      compact
                                          ? '${myHand.length}'
                                          : '${myHand.length} fichas',
                                  active: myTurn,
                                  compact: compact,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildProfileCard(
                                  initials: game.initialsFor(otherId),
                                  label: game.initialsFor(otherId),
                                  subtitle:
                                      compact
                                          ? '$otherHandCount'
                                          : '$otherHandCount fichas',
                                  active: !myTurn && !game.roundOver,
                                  compact: compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: tight ? 48 : (compact ? 56 : 72),
                        right: tight ? 12 : 18,
                        child: _buildBacks(otherHandCount, compact: compact),
                      ),
                      Positioned.fill(
                        top: boardTop,
                        bottom: statusBottom + handHeight + 8,
                        child: _OnlineBoard(board: game.board),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: statusBottom,
                        child: _buildStatusBar(status, game),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 10,
                        child: _buildHand(myHand, game, myPlayerId, handHeight),
                      ),
                      Positioned(
                        right: tight ? 8 : 14,
                        bottom: statusBottom + (tight ? 30 : 40),
                        child: Column(
                          children: [
                            _smallAction(
                              label: _isSpanish ? 'Apuntes' : 'Notes',
                              icon: Icons.edit_note_rounded,
                              onPressed:
                                  () => Navigator.pushNamed(
                                    context,
                                    '/game',
                                    arguments: {'fromDominoGame': true},
                                  ),
                            ),
                            if (canPass) ...[
                              const SizedBox(height: 8),
                              _smallAction(
                                label: _isSpanish ? 'Pasar' : 'Pass',
                                icon: Icons.skip_next_rounded,
                                onPressed: () => _pass(game),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({required String title}) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/lobby'),
          icon: const Icon(Icons.groups_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildProfileCard({
    required String initials,
    required String label,
    required String subtitle,
    required bool active,
    bool compact = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? _gold : Colors.white.withValues(alpha: 0.18),
          width: active ? 1.5 : 1,
        ),
        boxShadow:
            active
                ? [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
                : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: compact ? 14 : 17,
            backgroundColor: const Color(0xFFFFF2D2),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 13 : 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBacks(int count, {bool compact = false}) {
    return Row(
      children: [
        for (var index = 0; index < min(count, 7); index++)
          Container(
            width: compact ? 13 : 16,
            height: compact ? 28 : 34,
            margin: EdgeInsets.only(left: compact ? 2 : 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBar(String status, _OnlineGame game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (game.roundOver)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_isSpanish ? 'Lobby' : 'Lobby'),
            ),
        ],
      ),
    );
  }

  Widget _buildHand(
    List<_DominoTile> hand,
    _OnlineGame game,
    String myPlayerId,
    double height,
  ) {
    final dominoShort = ((height - 12) / 1.82).clamp(24.0, 34.0);
    final displayHand = _orderedHandForDisplay(hand, game, myPlayerId);
    return Container(
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ListView.separated(
        controller: _onlineHandScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: displayHand.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final tile = displayHand[index];
          final playable =
              game.isMyTurn(myPlayerId) && game.validSides(tile).isNotEmpty;
          return GestureDetector(
            onTap: playable ? () => _playTile(game, tile) : null,
            child: Opacity(
              opacity: playable || game.roundOver ? 1 : 0.45,
              child: _DominoWidget(
                tile: tile,
                vertical: true,
                accent: playable ? _gold : null,
                tableSize: dominoShort,
              ),
            ),
          );
        },
      ),
    );
  }

  List<_DominoTile> _orderedHandForDisplay(
    List<_DominoTile> hand,
    _OnlineGame game,
    String myPlayerId,
  ) {
    if (!game.isMyTurn(myPlayerId) || game.roundOver) {
      return List<_DominoTile>.from(hand);
    }

    final playable = <_DominoTile>[];
    final waiting = <_DominoTile>[];
    for (final tile in hand) {
      if (game.validSides(tile).isNotEmpty) {
        playable.add(tile);
      } else {
        waiting.add(tile);
      }
    }
    return [...playable, ...waiting];
  }

  void _scrollOnlineHandToPlayableStart(
    _OnlineGame game,
    String myPlayerId,
    List<_DominoTile> hand,
  ) {
    if (!game.isMyTurn(myPlayerId) || game.roundOver) return;
    final signature =
        '${game.id}:${game.turnId}:${game.board.length}:${hand.map((tile) => tile.label).join(",")}';
    if (_lastOnlineHandFocusSignature == signature) return;
    _lastOnlineHandFocusSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_onlineHandScrollController.hasClients) return;
      _onlineHandScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _smallAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 88,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class OnlineGameFactory {
  static Future<String> createClassicGame({
    required FirebaseFirestore db,
    required DominoPlayerProfile host,
    required String guestId,
    required String guestInitials,
  }) async {
    final hostId = host.publicId.toUpperCase();
    final cleanGuestId = guestId.toUpperCase();
    final guestProfileDoc =
        await db.collection('kapi_lobby_profiles').doc(cleanGuestId).get();
    final guestProfile = guestProfileDoc.data() ?? <String, dynamic>{};
    final deck = <_DominoTile>[
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++) _DominoTile(left, right),
    ]..shuffle(Random());
    final hands = {
      hostId: deck.take(7).toList(),
      cleanGuestId: deck.skip(7).take(7).toList(),
    };
    final starter = _selectStarter(hands);
    hands[starter.playerId]!.remove(starter.tile);
    final otherPlayer = starter.playerId == hostId ? cleanGuestId : hostId;

    final ref = db.collection('kapi_online_games').doc();
    await ref.set({
      'id': ref.id,
      'mode': 'classic',
      'status': 'active',
      'players': [hostId, cleanGuestId],
      'profiles': {
        hostId: {
          'initials': host.initials,
          'countryCode': host.countryCode,
          'code': host.code,
        },
        cleanGuestId: {
          'initials': guestProfile['initials'] as String? ?? guestInitials,
          'countryCode': guestProfile['countryCode'] as String? ?? '',
          'code': guestProfile['code'] as String? ?? '',
          'avatarKey': guestProfile['avatarKey'] as String? ?? '',
        },
      },
      'hands': {
        hostId: hands[hostId]!.map((tile) => tile.toText()).toList(),
        cleanGuestId:
            hands[cleanGuestId]!.map((tile) => tile.toText()).toList(),
      },
      'board': [
        {
          'left': starter.tile.left,
          'right': starter.tile.right,
          'isFirst': true,
        },
      ],
      'turnId': otherPlayer,
      'passed': <String>[],
      'message': '${starter.playerId} opened with ${starter.tile.label}',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static _Starter _selectStarter(Map<String, List<_DominoTile>> hands) {
    final all = <_Starter>[
      for (final entry in hands.entries)
        for (final tile in entry.value) _Starter(entry.key, tile),
    ];
    all.sort((a, b) {
      final aDouble = a.tile.isDouble ? 1 : 0;
      final bDouble = b.tile.isDouble ? 1 : 0;
      if (aDouble != bDouble) return bDouble.compareTo(aDouble);
      if (a.tile.isDouble && b.tile.isDouble) {
        return b.tile.left.compareTo(a.tile.left);
      }
      return b.tile.points.compareTo(a.tile.points);
    });
    return all.first;
  }
}

class _OnlineGame {
  const _OnlineGame({
    required this.id,
    required this.players,
    required this.hands,
    required this.profiles,
    required this.board,
    required this.turnId,
    required this.passed,
    required this.roundOver,
    required this.message,
  });

  final String id;
  final List<String> players;
  final Map<String, List<_DominoTile>> hands;
  final Map<String, Map<String, dynamic>> profiles;
  final List<_BoardDomino> board;
  final String turnId;
  final Set<String> passed;
  final bool roundOver;
  final String message;

  int? get leftOpen => board.isEmpty ? null : board.first.tile.left;
  int? get rightOpen => board.isEmpty ? null : board.last.tile.right;

  static _OnlineGame fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final players =
        List<String>.from(
          data['players'] ?? [],
        ).map((id) => id.toUpperCase()).toList();
    final rawHands = Map<String, dynamic>.from(data['hands'] ?? {});
    final rawProfiles = Map<String, dynamic>.from(data['profiles'] ?? {});
    return _OnlineGame(
      id: snapshot.id,
      players: players,
      hands: {
        for (final entry in rawHands.entries)
          entry.key.toUpperCase():
              List<String>.from(
                entry.value ?? [],
              ).map(_DominoTile.fromText).toList(),
      },
      profiles: {
        for (final entry in rawProfiles.entries)
          entry.key.toUpperCase(): Map<String, dynamic>.from(entry.value ?? {}),
      },
      board:
          List<Map<String, dynamic>>.from(
            data['board'] ?? [],
          ).map(_BoardDomino.fromMap).toList(),
      turnId: (data['turnId'] as String? ?? '').toUpperCase(),
      passed:
          Set<String>.from(
            data['passed'] ?? [],
          ).map((id) => id.toUpperCase()).toSet(),
      roundOver: data['status'] == 'roundOver',
      message: data['message'] as String? ?? '',
    );
  }

  List<_DominoTile> handFor(String playerId) =>
      List<_DominoTile>.from(hands[playerId.toUpperCase()] ?? []);

  String playerIdForProfile(DominoPlayerProfile profile) {
    final publicId = profile.publicId.toUpperCase();
    if (players.contains(publicId)) return publicId;
    final code = profile.code.toUpperCase();
    for (final id in players) {
      final data = profiles[id.toUpperCase()];
      final storedCode = (data?['code'] as String? ?? '').toUpperCase();
      if (storedCode.isNotEmpty && storedCode == code) {
        return id.toUpperCase();
      }
    }
    return publicId;
  }

  String otherPlayerId(String playerId) {
    final clean = playerId.toUpperCase();
    return players.firstWhere((id) => id != clean, orElse: () => '');
  }

  String initialsFor(String playerId) {
    final id = playerId.toUpperCase();
    return profiles[id]?['initials'] as String? ??
        id.split('.').first.padRight(2, '?').substring(0, 2);
  }

  bool isMyTurn(String playerId) => turnId == playerId.toUpperCase();

  bool hasMove(String playerId) =>
      handFor(playerId).any((tile) => validSides(tile).isNotEmpty);

  List<_BoardSide> validSides(_DominoTile tile) {
    if (board.isEmpty) return [_BoardSide.right];
    final sides = <_BoardSide>[];
    if (tile.left == leftOpen || tile.right == leftOpen) {
      sides.add(_BoardSide.left);
    }
    if (tile.left == rightOpen || tile.right == rightOpen) {
      sides.add(_BoardSide.right);
    }
    return sides;
  }

  _OnlineGame playTile({
    required String playerId,
    required _DominoTile tile,
    required _BoardSide side,
  }) {
    final clean = playerId.toUpperCase();
    final nextHands = {
      for (final entry in hands.entries)
        entry.key: List<_DominoTile>.from(entry.value),
    };
    nextHands[clean]!.remove(tile);
    final nextBoard = List<_BoardDomino>.from(board);
    if (side == _BoardSide.left) {
      final open = leftOpen!;
      final oriented = tile.right == open ? tile : tile.flipped;
      nextBoard.insert(0, _BoardDomino(oriented, isFirst: false));
    } else {
      final open = rightOpen!;
      final oriented = tile.left == open ? tile : tile.flipped;
      nextBoard.add(_BoardDomino(oriented, isFirst: false));
    }
    final other = otherPlayerId(clean);
    final next = copyWith(
      hands: nextHands,
      board: nextBoard,
      turnId: other,
      passed: <String>{},
      message: '${initialsFor(clean)} played ${tile.label}',
    );
    return nextHands[clean]!.isEmpty
        ? next.finish('${initialsFor(clean)} wins')
        : next;
  }

  _OnlineGame pass(String playerId) {
    final clean = playerId.toUpperCase();
    final nextPassed = Set<String>.from(passed)..add(clean);
    final other = otherPlayerId(clean);
    final next = copyWith(
      turnId: other,
      passed: nextPassed,
      message: '${initialsFor(clean)} passed',
    );
    if (nextPassed.length >= 2) {
      final myPoints = handFor(
        clean,
      ).fold<int>(0, (total, tile) => total + tile.points);
      final otherPoints = handFor(
        other,
      ).fold<int>(0, (total, tile) => total + tile.points);
      final winner = myPoints <= otherPoints ? clean : other;
      return next.finish('${initialsFor(winner)} wins by fewer points');
    }
    return next;
  }

  _OnlineGame finish(String result) =>
      copyWith(roundOver: true, message: result);

  _OnlineGame copyWith({
    Map<String, List<_DominoTile>>? hands,
    List<_BoardDomino>? board,
    String? turnId,
    Set<String>? passed,
    bool? roundOver,
    String? message,
  }) {
    return _OnlineGame(
      id: id,
      players: players,
      hands: hands ?? this.hands,
      profiles: profiles,
      board: board ?? this.board,
      turnId: turnId ?? this.turnId,
      passed: passed ?? this.passed,
      roundOver: roundOver ?? this.roundOver,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hands': {
        for (final entry in hands.entries)
          entry.key: entry.value.map((tile) => tile.toText()).toList(),
      },
      'board': [
        for (final domino in board)
          {
            'left': domino.tile.left,
            'right': domino.tile.right,
            'isFirst': domino.isFirst,
          },
      ],
      'turnId': turnId,
      'passed': passed.toList(),
      'status': roundOver ? 'roundOver' : 'active',
      'message': message,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class _OnlineBoard extends StatelessWidget {
  const _OnlineBoard({required this.board});

  final List<_BoardDomino> board;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileShort = min(
          44.0,
          max(
            30.0,
            min(constraints.maxWidth / 8.8, constraints.maxHeight / 5.2),
          ),
        );
        final tileLong = tileShort * 1.82;
        final positions = _layoutBoard(
          board: board,
          tileSize: Size(tileShort, tileLong),
          boardSize: constraints.biggest,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < board.length; index++)
              Positioned(
                left: positions[index].dx,
                top: positions[index].dy,
                child: _DominoWidget(
                  tile: board[index].tile,
                  vertical: positions[index].vertical,
                  first: board[index].isFirst,
                  tableSize: tileShort * positions[index].scaleFactor,
                ),
              ),
          ],
        );
      },
    );
  }

  List<_BoardPosition> _layoutBoard({
    required List<_BoardDomino> board,
    required Size tileSize,
    required Size boardSize,
  }) {
    if (board.isEmpty) return [];
    final firstIndex = board.indexWhere((domino) => domino.isFirst);
    final anchorIndex = firstIndex == -1 ? board.length ~/ 2 : firstIndex;
    final logical = List<_LogicalBoardPosition?>.filled(board.length, null);

    logical[anchorIndex] = _LogicalBoardPosition(
      center: Offset.zero,
      vertical: board[anchorIndex].tile.isDouble,
      direction: _LayoutDirection.right,
      isFirst: true,
    );

    _layoutSide(
      board: board,
      positions: logical,
      anchorIndex: anchorIndex,
      side: _BoardSide.right,
      tileSize: tileSize,
    );
    _layoutSide(
      board: board,
      positions: logical,
      anchorIndex: anchorIndex,
      side: _BoardSide.left,
      tileSize: tileSize,
    );

    final resolved = [
      for (var index = 0; index < logical.length; index++)
        logical[index] ??
            _LogicalBoardPosition(
              center: Offset.zero,
              vertical: board[index].tile.isDouble,
              direction: _LayoutDirection.right,
              isFirst: board[index].isFirst,
            ),
    ];
    final bounds = _logicalBounds(resolved, tileSize);
    final safeWidth = max(1.0, boardSize.width - 8);
    final safeHeight = max(1.0, boardSize.height - 8);
    final scale = min(
      1.0,
      min(safeWidth / bounds.width, safeHeight / bounds.height),
    );
    final translation = _fitTranslation(
      bounds: bounds,
      scale: scale,
      boardSize: boardSize,
      preferred: Offset(boardSize.width / 2, boardSize.height / 2),
    );

    return [
      for (final item in resolved)
        _toDrawPosition(item, tileSize, scale, translation),
    ];
  }

  Offset _fitTranslation({
    required Rect bounds,
    required double scale,
    required Size boardSize,
    required Offset preferred,
  }) {
    var dx = preferred.dx;
    var dy = preferred.dy;
    final scaled = Rect.fromLTRB(
      bounds.left * scale + dx,
      bounds.top * scale + dy,
      bounds.right * scale + dx,
      bounds.bottom * scale + dy,
    );
    const padding = 6.0;
    if (scaled.left < padding) dx += padding - scaled.left;
    if (scaled.right > boardSize.width - padding) {
      dx -= scaled.right - (boardSize.width - padding);
    }
    if (scaled.top < padding) dy += padding - scaled.top;
    if (scaled.bottom > boardSize.height - padding) {
      dy -= scaled.bottom - (boardSize.height - padding);
    }
    return Offset(dx, dy);
  }

  void _layoutSide({
    required List<_BoardDomino> board,
    required List<_LogicalBoardPosition?> positions,
    required int anchorIndex,
    required _BoardSide side,
    required Size tileSize,
  }) {
    final indices =
        side == _BoardSide.right
            ? [
              for (var index = anchorIndex + 1; index < board.length; index++)
                index,
            ]
            : [for (var index = anchorIndex - 1; index >= 0; index--) index];
    if (indices.isEmpty) return;

    var direction =
        side == _BoardSide.right
            ? _LayoutDirection.right
            : _LayoutDirection.left;
    var segmentCount = 0;
    var segmentLimit = _segmentLimitFor(direction);
    var turnPending = false;
    var previous = positions[anchorIndex]!;

    for (final index in indices) {
      final domino = board[index];
      if (turnPending && !domino.tile.isDouble) {
        direction = _nextDirection(direction, side);
        segmentCount = 0;
        segmentLimit = _segmentLimitFor(direction);
        turnPending = false;
      }
      final vertical = _isVertical(direction, domino.tile);
      final center = _nextCenter(
        previous: previous,
        direction: direction,
        vertical: vertical,
        tileSize: tileSize,
      );
      positions[index] = _LogicalBoardPosition(
        center: center,
        vertical: vertical,
        direction: direction,
        isFirst: domino.isFirst,
      );
      segmentCount++;
      if (segmentCount >= segmentLimit) turnPending = true;
      previous = positions[index]!;
    }
  }

  int _segmentLimitFor(_LayoutDirection direction) {
    return switch (direction) {
      _LayoutDirection.right || _LayoutDirection.left => 3,
      _LayoutDirection.down || _LayoutDirection.up => 2,
    };
  }

  Offset _nextCenter({
    required _LogicalBoardPosition previous,
    required _LayoutDirection direction,
    required bool vertical,
    required Size tileSize,
  }) {
    final previousSize = _drawSize(tileSize, previous.vertical);
    final currentSize = _drawSize(tileSize, vertical);
    final gap = 0.0;
    return switch (direction) {
      _LayoutDirection.right =>
        previous.center +
            Offset(previousSize.width / 2 + currentSize.width / 2 + gap, 0),
      _LayoutDirection.left =>
        previous.center -
            Offset(previousSize.width / 2 + currentSize.width / 2 + gap, 0),
      _LayoutDirection.down =>
        previous.center +
            Offset(0, previousSize.height / 2 + currentSize.height / 2 + gap),
      _LayoutDirection.up =>
        previous.center -
            Offset(0, previousSize.height / 2 + currentSize.height / 2 + gap),
    };
  }

  bool _isVertical(_LayoutDirection direction, _DominoTile tile) {
    final lineIsVertical =
        direction == _LayoutDirection.up || direction == _LayoutDirection.down;
    return tile.isDouble ? !lineIsVertical : lineIsVertical;
  }

  _LayoutDirection _nextDirection(_LayoutDirection direction, _BoardSide side) {
    if (side == _BoardSide.right) {
      return switch (direction) {
        _LayoutDirection.right => _LayoutDirection.down,
        _LayoutDirection.down => _LayoutDirection.left,
        _LayoutDirection.left => _LayoutDirection.up,
        _LayoutDirection.up => _LayoutDirection.right,
      };
    }
    return switch (direction) {
      _LayoutDirection.left => _LayoutDirection.up,
      _LayoutDirection.up => _LayoutDirection.right,
      _LayoutDirection.right => _LayoutDirection.down,
      _LayoutDirection.down => _LayoutDirection.left,
    };
  }

  Rect _logicalBounds(List<_LogicalBoardPosition> positions, Size tileSize) {
    var bounds = Rect.zero;
    for (final position in positions) {
      final size = _drawSize(tileSize, position.vertical);
      final rect = Rect.fromCenter(
        center: position.center,
        width: size.width,
        height: size.height,
      );
      bounds = bounds == Rect.zero ? rect : bounds.expandToInclude(rect);
    }
    return bounds.inflate(4);
  }

  _BoardPosition _toDrawPosition(
    _LogicalBoardPosition position,
    Size tileSize,
    double scale,
    Offset translation,
  ) {
    final size = _drawSize(tileSize, position.vertical) * scale;
    final center = position.center * scale + translation;
    return _BoardPosition(
      center.dx - size.width / 2,
      center.dy - size.height / 2,
      position.vertical,
      scale,
    );
  }

  Size _drawSize(Size tileSize, bool vertical) {
    return vertical ? tileSize : Size(tileSize.height, tileSize.width);
  }
}

class _DominoWidget extends StatelessWidget {
  const _DominoWidget({
    required this.tile,
    required this.vertical,
    this.first = false,
    this.accent,
    this.tableSize,
  });

  final _DominoTile tile;
  final bool vertical;
  final bool first;
  final Color? accent;
  final double? tableSize;

  @override
  Widget build(BuildContext context) {
    final short = tableSize ?? 34.0;
    final long = short * 1.82;
    final size = vertical ? Size(short, long) : Size(long, short);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color:
            first
                ? const Color(0xFF20B866)
                : tile.isDouble
                ? const Color(0xFF1E88E5)
                : const Color(0xFFFFF2D2),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: accent ?? Colors.black.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DominoPainter(tile: tile, vertical: vertical, first: first),
      ),
    );
  }
}

class _DominoPainter extends CustomPainter {
  const _DominoPainter({
    required this.tile,
    required this.vertical,
    required this.first,
  });

  final _DominoTile tile;
  final bool vertical;
  final bool first;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = Colors.black.withValues(
            alpha: first || tile.isDouble ? 0.18 : 0.20,
          )
          ..strokeWidth = 1.2;
    if (vertical) {
      canvas.drawLine(
        Offset(size.width * 0.18, size.height / 2),
        Offset(size.width * 0.82, size.height / 2),
        linePaint,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(0, 0, size.width, size.height / 2),
        tile.left,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
        tile.right,
      );
    } else {
      canvas.drawLine(
        Offset(size.width / 2, size.height * 0.18),
        Offset(size.width / 2, size.height * 0.82),
        linePaint,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(0, 0, size.width / 2, size.height),
        tile.left,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
        tile.right,
      );
    }
  }

  void _drawPips(Canvas canvas, Rect rect, int value) {
    if (value == 0) return;
    final pipPaint =
        Paint()..color = first || tile.isDouble ? Colors.white : Colors.black;
    final radius = min(rect.width, rect.height) * 0.075;
    final left = rect.left + rect.width * 0.30;
    final centerX = rect.left + rect.width * 0.50;
    final right = rect.left + rect.width * 0.70;
    final top = rect.top + rect.height * 0.28;
    final centerY = rect.top + rect.height * 0.50;
    final bottom = rect.top + rect.height * 0.72;
    final points = switch (value) {
      1 => [Offset(centerX, centerY)],
      2 => [Offset(left, top), Offset(right, bottom)],
      3 => [Offset(left, top), Offset(centerX, centerY), Offset(right, bottom)],
      4 => [
        Offset(left, top),
        Offset(right, top),
        Offset(left, bottom),
        Offset(right, bottom),
      ],
      5 => [
        Offset(left, top),
        Offset(right, top),
        Offset(centerX, centerY),
        Offset(left, bottom),
        Offset(right, bottom),
      ],
      _ => [
        Offset(left, top),
        Offset(right, top),
        Offset(left, centerY),
        Offset(right, centerY),
        Offset(left, bottom),
        Offset(right, bottom),
      ],
    };
    for (final point in points) {
      canvas.drawCircle(point, radius, pipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DominoPainter oldDelegate) {
    return oldDelegate.tile != tile ||
        oldDelegate.vertical != vertical ||
        oldDelegate.first != first;
  }
}

class _DominoTile {
  const _DominoTile(this.left, this.right);

  final int left;
  final int right;

  bool get isDouble => left == right;
  int get points => left + right;
  String get label => '$left-$right';
  _DominoTile get flipped => _DominoTile(right, left);

  String toText() => '$left-$right';

  static _DominoTile fromText(String text) {
    final parts = text.split('-');
    return _DominoTile(int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DominoTile && left == other.left && right == other.right;

  @override
  int get hashCode => Object.hash(left, right);
}

class _BoardDomino {
  const _BoardDomino(this.tile, {required this.isFirst});

  final _DominoTile tile;
  final bool isFirst;

  static _BoardDomino fromMap(Map<String, dynamic> map) {
    return _BoardDomino(
      _DominoTile(map['left'] as int? ?? 0, map['right'] as int? ?? 0),
      isFirst: map['isFirst'] == true,
    );
  }
}

class _BoardPosition {
  const _BoardPosition(this.dx, this.dy, this.vertical, this.scaleFactor);

  final double dx;
  final double dy;
  final bool vertical;
  final double scaleFactor;
}

class _LogicalBoardPosition {
  const _LogicalBoardPosition({
    required this.center,
    required this.vertical,
    required this.direction,
    required this.isFirst,
  });

  final Offset center;
  final bool vertical;
  final _LayoutDirection direction;
  final bool isFirst;
}

class _Starter {
  const _Starter(this.playerId, this.tile);

  final String playerId;
  final _DominoTile tile;
}

enum _BoardSide { left, right }

enum _LayoutDirection { right, down, left, up }
