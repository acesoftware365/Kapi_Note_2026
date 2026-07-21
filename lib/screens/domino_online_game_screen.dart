import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/audio_assets.dart';
import '../constants/domino_game_config.dart';
import '../services/audio_manager.dart';
import '../services/block_room_service.dart';
import '../services/domino_display_settings.dart';
import '../services/kapi_cosmetics_service.dart';
import '../widgets/adaptive_domino_hand_tray.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import '../widgets/game_audio_controls.dart';
import '../widgets/domino_result_celebration.dart';
import '../widgets/kapi_centerpiece_overlay.dart';
import 'admob_variable.dart';
import 'domino_player_profile.dart';
import 'simple_lobby/simple_friends_screen.dart';

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

class _DominoOnlineGameScreenState extends State<DominoOnlineGameScreen>
    with TickerProviderStateMixin {
  static const bool _autoPlayVerification = bool.fromEnvironment(
    'KAPI_AUTO_PLAY',
  );
  static const int _autoPlayMatchCount = int.fromEnvironment(
    'KAPI_AUTO_MATCH_COUNT',
    defaultValue: 1,
  );
  static const Color _redTop = Color(0xFF6D0907);
  static const Color _navyBottom = Color(0xFF071524);
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
  String? _audioGameId;
  int _lastAudioBoardLength = 0;
  String? _lastAudioTurnId;
  bool _lastAudioRoundOver = false;
  bool _leavingRoom = false;
  bool _allowPop = false;
  double _playedTileScale = 1.0;
  double _handTileScale = 1.0;
  late final AnimationController _celebrationController;
  late final AnimationController _sideChoicePulse;
  _DominoTile? _sideChoiceTile;
  String? _celebratedMatchId;
  Timer? _rematchTimer;
  bool _updatingRematch = false;
  bool _advancingRound = false;
  int _latestRenderedRevision = -1;
  _OnlineGame? _latestRenderedGame;
  int _automationScheduledRevision = -1;
  String? _automationHandledMatch;
  String? _recordedOnlineRoundKey;
  int _automationCompletedMatches = 0;

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

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
    KapiCosmeticsService.instance.addListener(_handleCosmeticsChanged);
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _sideChoicePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat(reverse: true);
    DominoDisplaySettings.playedTileScale.addListener(_handlePlayedTileScale);
    DominoDisplaySettings.handTileScale.addListener(_handleHandTileScale);
    _loadProfile();
    _loadPlayedTileScale();
    _loadHandTileScale();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AudioManager.instance.playMusic(AudioAssets.gameplayLoop));
    });
  }

  @override
  void dispose() {
    KapiCosmeticsService.instance.removeListener(_handleCosmeticsChanged);
    _rematchTimer?.cancel();
    _celebrationController.dispose();
    _sideChoicePulse.dispose();
    DominoDisplaySettings.playedTileScale.removeListener(
      _handlePlayedTileScale,
    );
    DominoDisplaySettings.handTileScale.removeListener(_handleHandTileScale);
    _onlineHandScrollController.dispose();
    unawaited(AudioManager.instance.stopMusic());
    super.dispose();
  }

  void _handleCosmeticsChanged() {
    if (mounted) setState(() {});
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

  Future<void> _openFriends() async {
    if (!_profileReady || !mounted) return;
    await Navigator.of(context).push<SimpleLobbyFriend>(
      MaterialPageRoute<SimpleLobbyFriend>(
        settings: const RouteSettings(name: '/simple-friends'),
        builder: (_) => SimpleFriendsScreen(profile: _profile),
      ),
    );
  }

  Future<void> _loadPlayedTileScale() async {
    final value = await DominoDisplaySettings.loadPlayedTileScale();
    if (mounted) setState(() => _playedTileScale = value);
  }

  void _handlePlayedTileScale() {
    if (mounted) {
      setState(() {
        _playedTileScale = DominoDisplaySettings.playedTileScale.value;
      });
    }
  }

  Future<void> _loadHandTileScale() async {
    final value = await DominoDisplaySettings.loadHandTileScale();
    if (mounted) setState(() => _handTileScale = value);
  }

  void _handleHandTileScale() {
    if (mounted) {
      setState(() {
        _handTileScale = DominoDisplaySettings.handTileScale.value;
      });
    }
  }

  Future<void> _playTile(_OnlineGame game, _DominoTile tile) async {
    final myPlayerId = _myPlayerId(game);
    if (!game.isMyTurn(myPlayerId) || game.roundOver) return;
    final sides = game.validSides(tile);
    if (sides.isEmpty) {
      await AudioManager.instance.playSfx(AudioAssets.invalidMove);
      _showMessage(_isSpanish ? 'Ficha invalida' : 'Invalid tile');
      return;
    }
    var side =
        sides.contains(_BoardSide.right) ? _BoardSide.right : sides.first;
    if (sides.length > 1 && game.leftOpen != game.rightOpen) {
      setState(() => _sideChoiceTile = tile);
      await AudioManager.instance.playSfx(AudioAssets.buttonTap);
      return;
    }
    if (!sides.contains(side)) return;

    await AudioManager.instance.playMusic(AudioAssets.gameplayLoop);
    await _commitTile(tile, side);
  }

  Future<void> _playSelectedTileOnSide(
    _OnlineGame game,
    _BoardSide side,
  ) async {
    final tile = _sideChoiceTile;
    if (tile == null || !game.validSides(tile).contains(side)) return;
    setState(() => _sideChoiceTile = null);
    await AudioManager.instance.playMusic(AudioAssets.gameplayLoop);
    await _commitTile(tile, side);
  }

  Future<void> _commitTile(_DominoTile tile, _BoardSide side) async {
    await _runOnlineAction('play ${tile.label}', () async {
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
    });
  }

  Future<bool> _runOnlineAction(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } catch (error, stackTrace) {
      debugPrint('[KAPI_ONLINE_ERROR] $label: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && !_autoPlayVerification) {
        _showMessage(
          _isSpanish
              ? 'No se pudo completar la accion. Intenta de nuevo.'
              : 'The action could not be completed. Please try again.',
        );
      }
      return false;
    }
  }

  void _scheduleVerificationMove(_OnlineGame game, String myPlayerId) {
    if (!_autoPlayVerification ||
        game.revision == _automationScheduledRevision) {
      return;
    }
    _automationScheduledRevision = game.revision;

    if (game.matchOver) {
      final matchKey = '${game.id}:${game.roundNumber}:${game.revision}';
      if (_automationHandledMatch == matchKey) return;
      _automationHandledMatch = matchKey;
      _automationCompletedMatches++;
      debugPrint(
        '[KAPI_AUTOMATION] match ${game.id} completed '
        '$_automationCompletedMatches/$_autoPlayMatchCount '
        'winner=${game.winnerId} revision=${game.revision}',
      );
      if (_automationCompletedMatches < _autoPlayMatchCount) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) unawaited(_requestRematch(game));
        });
      }
      return;
    }

    if (game.roundOver) {
      if (game.winnerId != myPlayerId) return;
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) unawaited(_startNextRound(game));
      });
      return;
    }
    if (!game.isMyTurn(myPlayerId)) return;

    final hand = game.handFor(myPlayerId);
    _DominoTile? playable;
    List<_BoardSide> sides = const [];
    for (final tile in hand) {
      final candidateSides = game.validSides(tile);
      if (candidateSides.isNotEmpty) {
        playable = tile;
        sides = candidateSides;
        break;
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (playable == null) {
        debugPrint(
          '[KAPI_AUTOMATION] ${game.initialsFor(myPlayerId)} passes '
          'revision=${game.revision}',
        );
        unawaited(_pass(game));
        return;
      }
      final side =
          sides.contains(_BoardSide.right) ? _BoardSide.right : sides.first;
      debugPrint(
        '[KAPI_AUTOMATION] ${game.initialsFor(myPlayerId)} plays '
        '${playable.label} ${side.name} revision=${game.revision}',
      );
      unawaited(_commitTile(playable, side));
    });
  }

  Future<void> _pass(_OnlineGame game) async {
    final myPlayerId = _myPlayerId(game);
    if (!game.isMyTurn(myPlayerId) ||
        game.roundOver ||
        game.hasMove(myPlayerId)) {
      return;
    }
    await AudioManager.instance.playSfx(AudioAssets.buttonTap);
    await _runOnlineAction('pass', () async {
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
    });
  }

  Future<void> _startNextRound(_OnlineGame game) async {
    if (!game.roundOver || game.matchOver || _advancingRound) return;
    _advancingRound = true;
    await AudioManager.instance.playSfx(AudioAssets.gameStart);
    await _runOnlineAction('start next round', () async {
      await _db.runTransaction((transaction) async {
        final ref = _db.collection('kapi_online_games').doc(widget.gameId);
        final snapshot = await transaction.get(ref);
        final fresh = _OnlineGame.fromSnapshot(snapshot);
        if (!fresh.roundOver || fresh.matchOver) return;
        transaction.set(
          ref,
          fresh.startNextRound().toMap(),
          SetOptions(merge: true),
        );
      });
    });
    _advancingRound = false;
  }

  void _handleGameAudio(_OnlineGame game, String myPlayerId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_audioGameId != game.id) {
        _audioGameId = game.id;
        _lastAudioBoardLength = game.board.length;
        _lastAudioTurnId = game.turnId;
        _lastAudioRoundOver = game.roundOver;
        AudioManager.instance.playSfx(AudioAssets.playerJoined);
        return;
      }
      if (game.board.length > _lastAudioBoardLength) {
        final sound =
            game.lastPlayedTile?.isDouble == true
                ? AudioAssets.dominoDouble
                : AudioAssets.dominoPlace;
        AudioManager.instance.playSfx(sound);
      }
      if (game.turnId != _lastAudioTurnId && game.turnId == myPlayerId) {
        AudioManager.instance.playSfx(AudioAssets.turnNotification);
      }
      if (game.roundOver && !_lastAudioRoundOver) {
        if (game.matchOver) {
          AudioManager.instance.playSfx(AudioAssets.gameOver);
          AudioManager.instance.playMusic(
            game.winnerId == myPlayerId
                ? AudioAssets.victoryMusic
                : AudioAssets.defeatMusic,
            loop: false,
          );
        } else {
          AudioManager.instance.playSfx(AudioAssets.roundWin);
        }
      }
      _lastAudioBoardLength = game.board.length;
      _lastAudioTurnId = game.turnId;
      _lastAudioRoundOver = game.roundOver;
    });
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

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmLeaveRoom());
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_redTop, _navyBottom],
            ),
          ),
          child: SafeArea(
            bottom: false,
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
                final data = snapshot.data!.data()!;
                final incomingGame = _OnlineGame.fromSnapshot(snapshot.data!);
                final game = _stableGame(incomingGame);
                if (data['status'] == 'abandoned') {
                  return _buildAbandonedGame(data, game);
                }
                if (data['rematchClosed'] == true) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_leavingRoom) {
                      unawaited(_finishMatch(game));
                    }
                  });
                }
                return _buildGame(game);
              },
            ),
          ),
        ),
      ),
    );
  }

  _OnlineGame _stableGame(_OnlineGame incoming) {
    final cached = _latestRenderedGame;
    if (cached == null ||
        cached.id != incoming.id ||
        incoming.revision >= _latestRenderedRevision) {
      _latestRenderedRevision = incoming.revision;
      _latestRenderedGame = incoming;
      return incoming;
    }
    return cached;
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildTopBar(canResumeGame: false),
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
    if (!game.matchOver) {
      _rematchTimer?.cancel();
      _rematchTimer = null;
      _updatingRematch = false;
    }
    final myPlayerId = _myPlayerId(game);
    final myHand = game.handFor(myPlayerId);
    final otherId = game.otherPlayerId(myPlayerId);
    final otherHandCount = game.handFor(otherId).length;
    final tableStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.table,
    );
    final dominoStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.domino,
    );
    final myTurn = game.isMyTurn(myPlayerId);
    final canPass = myTurn && !game.hasMove(myPlayerId) && !game.roundOver;
    _handleGameAudio(game, myPlayerId);
    _recordOnlineRoundIfNeeded(game, myPlayerId);
    _startMatchCelebrationIfNeeded(game, myPlayerId);
    _scrollOnlineHandToPlayableStart(game, myPlayerId, myHand);
    _scheduleVerificationMove(game, myPlayerId);
    final status =
        game.roundOver
            ? game.message
            : game.message.toLowerCase().contains('passed')
            ? game.message
            : myTurn
            ? (_isSpanish ? 'Tu turno' : 'Your turn')
            : (_isSpanish ? 'Esperando al amigo...' : 'Waiting for friend...');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          _buildTopBar(canResumeGame: true),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: tableStyle.primary,
                image:
                    tableStyle.previewAsset == null
                        ? null
                        : DecorationImage(
                          image: AssetImage(tableStyle.previewAsset!),
                          fit: BoxFit.cover,
                          opacity: .62,
                          onError: (_, _) {},
                        ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tableStyle.secondary.withValues(alpha: .72),
                ),
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
                  final baseHandHeight = tight ? 72.0 : (compact ? 78.0 : 90.0);
                  final handHeight = baseHandHeight * _handTileScale;
                  final statusBottom = handHeight + (tight ? 10 : 16);
                  return Stack(
                    children: [
                      const Positioned.fill(child: KapiCenterpieceOverlay()),
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
                                  avatarKey: _profile.avatarKey,
                                  label: _isSpanish ? 'Tu' : 'You',
                                  countryCode: game.countryCodeFor(myPlayerId),
                                  rankingPoints: game.rankingPointsFor(
                                    myPlayerId,
                                  ),
                                  gameScore: game.scoreFor(myPlayerId),
                                  targetScore: game.targetScore,
                                  active: myTurn,
                                  compact: compact,
                                ),
                              ),
                            ),
                            _buildRoundBadge(game, compact: compact),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildProfileCard(
                                  avatarKey: game.avatarKeyFor(otherId),
                                  label: _isSpanish ? 'Rival' : 'Opponent',
                                  countryCode: game.countryCodeFor(otherId),
                                  rankingPoints: game.rankingPointsFor(otherId),
                                  gameScore: game.scoreFor(otherId),
                                  targetScore: game.targetScore,
                                  active: !myTurn && !game.roundOver,
                                  compact: compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: tight ? 62 : (compact ? 70 : 88),
                        right: tight ? 12 : 18,
                        child: _buildBacks(otherHandCount, compact: compact),
                      ),
                      Positioned.fill(
                        top: boardTop,
                        bottom: statusBottom + handHeight + 8,
                        child: _OnlineBoard(
                          board: game.board,
                          playedTileScale: _playedTileScale,
                          dominoColor: dominoStyle.primary,
                          pipColor: dominoStyle.secondary,
                          sideChoiceTile: _sideChoiceTile,
                          sideChoicePulse: _sideChoicePulse,
                          onSideSelected:
                              (side) => _playSelectedTileOnSide(game, side),
                        ),
                      ),
                      if (game.matchOver)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _celebrationController,
                              builder:
                                  (context, _) => CustomPaint(
                                    painter: _OnlineConfettiPainter(
                                      progress: _celebrationController.value,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      if (game.roundOver || game.matchOver)
                        Positioned.fill(
                          child: DominoResultCelebration(
                            showConfetti: game.matchOver,
                            child: _buildRoundResult(
                              game,
                              myPlayerId: myPlayerId,
                              otherPlayerId: otherId,
                            ),
                          ),
                        ),
                      if (!game.roundOver && !game.matchOver) ...[
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: statusBottom,
                          child: _buildStatusBar(
                            status,
                            game,
                            canPass: canPass,
                          ),
                        ),
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 10,
                          child: _buildHand(
                            myHand,
                            game,
                            myPlayerId,
                            handHeight,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnchoredAdaptiveBannerAd(
            adUnitId: _adUnitId,
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _recordOnlineRoundIfNeeded(_OnlineGame game, String myPlayerId) {
    if (!game.roundOver || game.winnerId.isEmpty) return;
    final rewardKey =
        'block-online-${game.id}-${game.roundNumber}-${game.revision}-$myPlayerId';
    if (_recordedOnlineRoundKey == rewardKey) return;
    _recordedOnlineRoundKey = rewardKey;
    if (game.winnerId == myPlayerId) {
      unawaited(
        KapiCosmeticsService.instance.claimVictory(rewardKey: rewardKey),
      );
    }
  }

  void _startMatchCelebrationIfNeeded(_OnlineGame game, String myPlayerId) {
    final celebrationId = '${game.id}:${game.roundNumber}';
    if (!game.matchOver || _celebratedMatchId == celebrationId) return;
    _celebratedMatchId = celebrationId;
    _celebrationController
      ..reset()
      ..repeat();
    unawaited(
      AudioManager.instance.playSfx(
        game.winnerId == myPlayerId
            ? AudioAssets.celebration
            : AudioAssets.gameOver,
      ),
    );
    Future<void>.delayed(const Duration(seconds: 7), () {
      if (mounted && _celebratedMatchId == celebrationId) {
        _celebrationController.stop();
      }
    });
  }

  Future<void> _requestRematch(_OnlineGame game) async {
    if (_updatingRematch || !game.matchOver) return;
    final myPlayerId = _myPlayerId(game);
    setState(() => _updatingRematch = true);
    try {
      await _db.runTransaction((transaction) async {
        final ref = _db.collection('kapi_online_games').doc(widget.gameId);
        final snapshot = await transaction.get(ref);
        final data = snapshot.data() ?? <String, dynamic>{};
        final fresh = _OnlineGame.fromSnapshot(snapshot);
        if (!fresh.matchOver || data['rematchClosed'] == true) return;

        final requests =
            Set<String>.from(
                data['rematchRequestedBy'] as List<dynamic>? ?? const [],
              ).map((id) => id.toUpperCase()).toSet()
              ..add(myPlayerId);
        if (fresh.players.every(requests.contains)) {
          transaction.set(ref, {
            ...fresh.startRematch().toMap(),
            'rematchRequestedBy': FieldValue.delete(),
            'rematchRequestedAt': FieldValue.delete(),
            'rematchClosed': FieldValue.delete(),
          }, SetOptions(merge: true));
        } else {
          transaction.set(ref, {
            'rematchRequestedBy': requests.toList(),
            'rematchRequestedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
      _rematchTimer?.cancel();
      _rematchTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) unawaited(_expireRematch(game));
      });
    } finally {
      if (mounted) setState(() => _updatingRematch = false);
    }
  }

  Future<void> _expireRematch(_OnlineGame game) async {
    if (_leavingRoom || !mounted) return;
    final snapshot = await _db
        .collection('kapi_online_games')
        .doc(widget.gameId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists || !mounted) return;
    final fresh = _OnlineGame.fromSnapshot(snapshot);
    if (!fresh.matchOver || fresh.rematchRequestedBy.length >= 2) return;
    await _closeRematchAndReturn(game);
  }

  Future<void> _closeRematchAndReturn(_OnlineGame game) async {
    if (_leavingRoom || !mounted) return;
    _rematchTimer?.cancel();
    await _db.collection('kapi_online_games').doc(widget.gameId).set({
      'rematchClosed': true,
      'rematchRequestedBy': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) await _finishMatch(game);
  }

  Widget _buildTopBar({required bool canResumeGame}) {
    return Row(
      children: [
        IconButton(
          onPressed: canResumeGame ? _confirmLeaveRoom : _returnToLobby,
          tooltip: _isSpanish ? 'Inicio del juego' : 'Game home',
          icon: const Icon(Icons.home_rounded, color: Colors.white),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      '/game',
                      arguments: {'fromDominoGame': true},
                    ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 17),
                label: Text(_isSpanish ? 'Notas' : 'Notes'),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _profileReady ? _openFriends : null,
          tooltip: _isSpanish ? 'Amigos' : 'Friends',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.group_rounded, color: Colors.white),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/kapi-store'),
          tooltip: _isSpanish ? 'Personalizar' : 'Personalize',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.palette_rounded, color: Colors.white),
        ),
        IconButton(
          onPressed: _showSettingsMenu,
          tooltip: _isSpanish ? 'Configuracion' : 'Settings',
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
        ),
        const SizedBox(width: 54),
      ],
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isSpanish ? 'Menu del juego' : 'Game menu',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const GameAudioControls(compact: true),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      unawaited(_confirmLeaveRoom());
                    },
                    icon: const Icon(Icons.exit_to_app_rounded),
                    label: Text(_isSpanish ? 'Salir de la sala' : 'Leave room'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(context, '/game-settings');
                    },
                    icon: const Icon(Icons.sports_esports_rounded),
                    label: Text(
                      _isSpanish ? 'Configuracion del juego' : 'Game Settings',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(context, '/note-settings');
                    },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(
                      _isSpanish ? 'Configuracion de apuntes' : 'Note Settings',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _confirmLeaveRoom() async {
    if (_leavingRoom || !mounted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF101820),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: _gold.withValues(alpha: 0.72)),
            ),
            title: Text(
              _isSpanish ? 'Salir de la sala' : 'Leave room',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              _isSpanish
                  ? 'La partida actual terminara y ambos jugadores podran buscar otra sala.'
                  : 'The current match will end and both players can search for another room.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: TextButton.styleFrom(foregroundColor: _gold),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
                child: Text(_isSpanish ? 'Salir' : 'Leave'),
              ),
            ],
          ),
    );
    if (leave != true || !mounted) return;
    _leavingRoom = true;
    try {
      final roomService = BlockRoomService(_db);
      final playerId = widget.playerId ?? _profile.publicId;
      await roomService.leaveGame(
        playerId: playerId,
        gameId: widget.gameId,
        reason: 'leaveRoomConfirmed',
      );
      final released = await roomService.waitUntilReleased(
        playerId: playerId,
        gameId: widget.gameId,
      );
      if (!released) {
        throw StateError('The room could not be closed completely.');
      }
    } catch (_) {
      _leavingRoom = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSpanish
                ? 'No se pudo cerrar la sala. Intenta nuevamente.'
                : 'The room could not be closed. Please try again.',
          ),
        ),
      );
      return;
    } finally {
      if (_leavingRoom && mounted) _returnToLobby();
    }
  }

  void _returnToLobby() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  Future<void> _finishMatch(_OnlineGame game) async {
    if (_leavingRoom || !mounted) return;
    _leavingRoom = true;
    _rematchTimer?.cancel();
    await BlockRoomService(
      _db,
    ).releaseCompletedGame(players: game.players, gameId: widget.gameId);
    if (!mounted) return;
    _allowPop = true;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/start-game',
      (route) => route.isFirst,
    );
  }

  Widget _buildAbandonedGame(Map<String, dynamic> data, _OnlineGame game) {
    final myId = _myPlayerId(game);
    final abandonedBy = (data['abandonedBy'] as String? ?? '').toUpperCase();
    final iLeft = abandonedBy == myId;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildTopBar(canResumeGame: false),
          const Spacer(),
          Icon(
            iLeft ? Icons.exit_to_app_rounded : Icons.person_off_rounded,
            color: _gold,
            size: 68,
          ),
          const SizedBox(height: 18),
          Text(
            iLeft
                ? (_isSpanish ? 'Saliste de la sala' : 'You left the room')
                : (_isSpanish
                    ? 'El otro jugador salio de la sala'
                    : 'The other player left the room'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isSpanish
                ? 'Ya puedes volver al lobby y buscar otro jugador.'
                : 'You can return to the lobby and find another player.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _returnToLobby,
            icon: const Icon(Icons.groups_rounded),
            label: Text(_isSpanish ? 'Volver al lobby' : 'Return to lobby'),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required String avatarKey,
    required String label,
    required String countryCode,
    required int rankingPoints,
    required int gameScore,
    required int targetScore,
    required bool active,
    bool compact = false,
  }) {
    final visual = DominoTierVisual.fromScore(rankingPoints);
    return AnimatedContainer(
      width: double.infinity,
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? _gold : visual.frameColor(),
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
                : visual.shadows(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: visual.deep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: visual.frameColor(active: active)),
              boxShadow: visual.shadows(active: active),
            ),
            child: DominoAvatarVisual(
              avatarKey: avatarKey,
              fallbackIcon: Icons.person_rounded,
              backgroundColor: visual.deep,
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  '${countryCode.isEmpty ? '--' : countryCode} · ${visual.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: visual.accent,
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$gameScore/$targetScore pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBacks(int count, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 4 : 5),
      decoration: BoxDecoration(
        color: const Color(0xFF082D27).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < min(count, 7); index++)
            Container(
              width: compact ? 14 : 17,
              height: compact ? 30 : 36,
              margin: EdgeInsets.only(left: index == 0 ? 0 : (compact ? 2 : 3)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF183B36), Color(0xFF071B19)],
                ),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundBadge(_OnlineGame game, {required bool compact}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(
            '${_isSpanish ? 'Ronda' : 'Round'} ${game.roundNumber}',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${_isSpanish ? 'Meta' : 'Goal'} ${game.targetScore}',
            style: TextStyle(
              color: _gold,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundResult(
    _OnlineGame game, {
    required String myPlayerId,
    required String otherPlayerId,
  }) {
    final winnerId = game.winnerId;
    final loserId = game.otherPlayerId(winnerId);
    final winner = game.initialsFor(winnerId);
    final requestedRematch = game.rematchRequestedBy.contains(myPlayerId);
    final opponentRequested = game.rematchRequestedBy.contains(otherPlayerId);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 430),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0.78, end: 1),
      builder:
          (context, value, child) => Transform.scale(
            scale: value,
            child: Opacity(opacity: value.clamp(0, 1), child: child),
          ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              game.matchOver
                  ? '${_isSpanish ? 'Felicidades' : 'Congratulations'}!\n$winner ${_isSpanish ? 'gana la partida' : 'wins the match'}'
                  : '$winner ${_isSpanish ? 'gana la ronda' : 'wins the round'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            _buildResultProfileCard(game, winnerId, winner: true),
            const SizedBox(height: 5),
            _buildRemainingTiles(
              label:
                  '${game.initialsFor(winnerId)} ${_isSpanish ? 'fichas restantes' : 'remaining tiles'}',
              tiles: game.handFor(winnerId),
              accent: _gold,
            ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '${game.initialsFor(myPlayerId)} ${game.scoreFor(myPlayerId)}/${game.targetScore}'
                '  •  '
                '${game.initialsFor(otherPlayerId)} ${game.scoreFor(otherPlayerId)}/${game.targetScore}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildResultProfileCard(game, loserId, winner: false),
            const SizedBox(height: 5),
            _buildRemainingTiles(
              label:
                  '${game.initialsFor(loserId)} ${_isSpanish ? 'fichas restantes' : 'remaining tiles'}',
              tiles: game.handFor(loserId),
              accent: const Color(0xFF64B5F6),
              alignEnd: true,
            ),
            if (!game.matchOver) ...[
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _startNextRound(game),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(_isSpanish ? 'Continuar' : 'Continue'),
                ),
              ),
            ],
            if (game.matchOver) ...[
              const SizedBox(height: 9),
              if (requestedRematch)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: _gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _isSpanish
                              ? 'Esperando al oponente...'
                              : 'Waiting for opponent...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (opponentRequested && !requestedRematch)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _isSpanish
                        ? 'El oponente quiere una revancha'
                        : 'Opponent wants a rematch',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          requestedRematch || _updatingRematch
                              ? null
                              : () => _requestRematch(game),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.replay_rounded),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isSpanish ? 'Jugar otra vez' : 'Play Again',
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _closeRematchAndReturn(game),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.groups_rounded),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isSpanish ? 'Volver al lobby' : 'Return to Lobby',
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultProfileCard(
    _OnlineGame game,
    String playerId, {
    required bool winner,
  }) {
    final tier = DominoTierVisual.fromScore(game.rankingPointsFor(playerId));
    const avatarSize = 56.0;
    final playerInfo = Column(
      crossAxisAlignment:
          winner ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          game.initialsFor(playerId),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
          ),
        ),
        Text(
          '${game.countryCodeFor(playerId)} · ${tier.label}',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: tier.accent,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
      ],
    );
    return Align(
      alignment: winner ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(
            0xFF071524,
          ).withValues(alpha: winner ? 0.48 : 0.62),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: tier.frameColor(active: true),
            width: winner ? 2 : 2.5,
          ),
          boxShadow: tier.shadows(active: true),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (winner) ...[
                  _buildResultAvatar(game, playerId, tier, size: avatarSize),
                  const SizedBox(width: 14),
                ] else
                  const Spacer(),
                if (!winner) ...[
                  _buildTierScoreShield(tier, game.rankingPointsFor(playerId)),
                  const SizedBox(width: 12),
                ],
                if (winner) Flexible(child: playerInfo) else playerInfo,
                if (winner) ...[
                  const SizedBox(width: 8),
                  _buildTierScoreShield(tier, game.rankingPointsFor(playerId)),
                  const SizedBox(width: 12),
                  Text(
                    '+${game.roundPoints} ${_isSpanish ? 'puntos' : 'points'}',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 14),
                  _buildResultAvatar(game, playerId, tier, size: avatarSize),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierScoreShield(DominoTierVisual tier, int rankingPoints) {
    final scoreColor = switch (tier.tier) {
      DominoPlayerTier.platinum => const Color(0xFF10283B),
      DominoPlayerTier.gold => const Color(0xFF4A2B00),
      DominoPlayerTier.silver => const Color(0xFF243244),
      DominoPlayerTier.bronze => const Color(0xFF32180D),
      DominoPlayerTier.iron => Colors.white,
      DominoPlayerTier.unranked => Colors.white,
    };
    return SizedBox(
      width: 36,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(tier.icon, color: tier.accent, size: 36),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$rankingPoints',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  shadows:
                      tier.tier == DominoPlayerTier.iron
                          ? const [Shadow(color: Colors.black, blurRadius: 2)]
                          : const [],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultAvatar(
    _OnlineGame game,
    String playerId,
    DominoTierVisual tier, {
    required double size,
  }) {
    final avatarKey = game.avatarKeyFor(playerId);
    final icon = switch (avatarKey) {
      'woman' => Icons.face_3_rounded,
      'robot' => Icons.smart_toy_rounded,
      'rainbow' => Icons.auto_awesome_rounded,
      'game' => Icons.sports_esports_rounded,
      'star' => Icons.star_rounded,
      _ => Icons.person_rounded,
    };
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tier.deep,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: tier.frameColor(active: true), width: 2),
      ),
      child: DominoAvatarVisual(
        avatarKey: avatarKey,
        fallbackIcon: icon,
        backgroundColor: tier.deep,
      ),
    );
  }

  Widget _buildRemainingTiles({
    required String label,
    required List<_DominoTile> tiles,
    required Color accent,
    bool alignEnd = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF071524).withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
          const SizedBox(height: 4),
          if (tiles.isEmpty)
            Text(
              _isSpanish ? 'Sin fichas' : 'No tiles left',
              style: const TextStyle(color: Colors.white60),
            )
          else
            Wrap(
              alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tile in tiles)
                  _DominoWidget(
                    tile: tile,
                    vertical: true,
                    accent: accent,
                    tableSize: 24,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(
    String status,
    _OnlineGame game, {
    required bool canPass,
  }) {
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
          if (canPass)
            FilledButton.icon(
              onPressed: () => _pass(game),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: Text(_isSpanish ? 'Pasar' : 'Pass'),
            ),
          if (game.roundOver && !game.matchOver)
            FilledButton(
              onPressed: () => _startNextRound(game),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              child: Text(_isSpanish ? 'Siguiente ronda' : 'Next round'),
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
    final dominoStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.domino,
    );
    final dominoShort = ((height - 12) / 1.82).clamp(30.0, 43.0);
    final displayHand = _orderedHandForDisplay(hand, game, myPlayerId);
    return SizedBox(
      height: height,
      child: AdaptiveDominoHandTray(
        key: const ValueKey('block-online-adaptive-hand-tray'),
        dominoColor: dominoStyle.primary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                    tileColor: dominoStyle.primary,
                    pipColor: dominoStyle.secondary,
                  ),
                ),
              );
            },
          ),
        ),
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
    final hostProfileDoc =
        await db.collection('kapi_lobby_profiles').doc(hostId).get();
    final guestProfileDoc =
        await db.collection('kapi_lobby_profiles').doc(cleanGuestId).get();
    final hostProfile = hostProfileDoc.data() ?? <String, dynamic>{};
    final guestProfile = guestProfileDoc.data() ?? <String, dynamic>{};
    final deck = <_DominoTile>[
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++) _DominoTile(left, right),
    ]..shuffle(Random());
    _OnlineGame.debugVerifyDeck(deck);
    final hands = {
      hostId: deck.take(7).toList(),
      cleanGuestId: deck.skip(7).take(7).toList(),
    };
    final starter = _selectStarter(hands);
    hands[starter.playerId]!.remove(starter.tile);
    final otherPlayer = starter.playerId == hostId ? cleanGuestId : hostId;

    final ref = db.collection('kapi_online_games').doc();
    final gameData = <String, dynamic>{
      'id': ref.id,
      'mode': 'block',
      'status': 'active',
      'players': [hostId, cleanGuestId],
      'profiles': {
        hostId: {
          'initials': host.initials,
          'countryCode': host.countryCode,
          'code': host.code,
          'avatarKey': host.avatarKey,
          'totalPoints': (hostProfile['totalPoints'] as num?)?.toInt() ?? 0,
        },
        cleanGuestId: {
          'initials': guestProfile['initials'] as String? ?? guestInitials,
          'countryCode': guestProfile['countryCode'] as String? ?? '',
          'code': guestProfile['code'] as String? ?? '',
          'avatarKey': guestProfile['avatarKey'] as String? ?? '',
          'totalPoints': (guestProfile['totalPoints'] as num?)?.toInt() ?? 0,
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
      'scores': {hostId: 0, cleanGuestId: 0},
      'roundNumber': 1,
      'targetScore': DominoGameConfig.targetScore,
      'winnerId': '',
      'roundPoints': 0,
      'matchOver': false,
      'revision': 1,
      'lastPlayedTile': starter.tile.toText(),
      'message': '${starter.playerId} opened with ${starter.tile.label}',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await db.runTransaction((transaction) async {
      final playerIds = [hostId, cleanGuestId];
      final sessionRefs = [
        for (final id in playerIds)
          db.collection(BlockRoomService.sessionsCollection).doc(id),
      ];
      final sessions = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final sessionRef in sessionRefs) {
        sessions.add(await transaction.get(sessionRef));
      }
      for (var index = 0; index < sessions.length; index++) {
        if (BlockRoomService.isBusy(sessions[index].data())) {
          throw StateError('${playerIds[index]} is already in another room.');
        }
      }

      transaction.set(ref, gameData);
      for (final id in playerIds) {
        transaction.set(
          db.collection(BlockRoomService.sessionsCollection).doc(id),
          {
            'state': 'inGame',
            'activeGameId': ref.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(db.collection('kapi_block_matchmaking').doc(id), {
          'status': 'inGame',
          'gameId': ref.id,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(db.collection('kapi_lobby_profiles').doc(id), {
          'availability': 'inGame',
          'activeGameId': ref.id,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
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

  /// Deterministic regression checks for tip matching, 2-to-2 orientation,
  /// blocked-round ties, scoring, and winner-starts-next-round behavior.
  static bool debugValidateBlockRules() {
    const playerA = 'AA.US.AAAAAA';
    const playerB = 'BB.US.BBBBBB';
    final base = _OnlineGame(
      id: 'debug',
      players: const [playerA, playerB],
      hands: const {
        playerA: [_DominoTile(2, 5), _DominoTile(0, 1)],
        playerB: [_DominoTile(3, 5), _DominoTile(4, 4)],
      },
      profiles: const {
        playerA: {'initials': 'AA'},
        playerB: {'initials': 'BB'},
      },
      board: const [_BoardDomino(_DominoTile(2, 2), isFirst: true)],
      turnId: playerA,
      passed: const {},
      roundOver: false,
      message: '',
      scores: const {playerA: 0, playerB: 0},
      roundNumber: 1,
      targetScore: DominoGameConfig.targetScore,
      winnerId: '',
      roundPoints: 0,
      matchOver: false,
      lastPlayedTile: const _DominoTile(2, 2),
      rematchRequestedBy: const <String>{},
      revision: 1,
    );
    final afterTwo = base.playTile(
      playerId: playerA,
      tile: const _DominoTile(2, 5),
      side: _BoardSide.right,
    );
    if (afterTwo.board.last.tile.left != 2 ||
        afterTwo.board.last.tile.right != 5) {
      return false;
    }
    final afterFive = afterTwo.playTile(
      playerId: playerB,
      tile: const _DominoTile(3, 5),
      side: _BoardSide.right,
    );
    for (var index = 0; index < afterFive.board.length - 1; index++) {
      if (afterFive.board[index].tile.right !=
          afterFive.board[index + 1].tile.left) {
        return false;
      }
    }
    if (afterTwo.revision != base.revision + 1 ||
        afterFive.revision != afterTwo.revision + 1) {
      return false;
    }

    final blankTip = _OnlineGame(
      id: 'blank-tip',
      players: const [playerA, playerB],
      hands: const {
        playerA: [_DominoTile(0, 6)],
        playerB: [_DominoTile(1, 1)],
      },
      profiles: base.profiles,
      board: const [_BoardDomino(_DominoTile(4, 0), isFirst: true)],
      turnId: playerA,
      passed: const {},
      roundOver: false,
      message: '',
      scores: const {playerA: 0, playerB: 0},
      roundNumber: 1,
      targetScore: DominoGameConfig.targetScore,
      winnerId: '',
      roundPoints: 0,
      matchOver: false,
      lastPlayedTile: const _DominoTile(4, 0),
      rematchRequestedBy: const <String>{},
      revision: 7,
    );
    if (!blankTip
            .validSides(const _DominoTile(0, 6))
            .contains(_BoardSide.right) ||
        !blankTip.hasMove(playerA)) {
      return false;
    }
    final afterBlank = blankTip.playTile(
      playerId: playerA,
      tile: const _DominoTile(0, 6),
      side: _BoardSide.right,
    );
    if (afterBlank.board.last.tile != const _DominoTile(0, 6) ||
        afterBlank.revision != 8) {
      return false;
    }

    final tiedBlock = _OnlineGame(
      id: 'tie',
      players: const [playerA, playerB],
      hands: const {
        playerA: [_DominoTile(0, 1)],
        playerB: [_DominoTile(0, 1)],
      },
      profiles: base.profiles,
      board: const [_BoardDomino(_DominoTile(6, 6), isFirst: true)],
      turnId: playerA,
      passed: const {playerB},
      roundOver: false,
      message: '',
      scores: const {playerA: 0, playerB: 0},
      roundNumber: 1,
      targetScore: DominoGameConfig.targetScore,
      winnerId: '',
      roundPoints: 0,
      matchOver: false,
      lastPlayedTile: const _DominoTile(6, 6),
      rematchRequestedBy: const <String>{},
      revision: 1,
    ).pass(playerA);
    if (!tiedBlock.roundOver ||
        tiedBlock.winnerId != playerA ||
        tiedBlock.scoreFor(playerA) != 2) {
      return false;
    }
    final unequalBlock = _OnlineGame(
      id: 'unequal',
      players: const [playerA, playerB],
      hands: const {
        playerA: [_DominoTile(2, 3)],
        playerB: [_DominoTile(4, 4)],
      },
      profiles: base.profiles,
      board: const [_BoardDomino(_DominoTile(6, 6), isFirst: true)],
      turnId: playerB,
      passed: const {playerA},
      roundOver: false,
      message: '',
      scores: const {playerA: 0, playerB: 0},
      roundNumber: 1,
      targetScore: DominoGameConfig.targetScore,
      winnerId: '',
      roundPoints: 0,
      matchOver: false,
      lastPlayedTile: const _DominoTile(6, 6),
      rematchRequestedBy: const <String>{},
      revision: 1,
    ).pass(playerB);
    if (unequalBlock.winnerId != playerA ||
        unequalBlock.roundPoints != 13 ||
        unequalBlock.scoreFor(playerA) != 13) {
      return false;
    }
    final nextRound = tiedBlock.startNextRound();
    if (nextRound.roundNumber != 2 ||
        nextRound.turnId != playerA ||
        nextRound.board.isNotEmpty ||
        nextRound.handFor(playerA).length != 7 ||
        nextRound.handFor(playerB).length != 7) {
      return false;
    }
    final rematch = unequalBlock.copyWith(matchOver: true).startRematch();
    return rematch.roundNumber == 1 &&
        rematch.targetScore == DominoGameConfig.targetScore &&
        rematch.scoreFor(playerA) == 0 &&
        rematch.scoreFor(playerB) == 0 &&
        rematch.board.length == 1 &&
        rematch.handFor(playerA).length + rematch.handFor(playerB).length ==
            13 &&
        rematch.rematchRequestedBy.isEmpty &&
        !rematch.matchOver;
  }

  static bool debugValidateBoardGeometry() {
    final board = <_BoardDomino>[
      const _BoardDomino(_DominoTile(1, 2), isFirst: false),
      const _BoardDomino(_DominoTile(2, 5), isFirst: false),
      const _BoardDomino(_DominoTile(5, 6), isFirst: false),
      const _BoardDomino(_DominoTile(6, 6), isFirst: true),
      const _BoardDomino(_DominoTile(6, 4), isFirst: false),
      const _BoardDomino(_DominoTile(4, 2), isFirst: false),
      const _BoardDomino(_DominoTile(2, 0), isFirst: false),
      const _BoardDomino(_DominoTile(0, 3), isFirst: false),
      const _BoardDomino(_DominoTile(3, 3), isFirst: false),
    ];
    const tileSize = Size(40, 72.8);
    const boardSize = Size(360, 520);
    const view = _OnlineBoard(
      board: [],
      dominoColor: Colors.white,
      pipColor: Colors.black,
    );
    final positions = view._layoutBoard(
      board: board,
      tileSize: tileSize,
      boardSize: boardSize,
    );
    for (var index = 1; index < positions.length; index++) {
      final previous = positions[index - 1];
      final current = positions[index];
      final previousSize =
          view._drawSize(tileSize, previous.vertical) * previous.scaleFactor;
      final currentSize =
          view._drawSize(tileSize, current.vertical) * current.scaleFactor;
      final previousRect = Rect.fromLTWH(
        previous.dx,
        previous.dy,
        previousSize.width,
        previousSize.height,
      );
      final currentRect = Rect.fromLTWH(
        current.dx,
        current.dy,
        currentSize.width,
        currentSize.height,
      );
      if (!view._rectsTouch(previousRect, currentRect)) {
        return false;
      }
    }
    return true;
  }

  static bool debugValidateRapidGames() {
    const playerA = 'AA.US.AAAAAA';
    const playerB = 'BB.US.BBBBBB';
    for (var seed = 0; seed < 40; seed++) {
      final deck = <_DominoTile>[
        for (var left = 0; left <= 6; left++)
          for (var right = left; right <= 6; right++) _DominoTile(left, right),
      ]..shuffle(Random(seed));
      final hands = <String, List<_DominoTile>>{
        playerA: deck.take(7).toList(),
        playerB: deck.skip(7).take(7).toList(),
      };
      final starter = _selectStarter(hands);
      hands[starter.playerId]!.remove(starter.tile);
      final other = starter.playerId == playerA ? playerB : playerA;
      var game = _OnlineGame(
        id: 'rapid-$seed',
        players: const [playerA, playerB],
        hands: hands,
        profiles: const {
          playerA: {'initials': 'AA'},
          playerB: {'initials': 'BB'},
        },
        board: [_BoardDomino(starter.tile, isFirst: true)],
        turnId: other,
        passed: const {},
        roundOver: false,
        message: '',
        scores: const {playerA: 0, playerB: 0},
        roundNumber: 1,
        targetScore: DominoGameConfig.targetScore,
        winnerId: '',
        roundPoints: 0,
        matchOver: false,
        lastPlayedTile: starter.tile,
        rematchRequestedBy: const <String>{},
        revision: 1,
      );
      var steps = 0;
      while (!game.roundOver && steps < 30) {
        final player = game.turnId;
        final hand = game.handFor(player);
        _DominoTile? playable;
        _BoardSide? side;
        for (final tile in hand) {
          final sides = game.validSides(tile);
          if (sides.isNotEmpty) {
            playable = tile;
            side = sides.first;
            break;
          }
        }
        final beforeRevision = game.revision;
        game =
            playable == null
                ? game.pass(player)
                : game.playTile(playerId: player, tile: playable, side: side!);
        if (game.revision != beforeRevision + 1) return false;
        for (var index = 0; index < game.board.length - 1; index++) {
          if (game.board[index].tile.right != game.board[index + 1].tile.left) {
            return false;
          }
        }
        steps++;
      }
      if (!game.roundOver || steps >= 30) return false;
      final remainingPoints = game.hands.values
          .expand((hand) => hand)
          .fold<int>(0, (total, tile) => total + tile.points);
      if (game.roundPoints != remainingPoints) return false;
    }
    return true;
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
    required this.scores,
    required this.roundNumber,
    required this.targetScore,
    required this.winnerId,
    required this.roundPoints,
    required this.matchOver,
    required this.lastPlayedTile,
    required this.rematchRequestedBy,
    required this.revision,
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
  final Map<String, int> scores;
  final int roundNumber;
  final int targetScore;
  final String winnerId;
  final int roundPoints;
  final bool matchOver;
  final _DominoTile? lastPlayedTile;
  final Set<String> rematchRequestedBy;
  final int revision;

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
    final rawScores = Map<String, dynamic>.from(data['scores'] ?? {});
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
      scores: {
        for (final player in players)
          player: (rawScores[player] as num?)?.toInt() ?? 0,
      },
      roundNumber: (data['roundNumber'] as num?)?.toInt() ?? 1,
      targetScore:
          (data['targetScore'] as num?)?.toInt() ??
          DominoGameConfig.targetScore,
      winnerId: (data['winnerId'] as String? ?? '').toUpperCase(),
      roundPoints: (data['roundPoints'] as num?)?.toInt() ?? 0,
      matchOver: data['matchOver'] == true || data['status'] == 'matchOver',
      lastPlayedTile:
          (data['lastPlayedTile'] as String?)?.isNotEmpty == true
              ? _DominoTile.fromText(data['lastPlayedTile'] as String)
              : null,
      rematchRequestedBy:
          Set<String>.from(
            data['rematchRequestedBy'] as List<dynamic>? ?? const [],
          ).map((id) => id.toUpperCase()).toSet(),
      revision: (data['revision'] as num?)?.toInt() ?? 0,
    );
  }

  int scoreFor(String playerId) => scores[playerId.toUpperCase()] ?? 0;

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

  String countryCodeFor(String playerId) {
    final id = playerId.toUpperCase();
    final stored =
        (profiles[id]?['countryCode'] as String? ?? '').toUpperCase();
    if (stored.isNotEmpty) return stored;
    final parts = id.split('.');
    return parts.length > 1 ? parts[1].toUpperCase() : '';
  }

  int rankingPointsFor(String playerId) {
    final raw = profiles[playerId.toUpperCase()]?['totalPoints'];
    return raw is num ? raw.toInt() : 0;
  }

  String avatarKeyFor(String playerId) =>
      profiles[playerId.toUpperCase()]?['avatarKey'] as String? ?? 'person';

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
    if (nextBoard.isEmpty) {
      nextBoard.add(_BoardDomino(tile, isFirst: true));
    } else if (side == _BoardSide.left) {
      final open = leftOpen!;
      final oriented = tile.right == open ? tile : tile.flipped;
      nextBoard.insert(0, _BoardDomino(oriented, isFirst: false));
    } else {
      final open = rightOpen!;
      final oriented = tile.left == open ? tile : tile.flipped;
      nextBoard.add(_BoardDomino(oriented, isFirst: false));
    }
    _OnlineGame.debugVerifyBoardLinks(nextBoard);
    final other = otherPlayerId(clean);
    final next = copyWith(
      hands: nextHands,
      board: nextBoard,
      turnId: other,
      passed: <String>{},
      message: '${initialsFor(clean)} played ${tile.label}',
      lastPlayedTile: tile,
      revision: revision + 1,
    );
    if (nextHands[clean]!.isNotEmpty) return next;
    final points = nextHands[other]!.fold<int>(
      0,
      (total, domino) => total + domino.points,
    );
    return next.finishRound(
      winner: clean,
      points: points,
      result: '${initialsFor(clean)} wins the round +$points',
    );
  }

  _OnlineGame pass(String playerId) {
    final clean = playerId.toUpperCase();
    final nextPassed = Set<String>.from(passed)..add(clean);
    final other = otherPlayerId(clean);
    final next = copyWith(
      turnId: other,
      passed: nextPassed,
      message: '${initialsFor(clean)} passed',
      revision: revision + 1,
    );
    if (nextPassed.length >= 2) {
      final myPoints = handFor(
        clean,
      ).fold<int>(0, (total, tile) => total + tile.points);
      final otherPoints = handFor(
        other,
      ).fold<int>(0, (total, tile) => total + tile.points);
      final winner = myPoints <= otherPoints ? clean : other;
      final combinedPoints = myPoints + otherPoints;
      return next.finishRound(
        winner: winner,
        points: combinedPoints,
        result:
            '${initialsFor(winner)} wins the blocked round +$combinedPoints',
      );
    }
    return next;
  }

  _OnlineGame finishRound({
    required String winner,
    required int points,
    required String result,
  }) {
    final nextScores = Map<String, int>.from(scores);
    nextScores[winner] = (nextScores[winner] ?? 0) + points;
    final completed = (nextScores[winner] ?? 0) >= targetScore;
    return copyWith(
      scores: nextScores,
      roundOver: true,
      matchOver: completed,
      winnerId: winner,
      roundPoints: points,
      message: completed ? '${initialsFor(winner)} wins the match' : result,
    );
  }

  _OnlineGame startNextRound() {
    final deck = <_DominoTile>[
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++) _DominoTile(left, right),
    ]..shuffle(Random());
    debugVerifyDeck(deck);
    final nextHands = <String, List<_DominoTile>>{
      players[0]: deck.take(7).toList(),
      players[1]: deck.skip(7).take(7).toList(),
    };
    final starter = players.contains(winnerId) ? winnerId : players.first;
    return _OnlineGame(
      id: id,
      players: players,
      hands: nextHands,
      profiles: profiles,
      board: const [],
      turnId: starter,
      passed: const <String>{},
      roundOver: false,
      message: '${initialsFor(starter)} starts the round',
      scores: scores,
      roundNumber: roundNumber + 1,
      targetScore: targetScore,
      winnerId: '',
      roundPoints: 0,
      matchOver: false,
      lastPlayedTile: null,
      rematchRequestedBy: const <String>{},
      revision: revision + 1,
    );
  }

  _OnlineGame startRematch() {
    final deck = <_DominoTile>[
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++) _DominoTile(left, right),
    ]..shuffle(Random());
    debugVerifyDeck(deck);
    final nextHands = <String, List<_DominoTile>>{
      players[0]: deck.take(7).toList(),
      players[1]: deck.skip(7).take(7).toList(),
    };
    final candidates = <_Starter>[
      for (final entry in nextHands.entries)
        for (final tile in entry.value) _Starter(entry.key, tile),
    ]..sort((a, b) {
      final doubleOrder = (b.tile.isDouble ? 1 : 0).compareTo(
        a.tile.isDouble ? 1 : 0,
      );
      if (doubleOrder != 0) return doubleOrder;
      if (a.tile.isDouble && b.tile.isDouble) {
        return b.tile.left.compareTo(a.tile.left);
      }
      return b.tile.points.compareTo(a.tile.points);
    });
    final starter = candidates.first;
    nextHands[starter.playerId]!.remove(starter.tile);
    final nextPlayer = players.firstWhere((id) => id != starter.playerId);
    return _OnlineGame(
      id: id,
      players: players,
      hands: nextHands,
      profiles: profiles,
      board: [_BoardDomino(starter.tile, isFirst: true)],
      turnId: nextPlayer,
      passed: const <String>{},
      roundOver: false,
      message:
          '${initialsFor(starter.playerId)} opened with ${starter.tile.label}',
      scores: {for (final player in players) player: 0},
      roundNumber: 1,
      targetScore: DominoGameConfig.targetScore,
      winnerId: '',
      roundPoints: 0,
      matchOver: false,
      lastPlayedTile: starter.tile,
      rematchRequestedBy: const <String>{},
      revision: revision + 1,
    );
  }

  _OnlineGame copyWith({
    Map<String, List<_DominoTile>>? hands,
    List<_BoardDomino>? board,
    String? turnId,
    Set<String>? passed,
    bool? roundOver,
    String? message,
    Map<String, int>? scores,
    int? roundNumber,
    int? targetScore,
    String? winnerId,
    int? roundPoints,
    bool? matchOver,
    _DominoTile? lastPlayedTile,
    Set<String>? rematchRequestedBy,
    int? revision,
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
      scores: scores ?? this.scores,
      roundNumber: roundNumber ?? this.roundNumber,
      targetScore: targetScore ?? this.targetScore,
      winnerId: winnerId ?? this.winnerId,
      roundPoints: roundPoints ?? this.roundPoints,
      matchOver: matchOver ?? this.matchOver,
      lastPlayedTile: lastPlayedTile ?? this.lastPlayedTile,
      rematchRequestedBy: rematchRequestedBy ?? this.rematchRequestedBy,
      revision: revision ?? this.revision,
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
      'scores': scores,
      'roundNumber': roundNumber,
      'targetScore': targetScore,
      'winnerId': winnerId,
      'roundPoints': roundPoints,
      'matchOver': matchOver,
      'lastPlayedTile': lastPlayedTile?.toText() ?? '',
      'status': matchOver ? 'matchOver' : (roundOver ? 'roundOver' : 'active'),
      'message': message,
      'revision': revision,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static void debugVerifyDeck(List<_DominoTile> deck) {
    assert(() {
      final unique = deck.map((tile) => tile.key).toSet();
      if (deck.length != 28 || unique.length != 28) {
        debugPrint(
          'Kapi online deck error: expected 28 unique tiles, '
          'got ${deck.length} tiles and ${unique.length} unique.',
        );
        return false;
      }
      return true;
    }());
  }

  static void debugVerifyBoardLinks(List<_BoardDomino> board) {
    assert(() {
      for (var index = 0; index < board.length - 1; index++) {
        final current = board[index];
        final next = board[index + 1];
        if (current.tile.right != next.tile.left) {
          debugPrint(
            'Kapi online board link error at $index: '
            '${current.tile.label} does not connect to ${next.tile.label}.',
          );
          return false;
        }
      }
      return true;
    }());
  }
}

class _OnlineBoard extends StatelessWidget {
  const _OnlineBoard({
    required this.board,
    required this.dominoColor,
    required this.pipColor,
    this.playedTileScale = 1.0,
    this.sideChoiceTile,
    this.sideChoicePulse,
    this.onSideSelected,
  });

  final List<_BoardDomino> board;
  final Color dominoColor;
  final Color pipColor;
  final double playedTileScale;
  final _DominoTile? sideChoiceTile;
  final Animation<double>? sideChoicePulse;
  final ValueChanged<_BoardSide>? onSideSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileShort =
            min(
              44.0,
              max(
                30.0,
                min(constraints.maxWidth / 8.8, constraints.maxHeight / 5.2),
              ),
            ) *
            playedTileScale;
        final tileLong = tileShort * 1.82;
        final positions = _layoutBoard(
          board: board,
          tileSize: Size(tileShort, tileLong),
          boardSize: constraints.biggest,
        );
        final previews = <_OnlineSidePreview>[];
        if (sideChoiceTile != null && board.isNotEmpty) {
          previews
            ..add(
              _previewForSide(
                tile: sideChoiceTile!,
                side: _BoardSide.left,
                currentPositions: positions,
                tileSize: Size(tileShort, tileLong),
                boardSize: constraints.biggest,
              ),
            )
            ..add(
              _previewForSide(
                tile: sideChoiceTile!,
                side: _BoardSide.right,
                currentPositions: positions,
                tileSize: Size(tileShort, tileLong),
                boardSize: constraints.biggest,
              ),
            );
        }
        var contentBounds = Rect.zero;
        void includePosition(_BoardPosition position) {
          final size =
              _drawSize(Size(tileShort, tileLong), position.vertical) *
              position.scaleFactor;
          final rect = Rect.fromLTWH(
            position.dx,
            position.dy,
            size.width,
            size.height,
          );
          contentBounds =
              contentBounds == Rect.zero
                  ? rect
                  : contentBounds.expandToInclude(rect);
        }

        for (final position in positions) {
          includePosition(position);
        }
        for (final preview in previews) {
          includePosition(preview.position);
        }
        final fitScale =
            previews.isEmpty
                ? 1.0
                : min(
                  1.0,
                  min(
                    max(1.0, constraints.maxWidth - 8) /
                        max(1.0, contentBounds.width),
                    max(1.0, constraints.maxHeight - 8) /
                        max(1.0, contentBounds.height),
                  ),
                );
        final fitOffset =
            previews.isEmpty
                ? Offset.zero
                : Offset(
                  (constraints.maxWidth - contentBounds.width * fitScale) / 2 -
                      contentBounds.left * fitScale,
                  (constraints.maxHeight - contentBounds.height * fitScale) /
                          2 -
                      contentBounds.top * fitScale,
                );
        final content = Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < board.length; index++)
              Positioned(
                key: ValueKey(board[index].tile.key),
                left: positions[index].dx,
                top: positions[index].dy,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  tween: Tween(begin: 0.68, end: 1),
                  builder:
                      (context, value, child) => Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value.clamp(0, 1),
                          child: child,
                        ),
                      ),
                  child: _DominoWidget(
                    tile:
                        positions[index].flipVisual
                            ? board[index].tile.flipped
                            : board[index].tile,
                    vertical: positions[index].vertical,
                    first: board[index].isFirst,
                    tableSize: tileShort * positions[index].scaleFactor,
                    tileColor: dominoColor,
                    pipColor: pipColor,
                  ),
                ),
              ),
            for (final preview in previews)
              Positioned(
                left: preview.position.dx,
                top: preview.position.dy,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation:
                        sideChoicePulse ?? const AlwaysStoppedAnimation(0.5),
                    builder: (context, child) {
                      final pulse = Curves.easeInOut.transform(
                        sideChoicePulse?.value ?? 0.5,
                      );
                      return Opacity(
                        opacity: 0.58 + pulse * 0.42,
                        child: Transform.scale(
                          scale: 0.94 + pulse * 0.10,
                          child: child,
                        ),
                      );
                    },
                    child: _DominoWidget(
                      tile: preview.tile,
                      vertical: preview.position.vertical,
                      tableSize: tileShort * preview.position.scaleFactor,
                      tileColor: preview.color,
                      pipColor: Colors.white,
                      accent: Colors.white,
                      shadowColor: preview.color,
                    ),
                  ),
                ),
              ),
          ],
        );
        if (previews.isEmpty) return content;
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              for (final preview in previews) {
                final previewSize =
                    _drawSize(
                      Size(tileShort, tileLong),
                      preview.position.vertical,
                    ) *
                    preview.position.scaleFactor;
                final hitRect = Rect.fromLTWH(
                  fitOffset.dx + preview.position.dx * fitScale,
                  fitOffset.dy + preview.position.dy * fitScale,
                  previewSize.width * fitScale,
                  previewSize.height * fitScale,
                ).inflate(16);
                if (hitRect.contains(details.localPosition)) {
                  onSideSelected?.call(preview.side);
                  return;
                }
              }
            },
            child: Transform.translate(
              offset: fitOffset,
              child: Transform.scale(
                alignment: Alignment.topLeft,
                scale: fitScale,
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

  _OnlineSidePreview _previewForSide({
    required _DominoTile tile,
    required _BoardSide side,
    required List<_BoardPosition> currentPositions,
    required Size tileSize,
    required Size boardSize,
  }) {
    final open =
        side == _BoardSide.left ? board.first.tile.left : board.last.tile.right;
    final placed = switch (side) {
      _BoardSide.left => tile.right == open ? tile : tile.flipped,
      _BoardSide.right => tile.left == open ? tile : tile.flipped,
    };
    final hypothetical = <_BoardDomino>[
      if (side == _BoardSide.left) _BoardDomino(placed, isFirst: false),
      ...board,
      if (side == _BoardSide.right) _BoardDomino(placed, isFirst: false),
    ];
    final hypotheticalPositions = _layoutBoard(
      board: hypothetical,
      tileSize: tileSize,
      boardSize: boardSize,
    );
    final candidateIndex =
        side == _BoardSide.left ? 0 : hypothetical.length - 1;
    final hypotheticalNeighborIndex =
        side == _BoardSide.left ? 1 : hypothetical.length - 2;
    final currentNeighborIndex = side == _BoardSide.left ? 0 : board.length - 1;
    final candidate = hypotheticalPositions[candidateIndex];
    final hypotheticalNeighbor =
        hypotheticalPositions[hypotheticalNeighborIndex];
    final currentNeighbor = currentPositions[currentNeighborIndex];
    final ratio =
        currentNeighbor.scaleFactor / hypotheticalNeighbor.scaleFactor;
    final candidateCenter =
        _positionCenter(currentNeighbor, tileSize) +
        (_positionCenter(candidate, tileSize) -
                _positionCenter(hypotheticalNeighbor, tileSize)) *
            ratio;
    final candidateScale = candidate.scaleFactor * ratio;
    final candidateSize =
        _drawSize(tileSize, candidate.vertical) * candidateScale;
    final position = _BoardPosition(
      candidateCenter.dx - candidateSize.width / 2,
      candidateCenter.dy - candidateSize.height / 2,
      candidate.vertical,
      candidateScale,
      candidate.flipVisual,
      candidate.layoutDirection,
    );
    return _OnlineSidePreview(
      side: side,
      tile: candidate.flipVisual ? placed.flipped : placed,
      position: position,
      color:
          side == _BoardSide.left
              ? const Color(0xFFE53935)
              : const Color(0xFF1976D2),
    );
  }

  Offset _positionCenter(_BoardPosition position, Size tileSize) {
    final size = _drawSize(tileSize, position.vertical) * position.scaleFactor;
    return Offset(position.dx + size.width / 2, position.dy + size.height / 2);
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
      flipVisual: false,
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
              flipVisual: false,
            ),
    ];
    _debugVerifyBoardAlignment(resolved, tileSize);
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

    final drawPositions = [
      for (final item in resolved)
        _toDrawPosition(item, tileSize, scale, translation),
    ];
    _debugVerifyDrawAlignment(drawPositions, tileSize);
    return drawPositions;
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
        flipVisual: _shouldFlipVisual(side, direction),
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
    const contactOverlap = 1.1;
    final previousRect = Rect.fromCenter(
      center: previous.center,
      width: previousSize.width,
      height: previousSize.height,
    );
    return switch (direction) {
      _LayoutDirection.right => Offset(
        previousRect.right + currentSize.width / 2 - contactOverlap,
        previous.direction == _LayoutDirection.up
            ? previousRect.top + currentSize.height / 2
            : previous.direction == _LayoutDirection.down
            ? previousRect.bottom - currentSize.height / 2
            : previous.center.dy,
      ),
      _LayoutDirection.left => Offset(
        previousRect.left - currentSize.width / 2 + contactOverlap,
        previous.direction == _LayoutDirection.up
            ? previousRect.top + currentSize.height / 2
            : previous.direction == _LayoutDirection.down
            ? previousRect.bottom - currentSize.height / 2
            : previous.center.dy,
      ),
      _LayoutDirection.down => Offset(
        previous.direction == _LayoutDirection.right
            ? previousRect.right - currentSize.width / 2
            : previous.direction == _LayoutDirection.left
            ? previousRect.left + currentSize.width / 2
            : previous.center.dx,
        previousRect.bottom + currentSize.height / 2 - contactOverlap,
      ),
      _LayoutDirection.up => Offset(
        previous.direction == _LayoutDirection.right
            ? previousRect.right - currentSize.width / 2
            : previous.direction == _LayoutDirection.left
            ? previousRect.left + currentSize.width / 2
            : previous.center.dx,
        previousRect.top - currentSize.height / 2 + contactOverlap,
      ),
    };
  }

  bool _isVertical(_LayoutDirection direction, _DominoTile tile) {
    final lineIsVertical =
        direction == _LayoutDirection.up || direction == _LayoutDirection.down;
    return tile.isDouble ? !lineIsVertical : lineIsVertical;
  }

  bool _shouldFlipVisual(_BoardSide side, _LayoutDirection direction) {
    if (side == _BoardSide.right) {
      return direction == _LayoutDirection.left ||
          direction == _LayoutDirection.up;
    }
    return direction == _LayoutDirection.right ||
        direction == _LayoutDirection.down;
  }

  void _debugVerifyBoardAlignment(
    List<_LogicalBoardPosition> positions,
    Size tileSize,
  ) {
    assert(() {
      for (var index = 1; index < positions.length; index++) {
        final previous = positions[index - 1];
        final current = positions[index];
        final previousSize = _drawSize(tileSize, previous.vertical);
        final currentSize = _drawSize(tileSize, current.vertical);
        final previousRect = Rect.fromCenter(
          center: previous.center,
          width: previousSize.width,
          height: previousSize.height,
        );
        final currentRect = Rect.fromCenter(
          center: current.center,
          width: currentSize.width,
          height: currentSize.height,
        );
        if (!_rectsTouch(previousRect, currentRect)) {
          debugPrint(
            'Kapi online alignment warning at $index: '
            'previous=${previous.direction} current=${current.direction}',
          );
        }
      }
      return true;
    }());
  }

  void _debugVerifyDrawAlignment(
    List<_BoardPosition> positions,
    Size tileSize,
  ) {
    assert(() {
      for (var index = 1; index < positions.length; index++) {
        final previous = positions[index - 1];
        final current = positions[index];
        final previousSize =
            _drawSize(tileSize, previous.vertical) * previous.scaleFactor;
        final currentSize =
            _drawSize(tileSize, current.vertical) * current.scaleFactor;
        final previousRect = Rect.fromLTWH(
          previous.dx,
          previous.dy,
          previousSize.width,
          previousSize.height,
        );
        final currentRect = Rect.fromLTWH(
          current.dx,
          current.dy,
          currentSize.width,
          currentSize.height,
        );
        if (!_rectsTouch(previousRect, currentRect)) {
          debugPrint(
            'Kapi online draw alignment warning at $index: '
            'previous=${previous.layoutDirection} '
            'current=${current.layoutDirection}',
          );
        }
      }
      return true;
    }());
  }

  bool _rectsConnect(Rect previous, Rect current, _LayoutDirection direction) {
    const tolerance = 1.35;
    const maxVisualOverlap = 1.6;
    bool close(double a, double b) => (a - b).abs() <= tolerance;
    bool forward(double previousEdge, double currentEdge) {
      final delta = previousEdge - currentEdge;
      return delta.abs() <= tolerance ||
          (delta > 0 && delta <= maxVisualOverlap);
    }

    bool reverse(double previousEdge, double currentEdge) {
      final delta = currentEdge - previousEdge;
      return delta.abs() <= tolerance ||
          (delta > 0 && delta <= maxVisualOverlap);
    }

    bool alignedX() =>
        close(previous.center.dx, current.center.dx) ||
        close(previous.left, current.left) ||
        close(previous.right, current.right);
    bool alignedY() =>
        close(previous.center.dy, current.center.dy) ||
        close(previous.top, current.top) ||
        close(previous.bottom, current.bottom);
    return switch (direction) {
      _LayoutDirection.right =>
        forward(previous.right, current.left) && alignedY(),
      _LayoutDirection.left =>
        reverse(previous.left, current.right) && alignedY(),
      _LayoutDirection.down =>
        forward(previous.bottom, current.top) && alignedX(),
      _LayoutDirection.up =>
        reverse(previous.top, current.bottom) && alignedX(),
    };
  }

  bool _rectsTouch(Rect previous, Rect current) {
    return _LayoutDirection.values.any(
      (direction) => _rectsConnect(previous, current, direction),
    );
  }

  _LayoutDirection _nextDirection(_LayoutDirection direction, _BoardSide side) {
    if (side == _BoardSide.right) {
      return switch (direction) {
        _LayoutDirection.right => _LayoutDirection.down,
        _LayoutDirection.down => _LayoutDirection.left,
        _LayoutDirection.left => _LayoutDirection.down,
        _LayoutDirection.up => _LayoutDirection.right,
      };
    }
    return switch (direction) {
      _LayoutDirection.left => _LayoutDirection.up,
      _LayoutDirection.up => _LayoutDirection.right,
      _LayoutDirection.right => _LayoutDirection.up,
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
      position.flipVisual,
      position.direction,
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
    this.tileColor,
    this.pipColor,
    this.shadowColor,
  });

  final _DominoTile tile;
  final bool vertical;
  final bool first;
  final Color? accent;
  final double? tableSize;
  final Color? tileColor;
  final Color? pipColor;
  final Color? shadowColor;

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
            tileColor ??
            (first
                ? const Color(0xFF20B866)
                : tile.isDouble
                ? const Color(0xFF1E88E5)
                : const Color(0xFFFFF2D2)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: accent ?? Colors.black.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? Colors.black.withValues(alpha: 0.35),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DominoPainter(
          tile: tile,
          vertical: vertical,
          first: first,
          pipColor: pipColor,
        ),
      ),
    );
  }
}

class _DominoPainter extends CustomPainter {
  const _DominoPainter({
    required this.tile,
    required this.vertical,
    required this.first,
    this.pipColor,
  });

  final _DominoTile tile;
  final bool vertical;
  final bool first;
  final Color? pipColor;

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
        Paint()
          ..color =
              pipColor ??
              (first || tile.isDouble ? Colors.white : Colors.black);
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
        oldDelegate.first != first ||
        oldDelegate.pipColor != pipColor;
  }
}

class _DominoTile {
  const _DominoTile(this.left, this.right);

  final int left;
  final int right;

  bool get isDouble => left == right;
  int get points => left + right;
  String get label => '$left-$right';
  String get key => left <= right ? '$left-$right' : '$right-$left';
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
  const _BoardPosition(
    this.dx,
    this.dy,
    this.vertical,
    this.scaleFactor,
    this.flipVisual,
    this.layoutDirection,
  );

  final double dx;
  final double dy;
  final bool vertical;
  final double scaleFactor;
  final bool flipVisual;
  final _LayoutDirection layoutDirection;
}

class _OnlineSidePreview {
  const _OnlineSidePreview({
    required this.side,
    required this.tile,
    required this.position,
    required this.color,
  });

  final _BoardSide side;
  final _DominoTile tile;
  final _BoardPosition position;
  final Color color;
}

class _LogicalBoardPosition {
  const _LogicalBoardPosition({
    required this.center,
    required this.vertical,
    required this.direction,
    required this.isFirst,
    required this.flipVisual,
  });

  final Offset center;
  final bool vertical;
  final _LayoutDirection direction;
  final bool isFirst;
  final bool flipVisual;
}

class _Starter {
  const _Starter(this.playerId, this.tile);

  final String playerId;
  final _DominoTile tile;
}

enum _BoardSide { left, right }

enum _LayoutDirection { right, down, left, up }

class _OnlineConfettiPainter extends CustomPainter {
  const _OnlineConfettiPainter({required this.progress});

  final double progress;
  static const _colors = [
    Color(0xFFFFD36B),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF20B866),
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(731);
    for (var index = 0; index < 90; index++) {
      final startX = random.nextDouble() * size.width;
      final speed = 0.65 + random.nextDouble() * 0.75;
      final phase = (progress * speed + random.nextDouble()) % 1.0;
      final y = phase * (size.height + 80) - 40;
      final sway = sin((phase * pi * 4) + index) * 20;
      final width = 5 + random.nextDouble() * 7;
      final height = 8 + random.nextDouble() * 10;
      canvas.save();
      canvas.translate(startX + sway, y);
      canvas.rotate(phase * pi * 5 + index);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(2),
        ),
        Paint()..color = _colors[index % _colors.length],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OnlineConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
