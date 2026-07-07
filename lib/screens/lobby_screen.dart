import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'domino_online_game_screen.dart';
import 'domino_player_profile.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _friendIdController = TextEditingController();
  Timer? _presenceTimer;
  DominoPlayerProfile _profile = const DominoPlayerProfile(
    initials: 'JP',
    countryCode: 'US',
    code: '000000',
    avatarKey: 'person',
  );
  bool _loading = true;
  String? _error;

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';
  String get _myHashtag => '#${_profile.code.toUpperCase()}';

  @override
  void initState() {
    super.initState();
    unawaited(_startLobby());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _friendIdController.dispose();
    unawaited(_setOffline());
    super.dispose();
  }

  Future<void> _startLobby() async {
    try {
      final profile = await DominoPlayerProfile.load();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
      await _upsertPresence();
      _presenceTimer = Timer.periodic(
        const Duration(seconds: 25),
        (_) => unawaited(_upsertPresence()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _upsertPresence() {
    final publicId = _profile.publicId.toUpperCase();
    final code = _profile.code.toUpperCase();
    final batch = _db.batch();
    batch.set(_db.collection('kapi_lobby_profiles').doc(publicId), {
      'publicId': _profile.publicId,
      'initials': _profile.initials,
      'countryCode': _profile.countryCode,
      'code': code,
      'hashtag': _myHashtag,
      'avatarKey': _profile.avatarKey,
      'status': 'online',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('kapi_lobby_codes').doc(code), {
      'code': code,
      'publicId': publicId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return batch.commit();
  }

  Future<void> _setOffline() async {
    try {
      await _db.collection('kapi_lobby_profiles').doc(_profile.publicId).set({
        'status': 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best effort only; the next heartbeat will repair stale presence.
    }
  }

  Future<void> _sendFriendRequest() async {
    try {
      final toId = await _resolveFriendId(_friendIdController.text);
      final fromId = _profile.publicId.toUpperCase();
      if (toId == null || toId.isEmpty || toId == fromId) return;

      final requestId = _requestId(fromId: fromId, toId: toId);
      await _upsertPresence();
      await _db.collection('kapi_friend_requests').doc(requestId).set({
        'fromId': fromId,
        'toId': toId,
        'fromInitials': _profile.initials,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _friendIdController.clear();
      _showToast(_isSpanish ? 'Solicitud enviada.' : 'Request sent.');
    } catch (error) {
      _showToast(_friendlyLobbyError(error));
    }
  }

  Future<String?> _resolveFriendId(String rawInput) async {
    final input = rawInput.trim().toUpperCase();
    if (input.isEmpty) return null;
    if (input.contains('.')) return input;

    final code = input.replaceAll('#', '').replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!RegExp(r'^[A-NP-Z1-9]{6}$').hasMatch(code)) {
      _showToast(
        _isSpanish
            ? 'Usa un hashtag sin 0 ni O, como #A1B2C3.'
            : 'Use a hashtag without 0 or O, like #A1B2C3.',
      );
      return null;
    }

    final codeDoc = await _db.collection('kapi_lobby_codes').doc(code).get();
    final mappedId = codeDoc.data()?['publicId'] as String?;
    if (mappedId == null || mappedId.isEmpty) {
      _showToast(
        _isSpanish
            ? 'No encontre un jugador con $code.'
            : 'No player found with $code.',
      );
      return null;
    }
    return mappedId.toUpperCase();
  }

  Future<void> _shareFriendInvite() async {
    final message =
        _isSpanish
            ? 'Juega domino conmigo en Kapi Note. Agregame en el lobby con $_myHashtag o ID ${_profile.publicId.toUpperCase()}.'
            : 'Play domino with me in Kapi Note. Add me in the lobby with $_myHashtag or ID ${_profile.publicId.toUpperCase()}.';
    await Share.share(message);
  }

  Future<void> _acceptRequest(_LobbyRequest request) async {
    final pairId = _pairId(_profile.publicId, request.fromId);
    final batch = _db.batch();
    batch.set(_db.collection('kapi_friendships').doc(pairId), {
      'users': [_profile.publicId.toUpperCase(), request.fromId],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.update(_db.collection('kapi_friend_requests').doc(request.id), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } catch (error) {
      _showToast(error.toString());
    }
  }

  Future<void> _rejectRequest(_LobbyRequest request) async {
    try {
      await _db.collection('kapi_friend_requests').doc(request.id).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _showToast(error.toString());
    }
  }

  Future<void> _inviteFriend(_LobbyFriend friend) async {
    try {
      final gameId = await OnlineGameFactory.createClassicGame(
        db: _db,
        host: _profile,
        guestId: friend.publicId,
        guestInitials: friend.initials,
      );
      await _db.collection('kapi_game_invites').add({
        'fromId': _profile.publicId.toUpperCase(),
        'toId': friend.publicId,
        'mode': 'classic',
        'status': 'pending',
        'gameId': gameId,
        'fromInitials': _profile.initials,
        'toInitials': friend.initials,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showToast(_isSpanish ? 'Invitacion enviada.' : 'Invite sent.');
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/domino-online',
        arguments: {
          'gameId': gameId,
          'playerId': _profile.publicId.toUpperCase(),
        },
      );
    } catch (error) {
      _showToast(error.toString());
    }
  }

  Future<void> _acceptGameInvite(_GameInvite invite) async {
    try {
      await _db.collection('kapi_game_invites').doc(invite.id).set({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/domino-online',
        arguments: {
          'gameId': invite.gameId,
          'playerId': _profile.publicId.toUpperCase(),
        },
      );
    } catch (error) {
      _showToast(_friendlyLobbyError(error));
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _friendlyLobbyError(Object error) {
    if (error is FirebaseException &&
        (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
      return _isSpanish
          ? 'No se pudo conectar al lobby. Revisa internet e intenta otra vez.'
          : 'Could not connect to the lobby. Check internet and try again.';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return _isSpanish
          ? 'El lobby no tiene permiso en Firebase todavia.'
          : 'The lobby does not have Firebase permission yet.';
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final myId = _profile.publicId.toUpperCase();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSpanish ? 'Lobby y amigos' : 'Lobby & Friends',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6D0907), Color(0xFF071524)],
          ),
        ),
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      _buildMyIdCard(),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        _buildEmptyText(_error!),
                      ],
                      const SizedBox(height: 14),
                      _buildFriendRequestCard(),
                      const SizedBox(height: 14),
                      _buildSectionTitle(
                        _isSpanish ? 'Invitaciones' : 'Game Invites',
                      ),
                      _buildGameInvites(myId),
                      const SizedBox(height: 14),
                      _buildSectionTitle(
                        _isSpanish ? 'Solicitudes' : 'Requests',
                      ),
                      _buildRequests(myId),
                      const SizedBox(height: 14),
                      _buildSectionTitle(_isSpanish ? 'Amigos' : 'Friends'),
                      _buildFriends(myId),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildMyIdCard() {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            decoration: BoxDecoration(
              color: _profile.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD36B)),
            ),
            child: Icon(_profile.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSpanish ? 'Tu ID publico' : 'Your public ID',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _profile.publicId.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSpanish
                      ? 'Hashtag rapido: $_myHashtag'
                      : 'Quick hashtag: $_myHashtag',
                  style: const TextStyle(
                    color: Color(0xFFFFD36B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const _OnlinePulse(),
        ],
      ),
    );
  }

  Widget _buildFriendRequestCard() {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isSpanish ? 'Enviar friend request' : 'Send friend request',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _friendIdController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: '#A1B2C3 or JP.US.A1B2C3',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sendFriendRequest,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    _isSpanish ? 'Enviar' : 'Send',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareFriendInvite,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(
                    _isSpanish ? 'Compartir' : 'Share',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequests(String myId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          _db
              .collection('kapi_friend_requests')
              .where('toId', isEqualTo: myId)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyText(snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests =
            snapshot.data!.docs.map(_LobbyRequest.fromDocument).toList();
        if (requests.isEmpty) {
          return _buildEmptyText(
            _isSpanish
                ? 'No hay solicitudes pendientes.'
                : 'No pending requests.',
          );
        }
        return Column(
          children: [for (final request in requests) _buildRequestRow(request)],
        );
      },
    );
  }

  Widget _buildGameInvites(String myId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          _db
              .collection('kapi_game_invites')
              .where('toId', isEqualTo: myId)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyText(snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final invites =
            snapshot.data!.docs.map(_GameInvite.fromDocument).toList();
        if (invites.isEmpty) {
          return _buildEmptyText(
            _isSpanish
                ? 'No hay invitaciones para jugar.'
                : 'No game invites yet.',
          );
        }
        return Column(
          children: [
            for (final invite in invites)
              _buildPersonRow(
                _LobbyFriend(
                  publicId: invite.fromId,
                  initials: invite.fromInitials,
                  online: true,
                  rank: _isSpanish ? 'Quiere jugar' : 'Wants to play',
                ),
                trailing: FilledButton(
                  onPressed: () => _acceptGameInvite(invite),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isSpanish ? 'Aceptar' : 'Accept'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFriends(String myId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          _db
              .collection('kapi_friendships')
              .where('users', arrayContains: myId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyText(snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final friendIds =
            snapshot.data!.docs
                .expand((doc) => List<String>.from(doc.data()['users'] ?? []))
                .where((id) => id != myId)
                .toSet()
                .toList();
        if (friendIds.isEmpty) {
          return _buildEmptyText(
            _isSpanish ? 'Todavia no tienes amigos.' : 'No friends yet.',
          );
        }
        return Column(
          children: [
            for (final friendId in friendIds) _buildFriendProfile(friendId),
          ],
        );
      },
    );
  }

  Widget _buildFriendProfile(String friendId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('kapi_lobby_profiles').doc(friendId).snapshots(),
      builder: (context, snapshot) {
        final friend = _LobbyFriend.fromProfile(
          friendId,
          snapshot.data?.data(),
        );
        return _buildFriendRow(friend);
      },
    );
  }

  Widget _buildRequestRow(_LobbyRequest request) {
    return _buildPersonRow(
      _LobbyFriend(
        publicId: request.fromId,
        initials: request.fromInitials,
        online: false,
        rank: 'Pending',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _acceptRequest(request),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
          ),
          IconButton(
            onPressed: () => _rejectRequest(request),
            icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRow(_LobbyFriend friend) {
    return _buildPersonRow(
      friend,
      trailing: FilledButton(
        onPressed: friend.online ? () => _inviteFriend(friend) : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
        ),
        child: Text(_isSpanish ? 'Invitar' : 'Invite'),
      ),
    );
  }

  Widget _buildPersonRow(_LobbyFriend friend, {required Widget trailing}) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: _panelDecoration(alpha: 0.32),
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 18 : 20,
            backgroundColor:
                friend.online ? const Color(0xFF1FBF68) : Colors.grey,
            child: Text(
              friend.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.publicId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${friend.rank} · ${friend.online ? 'Online' : 'Offline'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(alpha: 0.26),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration({double alpha = 0.38}) {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    );
  }

  String _pairId(String first, String second) {
    final ids = [first.toUpperCase(), second.toUpperCase()]..sort();
    return ids.join('__');
  }

  String _requestId({required String fromId, required String toId}) {
    return '${fromId.toUpperCase()}__${toId.toUpperCase()}';
  }
}

class _OnlinePulse extends StatelessWidget {
  const _OnlinePulse();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFF1FBF68),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1FBF68).withValues(alpha: 0.65),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _LobbyRequest {
  const _LobbyRequest({
    required this.id,
    required this.fromId,
    required this.fromInitials,
  });

  final String id;
  final String fromId;
  final String fromInitials;

  static _LobbyRequest fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _LobbyRequest(
      id: doc.id,
      fromId: (data['fromId'] as String? ?? '').toUpperCase(),
      fromInitials: data['fromInitials'] as String? ?? '??',
    );
  }
}

class _LobbyFriend {
  const _LobbyFriend({
    required this.publicId,
    required this.initials,
    required this.online,
    required this.rank,
  });

  final String publicId;
  final String initials;
  final bool online;
  final String rank;

  static _LobbyFriend fromProfile(String publicId, Map<String, dynamic>? data) {
    final updatedAt = data?['updatedAt'];
    final updatedDate =
        updatedAt is Timestamp ? updatedAt.toDate() : DateTime(2000);
    final isFresh =
        DateTime.now().difference(updatedDate) < const Duration(seconds: 90);
    final status = data?['status'] as String? ?? 'offline';
    return _LobbyFriend(
      publicId: publicId,
      initials:
          (data?['initials'] as String?) ??
          publicId.split('.').first.padRight(2, '?').substring(0, 2),
      online: status == 'online' && isFresh,
      rank: data?['rank'] as String? ?? 'Bronze',
    );
  }
}

class _GameInvite {
  const _GameInvite({
    required this.id,
    required this.fromId,
    required this.fromInitials,
    required this.gameId,
  });

  final String id;
  final String fromId;
  final String fromInitials;
  final String gameId;

  static _GameInvite fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _GameInvite(
      id: doc.id,
      fromId: (data['fromId'] as String? ?? '').toUpperCase(),
      fromInitials: data['fromInitials'] as String? ?? '??',
      gameId: data['gameId'] as String? ?? '',
    );
  }
}
