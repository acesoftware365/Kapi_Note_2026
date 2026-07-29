import 'package:dominoes_note2025/screens/domino_teams/team_game_validator.dart';
import 'package:dominoes_note2025/screens/domino_teams/team_scoring_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Teams 2 vs 2 rules and special bonuses remain valid', () {
    expect(TeamGameValidator.debugValidateRules(), isTrue);
  });

  test('one thousand complete CPU matches keep every rule and tile valid', () {
    expect(TeamGameValidator.debugSimulateMatches(), isTrue);
  });

  test('round pass awards ten only after the same player plays again', () {
    expect(
      TeamScoringRules.roundPassBonusForPlay(
        consecutivePasses: 3,
        lastPlayerToPlay: 0,
        playerPlaying: 0,
      ),
      10,
    );
    expect(
      TeamScoringRules.roundPassBonusForPlay(
        consecutivePasses: 3,
        lastPlayerToPlay: 0,
        playerPlaying: 1,
      ),
      0,
    );
  });

  test('a blocked hand never awards round-pass points', () {
    expect(
      TeamScoringRules.roundPassBonusForPlay(
        consecutivePasses: 4,
        lastPlayerToPlay: 0,
        playerPlaying: 0,
      ),
      0,
    );
  });

  test('partner round pass credits the shared team score', () {
    final scores = <int>[7, 4];
    final bonus = TeamScoringRules.awardRoundPassBonusForPlay(
      teamScores: scores,
      consecutivePasses: 3,
      lastPlayerToPlay: 2,
      playerPlaying: 2,
    );

    expect(bonus, 10);
    expect(scores, <int>[17, 4]);
  });

  test('rival partner round pass credits only the rival team', () {
    final scores = <int>[7, 4];
    final bonus = TeamScoringRules.awardRoundPassBonusForPlay(
      teamScores: scores,
      consecutivePasses: 3,
      lastPlayerToPlay: 3,
      playerPlaying: 3,
    );

    expect(bonus, 10);
    expect(scores, <int>[7, 14]);
  });

  test('blocker competes only with the player immediately after them', () {
    final winner = TeamScoringRules.blockedWinnerPlayer(
      blockingPlayer: 0,
      handPips: const <int>[7, 26, 11, 0],
    );

    // MP blocks with 7 and must beat CPU R with 26. CPU L's 0 is irrelevant.
    expect(winner, 0);
  });

  test('next player wins the block only when they have fewer pips', () {
    expect(
      TeamScoringRules.blockedWinnerPlayer(
        blockingPlayer: 0,
        handPips: const <int>[17, 6, 0, 1],
      ),
      1,
    );
  });

  test('the same blocked-hand rule works when the partner blocks', () {
    expect(
      TeamScoringRules.blockedWinnerPlayer(
        blockingPlayer: 2,
        handPips: const <int>[0, 1, 8, 14],
      ),
      2,
    );
  });
}
