import 'package:flutter/material.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const String _currentPlayerId = 'JP-HGI386';
  static const int _currentRank = 37;
  final ScrollController _scrollController = ScrollController();

  late final List<_RankingEntry> _entries = List<_RankingEntry>.generate(60, (
    index,
  ) {
    final rank = index + 1;
    if (rank == _currentRank) {
      return const _RankingEntry(
        rank: _currentRank,
        id: _currentPlayerId,
        points: 128,
        tier: 'Silver',
        difficulty: 'Medium',
        mode: 'Draw',
        streak: 4,
      );
    }

    final initials =
        ['MR', 'KA', 'LG', 'AN', 'CP', 'DR', 'JM', 'RL', 'TA', 'YS'][index %
            10];
    final tier =
        ['Diamond', 'Platinum', 'Gold', 'Silver', 'Bronze'][(rank ~/ 8).clamp(
          0,
          4,
        )];
    final difficulty = ['Hard', 'Medium', 'Easy'][index % 3];
    final mode = index.isEven ? 'Draw' : 'Classic';

    return _RankingEntry(
      rank: rank,
      id: '$initials-${String.fromCharCode(65 + index % 26)}K${100 + index}',
      points: (520 - (rank * 7)).clamp(18, 520),
      tier: tier,
      difficulty: difficulty,
      mode: mode,
      streak: (12 - index % 9).clamp(1, 12),
    );
  });

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToPlayer() {
    const rowExtent = 78.0;
    final target = ((_currentRank - 2) * rowExtent).clamp(
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
    final currentEntry = _entries.firstWhere(
      (entry) => entry.rank == _currentRank,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: _isSpanish ? 'Volver' : 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSpanish ? 'Ranking de jugadores' : 'Player Ranking',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 28 : 16,
                12,
                isTablet ? 28 : 16,
                16,
              ),
              child: Column(
                children: [
                  Text(
                    _isSpanish ? 'Basado en puntos' : 'Based on points',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: isTablet ? 16 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCurrentPlayerCard(currentEntry, isTablet),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: _entries.length,
                          separatorBuilder:
                              (_, __) => Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return _buildRankingRow(
                              entry,
                              entry.id == _currentPlayerId,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlayerCard(_RankingEntry entry, bool isTablet) {
    final tierStyle = _TierStyle.forTier(entry.tier);

    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tierStyle.deepColor.withValues(alpha: 0.92),
            const Color(0xEE101820),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tierStyle.accentColor, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: tierStyle.accentColor.withValues(alpha: 0.24),
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
                '#${entry.rank}',
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
                  '${entry.id} · ${entry.points} pts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 24 : 18,
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
                      '${entry.difficulty} · ${entry.mode} · ${entry.streak} ${_isSpanish ? 'manos' : 'wins'}',
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
            onPressed: _jumpToPlayer,
            tooltip: _isSpanish ? 'Ver mi lugar' : 'Find me',
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingRow(_RankingEntry entry, bool isCurrentPlayer) {
    final tierStyle = _TierStyle.forTier(entry.tier);
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
            (isCurrentPlayer ? const Color(0xFF1E88E5) : tierStyle.deepColor)
                .withValues(alpha: isCurrentPlayer ? 0.42 : 0.20),
            Colors.white.withValues(alpha: isPremiumTier ? 0.08 : 0.045),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isCurrentPlayer
                  ? const Color(0xFFFFD36B)
                  : tierStyle.accentColor.withValues(
                    alpha: isPremiumTier ? 0.70 : 0.32,
                  ),
          width: isCurrentPlayer || isPremiumTier ? 1.4 : 1,
        ),
        boxShadow: [
          if (isPremiumTier)
            BoxShadow(
              color: tierStyle.accentColor.withValues(alpha: 0.18),
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
                color: tierStyle.accentColor.withValues(alpha: 0.74),
              ),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  color:
                      isCurrentPlayer
                          ? const Color(0xFFFFD36B)
                          : tierStyle.accentColor,
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
                      '${entry.difficulty} · ${entry.mode}',
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
                _isSpanish ? '${entry.streak} manos' : '${entry.streak} wins',
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
    final style = _TierStyle.forTier(tier);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            style.accentColor.withValues(alpha: 0.88),
            style.deepColor.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: style.accentColor.withValues(
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
    required this.id,
    required this.points,
    required this.tier,
    required this.difficulty,
    required this.mode,
    required this.streak,
  });

  final int rank;
  final String id;
  final int points;
  final String tier;
  final String difficulty;
  final String mode;
  final int streak;
}

class _TierStyle {
  const _TierStyle({
    required this.accentColor,
    required this.deepColor,
    required this.icon,
    required this.level,
    required this.glow,
  });

  final Color accentColor;
  final Color deepColor;
  final IconData icon;
  final int level;
  final double glow;

  static _TierStyle forTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return const _TierStyle(
          accentColor: Color(0xFF7DE7FF),
          deepColor: Color(0xFF143E69),
          icon: Icons.diamond_rounded,
          level: 5,
          glow: 20,
        );
      case 'platinum':
        return const _TierStyle(
          accentColor: Color(0xFFBFE8FF),
          deepColor: Color(0xFF2D4154),
          icon: Icons.auto_awesome_rounded,
          level: 4,
          glow: 16,
        );
      case 'gold':
        return const _TierStyle(
          accentColor: Color(0xFFFFD36B),
          deepColor: Color(0xFF6B4A13),
          icon: Icons.workspace_premium_rounded,
          level: 3,
          glow: 12,
        );
      case 'silver':
        return const _TierStyle(
          accentColor: Color(0xFFC9D4E5),
          deepColor: Color(0xFF3D4756),
          icon: Icons.shield_rounded,
          level: 2,
          glow: 8,
        );
      default:
        return const _TierStyle(
          accentColor: Color(0xFFC28B62),
          deepColor: Color(0xFF5B3828),
          icon: Icons.military_tech_rounded,
          level: 1,
          glow: 6,
        );
    }
  }
}
