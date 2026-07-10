// lib/screens/game_screen.dart
import 'dart:async';
import 'dart:convert';

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
import '../widgets/anchored_adaptive_banner_ad.dart';
import '../widgets/app_version_label.dart';
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
          title: Text(dialogTitle),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style:
                      Theme.of(
                        context,
                      ).textTheme.bodyMedium, // Adapt text color and size
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle:
                        Theme.of(context)
                            .textTheme
                            .bodyMedium, // Adapt hint text color and size
                  ),
                  onSubmitted: (_) {
                    setState(() {
                      if (int.tryParse(pointsController.text) != null &&
                          int.tryParse(pointsController.text)! > 200) {
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext innerDialogContext) {
                            return AlertDialog(
                              content: Text(appLocalizations.noMoreThan200),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text("OK"),
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
              child: Text(appLocalizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
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
                          content: Text(appLocalizations.noMoreThan200),
                          actions: <Widget>[
                            TextButton(
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
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/fireworks'),
            builder:
                (context) => FireworksScreen(winningTeamName: winningTeamName),
          ),
        );
      } else {
        _undoLastAdded();
      }
    }
  }

  // Reset game scores (called from AppBar button now)
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
          title: Text(appLocalizations.changeTeamName), // Localized title
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText:
                        appLocalizations.enterNewTeamName, // Localized hint
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(appLocalizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
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

  Widget _buildGameReturnButton(bool openedFromDominoGame) {
    Widget button = FilledButton.icon(
      onPressed: () {
        if (openedFromDominoGame && Navigator.canPop(context)) {
          Navigator.pop(context);
          return;
        }
        Navigator.pushNamed(context, '/start-game');
      },
      icon: const Icon(Icons.sports_esports_rounded, size: 18),
      label: Text(
        Localizations.localeOf(context).languageCode == 'es' ? 'Juego' : 'Game',
      ),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Center(child: _buildGameReturnButton(openedFromDominoGame)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
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
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: _resetGame,
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
                  Color.fromARGB((255 * 0.3).round(), 0, 0, 0),
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
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x66000000)
                      : const Color(0x33FFFFFF),
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xAA000000)
                      : const Color(0x66FFFFFF),
                ],
              ),
            ),
          ),
          // Game Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                        const SizedBox(width: 16),
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
                  const AppVersionLabel(
                    padding: EdgeInsets.only(top: 5, bottom: 3),
                    fontSize: 10,
                  ),
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
    final bool compactPhone = !isTablet && screenWidth < 480;
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 16 : 10),
      ),
      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
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
              child: Text(
                teamName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: baseHeadline,
                  fontWeight: FontWeight.w700,
                ), // Adapt text color and size
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
                      ), // Adapt text color and size
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Text(
              '${appLocalizations.total}: ${_getTotalScore(scores)}', // Localized "Total"
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: baseHeadline * scoreScale,
                fontWeight: FontWeight.w700,
              ), // Adapt text color and size
            ),
            SizedBox(height: isTablet ? 16 : 10),
            // Buttons for each team (remove, add, and bonus)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: actionButtonSize,
                  height: actionButtonSize,
                  child: FloatingActionButton(
                    heroTag:
                        'remove_${teamName.replaceAll(' ', '')}Btn', // Unique tag
                    onPressed: () => _removeLastScoreForTeam(scores),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.remove, size: actionIconSize),
                  ),
                ),
                SizedBox(width: buttonSpacing),
                SizedBox(
                  width: actionButtonSize,
                  height: actionButtonSize,
                  child: FloatingActionButton(
                    heroTag:
                        'add_${teamName.replaceAll(' ', '')}Btn', // Unique tag for add button
                    onPressed:
                        () => _showManualPointsDialog(
                          context,
                          scores,
                          appLocalizations,
                        ), // Call dialog for add
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.add, size: actionIconSize),
                  ),
                ),
                SizedBox(width: buttonSpacing),
                SizedBox(
                  width: actionButtonSize,
                  height: actionButtonSize,
                  child: FloatingActionButton(
                    heroTag:
                        'bonus_${teamName.replaceAll(' ', '')}Btn', // Unique tag
                    onPressed:
                        () => _addDefaultBonus(
                          scores,
                        ), // Directly add default bonus
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.star, size: actionIconSize), // Bonus icon
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
