import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../constants/audio_assets.dart';
import '../../services/audio_manager.dart';
import '../../services/kapi_cosmetics_service.dart';
import '../../services/teams_online_service.dart';
import '../domino_player_profile.dart';
import 'domino_teams_cpu_screen.dart';

class TeamsMatchFoundTransitionScreen extends StatefulWidget {
  const TeamsMatchFoundTransitionScreen({
    super.key,
    required this.gameId,
    required this.playerId,
    required this.players,
  });

  final String gameId;
  final String playerId;
  final List<TeamsOnlinePlayer> players;

  @override
  State<TeamsMatchFoundTransitionScreen> createState() =>
      _TeamsMatchFoundTransitionScreenState();
}

class _TeamsMatchFoundTransitionScreenState
    extends State<TeamsMatchFoundTransitionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..forward();
    unawaited(AudioManager.instance.playSfx(AudioAssets.playerJoined));
    _timer = Timer(const Duration(milliseconds: 3800), _openGame);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openGame() {
    if (!mounted) return;
    unawaited(AudioManager.instance.playSfx(AudioAssets.gameStart));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/domino-teams-online'),
        builder:
            (_) => DominoTeamsCpuScreen(
              onlineGameId: widget.gameId,
              onlinePlayerId: widget.playerId,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    final seats = TeamsOnlineRoster.relativeSeats(
      players: widget.players,
      currentPlayerId: widget.playerId,
    );
    final myTeam = [seats[0], seats[2]];
    final rivals = [seats[1], seats[3]];
    return Scaffold(
      backgroundColor: const Color(0xFF071524),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final panels = Curves.easeOutCubic.transform(
            (progress / .34).clamp(0.0, 1.0),
          );
          final cards = Curves.easeOutBack.transform(
            ((progress - .22) / .38).clamp(0.0, 1.0),
          );
          final impact = Curves.elasticOut.transform(
            ((progress - .30) / .30).clamp(0.0, 1.0),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: Transform.translate(
                        offset: Offset((1 - panels) * 300, 0),
                        child: const ColoredBox(color: Color(0xFF680908)),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: Offset((panels - 1) * 300, 0),
                        child: const ColoredBox(color: Color(0xFF0A3157)),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
                  child: Column(
                    children: [
                      Text(
                        spanish ? 'EQUIPOS LISTOS' : 'TEAMS READY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Transform.translate(
                        offset: Offset((1 - cards) * 100, 0),
                        child: Opacity(
                          opacity: cards.clamp(0, 1),
                          child: _TeamRow(
                            label: spanish ? 'RIVALES' : 'RIVALS',
                            players: rivals,
                            accent: const Color(0xFFFF6B64),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Transform.scale(
                        scale: max(.01, impact),
                        child: Container(
                          width: 86,
                          height: 86,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF101820),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFD36B),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xAA63E6FF),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Transform.translate(
                        offset: Offset((cards - 1) * 100, 0),
                        child: Opacity(
                          opacity: cards.clamp(0, 1),
                          child: _TeamRow(
                            label: spanish ? 'TU EQUIPO' : 'YOUR TEAM',
                            players: myTeam,
                            accent: const Color(0xFF64B5F6),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        spanish
                            ? 'PREPARANDO PARTIDA...'
                            : 'PREPARING MATCH...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        color: const Color(0xFFFFD36B),
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.label,
    required this.players,
    required this.accent,
  });

  final String label;
  final List<TeamsOnlinePlayer?> players;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
    decoration: BoxDecoration(
      color: const Color(0xE6101820),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: accent, width: 2),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < players.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(child: _PlayerCard(player: players[index])),
            ],
          ],
        ),
      ],
    ),
  );
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player});

  final TeamsOnlinePlayer? player;

  String? _flagEmoji(TeamsOnlinePlayer player) {
    if (player.isCpu &&
        !player.replacedPlayer &&
        !player.isFallbackOnlinePlayer) {
      return null;
    }
    final cosmetic = KapiCosmeticsService.byId(player.badgeKey);
    if (cosmetic.type == KapiCosmeticType.flag && cosmetic.id != 'flag_none') {
      return cosmetic.emoji;
    }
    final rawCountry = player.countryCode.trim().toUpperCase();
    final country = rawCountry == 'DR' ? 'DO' : rawCountry;
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country)) return null;
    return String.fromCharCodes(
      country.codeUnits.map((character) => character + 127397),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = player;
    if (value == null) return const SizedBox(height: 82);
    final visibleAsCpu = value.isCpu && !value.isFallbackOnlinePlayer;
    final tier = DominoTierVisual.fromScore(
      value.points,
      ranked: !visibleAsCpu,
    );
    final flag = _flagEmoji(value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 145;
        final wide = constraints.maxWidth >= 260;
        final cardHeight = wide ? 96.0 : 82.0;
        final horizontalPadding = wide ? 14.0 : (compact ? 7.0 : 9.0);
        final avatarSize = wide ? 60.0 : (compact ? 42.0 : 50.0);
        final flagWidth = wide ? 78.0 : (compact ? 30.0 : 48.0);
        final flagHeight = wide ? 62.0 : (compact ? 34.0 : 54.0);
        final avatarGap = wide ? 12.0 : (compact ? 5.0 : 7.0);
        final flagGap = wide ? 10.0 : (compact ? 2.0 : 4.0);
        return SizedBox(
          key: ValueKey('teams-ready-player-card-${value.id}'),
          height: cardHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x99101820),
                      border: Border.all(color: Colors.white12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Row(
                      children: [
                        Container(
                          key: ValueKey(
                            'teams-ready-player-avatar-${value.id}',
                          ),
                          width: avatarSize,
                          height: avatarSize,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: tier.deep,
                            borderRadius: BorderRadius.circular(wide ? 18 : 15),
                            border: Border.all(
                              color: tier.frameColor(active: true),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x99000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: DominoAvatarVisual(
                            avatarKey: value.avatarKey,
                            fallbackIcon:
                                visibleAsCpu
                                    ? Icons.smart_toy_rounded
                                    : Icons.person,
                            backgroundColor: tier.deep,
                          ),
                        ),
                        SizedBox(width: avatarGap),
                        Expanded(
                          child: KeyedSubtree(
                            key: ValueKey(
                              'teams-ready-player-text-${value.id}',
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  value.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 13 : (wide ? 16 : 14),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  visibleAsCpu
                                      ? 'CPU'
                                      : '${value.countryCode} · ${tier.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: compact ? 9 : (wide ? 11 : 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (flag != null) ...[
                          SizedBox(width: flagGap),
                          SizedBox(
                            key: ValueKey(
                              'teams-ready-player-flag-${value.id}',
                            ),
                            width: flagWidth,
                            height: flagHeight,
                            child: Opacity(
                              opacity: .78,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(
                                  flag,
                                  style: const TextStyle(
                                    fontSize: 84,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
