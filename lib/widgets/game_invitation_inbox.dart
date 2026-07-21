import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/domino_player_profile.dart';
import '../screens/domino_online_game_screen.dart';
import '../services/block_room_service.dart';
import '../services/player_points_service.dart';
import '../services/teams_online_service.dart';

class GameInvitationInbox extends StatefulWidget {
  const GameInvitationInbox({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<GameInvitationInbox> createState() => _GameInvitationInboxState();
}

class _GameInvitationInboxState extends State<GameInvitationInbox>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _friendRequestSubscription;
  Timer? _presenceTimer;
  DominoPlayerProfile? _profile;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pending = const [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _friendRequests = const [];
  late final AnimationController _pulse;

  bool get _isSpanish =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'es';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: 0.92,
      upperBound: 1.08,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final profile = await DominoPlayerProfile.load();
    if (!mounted) return;
    _profile = profile;
    _startPresence(profile);
    _subscription = _db
        .collection('kapi_game_invites')
        .where('toId', isEqualTo: profile.publicId.toUpperCase())
        .snapshots()
        .listen((snapshot) {
          final pending =
              snapshot.docs
                  .where((doc) => doc.data()['status'] == 'pending')
                  .toList()
                ..sort((a, b) {
                  final aTime = a.data()['createdAt'] as Timestamp?;
                  final bTime = b.data()['createdAt'] as Timestamp?;
                  return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                    aTime?.millisecondsSinceEpoch ?? 0,
                  );
                });
          if (!mounted) return;
          setState(() => _pending = pending);
          _syncPulse();
        });
    _friendRequestSubscription = _db
        .collection('kapi_friend_requests')
        .where('toId', isEqualTo: profile.publicId.toUpperCase())
        .snapshots()
        .listen((snapshot) {
          final requests =
              snapshot.docs
                  .where((doc) => doc.data()['status'] == 'pending')
                  .toList();
          if (!mounted) return;
          setState(() => _friendRequests = requests);
          _syncPulse();
        });
  }

  int get _pendingCount => _pending.length + _friendRequests.length;

  void _syncPulse() {
    if (_pendingCount == 0) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  void _startPresence(DominoPlayerProfile profile) {
    unawaited(_writePresence(profile, online: true));
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => unawaited(_writePresence(profile, online: true)),
    );
  }

  Future<void> _writePresence(
    DominoPlayerProfile profile, {
    required bool online,
  }) => _db
      .collection('kapi_lobby_profiles')
      .doc(profile.publicId.toUpperCase())
      .set({
        'publicId': profile.publicId.toUpperCase(),
        'initials': profile.initials,
        'countryCode': profile.countryCode,
        'code': profile.code,
        'avatarKey': profile.avatarKey,
        'status': online ? 'online' : 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profile = _profile;
    if (profile == null) return;
    if (state == AppLifecycleState.resumed) {
      _startPresence(profile);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _presenceTimer?.cancel();
      unawaited(_writePresence(profile, online: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _friendRequestSubscription?.cancel();
    _presenceTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_pendingCount > 0)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 7,
            right: 10,
            child: SafeArea(
              top: false,
              child: ScaleTransition(
                scale: _pulse,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showInbox,
                    customBorder: const CircleBorder(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF168B50),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF8CFFB9),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xAA39E989),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_pendingCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showInbox() async {
    await showModalBottomSheet<void>(
      context: widget.navigatorKey.currentContext ?? context,
      backgroundColor: const Color(0xFF0D1B28),
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isSpanish ? 'Notificaciones' : 'Notifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_pending.isEmpty && _friendRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        _isSpanish
                            ? 'No tienes notificaciones pendientes.'
                            : 'You have no pending notifications.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  for (final invite in _pending)
                    _inviteCard(sheetContext, invite),
                  for (final request in _friendRequests)
                    _friendRequestCard(sheetContext, request),
                ],
              ),
            ),
          ),
    );
  }

  Widget _friendRequestCard(
    BuildContext sheetContext,
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) {
    final data = request.data();
    final initials = data['fromInitials'] as String? ?? 'Kapi';
    return Card(
      color: const Color(0xFF172B3A),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF5AB7FF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSpanish
                    ? '$initials quiere agregarte como amigo.'
                    : '$initials wants to add you as a friend.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: _isSpanish ? 'Rechazar' : 'Decline',
              onPressed: () => _declineFriendRequest(request),
              icon: const Icon(Icons.close_rounded, color: Colors.white60),
            ),
            IconButton.filled(
              tooltip: _isSpanish ? 'Aceptar' : 'Accept',
              onPressed: () => _acceptFriendRequest(request),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF22A863),
              ),
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _declineFriendRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) => request.reference.update({
    'status': 'rejected',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> _acceptFriendRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final profile = _profile;
    if (profile == null) return;
    final fromId = (request.data()['fromId'] as String? ?? '').toUpperCase();
    final myId = profile.publicId.toUpperCase();
    if (fromId.isEmpty) return;
    final ids = [fromId, myId]..sort();
    final batch = _db.batch();
    batch.set(
      _db.collection('kapi_friendships').doc(ids.join('__')),
      {'users': ids, 'createdAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    batch.update(request.reference, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Widget _inviteCard(
    BuildContext sheetContext,
    QueryDocumentSnapshot<Map<String, dynamic>> invite,
  ) {
    final data = invite.data();
    final teams = data['gameType'] == 'teams2v2';
    return Card(
      color: const Color(0xFF172B3A),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(
              teams ? Icons.groups_2_rounded : Icons.view_module_rounded,
              color: const Color(0xFFFFD36B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSpanish
                    ? '${data['fromInitials'] ?? 'Un amigo'} te invita a ${teams ? 'Teams 2 vs 2' : 'Block'}.'
                    : '${data['fromInitials'] ?? 'A friend'} invited you to ${teams ? 'Teams 2 vs 2' : 'Block'}.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: _isSpanish ? 'Rechazar' : 'Decline',
              onPressed: () => _decline(invite),
              icon: const Icon(Icons.close_rounded, color: Colors.white60),
            ),
            IconButton.filled(
              tooltip: _isSpanish ? 'Aceptar' : 'Accept',
              onPressed: () {
                Navigator.pop(sheetContext);
                unawaited(_accept(invite));
              },
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF22A863),
              ),
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decline(
    QueryDocumentSnapshot<Map<String, dynamic>> invite,
  ) async {
    final data = invite.data();
    await invite.reference.update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (data['gameType'] != 'teams2v2') {
      final fromId = data['fromId'] as String? ?? '';
      final gameId = data['gameId'] as String? ?? '';
      if (fromId.isNotEmpty && gameId.isNotEmpty) {
        await BlockRoomService(
          _db,
        ).leaveGame(playerId: fromId, gameId: gameId, reason: 'inviteDeclined');
      }
    }
  }

  Future<void> _accept(
    QueryDocumentSnapshot<Map<String, dynamic>> invite,
  ) async {
    final profile = _profile;
    if (profile == null) return;
    final data = invite.data();
    if (data['gameType'] == 'teams2v2') {
      final roomId = data['roomId'] as String? ?? '';
      final points = await PlayerPointsService.loadLocalTotalPoints(
        profile.code,
      );
      final result = await TeamsOnlineService(
        _db,
      ).joinInviteLobby(gameId: roomId, profile: profile, points: points);
      await invite.reference.update({
        'status':
            result == TeamsInviteJoinResult.joined
                ? 'accepted'
                : result == TeamsInviteJoinResult.roomFull
                ? 'roomFull'
                : 'failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (result != TeamsInviteJoinResult.joined) {
        _message(
          result == TeamsInviteJoinResult.roomFull
              ? (_isSpanish
                  ? 'La sala ya está llena.'
                  : 'This room is already full.')
              : (_isSpanish
                  ? 'La sala ya no está disponible.'
                  : 'This room is no longer available.'),
        );
        return;
      }
      widget.navigatorKey.currentState?.pushNamed(
        '/domino-teams-online-lobby',
        arguments: {'initialGameId': roomId},
      );
      return;
    }

    var gameId = data['gameId'] as String? ?? '';
    if (gameId.isEmpty) {
      final hostId = (data['fromId'] as String? ?? '').toUpperCase();
      final hostDoc =
          await _db.collection('kapi_lobby_profiles').doc(hostId).get();
      final hostData = hostDoc.data();
      if (hostData == null) {
        await invite.reference.update({
          'status': 'failed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final host = DominoPlayerProfile(
        initials:
            hostData['initials'] as String? ??
            data['fromInitials'] as String? ??
            'P1',
        countryCode: hostData['countryCode'] as String? ?? '',
        code: hostData['code'] as String? ?? hostId.split('.').last,
        avatarKey: hostData['avatarKey'] as String? ?? 'person',
      );
      try {
        gameId = await OnlineGameFactory.createClassicGame(
          db: _db,
          host: host,
          guestId: profile.publicId,
          guestInitials: profile.initials,
        );
      } on StateError {
        await invite.reference.update({
          'status': 'roomFull',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _message(
          _isSpanish
              ? 'Uno de los jugadores ya está en otra partida.'
              : 'One of the players is already in another game.',
        );
        return;
      }
    }
    final canEnter = await BlockRoomService(
      _db,
    ).canEnterRoom(playerId: profile.publicId, gameId: gameId);
    if (!canEnter) {
      await invite.reference.update({
        'status': 'roomFull',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(
        _isSpanish
            ? 'La sala ya no está disponible.'
            : 'This room is no longer available.',
      );
      return;
    }
    await invite.reference.update({
      'status': 'accepted',
      'gameId': gameId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    widget.navigatorKey.currentState?.pushNamed(
      '/domino-online',
      arguments: {'gameId': gameId, 'playerId': profile.publicId},
    );
  }

  void _message(String message) {
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
