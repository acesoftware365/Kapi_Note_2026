import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../premium_notifier.dart';
import '../services/mac_pro_features_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _presenceTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _pointsSubscription;
  DominoPlayerProfile _profile = const DominoPlayerProfile(
    initials: 'JP',
    countryCode: 'US',
    code: '000000',
    avatarKey: 'person',
  );
  bool _loading = true;
  String? _error;
  int _socialTab = 0;
  bool _onlineOpen = true;
  bool _allFriendsOpen = true;
  bool _invitesOpen = true;
  bool _requestsOpen = true;
  int _playerPoints = 0;

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
    unawaited(_pointsSubscription?.cancel());
    _friendIdController.dispose();
    _searchController.dispose();
    unawaited(_setOffline());
    super.dispose();
  }

  Future<void> _startLobby() async {
    try {
      final profile = await DominoPlayerProfile.load();
      final prefs = await SharedPreferences.getInstance();
      final localPoints =
          prefs.getInt('kapi_player_points_${profile.code}_total') ?? 0;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _playerPoints = localPoints;
        _loading = false;
      });
      _pointsSubscription = _db
          .collection('kapi_player_points')
          .doc(profile.code.toUpperCase())
          .snapshots()
          .listen((snapshot) {
            final cloudPoints = _pointValue(snapshot.data()?['totalPoints']);
            if (!mounted) return;
            setState(() {
              _playerPoints = cloudPoints;
            });
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
      'displayName': _profile.effectiveDisplayName,
      'countryCode': _profile.countryCode,
      'code': code,
      'hashtag': _myHashtag,
      'avatarKey': _profile.avatarKey,
      'rank': DominoTierVisual.fromScore(_playerPoints).label,
      'totalPoints': _playerPoints,
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
        'fromDisplayName': _profile.effectiveDisplayName,
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
      final premium = context.read<PremiumNotifier>();
      final customTarget =
          premium.isMacPro
              ? await MacProFeaturesService.instance.targetScore()
              : null;
      final gameId = await OnlineGameFactory.createClassicGame(
        db: _db,
        host: _profile,
        guestId: friend.publicId,
        guestInitials: friend.initials,
        targetScore: customTarget,
      );
      await _db.collection('kapi_game_invites').add({
        'fromId': _profile.publicId.toUpperCase(),
        'toId': friend.publicId,
        'mode': 'classic',
        'status': 'pending',
        'gameId': gameId,
        'fromInitials': _profile.initials,
        'fromDisplayName': _profile.effectiveDisplayName,
        'toInitials': friend.initials,
        'toDisplayName': friend.effectiveDisplayName,
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
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackToGameSetup();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _goBackToGameSetup,
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
                    : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 720 : 520,
                        ),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 24 : 16,
                            14,
                            isTablet ? 24 : 16,
                            24,
                          ),
                          children: [
                            _buildPartyStage(myId, isTablet),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              _buildEmptyText(_error!),
                            ],
                            const SizedBox(height: 16),
                            _buildSocialPanel(myId),
                          ],
                        ),
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  void _goBackToGameSetup() {
    Navigator.pushReplacementNamed(context, '/start-game');
  }

  Widget _buildPartyStage(String myId, bool isTablet) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFFD36B).withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _isSpanish ? 'Prepara tu partida' : 'Prepare match',
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isSpanish
                ? 'Invita un amigo o encuentra un rival disponible.'
                : 'Invite one friend or find an available rival.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontWeight: FontWeight.w700,
              fontSize: isTablet ? 14 : 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildPartyPlayerCard(compact: compact)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: const Color(0xFFFFD36B).withValues(alpha: 0.86),
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(child: _buildRivalSlot(compact: compact)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: isTablet ? 54 : 48,
            child: FilledButton.icon(
              onPressed: _findMatch,
              icon: const Icon(Icons.travel_explore_rounded),
              label: Text(
                _isSpanish ? 'Encontrar partida' : 'Find match',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareFriendInvite,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(_isSpanish ? 'Compartir ID' : 'Share ID'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: const Color(0xFFFFD36B).withValues(alpha: 0.36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyPlayerCard({required bool compact}) {
    final tierVisual = DominoTierVisual.fromScore(_playerPoints);
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 112 : 124),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tierVisual.deep.withValues(alpha: 0.76),
            Colors.black.withValues(alpha: 0.40),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierVisual.frameColor(), width: 1.2),
        boxShadow: tierVisual.shadows(),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatarFrame(size: compact ? 46 : 52, visual: tierVisual),
          const SizedBox(height: 8),
          Text(
            _profile.effectiveDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 19 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _profile.publicId.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          _buildMiniTierChip(tierVisual),
        ],
      ),
    );
  }

  Widget _buildRivalSlot({required bool compact}) {
    return InkWell(
      onTap:
          () => _showToast(
            _isSpanish
                ? 'Elige un amigo online abajo para invitarlo.'
                : 'Pick an online friend below to invite.',
          ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 112 : 124),
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 48 : 54,
              height: compact ? 48 : 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD36B)),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFFFFD36B),
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSpanish ? 'Invitar amigo' : 'Invite friend',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              _isSpanish ? '1 vs 1' : '1 vs 1',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFrame({
    required double size,
    required DominoTierVisual visual,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [visual.accent, visual.avatarBackground(_profile.color)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: visual.frameColor(), width: 1.5),
        boxShadow: visual.shadows(),
      ),
      clipBehavior: Clip.antiAlias,
      child: DominoAvatarVisual(
        avatarKey: _profile.avatarKey,
        fallbackIcon: _profile.icon,
        backgroundColor: visual.avatarBackground(_profile.color),
      ),
    );
  }

  Widget _buildMiniTierChip(DominoTierVisual visual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.accent.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, color: visual.accent, size: 11),
          const SizedBox(width: 4),
          Text(
            visual.label,
            style: TextStyle(
              color: visual.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialHeader() {
    return Row(
      children: [
        const Icon(Icons.groups_2_rounded, color: Color(0xFFFFD36B), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _isSpanish ? 'Social' : 'Social',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialPanel(String myId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSocialHeader(),
          const SizedBox(height: 10),
          _buildSocialTabs(),
          const SizedBox(height: 10),
          if (_socialTab == 0) ...[
            _buildSearchField(),
            const SizedBox(height: 12),
            _buildCollapsibleHeader(
              title: _isSpanish ? 'En linea' : 'Online',
              icon: Icons.circle,
              accent: const Color(0xFF28C76F),
              open: _onlineOpen,
              onTap: () => setState(() => _onlineOpen = !_onlineOpen),
            ),
            if (_onlineOpen) _buildFriends(myId, onlineOnly: true),
            const SizedBox(height: 10),
            _buildCollapsibleHeader(
              title: _isSpanish ? 'General' : 'General',
              icon: Icons.groups_2_rounded,
              accent: const Color(0xFFFFD36B),
              open: _allFriendsOpen,
              onTap: () => setState(() => _allFriendsOpen = !_allFriendsOpen),
            ),
            if (_allFriendsOpen) _buildFriends(myId),
          ] else if (_socialTab == 1) ...[
            _buildCollapsibleHeader(
              title: _isSpanish ? 'Invitaciones' : 'Game Invites',
              icon: Icons.sports_esports_rounded,
              accent: const Color(0xFFFFD36B),
              open: _invitesOpen,
              onTap: () => setState(() => _invitesOpen = !_invitesOpen),
            ),
            if (_invitesOpen) _buildGameInvites(myId),
            const SizedBox(height: 10),
            _buildCollapsibleHeader(
              title: _isSpanish ? 'Solicitudes' : 'Requests',
              icon: Icons.person_add_alt_1_rounded,
              accent: const Color(0xFF64B5F6),
              open: _requestsOpen,
              onTap: () => setState(() => _requestsOpen = !_requestsOpen),
            ),
            if (_requestsOpen) _buildRequests(myId),
          ] else ...[
            _buildFriendRequestCard(embedded: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialTabs() {
    final tabs = [
      (Icons.format_list_bulleted_rounded, _isSpanish ? 'Amigos' : 'Friends'),
      (Icons.chat_bubble_outline_rounded, _isSpanish ? 'Invites' : 'Invites'),
      (Icons.person_add_alt_1_rounded, _isSpanish ? 'Anadir' : 'Add'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _socialTab = i),
                borderRadius: BorderRadius.circular(13),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        _socialTab == i
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        tabs[i].$1,
                        color:
                            _socialTab == i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.78),
                        size: 20,
                      ),
                      Positioned(
                        bottom: 0,
                        left: 18,
                        right: 18,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 3,
                          decoration: BoxDecoration(
                            color:
                                _socialTab == i
                                    ? const Color(0xFFE53935)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.46),
        ),
        hintText: _isSpanish ? 'Buscar' : 'Search',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.46)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCollapsibleHeader({
    required String title,
    required IconData icon,
    required Color accent,
    required bool open,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: open ? Colors.white.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ],
        ),
      ),
    );
  }

  void _findMatch() {
    _showToast(
      _isSpanish
          ? 'La búsqueda de partidas estará disponible pronto. Por ahora invita a un amigo.'
          : 'Matchmaking is coming soon. For now, invite a friend.',
    );
  }

  Widget _buildFriendRequestCard({bool embedded = false}) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: embedded ? null : _panelDecoration(),
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
                  displayName: invite.fromDisplayName,
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

  Widget _buildFriends(String myId, {bool onlineOnly = false}) {
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
            for (final friendId in friendIds)
              _buildFriendProfile(friendId, onlineOnly: onlineOnly),
          ],
        );
      },
    );
  }

  Widget _buildFriendProfile(String friendId, {bool onlineOnly = false}) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('kapi_lobby_profiles').doc(friendId).snapshots(),
      builder: (context, profileSnapshot) {
        final profileData = profileSnapshot.data?.data();
        final code =
            (profileData?['code'] as String?)?.toUpperCase() ??
            friendId.split('.').last.toUpperCase();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('kapi_player_points').doc(code).snapshots(),
          builder: (context, pointsSnapshot) {
            final friend = _LobbyFriend.fromProfile(
              friendId,
              profileData,
              pointsData: pointsSnapshot.data?.data(),
            );
            if (onlineOnly && !friend.online) {
              return const SizedBox.shrink();
            }
            final query = _searchController.text.trim().toUpperCase();
            if (query.isNotEmpty &&
                !friend.publicId.toUpperCase().contains(query) &&
                !friend.initials.toUpperCase().contains(query) &&
                !friend.effectiveDisplayName.toUpperCase().contains(query) &&
                !friend.rank.toUpperCase().contains(query)) {
              return const SizedBox.shrink();
            }
            return _buildFriendRow(friend);
          },
        );
      },
    );
  }

  Widget _buildRequestRow(_LobbyRequest request) {
    return _buildPersonRow(
      _LobbyFriend(
        publicId: request.fromId,
        initials: request.fromInitials,
        displayName: request.fromDisplayName,
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
    final tierVisual = DominoTierVisual.forLabel(friend.rank);
    final isPending = friend.rank.toLowerCase() == 'pending';
    final avatarAccent =
        isPending
            ? const Color(0xFFFFD36B)
            : (tierVisual.isRanked
                ? tierVisual.accent
                : (friend.online ? const Color(0xFF1FBF68) : Colors.grey));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: _panelDecoration(alpha: 0.32),
      child: Row(
        children: [
          Container(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            decoration: BoxDecoration(
              gradient:
                  tierVisual.isRanked
                      ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [tierVisual.accent, tierVisual.deep],
                      )
                      : null,
              color: tierVisual.isRanked ? null : avatarAccent,
              shape: BoxShape.circle,
              border: Border.all(color: avatarAccent.withValues(alpha: 0.90)),
              boxShadow:
                  tierVisual.isRanked
                      ? [
                        BoxShadow(
                          color: tierVisual.accent.withValues(alpha: 0.20),
                          blurRadius: tierVisual.glow,
                        ),
                      ]
                      : null,
            ),
            child: Center(
              child: Text(
                friend.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.effectiveDisplayName,
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

class _LobbyRequest {
  const _LobbyRequest({
    required this.id,
    required this.fromId,
    required this.fromInitials,
    this.fromDisplayName = '',
  });

  final String id;
  final String fromId;
  final String fromInitials;
  final String fromDisplayName;

  static _LobbyRequest fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _LobbyRequest(
      id: doc.id,
      fromId: (data['fromId'] as String? ?? '').toUpperCase(),
      fromInitials: data['fromInitials'] as String? ?? '??',
      fromDisplayName: data['fromDisplayName'] as String? ?? '',
    );
  }
}

class _LobbyFriend {
  const _LobbyFriend({
    required this.publicId,
    required this.initials,
    this.displayName = '',
    required this.online,
    required this.rank,
  });

  final String publicId;
  final String initials;
  final String displayName;
  final bool online;
  final String rank;

  String get effectiveDisplayName {
    final normalized = DominoPlayerProfile.normalizeDisplayName(displayName);
    return DominoPlayerProfile.isValidDisplayName(normalized)
        ? normalized
        : initials;
  }

  static _LobbyFriend fromProfile(
    String publicId,
    Map<String, dynamic>? data, {
    Map<String, dynamic>? pointsData,
  }) {
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
      displayName: data?['displayName'] as String? ?? '',
      online: status == 'online' && isFresh,
      rank:
          DominoTierVisual.fromScore(
            _intValue(pointsData?['totalPoints'] ?? data?['totalPoints']),
          ).label,
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

int _pointValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class _GameInvite {
  const _GameInvite({
    required this.id,
    required this.fromId,
    required this.fromInitials,
    this.fromDisplayName = '',
    required this.gameId,
  });

  final String id;
  final String fromId;
  final String fromInitials;
  final String fromDisplayName;
  final String gameId;

  static _GameInvite fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _GameInvite(
      id: doc.id,
      fromId: (data['fromId'] as String? ?? '').toUpperCase(),
      fromInitials: data['fromInitials'] as String? ?? '??',
      fromDisplayName: data['fromDisplayName'] as String? ?? '',
      gameId: data['gameId'] as String? ?? '',
    );
  }
}
