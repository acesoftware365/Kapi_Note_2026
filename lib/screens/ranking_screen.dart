import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/anchored_adaptive_banner_ad.dart';
import 'admob_variable.dart';
import 'domino_player_profile.dart';
import '../services/player_points_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final ScrollController _scrollController = ScrollController();
  _RankingMode _selectedMode = _RankingMode.block;

  late final Future<DominoPlayerProfile> _profileFuture = _loadProfile();
  final Stream<QuerySnapshot<Map<String, dynamic>>> _rankingStream =
      FirebaseFirestore.instance
          .collection('kapi_ranking_seasons')
          .doc(PlayerPointsService.seasonIdFor())
          .collection('players')
          .orderBy('totalPoints', descending: true)
          .limit(100)
          .snapshots();

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  Future<DominoPlayerProfile> _loadProfile() async {
    final profile = await DominoPlayerProfile.load();
    await PlayerPointsService.ensureProfileRegistered(
      code: profile.code,
      publicId: profile.publicId,
      initials: profile.initials,
      countryCode: profile.countryCode,
    );
    return profile;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToPlayer(int currentRank) {
    const rowExtent = 78.0;
    if (!_scrollController.hasClients) return;
    final target = ((currentRank - 2) * rowExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: _isSpanish ? 'Volver' : 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSpanish ? 'Ranking de jugadores' : 'Player Ranking',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Color(0xAA000000),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA4B0706), Color(0xDD071524)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: FutureBuilder<DominoPlayerProfile>(
                    future: _profileFuture,
                    builder: (context, profileSnapshot) {
                      final profile = profileSnapshot.data;
                      if (profile == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _rankingStream,
                        builder: (context, rankingSnapshot) {
                          return FutureBuilder<List<_RankingEntry>>(
                            future: _entriesFromSnapshots(
                              profile,
                              rankingSnapshot,
                            ),
                            builder: (context, entriesSnapshot) {
                              final allEntries = entriesSnapshot.data;
                              if (allEntries == null) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final entries = _entriesForSelectedMode(
                                allEntries,
                              );
                              final currentEntry = entries.firstWhere(
                                (entry) => entry.code == profile.code,
                                orElse:
                                    () => _RankingEntry.fromProfile(
                                      profile,
                                      rank: 0,
                                      mode: _selectedMode.label,
                                    ),
                              );
                              return Padding(
                                padding: EdgeInsets.fromLTRB(
                                  isTablet ? 28 : 16,
                                  12,
                                  isTablet ? 28 : 16,
                                  16,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _isSpanish
                                          ? 'Temporada mensual · reinicia el dia 1'
                                          : 'Monthly season · resets on day 1',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.72,
                                        ),
                                        fontSize: isTablet ? 16 : 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _showPastMonths,
                                      icon: const Icon(
                                        Icons.emoji_events_rounded,
                                      ),
                                      label: Text(
                                        _isSpanish
                                            ? 'Top 3 de meses pasados'
                                            : 'Past months top 3',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFFFD36B,
                                        ),
                                        side: BorderSide(
                                          color: const Color(
                                            0xFFFFD36B,
                                          ).withValues(alpha: 0.64),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildModeTabs(isTablet),
                                    const SizedBox(height: 10),
                                    _buildCurrentPlayerCard(
                                      currentEntry,
                                      isTablet,
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: _buildRankingList(
                                        entries,
                                        profile.code,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                AnchoredAdaptiveBannerAd(
                  adUnitId: _adUnitId,
                  margin: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _seasonLabel(String seasonId) {
    final parts = seasonId.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    final month = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    return MaterialLocalizations.of(
      context,
    ).formatMonthYear(DateTime(year, month));
  }

  void _showPastMonths() {
    final seasons = PlayerPointsService.previousSeasonIds(count: 12);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1E2D),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSpanish
                        ? 'Ganadores de meses pasados'
                        : 'Past monthly winners',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSpanish
                        ? 'Elige un mes para ver sus tres primeros lugares.'
                        : 'Choose a month to see its top three players.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: seasons.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                      itemBuilder: (context, index) {
                        final seasonId = seasons[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFFFFD36B),
                          ),
                          title: Text(
                            _seasonLabel(seasonId),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white70,
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showSeasonPodium(seasonId);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showSeasonPodium(String seasonId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD36B)),
          ),
    );
    List<_RankingEntry> entries = const [];
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('kapi_ranking_seasons')
              .doc(seasonId)
              .collection('players')
              .orderBy('totalPoints', descending: true)
              .limit(3)
              .get();
      entries = [
        for (var i = 0; i < snapshot.docs.length; i++)
          _RankingEntry.fromFirestore(snapshot.docs[i]).copyWith(rank: i + 1),
      ];
    } catch (_) {
      entries = const [];
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF101820),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFFFD36B)),
            ),
            title: Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD36B),
                  size: 42,
                ),
                const SizedBox(height: 6),
                Text(
                  _seasonLabel(seasonId),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            content:
                entries.isEmpty
                    ? Text(
                      _isSpanish
                          ? 'Todavia no hay resultados guardados para este mes.'
                          : 'There are no saved results for this month yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in entries) _buildPodiumRow(entry),
                      ],
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_isSpanish ? 'Cerrar' : 'Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildPodiumRow(_RankingEntry entry) {
    const colors = <Color>[
      Color(0xFFFFD36B),
      Color(0xFFC7D0D9),
      Color(0xFFCD8B55),
    ];
    final color = colors[(entry.rank - 1).clamp(0, 2)];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            foregroundColor: const Color(0xFF101820),
            child: Text(
              '${entry.rank}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.id,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${entry.points} pts',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Future<List<_RankingEntry>> _entriesFromSnapshots(
    DominoPlayerProfile profile,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) async {
    final entries = <_RankingEntry>[];
    if (snapshot.hasData) {
      for (final doc in snapshot.data!.docs) {
        entries.add(_RankingEntry.fromFirestore(doc));
      }
    }
    if (entries.isEmpty) {
      entries.add(await _RankingEntry.fromLocal(profile, rank: 1));
    } else if (!entries.any((entry) => entry.code == profile.code)) {
      entries.add(
        await _RankingEntry.fromLocal(profile, rank: entries.length + 1),
      );
    }
    entries.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byWins = b.wins.compareTo(a.wins);
      if (byWins != 0) return byWins;
      final byLosses = a.losses.compareTo(b.losses);
      if (byLosses != 0) return byLosses;
      return a.id.compareTo(b.id);
    });
    for (var i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(rank: i + 1);
    }
    return entries;
  }

  List<_RankingEntry> _entriesForSelectedMode(List<_RankingEntry> allEntries) {
    final entries =
        allEntries.where((entry) => entry.mode == _selectedMode.label).toList();
    for (var i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(rank: i + 1);
    }
    return entries;
  }

  Widget _buildModeTabs(bool isTablet) {
    return Container(
      height: isTablet ? 52 : 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children:
            _RankingMode.values.map((mode) {
              final selected = mode == _selectedMode;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (mode != _RankingMode.block &&
                        mode != _RankingMode.teams) {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 82),
                            backgroundColor: const Color(0xFF101820),
                            content: Text(
                              _isSpanish
                                  ? '${mode.label} todavia no esta disponible.'
                                  : '${mode.label} is not available yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      return;
                    }
                    setState(() => _selectedMode = mode);
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? const Color(0xFF1E88E5)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          selected
                              ? Border.all(color: const Color(0xFFFFD36B))
                              : null,
                    ),
                    child: Text(
                      mode.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w900,
                        fontSize: isTablet ? 15 : 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildRankingList(List<_RankingEntry> entries, String currentCode) {
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.leaderboard_rounded,
                  color: Colors.white.withValues(alpha: 0.58),
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  _isSpanish
                      ? 'Todavia no hay partidas de ${_selectedMode.label}.'
                      : 'No ${_selectedMode.label} matches yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: entries.length,
          separatorBuilder:
              (_, __) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _buildRankingRow(entry, entry.code == currentCode);
          },
        ),
      ),
    );
  }

  Widget _buildCurrentPlayerCard(_RankingEntry entry, bool isTablet) {
    final tierStyle = DominoTierVisual.forLabel(entry.tier);

    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tierStyle.deep.withValues(alpha: 0.92),
            const Color(0xEE101820),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tierStyle.accent, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: tierStyle.accent.withValues(alpha: 0.24),
            blurRadius: tierStyle.glow,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 72 : 58,
            height: isTablet ? 72 : 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFD36B), width: 2),
            ),
            child: Center(
              child: Text(
                entry.rank > 0 ? '#${entry.rank}' : '--',
                style: TextStyle(
                  color: const Color(0xFF101820),
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSpanish ? 'Tu posicion' : 'Your position',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                    fontSize: isTablet ? 15 : 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 24 : 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTierBadge(entry.tier, compact: false),
                    Text(
                      '${entry.points} pts',
                      style: TextStyle(
                        color: const Color(0xFFFFD36B).withValues(alpha: 0.9),
                        fontWeight: FontWeight.w900,
                        fontSize: isTablet ? 14 : 12,
                      ),
                    ),
                    Text(
                      '${entry.mode} · ${entry.streak} ${_isSpanish ? 'ganadas seguidas' : 'win streak'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w800,
                        fontSize: isTablet ? 14 : 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: entry.rank > 0 ? () => _jumpToPlayer(entry.rank) : null,
            tooltip: _isSpanish ? 'Ver mi lugar' : 'Find me',
            icon: const Icon(Icons.my_location_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            onPressed: _showRankingHelp,
            tooltip: _isSpanish ? 'Reglas del ranking' : 'Ranking rules',
            icon: const Icon(Icons.question_mark_rounded),
          ),
        ],
      ),
    );
  }

  void _showRankingHelp() {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF101820),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: const Color(0xFFFFD36B).withValues(alpha: 0.48),
              ),
            ),
            title: Text(
              _isSpanish ? 'Reglas del ranking' : 'Ranking rules',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              _isSpanish
                  ? 'El ranking comienza desde cero el dia 1 de cada mes. Ganar suma puntos y perder resta puntos. Los tres primeros lugares quedan guardados en el historial de meses pasados. Las partidas contra CPU son practica y no deciden el ranking competitivo.'
                  : 'Ranking starts from zero on the first day of every month. Wins add points and losses subtract points. The top three remain saved in past-month history. CPU games are practice and do not decide competitive ranking.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_isSpanish ? 'Entendido' : 'Got it'),
              ),
            ],
          ),
    );
  }

  Widget _buildRankingRow(_RankingEntry entry, bool isCurrentPlayer) {
    final tierStyle = DominoTierVisual.forLabel(entry.tier);
    final isPremiumTier = tierStyle.level >= 4;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            (isCurrentPlayer ? const Color(0xFF1E88E5) : tierStyle.deep)
                .withValues(alpha: isCurrentPlayer ? 0.42 : 0.20),
            Colors.white.withValues(alpha: isPremiumTier ? 0.08 : 0.045),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isCurrentPlayer
                  ? const Color(0xFFFFD36B)
                  : tierStyle.accent.withValues(
                    alpha: isPremiumTier ? 0.70 : 0.32,
                  ),
          width: isCurrentPlayer || isPremiumTier ? 1.4 : 1,
        ),
        boxShadow: [
          if (isPremiumTier)
            BoxShadow(
              color: tierStyle.accent.withValues(alpha: 0.18),
              blurRadius: tierStyle.glow,
              spreadRadius: 0.5,
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tierStyle.accent.withValues(alpha: 0.74),
              ),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  color:
                      isCurrentPlayer
                          ? const Color(0xFFFFD36B)
                          : tierStyle.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
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
                  entry.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTierBadge(entry.tier, compact: true),
                    Text(
                      '${entry.wins}W ${entry.losses}L · ${entry.mode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.points}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                _isSpanish ? '${entry.streak} racha' : '${entry.streak} streak',
                style: TextStyle(
                  color: const Color(0xFFFFD36B).withValues(alpha: 0.86),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String tier, {required bool compact}) {
    final style = DominoTierVisual.forLabel(tier);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            style.accent.withValues(alpha: 0.88),
            style.deep.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: style.accent.withValues(
              alpha: style.level >= 4 ? 0.28 : 0.12,
            ),
            blurRadius: style.level >= 4 ? 12 : 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: Colors.white, size: compact ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            tier,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingEntry {
  const _RankingEntry({
    required this.rank,
    required this.code,
    required this.id,
    required this.points,
    required this.tier,
    required this.mode,
    required this.wins,
    required this.losses,
    required this.streak,
  });

  final int rank;
  final String code;
  final String id;
  final int points;
  final String tier;
  final String mode;
  final int wins;
  final int losses;
  final int streak;

  static Future<_RankingEntry> fromLocal(
    DominoPlayerProfile profile, {
    required int rank,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'kapi_player_points_${profile.code}';
    final points = prefs.getInt('${prefix}_total') ?? 0;
    final rounds = prefs.getInt('${prefix}_rounds') ?? 0;
    final wins = prefs.getInt('${prefix}_wins') ?? 0;
    final savedLosses = prefs.getInt('${prefix}_losses');
    final losses = savedLosses ?? (rounds > wins ? rounds - wins : 0);
    return _RankingEntry(
      rank: rank,
      code: profile.code,
      id: profile.publicId.toUpperCase(),
      points: points,
      tier: _tierForPoints(points),
      mode: 'Block',
      wins: wins,
      losses: losses,
      streak: prefs.getInt('${prefix}_streak') ?? 0,
    );
  }

  factory _RankingEntry.fromProfile(
    DominoPlayerProfile profile, {
    required int rank,
    String mode = 'Block',
  }) {
    return _RankingEntry(
      rank: rank,
      code: profile.code,
      id: profile.publicId.toUpperCase(),
      points: 0,
      tier: rank > 0 ? 'Iron' : 'Unranked',
      mode: mode,
      wins: 0,
      losses: 0,
      streak: 0,
    );
  }

  factory _RankingEntry.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final points = _intValue(data['totalPoints']);
    final wins = _intValue(data['roundsWon']);
    final rounds = _intValue(data['roundsPlayed']);
    final storedLosses = _intValue(data['roundsLost']);
    final losses =
        storedLosses == 0 && rounds > wins ? rounds - wins : storedLosses;
    final code = _stringValue(data['code'], doc.id).toUpperCase();
    return _RankingEntry(
      rank: 0,
      code: code,
      id: _stringValue(data['publicId'], code).toUpperCase(),
      points: points,
      tier: _tierForPoints(points),
      mode: _modeLabel(_stringValue(data['lastMode'], 'classic')),
      wins: wins,
      losses: losses,
      streak: _intValue(data['currentStreak']),
    );
  }

  _RankingEntry copyWith({int? rank}) {
    return _RankingEntry(
      rank: rank ?? this.rank,
      code: code,
      id: id,
      points: points,
      tier: tier,
      mode: mode,
      wins: wins,
      losses: losses,
      streak: streak,
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _stringValue(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static String _modeLabel(String value) {
    final clean = value.toLowerCase();
    if (clean.contains('all_fives') || clean.contains('all fives')) {
      return 'All Fives';
    }
    if (clean.contains('draw') || clean.contains('pool')) return 'Draw';
    if (clean.contains('teams') || clean.contains('2v2')) {
      return 'Teams 2 vs 2';
    }
    return 'Block';
  }

  static String _tierForPoints(int points) {
    if (points >= 900) return 'Platinum';
    if (points >= 500) return 'Gold';
    if (points >= 250) return 'Silver';
    if (points >= 100) return 'Bronze';
    return 'Iron';
  }
}

enum _RankingMode {
  block('Block'),
  teams('Teams 2 vs 2'),
  draw('Draw'),
  allFives('All Fives');

  const _RankingMode(this.label);

  final String label;
}
