/// Shared scoring rules for the Teams 2 vs 2 game.
///
/// A round-pass bonus is earned only when the player who last placed a tile
/// receives the turn back after the other three players pass *and then places
/// another tile*. Merely receiving the turn is not enough because the fourth
/// pass may still close a blocked hand.
class TeamScoringRules {
  const TeamScoringRules._();

  static const int roundPassPoints = 10;

  /// Seats 0 and 2 are partners; seats 1 and 3 are the rival team.
  static int teamIndexForPlayer(int player) => player.isEven ? 0 : 1;

  /// Resolves a blocked hand using the Kapi Teams 2 vs 2 rule.
  ///
  /// The player who placed the tile that caused the block competes only with
  /// the player whose turn comes immediately after theirs. The other two
  /// players never participate in deciding the blocked-hand winner.
  static int blockedWinnerPlayer({
    required int blockingPlayer,
    required List<int> handPips,
  }) {
    if (blockingPlayer < 0 || blockingPlayer >= 4) {
      throw ArgumentError.value(
        blockingPlayer,
        'blockingPlayer',
        'Teams 2 vs 2 seats must be between 0 and 3.',
      );
    }
    if (handPips.length != 4) {
      throw ArgumentError.value(
        handPips,
        'handPips',
        'Teams 2 vs 2 requires the pip total for all four players.',
      );
    }
    final nextPlayer = (blockingPlayer + 1) % 4;
    return handPips[blockingPlayer] <= handPips[nextPlayer]
        ? blockingPlayer
        : nextPlayer;
  }

  static int roundPassBonusForPlay({
    required int consecutivePasses,
    required int? lastPlayerToPlay,
    required int playerPlaying,
  }) {
    return consecutivePasses == 3 && lastPlayerToPlay == playerPlaying
        ? roundPassPoints
        : 0;
  }

  /// Applies the bonus to the player's shared team and returns the amount.
  ///
  /// Keeping the calculation and the team credit together prevents a partner
  /// (seat 2 or 3) from completing a round pass without the team score being
  /// updated in CPU or online games.
  static int awardRoundPassBonusForPlay({
    required List<int> teamScores,
    required int consecutivePasses,
    required int? lastPlayerToPlay,
    required int playerPlaying,
  }) {
    if (teamScores.length < 2) {
      throw ArgumentError.value(
        teamScores,
        'teamScores',
        'Teams 2 vs 2 requires two team scores.',
      );
    }
    final bonus = roundPassBonusForPlay(
      consecutivePasses: consecutivePasses,
      lastPlayerToPlay: lastPlayerToPlay,
      playerPlaying: playerPlaying,
    );
    if (bonus > 0) {
      teamScores[teamIndexForPlayer(playerPlaying)] += bonus;
    }
    return bonus;
  }
}
