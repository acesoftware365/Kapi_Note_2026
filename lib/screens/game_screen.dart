// lib/screens/game_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dominoes_note2025/screens/team_name_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import generated localizations
import 'package:provider/provider.dart'; // Import provider
import 'package:flutter/foundation.dart'; // NEW: Import for defaultTargetPlatform

import '../game_settings_notifier.dart'; // Import game settings notifier
import '../font_size_notifier.dart';
import '../l10n/app_localizations.dart';
import '../services/analytics_service.dart';
import '../constants/audio_assets.dart';
import '../services/audio_manager.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import 'admob_variable.dart';
import 'fireworks_screen.dart'; // I// Import font size notifier

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _teamAScores = [];
  final List<int> _teamBScores = [];
  List<int>? _lastAddedScores;
  late final AnimationController _gameButtonPulseController;

  static const Color _notesNavy = Color(0xFF071421);
  static const Color _notesPanel = Color(0xFF10243A);
  static const Color _notesGold = Color(0xFFF2C65A);
  static const Color _notesRed = Color(0xFFEF3E38);
  static const Color _notesBlue = Color(0xFF2F8EEB);

  // TODO: Replace this test ad unit ID with your own banner ad unit ID.
  final String _adUnitId =
      (defaultTargetPlatform ==
              TargetPlatform.android) // FIXED: Using defaultTargetPlatform
          ? AdmobVariable
              .bannerAndroidUnit // Test Android Banner
          : AdmobVariable.bannerIosUnit; // Test iOS Banner

  @override
  void initState() {
    super.initState();
    _gameButtonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);
    unawaited(AudioManager.instance.stopAll());
    _loadScores();
  }

  Future<void> _loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final String? teamAJson = prefs.getString('teamAScores');
    final String? teamBJson = prefs.getString('teamBScores');
    if (teamAJson != null) {
      final List<dynamic> decoded = jsonDecode(teamAJson);
      _teamAScores
        ..clear()
        ..addAll(decoded.map((e) => e as int));
    }
    if (teamBJson != null) {
      final List<dynamic> decoded = jsonDecode(teamBJson);
      _teamBScores
        ..clear()
        ..addAll(decoded.map((e) => e as int));
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teamAScores', jsonEncode(_teamAScores));
    await prefs.setString('teamBScores', jsonEncode(_teamBScores));
  }

  // Method to remove the last score for a specific team
  void _removeLastScoreForTeam(List<int> scores) {
    setState(() {
      if (scores.isNotEmpty) {
        scores.removeLast();
      }
      _checkMaxScoreReached(); // Check after removing a score
    });
    _saveScores();
  }

  void _markLastAdded(List<int> scores) {
    _lastAddedScores = scores;
  }

  void _undoLastAdded() {
    final List<int>? scores = _lastAddedScores;
    if (scores != null && scores.isNotEmpty) {
      setState(() {
        scores.removeLast();
      });
      _saveScores();
    }
  }

  // Method to show a dialog for adding regular points
  Future<void> _showManualPointsDialog(
    BuildContext context,
    List<int> scores,
    AppLocalizations appLocalizations,
  ) async {
    final TextEditingController pointsController = TextEditingController();
    String dialogTitle = appLocalizations.enterPoints;
    String hintText = appLocalizations.points;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _notesPanel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _notesGold, width: 1.5),
          ),
          title: Text(
            dialogTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: _notesNavy,
                    prefixIcon: const Icon(
                      Icons.calculate_rounded,
                      color: _notesGold,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _notesGold,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    setState(() {
                      if (int.tryParse(pointsController.text) != null &&
                          int.tryParse(pointsController.text)! > 200) {
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext innerDialogContext) {
                            return AlertDialog(
                              backgroundColor: _notesPanel,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                                side: const BorderSide(color: _notesGold),
                              ),
                              content: Text(
                                appLocalizations.noMoreThan200,
                                style: const TextStyle(color: Colors.white),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: _notesGold,
                                  ),
                                  child: const Text('OK'),
                                  onPressed: () {
                                    pointsController.clear();
                                    Navigator.of(innerDialogContext).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        int? points = int.tryParse(pointsController.text);
                        if (points != null) {
                          scores.add(points);
                          _markLastAdded(scores);
                        }
                        Navigator.of(context).pop();
                        _checkMaxScoreReached();
                      }
                    });
                    _saveScores();
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: Text(appLocalizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _notesGold),
              child: Text(appLocalizations.add),
              onPressed: () {
                setState(() {
                  ///Todo: if point enter is more than 200 point
                  //if point enter is more than 200 point
                  if (int.tryParse(pointsController.text) != null &&
                      int.tryParse(pointsController.text)! > 200) {
                    // Show error dialog
                    showDialog<void>(
                      context:
                          context, // Use the context from the parent AlertDialog's builder
                      builder: (BuildContext innerDialogContext) {
                        // This context is for the new dialog
                        return AlertDialog(
                          backgroundColor: _notesPanel,
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: const BorderSide(color: _notesGold),
                          ),
                          content: Text(
                            appLocalizations.noMoreThan200,
                            style: const TextStyle(color: Colors.white),
                          ),
                          actions: <Widget>[
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: _notesGold,
                              ),
                              child: const Text(
                                "OK",
                              ), // Using a plain string "OK"
                              onPressed: () {
                                //clear text field
                                pointsController.clear();
                                Navigator.of(
                                  innerDialogContext,
                                ).pop(); // Dismisses this "hello" dialog
                              },
                            ),
                          ],
                        );
                      },
                    );
                    //end show error dialog
                    //end if point enter is more less 200 point and not null
                  } else {
                    // Add the entered points to the list
                    int? points = int.tryParse(pointsController.text);
                    if (points != null) {
                      scores.add(points);
                      _markLastAdded(scores);
                    }
                    Navigator.of(context).pop();
                    _checkMaxScoreReached(); // Check after adding a score
                    //end if point enter is more than 200 point
                  }
                });
                _saveScores();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to add the default bonus directly
  void _addDefaultBonus(List<int> scores) {
    final gameSettingsNotifier = Provider.of<GameSettingsNotifier>(
      context,
      listen: false,
    );
    setState(() {
      scores.add(gameSettingsNotifier.defaultBonus);
      _markLastAdded(scores);
    });
    _checkMaxScoreReached();
    _saveScores();
  }

  // Function to calculate total score for a team
  int _getTotalScore(List<int> scores) {
    return scores.fold(0, (sum, item) => sum + item);
  }

  // Check if max score is reached
  Future<void> _checkMaxScoreReached() async {
    final gameSettingsNotifier = Provider.of<GameSettingsNotifier>(
      context,
      listen: false,
    );
    final teamNameNotifier = Provider.of<TeamNameNotifier>(
      context,
      listen: false,
    ); // Access team name notifier
    final int maxScore = gameSettingsNotifier.maxScore;

    final int totalA = _getTotalScore(_teamAScores);
    final int totalB = _getTotalScore(_teamBScores);

    String winningTeamName = '';
    final AppLocalizations appLocalizations =
        AppLocalizations.of(context)!; // Get localizations here

    if (totalA >= maxScore && totalB >= maxScore) {
      winningTeamName =
          appLocalizations.bothTeams; // Both teams reached max score
    } else if (totalA >= maxScore) {
      winningTeamName = teamNameNotifier.teamAName; // Team A won
    } else if (totalB >= maxScore) {
      winningTeamName = teamNameNotifier.teamBName; // Team B won
    }

    if (winningTeamName.isNotEmpty) {
      final bool? goFireworks = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(appLocalizations.confirmEndTitle),
            content: Text(appLocalizations.confirmEndMessage),
            actions: <Widget>[
              TextButton(
                child: Text(appLocalizations.cancel),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: Text(appLocalizations.confirmEndOk),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        },
      );

      if (goFireworks == true) {
        if (!mounted) return;
        unawaited(
          AnalyticsService.logGameCompleted(
            winningTeamName: winningTeamName,
            teamATotal: totalA,
            teamBTotal: totalB,
            maxScore: maxScore,
          ),
        );
        final resetNotes = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/fireworks'),
            builder:
                (context) => FireworksScreen(winningTeamName: winningTeamName),
          ),
        );
        if (resetNotes == true && mounted) {
          _resetGame();
        }
      } else {
        _undoLastAdded();
      }
    }
  }

  Future<void> _confirmResetGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .76),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_notesPanel, _notesNavy],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _notesGold, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _notesRed.withValues(alpha: .16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _notesRed.withValues(alpha: .8),
                        ),
                      ),
                      child: const Icon(
                        Icons.restart_alt_rounded,
                        color: _notesRed,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Reset all scores?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'This will remove every score for both teams and cannot be undone.',
                  style: TextStyle(
                    color: Color(0xFFC3CAD2),
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _notesRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 19),
                        label: const Text(
                          'Reset',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
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

    if (confirmed == true && mounted) {
      _resetGame();
    }
  }

  // Reset game scores after an explicit confirmation from the AppBar button.
  void _resetGame() {
    setState(() {
      _teamAScores.clear();
      _teamBScores.clear();
    });
    unawaited(AnalyticsService.logGameReset());
    _saveScores();
  }

  // Method to show a dialog for changing team name
  Future<void> _showChangeTeamNameDialog(
    BuildContext context,
    String currentName,
    Function(String) onNameChanged,
    AppLocalizations appLocalizations,
  ) async {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _notesPanel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _notesGold, width: 1.5),
          ),
          title: Text(
            appLocalizations.changeTeamName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        appLocalizations.enterNewTeamName, // Localized hint
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: _notesNavy,
                    prefixIcon: const Icon(
                      Icons.groups_rounded,
                      color: _notesGold,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _notesGold,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: Text(appLocalizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _notesGold),
              child: Text(appLocalizations.save), // Localized save button
              onPressed: () {
                onNameChanged(nameController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _gameButtonPulseController.dispose();
    _saveScores();
    super.dispose();
  }

  Widget _buildGameReturnButton(
    bool openedFromDominoGame, {
    bool compact = false,
  }) {
    void openGame() {
      if (openedFromDominoGame && Navigator.canPop(context)) {
        unawaited(AudioManager.instance.playMusic(AudioAssets.gameplayLoop));
        Navigator.pop(context);
        return;
      }
      Navigator.pushNamed(context, '/start-game');
    }

    final style = FilledButton.styleFrom(
      backgroundColor: const Color(0xFFE53935),
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 16,
        vertical: compact ? 8 : 9,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
    final Widget button =
        compact
            ? Tooltip(
              message:
                  Localizations.localeOf(context).languageCode == 'es'
                      ? 'Volver al juego'
                      : 'Return to game',
              child: FilledButton(
                onPressed: openGame,
                style: style,
                child: const Icon(Icons.sports_esports_rounded, size: 20),
              ),
            )
            : FilledButton.icon(
              onPressed: openGame,
              icon: const Icon(Icons.sports_esports_rounded, size: 18),
              label: Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Juego'
                    : 'Game',
              ),
              style: style,
            );

    if (!openedFromDominoGame) return button;

    return AnimatedBuilder(
      animation: _gameButtonPulseController,
      builder: (context, child) {
        final glow = 0.18 + (_gameButtonPulseController.value * 0.22);
        final scale = 1.0 + (_gameButtonPulseController.value * 0.035);
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: glow),
                  blurRadius: 14 + (_gameButtonPulseController.value * 6),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: button,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context)!;
    final teamNameNotifier = Provider.of<TeamNameNotifier>(context);
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(context);
    final routeArguments = ModalRoute.of(context)?.settings.arguments;
    final openedFromDominoGame =
        routeArguments is Map && routeArguments['fromDominoGame'] == true;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactPhone = screenWidth < 380;
    final contentPadding = compactPhone ? 8.0 : 16.0;
    final teamGap = compactPhone ? 8.0 : 16.0;

    return Scaffold(
      backgroundColor: _notesNavy,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Center(
          child: _buildGameReturnButton(
            openedFromDominoGame,
            compact: compactPhone,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF970A0E), Color(0xFF43070B)],
            ),
          ),
        ),
        elevation: 0,
        foregroundColor: Colors.white,
        leading:
            openedFromDominoGame
                ? null
                : IconButton(
                  icon: const Icon(Icons.home_rounded),
                  tooltip: appLocalizations.homeScreenTitle,
                  onPressed:
                      () => Navigator.pushReplacementNamed(context, '/home'),
                ),
        actions: [
          // Reset Game Button in AppBar
          if (compactPhone)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset',
              onPressed: _confirmResetGame,
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: _confirmResetGame,
            ),
          // Settings Button in AppBar
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: appLocalizations.settingsButton, // Use localized tooltip
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
        // AppBar color will adapt based on theme
      ),
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  const Color(0xDD071421),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0x440E263B), Color(0xCC071421)],
              ),
            ),
          ),
          // Game Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Team A Column
                        Expanded(
                          child: _buildTeamColumn(
                            context,
                            teamNameNotifier
                                .teamAName, // Use team A name from notifier
                            (newName) => teamNameNotifier.setTeamAName(
                              newName,
                            ), // Callback to update team A name
                            _teamAScores,
                            appLocalizations,
                            fontSizeNotifier.scoreFontSizeScale,
                          ),
                        ),
                        // Spacer between columns
                        SizedBox(width: teamGap),
                        // Team B Column
                        Expanded(
                          child: _buildTeamColumn(
                            context,
                            teamNameNotifier
                                .teamBName, // Use team B name from notifier
                            (newName) => teamNameNotifier.setTeamBName(
                              newName,
                            ), // Callback to update team B name
                            _teamBScores,
                            appLocalizations,
                            fontSizeNotifier.scoreFontSizeScale,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamColumn(
    BuildContext context,
    String teamName,
    Function(String) onNameChanged, // Callback to update team name
    List<int> scores,
    AppLocalizations appLocalizations,
    double scoreScale,
  ) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= 600;
    final double baseBody =
        (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) *
        (isTablet ? 1.35 : 1.0);
    final double baseHeadline =
        (Theme.of(context).textTheme.headlineMedium?.fontSize ?? 20) *
        (isTablet ? 1.45 : 1.0);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool compactPhone = !isTablet && screenWidth < 400;
    final double actionButtonSize =
        isTablet
            ? 72.0
            : compactPhone
            ? 38.0
            : 46.0;
    final double actionIconSize =
        isTablet
            ? 38.0
            : compactPhone
            ? 22.0
            : 24.0;
    final double cardPadding =
        isTablet
            ? 20.0
            : compactPhone
            ? 9.0
            : 12.0;
    final double buttonSpacing =
        isTablet
            ? 18.0
            : compactPhone
            ? 7.0
            : 12.0;
    final Color accentColor =
        identical(scores, _teamAScores) ? _notesBlue : _notesRed;

    return Container(
      key: ValueKey('notes-team-panel-$teamName'),
      decoration: BoxDecoration(
        color: _notesPanel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.78),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          children: [
            GestureDetector(
              // Make team name tappable
              onTap:
                  () => _showChangeTeamNameDialog(
                    context,
                    teamName,
                    onNameChanged,
                    appLocalizations,
                  ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 8,
                  vertical: isTablet ? 12 : 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.70),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    teamName,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: baseHeadline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isTablet ? 16 : 10),
            Expanded(
              child: ListView.builder(
                itemCount: scores.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      scores[index].toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: baseBody * scoreScale,
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                      ), // Adapt text color and size
                    ),
                  );
                },
              ),
            ),
            Divider(color: accentColor.withValues(alpha: 0.60), thickness: 1.5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${appLocalizations.total}: ${_getTotalScore(scores)}',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _notesGold,
                  fontSize: baseHeadline * scoreScale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: isTablet ? 16 : 10),
            // Buttons for each team (remove, add, and bonus)
            LayoutBuilder(
              builder: (context, constraints) {
                final fittedSpacing = min(
                  buttonSpacing,
                  max(3.0, constraints.maxWidth * 0.04),
                );
                final fittedButtonSize = min(
                  actionButtonSize,
                  max(24.0, (constraints.maxWidth - fittedSpacing * 2) / 3),
                );
                final fittedIconSize = min(
                  actionIconSize,
                  fittedButtonSize * 0.58,
                );
                Widget actionButton({
                  required String heroTag,
                  required VoidCallback onPressed,
                  required Color color,
                  required IconData icon,
                }) => SizedBox(
                  width: fittedButtonSize,
                  height: fittedButtonSize,
                  child: FloatingActionButton(
                    heroTag: heroTag,
                    onPressed: onPressed,
                    backgroundColor: color,
                    foregroundColor:
                        color == _notesGold ? _notesNavy : Colors.white,
                    elevation: 2,
                    child: Icon(icon, size: fittedIconSize),
                  ),
                );

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    actionButton(
                      heroTag: 'remove_${teamName.replaceAll(' ', '')}Btn',
                      onPressed: () => _removeLastScoreForTeam(scores),
                      color: _notesRed,
                      icon: Icons.remove,
                    ),
                    SizedBox(width: fittedSpacing),
                    actionButton(
                      heroTag: 'add_${teamName.replaceAll(' ', '')}Btn',
                      onPressed:
                          () => _showManualPointsDialog(
                            context,
                            scores,
                            appLocalizations,
                          ),
                      color: _notesBlue,
                      icon: Icons.add,
                    ),
                    SizedBox(width: fittedSpacing),
                    actionButton(
                      heroTag: 'bonus_${teamName.replaceAll(' ', '')}Btn',
                      onPressed: () => _addDefaultBonus(scores),
                      color: _notesGold,
                      icon: Icons.star,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
