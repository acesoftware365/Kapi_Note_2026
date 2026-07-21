import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../domino_player_profile.dart';

class SimpleLobbyFriend {
  const SimpleLobbyFriend({
    required this.publicId,
    required this.initials,
    required this.countryCode,
    required this.code,
    required this.avatarKey,
    required this.points,
    required this.online,
  });

  final String publicId;
  final String initials;
  final String countryCode;
  final String code;
  final String avatarKey;
  final int points;
  final bool online;
}

class SimpleFriendsScreen extends StatefulWidget {
  const SimpleFriendsScreen({
    super.key,
    required this.profile,
    this.multiSelect = false,
    this.maxSelections = 12,
  });

  final DominoPlayerProfile profile;
  final bool multiSelect;
  final int maxSelections;

  @override
  State<SimpleFriendsScreen> createState() => _SimpleFriendsScreenState();
}

class _SimpleFriendsScreenState extends State<SimpleFriendsScreen> {
  bool _onlineExpanded = true;
  bool _offlineExpanded = true;
  final Map<String, SimpleLobbyFriend> _selected = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _isSpanish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'es';

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final myId = widget.profile.publicId.toUpperCase();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D0907),
        foregroundColor: Colors.white,
        title: Text(
          _isSpanish(context) ? 'Mis amigos' : 'My friends',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _isSpanish(context) ? 'Agregar amigo' : 'Add friend',
            onPressed: _showAddFriendDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          const SizedBox(width: 60),
        ],
      ),
      bottomNavigationBar:
          widget.multiSelect
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed:
                        _selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                              context,
                              _selected.values.toList(growable: false),
                            ),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      _isSpanish(context)
                          ? 'Invitar (${_selected.length})'
                          : 'Invite (${_selected.length})',
                    ),
                  ),
                ),
              )
              : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF55100F), Color(0xFF071524)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              db
                  .collection('kapi_friendships')
                  .where('users', arrayContains: myId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _errorState(context);
            }
            final ids = <String>{};
            for (final doc in snapshot.data?.docs ?? const []) {
              final users = List<String>.from(doc.data()['users'] ?? []);
              ids.addAll(users.map((id) => id.toUpperCase()));
            }
            ids.remove(myId);
            if (ids.isEmpty) {
              return _emptyState(context);
            }
            return FutureBuilder<List<SimpleLobbyFriend>>(
              future: _loadFriends(db, ids),
              builder: (context, friendsSnapshot) {
                if (friendsSnapshot.hasError) {
                  return _errorState(context);
                }
                final friends = friendsSnapshot.data;
                if (friends == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final online =
                    friends.where((friend) => friend.online).toList();
                final offline =
                    friends.where((friend) => !friend.online).toList();
                return _friendsList(context, online: online, offline: offline);
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<SimpleLobbyFriend>> _loadFriends(
    FirebaseFirestore db,
    Set<String> ids,
  ) async {
    final friends = <SimpleLobbyFriend>[];
    for (final id in ids) {
      final profileDoc =
          await db.collection('kapi_lobby_profiles').doc(id).get();
      final data = profileDoc.data() ?? {};
      final code = data['code'] as String? ?? id.split('.').last;
      final pointsDoc =
          await db.collection('kapi_player_points').doc(code).get();
      final rawPoints = pointsDoc.data()?['totalPoints'];
      final rawUpdatedAt = data['updatedAt'];
      final updatedAt =
          rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null;
      final recentlyActive =
          updatedAt != null &&
          DateTime.now().difference(updatedAt).inSeconds.abs() < 90;
      friends.add(
        SimpleLobbyFriend(
          publicId: id,
          initials: data['initials'] as String? ?? id.split('.').first,
          countryCode: data['countryCode'] as String? ?? '',
          code: code,
          avatarKey: data['avatarKey'] as String? ?? 'person',
          points: rawPoints is num ? rawPoints.toInt() : 0,
          online: data['status'] == 'online' && recentlyActive,
        ),
      );
    }
    friends.sort((a, b) {
      if (a.online != b.online) return a.online ? -1 : 1;
      return a.initials.compareTo(b.initials);
    });
    return friends;
  }

  Widget _friendsList(
    BuildContext context, {
    required List<SimpleLobbyFriend> online,
    required List<SimpleLobbyFriend> offline,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _informationCard(context),
        const SizedBox(height: 16),
        _pendingRequestsSection(context),
        const SizedBox(height: 14),
        _section(
          context,
          title: _isSpanish(context) ? 'En línea' : 'Online',
          friends: online,
          enabled: true,
          expanded: _onlineExpanded,
          accent: const Color(0xFF45D483),
          onToggle: () => setState(() => _onlineExpanded = !_onlineExpanded),
        ),
        const SizedBox(height: 14),
        _section(
          context,
          title: _isSpanish(context) ? 'Desconectados' : 'Offline',
          friends: offline,
          enabled: false,
          expanded: _offlineExpanded,
          accent: Colors.white38,
          onToggle: () => setState(() => _offlineExpanded = !_offlineExpanded),
        ),
      ],
    );
  }

  Widget _pendingRequestsSection(BuildContext context) {
    final myId = widget.profile.publicId.toUpperCase();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('kapi_friend_requests')
              .where('toId', isEqualTo: myId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final requests =
            (snapshot.data?.docs ?? const [])
                .where((doc) => doc.data()['status'] == 'pending')
                .map(_SimpleFriendRequest.fromDocument)
                .toList();
        if (requests.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2B1720).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF6473), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFFFF8A97),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _isSpanish(context)
                        ? 'Solicitudes recibidas (${requests.length})'
                        : 'Friend requests (${requests.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final request in requests) _requestRow(context, request),
            ],
          ),
        );
      },
    );
  }

  Widget _requestRow(BuildContext context, _SimpleFriendRequest request) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF7A2634),
            foregroundColor: Colors.white,
            child: Text(
              request.fromInitials,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              request.fromInitials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: _isSpanish(context) ? 'Rechazar' : 'Decline',
            onPressed: () => _rejectRequest(request),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: _isSpanish(context) ? 'Aceptar' : 'Accept',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2EB872),
            ),
            onPressed: () => _acceptRequest(request),
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFriendDialog() async {
    var friendId = '';
    final input = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF101C29),
            title: Text(
              _isSpanish(context) ? 'Agregar amigo' : 'Add a friend',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSpanish(context)
                      ? 'Escribe su hashtag de 6 caracteres o su ID completo.'
                      : 'Enter their 6-character hashtag or full player ID.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                TextField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '#A1B2C3',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.tag_rounded),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (value) => friendId = value,
                  onSubmitted: (value) => Navigator.pop(context, value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_isSpanish(context) ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, friendId),
                icon: const Icon(Icons.send_rounded),
                label: Text(_isSpanish(context) ? 'Enviar' : 'Send'),
              ),
            ],
          ),
    );
    if (input == null || input.trim().isEmpty || !mounted) return;
    await _sendFriendRequest(input);
  }

  Future<void> _sendFriendRequest(String rawInput) async {
    final db = FirebaseFirestore.instance;
    final spanish = _isSpanish(context);
    try {
      final toId = await _resolveFriendId(rawInput);
      final fromId = widget.profile.publicId.toUpperCase();
      if (toId == null || !mounted) return;
      if (toId == fromId) {
        _showMessage(
          _isSpanish(context) ? 'Ese es tu propio ID.' : 'That is your own ID.',
        );
        return;
      }
      final pairId = _pairId(fromId, toId);
      final existing =
          await db.collection('kapi_friendships').doc(pairId).get();
      if (!mounted) return;
      if (existing.exists) {
        _showMessage(
          spanish
              ? 'Ese jugador ya está en tu lista.'
              : 'That player is already in your list.',
        );
        return;
      }
      await db.collection('kapi_friend_requests').doc('${fromId}__$toId').set({
        'fromId': fromId,
        'toId': toId,
        'fromInitials': widget.profile.initials,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _showMessage(spanish ? 'Solicitud enviada.' : 'Friend request sent.');
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        _isSpanish(context)
            ? 'No se pudo enviar. Revisa tu conexión.'
            : 'Could not send it. Check your connection.',
      );
    }
  }

  Future<String?> _resolveFriendId(String rawInput) async {
    final spanish = _isSpanish(context);
    final input = rawInput.trim().toUpperCase();
    if (input.isEmpty) return null;
    if (input.contains('.')) return input;
    final code = input.replaceAll('#', '').replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!RegExp(r'^[A-NP-Z1-9]{6}$').hasMatch(code)) {
      _showMessage(
        _isSpanish(context)
            ? 'Usa un código de 6 caracteres sin 0 ni O.'
            : 'Use a 6-character code without 0 or O.',
      );
      return null;
    }
    final codeDoc =
        await FirebaseFirestore.instance
            .collection('kapi_lobby_codes')
            .doc(code)
            .get();
    final mappedId = codeDoc.data()?['publicId'] as String?;
    if (!mounted) return null;
    if (mappedId == null || mappedId.isEmpty) {
      _showMessage(
        spanish
            ? 'No encontramos un jugador con #$code.'
            : 'No player was found with #$code.',
      );
      return null;
    }
    return mappedId.toUpperCase();
  }

  Future<void> _acceptRequest(_SimpleFriendRequest request) async {
    final db = FirebaseFirestore.instance;
    final myId = widget.profile.publicId.toUpperCase();
    final batch = db.batch();
    batch.set(
      db.collection('kapi_friendships').doc(_pairId(myId, request.fromId)),
      {
        'users': [myId, request.fromId],
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.update(db.collection('kapi_friend_requests').doc(request.id), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
      if (mounted) {
        _showMessage(_isSpanish(context) ? 'Amigo agregado.' : 'Friend added.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          _isSpanish(context)
              ? 'No se pudo aceptar la solicitud.'
              : 'The request could not be accepted.',
        );
      }
    }
  }

  Future<void> _rejectRequest(_SimpleFriendRequest request) async {
    try {
      await FirebaseFirestore.instance
          .collection('kapi_friend_requests')
          .doc(request.id)
          .update({
            'status': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      if (mounted) {
        _showMessage(
          _isSpanish(context)
              ? 'No se pudo rechazar la solicitud.'
              : 'The request could not be declined.',
        );
      }
    }
  }

  String _pairId(String first, String second) {
    final ids = [first.toUpperCase(), second.toUpperCase()]..sort();
    return ids.join('__');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _informationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102337).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5AB7FF), width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSpanish(context)
                      ? 'Tus amigos guardados'
                      : 'Your saved friends',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSpanish(context)
                      ? 'Los que están en línea pueden recibir una invitación. Los desconectados permanecen guardados.'
                      : 'Online friends can receive an invitation. Offline friends remain saved here.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
      children: [
        _pendingRequestsSection(context),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF102337).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF5AB7FF), width: 1.4),
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E88E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isSpanish(context)
                    ? 'Todavía no tienes amigos'
                    : 'You have no friends yet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _isSpanish(context)
                    ? 'Agrega a una persona usando su hashtag de 6 caracteres. Aparecerá aquí cuando acepte tu solicitud.'
                    : 'Add someone using their 6-character hashtag. They will appear here after accepting your request.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _showAddFriendDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    _isSpanish(context) ? 'Agregar amigo' : 'Add a friend',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 44),
          const SizedBox(height: 12),
          Text(
            _isSpanish(context)
                ? 'No se pudo cargar la lista. Revisa tu conexión e inténtalo otra vez.'
                : 'The list could not be loaded. Check your connection and try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    ),
  );

  Widget _section(
    BuildContext context, {
    required String title,
    required List<SimpleLobbyFriend> friends,
    required bool enabled,
    required bool expanded,
    required Color accent,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$title (${friends.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    expanded
                        ? (_isSpanish(context) ? 'Ocultar' : 'Hide')
                        : (_isSpanish(context) ? 'Mostrar' : 'Show'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(color: Colors.white12, height: 1),
                  if (friends.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        _isSpanish(context) ? 'Ninguno' : 'None',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  for (final friend in friends)
                    _friendRow(context, friend, enabled),
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _friendRow(
    BuildContext context,
    SimpleLobbyFriend friend,
    bool enabled,
  ) {
    final tier = DominoTierVisual.fromScore(friend.points);
    final country = friend.countryCode == 'US' ? 'USA' : friend.countryCode;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: tier.deep,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: tier.frameColor(), width: 1.5),
          boxShadow: tier.shadows(),
        ),
        clipBehavior: Clip.antiAlias,
        child: DominoAvatarVisual(
          avatarKey: friend.avatarKey,
          fallbackIcon: Icons.person_rounded,
          backgroundColor: tier.deep,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              '${friend.initials} · $country',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${tier.label} · ${friend.points} pts',
        style: const TextStyle(color: Colors.white60),
      ),
      onTap:
          widget.multiSelect && enabled ? () => _toggleSelection(friend) : null,
      trailing:
          enabled
              ? widget.multiSelect
                  ? Checkbox(
                    value: _selected.containsKey(friend.publicId),
                    onChanged: (_) => _toggleSelection(friend),
                  )
                  : FilledButton.icon(
                    onPressed: () => Navigator.pop(context, friend),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSpanish(context) ? 'Invitar' : 'Invite'),
                  )
              : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isSpanish(context) ? 'Fuera' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
    );
  }

  void _toggleSelection(SimpleLobbyFriend friend) {
    if (!friend.online) return;
    setState(() {
      if (_selected.remove(friend.publicId) != null) return;
      if (_selected.length >= widget.maxSelections) {
        _showMessage(
          _isSpanish(context)
              ? 'Puedes invitar hasta ${widget.maxSelections} amigos a la vez.'
              : 'You can invite up to ${widget.maxSelections} friends at once.',
        );
        return;
      }
      _selected[friend.publicId] = friend;
    });
  }
}

class _SimpleFriendRequest {
  const _SimpleFriendRequest({
    required this.id,
    required this.fromId,
    required this.fromInitials,
  });

  final String id;
  final String fromId;
  final String fromInitials;

  static _SimpleFriendRequest fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _SimpleFriendRequest(
      id: doc.id,
      fromId: (data['fromId'] as String? ?? '').toUpperCase(),
      fromInitials: data['fromInitials'] as String? ?? '??',
    );
  }
}
