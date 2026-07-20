import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/block_matchmaking_service.dart';
import '../../services/block_room_service.dart';
import '../../widgets/anchored_adaptive_banner_ad.dart';
import '../admob_variable.dart';
import '../domino_online_game_screen.dart';
import '../domino_player_profile.dart';
import 'match_found_transition_screen.dart';
import 'simple_friends_screen.dart';

class SimpleLobbyScreen extends StatefulWidget {
  const SimpleLobbyScreen({super.key});

  @override
  State<SimpleLobbyScreen> createState() => _SimpleLobbyScreenState();
}

class _SimpleLobbyScreenState extends State<SimpleLobbyScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DominoPlayerProfile? _profile;
  int _points = 0;
  bool _searching = false;
  bool _openingGame = false;
  bool _preparingMatch = false;
  DominoPlayerProfile? _matchedOpponent;
  int _matchCountdown = 3;
  Timer? _presenceTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _matchSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inviteSubscription;
  String? _shownInviteId;
  String? _activeSearchToken;

  late final BlockMatchmakingService _matchmaking = BlockMatchmakingService(
    _db,
  );

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';
  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    unawaited(_matchSubscription?.cancel());
    unawaited(_inviteSubscription?.cancel());
    final profile = _profile;
    if (_searching && profile != null) {
      unawaited(
        _matchmaking.cancel(
          profile.publicId,
          expectedToken: _activeSearchToken,
        ),
      );
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await DominoPlayerProfile.load();
    final prefs = await SharedPreferences.getInstance();
    final points =
        prefs.getInt('kapi_player_points_${profile.code}_total') ?? 0;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _points = points;
    });
    await _upsertPresence(profile);
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => unawaited(_upsertPresence(profile)),
    );
    _listenForInvites(profile);
    if (await _resumeOrReleaseActiveGame(profile)) return;
    const autoMatch = bool.fromEnvironment('KAPI_AUTO_MATCH');
    if (autoMatch) unawaited(_startMatchmaking());
  }

  Future<bool> _resumeOrReleaseActiveGame(DominoPlayerProfile profile) async {
    final roomService = BlockRoomService(_db);
    final gameId = await roomService.activeGameId(profile.publicId);
    if (gameId == null || gameId.isEmpty) return false;

    if (await roomService.canEnterRoom(
      playerId: profile.publicId,
      gameId: gameId,
    )) {
      if (mounted) unawaited(_openOnlineGame(gameId, showTransition: false));
      return true;
    }

    final snapshot =
        await _db.collection('kapi_online_games').doc(gameId).get();
    final players =
        (snapshot.data()?['players'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList();
    await roomService.releaseCompletedGame(
      players: players.isEmpty ? [profile.publicId] : players,
      gameId: gameId,
    );
    await _upsertPresence(profile);
    return false;
  }

  Future<void> _upsertPresence(DominoPlayerProfile profile) async {
    final tier = DominoTierVisual.fromScore(_points);
    final activeGameId = await BlockRoomService(
      _db,
    ).activeGameId(profile.publicId);
    final batch = _db.batch();
    batch.set(
      _db.collection('kapi_lobby_profiles').doc(profile.publicId),
      {
        'publicId': profile.publicId,
        'initials': profile.initials,
        'countryCode': profile.countryCode,
        'code': profile.code,
        'avatarKey': profile.avatarKey,
        'rank': tier.label,
        'totalPoints': _points,
        'status': 'online',
        'availability': activeGameId == null ? 'available' : 'inGame',
        'activeGameId': activeGameId ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('kapi_lobby_codes').doc(profile.code),
      {
        'code': profile.code,
        'publicId': profile.publicId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  void _listenForInvites(DominoPlayerProfile profile) {
    _inviteSubscription = _db
        .collection('kapi_game_invites')
        .where('toId', isEqualTo: profile.publicId.toUpperCase())
        .snapshots()
        .listen((snapshot) {
          for (final doc in snapshot.docs) {
            if (doc.data()['status'] == 'pending' && doc.id != _shownInviteId) {
              _shownInviteId = doc.id;
              unawaited(_showIncomingInvite(doc));
              break;
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width >= 700;
    final isIPhone = defaultTargetPlatform == TargetPlatform.iOS && !isTablet;
    final compact = isIPhone || size.height < 760 || size.width < 370;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B110F), Color(0xFF3A1420), Color(0xFF071524)],
            stops: [0, 0.52, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(compact: compact),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 56 : (compact ? 12 : 20),
                    compact ? 4 : 10,
                    isTablet ? 56 : (compact ? 12 : 20),
                    compact ? 14 : 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(compact: compact),
                          SizedBox(height: compact ? 10 : 18),
                          if (profile == null)
                            const Center(child: CircularProgressIndicator())
                          else ...[
                            _buildPlayers(profile, compact: compact),
                            SizedBox(height: compact ? 10 : 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child:
                                  _searching
                                      ? _buildSearchingPanel()
                                      : _buildChoicePanel(
                                        profile,
                                        compact: compact,
                                      ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnchoredAdaptiveBannerAd(
                adUnitId: _adUnitId,
                margin: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar({required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, compact ? 3 : 8, 12, compact ? 3 : 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: _isSpanish ? 'Volver' : 'Back',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6BE68A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSpanish ? 'Conectado' : 'Connected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isSpanish ? 'Lobby' : 'Lobby',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 21 : 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    return Column(
      children: [
        Text(
          _isSpanish ? 'Elige como jugar' : 'Choose how to play',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 24 : 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isSpanish ? 'Block Dominoes · 1 vs 1' : 'Block Dominoes · 1 vs 1',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayers(DominoPlayerProfile profile, {required bool compact}) {
    final tier = DominoTierVisual.fromScore(_points);
    final opponent = _matchedOpponent;
    final opponentTier = DominoTierVisual.fromScore(0);
    return Container(
      padding: EdgeInsets.all(compact ? 11 : 16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _PlayerSlot(
              icon: profile.icon,
              avatarKey: profile.avatarKey,
              initials: profile.initials,
              subtitle: '${_countryLabel(profile.countryCode)} · ${tier.label}',
              color: tier.avatarBackground(profile.color),
              borderColor: tier.frameColor(),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
            child: _LobbyVsMark(compact: compact),
          ),
          Expanded(
            child: _PlayerSlot(
              icon: opponent?.icon ?? Icons.add_rounded,
              avatarKey: opponent?.avatarKey,
              avatarText: opponent?.initials,
              initials:
                  opponent == null
                      ? (_isSpanish ? 'Rival' : 'Rival')
                      : _countryLabel(opponent.countryCode),
              subtitle:
                  opponent == null
                      ? (_isSpanish ? 'Sin elegir' : 'Not selected')
                      : opponentTier.label,
              color: opponent?.color ?? const Color(0xFF21181B),
              borderColor:
                  opponent == null ? Colors.white24 : opponentTier.frameColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicePanel(
    DominoPlayerProfile profile, {
    required bool compact,
  }) {
    return Container(
      key: const ValueKey('choices'),
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LobbyChoiceButton(
            icon: Icons.travel_explore_rounded,
            title: _isSpanish ? 'Buscar jugador' : 'Find a player',
            subtitle:
                _isSpanish
                    ? 'Conectar con alguien disponible'
                    : 'Connect with someone available',
            primary: true,
            compact: compact,
            onTap: _startMatchmaking,
          ),
          SizedBox(height: compact ? 8 : 12),
          _LobbyChoiceButton(
            icon: Icons.person_add_alt_1_rounded,
            title: _isSpanish ? 'Invitar amigo' : 'Invite a friend',
            subtitle:
                _isSpanish
                    ? 'Ver amigos online, desconectados o compartir ID'
                    : 'View online/offline friends or share your ID',
            onTap: () => _showInviteChoices(profile),
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 12),
          _LobbyChoiceButton(
            icon: Icons.smart_toy_rounded,
            title: _isSpanish ? 'Jugar contra CPU' : 'Play against CPU',
            subtitle:
                _isSpanish
                    ? 'Practicar sin esperar'
                    : 'Practice without waiting',
            onTap: () => Navigator.pushNamed(context, '/domino-block'),
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingPanel() {
    return Container(
      key: const ValueKey('searching'),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          const SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              color: Color(0xFFFFD36B),
              strokeWidth: 5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _matchedOpponent == null
                ? (_isSpanish ? 'Buscando jugador…' : 'Finding a player…')
                : (_isSpanish ? 'Jugador encontrado' : 'Player found'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _matchedOpponent == null
                ? (_isSpanish
                    ? 'Puedes cancelar cuando quieras.'
                    : 'You can cancel at any time.')
                : (_isSpanish
                    ? 'La partida comienza en $_matchCountdown…'
                    : 'Match starts in $_matchCountdown…'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _preparingMatch ? null : _cancelMatchmaking,
              icon: const Icon(Icons.close_rounded),
              label: Text(_isSpanish ? 'Cancelar búsqueda' : 'Cancel search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startMatchmaking() async {
    final profile = _profile;
    if (profile == null || _searching) return;
    final searchToken = BlockMatchmakingService.createSearchToken(
      profile.publicId,
    );
    setState(() {
      _searching = true;
      _activeSearchToken = searchToken;
    });
    await _matchSubscription?.cancel();
    _matchSubscription = _matchmaking.watch(profile.publicId).listen((doc) {
      final data = doc.data();
      if (data?['searchToken'] != _activeSearchToken) return;
      final status = data?['status'];
      if (status == 'matched' || status == 'inGame') {
        final gameId = data?['gameId'] as String?;
        final opponentId = data?['opponentId'] as String?;
        if (gameId != null &&
            gameId.isNotEmpty &&
            opponentId != null &&
            opponentId.isNotEmpty) {
          unawaited(_showMatchedPlayerThenOpen(gameId, opponentId));
        }
      }
    });
    try {
      final token = await _matchmaking.start(
        profile: profile,
        points: _points,
        searchToken: searchToken,
      );
      if (!mounted || !_searching) {
        await _matchmaking.cancel(profile.publicId, expectedToken: token);
        return;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _activeSearchToken = null;
      });
      _showMessage(
        _isSpanish
            ? 'Ya estas jugando en una sala. Sal de esa sala antes de buscar otra partida.'
            : 'You are already in a room. Leave it before searching for another match.',
      );
    }
  }

  Future<void> _cancelMatchmaking() async {
    final profile = _profile;
    await _matchSubscription?.cancel();
    _matchSubscription = null;
    if (profile != null) {
      await _matchmaking.cancel(
        profile.publicId,
        expectedToken: _activeSearchToken,
      );
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      _matchedOpponent = null;
      _activeSearchToken = null;
    });
  }

  Future<void> _showMatchedPlayerThenOpen(
    String gameId,
    String opponentId,
  ) async {
    if (_preparingMatch || _openingGame || !mounted) return;
    _preparingMatch = true;
    final profile = _profile;
    if (profile == null ||
        !await BlockRoomService(
          _db,
        ).canEnterRoom(playerId: profile.publicId, gameId: gameId)) {
      _preparingMatch = false;
      return;
    }
    final snapshot =
        await _db.collection('kapi_lobby_profiles').doc(opponentId).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final opponent = DominoPlayerProfile(
      initials: (data['initials'] as String? ?? 'P2').toUpperCase(),
      countryCode: (data['countryCode'] as String? ?? 'US').toUpperCase(),
      code: (data['code'] as String? ?? '111111').toUpperCase(),
      avatarKey: data['avatarKey'] as String? ?? 'person',
    );
    if (!mounted) return;
    setState(() {
      _matchedOpponent = opponent;
      _matchCountdown = 3;
    });
    for (var remaining = 1; remaining > 0; remaining--) {
      if (!mounted) return;
      setState(() => _matchCountdown = remaining);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    try {
      await _openOnlineGame(gameId);
    } finally {
      _preparingMatch = false;
      if (mounted) setState(() => _matchedOpponent = null);
    }
  }

  Future<void> _openOnlineGame(
    String gameId, {
    bool showTransition = true,
  }) async {
    if (_openingGame || !mounted) return;
    _openingGame = true;
    await _matchSubscription?.cancel();
    _matchSubscription = null;
    _activeSearchToken = null;
    setState(() => _searching = false);
    if (!await BlockRoomService(
      _db,
    ).canEnterRoom(playerId: _profile!.publicId, gameId: gameId)) {
      _openingGame = false;
      await _upsertPresence(_profile!);
      return;
    }
    final gameSnapshot =
        await _db.collection('kapi_online_games').doc(gameId).get();
    final gameData = gameSnapshot.data() ?? const <String, dynamic>{};
    final players = List<String>.from(gameData['players'] ?? const []);
    final myId = _profile!.publicId.toUpperCase();
    final opponentId = players.firstWhere(
      (id) => id.toUpperCase() != myId,
      orElse: () => '',
    );
    final opponentSnapshot =
        opponentId.isEmpty
            ? null
            : await _db.collection('kapi_lobby_profiles').doc(opponentId).get();
    final opponentData = opponentSnapshot?.data() ?? const <String, dynamic>{};
    final opponent = DominoPlayerProfile(
      initials: (opponentData['initials'] as String? ?? 'P2').toUpperCase(),
      countryCode:
          (opponentData['countryCode'] as String? ?? 'US').toUpperCase(),
      code: (opponentData['code'] as String? ?? '111111').toUpperCase(),
      avatarKey: opponentData['avatarKey'] as String? ?? 'person',
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/domino-online'),
        builder:
            (_) =>
                showTransition
                    ? MatchFoundTransitionScreen(
                      gameId: gameId,
                      player: _profile!,
                      playerPoints: _points,
                      opponent: opponent,
                      opponentPoints:
                          (opponentData['totalPoints'] as num?)?.toInt() ?? 0,
                    )
                    : DominoOnlineGameScreen(
                      gameId: gameId,
                      playerId: _profile!.publicId,
                    ),
      ),
    );
    _openingGame = false;
    await _upsertPresence(_profile!);
  }

  Future<void> _showIncomingInvite(
    QueryDocumentSnapshot<Map<String, dynamic>> invite,
  ) async {
    if (!mounted) return;
    final data = invite.data();
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isSpanish ? 'Invitacion para jugar' : 'Game invite'),
            content: Text(
              _isSpanish
                  ? '${data['fromInitials'] ?? 'Un amigo'} quiere jugar Block Dominoes contigo.'
                  : '${data['fromInitials'] ?? 'A friend'} wants to play Block Dominoes with you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_isSpanish ? 'Rechazar' : 'Decline'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_isSpanish ? 'Aceptar' : 'Accept'),
              ),
            ],
          ),
    );
    await invite.reference.set({
      'status': accepted == true ? 'accepted' : 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (accepted == true) {
      await _openOnlineGame(data['gameId'] as String);
    } else {
      await BlockRoomService(_db).leaveGame(
        playerId: data['fromId'] as String,
        gameId: data['gameId'] as String,
        reason: 'inviteDeclined',
      );
    }
  }

  Future<String?> _resolveCode(String raw) async {
    final code = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!RegExp(r'^[A-NP-Z1-9]{6}$').hasMatch(code)) {
      _showMessage(
        _isSpanish
            ? 'Escribe los 6 caracteres, sin cero ni letra O.'
            : 'Enter all 6 characters, without zero or the letter O.',
      );
      return null;
    }
    final doc = await _db.collection('kapi_lobby_codes').doc(code).get();
    return doc.data()?['publicId'] as String?;
  }

  Future<void> _inviteByCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isSpanish ? 'ID del jugador' : 'Player ID'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(hintText: 'TGHIDU'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(_isSpanish ? 'Invitar' : 'Invite'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (code == null) return;
    final playerId = await _resolveCode(code);
    if (playerId == null) {
      _showMessage(_isSpanish ? 'Jugador no encontrado.' : 'Player not found.');
      return;
    }
    await _invitePlayer(playerId);
  }

  Future<void> _invitePlayer(String playerId) async {
    final profile = _profile!;
    if (playerId.toUpperCase() == profile.publicId.toUpperCase()) return;
    final roomService = BlockRoomService(_db);
    if (await roomService.activeGameId(profile.publicId) != null) {
      _showMessage(
        _isSpanish
            ? 'Sal de tu sala actual antes de invitar a otra persona.'
            : 'Leave your current room before inviting another player.',
      );
      return;
    }
    if (await roomService.activeGameId(playerId) != null) {
      _showMessage(
        _isSpanish
            ? 'Ese jugador ya esta jugando en otra sala.'
            : 'That player is already playing in another room.',
      );
      return;
    }
    try {
      final playerDoc =
          await _db.collection('kapi_lobby_profiles').doc(playerId).get();
      final initials = playerDoc.data()?['initials'] as String? ?? 'P2';
      final gameId = await OnlineGameFactory.createClassicGame(
        db: _db,
        host: profile,
        guestId: playerId,
        guestInitials: initials,
      );
      await _db.collection('kapi_game_invites').add({
        'fromId': profile.publicId.toUpperCase(),
        'toId': playerId.toUpperCase(),
        'mode': 'block',
        'status': 'pending',
        'gameId': gameId,
        'fromInitials': profile.initials,
        'toInitials': initials,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage(_isSpanish ? 'Invitacion enviada.' : 'Invite sent.');
      await _openOnlineGame(gameId);
    } on StateError {
      _showMessage(
        _isSpanish
            ? 'No se pudo crear la sala. Uno de los jugadores ya esta jugando.'
            : 'The room could not be created. One player is already in a game.',
      );
    }
  }

  Future<void> _openFriends() async {
    final friend = await Navigator.push<SimpleLobbyFriend>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/simple-friends'),
        builder: (_) => SimpleFriendsScreen(profile: _profile!),
      ),
    );
    if (friend != null) await _invitePlayer(friend.publicId);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _countryLabel(String code) => code == 'US' ? 'USA' : code;

  Future<void> _showInviteChoices(DominoPlayerProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isSpanish ? 'Invitar amigo' : 'Invite a friend',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SheetAction(
                    icon: Icons.groups_rounded,
                    title:
                        _isSpanish
                            ? 'Ver amigos online y desconectados'
                            : 'View online and offline friends',
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_openFriends());
                    },
                  ),
                  const SizedBox(height: 10),
                  _SheetAction(
                    icon: Icons.tag_rounded,
                    title:
                        _isSpanish
                            ? 'Entrar ID de 6 caracteres'
                            : 'Enter 6-character ID',
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_inviteByCode());
                    },
                  ),
                  const SizedBox(height: 10),
                  _SheetAction(
                    icon: Icons.ios_share_rounded,
                    title: _isSpanish ? 'Compartir mi ID' : 'Share my ID',
                    onTap: () async {
                      Navigator.pop(context);
                      await Share.share(
                        _isSpanish
                            ? 'Juega Block Dominoes conmigo en Kapi Note. Mi ID es ${profile.code.toUpperCase()}.'
                            : 'Play Block Dominoes with me in Kapi Note. My ID is ${profile.code.toUpperCase()}.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF241719).withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: const Color(0xFFFFD36B).withValues(alpha: 0.34),
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 11)),
      ],
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({
    required this.icon,
    required this.initials,
    required this.subtitle,
    required this.color,
    required this.borderColor,
    this.avatarKey,
    this.avatarText,
  });

  final IconData icon;
  final String initials;
  final String subtitle;
  final Color color;
  final Color borderColor;
  final String? avatarKey;
  final String? avatarText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child:
              avatarKey != null
                  ? DominoAvatarVisual(
                    avatarKey: avatarKey!,
                    fallbackIcon: icon,
                    backgroundColor: color,
                  )
                  : avatarText == null
                  ? Icon(icon, color: Colors.white, size: 32)
                  : Center(
                    child: Text(
                      avatarText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
        ),
        const SizedBox(height: 8),
        Text(
          initials,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: const TextScaler.linear(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: const TextScaler.linear(1),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LobbyVsMark extends StatelessWidget {
  const _LobbyVsMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.14,
      child: Text(
        'VS',
        style: TextStyle(
          color: const Color(0xFFFFE0A3),
          fontSize: compact ? 26 : 32,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -3,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(1, 3)),
          ],
        ),
      ),
    );
  }
}

class _LobbyChoiceButton extends StatelessWidget {
  const _LobbyChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final background =
        primary
            ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6DCD7F), Color(0xFF2B8849)],
            )
            : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF777279), Color(0xFF4E4A50)],
            );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 60 : 76),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            gradient: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  primary
                      ? const Color(0xFFD9FFE1).withValues(alpha: 0.74)
                      : Colors.white.withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: compact ? 25 : 30),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: const TextScaler.linear(1),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      textScaler: const TextScaler.linear(1),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
