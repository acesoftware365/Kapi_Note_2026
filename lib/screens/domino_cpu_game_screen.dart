import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/audio_assets.dart';
import '../constants/domino_game_config.dart';
import '../services/audio_manager.dart';
import '../services/domino_display_settings.dart';
import '../services/kapi_cosmetics_service.dart';
import '../widgets/adaptive_domino_hand_tray.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import '../widgets/game_audio_controls.dart';
import '../widgets/domino_result_celebration.dart';
import '../widgets/kapi_centerpiece_overlay.dart';
import '../widgets/kapi_table_center_material.dart';
import '../services/player_points_service.dart';
import 'admob_variable.dart';
import 'domino_player_profile.dart';

enum DominoCpuMode { classic, draw }

enum _RoundWinner { player, cpu }

class DominoCpuGameScreen extends StatefulWidget {
  const DominoCpuGameScreen({super.key, required this.mode});

  final DominoCpuMode mode;

  @override
  State<DominoCpuGameScreen> createState() => _DominoCpuGameScreenState();
}

class _DominoCpuGameScreenState extends State<DominoCpuGameScreen>
    with TickerProviderStateMixin {
  static const Color _redTop = Color(0xFF6D0907);
  static const Color _navyBottom = Color(0xFF071524);
  static const Color _gold = Color(0xFFFFD36B);
  static const Duration _cpuThinkingDelay = Duration(seconds: 3);
  static int get _targetScore => DominoGameConfig.targetScore;

  final Random _random = Random();
  final ScrollController _playerHandScrollController = ScrollController();
  late final AnimationController _confettiController;
  late final AnimationController _sideChoicePulse;
  DominoPlayerProfile _profile = const DominoPlayerProfile(
    initials: 'JP',
    countryCode: 'US',
    code: '000000',
    avatarKey: 'person',
  );

  List<_DominoTile> _playerHand = [];
  List<_DominoTile> _cpuHand = [];
  List<_DominoTile> _pool = [];
  List<_BoardDomino> _board = [];
  int _playerScore = 0;
  int _cpuScore = 0;
  int _profilePoints = 0;
  int _roundNumber = 0;
  bool _isPlayerTurn = true;
  bool _cpuThinking = false;
  bool _roundOver = false;
  bool _statusVisible = true;
  bool _isSpanish = false;
  bool _showConfetti = false;
  double _playedTileScale = 1.0;
  double _handTileScale = 1.0;
  String _status = '';
  _RoundWinner? _roundWinner;
  _RoundWinner? _previousRoundWinner;
  _TileOwner? _lastTileOwner;
  List<_DominoTile> _roundCpuTiles = [];
  List<_DominoTile> _roundPlayerTiles = [];
  _DominoTile? _sideChoiceTile;
  Completer<_BoardSide?>? _sideChoiceCompleter;
  Timer? _statusTimer;

  bool get _isDrawMode => widget.mode == DominoCpuMode.draw;

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  int? get _leftOpen => _board.isEmpty ? null : _board.first.left;
  int? get _rightOpen => _board.isEmpty ? null : _board.last.right;
  bool get _matchOver =>
      _playerScore >= _targetScore || _cpuScore >= _targetScore;

  @override
  void dispose() {
    DominoDisplaySettings.playedTileScale.removeListener(
      _handlePlayedTileScale,
    );
    DominoDisplaySettings.handTileScale.removeListener(_handleHandTileScale);
    _statusTimer?.cancel();
    if (!(_sideChoiceCompleter?.isCompleted ?? true)) {
      _sideChoiceCompleter!.complete(null);
    }
    _confettiController.dispose();
    _sideChoicePulse.dispose();
    _playerHandScrollController.dispose();
    unawaited(AudioManager.instance.stopMusic());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    DominoDisplaySettings.playedTileScale.addListener(_handlePlayedTileScale);
    DominoDisplaySettings.handTileScale.addListener(_handleHandTileScale);
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _sideChoicePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat(reverse: true);
    _loadProfile();
    _loadPlayedTileScale();
    _loadHandTileScale();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AudioManager.instance.playMusic(AudioAssets.gameplayLoop));
      unawaited(AudioManager.instance.playSfx(AudioAssets.gameStart));
      _startNewRound();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isSpanish = Localizations.localeOf(context).languageCode == 'es';
  }

  Future<void> _loadProfile() async {
    final profile = await DominoPlayerProfile.load();
    final profilePoints = await PlayerPointsService.loadLocalTotalPoints(
      profile.code,
    );
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profilePoints = profilePoints;
    });
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

  void _startNewRound() {
    _confettiController.stop();
    _confettiController.reset();
    _showConfetti = false;
    _roundNumber += 1;
    final deck = <_DominoTile>[
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++) _DominoTile(left, right),
    ]..shuffle(_random);
    _debugVerifyDeck(deck);

    _playerHand = deck.take(7).toList();
    _cpuHand = deck.skip(7).take(7).toList();
    _pool = _isDrawMode ? deck.skip(14).toList() : [];
    _board = [];
    _roundOver = false;
    _cpuThinking = false;
    _roundWinner = null;
    _lastTileOwner = null;
    _roundCpuTiles = [];
    _roundPlayerTiles = [];

    if (_previousRoundWinner == _RoundWinner.player) {
      _isPlayerTurn = true;
      _setStatus(
        _isSpanish
            ? 'Ganaste la ronda anterior. Elige tu ficha de salida.'
            : 'You won the previous round. Choose your opening tile.',
        keepVisible: true,
      );
    } else {
      final starter = _selectStarter();
      if (starter.owner == _TileOwner.player) {
        _playerHand.remove(starter.tile);
        _board.add(_BoardDomino.fromTile(starter.tile, isFirst: true));
        _lastTileOwner = _TileOwner.player;
        _isPlayerTurn = false;
        _setStatus(
          _isSpanish
              ? 'Saliste con ${starter.tile.label}'
              : 'You opened with ${starter.tile.label}',
        );
        unawaited(_playCpuTurn());
      } else {
        _cpuHand.remove(starter.tile);
        _board.add(_BoardDomino.fromTile(starter.tile, isFirst: true));
        _lastTileOwner = _TileOwner.cpu;
        _isPlayerTurn = true;
        _setStatus(
          _isSpanish
              ? 'CPU salio con ${starter.tile.label}'
              : 'CPU opened with ${starter.tile.label}',
        );
      }
    }
    setState(() {});
    _scrollPlayerHandToPlayableStart();
  }

  void _startNewMatch() {
    _playerScore = 0;
    _cpuScore = 0;
    _roundNumber = 0;
    _previousRoundWinner = null;
    _startNewRound();
  }

  void _setStatus(String message, {bool keepVisible = false}) {
    _statusTimer?.cancel();
    _status = message;
    _statusVisible = true;
    if (keepVisible) return;
    _statusTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _cpuThinking || _roundOver) return;
      setState(() => _statusVisible = false);
    });
  }

  _StartingTile _selectStarter() {
    if (_previousRoundWinner != null) {
      final owner =
          _previousRoundWinner == _RoundWinner.player
              ? _TileOwner.player
              : _TileOwner.cpu;
      final hand = owner == _TileOwner.player ? _playerHand : _cpuHand;
      return _StartingTile(owner, _bestOpeningTile(hand));
    }

    final candidates = <_StartingTile>[
      ..._playerHand.map((tile) => _StartingTile(_TileOwner.player, tile)),
      ..._cpuHand.map((tile) => _StartingTile(_TileOwner.cpu, tile)),
    ];

    candidates.sort((a, b) => _compareOpeningTiles(a.tile, b.tile));
    return candidates.first;
  }

  _DominoTile _bestOpeningTile(List<_DominoTile> hand) {
    final sorted = List<_DominoTile>.from(hand)
      ..sort((a, b) => _compareOpeningTiles(a, b));
    return sorted.first;
  }

  int _compareOpeningTiles(_DominoTile a, _DominoTile b) {
    final aDouble = a.isDouble ? 1 : 0;
    final bDouble = b.isDouble ? 1 : 0;
    if (aDouble != bDouble) return bDouble.compareTo(aDouble);
    if (a.isDouble && b.isDouble) {
      return b.left.compareTo(a.left);
    }
    return b.points.compareTo(a.points);
  }

  Future<void> _playTile(_DominoTile tile, [_BoardSide? requestedSide]) async {
    if (!_isPlayerTurn || _roundOver || _cpuThinking) return;

    final sides = _validSides(tile);
    if (sides.isEmpty) {
      unawaited(AudioManager.instance.playSfx(AudioAssets.invalidMove));
      _showMessage(_isSpanish ? 'Ficha invalida' : 'Invalid tile');
      return;
    }

    var side = requestedSide;
    if (side == null &&
        sides.length > 1 &&
        _leftOpen != null &&
        _leftOpen != _rightOpen) {
      side = await _askSideForTile(tile);
      if (side == null || !mounted || !_isPlayerTurn) return;
    }
    side ??= sides.contains(_BoardSide.right) ? _BoardSide.right : sides.first;
    if (!sides.contains(side)) return;
    final selectedSide = side;

    setState(() {
      _placeTile(tile, selectedSide);
      _playerHand.remove(tile);
      _lastTileOwner = _TileOwner.player;
      _isPlayerTurn = false;
      _setStatus(
        _isSpanish ? 'Jugaste ${tile.label}' : 'You played ${tile.label}',
      );
    });
    unawaited(
      AudioManager.instance.playSfx(
        tile.isDouble ? AudioAssets.dominoDouble : AudioAssets.dominoPlace,
      ),
    );

    if (_checkRoundEnd()) return;
    await _playCpuTurn();
  }

  Future<_BoardSide?> _askSideForTile(_DominoTile tile) async {
    final previousChoice = _sideChoiceCompleter;
    if (previousChoice != null && !previousChoice.isCompleted) {
      previousChoice.complete(null);
    }
    final choice = Completer<_BoardSide?>();
    setState(() {
      _sideChoiceTile = tile;
      _sideChoiceCompleter = choice;
    });
    try {
      return await choice.future;
    } finally {
      if (mounted && identical(_sideChoiceCompleter, choice)) {
        setState(() {
          _sideChoiceTile = null;
          _sideChoiceCompleter = null;
        });
      }
    }
  }

  void _finishSideChoice(_BoardSide? side) {
    final choice = _sideChoiceCompleter;
    if (choice == null || choice.isCompleted) return;
    choice.complete(side);
  }

  Widget _buildSideChoicePrompt() {
    final tile = _sideChoiceTile;
    if (tile == null) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('block-side-choice-prompt'),
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      decoration: BoxDecoration(
        color: const Color(0xF5101820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.62), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _DominoWidget(
            tile: tile,
            vertical: tile.isDouble,
            highlighted: false,
            color: const Color(0xFFFFF6DF),
            width: 25,
            height: 46,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _isSpanish
                  ? 'Toca la ficha roja o azul en la mesa'
                  : 'Tap the red or blue tile on the table',
              maxLines: 2,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('block-side-choice-cancel'),
            tooltip: _isSpanish ? 'Cancelar' : 'Cancel',
            visualDensity: VisualDensity.compact,
            onPressed: () => _finishSideChoice(null),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _playCpuTurn() async {
    if (_roundOver) return;
    setState(() {
      _cpuThinking = true;
      _setStatus(
        _isSpanish ? 'CPU pensando...' : 'CPU thinking...',
        keepVisible: true,
      );
    });
    await Future<void>.delayed(_cpuThinkingDelay);
    if (!mounted || _roundOver) return;

    _CpuMove? move = _findCpuMove();

    if (move == null && _isDrawMode) {
      while (_pool.isNotEmpty && move == null) {
        _cpuHand.add(_pool.removeLast());
        move = _findCpuMove();
      }
    }

    setState(() {
      if (move != null) {
        _placeTile(move.tile, move.side);
        _cpuHand.remove(move.tile);
        _lastTileOwner = _TileOwner.cpu;
        _setStatus(
          _isSpanish
              ? 'CPU jugo ${move.tile.label}'
              : 'CPU played ${move.tile.label}',
        );
      } else {
        _setStatus(_isSpanish ? 'CPU paso' : 'CPU passed');
      }
      _cpuThinking = false;
      _isPlayerTurn = true;
    });
    if (move != null) {
      unawaited(
        AudioManager.instance.playSfx(
          move.tile.isDouble
              ? AudioAssets.dominoDouble
              : AudioAssets.dominoPlace,
        ),
      );
    }
    _scrollPlayerHandToPlayableStart();

    _checkRoundEnd();
  }

  _CpuMove? _findCpuMove() {
    for (final tile in _cpuHand) {
      final sides = _validSides(tile);
      if (sides.isNotEmpty) return _CpuMove(tile, sides.first);
    }
    return null;
  }

  Future<void> _drawOrPass() async {
    if (!_isPlayerTurn || _roundOver || _cpuThinking) return;

    final playerHasMove = _playerHand.any(
      (tile) => _validSides(tile).isNotEmpty,
    );
    if (playerHasMove) {
      _showMessage(
        _isSpanish
            ? 'Tienes una ficha valida para jugar'
            : 'You have a valid tile to play',
      );
      return;
    }

    if (_isDrawMode && _pool.isNotEmpty) {
      setState(() {
        final tile = _pool.removeLast();
        _playerHand.add(tile);
        _setStatus(
          _isSpanish
              ? 'Tomaste ${tile.label} del pozo'
              : 'You drew ${tile.label}',
        );
      });
      _scrollPlayerHandToPlayableStart();
      return;
    }

    setState(() {
      _isPlayerTurn = false;
      _setStatus(_isSpanish ? 'Pasaste' : 'You passed');
    });
    unawaited(AudioManager.instance.playSfx(AudioAssets.turnNotification));
    await _playCpuTurn();
  }

  List<_BoardSide> _validSides(_DominoTile tile) {
    if (_board.isEmpty) return [_BoardSide.right];
    final sides = <_BoardSide>[];
    if (tile.left == _leftOpen || tile.right == _leftOpen) {
      sides.add(_BoardSide.left);
    }
    if (tile.left == _rightOpen || tile.right == _rightOpen) {
      sides.add(_BoardSide.right);
    }
    return sides;
  }

  void _placeTile(_DominoTile tile, _BoardSide side) {
    if (_board.isEmpty) {
      _board.add(_BoardDomino.fromTile(tile, isFirst: true));
      return;
    }

    if (side == _BoardSide.left) {
      final open = _leftOpen!;
      final oriented = tile.right == open ? tile : tile.flipped;
      _board.insert(0, _BoardDomino.fromTile(oriented));
    } else {
      final open = _rightOpen!;
      final oriented = tile.left == open ? tile : tile.flipped;
      _board.add(_BoardDomino.fromTile(oriented));
    }
    _debugVerifyBoardLinks();
  }

  void _debugVerifyDeck(List<_DominoTile> deck) {
    assert(() {
      final unique = deck.map((tile) => tile.key).toSet();
      if (deck.length != 28 || unique.length != 28) {
        debugPrint(
          'Kapi domino deck error: expected 28 unique tiles, '
          'got ${deck.length} tiles and ${unique.length} unique.',
        );
      }
      return true;
    }());
  }

  void _debugVerifyBoardLinks() {
    assert(() {
      for (var index = 0; index < _board.length - 1; index++) {
        final current = _board[index];
        final next = _board[index + 1];
        if (current.right != next.left) {
          debugPrint(
            'Kapi board link error at $index: '
            '${current.tile.label} does not connect to ${next.tile.label}.',
          );
        }
      }
      return true;
    }());
  }

  bool _checkRoundEnd() {
    String? result;
    _RoundWinner? winner;
    var playerGained = 0;
    if (_playerHand.isEmpty) {
      final gained = _cpuHand.fold<int>(0, (sum, tile) => sum + tile.points);
      _playerScore += gained;
      playerGained = gained;
      winner = _RoundWinner.player;
      result =
          _isSpanish
              ? 'Ganaste la ronda +$gained'
              : 'You won the round +$gained';
    } else if (_cpuHand.isEmpty) {
      final gained = _playerHand.fold<int>(0, (sum, tile) => sum + tile.points);
      _cpuScore += gained;
      winner = _RoundWinner.cpu;
      result =
          _isSpanish
              ? 'CPU gana la ronda +$gained'
              : 'CPU won the round +$gained';
    } else if (_isBlocked()) {
      final playerPoints = _playerHand.fold<int>(
        0,
        (sum, tile) => sum + tile.points,
      );
      final cpuPoints = _cpuHand.fold<int>(0, (sum, tile) => sum + tile.points);
      final playerWinsBlock =
          playerPoints < cpuPoints ||
          (playerPoints == cpuPoints && _lastTileOwner == _TileOwner.player);
      final combinedPoints = playerPoints + cpuPoints;
      if (playerWinsBlock) {
        final gained = combinedPoints;
        _playerScore += gained;
        playerGained = gained;
        winner = _RoundWinner.player;
        result =
            _isSpanish
                ? 'Ronda bloqueada: ganaste +$gained'
                : 'Blocked round: you won +$gained';
      } else {
        final gained = combinedPoints;
        _cpuScore += gained;
        winner = _RoundWinner.cpu;
        result =
            _isSpanish
                ? 'Ronda bloqueada: CPU gana +$gained'
                : 'Blocked round: CPU won +$gained';
      }
    }

    if (result == null) return false;
    setState(() {
      _roundOver = true;
      _roundWinner = winner;
      _previousRoundWinner = winner;
      _roundCpuTiles = List<_DominoTile>.from(_cpuHand);
      _roundPlayerTiles = List<_DominoTile>.from(_playerHand);
      _cpuThinking = false;
      _setStatus(result!, keepVisible: true);
    });
    unawaited(
      AudioManager.instance.playSfx(
        _matchOver ? AudioAssets.gameOver : AudioAssets.roundWin,
      ),
    );
    if (_matchOver) {
      unawaited(
        AudioManager.instance.playMusic(
          winner == _RoundWinner.player
              ? AudioAssets.victoryMusic
              : AudioAssets.defeatMusic,
          loop: false,
        ),
      );
    }
    if (_matchOver) {
      setState(() => _showConfetti = true);
      _confettiController
        ..reset()
        ..repeat(period: const Duration(milliseconds: 1800));
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _matchOver) {
          _confettiController.stop();
          setState(() => _showConfetti = false);
        }
      });
    } else {
      _confettiController.stop();
      _confettiController.reset();
      _showConfetti = false;
    }
    unawaited(
      PlayerPointsService.recordRound(
        code: _profile.code,
        publicId: _profile.publicId,
        initials: _profile.initials,
        countryCode: _profile.countryCode,
        mode: _isDrawMode ? 'draw_pool' : 'classic',
        pointsEarned: playerGained,
        playerScore: _playerScore,
        cpuScore: _cpuScore,
        wonRound: winner == _RoundWinner.player,
      ),
    );
    return true;
  }

  bool _isBlocked() {
    if (_isDrawMode && _pool.isNotEmpty) return false;
    final playerCanPlay = _playerHand.any(
      (tile) => _validSides(tile).isNotEmpty,
    );
    final cpuCanPlay = _cpuHand.any((tile) => _validSides(tile).isNotEmpty);
    return !playerCanPlay && !cpuCanPlay;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
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
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, max(10, bottomPadding)),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 10),
                Expanded(child: _buildTable()),
                AnchoredAdaptiveBannerAd(
                  adUnitId: _adUnitId,
                  margin: const EdgeInsets.only(top: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final title =
        _isDrawMode
            ? (_isSpanish ? 'Control con pozo' : 'Draw / Pool')
            : 'Block beta';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/start-game',
                  arguments: {'resumeClassicGame': !_matchOver},
                );
              },
              tooltip: _isSpanish ? 'Inicio del juego' : 'Game home',
              icon: const Icon(Icons.home_rounded, color: Colors.white),
            ),
            Expanded(
              child: Center(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/game',
                      arguments: {'fromDominoGame': true},
                    );
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(_isSpanish ? 'Apuntes' : 'Notes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: _gold.withValues(alpha: 0.45)),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/kapi-store'),
              tooltip: _isSpanish ? 'Personalizar' : 'Personalize',
              icon: const Icon(Icons.palette_rounded, color: Colors.white),
            ),
            IconButton(
              onPressed: _showQuickOptions,
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
            ),
          ],
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  void _showQuickOptions() {
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
                      unawaited(_confirmEndCpuGame());
                    },
                    icon: const Icon(Icons.exit_to_app_rounded),
                    label: Text(_isSpanish ? 'Terminar partida' : 'End game'),
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

  Future<void> _confirmEndCpuGame() async {
    final endGame = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(_isSpanish ? 'Terminar partida' : 'End game'),
            content: Text(
              _isSpanish
                  ? 'Se perdera el progreso de esta partida contra CPU.'
                  : 'Progress in this CPU match will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_isSpanish ? 'Terminar' : 'End game'),
              ),
            ],
          ),
    );
    if (endGame != true || !mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/start-game',
      (route) => route.isFirst,
    );
  }

  Widget _buildTable() {
    final tableStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.table,
    );
    final dominoStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.domino,
    );
    final compact = MediaQuery.sizeOf(context).width < 520;
    final handHeight = 78.0 * _handTileScale;
    const handBottom = 8.0;
    final statusBottom = handHeight + handBottom + 10;
    final showPassAction = _shouldShowPassAction;
    return Container(
      decoration: BoxDecoration(
        color: tableStyle.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: KapiTableCenterMaterial(
                fallbackColor: tableStyle.primary,
                assetPath: tableStyle.previewAsset,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: KapiCenterpieceOverlay()),
          // Keep the table frame above the table material but below every
          // game control. A foregroundDecoration used to paint this border
          // over the profile cards and cut them with a horizontal gold line.
          Positioned.fill(
            key: const ValueKey('block-table-frame-layer'),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: tableStyle.secondary, width: 8),
                ),
              ),
            ),
          ),
          Positioned(
            key: const ValueKey('block-table-profile-layer'),
            top: -6,
            left: 8,
            right: 8,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildProfileBadge(isCpu: false, compact: compact),
                  ),
                ),
                const SizedBox(width: 8),
                _buildRoundCenterBadge(compact: compact),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildProfileBadge(isCpu: true, compact: compact),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: compact ? 42 : 66,
            right: 18,
            child: _buildCpuHandPreview(compact: compact),
          ),
          if (_isDrawMode)
            Positioned(right: 12, bottom: 124, child: _buildPoolBadge()),
          Positioned.fill(
            top: compact ? 48 : 62,
            left: 12,
            right: 12,
            bottom: statusBottom + 34,
            child: _BoardView(
              board: _board,
              centerTileScale: 1.0,
              playedTileScale: _playedTileScale,
              dominoColor: dominoStyle.primary,
              dominoPipColor: dominoStyle.secondary,
              sideChoiceTile: _sideChoiceTile,
              sideChoicePulse: _sideChoicePulse,
              onSideChoice: _finishSideChoice,
            ),
          ),
          Positioned(
            left: -2,
            right: -2,
            bottom: handBottom,
            child: _buildPlayerHandArea(handHeight),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: statusBottom,
            child: _buildStatusBar(showPassAction: showPassAction),
          ),
          if (_sideChoiceTile != null)
            Positioned(
              top: compact ? 2 : 8,
              left: 8,
              right: 8,
              child: Center(child: _buildSideChoicePrompt()),
            ),
          if (_roundOver && _matchOver && _showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder:
                      (context, _) => CustomPaint(
                        painter: _ConfettiPainter(
                          progress: _confettiController.value,
                        ),
                      ),
                ),
              ),
            ),
          if (_roundOver)
            Positioned.fill(
              child: DominoResultCelebration(
                showConfetti: _matchOver,
                child: _buildRoundOverCard(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundCenterBadge({bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        // Solid enough to mask the table frame when the badge overlaps the
        // top edge. This keeps the round card visually above the table.
        color: const Color(0xFF211B18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isSpanish ? 'Ronda $_roundNumber' : 'Round $_roundNumber',
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            _isSpanish ? 'Meta $_targetScore' : 'Goal $_targetScore',
            maxLines: 1,
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

  Widget _buildProfileBadge({required bool isCpu, bool compact = false}) {
    final title = isCpu ? 'CPU' : _profile.initials;
    final score = isCpu ? _cpuScore : _playerScore;
    final tierVisual = DominoTierVisual.fromScore(
      isCpu ? 0 : _profilePoints,
      ranked: !isCpu,
    );
    final icon = isCpu ? Icons.smart_toy_rounded : _profile.icon;
    final color =
        isCpu
            ? const Color(0xFF795548)
            : tierVisual.avatarBackground(_profile.color);
    final isActive = (_cpuThinking && isCpu) || (_isPlayerTurn && !isCpu);
    final borderColor =
        isActive
            ? _gold
            : (tierVisual.isRanked
                ? tierVisual.frameColor()
                : Colors.white.withValues(alpha: 0.18));
    final flag = KapiCosmeticsService.instance.equipped(KapiCosmeticType.flag);

    return Semantics(
      button: true,
      label:
          isCpu
              ? (_isSpanish ? 'Abrir perfil de CPU' : 'Open CPU profile')
              : (_isSpanish ? 'Abrir tu perfil' : 'Open your profile'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(isCpu ? 'block-profile-cpu' : 'block-profile-player'),
          onTap: () => _showBlockPlayerProfile(isCpu: isCpu),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 7 : 8,
            ),
            decoration: BoxDecoration(
              // Profile cards sit above the table edge, so their surface must
              // be opaque; otherwise the gold frame remains visible through
              // the card and appears to cut the profile in half.
              color:
                  isActive ? const Color(0xFF2B211C) : const Color(0xFF211B18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isActive ? 1.4 : 1),
              boxShadow:
                  tierVisual.shadows(active: isActive).isEmpty
                      ? null
                      : tierVisual.shadows(active: isActive),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: compact ? 34 : 42,
                  height: compact ? 34 : 42,
                  decoration: BoxDecoration(
                    gradient:
                        tierVisual.isRanked
                            ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [tierVisual.accent, color],
                            )
                            : null,
                    color: tierVisual.isRanked ? null : color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tierVisual.frameColor(active: isActive),
                    ),
                    boxShadow:
                        tierVisual.isRanked
                            ? [
                              BoxShadow(
                                color: tierVisual.accent.withValues(
                                  alpha: 0.24,
                                ),
                                blurRadius: compact ? 8 : 12,
                              ),
                            ]
                            : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      isCpu
                          ? Icon(
                            icon,
                            color: Colors.white,
                            size: compact ? 20 : 24,
                          )
                          : DominoAvatarVisual(
                            avatarKey: _profile.avatarKey,
                            fallbackIcon: icon,
                            backgroundColor: color,
                          ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !isCpu && flag.id != 'flag_none'
                            ? '${flag.emoji} $title'
                            : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 13 : 15,
                        ),
                      ),
                      Text(
                        '$score/$_targetScore pts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 10 : 11,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 2),
                        _buildTierChip(
                          isCpu && _isSpanish
                              ? 'No clasificatorio'
                              : tierVisual.label,
                          tierVisual,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _countryFlag(String countryCode) {
    final normalized = countryCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '🌐';
    return String.fromCharCodes(
      normalized.codeUnits.map((character) => character + 127397),
    );
  }

  Widget _profileInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockPlayerProfile({required bool isCpu}) async {
    final tier = DominoTierVisual.fromScore(
      isCpu ? 0 : _profilePoints,
      ranked: !isCpu,
    );
    final accent = isCpu ? const Color(0xFFFF6B6B) : const Color(0xFF64B5F6);
    final name = isCpu ? 'CPU' : _profile.initials;
    final avatarKey = isCpu ? 'robot' : _profile.avatarKey;
    final avatarColor =
        isCpu ? const Color(0xFF795548) : tier.avatarBackground(_profile.color);
    final tiles = isCpu ? _cpuHand.length : _playerHand.length;
    final matchScore = isCpu ? _cpuScore : _playerScore;
    final publicId = isCpu ? 'CPU-BLOCK' : _profile.publicId;
    final country = isCpu ? 'CPU' : _profile.countryCode;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      builder: (sheetContext) {
        return Container(
          key: ValueKey(
            isCpu ? 'block-cpu-profile-sheet' : 'block-player-profile-sheet',
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          decoration: BoxDecoration(
            color: const Color(0xFA101923),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: accent, width: 2.5)),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 24),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isCpu ? Icons.smart_toy_rounded : Icons.badge_rounded,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCpu
                            ? (_isSpanish ? 'Perfil de CPU' : 'CPU profile')
                            : (_isSpanish ? 'Tu perfil' : 'Your profile'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                    ),
                  ],
                ),
                Container(
                  key: const ValueKey('block-player-avatar-large'),
                  width: 122,
                  height: 122,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: tier.accent, width: 3),
                    boxShadow: tier.shadows(active: true),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: DominoAvatarVisual(
                    avatarKey: avatarKey,
                    fallbackIcon:
                        isCpu ? Icons.smart_toy_rounded : _profile.icon,
                    backgroundColor: avatarColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isCpu ? name : '${_countryFlag(country)}  $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  publicId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _profileInfoTile(
                        icon: tier.icon,
                        label: _isSpanish ? 'Nivel' : 'Tier',
                        value: isCpu ? 'CPU' : '${tier.label} ${tier.level}',
                        accent: tier.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _profileInfoTile(
                        icon: Icons.stars_rounded,
                        label: _isSpanish ? 'Puntos' : 'Points',
                        value: isCpu ? '—' : '$_profilePoints',
                        accent: _gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _profileInfoTile(
                        icon: Icons.scoreboard_rounded,
                        label: _isSpanish ? 'Partida' : 'Match',
                        value: '$matchScore/$_targetScore',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _profileInfoTile(
                        icon: Icons.view_week_rounded,
                        label: _isSpanish ? 'Fichas' : 'Tiles',
                        value: '$tiles',
                        accent: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTierChip(String tier, DominoTierVisual visual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.accent.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, color: visual.accent, size: 11),
          const SizedBox(width: 3),
          Text(
            tier,
            style: TextStyle(
              color: visual.accent,
              fontSize: tier.length > 10 ? 9 : 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCpuHandPreview({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < min(_cpuHand.length, 7); i++)
          Container(
            width: compact ? 16 : 22,
            height: compact ? 32 : 42,
            margin: EdgeInsets.only(left: compact ? 3 : 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
      ],
    );
  }

  Widget _buildPoolBadge() {
    return Container(
      width: 98,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: _isPlayerTurn && _isDrawMode ? 0.44 : 0.18,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _isPlayerTurn && _isDrawMode
                  ? _gold.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '${_pool.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  bool get _shouldShowPassAction {
    if (!_isPlayerTurn || _roundOver || _cpuThinking) return false;
    return !_playerHand.any((tile) => _validSides(tile).isNotEmpty);
  }

  Widget _buildStatusBar({bool showPassAction = false}) {
    final visible = _statusVisible || showPassAction;
    final statusText =
        showPassAction
            ? (_isDrawMode && _pool.isNotEmpty
                ? (_isSpanish ? 'Toma del pozo.' : 'Draw from pool.')
                : (_isSpanish ? 'Sin jugada.' : 'No move.'))
            : _status;
    final actionLabel =
        _isDrawMode && _pool.isNotEmpty
            ? (_isSpanish ? 'Pozo' : 'Pool')
            : (_isSpanish ? 'Paso' : 'Pass');
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          offset: visible ? Offset.zero : const Offset(0, 0.18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.44),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _cpuThinking
                        ? (_isSpanish ? 'CPU' : 'CPU')
                        : (_isPlayerTurn
                            ? (_isSpanish ? 'Tu turno' : 'Your turn')
                            : 'CPU'),
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (showPassAction) ...[
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _drawOrPass,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: _gold.withValues(alpha: 0.38)),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerHandArea(double height) {
    return SizedBox(height: height, child: _buildPlayerHand(height));
  }

  Widget _buildPlayerHand(double height) {
    final dominoStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.domino,
    );
    final displayHand = _orderedPlayerHandForDisplay();
    return AdaptiveDominoHandTray(
      key: const ValueKey('block-adaptive-hand-tray'),
      dominoColor: dominoStyle.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        child: ListView.separated(
          controller: _playerHandScrollController,
          scrollDirection: Axis.horizontal,
          itemCount: displayHand.length,
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            final tile = displayHand[index];
            final playable =
                _isPlayerTurn && !_cpuThinking && _validSides(tile).isNotEmpty;
            return GestureDetector(
              onTap: () => _playTile(tile),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: playable || _roundOver ? 1 : 0.55,
                child: _DominoWidget(
                  tile: tile,
                  vertical: true,
                  highlighted: playable,
                  color: dominoStyle.primary,
                  pipColor: dominoStyle.secondary,
                  width: 52 * _handTileScale,
                  height: 60 * _handTileScale,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<_DominoTile> _orderedPlayerHandForDisplay() {
    if (!_isPlayerTurn || _cpuThinking || _roundOver) {
      return List<_DominoTile>.from(_playerHand);
    }

    final playable = <_DominoTile>[];
    final waiting = <_DominoTile>[];
    for (final tile in _playerHand) {
      if (_validSides(tile).isNotEmpty) {
        playable.add(tile);
      } else {
        waiting.add(tile);
      }
    }
    return [...playable, ...waiting];
  }

  void _scrollPlayerHandToPlayableStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_playerHandScrollController.hasClients) return;
      if (!_isPlayerTurn || _cpuThinking || _roundOver) return;
      _playerHandScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildRoundOverCard() {
    final winnerName =
        _roundWinner == _RoundWinner.cpu ? 'CPU' : _profile.initials;
    final matchWinner =
        _playerScore >= _targetScore
            ? _profile.initials
            : (_cpuScore >= _targetScore ? 'CPU' : null);
    final title =
        matchWinner == null
            ? _status
            : (_isSpanish
                ? '$matchWinner gana el juego'
                : '$matchWinner wins the game');
    return Container(
      width: min(MediaQuery.sizeOf(context).width - 54, 380),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xEE101820),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isSpanish ? 'Ganador: $winnerName' : 'Winner: $winnerName',
            style: TextStyle(
              color: _gold.withValues(alpha: 0.95),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_profile.initials} $_playerScore/$_targetScore  ·  CPU $_cpuScore/$_targetScore',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _buildRoundTilesSummary(),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _matchOver ? _startNewMatch : _startNewRound,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              _matchOver
                  ? (_isSpanish ? 'Nuevo juego' : 'New game')
                  : (_isSpanish ? 'Siguiente ronda' : 'Next round'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundTilesSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResultTileGroup(
          title: _isSpanish ? 'Fichas del CPU' : 'CPU tiles',
          tiles: _roundCpuTiles,
          emptyText:
              _isSpanish ? 'CPU no tiene fichas' : 'CPU has no tiles left',
          color: const Color(0xFF1E88E5),
        ),
        const SizedBox(height: 10),
        _buildResultTileGroup(
          title: _isSpanish ? 'Tus fichas restantes' : 'Your remaining tiles',
          tiles: _roundPlayerTiles,
          emptyText:
              _isSpanish ? 'No te quedaron fichas' : 'You have no tiles left',
          color: const Color(0xFFFFF6DF),
        ),
      ],
    );
  }

  Widget _buildResultTileGroup({
    required String title,
    required List<_DominoTile> tiles,
    required String emptyText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (tiles.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tile in tiles)
                  _DominoWidget(
                    tile: tile,
                    vertical: true,
                    highlighted: false,
                    color: color,
                    width: 24,
                    height: 38,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class ClassicDominoGameScreen extends StatelessWidget {
  const ClassicDominoGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DominoCpuGameScreen(mode: DominoCpuMode.classic);
  }
}

class DrawDominoGameScreen extends StatelessWidget {
  const DrawDominoGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6D0907), Color(0xFF071524)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFFFD36B),
                  size: 64,
                ),
                const SizedBox(height: 18),
                Text(
                  isSpanish ? 'Control con pozo' : 'Draw / Pool',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isSpanish
                      ? 'Este modo viene pronto. Por ahora prueba Block beta.'
                      : 'This mode is coming soon. For now, test Block beta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed:
                        () => Navigator.pushReplacementNamed(
                          context,
                          '/domino-block',
                        ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      isSpanish ? 'Probar Block beta' : 'Try Block beta',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView({
    required this.board,
    required this.centerTileScale,
    required this.playedTileScale,
    required this.dominoColor,
    required this.dominoPipColor,
    this.sideChoiceTile,
    this.sideChoicePulse,
    this.onSideChoice,
  });

  final List<_BoardDomino> board;
  final double centerTileScale;
  final double playedTileScale;
  final Color dominoColor;
  final Color dominoPipColor;
  final _DominoTile? sideChoiceTile;
  final Animation<double>? sideChoicePulse;
  final ValueChanged<_BoardSide>? onSideChoice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (board.isEmpty) return const SizedBox.shrink();
        final tileW =
            (constraints.maxWidth < 430 ? 38.0 : 42.0) * playedTileScale;
        final tileH = tileW * 1.86;
        final positions = _layoutBoard(
          board,
          Size(tileW, tileH),
          constraints.biggest,
        );
        final previews = <_DominoSidePreview>[];
        if (sideChoiceTile != null && board.isNotEmpty) {
          previews
            ..add(
              _previewForSide(
                tile: sideChoiceTile!,
                side: _BoardSide.left,
                currentPositions: positions,
                tileSize: Size(tileW, tileH),
                boardSize: constraints.biggest,
              ),
            )
            ..add(
              _previewForSide(
                tile: sideChoiceTile!,
                side: _BoardSide.right,
                currentPositions: positions,
                tileSize: Size(tileW, tileH),
                boardSize: constraints.biggest,
              ),
            );
        }
        var contentBounds = Rect.zero;
        void includePosition(_DominoPosition position) {
          final size =
              _drawSize(Size(tileW, tileH), position.vertical) *
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
            for (var i = 0; i < board.length; i++)
              Positioned(
                left: positions[i].dx,
                top: positions[i].dy,
                child: _DominoWidget(
                  tile:
                      positions[i].flipVisual
                          ? board[i].tile.flipped
                          : board[i].tile,
                  vertical: positions[i].vertical,
                  highlighted: board[i].isFirst,
                  color: dominoColor,
                  pipColor: dominoPipColor,
                  width: tileW * positions[i].scaleFactor,
                  height: tileH * positions[i].scaleFactor,
                ),
              ),
            for (final preview in previews)
              _buildSideChoicePreview(
                preview: preview,
                tileSize: Size(tileW, tileH),
              ),
          ],
        );
        if (previews.isEmpty) return content;
        return ClipRect(
          child: Transform.translate(
            offset: fitOffset,
            child: Transform.scale(
              alignment: Alignment.topLeft,
              scale: fitScale,
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSideChoicePreview({
    required _DominoSidePreview preview,
    required Size tileSize,
  }) {
    const tapPadding = 12.0;
    final visualSize =
        _drawSize(tileSize, preview.position.vertical) *
        preview.position.scaleFactor;
    final label =
        preview.side == _BoardSide.left
            ? 'Play on the red tile'
            : 'Play on the blue tile';

    return Positioned(
      left: preview.position.dx - tapPadding,
      top: preview.position.dy - tapPadding,
      child: BlockSideChoiceTapTarget(
        key: ValueKey('block-side-preview-${preview.side.name}'),
        visualWidth: visualSize.width,
        visualHeight: visualSize.height,
        tapPadding: tapPadding,
        semanticsLabel: label,
        onTap: () => onSideChoice?.call(preview.side),
        child: AnimatedBuilder(
          animation: sideChoicePulse ?? const AlwaysStoppedAnimation(0.5),
          builder: (context, child) {
            final pulse = Curves.easeInOut.transform(
              sideChoicePulse?.value ?? 0.5,
            );
            return Opacity(
              opacity: 0.58 + pulse * 0.42,
              child: Transform.scale(scale: 0.94 + pulse * 0.10, child: child),
            );
          },
          child: _DominoWidget(
            tile: preview.tile,
            vertical: preview.position.vertical,
            highlighted: true,
            color: preview.color,
            pipColor: Colors.white,
            borderColor: Colors.white,
            shadowColor: preview.color,
            width: tileSize.width * preview.position.scaleFactor,
            height: tileSize.height * preview.position.scaleFactor,
          ),
        ),
      ),
    );
  }

  _DominoSidePreview _previewForSide({
    required _DominoTile tile,
    required _BoardSide side,
    required List<_DominoPosition> currentPositions,
    required Size tileSize,
    required Size boardSize,
  }) {
    final open = side == _BoardSide.left ? board.first.left : board.last.right;
    final placed = switch (side) {
      _BoardSide.left => tile.right == open ? tile : tile.flipped,
      _BoardSide.right => tile.left == open ? tile : tile.flipped,
    };
    final hypothetical = <_BoardDomino>[
      if (side == _BoardSide.left) _BoardDomino.fromTile(placed),
      ...board,
      if (side == _BoardSide.right) _BoardDomino.fromTile(placed),
    ];
    final hypotheticalPositions = _layoutBoard(
      hypothetical,
      tileSize,
      boardSize,
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
    final position = _DominoPosition(
      candidateCenter.dx - candidateSize.width / 2,
      candidateCenter.dy - candidateSize.height / 2,
      candidate.vertical,
      candidateScale,
      candidate.flipVisual,
      candidate.layoutDirection,
    );
    return _DominoSidePreview(
      side: side,
      tile: candidate.flipVisual ? placed.flipped : placed,
      position: position,
      color:
          side == _BoardSide.left
              ? const Color(0xFFE53935)
              : const Color(0xFF1976D2),
    );
  }

  Offset _positionCenter(_DominoPosition position, Size tileSize) {
    final size = _drawSize(tileSize, position.vertical) * position.scaleFactor;
    return Offset(position.dx + size.width / 2, position.dy + size.height / 2);
  }

  List<_DominoPosition> _layoutBoard(
    List<_BoardDomino> board,
    Size tileSize,
    Size boardSize,
  ) {
    final firstIndex = board.indexWhere((domino) => domino.isFirst);
    final anchorIndex = firstIndex == -1 ? 0 : firstIndex;
    final firstVertical = board[anchorIndex].tile.isDouble;
    final logical = List<_LogicalDominoPosition?>.filled(board.length, null);

    logical[anchorIndex] = _LogicalDominoPosition(
      center: Offset.zero,
      vertical: firstVertical,
      direction: _LayoutDirection.right,
      sizeFactor: _sizeFactorFor(board[anchorIndex]),
      isCenterTile: true,
      flipVisual: false,
    );

    _layoutSide(
      board: board,
      positions: logical,
      tileSize: tileSize,
      anchorIndex: anchorIndex,
      side: _BoardSide.right,
    );
    _layoutSide(
      board: board,
      positions: logical,
      tileSize: tileSize,
      anchorIndex: anchorIndex,
      side: _BoardSide.left,
    );

    final resolved = [
      for (var index = 0; index < logical.length; index++)
        logical[index] ??
            _LogicalDominoPosition(
              center: Offset.zero,
              vertical: board[index].tile.isDouble,
              direction: _LayoutDirection.right,
              sizeFactor: _sizeFactorFor(board[index]),
              isCenterTile: board[index].isFirst,
              flipVisual: false,
            ),
    ];
    _debugVerifyBoardAlignment(resolved, tileSize);
    final bounds = _logicalBounds(resolved, tileSize);
    final safeWidth = max(1.0, boardSize.width - 12);
    final safeHeight = max(1.0, boardSize.height - 12);
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
    required List<_LogicalDominoPosition?> positions,
    required Size tileSize,
    required int anchorIndex,
    required _BoardSide side,
  }) {
    final indices =
        side == _BoardSide.right
            ? [for (var i = anchorIndex + 1; i < board.length; i++) i]
            : [for (var i = anchorIndex - 1; i >= 0; i--) i];
    if (indices.isEmpty) return;

    var direction =
        side == _BoardSide.right
            ? _LayoutDirection.right
            : _LayoutDirection.left;
    var segmentCount = 0;
    var segmentLimit = _segmentLimitFor(direction);
    var turnPending = false;
    var previous =
        positions[anchorIndex] ??
        _LogicalDominoPosition(
          center: Offset.zero,
          vertical: board[anchorIndex].tile.isDouble,
          direction: direction,
          sizeFactor: _sizeFactorFor(board[anchorIndex]),
          isCenterTile: board[anchorIndex].isFirst,
          flipVisual: false,
        );

    for (final index in indices) {
      final domino = board[index];
      if (turnPending && !domino.tile.isDouble) {
        direction = _nextDirection(direction, side);
        segmentCount = 0;
        segmentLimit = _segmentLimitFor(direction);
        turnPending = false;
      }

      final vertical = _verticalFor(domino.tile, direction);
      final currentSizeFactor = _sizeFactorFor(domino);
      final center = _nextCenter(
        previous,
        direction,
        vertical,
        currentSizeFactor,
        tileSize,
      );
      positions[index] = _LogicalDominoPosition(
        center: center,
        vertical: vertical,
        direction: direction,
        sizeFactor: currentSizeFactor,
        isCenterTile: domino.isFirst,
        flipVisual: _shouldFlipVisual(side, direction),
      );

      segmentCount++;
      if (segmentCount >= segmentLimit) {
        turnPending = true;
      }
      previous = positions[index]!;
    }
  }

  int _segmentLimitFor(_LayoutDirection direction) {
    switch (direction) {
      case _LayoutDirection.right:
      case _LayoutDirection.left:
        return 3;
      case _LayoutDirection.down:
      case _LayoutDirection.up:
        return 2;
    }
  }

  bool _verticalFor(_DominoTile tile, _LayoutDirection direction) {
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

  Offset _nextCenter(
    _LogicalDominoPosition previous,
    _LayoutDirection direction,
    bool vertical,
    double currentSizeFactor,
    Size tileSize,
  ) {
    final previousSize =
        _drawSize(tileSize, previous.vertical) * previous.sizeFactor;
    final currentSize = _drawSize(tileSize, vertical) * currentSizeFactor;
    const contactOverlap = 1.1;
    final previousRect = Rect.fromCenter(
      center: previous.center,
      width: previousSize.width,
      height: previousSize.height,
    );

    switch (direction) {
      case _LayoutDirection.right:
        final x = previousRect.right + currentSize.width / 2 - contactOverlap;
        var y = previous.center.dy;
        if (previous.direction == _LayoutDirection.up) {
          y = previousRect.top + currentSize.height / 2;
        } else if (previous.direction == _LayoutDirection.down) {
          y = previousRect.bottom - currentSize.height / 2;
        }
        return Offset(x, y);
      case _LayoutDirection.left:
        final x = previousRect.left - currentSize.width / 2 + contactOverlap;
        var y = previous.center.dy;
        if (previous.direction == _LayoutDirection.up) {
          y = previousRect.top + currentSize.height / 2;
        } else if (previous.direction == _LayoutDirection.down) {
          y = previousRect.bottom - currentSize.height / 2;
        }
        return Offset(x, y);
      case _LayoutDirection.down:
        var x = previous.center.dx;
        if (previous.direction == _LayoutDirection.right) {
          x = previousRect.right - currentSize.width / 2;
        } else if (previous.direction == _LayoutDirection.left) {
          x = previousRect.left + currentSize.width / 2;
        }
        final y = previousRect.bottom + currentSize.height / 2 - contactOverlap;
        return Offset(x, y);
      case _LayoutDirection.up:
        var x = previous.center.dx;
        if (previous.direction == _LayoutDirection.right) {
          x = previousRect.right - currentSize.width / 2;
        } else if (previous.direction == _LayoutDirection.left) {
          x = previousRect.left + currentSize.width / 2;
        }
        final y = previousRect.top - currentSize.height / 2 + contactOverlap;
        return Offset(x, y);
    }
  }

  void _debugVerifyBoardAlignment(
    List<_LogicalDominoPosition> positions,
    Size tileSize,
  ) {
    assert(() {
      for (var index = 1; index < positions.length; index++) {
        final previous = positions[index - 1];
        final current = positions[index];
        final previousSize =
            _drawSize(tileSize, previous.vertical) * previous.sizeFactor;
        final currentSize =
            _drawSize(tileSize, current.vertical) * current.sizeFactor;
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

        if (!_rectsConnect(previousRect, currentRect, current.direction)) {
          debugPrint(
            'Kapi classic alignment warning at $index: '
            'previous=${previous.direction} current=${current.direction}',
          );
        }
      }
      return true;
    }());
  }

  void _debugVerifyDrawAlignment(
    List<_DominoPosition> positions,
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

        if (!_rectsConnect(
          previousRect,
          currentRect,
          current.layoutDirection,
        )) {
          debugPrint(
            'Kapi classic draw alignment warning at $index: '
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
    bool touchesOrSlightlyOverlaps(double previousEdge, double currentEdge) {
      final delta = previousEdge - currentEdge;
      return delta.abs() <= tolerance ||
          (delta > 0 && delta <= maxVisualOverlap);
    }

    bool touchesOrSlightlyOverlapsReverse(
      double previousEdge,
      double currentEdge,
    ) {
      final delta = currentEdge - previousEdge;
      return delta.abs() <= tolerance ||
          (delta > 0 && delta <= maxVisualOverlap);
    }

    bool crossAxisAlignedX() =>
        close(previous.center.dx, current.center.dx) ||
        close(previous.left, current.left) ||
        close(previous.right, current.right);
    bool crossAxisAlignedY() =>
        close(previous.center.dy, current.center.dy) ||
        close(previous.top, current.top) ||
        close(previous.bottom, current.bottom);

    return switch (direction) {
      _LayoutDirection.right =>
        touchesOrSlightlyOverlaps(previous.right, current.left) &&
            crossAxisAlignedY(),
      _LayoutDirection.left =>
        touchesOrSlightlyOverlapsReverse(previous.left, current.right) &&
            crossAxisAlignedY(),
      _LayoutDirection.down =>
        touchesOrSlightlyOverlaps(previous.bottom, current.top) &&
            crossAxisAlignedX(),
      _LayoutDirection.up =>
        touchesOrSlightlyOverlapsReverse(previous.top, current.bottom) &&
            crossAxisAlignedX(),
    };
  }

  Rect _logicalBounds(List<_LogicalDominoPosition> positions, Size tileSize) {
    var bounds = Rect.zero;
    for (final position in positions) {
      final size = _drawSize(tileSize, position.vertical) * position.sizeFactor;
      final rect = Rect.fromCenter(
        center: position.center,
        width: size.width,
        height: size.height,
      );
      bounds = bounds == Rect.zero ? rect : bounds.expandToInclude(rect);
    }
    return bounds.inflate(4);
  }

  _DominoPosition _toDrawPosition(
    _LogicalDominoPosition position,
    Size tileSize,
    double scale,
    Offset translation,
  ) {
    final size =
        _drawSize(tileSize, position.vertical) * position.sizeFactor * scale;
    final center = position.center * scale + translation;
    return _DominoPosition(
      center.dx - size.width / 2,
      center.dy - size.height / 2,
      position.vertical,
      scale * position.sizeFactor,
      position.flipVisual,
      position.direction,
    );
  }

  Size _drawSize(Size tileSize, bool vertical) {
    return vertical ? tileSize : Size(tileSize.height, tileSize.width);
  }

  double _sizeFactorFor(_BoardDomino domino) {
    return domino.isFirst ? centerTileScale : 1.0;
  }
}

class _DominoWidget extends StatelessWidget {
  const _DominoWidget({
    required this.tile,
    required this.vertical,
    required this.highlighted,
    required this.color,
    required this.width,
    required this.height,
    this.pipColor = Colors.black87,
    this.borderColor,
    this.shadowColor = Colors.black38,
  });

  final _DominoTile tile;
  final bool vertical;
  final bool highlighted;
  final Color color;
  final double width;
  final double height;
  final Color pipColor;
  final Color? borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    final size = vertical ? Size(width, height) : Size(height, width);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              borderColor ??
              (highlighted ? const Color(0xFFFFD36B) : const Color(0xFF1F1B17)),
          width: highlighted ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DominoPainter(
          tile: tile,
          vertical: vertical,
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
    this.pipColor = Colors.black87,
  });

  final _DominoTile tile;
  final bool vertical;
  final Color pipColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pipPaint = Paint()..color = pipColor;
    final linePaint =
        Paint()
          ..color = Colors.black26
          ..strokeWidth = 1.1;

    if (vertical) {
      canvas.drawLine(
        Offset(5, size.height / 2),
        Offset(size.width - 5, size.height / 2),
        linePaint,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(0, 0, size.width, size.height / 2),
        tile.left,
        pipPaint,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
        tile.right,
        pipPaint,
      );
    } else {
      canvas.drawLine(
        Offset(size.width / 2, 5),
        Offset(size.width / 2, size.height - 5),
        linePaint,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(0, 0, size.width / 2, size.height),
        tile.left,
        pipPaint,
      );
      _drawPips(
        canvas,
        Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
        tile.right,
        pipPaint,
      );
    }
  }

  void _drawPips(Canvas canvas, Rect rect, int value, Paint paint) {
    if (value == 0) return;
    final r = min(rect.width, rect.height) * 0.075;
    final left = rect.left + rect.width * 0.28;
    final centerX = rect.left + rect.width * 0.5;
    final right = rect.left + rect.width * 0.72;
    final top = rect.top + rect.height * 0.25;
    final centerY = rect.top + rect.height * 0.5;
    final bottom = rect.top + rect.height * 0.75;

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
      6 => [
        Offset(left, top),
        Offset(right, top),
        Offset(left, centerY),
        Offset(right, centerY),
        Offset(left, bottom),
        Offset(right, bottom),
      ],
      _ => <Offset>[],
    };
    for (final point in points) {
      canvas.drawCircle(point, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DominoPainter oldDelegate) {
    return oldDelegate.tile != tile ||
        oldDelegate.vertical != vertical ||
        oldDelegate.pipColor != pipColor;
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;
  static const _colors = [
    Color(0xFFFFD36B),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFFF6DF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const pieces = 96;
    for (var index = 0; index < pieces; index++) {
      final seed = index * 37.0;
      final startX = ((seed * 17.0) % 1000) / 1000 * size.width;
      final speed = 0.55 + ((index * 11) % 45) / 100;
      final drift = sin(progress * pi * 2 + index) * (8 + index % 18);
      final yProgress = (progress * speed + ((index * 29) % 100) / 100) % 1.0;
      final x = startX + drift;
      final y = yProgress * (size.height + 90) - 45;
      final width = 5.0 + (index % 4);
      final height = 9.0 + (index % 5);
      final rotation = progress * pi * (2 + index % 4) + index;

      paint.color = _colors[index % _colors.length].withValues(alpha: 0.92);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
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
}

class _BoardDomino {
  const _BoardDomino({required this.tile, this.isFirst = false});

  final _DominoTile tile;
  final bool isFirst;

  int get left => tile.left;
  int get right => tile.right;

  factory _BoardDomino.fromTile(_DominoTile tile, {bool isFirst = false}) {
    return _BoardDomino(tile: tile, isFirst: isFirst);
  }
}

class _DominoPosition extends Offset {
  const _DominoPosition(
    super.dx,
    super.dy,
    this.vertical,
    this.scaleFactor,
    this.flipVisual,
    this.layoutDirection,
  );
  final bool vertical;
  final double scaleFactor;
  final bool flipVisual;
  final _LayoutDirection layoutDirection;
}

class _DominoSidePreview {
  const _DominoSidePreview({
    required this.side,
    required this.tile,
    required this.position,
    required this.color,
  });

  final _BoardSide side;
  final _DominoTile tile;
  final _DominoPosition position;
  final Color color;
}

/// Makes the complete painted red/blue Block preview respond to a tap,
/// including a small margin around the animated domino.
class BlockSideChoiceTapTarget extends StatelessWidget {
  const BlockSideChoiceTapTarget({
    super.key,
    required this.visualWidth,
    required this.visualHeight,
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
    this.tapPadding = 12,
  });

  final double visualWidth;
  final double visualHeight;
  final double tapPadding;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: visualWidth + tapPadding * 2,
        height: visualHeight + tapPadding * 2,
        child: Center(child: child),
      ),
    ),
  );
}

class _LogicalDominoPosition {
  const _LogicalDominoPosition({
    required this.center,
    required this.vertical,
    required this.direction,
    required this.sizeFactor,
    required this.isCenterTile,
    required this.flipVisual,
  });

  final Offset center;
  final bool vertical;
  final _LayoutDirection direction;
  final double sizeFactor;
  final bool isCenterTile;
  final bool flipVisual;
}

class _StartingTile {
  const _StartingTile(this.owner, this.tile);
  final _TileOwner owner;
  final _DominoTile tile;
}

class _CpuMove {
  const _CpuMove(this.tile, this.side);
  final _DominoTile tile;
  final _BoardSide side;
}

enum _BoardSide { left, right }

enum _TileOwner { player, cpu }

enum _LayoutDirection { right, down, left, up }
