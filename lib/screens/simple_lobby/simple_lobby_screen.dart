import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/block_matchmaking_service.dart';
import '../../services/block_room_service.dart';
import '../../services/domino_match_mode.dart';
import '../../services/online_version_service.dart';
import '../../widgets/anchored_adaptive_banner_ad.dart';
import '../admob_variable.dart';
import '../domino_online_game_screen.dart';
import '../domino_player_profile.dart';
import 'match_found_transition_screen.dart';
import 'simple_friends_screen.dart';

class SimpleLobbyScreen extends StatefulWidget {
  const SimpleLobbyScreen({super.key, this.mode = DominoMatchMode.block});

  final DominoMatchMode mode;

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
  int _matchedOpponentPoints = 0;
  int _matchCountdown = 3;
  int _searchSecondsRemaining =
      BlockMatchmakingService.quickSearchDuration.inSeconds;
  Timer? _presenceTimer;
  Timer? _searchCountdownTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _matchSubscription;
  String? _activeSearchToken;

  late final BlockMatchmakingService _matchmaking;

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';
  bool get _isDrawPool => widget.mode == DominoMatchMode.drawPool;
  String get _modeTitle => _isDrawPool ? 'Draw / Pool' : 'Block Dominoes';
  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  void initState() {
    super.initState();
    _matchmaking = BlockMatchmakingService(_db, mode: widget.mode);
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _searchCountdownTimer?.cancel();
    unawaited(_matchSubscription?.cancel());
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
        'displayName': profile.effectiveDisplayName,
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
          '$_modeTitle · 1 vs 1',
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
    final opponentTier = DominoTierVisual.fromScore(_matchedOpponentPoints);
    return Container(
      padding: EdgeInsets.all(compact ? 11 : 16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _PlayerSlot(
              icon: profile.icon,
              avatarKey: profile.avatarKey,
              initials: profile.effectiveDisplayName,
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
                      : opponent.effectiveDisplayName,
              subtitle:
                  opponent == null
                      ? (_isSpanish ? 'Sin elegir' : 'Not selected')
                      : '${_countryLabel(opponent.countryCode)} · ${opponentTier.label}',
              color: opponent?.color ?? const Color(0xFF21181B),
              borderColor:
                  opponent == null ? Colors.white24 : opponentTier.frameColor(),
              onTap: opponent == null ? _openFriends : null,
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
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFFFFD36B),
                  strokeWidth: 5,
                ),
                if (_matchedOpponent == null)
                  Text(
                    '$_searchSecondsRemaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else
                  const Icon(
                    Icons.check_rounded,
                    color: Color(0xFFFFD36B),
                    size: 26,
                  ),
              ],
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
                    ? 'Si nadie aparece, completaremos la mesa en $_searchSecondsRemaining s.'
                    : 'If nobody joins, the table completes in $_searchSecondsRemaining s.')
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
    if (!await _ensureOnlineVersion()) return;
    final profile = _profile;
    if (profile == null || _searching) return;
    final searchToken = BlockMatchmakingService.createSearchToken(
      profile.publicId,
    );
    setState(() {
      _searching = true;
      _activeSearchToken = searchToken;
      _matchedOpponent = null;
      _matchedOpponentPoints = 0;
      _searchSecondsRemaining =
          BlockMatchmakingService.quickSearchDuration.inSeconds;
    });
    _searchCountdownTimer?.cancel();
    _searchCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_searching || _matchedOpponent != null) {
        timer.cancel();
        return;
      }
      setState(() {
        _searchSecondsRemaining = max(0, _searchSecondsRemaining - 1);
      });
      if (_searchSecondsRemaining == 0) timer.cancel();
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
      if (!mounted || !_searching || _activeSearchToken != searchToken) {
        return;
      }
      final committedGameId = await _reconcileCommittedMatch(
        profile.publicId,
        searchToken,
      );
      if (!mounted || !_searching || _activeSearchToken != searchToken) {
        return;
      }
      if (committedGameId != null) {
        await _openOnlineGame(committedGameId);
        return;
      }
      await _matchSubscription?.cancel();
      _matchSubscription = null;
      await _matchmaking.cancel(profile.publicId, expectedToken: searchToken);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _activeSearchToken = null;
      });
      _searchCountdownTimer?.cancel();
      final busyError =
          error is StateError &&
          error.toString().toLowerCase().contains('already');
      _showMessage(
        busyError
            ? (_isSpanish
                ? 'Ya estas jugando en una sala. Sal de esa sala antes de buscar otra partida.'
                : 'You are already in a room. Leave it before searching for another match.')
            : (_isSpanish
                ? 'No pudimos completar la búsqueda. Revisa tu conexión e inténtalo de nuevo.'
                : 'We could not complete the search. Check your connection and try again.'),
      );
    }
  }

  Future<void> _cancelMatchmaking() async {
    final profile = _profile;
    final expectedToken = _activeSearchToken;
    if (mounted) {
      setState(() {
        _searching = false;
        _matchedOpponent = null;
        _matchedOpponentPoints = 0;
        _activeSearchToken = null;
      });
    }
    _searchCountdownTimer?.cancel();
    await _matchSubscription?.cancel();
    _matchSubscription = null;
    if (profile != null) {
      await _matchmaking.cancel(profile.publicId, expectedToken: expectedToken);
    }
  }

  Future<String?> _reconcileCommittedMatch(
    String playerId,
    String searchToken,
  ) async {
    final cleanPlayerId = playerId.toUpperCase();
    try {
      final snapshots = await Future.wait([
        _db
            .collection(BlockRoomService.sessionsCollection)
            .doc(cleanPlayerId)
            .get(const GetOptions(source: Source.server)),
        _db
            .collection('kapi_block_matchmaking')
            .doc(cleanPlayerId)
            .get(const GetOptions(source: Source.server)),
      ]);
      final session = snapshots[0].data();
      final queue = snapshots[1].data();
      final possibleGameIds = <String>{
        if (session?['activeGameId'] is String)
          session!['activeGameId'] as String,
        if (queue?['searchToken'] == searchToken && queue?['gameId'] is String)
          queue!['gameId'] as String,
      }..removeWhere((id) => id.isEmpty);
      for (final gameId in possibleGameIds) {
        if (!BlockRoomService.ownsRoom(session, gameId)) continue;
        final gameSnapshot = await _db
            .collection('kapi_online_games')
            .doc(gameId)
            .get(const GetOptions(source: Source.server));
        final game = gameSnapshot.data();
        final players =
            (game?['players'] as List<dynamic>? ?? const [])
                .map((id) => id.toString().toUpperCase())
                .toSet();
        final status = game?['status'] as String? ?? '';
        if (players.contains(cleanPlayerId) &&
            status != 'abandoned' &&
            status != 'matchOver') {
          return gameId;
        }
      }
    } catch (_) {
      // A failed reconciliation is handled by the normal transient-error path.
    }
    return null;
  }

  Future<void> _showMatchedPlayerThenOpen(
    String gameId,
    String opponentId,
  ) async {
    if (_preparingMatch || _openingGame || !mounted) return;
    _preparingMatch = true;
    _searchCountdownTimer?.cancel();
    final profile = _profile;
    if (profile == null ||
        !await BlockRoomService(
          _db,
        ).canEnterRoom(playerId: profile.publicId, gameId: gameId)) {
      _preparingMatch = false;
      return;
    }
    final opponentData = await _loadOpponentProfile(gameId, opponentId);
    if (!mounted) return;
    setState(() {
      _matchedOpponent = opponentData.profile;
      _matchedOpponentPoints = opponentData.points;
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
      if (mounted) {
        setState(() {
          _matchedOpponent = null;
          _matchedOpponentPoints = 0;
        });
      }
    }
  }

  Future<void> _openOnlineGame(
    String gameId, {
    bool showTransition = true,
  }) async {
    if (_openingGame || !mounted) return;
    _openingGame = true;
    _searchCountdownTimer?.cancel();
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
    final resolvedOpponent =
        opponentId.isEmpty
            ? (
              profile: const DominoPlayerProfile(
                initials: 'P2',
                countryCode: 'US',
                code: '111111',
                avatarKey: 'person',
              ),
              points: 0,
            )
            : await _loadOpponentProfile(
              gameId,
              opponentId,
              gameData: gameData,
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
                      opponent: resolvedOpponent.profile,
                      opponentPoints: resolvedOpponent.points,
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

  Future<({DominoPlayerProfile profile, int points})> _loadOpponentProfile(
    String gameId,
    String opponentId, {
    Map<String, dynamic>? gameData,
  }) async {
    final cleanOpponentId = opponentId.toUpperCase();
    final resolvedGameData =
        gameData ??
        (await _db.collection('kapi_online_games').doc(gameId).get()).data() ??
        const <String, dynamic>{};
    final profiles = Map<String, dynamic>.from(
      resolvedGameData['profiles'] as Map? ?? const <String, dynamic>{},
    );
    final embedded = Map<String, dynamic>.from(
      profiles[cleanOpponentId] as Map? ?? const <String, dynamic>{},
    );
    final lobbySnapshot =
        embedded.isEmpty
            ? await _db
                .collection('kapi_lobby_profiles')
                .doc(cleanOpponentId)
                .get()
            : null;
    final data =
        embedded.isNotEmpty
            ? embedded
            : lobbySnapshot?.data() ?? const <String, dynamic>{};
    return (
      profile: DominoPlayerProfile(
        initials: (data['initials'] as String? ?? 'P2').toUpperCase(),
        displayName: data['displayName'] as String? ?? '',
        countryCode: (data['countryCode'] as String? ?? 'US').toUpperCase(),
        code: (data['code'] as String? ?? '111111').toUpperCase(),
        avatarKey: data['avatarKey'] as String? ?? 'person',
      ),
      points: (data['totalPoints'] as num?)?.toInt() ?? 0,
    );
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
    var playerCode = '';
    final code = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF101C29),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: Color(0xFFFFD36B), width: 1.4),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            title: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5AB7FF).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF5AB7FF)),
                  ),
                  child: const Icon(
                    Icons.tag_rounded,
                    color: Color(0xFF5AB7FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isSpanish ? 'ID del jugador' : 'Player ID',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSpanish
                      ? 'Escribe el código de 6 caracteres de tu amigo.'
                      : "Enter your friend's 6-character code.",
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                ),
                const SizedBox(height: 14),
                TextField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'A1B2C3',
                    hintStyle: const TextStyle(color: Colors.white30),
                    counterStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF071524),
                    prefixIcon: const Icon(
                      Icons.tag_rounded,
                      color: Color(0xFFFFD36B),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF5AB7FF),
                        width: 1.8,
                      ),
                    ),
                  ),
                  onChanged: (value) => playerCode = value,
                  onSubmitted: (value) => Navigator.pop(context, value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, playerCode),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2EB872),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(_isSpanish ? 'Invitar' : 'Invite'),
              ),
            ],
          ),
    );
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
      final displayName =
          playerDoc.data()?['displayName'] as String? ?? initials;
      final inviteRef = _db.collection('kapi_game_invites').doc();
      await inviteRef.set({
        'gameType': widget.mode.storageValue,
        'fromId': profile.publicId.toUpperCase(),
        'toId': playerId.toUpperCase(),
        'mode': widget.mode.storageValue,
        'status': 'pending',
        'fromInitials': profile.initials,
        'fromDisplayName': profile.effectiveDisplayName,
        'toInitials': initials,
        'toDisplayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage(_isSpanish ? 'Invitacion enviada.' : 'Invite sent.');
      final gameId = await _waitForInviteResponse(inviteRef);
      if (gameId != null && mounted) await _openOnlineGame(gameId);
    } on StateError {
      _showMessage(
        _isSpanish
            ? 'No se pudo crear la sala. Uno de los jugadores ya esta jugando.'
            : 'The room could not be created. One player is already in a game.',
      );
    }
  }

  Future<String?> _waitForInviteResponse(
    DocumentReference<Map<String, dynamic>> inviteRef,
  ) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (
            dialogContext,
          ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: inviteRef.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final status = data['status'] as String? ?? 'pending';
              final gameId = data['gameId'] as String? ?? '';
              if (status == 'accepted' && gameId.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.pop(dialogContext, gameId);
                  }
                });
              } else if (status == 'declined' ||
                  status == 'cancelled' ||
                  status == 'roomFull' ||
                  status == 'failed') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.pop(dialogContext);
                  }
                  if (mounted) {
                    _showMessage(
                      status == 'declined'
                          ? (_isSpanish
                              ? 'El jugador rechazó la invitación.'
                              : 'The player declined the invitation.')
                          : (_isSpanish
                              ? 'La invitación ya no está disponible.'
                              : 'The invitation is no longer available.'),
                    );
                  }
                });
              }
              return AlertDialog(
                backgroundColor: const Color(0xFF101C29),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                  side: const BorderSide(color: Color(0xFFFFD36B), width: 1.4),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        color: Color(0xFF45D483),
                        strokeWidth: 5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isSpanish
                          ? 'Esperando que el jugador acepte'
                          : 'Waiting for the player to accept',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSpanish
                          ? 'La partida comenzará solamente después de aceptar la invitación.'
                          : 'The game will start only after the invitation is accepted.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton.icon(
                    onPressed: () async {
                      await inviteRef.update({
                        'status': 'cancelled',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
                  ),
                ],
              );
            },
          ),
    );
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
    if (!await _ensureOnlineVersion()) return;
    if (!mounted) return;
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
                            ? 'Juega $_modeTitle conmigo en Kapi Note. Mi ID es ${profile.code.toUpperCase()}.'
                            : 'Play $_modeTitle with me in Kapi Note. My ID is ${profile.code.toUpperCase()}.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<bool> _ensureOnlineVersion() async {
    final status = await OnlineVersionService.instance.check(refresh: true);
    if (!mounted) return false;
    if (!status.requiresUpdate) return true;
    await showOnlineVersionDialog(context, status, allowOffline: false);
    return false;
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
    this.onTap,
  });

  final IconData icon;
  final String initials;
  final String subtitle;
  final Color color;
  final Color borderColor;
  final String? avatarKey;
  final String? avatarText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
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
          ),
        ),
      ),
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
