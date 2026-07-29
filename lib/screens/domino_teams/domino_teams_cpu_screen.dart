import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/audio_assets.dart';
import '../../services/audio_manager.dart';
import '../../services/domino_display_settings.dart';
import '../../services/kapi_cosmetics_service.dart';
import '../../services/player_points_service.dart';
import '../../services/team_domino_chain_validator.dart';
import '../../services/teams_online_service.dart';
import '../../widgets/anchored_adaptive_banner_ad.dart';
import '../../widgets/adaptive_domino_hand_tray.dart';
import '../../widgets/domino_result_celebration.dart';
import '../../widgets/domino_special_play_effect.dart';
import '../../widgets/game_audio_controls.dart';
import '../../widgets/kapi_centerpiece_overlay.dart';
import '../../widgets/kapi_table_center_material.dart';
import '../admob_variable.dart';
import '../domino_player_profile.dart';
import 'team_board_layout.dart';
import 'team_scoring_rules.dart';

class DominoTeamsCpuScreen extends StatefulWidget {
  const DominoTeamsCpuScreen({
    super.key,
    this.onlineGameId,
    this.onlinePlayerId,
    this.partnerDisplayNameForTesting,
  }) : assert(
         (onlineGameId == null) == (onlinePlayerId == null),
         'Online game and player IDs must be provided together.',
       );

  final String? onlineGameId;
  final String? onlinePlayerId;

  @visibleForTesting
  final String? partnerDisplayNameForTesting;

  @visibleForTesting
  static bool resetAllowedFor({required String? onlineGameId}) =>
      onlineGameId == null;

  @visibleForTesting
  static const String completedMatchGameModeRoute = '/start-game';

  @visibleForTesting
  static bool shouldApplyAbandonmentPenalty({required bool matchFinished}) =>
      !matchFinished;

  @visibleForTesting
  static ({int player, String messageId})? cpuRoundPassReactionFor({
    required int scoringPlayer,
    required double chanceRoll,
    required int messageVariant,
    required bool useLeftRival,
  }) {
    // Keep reactions occasional so the CPU feels present without becoming
    // repetitive. Online games use the real players' quick messages instead.
    if (chanceRoll >= 0.55) return null;
    final humanScored = scoringPlayer == 0;
    final messages =
        humanScored
            ? const ['wellPlayed', 'wow', 'fire']
            : const ['fire', 'laugh', 'wow'];
    return (
      player: humanScored ? (useLeftRival ? 1 : 3) : scoringPlayer,
      messageId: messages[messageVariant.abs() % messages.length],
    );
  }

  @visibleForTesting
  static bool coordinatesFallbackReactions({
    required String currentPlayerId,
    required List<TeamsOnlinePlayer> players,
  }) {
    final currentIdentity = TeamsOnlineRoster.identityKey(currentPlayerId);
    final humanIdentities = players
      .where((player) => !player.isCpu)
      .map((player) => TeamsOnlineRoster.identityKey(player.id))
      .where((identity) => identity.isNotEmpty)
      .toList(growable: false)..sort();
    return humanIdentities.isNotEmpty &&
        currentIdentity == humanIdentities.first;
  }

  @override
  State<DominoTeamsCpuScreen> createState() => _DominoTeamsCpuScreenState();
}

class _DominoTeamsCpuScreenState extends State<DominoTeamsCpuScreen>
    with SingleTickerProviderStateMixin {
  static const bool _autoPlayOnlineForTesting = bool.fromEnvironment(
    'KAPI_AUTO_PLAY_ONLINE',
  );
  // Development stays fast to test; distributable release builds use the
  // agreed production goal of 100 points.
  static const _target = kReleaseMode ? 100 : 30;
  static const _layoutEngine = TeamBoardLayoutEngine();
  final _random = Random();
  final List<List<_TeamTile>> _hands = List.generate(4, (_) => []);
  final List<_TeamTile> _board = [];
  final List<int> _teamScores = [0, 0];
  _TeamTile? _openingTile;
  _TeamTile? _lastPlacedTile;
  int _openingPlayer = 0;
  int _turn = 0;
  int _round = 1;
  int _consecutivePasses = 0;
  int? _lastPlayerToPlay;
  int? _previousDominator;
  int? _resultWinnerPlayer;
  int _resultPoints = 0;
  String? _resultSpecial;
  bool _resultBlocked = false;
  bool _roundOver = false;
  bool _showFinalHand = false;
  bool _cpuBusy = false;
  _TeamTile? _sideChoiceTile;
  Completer<_Side?>? _sideChoiceCompleter;
  _Side? _selectedSideChoice;
  DominoSpecialEffectKind? _specialEffectKind;
  String? _specialEffectPlayerName;
  int _specialEffectSequence = 0;
  bool _blockResultPending = false;
  int? _quickChatNoticePlayer;
  String? _quickChatNoticeId;
  String? _quickChatNoticeEmoji;
  int _quickChatNoticeSequence = 0;
  int _onlineQuickChatSequence = -1;
  int _gameGeneration = 0;
  String _status = 'Preparando la mesa...';
  DominoPlayerProfile? _profile;
  int _profilePoints = 0;
  late final AnimationController _sideChoicePulse;
  Timer? _specialEffectTimer;
  Timer? _quickChatNoticeTimer;
  DateTime? _lastQuickChatSentAt;
  TeamsOnlineService? _onlineService;
  StreamSubscription<TeamsOnlineGame>? _onlineSubscription;
  Timer? _onlineCpuTimer;
  Timer? _onlineHumanTimer;
  Timer? _onlineNextRoundTimer;
  List<TeamsOnlinePlayer> _onlinePlayers = const [];
  int _onlineGlobalSeat = 0;
  int _onlineRevision = -1;
  int _onlineTarget = _target;
  int _onlineCpuScheduledRevision = -1;
  int _onlineHumanScheduledRevision = -1;
  int _onlineNextRoundScheduledRevision = -1;
  int? _onlineRecordedEndRevision;
  bool _allowOnlinePop = false;
  bool _leavingOnline = false;
  double _playedTileScale = 1.0;
  double _handTileScale = 1.0;

  // In iPad floating/windowed modes the compact width can fall below 600 pt.
  // Its long side still identifies a tablet, which keeps the Settings dialog
  // from using the auto-dismissed phone sheet.
  bool get _isTablet {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide >= 550 || size.longestSide >= 1100;
  }

  double get _effectiveHandTileScale =>
      _handTileScale * (_isTablet ? 1.18 : 1.0);

  bool get _isOnline => widget.onlineGameId != null;
  bool get _resetAllowed =>
      DominoTeamsCpuScreen.resetAllowedFor(onlineGameId: widget.onlineGameId);
  int get _scoreTarget => _isOnline ? _onlineTarget : _target;

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';
  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;
  int _teamFor(int player) => player.isEven ? 0 : 1;
  int get _leftOpen => _board.first.left;
  int get _rightOpen => _board.last.right;

  bool _openingIsVertical(_TeamTile opening) {
    final rivalsOpened = _openingPlayer.isOdd;
    return opening.isDouble ? rivalsOpened : !rivalsOpened;
  }

  bool _openingChainStartsHorizontally(_TeamTile opening) {
    final openingVertical = _openingIsVertical(opening);
    return opening.isDouble ? openingVertical : !openingVertical;
  }

  bool _boardConnectionsAreValid() {
    return TeamDominoChainValidator.isValidChain(
      _board.map((tile) => (left: tile.left, right: tile.right)),
    );
  }

  @override
  void initState() {
    super.initState();
    KapiCosmeticsService.instance.addListener(_handleCosmeticsChanged);
    DominoDisplaySettings.playedTileScale.addListener(_handlePlayedTileScale);
    DominoDisplaySettings.handTileScale.addListener(_handleHandTileScale);
    _sideChoicePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat(reverse: true);
    unawaited(_loadPlayedTileScale());
    unawaited(_loadHandTileScale());
    unawaited(_loadProfile());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AudioManager.instance.playMusic(AudioAssets.gameplayLoop));
      unawaited(AudioManager.instance.playSfx(AudioAssets.gameStart));
      if (_isOnline) {
        _subscribeOnlineGame();
      } else {
        _startRound();
      }
    });
  }

  @override
  void dispose() {
    KapiCosmeticsService.instance.removeListener(_handleCosmeticsChanged);
    DominoDisplaySettings.playedTileScale.removeListener(
      _handlePlayedTileScale,
    );
    DominoDisplaySettings.handTileScale.removeListener(_handleHandTileScale);
    _specialEffectTimer?.cancel();
    _quickChatNoticeTimer?.cancel();
    _onlineCpuTimer?.cancel();
    _onlineHumanTimer?.cancel();
    _onlineNextRoundTimer?.cancel();
    _onlineSubscription?.cancel();
    final sideChoiceCompleter = _sideChoiceCompleter;
    if (sideChoiceCompleter != null && !sideChoiceCompleter.isCompleted) {
      sideChoiceCompleter.complete(null);
    }
    _sideChoicePulse.dispose();
    unawaited(AudioManager.instance.stopMusic());
    super.dispose();
  }

  void _handleCosmeticsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPlayedTileScale() async {
    final value = await DominoDisplaySettings.loadPlayedTileScale();
    if (mounted) setState(() => _playedTileScale = value);
  }

  void _handlePlayedTileScale() {
    if (!mounted) return;
    setState(() {
      _playedTileScale = DominoDisplaySettings.playedTileScale.value;
    });
  }

  Future<void> _loadHandTileScale() async {
    final value = await DominoDisplaySettings.loadHandTileScale();
    if (mounted) setState(() => _handTileScale = value);
  }

  void _handleHandTileScale() {
    if (!mounted) return;
    setState(() {
      _handTileScale = DominoDisplaySettings.handTileScale.value;
    });
  }

  Future<void> _loadProfile() async {
    final profile = await DominoPlayerProfile.load();
    final prefs = await SharedPreferences.getInstance();
    final points =
        prefs.getInt(
          'kapi_player_points_${profile.code.toUpperCase()}_total',
        ) ??
        0;
    if (mounted) {
      setState(() {
        _profile = profile;
        _profilePoints = points;
      });
    }
  }

  void _subscribeOnlineGame() {
    final gameId = widget.onlineGameId;
    if (gameId == null) return;
    final service = TeamsOnlineService(FirebaseFirestore.instance);
    _onlineService = service;
    _onlineSubscription = service
        .watchGame(gameId)
        .listen(
          _applyOnlineGame,
          onError: (Object error) {
            if (!mounted) return;
            _message(
              _isSpanish
                  ? 'Se perdió la conexión. Intentando reconectar...'
                  : 'Connection lost. Trying to reconnect...',
            );
          },
        );
  }

  int _relativeSeat(int globalSeat) => (globalSeat - _onlineGlobalSeat + 4) % 4;

  void _applyOnlineGame(TeamsOnlineGame game) {
    if (!mounted || game.players.length < 4) return;
    final cleanPlayerId = TeamsOnlineRoster.identityKey(widget.onlinePlayerId!);
    final globalSeat = game.players.indexWhere(
      (player) => TeamsOnlineRoster.identityKey(player.id) == cleanPlayerId,
    );
    if (globalSeat < 0) {
      _message(
        _isSpanish
            ? 'Tu puesto ya no está disponible.'
            : 'Your seat is no longer available.',
      );
      return;
    }
    _onlineGlobalSeat = globalSeat;
    final relativePlayers = <TeamsOnlinePlayer>[
      for (var relative = 0; relative < 4; relative++)
        game.players[(globalSeat + relative) % 4],
    ];
    final isNewRevision = game.revision > _onlineRevision;
    final action = game.lastAction;
    final actionType = action['type'] as String? ?? '';
    final actionGlobal = (action['player'] as num?)?.toInt();
    final actionRelative =
        actionGlobal == null ? null : (actionGlobal - globalSeat + 4) % 4;
    final quickChat = game.quickChat;
    final quickChatSequence = (quickChat['sequence'] as num?)?.toInt() ?? 0;
    final quickChatGlobal = (quickChat['player'] as num?)?.toInt();
    final quickChatRelative =
        quickChatGlobal == null ? null : (quickChatGlobal - globalSeat + 4) % 4;
    final quickChatId = quickChat['messageId'] as String?;
    final quickChatEmoji = quickChat['emoji'] as String?;
    final isNewQuickChat =
        _onlineQuickChatSequence >= 0 &&
        quickChatSequence > _onlineQuickChatSequence &&
        quickChatRelative != null &&
        quickChatId != null &&
        quickChatEmoji != null;
    final incomingBoard = <_TeamTile>[
      for (final tile in game.board) _TeamTile(tile.left, tile.right),
    ];
    if (!TeamDominoChainValidator.isValidChain(
      incomingBoard.map((tile) => (left: tile.left, right: tile.right)),
    )) {
      debugPrint(
        'KAPI_TEAMS_CHAIN_REJECTED game=${game.id} revision=${game.revision}',
      );
      _message(
        _isSpanish
            ? 'Revalidando la mesa antes de continuar...'
            : 'Revalidating the table before continuing...',
      );
      return;
    }

    setState(() {
      _onlinePlayers = relativePlayers;
      for (var relative = 0; relative < 4; relative++) {
        final global = (globalSeat + relative) % 4;
        _hands[relative]
          ..clear()
          ..addAll(
            (game.hands[global] ?? const <TeamsOnlineTile>[]).map(
              (tile) => _TeamTile(tile.left, tile.right),
            ),
          );
      }
      _board
        ..clear()
        ..addAll(incomingBoard);
      if (globalSeat.isEven) {
        _teamScores
          ..[0] = game.teamScores[0]
          ..[1] = game.teamScores[1];
      } else {
        _teamScores
          ..[0] = game.teamScores[1]
          ..[1] = game.teamScores[0];
      }
      _turn = _relativeSeat(game.turn);
      _round = game.round;
      _onlineTarget = game.targetScore;
      _openingPlayer = _relativeSeat(game.openingPlayer);
      _consecutivePasses = game.consecutivePasses;
      _lastPlayerToPlay =
          game.lastPlayerToPlay == null
              ? null
              : _relativeSeat(game.lastPlayerToPlay!);
      _previousDominator =
          game.previousDominator == null
              ? null
              : _relativeSeat(game.previousDominator!);
      _resultWinnerPlayer =
          game.resultWinnerPlayer == null
              ? null
              : _relativeSeat(game.resultWinnerPlayer!);
      _resultPoints = game.resultPoints;
      _resultSpecial = game.resultSpecial;
      _resultBlocked = game.resultBlocked;
      _roundOver = game.roundOver;
      _cpuBusy = !game.roundOver && relativePlayers[_turn].isCpu;
      _openingTile = null;
      if (game.openingTileId != null) {
        for (final tile in _board) {
          if (tile.id == game.openingTileId) {
            _openingTile = tile;
            break;
          }
        }
      }
      _openingTile ??= _board.isEmpty ? null : _board.first;
      if (actionType == 'play' && _board.isNotEmpty) {
        _lastPlacedTile = action['side'] == 'left' ? _board.first : _board.last;
      }
      _status = _onlineStatus(actionType, actionRelative, action);
      _onlineRevision = game.revision;
      _onlineQuickChatSequence = max(
        _onlineQuickChatSequence,
        quickChatSequence,
      );
      if (isNewQuickChat) {
        _quickChatNoticePlayer = quickChatRelative;
        _quickChatNoticeId = quickChatId;
        _quickChatNoticeEmoji = quickChatEmoji;
        _quickChatNoticeSequence++;
      }
    });

    if (isNewQuickChat) {
      unawaited(AudioManager.instance.playSfx(AudioAssets.turnNotification));
      final noticeSequence = _quickChatNoticeSequence;
      _quickChatNoticeTimer?.cancel();
      _quickChatNoticeTimer = Timer(const Duration(milliseconds: 3200), () {
        if (!mounted || _quickChatNoticeSequence != noticeSequence) return;
        setState(() {
          _quickChatNoticePlayer = null;
          _quickChatNoticeId = null;
          _quickChatNoticeEmoji = null;
        });
      });
    }

    if (isNewRevision) {
      if (actionType == 'pass') {
        unawaited(AudioManager.instance.playSfx(AudioAssets.dominoPass));
        _showSpecialEffect(
          DominoSpecialEffectKind.pass,
          player: actionRelative,
        );
      } else if (actionType == 'play') {
        final played = _lastPlacedTile;
        unawaited(
          AudioManager.instance.playSfx(
            played?.isDouble == true
                ? AudioAssets.dominoDouble
                : AudioAssets.dominoPlace,
          ),
        );
        if ((action['roundPassBonus'] as num?)?.toInt() case final bonus?
            when bonus > 0) {
          _showSpecialEffect(
            DominoSpecialEffectKind.roundPass,
            player: actionRelative,
          );
        }
      } else if (actionType == 'roundEnd') {
        if (action['blocked'] == true) {
          _blockResultPending = true;
          _showSpecialEffect(DominoSpecialEffectKind.blocked);
        } else if (action['special'] == 'capicua') {
          _showSpecialEffect(
            DominoSpecialEffectKind.capicua,
            player: actionRelative,
          );
        } else {
          _showSpecialEffect(
            DominoSpecialEffectKind.domino,
            player: actionRelative,
          );
        }
      }
      _maybeSendOnlinePlayerReaction(
        game: game,
        actionType: actionType,
        action: action,
      );
    }
    if (game.roundOver && _onlineRecordedEndRevision != game.revision) {
      _onlineRecordedEndRevision = game.revision;
      final winner = _resultWinnerPlayer ?? 1;
      _recordRankingRound(
        _teamFor(winner) == 0,
        _resultPoints,
        rewardKey:
            'teams-online-${widget.onlineGameId}-${game.revision}-${TeamsOnlineRoster.identityKey(widget.onlinePlayerId!)}',
      );
    }
    _scheduleOnlineCpu(game);
    _scheduleOnlineHumanForTesting(game);
  }

  String _onlineStatus(
    String actionType,
    int? player,
    Map<String, dynamic> action,
  ) {
    final name = player == null ? '' : _playerName(player);
    final roundPassBonus = (action['roundPassBonus'] as num?)?.toInt() ?? 0;
    return switch (actionType) {
      'pass' => '$name ${_isSpanish ? 'pasó' : 'passed'}',
      'play' =>
        roundPassBonus > 0
            ? '$name ${_isSpanish ? 'completó el pase redondo' : 'completed the round pass'} +$roundPassBonus'
            : '$name ${_isSpanish ? 'jugó' : 'played'} ${_tileLabel(action['tile'])}',
      'roundEnd' =>
        '$name ${action['blocked'] == true ? (_isSpanish ? 'ganó la tranca' : 'won the block') : (_isSpanish ? 'dominó' : 'dominoed')} +${action['points'] ?? 0}',
      'replacedByCpu' =>
        _isSpanish
            ? '$name ahora juega automáticamente'
            : '$name is now playing automatically',
      _ => _isSpanish ? 'Partida online' : 'Online match',
    };
  }

  String _tileLabel(Object? raw) {
    final code = (raw as num?)?.toInt();
    return code == null ? '' : '${code ~/ 10}-${code % 10}';
  }

  void _scheduleOnlineCpu(TeamsOnlineGame game) {
    if (game.roundOver || game.status != 'playing') return;
    final active = game.players[game.turn];
    if (!active.isCpu || _onlineCpuScheduledRevision == game.revision) return;
    _onlineCpuScheduledRevision = game.revision;
    _onlineCpuTimer?.cancel();
    _onlineCpuTimer = Timer(const Duration(seconds: 3), () async {
      final service = _onlineService;
      final gameId = widget.onlineGameId;
      if (!mounted || service == null || gameId == null) return;
      final applied = await service.processCpuTurn(
        gameId: gameId,
        expectedRevision: game.revision,
      );
      if (!applied && mounted && _onlineRevision == game.revision) {
        _onlineCpuScheduledRevision = -1;
        _scheduleOnlineCpu(game);
      }
    });
  }

  void _scheduleOnlineHumanForTesting(TeamsOnlineGame game) {
    if (!_autoPlayOnlineForTesting || !_isOnline) return;
    if (game.roundOver) {
      if (game.matchOver ||
          _onlineNextRoundScheduledRevision == game.revision) {
        return;
      }
      _onlineNextRoundScheduledRevision = game.revision;
      _onlineNextRoundTimer?.cancel();
      _onlineNextRoundTimer = Timer(const Duration(milliseconds: 900), () {
        final service = _onlineService;
        final gameId = widget.onlineGameId;
        if (!mounted || service == null || gameId == null) return;
        unawaited(service.nextRound(gameId));
      });
      return;
    }
    if (game.status != 'playing' ||
        game.turn != _onlineGlobalSeat ||
        game.players[game.turn].isCpu ||
        _onlineHumanScheduledRevision == game.revision) {
      return;
    }
    _onlineHumanScheduledRevision = game.revision;
    _onlineHumanTimer?.cancel();
    _onlineHumanTimer = Timer(const Duration(milliseconds: 450), () async {
      final service = _onlineService;
      final gameId = widget.onlineGameId;
      final playerId = widget.onlinePlayerId;
      if (!mounted ||
          service == null ||
          gameId == null ||
          playerId == null ||
          _onlineRevision != game.revision ||
          _turn != 0) {
        return;
      }
      _TeamTile? choice;
      List<_Side> choiceSides = const [];
      for (final tile in _hands[0]) {
        final sides = _validSides(tile);
        if (sides.isNotEmpty &&
            (choice == null || tile.points > choice.points)) {
          choice = tile;
          choiceSides = sides;
        }
      }
      if (choice == null) {
        await service.pass(gameId: gameId, playerId: playerId);
        return;
      }
      final side =
          choiceSides.contains(_Side.right) ? _Side.right : choiceSides.first;
      await service.playTile(
        gameId: gameId,
        playerId: playerId,
        tileId: choice.id,
        side: side.name,
      );
    });
  }

  void _startRound() {
    if (!_resetAllowed) return;
    _gameGeneration++;
    _cpuBusy = false;
    final deck = <_TeamTile>[
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++) _TeamTile(left, right),
    ]..shuffle(_random);
    for (var player = 0; player < 4; player++) {
      _hands[player]
        ..clear()
        ..addAll(deck.skip(player * 7).take(7));
    }
    _board.clear();
    _openingTile = null;
    _lastPlacedTile = null;
    _roundOver = false;
    _blockResultPending = false;
    _resultWinnerPlayer = null;
    _resultPoints = 0;
    _resultSpecial = null;
    _resultBlocked = false;
    _showFinalHand = false;
    _sideChoiceTile = null;
    _consecutivePasses = 0;
    _lastPlayerToPlay = null;

    if (_round == 1) {
      var bestPlayer = 0;
      var bestDouble = -1;
      for (var player = 0; player < 4; player++) {
        for (final tile in _hands[player]) {
          if (tile.isDouble && tile.left > bestDouble) {
            bestDouble = tile.left;
            bestPlayer = player;
          }
        }
      }
      _turn = bestPlayer;
      final opening = _hands[_turn].firstWhere(
        (tile) => tile.isDouble && tile.left == bestDouble,
      );
      _hands[_turn].remove(opening);
      _board.add(opening);
      _openingTile = opening;
      _lastPlacedTile = opening;
      _openingPlayer = _turn;
      _lastPlayerToPlay = _turn;
      _status =
          '${_playerName(_turn)} ${_isSpanish ? 'sale con' : 'opens'} ${opening.label}';
      _turn = (_turn + 1) % 4;
    } else {
      _turn = _previousDominator ?? 0;
      _status =
          '${_playerName(_turn)} ${_isSpanish ? 'sale como quiera' : 'may open with any tile'}';
    }
    setState(() {});
    _continueCpuTurns();
  }

  String _playerName(int player) {
    if (player == 2 && widget.partnerDisplayNameForTesting != null) {
      return widget.partnerDisplayNameForTesting!;
    }
    if (_isOnline && player >= 0 && player < _onlinePlayers.length) {
      if (player == 0) return _isSpanish ? 'Tú' : 'You';
      final onlinePlayer = _onlinePlayers[player];
      if (!onlinePlayer.isCpu ||
          onlinePlayer.replacedPlayer ||
          onlinePlayer.isFallbackOnlinePlayer) {
        final badge = KapiCosmeticsService.byId(onlinePlayer.badgeKey);
        final flag =
            badge.type == KapiCosmeticType.flag && badge.id != 'flag_none'
                ? badge.emoji
                : _countryFlag(onlinePlayer.countryCode);
        final identity = '$flag ${onlinePlayer.displayName}';
        return identity;
      }
      return switch (player) {
        1 => 'CPU R',
        2 => _isSpanish ? 'Compañero CPU' : 'Partner CPU',
        _ => 'CPU L',
      };
    }
    return switch (player) {
      0 => _isSpanish ? 'Tú' : 'You',
      1 => 'CPU R',
      2 => _isSpanish ? 'Compañero' : 'Partner',
      _ => 'CPU L',
    };
  }

  List<_Side> _validSides(_TeamTile tile) {
    if (_board.isEmpty) return const [_Side.right];
    final sides = <_Side>[];
    if (tile.left == _leftOpen || tile.right == _leftOpen) {
      sides.add(_Side.left);
    }
    if (tile.left == _rightOpen || tile.right == _rightOpen) {
      sides.add(_Side.right);
    }
    return sides;
  }

  bool _isCapicuaPlay(int player, _TeamTile tile) =>
      _board.isNotEmpty &&
      _hands[player].length == 1 &&
      !tile.isDouble &&
      _leftOpen != _rightOpen &&
      _validSides(tile).length == 2;

  _BoardSidePreview _previewForSide(
    _Side side,
    _TeamTile candidate, {
    TeamBoardLayoutEngine layoutEngine = _layoutEngine,
  }) {
    final opening = _openingTile!;
    assert(_board.isNotEmpty);
    final placed = switch (side) {
      _Side.right =>
        candidate.left == _rightOpen ? candidate : candidate.flipped,
      _Side.left =>
        candidate.right == _leftOpen ? candidate : candidate.flipped,
    };
    final hypothetical = <_TeamTile>[
      if (side == _Side.left) placed,
      ..._board,
      if (side == _Side.right) placed,
    ];
    var openingIndex = _board.indexWhere((tile) => identical(tile, opening));
    if (openingIndex < 0) openingIndex = _board.indexOf(opening);
    if (side == _Side.left) openingIndex++;
    final placements = layoutEngine.build(
      board: [
        for (final tile in hypothetical)
          TeamBoardTileSpec(isDouble: tile.isDouble),
      ],
      openingIndex: openingIndex,
      openingVertical: _openingIsVertical(opening),
      startsHorizontally: _openingChainStartsHorizontally(opening),
    );
    final placement =
        placements[side == _Side.left ? 0 : placements.length - 1];
    return _BoardSidePreview(
      side: side,
      placement: placement,
      tile: placement.flipped ? placed.flipped : placed,
      color:
          side == _Side.left
              ? const Color(0xFFE53935)
              : const Color(0xFF1976D2),
    );
  }

  void _selectSideChoice(_Side side) {
    final completer = _sideChoiceCompleter;
    if (_sideChoiceTile == null ||
        completer == null ||
        completer.isCompleted ||
        _selectedSideChoice != null) {
      return;
    }
    setState(() => _selectedSideChoice = side);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted || completer.isCompleted) return;
        completer.complete(side);
      }),
    );
  }

  void _cancelSideChoice() {
    final completer = _sideChoiceCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(null);
  }

  Widget _sideChoiceBanner() {
    final tile = _sideChoiceTile;
    if (tile == null) return const SizedBox.shrink();
    return Material(
      key: const ValueKey('teams-side-choice-banner'),
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xF7101D29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFD36B).withValues(alpha: 0.84),
            width: 1.3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 29,
              height: 50,
              child: FittedBox(child: _tileWidget(tile)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isSpanish
                    ? 'Toca la ficha roja o azul directamente en la mesa'
                    : 'Tap the red or blue tile directly on the table',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('teams-side-choice-cancel'),
              visualDensity: VisualDensity.compact,
              onPressed: _cancelSideChoice,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playHuman(_TeamTile tile) async {
    if (_turn != 0 || _roundOver || _cpuBusy) {
      return;
    }
    // A player may change their mind before choosing the red/blue end. Clear
    // the old pair of previews first, so only the newly selected tile owns
    // the active animation.
    final previousChoice = _sideChoiceCompleter;
    if (_sideChoiceTile != null && previousChoice != null) {
      setState(() {
        _sideChoiceTile = null;
        _selectedSideChoice = null;
        _sideChoiceCompleter = null;
      });
      if (!previousChoice.isCompleted) previousChoice.complete(null);
    }
    final sides = _validSides(tile);
    if (sides.isEmpty) {
      _message(
        _isSpanish
            ? 'Esa ficha no se puede jugar.'
            : 'That tile cannot be played.',
      );
      return;
    }
    var selectedSide = sides.first;
    if (_isCapicuaPlay(0, tile)) {
      selectedSide = _Side.right;
    } else if (sides.length > 1 && _leftOpen == _rightOpen) {
      // Both open ends are equivalent. Keep the game moving by using the
      // positive end: visually right on a horizontal chain, bottom on a
      // vertical chain.
      selectedSide = _Side.right;
    } else if (sides.length > 1) {
      final completer = Completer<_Side?>();
      setState(() {
        _sideChoiceTile = tile;
        _selectedSideChoice = null;
        _sideChoiceCompleter = completer;
      });
      _Side? choice;
      try {
        choice = await completer.future;
      } finally {
        // A newer tile may already have opened a different side chooser.
        // Never let this old async continuation erase the new markers.
        if (mounted && identical(_sideChoiceCompleter, completer)) {
          setState(() {
            _sideChoiceTile = null;
            _selectedSideChoice = null;
            _sideChoiceCompleter = null;
          });
        }
      }
      if (choice == null || !mounted || _turn != 0) return;
      selectedSide = choice;
    }
    if (_isOnline) {
      final accepted = await _onlineService!.playTile(
        gameId: widget.onlineGameId!,
        playerId: widget.onlinePlayerId!,
        tileId: tile.id,
        side: selectedSide.name,
      );
      if (!accepted && mounted) {
        _message(
          _isSpanish
              ? 'La jugada cambió. Inténtalo otra vez.'
              : 'The play changed. Please try again.',
        );
      }
    } else {
      _play(0, tile, selectedSide);
    }
  }

  void _play(int player, _TeamTile tile, _Side side) {
    final wasEmpty = _board.isEmpty;
    var roundPassBonus = 0;
    final capicua = _isCapicuaPlay(player, tile);
    final chuchazo =
        _hands[player].length == 1 && tile.left == 0 && tile.right == 0;
    final playSide = capicua ? _Side.right : side;
    final proposed = TeamDominoChainValidator.tryPlace(
      board: _board.map((value) => (left: value.left, right: value.right)),
      tile: (left: tile.left, right: tile.right),
      side:
          playSide == _Side.right
              ? TeamDominoChainSide.right
              : TeamDominoChainSide.left,
    );
    if (proposed == null) {
      debugPrint(
        'KAPI_TEAMS_CHAIN_REJECTED player=$player tile=${tile.label} '
        'side=${playSide.name}',
      );
      unawaited(AudioManager.instance.playSfx(AudioAssets.invalidMove));
      _message(
        _isSpanish
            ? 'La ficha no conecta correctamente.'
            : 'The tile does not connect correctly.',
      );
      return;
    }
    final oriented = playSide == _Side.right ? proposed.last : proposed.first;
    final placed = _TeamTile(oriented.left, oriented.right);
    var placementAccepted = false;
    setState(() {
      if (playSide == _Side.right) {
        _board.add(placed);
      } else {
        _board.insert(0, placed);
      }
      // Mandatory second check after mutation. This remains active in release.
      if (!_boardConnectionsAreValid()) {
        if (playSide == _Side.right) {
          _board.removeLast();
        } else {
          _board.removeAt(0);
        }
        return;
      }
      placementAccepted = true;
      roundPassBonus = TeamScoringRules.awardRoundPassBonusForPlay(
        teamScores: _teamScores,
        consecutivePasses: _consecutivePasses,
        lastPlayerToPlay: _lastPlayerToPlay,
        playerPlaying: player,
      );
      _hands[player].remove(tile);
      _openingTile ??= placed;
      _lastPlacedTile = placed;
      if (wasEmpty) _openingPlayer = player;
      _lastPlayerToPlay = player;
      _consecutivePasses = 0;
      _status =
          roundPassBonus > 0
              ? '${_playerName(player)} ${_isSpanish ? 'completó el pase redondo' : 'completed the round pass'} +$roundPassBonus'
              : '${_playerName(player)} ${_isSpanish ? 'jugó' : 'played'} ${tile.label}';
    });
    if (!placementAccepted) {
      debugPrint('KAPI_TEAMS_CHAIN_ROLLBACK tile=${tile.label}');
      unawaited(AudioManager.instance.playSfx(AudioAssets.invalidMove));
      _message(
        _isSpanish
            ? 'La mesa se protegió de una conexión incorrecta.'
            : 'The table blocked an incorrect connection.',
      );
      return;
    }
    unawaited(
      AudioManager.instance.playSfx(
        placed.isDouble ? AudioAssets.dominoDouble : AudioAssets.dominoPlace,
      ),
    );
    if (roundPassBonus > 0) {
      _maybeShowCpuRoundPassReaction(player);
      _showSpecialEffect(DominoSpecialEffectKind.roundPass, player: player);
    }
    if (_hands[player].isEmpty) {
      if (capicua) {
        _showSpecialEffect(DominoSpecialEffectKind.capicua, player: player);
      } else {
        _showSpecialEffect(DominoSpecialEffectKind.domino, player: player);
      }
      _finishDominated(
        player,
        capicua: capicua,
        chuchazo: chuchazo,
        roundPassBonus: roundPassBonus,
      );
      return;
    }
    _turn = (_turn + 1) % 4;
    _continueCpuTurns();
  }

  void _pass(int player) {
    setState(() {
      _consecutivePasses++;
      _status = '${_playerName(player)} ${_isSpanish ? 'pasó' : 'passed'}';
    });
    unawaited(AudioManager.instance.playSfx(AudioAssets.dominoPass));
    _showSpecialEffect(DominoSpecialEffectKind.pass, player: player);
    _turn = (_turn + 1) % 4;
    final returnedToBlocker =
        _consecutivePasses >= 3 && _turn == _lastPlayerToPlay;
    final blockerCannotPlay =
        returnedToBlocker &&
        !_hands[_turn].any((tile) => _validSides(tile).isNotEmpty);
    if (blockerCannotPlay || _consecutivePasses >= 4) {
      _finishBlocked();
      return;
    }
    _continueCpuTurns();
  }

  void _showSpecialEffect(DominoSpecialEffectKind kind, {int? player}) {
    if (!mounted) return;
    _specialEffectTimer?.cancel();
    setState(() {
      _specialEffectKind = kind;
      _specialEffectPlayerName = player == null ? null : _playerName(player);
      _specialEffectSequence++;
    });
    if (kind == DominoSpecialEffectKind.capicua) {
      unawaited(AudioManager.instance.playSfx(AudioAssets.celebration));
    } else if (kind == DominoSpecialEffectKind.domino) {
      unawaited(AudioManager.instance.playSfx(AudioAssets.dominoLastTile));
    } else if (kind == DominoSpecialEffectKind.blocked) {
      unawaited(AudioManager.instance.playSfx(AudioAssets.dominoBlocked));
    }
    final sequence = _specialEffectSequence;
    _specialEffectTimer = Timer(
      Duration(
        milliseconds:
            kind == DominoSpecialEffectKind.capicua
                ? 3050
                : kind == DominoSpecialEffectKind.domino
                ? 3000
                : kind == DominoSpecialEffectKind.blocked
                ? 2750
                : 2250,
      ),
      () {
        if (!mounted || sequence != _specialEffectSequence) return;
        setState(() {
          _specialEffectKind = null;
          _specialEffectPlayerName = null;
          if (kind == DominoSpecialEffectKind.blocked) {
            _blockResultPending = false;
          }
        });
      },
    );
  }

  Future<void> _continueCpuTurns() async {
    if (_isOnline) return;
    if (_roundOver || _turn == 0 || _cpuBusy) return;
    final generation = _gameGeneration;
    _cpuBusy = true;
    while (!_roundOver && _turn != 0) {
      setState(() {
        _status =
            '${_playerName(_turn)} ${_isSpanish ? 'pensando...' : 'thinking...'}';
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted || _roundOver || generation != _gameGeneration) break;
      final player = _turn;
      _TeamTile? choice;
      List<_Side> sides = const [];
      for (final tile in _hands[player]) {
        final candidate = _validSides(tile);
        if (candidate.isNotEmpty &&
            (choice == null || tile.points > choice.points)) {
          choice = tile;
          sides = candidate;
        }
      }
      if (choice == null) {
        _pass(player);
      } else {
        _play(
          player,
          choice,
          sides.contains(_Side.right) ? _Side.right : sides.first,
        );
      }
    }
    if (generation == _gameGeneration) {
      _cpuBusy = false;
      if (mounted) setState(() {});
    }
  }

  void _resetGame() {
    // An online table is shared state. It must never be reset by one player,
    // even when every other seat is currently occupied by a CPU.
    if (_isOnline) return;
    setState(() {
      _teamScores[0] = 0;
      _teamScores[1] = 0;
      _round = 1;
      _previousDominator = null;
      _status = _isSpanish ? 'Juego reiniciado' : 'Game reset';
    });
    _startRound();
  }

  void _humanPass() {
    if (_turn != 0 || _roundOver || _humanHasPlayableTile) {
      return;
    }
    if (_isOnline) {
      unawaited(
        _onlineService!.pass(
          gameId: widget.onlineGameId!,
          playerId: widget.onlinePlayerId!,
        ),
      );
    } else {
      _pass(0);
    }
  }

  bool get _humanHasPlayableTile =>
      _hands[0].any((tile) => _validSides(tile).isNotEmpty);

  void _finishDominated(
    int player, {
    bool capicua = false,
    bool chuchazo = false,
    int roundPassBonus = 0,
  }) {
    final team = _teamFor(player);
    final remainingPoints = _hands
        .expand((hand) => hand)
        .fold(0, (total, tile) => total + tile.points);
    final hasBonus = capicua || chuchazo;
    final gained = remainingPoints + (hasBonus ? 25 : 0);
    setState(() {
      _teamScores[team] += gained;
      _previousDominator = player;
      _roundOver = true;
      _resultWinnerPlayer = player;
      _resultPoints = gained + roundPassBonus;
      _resultSpecial = chuchazo ? 'chuchazo' : (capicua ? 'capicua' : null);
      _resultBlocked = false;
      _showFinalHand = false;
      _status =
          chuchazo
              ? '${_isSpanish ? '¡Chuchazo!' : 'Chuchazo!'} ${_playerName(player)} +$remainingPoints +25'
              : capicua
              ? '${_isSpanish ? '¡Capicúa!' : 'Capicua!'} ${_playerName(player)} +$remainingPoints +25'
              : roundPassBonus > 0
              ? '${_playerName(player)} ${_isSpanish ? 'dominó' : 'dominoed'} +$gained +$roundPassBonus'
              : '${_playerName(player)} ${_isSpanish ? 'dominó' : 'dominoed'} +$gained';
    });
    _recordRankingRound(team == 0, gained);
  }

  void _finishBlocked() {
    final handPips = <int>[
      for (var player = 0; player < 4; player++)
        _hands[player].fold<int>(0, (total, tile) => total + tile.points),
    ];
    final blockingPlayer = _lastPlayerToPlay;
    assert(
      blockingPlayer != null,
      'A blocked hand must remember the player who placed the last tile.',
    );
    final winner = TeamScoringRules.blockedWinnerPlayer(
      blockingPlayer: blockingPlayer ?? 0,
      handPips: handPips,
    );
    final gained = handPips.fold<int>(0, (total, points) => total + points);
    setState(() {
      _teamScores[_teamFor(winner)] += gained;
      _previousDominator = winner;
      _roundOver = true;
      _resultWinnerPlayer = winner;
      _resultPoints = gained;
      _resultSpecial = null;
      _resultBlocked = true;
      _blockResultPending = true;
      _showFinalHand = false;
      _status =
          '${_isSpanish ? 'Tranca:' : 'Blocked:'} ${_playerName(winner)} +$gained';
    });
    _showSpecialEffect(DominoSpecialEffectKind.blocked);
    _recordRankingRound(_teamFor(winner) == 0, gained);
  }

  void _recordRankingRound(bool myTeamWon, int gained, {String? rewardKey}) {
    final profile = _profile;
    if (profile == null) return;
    unawaited(
      PlayerPointsService.recordRound(
        code: profile.code,
        publicId: profile.publicId,
        initials: profile.initials,
        displayName: profile.effectiveDisplayName,
        countryCode: profile.countryCode,
        mode: 'teams_2v2',
        pointsEarned: myTeamWon ? gained : 0,
        playerScore: _teamScores[0],
        cpuScore: _teamScores[1],
        wonRound: myTeamWon,
        awardCoins: _isOnline,
        rewardKey: rewardKey,
      ),
    );
  }

  void _nextRound() {
    if (_isOnline) {
      setState(() => _showFinalHand = false);
      unawaited(_onlineService!.nextRound(widget.onlineGameId!));
      return;
    }
    if (_teamScores.any((score) => score >= _scoreTarget)) {
      setState(() {
        _teamScores[0] = 0;
        _teamScores[1] = 0;
        _round = 1;
        _previousDominator = null;
      });
    } else {
      _round++;
    }
    _startRound();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _openNotes() {
    Navigator.pushNamed(context, '/game', arguments: {'fromDominoGame': true});
  }

  Future<void> _leaveOnlineMatch() async {
    if (!_isOnline || _leavingOnline) return;
    final profile = _profile;
    if (profile == null) return;
    _leavingOnline = true;
    _onlineCpuTimer?.cancel();
    await PlayerPointsService.applyAbandonmentPenalty(
      code: profile.code,
      publicId: profile.publicId,
    );
    await _onlineService?.replaceWithCpu(
      gameId: widget.onlineGameId!,
      playerId: widget.onlinePlayerId!,
    );
    if (!mounted) return;
    setState(() => _allowOnlinePop = true);
    Navigator.pushReplacementNamed(context, '/domino-teams-online-lobby');
  }

  bool get _onlineMatchIsFinished =>
      _isOnline &&
      _roundOver &&
      _teamScores.any((score) => score >= _scoreTarget);

  /// A completed match is not an abandonment.  The player can return to the
  /// lobby without being replaced by a CPU or losing ranking points.
  bool _prepareCompletedOnlineExit() {
    if (!_onlineMatchIsFinished || _leavingOnline) return false;
    _leavingOnline = true;
    _onlineCpuTimer?.cancel();
    _onlineHumanTimer?.cancel();
    _onlineNextRoundTimer?.cancel();
    final subscription = _onlineSubscription;
    _onlineSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    setState(() => _allowOnlinePop = true);
    return true;
  }

  void _exitCompletedOnlineMatch() {
    if (!_prepareCompletedOnlineExit()) return;
    Navigator.pushReplacementNamed(context, '/domino-teams-online-lobby');
  }

  void _openGameModeSelection() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      DominoTeamsCpuScreen.completedMatchGameModeRoute,
      (route) => route.settings.name == '/home',
    );
  }

  void _returnFromCpuGame() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _openGameModeSelection();
  }

  void _returnToGameModeSelection() {
    final matchFinished =
        _roundOver && _teamScores.any((score) => score >= _scoreTarget);
    if (!matchFinished) return;
    if (_isOnline && !_prepareCompletedOnlineExit()) return;
    _openGameModeSelection();
  }

  Future<void> _confirmLeaveOnlineMatch() async {
    if (!_isOnline || _leavingOnline) return;
    if (!DominoTeamsCpuScreen.shouldApplyAbandonmentPenalty(
      matchFinished: _onlineMatchIsFinished,
    )) {
      _exitCompletedOnlineMatch();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF101C29),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: Color(0xFFFFD36B), width: 1.4),
            ),
            title: Text(
              _isSpanish ? '¿Salir de la partida?' : 'Leave the match?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              _isSpanish
                  ? 'Un jugador automático ocupará tu puesto y perderás 30 puntos de ranking.'
                  : 'An automatic player will take your seat and you will lose 30 ranking points.',
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                ),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: Text(_isSpanish ? 'Salir (-30)' : 'Leave (-30)'),
              ),
            ],
          ),
    );
    if (leave == true && mounted) await _leaveOnlineMatch();
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final rules = <
          ({IconData icon, Color color, String title, String body})
        >[
          (
            icon: Icons.casino_rounded,
            color: const Color(0xFFFFD36B),
            title: _isSpanish ? 'Doble seis' : 'Double-six',
            body:
                _isSpanish
                    ? '28 fichas · 7 para cada jugador'
                    : '28 tiles · 7 for each player',
          ),
          (
            icon: Icons.groups_rounded,
            color: const Color(0xFF64B5F6),
            title: _isSpanish ? 'Dos equipos' : 'Two teams',
            body:
                _isSpanish
                    ? 'Tú y tu compañero juegan en posiciones opuestas.'
                    : 'You and your partner play from opposite positions.',
          ),
          (
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFFFF6B6B),
            title: _isSpanish ? 'Quién comienza' : 'Who opens',
            body:
                _isSpanish
                    ? 'La primera mano sale con el doble más alto. Después sale quien dominó la mano anterior, con cualquier ficha.'
                    : 'The highest double opens the first hand. Later, the previous dominator opens with any tile.',
          ),
          (
            icon: Icons.lock_rounded,
            color: const Color(0xFFFFA94D),
            title: _isSpanish ? 'Mano trancada' : 'Blocked hand',
            body:
                _isSpanish
                    ? 'Quien tranca se compara solamente con el jugador que juega después. Gana quien tenga menos puntos entre esos dos. Su equipo recibe todos los puntos que quedaron sin jugar.'
                    : 'The blocker competes only with the player who plays next. The lower total between those two wins. Their team scores every unplayed pip.',
          ),
          (
            icon: Icons.replay_circle_filled_rounded,
            color: const Color(0xFFB197FC),
            title: _isSpanish ? 'Pase redondo · +10' : 'Round pass · +10',
            body:
                _isSpanish
                    ? 'Después de jugar, los otros tres pasan y ese mismo jugador vuelve a colocar una ficha. Si la mano se tranca, no hay premio.'
                    : 'After playing, the other three pass and that same player places another tile. A blocked hand earns no bonus.',
          ),
          (
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF63E6BE),
            title:
                _isSpanish ? 'Jugadas especiales · +25' : 'Special wins · +25',
            body:
                _isSpanish
                    ? 'Premio por capicúa o por dominar con la blanca doble.'
                    : 'Bonus for capicúa or winning with the double blank.',
          ),
        ];
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 430,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF172735), Color(0xFF09131D)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFFFD36B), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF9E1111), Color(0xFF5E0707)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Color(0xFFFFD36B),
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isSpanish ? 'Reglas 2 vs 2' : '2 vs 2 Rules',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                _isSpanish
                                    ? 'Dominó en equipos'
                                    : 'Team dominoes',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      itemCount: rules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final rule = rules[index];
                        return _ruleCard(
                          icon: rule.icon,
                          color: rule.color,
                          title: rule.title,
                          body: rule.body,
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.26),
                      border: const Border(
                        top: BorderSide(color: Colors.white12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _targetPill(
                              label: _isSpanish ? 'PRUEBA' : 'TEST',
                              points: 30,
                              color: const Color(0xFF64B5F6),
                            ),
                            const SizedBox(width: 8),
                            _targetPill(
                              label: _isSpanish ? 'VERSIÓN FINAL' : 'FINAL',
                              points: 100,
                              color: const Color(0xFFFFD36B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text(
                              _isSpanish ? 'Entendido' : 'Got it',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ruleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withValues(alpha: 0.34)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _targetPill({
    required String label,
    required int points,
    required Color color,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.78),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$points',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );

  void _showSettingsMenu() {
    if (_isTablet) {
      showDialog<void>(
        context: context,
        // On iPad the pointer-up event that opens this dialog can also reach
        // the large modal barrier and dismiss it immediately. Keep the tablet
        // menu modal until the player uses its explicit close button.
        barrierDismissible: false,
        builder:
            (dialogContext) => Dialog(
              alignment: Alignment.bottomCenter,
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.fromLTRB(72, 72, 72, 44),
              child: Material(
                color: const Color(0xFF101820),
                elevation: 18,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _settingsMenuContent(dialogContext, showClose: true),
                ),
              ),
            ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _settingsMenuContent(sheetContext),
    );
  }

  Widget _settingsMenuContent(
    BuildContext sheetContext, {
    bool showClose = false,
  }) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            showClose ? 26 : 18,
            showClose ? 24 : 18,
            showClose ? 26 : 18,
            showClose ? 28 : 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_rounded, color: Color(0xFFFFD36B)),
                  const SizedBox(width: 10),
                  Text(
                    _isSpanish ? 'Configuración' : 'Settings',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (showClose) ...[
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                      tooltip: _isSpanish ? 'Cerrar' : 'Close',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              const GameAudioControls(compact: true),
              const SizedBox(height: 12),
              if (_isOnline) ...[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    unawaited(_confirmLeaveOnlineMatch());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: Text(_isSpanish ? 'Salir de la sala' : 'Leave room'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, '/note-settings');
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(
                  _isSpanish ? 'Configuración de apuntes' : 'Note settings',
                ),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, '/game-settings');
                },
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  _isSpanish ? 'Configuración del juego' : 'Game settings',
                ),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _quickChatLabel(String messageId) => switch (messageId) {
    'wellPlayed' => _isSpanish ? '¡Buena jugada!' : 'Well played!',
    'thanks' => _isSpanish ? '¡Gracias!' : 'Thanks!',
    'goodLuck' => _isSpanish ? '¡Buena suerte!' : 'Good luck!',
    'goodGame' => _isSpanish ? '¡Buen juego!' : 'Good game!',
    'wow' => '¡Wow!',
    'oops' => 'Oops…',
    'laugh' => _isSpanish ? '¡Jajaja!' : 'Hahaha!',
    'fire' => _isSpanish ? '¡Está encendido!' : 'On fire!',
    _ => messageId,
  };

  Future<void> _showQuickChatPicker() =>
      _showPlayerProfile(0, includeQuickMessages: true);

  String _countryFlag(String countryCode) {
    final raw = countryCode.trim().toUpperCase();
    final normalized = raw == 'DR' ? 'DO' : raw;
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '🌐';
    return String.fromCharCodes(
      normalized.codeUnits.map((character) => character + 127397),
    );
  }

  String? _cosmeticFlagEmoji(String cosmeticId) {
    for (final item in KapiCosmeticsService.catalog) {
      if (item.id == cosmeticId &&
          item.type == KapiCosmeticType.flag &&
          item.id != 'flag_none') {
        return item.emoji;
      }
    }
    return null;
  }

  _TeamsPlayerProfileData _playerProfileData(int player) {
    if (_isOnline && player >= 0 && player < _onlinePlayers.length) {
      final online = _onlinePlayers[player];
      final cpu = online.isCpu;
      final replaced = online.replacedPlayer;
      final fallbackPlayer = online.isFallbackOnlinePlayer;
      final visibleAsCpu = cpu && !replaced && !fallbackPlayer;
      return _TeamsPlayerProfileData(
        player: player,
        name: online.displayName,
        publicId: visibleAsCpu ? 'CPU' : online.id,
        countryCode: visibleAsCpu ? 'CPU' : online.countryCode,
        flagEmoji:
            visibleAsCpu
                ? '🤖'
                : (_cosmeticFlagEmoji(online.badgeKey) ??
                    _countryFlag(online.countryCode)),
        avatarKey: visibleAsCpu ? 'robot' : online.avatarKey,
        points: online.points,
        isCpu: visibleAsCpu,
        tiles: _hands[player].length,
      );
    }

    if (player == 0) {
      final profile = _profile;
      final flag = KapiCosmeticsService.instance.equipped(
        KapiCosmeticType.flag,
      );
      return _TeamsPlayerProfileData(
        player: player,
        name: profile?.effectiveDisplayName ?? (_isSpanish ? 'Tú' : 'You'),
        publicId: profile?.publicId ?? 'PLAYER',
        countryCode: profile?.countryCode ?? 'US',
        flagEmoji:
            flag.id == 'flag_none'
                ? _countryFlag(profile?.countryCode ?? 'US')
                : flag.emoji,
        avatarKey: profile?.avatarKey ?? 'person',
        points: _profilePoints,
        isCpu: false,
        tiles: _hands[player].length,
      );
    }

    return _TeamsPlayerProfileData(
      player: player,
      name: _playerName(player),
      publicId: 'CPU-${player + 1}',
      countryCode: 'CPU',
      flagEmoji: '🤖',
      avatarKey: 'robot',
      points: 0,
      isCpu: true,
      tiles: _hands[player].length,
    );
  }

  Widget _profileStat({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: accent.withValues(alpha: 0.34)),
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

  Widget _quickMessagesGrid(BuildContext sheetContext) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.forum_rounded, color: Color(0xFFFFD36B), size: 20),
          const SizedBox(width: 8),
          Text(
            _isSpanish ? 'Mensajes rápidos' : 'Quick messages',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.05,
        children: [
          for (final entry in TeamsOnlineService.quickChatEmojis.entries)
            Material(
              color: const Color(0xFF1D2A37),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('quick-chat-message-${entry.key}'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_sendQuickChat(entry.key));
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Text(entry.value, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _quickChatLabel(entry.key),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
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
    ],
  );

  Future<void> _showPlayerProfile(
    int player, {
    bool includeQuickMessages = false,
  }) async {
    if (_isOnline && _leavingOnline) return;
    final data = _playerProfileData(player);
    final tier = DominoTierVisual.fromScore(data.points, ranked: !data.isCpu);
    final visualProfile = DominoPlayerProfile(
      initials: DominoPlayerProfile.initialsForDisplayName(data.name),
      displayName: data.name,
      countryCode:
          RegExp(r'^[A-Z]{2}$').hasMatch(data.countryCode)
              ? data.countryCode
              : 'US',
      code: data.publicId,
      avatarKey: data.avatarKey,
    );
    final accent =
        data.team == 0 ? const Color(0xFF64B5F6) : const Color(0xFFFF6B6B);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;
        return SizedBox(
          key: const ValueKey('teams-player-profile-sheet'),
          height: min(
            includeQuickMessages ? 670.0 : 470.0,
            screenHeight * 0.90,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            decoration: BoxDecoration(
              color: const Color(0xFA101923),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(top: BorderSide(color: accent, width: 2.5)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
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
                        data.isCpu
                            ? Icons.smart_toy_rounded
                            : Icons.badge_rounded,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player == 0
                              ? (_isSpanish ? 'Tu perfil' : 'Your profile')
                              : (_isSpanish
                                  ? 'Perfil del jugador'
                                  : 'Player profile'),
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
                    width: 118,
                    height: 118,
                    key: const ValueKey('teams-player-avatar-large'),
                    decoration: BoxDecoration(
                      color: visualProfile.color.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(color: tier.accent, width: 3),
                      boxShadow: tier.shadows(active: true),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: DominoAvatarVisual(
                      avatarKey: visualProfile.avatarKey,
                      fallbackIcon: visualProfile.icon,
                      backgroundColor: tier.avatarBackground(
                        visualProfile.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '${data.flagEmoji}  ${data.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    data.publicId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _profileStat(
                          icon: tier.icon,
                          label: _isSpanish ? 'Nivel' : 'Tier',
                          value:
                              data.isCpu
                                  ? 'CPU'
                                  : '${tier.label} ${tier.level}',
                          accent: tier.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _profileStat(
                          icon: Icons.stars_rounded,
                          label: _isSpanish ? 'Puntos' : 'Points',
                          value: '${data.points}',
                          accent: const Color(0xFFFFD36B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _profileStat(
                          icon:
                              data.team == 0
                                  ? Icons.groups_rounded
                                  : Icons.sports_martial_arts_rounded,
                          label: _isSpanish ? 'Equipo' : 'Team',
                          value:
                              data.team == 0
                                  ? (_isSpanish ? 'Nuestro equipo' : 'Our team')
                                  : (_isSpanish ? 'Rivales' : 'Rivals'),
                          accent: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _profileStat(
                          icon: Icons.view_week_rounded,
                          label: _isSpanish ? 'Fichas' : 'Tiles',
                          value: '${data.tiles}',
                          accent: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  if (includeQuickMessages) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 10),
                    _quickMessagesGrid(sheetContext),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendQuickChat(String messageId) async {
    final now = DateTime.now();
    final lastSent = _lastQuickChatSentAt;
    if (lastSent != null &&
        now.difference(lastSent) < const Duration(milliseconds: 850)) {
      return;
    }
    _lastQuickChatSentAt = now;
    if (!_isOnline) {
      _showLocalQuickChat(player: 0, messageId: messageId);
      return;
    }

    final service = _onlineService;
    final gameId = widget.onlineGameId;
    final playerId = widget.onlinePlayerId;
    if (service == null || gameId == null || playerId == null) return;
    final sent = await service.sendQuickChat(
      gameId: gameId,
      playerId: playerId,
      messageId: messageId,
    );
    if (!sent && mounted) {
      _message(
        _isSpanish
            ? 'No se pudo enviar el mensaje.'
            : 'The message could not be sent.',
      );
    }
  }

  void _showLocalQuickChat({required int player, required String messageId}) {
    final emoji = TeamsOnlineService.quickChatEmojis[messageId];
    if (emoji == null || !mounted) return;
    setState(() {
      _quickChatNoticePlayer = player;
      _quickChatNoticeId = messageId;
      _quickChatNoticeEmoji = emoji;
      _quickChatNoticeSequence++;
    });
    unawaited(AudioManager.instance.playSfx(AudioAssets.turnNotification));
    final noticeSequence = _quickChatNoticeSequence;
    _quickChatNoticeTimer?.cancel();
    _quickChatNoticeTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted || _quickChatNoticeSequence != noticeSequence) return;
      setState(() {
        _quickChatNoticePlayer = null;
        _quickChatNoticeId = null;
        _quickChatNoticeEmoji = null;
      });
    });
  }

  void _maybeShowCpuRoundPassReaction(int scoringPlayer) {
    if (_isOnline) return;
    final reaction = DominoTeamsCpuScreen.cpuRoundPassReactionFor(
      scoringPlayer: scoringPlayer,
      chanceRoll: _random.nextDouble(),
      messageVariant: _random.nextInt(1000),
      useLeftRival: _random.nextBool(),
    );
    if (reaction == null) return;
    final generation = _gameGeneration;
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || _isOnline || generation != _gameGeneration) return;
      _showLocalQuickChat(
        player: reaction.player,
        messageId: reaction.messageId,
      );
    });
  }

  void _maybeSendOnlinePlayerReaction({
    required TeamsOnlineGame game,
    required String actionType,
    required Map<String, dynamic> action,
  }) {
    if (!_isOnline) return;
    // Only one real client coordinates fallback reactions. Without this
    // guard, every connected phone could schedule a different message for the
    // same play.
    if (!DominoTeamsCpuScreen.coordinatesFallbackReactions(
      currentPlayerId: widget.onlinePlayerId ?? '',
      players: game.players,
    )) {
      return;
    }
    final roundPass = (action['roundPassBonus'] as num?)?.toInt() ?? 0;
    final special = action['special'] as String?;
    final isInteresting =
        actionType == 'pass' ||
        roundPass > 0 ||
        special == 'capicua' ||
        special == 'chuchazo';
    if (!isInteresting) return;

    // Keep the chat occasional. A response is more likely for a big play and
    // less likely for an ordinary pass, just like a relaxed real table.
    final chance = roundPass > 0 || special != null ? 0.64 : 0.27;
    if (_random.nextDouble() > chance) return;
    final candidates = <int>[
      for (var seat = 0; seat < game.players.length; seat++)
        if (game.players[seat].isFallbackOnlinePlayer &&
            seat != (action['player'] as num?)?.toInt())
          seat,
    ];
    if (candidates.isEmpty) return;
    final messages =
        special == 'capicua' || special == 'chuchazo'
            ? const ['wow', 'fire', 'wellPlayed']
            : roundPass > 0
            ? const ['fire', 'wellPlayed', 'wow', 'thanks']
            : const ['oops', 'laugh', 'goodLuck', 'wellPlayed'];
    final seat = candidates[_random.nextInt(candidates.length)];
    final messageId = messages[_random.nextInt(messages.length)];
    final revision = game.revision;
    Future<void>.delayed(
      Duration(milliseconds: 500 + _random.nextInt(900)),
      () async {
        if (!mounted || _onlineRevision != revision) return;
        final service = _onlineService;
        final gameId = widget.onlineGameId;
        if (service == null || gameId == null) return;
        await service.sendCpuQuickChat(
          gameId: gameId,
          seat: seat,
          messageId: messageId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the table immediately after the player equips a cosmetic.
    final compactPhone = MediaQuery.sizeOf(context).width < 390;
    return PopScope(
      canPop: !_isOnline || _allowOnlinePop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isOnline) unawaited(_confirmLeaveOnlineMatch());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF071524),
        appBar: AppBar(
          toolbarHeight: compactPhone ? 52 : kToolbarHeight,
          backgroundColor: const Color(0xFF8B0808),
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed:
                _isOnline
                    ? () => unawaited(_confirmLeaveOnlineMatch())
                    : _returnFromCpuGame,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip:
                _isOnline
                    ? (_isSpanish ? 'Salir de la partida' : 'Leave match')
                    : (_isSpanish ? 'Volver' : 'Back'),
          ),
          titleSpacing: 0,
          title:
              compactPhone
                  ? Tooltip(
                    message: 'Teams 2 vs 2',
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.groups_rounded, size: 22),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text(
                          'Teams 2 vs 2',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: _openNotes,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 7,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          _isSpanish ? 'Apuntes' : 'Notes',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
          actions: [
            if (compactPhone)
              IconButton(
                onPressed: _openNotes,
                icon: const Icon(Icons.edit_note_rounded),
                tooltip: _isSpanish ? 'Apuntes' : 'Notes',
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/kapi-store'),
              icon: const Icon(Icons.palette_rounded),
              tooltip: _isSpanish ? 'Personalizar' : 'Personalize',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: _showSettingsMenu,
              icon: const Icon(Icons.settings_rounded),
              tooltip: _isSpanish ? 'Configuración' : 'Settings',
              visualDensity: VisualDensity.compact,
            ),
            if (_resetAllowed)
              IconButton(
                onPressed: _resetGame,
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: _isSpanish ? 'Reiniciar juego' : 'Reset game',
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              onPressed: _showRules,
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: _isSpanish ? 'Reglas' : 'Rules',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _scoreBar(),
                        Expanded(child: _boardView()),
                        _handView(),
                      ],
                    ),
                    if (_roundOver &&
                        !_blockResultPending &&
                        !_showFinalHand &&
                        _specialEffectKind == null)
                      Positioned.fill(
                        child: DominoResultCelebration(
                          maxContentWidth:
                              defaultTargetPlatform == TargetPlatform.macOS
                                  ? 720
                                  : 430,
                          showConfetti: _teamScores.any(
                            (score) => score >= _scoreTarget,
                          ),
                          child: _buildTeamsResultCard(),
                        ),
                      ),
                    if (_roundOver && _showFinalHand)
                      Positioned(
                        left: 14,
                        right: 14,
                        top: 4,
                        child: _finalHandBanner(),
                      ),
                    if (_specialEffectKind != null)
                      Positioned.fill(
                        child: DominoSpecialPlayEffect(
                          key: ValueKey(
                            'special-effect-$_specialEffectSequence',
                          ),
                          kind: _specialEffectKind!,
                          sequence: _specialEffectSequence,
                          spanish: _isSpanish,
                          playerName: _specialEffectPlayerName,
                        ),
                      ),
                    Positioned(
                      left: 58,
                      right: 58,
                      top: 104,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [_quickChatNotification()],
                      ),
                    ),
                    if (_sideChoiceTile != null)
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 4,
                        child: _sideChoiceBanner(),
                      ),
                    if (_turn == 0 && !_roundOver && !_humanHasPlayableTile)
                      Positioned(
                        right: 8,
                        bottom: compactPhone ? 76 : 88,
                        child: FilledButton.icon(
                          onPressed: _humanPass,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC928),
                            foregroundColor: const Color(0xFF17202A),
                            minimumSize:
                                compactPhone
                                    ? const Size(104, 42)
                                    : const Size(132, 48),
                            padding: EdgeInsets.symmetric(
                              horizontal: compactPhone ? 14 : 18,
                            ),
                            textStyle: TextStyle(
                              fontSize: compactPhone ? 14 : 16,
                              fontWeight: FontWeight.w900,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            Icons.skip_next_rounded,
                            size: compactPhone ? 20 : 23,
                          ),
                          label: Text(_isSpanish ? 'Pasar' : 'Pass'),
                        ),
                      ),
                  ],
                ),
              ),
              AnchoredAdaptiveBannerAd(
                adUnitId: _adUnitId,
                margin: const EdgeInsets.only(top: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickChatNotification() {
    final player = _quickChatNoticePlayer;
    final messageId = _quickChatNoticeId;
    final emoji = _quickChatNoticeEmoji;
    final visible = player != null && messageId != null && emoji != null;
    final accent =
        player?.isEven == false
            ? const Color(0xFFFF5C64)
            : const Color(0xFF64B5F6);
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        reverseDuration: const Duration(milliseconds: 180),
        transitionBuilder:
            (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.18),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            ),
        child:
            !visible
                ? const SizedBox.shrink(key: ValueKey('no-quick-chat'))
                : Semantics(
                  key: ValueKey(
                    'quick-chat-$_quickChatNoticeSequence-$player-$messageId',
                  ),
                  liveRegion: true,
                  label:
                      '${_playerName(player)}: ${_quickChatLabel(messageId)}',
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xF2111A24),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _playerName(player),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                _quickChatLabel(messageId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
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

  Widget _finalHandBanner() {
    final winnerPlayer = _resultWinnerPlayer ?? 0;
    final title =
        _resultBlocked
            ? (_isSpanish ? 'MANO TRANCADA' : 'BLOCKED HAND')
            : (_isSpanish
                ? '${_playerName(winnerPlayer).toUpperCase()} DOMINÓ'
                : '${_playerName(winnerPlayer).toUpperCase()} DOMINOED');
    final detail =
        _resultBlocked
            ? (_isSpanish
                ? 'Cuatro pases · extremos $_leftOpen y $_rightOpen'
                : 'Four passes · open ends $_leftOpen and $_rightOpen')
            : (_isSpanish
                ? 'Se quedó sin fichas · extremos $_leftOpen y $_rightOpen'
                : 'No tiles left · open ends $_leftOpen and $_rightOpen');
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xF20A1722),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                _resultBlocked
                    ? const Color(0xFFFFC928)
                    : const Color(0xFF64B5F6),
            width: 1.5,
          ),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (_resultBlocked
                        ? const Color(0xFFFFC928)
                        : const Color(0xFF64B5F6))
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _resultBlocked
                    ? Icons.lock_rounded
                    : Icons.emoji_events_rounded,
                color:
                    _resultBlocked
                        ? const Color(0xFFFFC928)
                        : const Color(0xFF64B5F6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showFinalHand = false),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                _isSpanish ? 'Resultado' : 'Result',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsResultCard() {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final winnerPlayer = _resultWinnerPlayer ?? 0;
    final winnerTeam = _teamFor(winnerPlayer);
    final loserTeam = 1 - winnerTeam;
    final matchOver = _teamScores.any((score) => score >= _scoreTarget);
    final winnerLabel =
        winnerTeam == 0
            ? (_isSpanish ? 'Nosotros' : 'Us')
            : (_isSpanish ? 'Rivales' : 'Rivals');
    final special = switch (_resultSpecial) {
      'capicua' => _isSpanish ? '¡CAPICÚA!  +25' : 'CAPICUA!  +25',
      'chuchazo' => '¡CHUCHAZO!  +25',
      _ => null,
    };
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMac ? 20 : 8,
        vertical: isMac ? 18 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            matchOver
                ? (_isSpanish
                    ? '¡$winnerLabel gana la partida!'
                    : '$winnerLabel wins the match!')
                : (_resultBlocked
                    ? (_isSpanish
                        ? '¡$winnerLabel gana la tranca!'
                        : '$winnerLabel wins the block!')
                    : (_isSpanish
                        ? '¡$winnerLabel gana la mano!'
                        : '$winnerLabel wins the hand!')),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMac ? 38 : 24,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
          SizedBox(height: isMac ? 8 : 4),
          Text(
            '+$_resultPoints ${_isSpanish ? 'puntos' : 'points'}',
            style: TextStyle(
              color: Color(0xFFFFD36B),
              fontSize: isMac ? 30 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (special != null)
            Text(
              special,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMac ? 21 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          SizedBox(height: isMac ? 16 : 8),
          _resultTeamPanel(
            team: winnerTeam,
            winnerPlayer: winnerPlayer,
            winner: true,
          ),
          SizedBox(height: isMac ? 14 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMac ? 26 : 16,
              vertical: isMac ? 11 : 7,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              '${_isSpanish ? 'Nosotros' : 'Us'} ${_teamScores[0]}/$_scoreTarget  •  ${_isSpanish ? 'Rivales' : 'Rivals'} ${_teamScores[1]}/$_scoreTarget',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMac ? 20 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: isMac ? 14 : 8),
          _resultTeamPanel(
            team: loserTeam,
            winnerPlayer: winnerPlayer,
            winner: false,
          ),
          SizedBox(height: isMac ? 18 : 10),
          SizedBox(
            width: double.infinity,
            height: isMac ? 62 : 44,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showFinalHand = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: 0.32),
                side: const BorderSide(color: Colors.white70, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded),
              label: Text(
                _resultBlocked
                    ? (_isSpanish ? 'Ver la tranca' : 'View blocked hand')
                    : (_isSpanish ? 'Ver mano final' : 'View final hand'),
                style: TextStyle(
                  fontSize: isMac ? 20 : 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(height: isMac ? 12 : 8),
          if (_isOnline && matchOver) ...[
            SizedBox(
              width: double.infinity,
              height: isMac ? 62 : 46,
              child: OutlinedButton.icon(
                onPressed: _exitCompletedOnlineMatch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF64B5F6), width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: Text(
                  _isSpanish ? 'Salir al lobby' : 'Exit to lobby',
                  style: TextStyle(
                    fontSize: isMac ? 20 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(height: isMac ? 12 : 8),
          ],
          SizedBox(
            width: double.infinity,
            height: isMac ? 66 : 48,
            child: FilledButton.icon(
              onPressed: _nextRound,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                matchOver
                    ? (_isSpanish ? 'Jugar otra vez' : 'Play again')
                    : (_isSpanish ? 'Siguiente mano' : 'Next hand'),
                style: TextStyle(
                  fontSize: isMac ? 22 : 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (matchOver) ...[
            SizedBox(height: isMac ? 12 : 8),
            SizedBox(
              width: double.infinity,
              height: isMac ? 62 : 46,
              child: OutlinedButton.icon(
                key: const ValueKey('teams-result-choose-mode'),
                onPressed: _returnToGameModeSelection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(
                    0xFF071524,
                  ).withValues(alpha: 0.74),
                  side: const BorderSide(color: Color(0xFFFFD36B), width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text(
                  _isSpanish ? 'Elegir modo de juego' : 'Choose game mode',
                  style: TextStyle(
                    fontSize: isMac ? 20 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultTeamPanel({
    required int team,
    required int winnerPlayer,
    required bool winner,
  }) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final players = team == 0 ? <int>[0, 2] : <int>[1, 3];
    if (players.contains(winnerPlayer)) {
      players
        ..remove(winnerPlayer)
        ..insert(0, winnerPlayer);
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMac ? 15 : 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: winner ? 0.40 : 0.30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: winner ? const Color(0xFFFFD36B) : Colors.white54,
          width: winner ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < players.length; index++) ...[
            if (index > 0) SizedBox(height: isMac ? 12 : 6),
            _resultPlayerRow(players[index], winnerPlayer == players[index]),
          ],
        ],
      ),
    );
  }

  Widget _resultPlayerRow(int player, bool dominated) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final tiles = _hands[player];
    final points = tiles.fold(0, (total, tile) => total + tile.points);
    final profileData = _playerProfileData(player);
    final icon =
        profileData.isCpu
            ? Icons.smart_toy_rounded
            : (player == 0
                ? (_profile?.icon ?? Icons.person_rounded)
                : Icons.person_rounded);
    final name = player == 0 ? profileData.name : _playerName(player);
    return Semantics(
      button: true,
      label: _isSpanish ? 'Abrir perfil de $name' : 'Open $name profile',
      child: InkWell(
        key: ValueKey('teams-result-player-profile-$player'),
        onTap:
            () => _showPlayerProfile(player, includeQuickMessages: player == 0),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            TeamsResultPlayerAvatar(
              player: player,
              avatarKey: profileData.avatarKey,
              fallbackIcon: icon,
              size: isMac ? 68 : 38,
            ),
            SizedBox(width: isMac ? 14 : 8),
            SizedBox(
              width: isMac ? 150 : 74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMac ? 21 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    dominated
                        ? (_resultBlocked
                            ? (_isSpanish ? 'Ganó la tranca' : 'Won the block')
                            : (_isSpanish ? 'Dominó' : 'Dominoed'))
                        : '$points ${_isSpanish ? 'pts' : 'pts'}',
                    style: TextStyle(
                      color:
                          dominated ? const Color(0xFFFFD36B) : Colors.white70,
                      fontSize: isMac ? 15 : 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  tiles.isEmpty
                      ? Text(
                        _isSpanish ? 'Sin fichas' : 'No tiles',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isMac ? 16 : 11,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                      : Wrap(
                        alignment: WrapAlignment.end,
                        spacing: isMac ? 5 : 2,
                        runSpacing: isMac ? 5 : 2,
                        children: [
                          for (final tile in tiles)
                            SizedBox(
                              width: isMac ? 34 : 20,
                              height: isMac ? 58 : 36,
                              child: FittedBox(
                                child: _tileWidget(tile, small: true),
                              ),
                            ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnerBar({
    bool insideTable = false,
    required bool hiddenTilesCompact,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final largeTable = insideTable && _isTablet;
      final compact =
          !largeTable && constraints.maxWidth < (insideTable ? 230 : 390);
      final availableMiddleWidth =
          insideTable
              ? constraints.maxWidth
              : max(160.0, constraints.maxWidth - 148);
      final showOnlineAvatar = _onlinePanelUsesAvatar(2);
      final partnerProfile = _playerProfileData(2);
      final displayName = partnerProfile.name;
      final partnerFlag = partnerProfile.flagEmoji.trim();
      final showPartnerFlag =
          showOnlineAvatar && partnerFlag.isNotEmpty && partnerFlag != '🤖';
      final avatarSize = largeTable ? 44.0 : (compact ? 27.0 : 31.0);
      final contentPadding = largeTable ? 12.0 : (compact ? 6.0 : 8.0);
      final contentGap = largeTable ? 10.0 : (compact ? 4.0 : 8.0);
      final nameStyle = TextStyle(
        color: Colors.white,
        fontSize: largeTable ? 18 : (compact ? 12 : 13),
        fontWeight: FontWeight.w900,
      );
      final namePainter = TextPainter(
        text: TextSpan(text: displayName, style: nameStyle),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final hiddenTileWidth =
          largeTable ? 22.0 : (hiddenTilesCompact ? 14.0 : 16.0);
      final hiddenTileGap = largeTable ? 3.0 : (hiddenTilesCompact ? 1.0 : 2.0);
      final hiddenTileCount = _hands[2].length;
      final rackWidth =
          (hiddenTileWidth * hiddenTileCount) +
          (hiddenTileGap * max(0, hiddenTileCount - 1));
      final nameWidth = min(
        namePainter.width,
        largeTable ? 196.0 : (compact ? 82.0 : 132.0),
      );
      final desiredPanelWidth =
          (contentPadding * 2) +
          avatarSize +
          contentGap +
          nameWidth +
          contentGap +
          rackWidth +
          (showPartnerFlag ? contentGap + avatarSize : 0);
      final panelWidth = min(
        desiredPanelWidth,
        min(
          insideTable ? (largeTable ? 560.0 : 400.0) : 360.0,
          availableMiddleWidth,
        ),
      );
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: panelWidth,
          child: Semantics(
            button: true,
            value: _status,
            label:
                _isSpanish
                    ? 'Abrir perfil de $displayName'
                    : 'Open $displayName profile',
            child: InkWell(
              key: const ValueKey('teams-player-profile-2'),
              onTap: () => _showPlayerProfile(2),
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: largeTable ? 64 : 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      left: largeTable ? 6 : (compact ? 4 : 5),
                      right: largeTable ? 6 : (compact ? 4 : 5),
                      top: largeTable ? 10 : (compact ? 14 : 12),
                      bottom: largeTable ? 10 : (compact ? 14 : 12),
                      child: AnimatedContainer(
                        key: const ValueKey('teams-player-partner-panel'),
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          color:
                              _turn == 2 && !_roundOver
                                  ? const Color(0xFF174D73)
                                  : const Color(0xE6101820),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF64B5F6),
                            width: _turn == 2 && !_roundOver ? 2.5 : 1.2,
                          ),
                          boxShadow:
                              _turn == 2 && !_roundOver
                                  ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF64B5F6,
                                      ).withValues(alpha: 0.42),
                                      blurRadius: 10,
                                    ),
                                  ]
                                  : const [],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: largeTable ? 12 : (compact ? 6 : 8),
                      ),
                      child: Row(
                        key: const ValueKey('teams-player-partner-content'),
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Container(
                            key: const ValueKey('teams-player-partner-avatar'),
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              color: const Color(0xFF102737),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: const Color(0xFF64B5F6),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: DominoAvatarVisual(
                              avatarKey: partnerProfile.avatarKey,
                              fallbackIcon: Icons.person_rounded,
                              backgroundColor: const Color(0xFF102737),
                            ),
                          ),
                          SizedBox(width: largeTable ? 10 : (compact ? 4 : 8)),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                displayName,
                                key: const ValueKey(
                                  'teams-player-partner-name',
                                ),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.left,
                                style: nameStyle,
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 4 : 8),
                          KeyedSubtree(
                            key: const ValueKey('teams-player-partner-rack'),
                            child: _hiddenRack(
                              _hands[2].length,
                              Axis.horizontal,
                              compact: hiddenTilesCompact,
                              large: largeTable,
                            ),
                          ),
                          if (showPartnerFlag) ...[
                            SizedBox(
                              width: largeTable ? 10 : (compact ? 4 : 8),
                            ),
                            SizedBox(
                              key: const ValueKey('teams-player-partner-flag'),
                              width: avatarSize,
                              height: avatarSize,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(
                                  partnerFlag,
                                  style: TextStyle(
                                    fontSize: avatarSize,
                                    height: 1,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
        ),
      );
    },
  );

  Widget _scoreBar() => Container(
    margin: const EdgeInsets.all(8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_isSpanish ? 'Nosotros' : 'Us'} ${_teamScores[0]}/$_scoreTarget',
              style: const TextStyle(
                color: Color(0xFF64B5F6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_isSpanish ? 'Mano' : 'Hand'} $_round',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${_isSpanish ? 'Rivales' : 'Rivals'} ${_teamScores[1]}/$_scoreTarget',
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _verticalRival(
    int player, {
    bool compact = false,
    required bool isLeft,
  }) {
    final active = _turn == player && !_roundOver;
    final showOnlineAvatar = _onlinePanelUsesAvatar(player);
    final profileData = _playerProfileData(player);
    final name = profileData.name;
    return Semantics(
      button: true,
      label: _isSpanish ? 'Abrir perfil de $name' : 'Open $name profile',
      child: GestureDetector(
        key: ValueKey('teams-player-profile-$player'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPlayerProfile(player),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: active ? 1 : 0.92,
          child: Align(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  left: compact ? 6 : 7,
                  right: compact ? 6 : 7,
                  top: compact ? 5 : 6,
                  bottom: compact ? 5 : 6,
                  child: AnimatedContainer(
                    key: ValueKey('teams-player-side-panel-$player'),
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF245A48) : Colors.black38,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFFF6B6B),
                        width: active ? 2.5 : 1.2,
                      ),
                      boxShadow:
                          active
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFD36B,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ]
                              : const [],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: _isTablet ? 5 : (compact ? 2 : 3),
                  ),
                  child: TeamsSideRivalIdentity(
                    player: player,
                    isLeft: isLeft,
                    compact: compact,
                    large: _isTablet,
                    showOnlineAvatar: showOnlineAvatar,
                    name: name,
                    avatarKey: profileData.avatarKey,
                    flagEmoji: showOnlineAvatar ? profileData.flagEmoji : '',
                    rack: _hiddenRack(
                      _hands[player].length,
                      Axis.vertical,
                      compact: compact,
                      sideRival: true,
                      large: _isTablet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _onlinePanelUsesAvatar(int player) {
    if (!_isOnline || player < 0 || player >= _onlinePlayers.length) {
      return false;
    }
    final onlinePlayer = _onlinePlayers[player];
    return !onlinePlayer.isCpu ||
        onlinePlayer.isFallbackOnlinePlayer ||
        onlinePlayer.replacedPlayer;
  }

  Widget _hiddenRack(
    int count,
    Axis axis, {
    bool compact = false,
    bool sideRival = false,
    bool large = false,
  }) {
    final longEdge = large ? 50.0 : (compact ? 32.0 : 36.0);
    final shortEdge = large ? 22.0 : (compact ? 14.0 : 16.0);
    final tiles = List<Widget>.generate(
      count,
      (index) => TeamsHiddenDominoBack(
        key: ValueKey(
          'teams-hidden-tile-${axis.name}-${sideRival ? 'side' : 'partner'}-$index',
        ),
        width: axis == Axis.horizontal ? shortEdge : longEdge,
        height: axis == Axis.horizontal ? longEdge : shortEdge,
        opacity: 0.80,
      ),
    );
    final spaced = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        spaced.add(
          axis == Axis.horizontal
              ? SizedBox(width: large ? 3 : (compact ? 1 : 2))
              : SizedBox(height: large ? 3 : (compact ? 1 : 2)),
        );
      }
      spaced.add(tiles[i]);
    }
    return axis == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: spaced)
        : Column(mainAxisSize: MainAxisSize.min, children: spaced);
  }

  Widget _boardView() {
    final tableStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.table,
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactTable = viewportWidth < 430;
    final sideWidth = _isTablet ? 122.0 : (compactTable ? 70.0 : 84.0);
    final profileTop = _isTablet ? 18.0 : (compactTable ? 10.0 : 14.0);
    final playedAreaTop = profileTop + (_isTablet ? 74.0 : 52.0);
    // The painted phone rails use at most 36 logical pixels. A stable 38 px
    // inset keeps the animated dominoes clear while reclaiming the unused
    // width that previously made Pro Max boards shrink too soon.
    final playedAreaSideInset = _isTablet ? 68.0 : 38.0;
    return Container(
      key: const ValueKey('teams-board-table'),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: tableStyle.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tableStyle.secondary),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: KapiTableCenterMaterial(
              fallbackColor: tableStyle.primary,
              assetPath: tableStyle.previewAsset,
            ),
          ),
          const Positioned.fill(
            child: KapiCenterpieceOverlay(maxFraction: .44, opacity: .30),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: sideWidth,
                child: _verticalRival(3, compact: compactTable, isLeft: true),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: sideWidth,
                child: _verticalRival(1, compact: compactTable, isLeft: false),
              ),
            ),
          ),
          Positioned(
            left: compactTable ? 12 : 14,
            right: compactTable ? 12 : 14,
            top: profileTop,
            child: _partnerBar(
              insideTable: true,
              hiddenTilesCompact: compactTable,
            ),
          ),
          Padding(
            key: const ValueKey('teams-played-area'),
            padding: EdgeInsets.fromLTRB(
              playedAreaSideInset,
              playedAreaTop,
              playedAreaSideInset,
              8,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_board.isEmpty) return _waitingForOpeningTile();
                if (!_boardConnectionsAreValid()) {
                  return _invalidBoardSafetyView();
                }
                final opening = _openingTile ?? _board.first;
                var openingIndex = _board.indexWhere(
                  (tile) => identical(tile, opening),
                );
                if (openingIndex < 0) openingIndex = _board.indexOf(opening);
                final startsHorizontally = _openingChainStartsHorizontally(
                  opening,
                );
                final visualBoard = <TeamBoardTileSpec>[
                  for (final tile in _board)
                    TeamBoardTileSpec(
                      isDouble: tile.isDouble,
                      left: tile.left,
                      right: tile.right,
                    ),
                ];
                final preferredBoardShortEdge =
                    _isTablet
                        ? 75.6
                        : (viewportWidth * 0.10).clamp(36.0, 42.0).toDouble();
                final preferredBoardScale =
                    (preferredBoardShortEdge / 30.0) * _playedTileScale;
                final layoutChoice = TeamBoardLayoutEngine.bestFit(
                  board: visualBoard,
                  openingIndex: max(0, openingIndex),
                  openingVertical: _openingIsVertical(opening),
                  startsHorizontally: startsHorizontally,
                  availableSize: constraints.biggest,
                  preferredScale: preferredBoardScale,
                  baseLongRunLength:
                      TeamBoardLayoutEngine.responsiveLongRunLengthForWidth(
                        viewportWidth,
                        startsHorizontally: startsHorizontally,
                      ),
                  edgeRunLength:
                      TeamBoardLayoutEngine.responsiveEdgeRunLengthForWidth(
                        viewportWidth,
                        startsHorizontally: startsHorizontally,
                      ),
                );
                final responsiveLayoutEngine = layoutChoice.engine;
                final layouts = layoutChoice.placements;
                assert(
                  TeamBoardLayoutEngine.debugValidatePlacements(layouts),
                  'The visual domino path is disconnected or has a false contact.',
                );
                if (!TeamBoardLayoutEngine.validateVisualConnections(
                  board: visualBoard,
                  placements: layouts,
                  openingIndex: max(0, openingIndex),
                )) {
                  debugPrint('KAPI_TEAMS_VISUAL_CHAIN_REJECTED round=$_round');
                  return _invalidBoardSafetyView();
                }
                final previews = <_BoardSidePreview>[];
                final choiceTile = _sideChoiceTile;
                if (choiceTile != null) {
                  previews
                    ..add(
                      _previewForSide(
                        _Side.left,
                        choiceTile,
                        layoutEngine: responsiveLayoutEngine,
                      ),
                    )
                    ..add(
                      _previewForSide(
                        _Side.right,
                        choiceTile,
                        layoutEngine: responsiveLayoutEngine,
                      ),
                    );
                }
                final boardBounds = TeamBoardLayoutEngine.boundsFor(
                  layouts,
                  padding: 0,
                );
                var contentBounds = boardBounds;
                for (final preview in previews) {
                  contentBounds = contentBounds.expandToInclude(
                    TeamBoardLayoutEngine.rectFor(preview.placement),
                  );
                }
                final cameraFit = TeamBoardLayoutEngine.centeredFit(
                  bounds: contentBounds,
                  availableSize: constraints.biggest,
                  preferredScale: preferredBoardScale,
                );
                final targetCamera = _TeamBoardCamera(
                  scale: cameraFit.scale,
                  translation: cameraFit.translation,
                );

                return TweenAnimationBuilder<_TeamBoardCamera>(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  tween: _TeamBoardCameraTween(
                    begin: targetCamera,
                    end: targetCamera,
                  ),
                  builder: (context, camera, _) {
                    Offset fittedOffset(int index) {
                      final rect = TeamBoardLayoutEngine.rectFor(
                        layouts[index],
                      );
                      return camera.translation + rect.topLeft * camera.scale;
                    }

                    Offset fittedPreviewOffset(TeamBoardPlacement placement) {
                      final rect = TeamBoardLayoutEngine.rectFor(placement);
                      return camera.translation + rect.topLeft * camera.scale;
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var index = 0; index < _board.length; index++)
                          Positioned(
                            key: ValueKey(
                              'teams-board-tile-${_board[index].id}',
                            ),
                            left: fittedOffset(index).dx,
                            top: fittedOffset(index).dy,
                            child: Transform.scale(
                              alignment: Alignment.topLeft,
                              scale: camera.scale,
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 460),
                                curve: Curves.easeOutBack,
                                tween: Tween(
                                  begin:
                                      identical(_board[index], _lastPlacedTile)
                                          ? 0.35
                                          : 1,
                                  end: 1,
                                ),
                                builder:
                                    (context, arrivalScale, child) =>
                                        Transform.scale(
                                          alignment: Alignment.center,
                                          scale: arrivalScale,
                                          child: Opacity(
                                            opacity:
                                                identical(
                                                      _board[index],
                                                      _lastPlacedTile,
                                                    )
                                                    ? arrivalScale.clamp(0, 1)
                                                    : 1,
                                            child: child,
                                          ),
                                        ),
                                child: _tileWidget(
                                  layouts[index].flipped
                                      ? _board[index].flipped
                                      : _board[index],
                                  small: true,
                                  onBoard: true,
                                  verticalOverride: layouts[index].vertical,
                                ),
                              ),
                            ),
                          ),
                        for (final preview in previews)
                          _sidePreviewTarget(
                            preview: preview,
                            boardScale: camera.scale,
                            offset: fittedPreviewOffset(preview.placement),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidePreviewTarget({
    required _BoardSidePreview preview,
    required double boardScale,
    required Offset offset,
  }) {
    const tapPadding = 14.0;
    final rect = TeamBoardLayoutEngine.rectFor(preview.placement);
    final visualWidth = rect.width * boardScale;
    final visualHeight = rect.height * boardScale;
    final label =
        preview.side == _Side.left
            ? (_isSpanish ? 'Jugar por la ficha roja' : 'Play on the red tile')
            : (_isSpanish
                ? 'Jugar por la ficha azul'
                : 'Play on the blue tile');

    return Positioned(
      // Tie the element to the selected tile as well as the side. Replacing a
      // hand tile disposes the old red/blue animation instead of reusing it.
      key: ValueKey('side-preview-${preview.side.name}-${preview.tile.id}'),
      left: offset.dx - tapPadding,
      top: offset.dy - tapPadding,
      child: TeamsSideChoiceTapTarget(
        key: ValueKey('teams-side-preview-${preview.side.name}'),
        visualWidth: visualWidth,
        visualHeight: visualHeight,
        tapPadding: tapPadding,
        semanticsLabel: label,
        onTap: () => _selectSideChoice(preview.side),
        child: AnimatedBuilder(
          animation: _sideChoicePulse,
          builder: (context, child) {
            final pulse = Curves.easeInOut.transform(_sideChoicePulse.value);
            final selected = _selectedSideChoice == preview.side;
            final dimmed = _selectedSideChoice != null && !selected;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: selected ? 1 : (dimmed ? 0.24 : 0.58 + pulse * 0.42),
              child: Transform.scale(
                scale: selected ? 1.10 : 0.94 + pulse * 0.10,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child!,
                    if (selected)
                      const Positioned(
                        right: -5,
                        top: -5,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          child: SizedBox(
            width: visualWidth,
            height: visualHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              child: _tileWidget(
                preview.tile,
                small: true,
                onBoard: true,
                verticalOverride: preview.placement.vertical,
                tileColor: preview.color,
                borderColor: Colors.white,
                pipColor: Colors.white,
                shadowColor: preview.color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _invalidBoardSafetyView() => Center(
    child: Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xEE0C1B24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD36B), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFFFFD36B)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _isSpanish
                  ? 'Verificando las conexiones de la mesa...'
                  : 'Verifying the table connections...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _waitingForOpeningTile() {
    final humanOpens = _turn == 0;
    final opener = _playerName(_turn);
    final accent =
        humanOpens ? const Color(0xFF64B5F6) : const Color(0xFFFFD36B);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: Container(
            key: ValueKey('opening-$_round-$_turn'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xEF142630), Color(0xEF071820)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.55)),
                  ),
                  child: Icon(
                    humanOpens
                        ? Icons.touch_app_rounded
                        : Icons.hourglass_top_rounded,
                    color: accent,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_isSpanish ? 'MANO' : 'HAND'} $_round',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        humanOpens
                            ? (_isSpanish ? '¡Tú sales!' : 'You open!')
                            : (_isSpanish
                                ? '$opener va a salir'
                                : '$opener will open'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        humanOpens
                            ? (_isSpanish
                                ? 'Elige una ficha para comenzar.'
                                : 'Choose a tile to begin.')
                            : (_isSpanish
                                ? 'Preparando la primera ficha...'
                                : 'Preparing the first tile...'),
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!humanOpens) ...[
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            color: accent,
                            backgroundColor: Colors.white12,
                          ),
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

  Widget _handView() {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final dominoStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.domino,
    );
    return SizedBox(
      key: const ValueKey('teams-hand-area'),
      height: (compact ? 74 : 84) * _effectiveHandTileScale,
      child: Row(
        children: [
          _quickChatProfileButton(compact: compact),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AdaptiveDominoHandTray(
                key: const ValueKey('teams-adaptive-hand-tray'),
                dominoColor: dominoStyle.primary,
                borderRadius: 16,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tiles = <Widget>[];
                    for (var index = 0; index < _hands[0].length; index++) {
                      if (index > 0) {
                        tiles.add(SizedBox(width: compact ? 3 : 5));
                      }
                      final tile = _hands[0][index];
                      final isMyTurn = _turn == 0 && !_roundOver && !_cpuBusy;
                      final canPlay = isMyTurn && _validSides(tile).isNotEmpty;
                      tiles.add(
                        IgnorePointer(
                          ignoring: !isMyTurn,
                          child: Opacity(
                            opacity:
                                (_roundOver && _showFinalHand) || canPlay
                                    ? 1
                                    : 0.38,
                            child: GestureDetector(
                              onTap: () => _playHuman(tile),
                              child: _tileWidget(
                                tile,
                                displayScale: _effectiveHandTileScale,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    if (tiles.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 5 : 8,
                      ),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: (compact ? 66 : 76) * _effectiveHandTileScale,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: tiles,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChatProfileButton({required bool compact}) {
    final profile = _profile;
    final flag = KapiCosmeticsService.instance.equipped(KapiCosmeticType.flag);
    final accent = profile?.color ?? const Color(0xFF64B5F6);
    final tooltip =
        _isSpanish
            ? 'Abrir perfil, emojis y mensajes'
            : 'Open profile, emojis and messages';
    return Padding(
      padding: EdgeInsets.only(
        left: compact ? 5 : 8,
        right: 2,
        top: 4,
        bottom: 4,
      ),
      child: Semantics(
        button: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: const Color(0xFF111A24),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const ValueKey('teams-quick-chat-profile'),
              onTap: _showQuickChatPicker,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: compact ? 44 : 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: compact ? 16 : 20,
                        backgroundColor: accent.withValues(alpha: 0.22),
                        child: ClipOval(
                          child: SizedBox.expand(
                            child: DominoAvatarVisual(
                              avatarKey: profile?.avatarKey ?? 'person',
                              fallbackIcon:
                                  profile?.icon ?? Icons.person_rounded,
                              backgroundColor: accent.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 2,
                      top: 1,
                      child:
                          flag.id == 'flag_none'
                              ? const SizedBox.shrink()
                              : Text(
                                flag.emoji,
                                style: TextStyle(fontSize: compact ? 11 : 14),
                              ),
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: compact ? 19 : 23,
                        height: compact ? 19 : 23,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD36B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF071524),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: Color(0xFF17202A),
                          size: compact ? 11 : 13,
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
    );
  }

  Widget _tileWidget(
    _TeamTile tile, {
    bool small = false,
    bool onBoard = false,
    bool? verticalOverride,
    Color? tileColor,
    Color? borderColor,
    Color? pipColor,
    Color? shadowColor,
    double displayScale = 1.0,
  }) {
    final dominoStyle = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.domino,
    );
    final vertical = verticalOverride ?? (!onBoard || tile.isDouble);
    final shortSide = (small ? 30.0 : 46.0) * displayScale;
    final longSide = (small ? 54.0 : 72.0) * displayScale;
    return Container(
      width: vertical ? shortSide : longSide,
      height: vertical ? longSide : shortSide,
      decoration: BoxDecoration(
        color: tileColor ?? dominoStyle.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              borderColor ??
              Color.lerp(dominoStyle.primary, Colors.black, 0.24)!,
          width: 2,
        ),
        boxShadow:
            shadowColor == null
                ? null
                : [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.85),
                    blurRadius: 13,
                    spreadRadius: 3,
                  ),
                ],
      ),
      child:
          vertical
              ? Column(
                children: [
                  Expanded(
                    child: _pipFace(
                      tile.left,
                      pipColor ?? dominoStyle.secondary,
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black38),
                  Expanded(
                    child: _pipFace(
                      tile.right,
                      pipColor ?? dominoStyle.secondary,
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    child: _pipFace(
                      tile.left,
                      pipColor ?? dominoStyle.secondary,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Colors.black38),
                  Expanded(
                    child: _pipFace(
                      tile.right,
                      pipColor ?? dominoStyle.secondary,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _pipFace(int value, [Color? color]) => CustomPaint(
    painter: _PipPainter(value, color ?? Colors.black),
    child: const SizedBox.expand(),
  );
}

/// A single slim side rail: avatar, name and hidden tiles share one axis. The
/// domino backs are deliberately wider than the painted pill so they stand
/// out, while the avatar remains upright and easy to recognize.
class TeamsResultPlayerAvatar extends StatelessWidget {
  const TeamsResultPlayerAvatar({
    super.key,
    required this.player,
    required this.avatarKey,
    required this.fallbackIcon,
    required this.size,
  });

  final int player;
  final String avatarKey;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('teams-result-player-avatar-$player'),
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF202830),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Colors.white70),
    ),
    clipBehavior: Clip.antiAlias,
    child: DominoAvatarVisual(
      avatarKey: avatarKey,
      fallbackIcon: fallbackIcon,
      backgroundColor: const Color(0xFF202830),
    ),
  );
}

/// A single slim side rail: avatar, name and hidden tiles share one axis. The
/// domino backs are deliberately wider than the painted pill so they stand
/// out, while the avatar remains upright and easy to recognize.
class TeamsSideRivalIdentity extends StatelessWidget {
  const TeamsSideRivalIdentity({
    super.key,
    required this.player,
    required this.isLeft,
    required this.compact,
    this.large = false,
    required this.showOnlineAvatar,
    required this.name,
    required this.avatarKey,
    required this.flagEmoji,
    required this.rack,
  });

  final int player;
  final bool isLeft;
  final bool compact;
  final bool large;
  final bool showOnlineAvatar;
  final String name;
  final String avatarKey;
  final String flagEmoji;
  final Widget rack;

  Widget _avatar() {
    final size = large ? 44.0 : (compact ? 28.0 : 32.0);
    return Container(
      key: ValueKey('teams-player-side-avatar-$player'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF102737),
        borderRadius: BorderRadius.circular(large ? 13 : (compact ? 8 : 10)),
        border: Border.all(
          color: const Color(0xFFFFD36B).withValues(alpha: 0.78),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: DominoAvatarVisual(
        avatarKey: avatarKey,
        fallbackIcon: Icons.person_rounded,
        backgroundColor: const Color(0xFF102737),
      ),
    );
  }

  Widget _rotatedName() {
    final rotatedName = RotatedBox(
      key: ValueKey('teams-player-rotated-name-$player'),
      quarterTurns: isLeft ? 1 : 3,
      child: Text(
        name,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 14 : (compact ? 10 : 11),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
    final nameExtent =
        (name.runes.length * (large ? 8.5 : (compact ? 6.2 : 7.0))).clamp(
          large ? 70.0 : (compact ? 44.0 : 50.0),
          large ? 118.0 : (compact ? 76.0 : 88.0),
        );
    return SizedBox(
      key: ValueKey('teams-player-side-name-$player'),
      width: large ? 29 : (compact ? 20 : 22),
      height: nameExtent,
      child: FittedBox(fit: BoxFit.scaleDown, child: rotatedName),
    );
  }

  Widget _rack() => KeyedSubtree(
    key: ValueKey('teams-player-side-rack-$player'),
    child: rack,
  );

  Widget _flag() {
    final size = large ? 44.0 : (compact ? 28.0 : 32.0);
    return SizedBox(
      key: ValueKey('teams-player-side-flag-$player'),
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          flagEmoji.trim(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            height: 1,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar();
    final nameWidget = _rotatedName();
    final rackWidget = _rack();
    final showFlag =
        showOnlineAvatar &&
        flagEmoji.trim().isNotEmpty &&
        flagEmoji.trim() != '🤖';
    final gap = SizedBox(height: large ? 5 : (compact ? 2 : 3));
    final children = <Widget>[
      avatar,
      gap,
      nameWidget,
      gap,
      rackWidget,
      if (showFlag) ...[gap, _flag()],
    ];
    return KeyedSubtree(
      key: ValueKey('teams-player-side-content-$player'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: isLeft ? children : children.reversed.toList(),
      ),
    );
  }
}

/// A compact domino back for hidden hands. The highlight, center divider and
/// inner rim make every tile readable while preserving the original footprint.
class TeamsHiddenDominoBack extends StatelessWidget {
  const TeamsHiddenDominoBack({
    super.key,
    required this.width,
    required this.height,
    this.opacity = 1,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final vertical = height >= width;
    final radius = min(width, height) * 0.22;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF62B5F4).withValues(alpha: opacity),
              const Color(0xFF1E88E5).withValues(alpha: opacity),
              const Color(0xFF0B4F9F).withValues(alpha: opacity),
            ],
            stops: const [0, 0.45, 1],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: const Color(0xFFD8EEFF).withValues(alpha: 0.92 * opacity),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38 * opacity),
              blurRadius: 2.5,
              offset: const Offset(1, 1.5),
            ),
            BoxShadow(
              color: const Color(0xFF8FD2FF).withValues(alpha: 0.22 * opacity),
              blurRadius: 2,
              offset: const Offset(-0.5, -0.5),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              margin: const EdgeInsets.all(1.6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(max(1, radius - 1)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18 * opacity),
                  width: 0.7,
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, -0.78),
              child: Container(
                width: vertical ? max(2, width - 4) : 1.2,
                height: vertical ? 1.1 : max(2, height - 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18 * opacity),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Container(
                key: const ValueKey('teams-hidden-domino-divider'),
                width: vertical ? max(2, width - 4) : 1,
                height: vertical ? 1 : max(2, height - 4),
                color: const Color(
                  0xFF073A79,
                ).withValues(alpha: 0.62 * opacity),
              ),
            ),
            Center(
              child: Container(
                width: 2.2,
                height: 2.2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.52 * opacity),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.28 * opacity),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Side { left, right }

class _TeamBoardCamera {
  const _TeamBoardCamera({required this.scale, required this.translation});

  final double scale;
  final Offset translation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TeamBoardCamera &&
          other.scale == scale &&
          other.translation == translation;

  @override
  int get hashCode => Object.hash(scale, translation);
}

class _TeamBoardCameraTween extends Tween<_TeamBoardCamera> {
  _TeamBoardCameraTween({
    required _TeamBoardCamera begin,
    required _TeamBoardCamera end,
  }) : super(begin: begin, end: end);

  @override
  _TeamBoardCamera lerp(double t) {
    final start = begin!;
    final finish = end!;
    return _TeamBoardCamera(
      scale: start.scale + (finish.scale - start.scale) * t,
      translation: Offset.lerp(start.translation, finish.translation, t)!,
    );
  }
}

/// Keeps the complete painted red/blue preview easy to tap even when the
/// domino is visually scaled beyond its original layout size.
class TeamsSideChoiceTapTarget extends StatelessWidget {
  const TeamsSideChoiceTapTarget({
    super.key,
    required this.visualWidth,
    required this.visualHeight,
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
    this.tapPadding = 14,
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

class _TeamsPlayerProfileData {
  const _TeamsPlayerProfileData({
    required this.player,
    required this.name,
    required this.publicId,
    required this.countryCode,
    required this.flagEmoji,
    required this.avatarKey,
    required this.points,
    required this.isCpu,
    required this.tiles,
  });

  final int player;
  final String name;
  final String publicId;
  final String countryCode;
  final String flagEmoji;
  final String avatarKey;
  final int points;
  final bool isCpu;
  final int tiles;

  int get team => player.isEven ? 0 : 1;
}

class _BoardSidePreview {
  const _BoardSidePreview({
    required this.side,
    required this.placement,
    required this.tile,
    required this.color,
  });

  final _Side side;
  final TeamBoardPlacement placement;
  final _TeamTile tile;
  final Color color;
}

class _TeamTile {
  const _TeamTile(this.left, this.right);
  final int left;
  final int right;
  bool get isDouble => left == right;
  int get points => left + right;
  int get id => min(left, right) * 10 + max(left, right);
  String get label => '$left-$right';
  _TeamTile get flipped => _TeamTile(right, left);
}

class _PipPainter extends CustomPainter {
  const _PipPainter(this.value, this.color);
  final int value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = min(size.width, size.height) * 0.075;
    final left = size.width * 0.27;
    final right = size.width * 0.73;
    final top = size.height * 0.25;
    final middle = size.height * 0.5;
    final bottom = size.height * 0.75;
    final points = switch (value) {
      1 => [Offset(size.width / 2, middle)],
      2 => [Offset(left, top), Offset(right, bottom)],
      3 => [
        Offset(left, top),
        Offset(size.width / 2, middle),
        Offset(right, bottom),
      ],
      4 => [
        Offset(left, top),
        Offset(right, top),
        Offset(left, bottom),
        Offset(right, bottom),
      ],
      5 => [
        Offset(left, top),
        Offset(right, top),
        Offset(size.width / 2, middle),
        Offset(left, bottom),
        Offset(right, bottom),
      ],
      6 => [
        Offset(left, top),
        Offset(right, top),
        Offset(left, middle),
        Offset(right, middle),
        Offset(left, bottom),
        Offset(right, bottom),
      ],
      _ => const <Offset>[],
    };
    for (final point in points) {
      canvas.drawCircle(point, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PipPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
