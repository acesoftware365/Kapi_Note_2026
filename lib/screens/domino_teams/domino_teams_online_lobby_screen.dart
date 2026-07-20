import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/audio_assets.dart';
import '../../services/audio_manager.dart';
import '../../services/teams_online_service.dart';
import '../../widgets/anchored_adaptive_banner_ad.dart';
import '../admob_variable.dart';
import '../domino_player_profile.dart';
import 'domino_teams_cpu_screen.dart';

class DominoTeamsOnlineLobbyScreen extends StatefulWidget {
  const DominoTeamsOnlineLobbyScreen({super.key});

  @override
  State<DominoTeamsOnlineLobbyScreen> createState() =>
      _DominoTeamsOnlineLobbyScreenState();
}

class _DominoTeamsOnlineLobbyScreenState
    extends State<DominoTeamsOnlineLobbyScreen> {
  static const bool _autoSearchForTesting = bool.fromEnvironment(
    'KAPI_AUTO_SEARCH_ONLINE',
  );

  late final TeamsOnlineService _service;
  StreamSubscription<TeamsOnlineLobby>? _subscription;
  Timer? _ticker;
  DominoPlayerProfile? _profile;
  TeamsOnlineLobby? _lobby;
  String? _gameId;
  String? _error;
  int _playerPoints = 0;
  bool _loadingProfile = true;
  bool _joining = false;
  bool _cancelJoinRequested = false;
  bool _finalizing = false;
  bool _openingGame = false;
  bool _allowPop = false;
  int _lastPlayerCount = 0;

  bool get _isSpanish =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'es';
  bool get _isSearching => _gameId != null;
  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  void initState() {
    super.initState();
    _service = TeamsOnlineService(FirebaseFirestore.instance);
    unawaited(AudioManager.instance.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await DominoPlayerProfile.load();
      final prefs = await SharedPreferences.getInstance();
      final points =
          prefs.getInt(
            'kapi_player_points_${profile.code.toUpperCase()}_total',
          ) ??
          0;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _playerPoints = points;
        _loadingProfile = false;
      });
      if (_autoSearchForTesting) unawaited(_join());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _join() async {
    final profile = _profile;
    if (_joining || _isSearching || profile == null) return;
    setState(() {
      _joining = true;
      _cancelJoinRequested = false;
      _error = null;
    });
    try {
      final gameId = await _service.joinQuickMatch(
        profile: profile,
        points: _playerPoints,
      );
      if (_cancelJoinRequested || !mounted) {
        await _service.cancelWaiting(
          gameId: gameId,
          playerId: profile.publicId,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _gameId = gameId;
        _joining = false;
      });
      _subscription = _service
          .watchLobby(gameId)
          .listen(
            _onLobby,
            onError: (Object error) {
              if (mounted) {
                setState(() => _error = error.toString());
              }
            },
          );
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        final lobby = _lobby;
        if (lobby != null && lobby.secondsRemaining == 0) {
          unawaited(_tryFinalize());
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = error.toString();
        });
      }
    }
  }

  void _onLobby(TeamsOnlineLobby lobby) {
    if (!mounted) return;
    if (lobby.players.length > _lastPlayerCount && _lastPlayerCount > 0) {
      unawaited(AudioManager.instance.playSfx(AudioAssets.playerJoined));
    }
    _lastPlayerCount = lobby.players.length;
    setState(() => _lobby = lobby);
    if (lobby.status == 'playing' || lobby.status == 'matchOver') {
      unawaited(_openGame());
      return;
    }
    if (lobby.players.length >= 4 || lobby.secondsRemaining == 0) {
      unawaited(_tryFinalize());
    }
  }

  Future<void> _tryFinalize() async {
    final gameId = _gameId;
    if (_finalizing || gameId == null || _openingGame) return;
    _finalizing = true;
    try {
      await _service.finalizeLobby(gameId);
    } finally {
      _finalizing = false;
    }
  }

  Future<void> _openGame() async {
    final gameId = _gameId;
    final profile = _profile;
    if (_openingGame || gameId == null || profile == null) return;
    _openingGame = true;
    _ticker?.cancel();
    await AudioManager.instance.playSfx(AudioAssets.gameStart);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/domino-teams-online'),
        builder:
            (_) => DominoTeamsCpuScreen(
              onlineGameId: gameId,
              onlinePlayerId: profile.publicId,
            ),
      ),
    );
  }

  Future<void> _leaveRoom({required bool closeScreen}) async {
    final gameId = _gameId;
    final profile = _profile;
    if (_joining && gameId == null) _cancelJoinRequested = true;
    _ticker?.cancel();
    _ticker = null;
    await _subscription?.cancel();
    _subscription = null;
    if (gameId != null && profile != null && !_openingGame) {
      try {
        await _service.cancelWaiting(
          gameId: gameId,
          playerId: profile.publicId,
        );
      } on FirebaseException {
        // Leaving the UI must remain possible during a temporary sync issue.
      }
    }
    if (!mounted) return;
    if (closeScreen) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
      return;
    }
    setState(() {
      _gameId = null;
      _lobby = null;
      _error = null;
      _joining = false;
      _finalizing = false;
      _lastPlayerCount = 0;
    });
  }

  Future<void> _cancel() => _leaveRoom(closeScreen: true);

  void _openNotes() {
    Navigator.pushNamed(context, '/game', arguments: {'fromDominoGame': true});
  }

  void _playWithCpu() {
    Navigator.pushReplacementNamed(context, '/domino-teams-cpu');
  }

  @override
  Widget build(BuildContext context) {
    final lobby = _lobby;
    final players = lobby?.players ?? const <TeamsOnlinePlayer>[];
    final relativeSeats = TeamsOnlineRoster.relativeSeats(
      players: players,
      currentPlayerId: _profile?.publicId ?? '',
    );
    final seconds = lobby?.secondsRemaining ?? 30;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF061421),
        appBar: AppBar(
          backgroundColor: const Color(0xFF8B0808),
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: _cancel,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: _isSpanish ? 'Salir' : 'Exit',
          ),
          title: const Text(
            'Teams 2 vs 2',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _openNotes,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(
                  _isSpanish ? 'Apuntes' : 'Notes',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child:
                    _isSearching
                        ? _searchingBody(seconds, relativeSeats, players.length)
                        : _modeSelectionBody(),
              ),
              AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSelectionBody() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF172735), Color(0xFF0B1721)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD36B)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_2_rounded,
                color: Color(0xFFFFD36B),
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSpanish ? 'Elige el modo' : 'Choose a mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _isSpanish
                          ? 'Puedes jugar ahora con CPU o buscar jugadores.'
                          : 'Play with CPU now or search for players.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _modeCard(
          icon: Icons.smart_toy_rounded,
          color: const Color(0xFF29A36A),
          title: _isSpanish ? 'Jugar con CPU' : 'Play with CPU',
          subtitle:
              _isSpanish
                  ? 'Comienza inmediatamente con tres jugadores CPU.'
                  : 'Start immediately with three CPU players.',
          onTap: _playWithCpu,
        ),
        const SizedBox(height: 12),
        _modeCard(
          icon: Icons.public_rounded,
          color: const Color(0xFF1976D2),
          title: 'Online',
          subtitle:
              _isSpanish
                  ? 'Busca hasta 30 segundos; el CPU completa los puestos.'
                  : 'Search for 30 seconds; CPU fills empty seats.',
          selected: true,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed:
              _loadingProfile || _joining || _profile == null ? null : _join,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          icon:
              _joining || _loadingProfile
                  ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.search_rounded),
          label: Text(
            _joining
                ? (_isSpanish ? 'Entrando...' : 'Joining...')
                : (_isSpanish ? 'Buscar jugadores' : 'Find players'),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: Colors.white30),
          ),
          icon: const Icon(Icons.close_rounded),
          label: Text(_isSpanish ? 'Salir' : 'Exit'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _modeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool selected = false,
  }) => Material(
    color: color.withValues(alpha: selected ? 0.28 : 0.18),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: selected ? 2.2 : 1.3),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right,
              color: selected ? const Color(0xFF64B5F6) : Colors.white54,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _searchingBody(
    int seconds,
    List<TeamsOnlinePlayer?> players,
    int playerCount,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
    child: Column(
      children: [
        _searchHeader(seconds, playerCount),
        const SizedBox(height: 14),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF0E6B50), Color(0xFF064231)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFFFFD36B),
                    width: 1.5,
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 70,
                right: 70,
                child: _seat(2, players),
              ),
              Positioned(
                left: 10,
                top: 124,
                width: 126,
                child: _seat(3, players),
              ),
              Positioned(
                right: 10,
                top: 124,
                width: 126,
                child: _seat(1, players),
              ),
              Positioned(
                bottom: 18,
                left: 70,
                right: 70,
                child: _seat(0, players),
              ),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.groups_2_rounded,
                      color: Color(0xFFFFD36B),
                      size: 38,
                    ),
                    Text(
                      '$playerCount/4',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _error ??
              (_isSpanish
                  ? 'Si faltan jugadores, el CPU ocupa sus puestos.'
                  : 'CPU players fill every empty seat.'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _error == null ? Colors.white70 : Colors.redAccent,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _leaveRoom(closeScreen: false),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF6B6B),
            minimumSize: const Size.fromHeight(46),
            side: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: Text(_isSpanish ? 'Salir de la sala' : 'Leave the room'),
        ),
      ],
    ),
  );

  Widget _searchHeader(int seconds, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF111E2A),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF64B5F6)),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF64B5F6),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count >= 4
                    ? (_isSpanish ? '¡Equipo completo!' : 'Full table!')
                    : (_isSpanish
                        ? 'Buscando jugadores...'
                        : 'Finding players...'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _isSpanish
                    ? 'La partida comienza automáticamente'
                    : 'The match starts automatically',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withValues(alpha: 0.45),
                blurRadius: 14,
              ),
            ],
          ),
          child: Text(
            '$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _seat(int index, List<TeamsOnlinePlayer?> players) {
    final player = index < players.length ? players[index] : null;
    final labels = [
      _isSpanish ? 'Tú' : 'You',
      _isSpanish ? 'Rival derecho' : 'Right rival',
      _isSpanish ? 'Compañero' : 'Partner',
      _isSpanish ? 'Rival izquierdo' : 'Left rival',
    ];
    final color =
        index.isEven ? const Color(0xFF64B5F6) : const Color(0xFFFF6B6B);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:
            player == null
                ? Colors.black.withValues(alpha: 0.24)
                : color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: player == null ? Colors.white24 : color,
          width: player == null ? 1 : 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                player == null ? Colors.white12 : color.withValues(alpha: 0.28),
            child:
                player == null
                    ? const Icon(
                      Icons.person_search_rounded,
                      color: Colors.white38,
                      size: 23,
                    )
                    : player.isCpu
                    ? const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 23,
                    )
                    : ClipOval(
                      child: SizedBox.expand(
                        child: DominoAvatarVisual(
                          avatarKey: player.avatarKey,
                          fallbackIcon: _avatarIcon(player.avatarKey),
                          backgroundColor: color.withValues(alpha: .28),
                        ),
                      ),
                    ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  player == null
                      ? (_isSpanish ? 'Buscando...' : 'Searching...')
                      : '${_badgeEmoji(player.badgeKey)}${player.initials}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: player == null ? Colors.white38 : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (player != null)
                  Text(
                    '${player.points} pts',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _avatarIcon(String key) => switch (key) {
    'woman' => Icons.face_3_rounded,
    'robot' => Icons.smart_toy_rounded,
    'rainbow' => Icons.auto_awesome_rounded,
    'game' => Icons.sports_esports_rounded,
    'star' => Icons.star_rounded,
    'android_emerald' => Icons.android_rounded,
    _ => Icons.person_rounded,
  };

  String _badgeEmoji(String key) => switch (key) {
    'flag_do' => '🇩🇴 ',
    'flag_us' => '🇺🇸 ',
    'flag_pr' => '🇵🇷 ',
    'flag_mx' => '🇲🇽 ',
    'flag_co' => '🇨🇴 ',
    'flag_ve' => '🇻🇪 ',
    'flag_cu' => '🇨🇺 ',
    'flag_es' => '🇪🇸 ',
    'flag_pa' => '🇵🇦 ',
    'flag_br' => '🇧🇷 ',
    'flag_jm' => '🇯🇲 ',
    'flag_ht' => '🇭🇹 ',
    'flag_in' => '🇮🇳 ',
    'flag_jp' => '🇯🇵 ',
    'flag_kr' => '🇰🇷 ',
    _ => '',
  };
}
