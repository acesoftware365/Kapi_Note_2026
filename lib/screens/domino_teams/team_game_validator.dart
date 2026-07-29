import 'dart:math';

import 'team_board_layout.dart';
import 'team_scoring_rules.dart';

/// Release guard for the Teams 2 vs 2 CPU rules.
///
/// This runs complete four-player matches without animation delays and checks
/// the deck, turn order, scoring, logical links, and the exact visual layout
/// after every play.
class TeamGameValidator {
  const TeamGameValidator._();

  static const targetScore = 100;

  static bool debugValidateRules() {
    final deck = _deck();
    if (deck.length != 28 || deck.map((tile) => tile.id).toSet().length != 28) {
      return false;
    }
    final doubleSix = deck.singleWhere(
      (tile) => tile.left == 6 && tile.right == 6,
    );
    if (!doubleSix.isDouble || doubleSix.points != 12) return false;

    final openBoard = [
      const _ValidationTile(0, 2, 1),
      const _ValidationTile(1, 1, 6),
    ];
    final capicua = const _ValidationTile(2, 2, 6);
    if (_validSides(openBoard, capicua).length != 2 || capicua.isDouble) {
      return false;
    }
    const remainingPips = 19;
    if (_winningPoints(remainingPips, capicua: true) != 44 ||
        _winningPoints(remainingPips, chuchazo: true) != 44 ||
        _winningPoints(remainingPips) != 19) {
      return false;
    }
    if (TeamScoringRules.teamIndexForPlayer(0) != 0 ||
        TeamScoringRules.teamIndexForPlayer(2) != 0 ||
        TeamScoringRules.teamIndexForPlayer(1) != 1 ||
        TeamScoringRules.teamIndexForPlayer(3) != 1) {
      return false;
    }
    if (TeamScoringRules.roundPassBonusForPlay(
          consecutivePasses: 3,
          lastPlayerToPlay: 2,
          playerPlaying: 2,
        ) !=
        10) {
      return false;
    }
    if (TeamScoringRules.roundPassBonusForPlay(
              consecutivePasses: 4,
              lastPlayerToPlay: 2,
              playerPlaying: 2,
            ) !=
            0 ||
        TeamScoringRules.roundPassBonusForPlay(
              consecutivePasses: 3,
              lastPlayerToPlay: 2,
              playerPlaying: 1,
            ) !=
            0) {
      return false;
    }
    if (TeamScoringRules.blockedWinnerPlayer(
              blockingPlayer: 0,
              handPips: const [7, 26, 11, 0],
            ) !=
            0 ||
        TeamScoringRules.blockedWinnerPlayer(
              blockingPlayer: 0,
              handPips: const [17, 6, 0, 1],
            ) !=
            1) {
      return false;
    }
    return true;
  }

  static bool debugSimulateMatches({int matchCount = 1000}) {
    const layoutEngine = TeamBoardLayoutEngine();
    for (var match = 0; match < matchCount; match++) {
      final random = Random(9142026 + match);
      final scores = [0, 0];
      int? previousDominator;
      var round = 1;
      var roundGuard = 0;

      while (scores[0] < targetScore && scores[1] < targetScore) {
        if (++roundGuard > 80) return false;
        final deck = _deck()..shuffle(random);
        final hands = [
          for (var player = 0; player < 4; player++)
            deck.skip(player * 7).take(7).toList(),
        ];
        final board = <_ValidationTile>[];
        _ValidationTile? opening;
        var openingPlayer = 0;
        var turn = 0;
        var consecutivePasses = 0;
        int? lastPlayerToPlay;

        if (round == 1) {
          opening = deck.singleWhere(
            (tile) => tile.left == 6 && tile.right == 6,
          );
          openingPlayer = hands.indexWhere(
            (hand) => hand.any((tile) => tile.id == opening!.id),
          );
          if (openingPlayer < 0) return false;
          hands[openingPlayer].removeWhere((tile) => tile.id == opening!.id);
          board.add(opening);
          lastPlayerToPlay = openingPlayer;
          turn = (openingPlayer + 1) % 4;
        } else {
          turn = previousDominator ?? 0;
        }

        var handOver = false;
        var stepGuard = 0;
        while (!handOver) {
          if (++stepGuard > 160) return false;
          final hand = hands[turn];
          _ValidationTile? choice;
          List<_ValidationSide> valid = const [];
          for (final tile in hand) {
            final candidate = _validSides(board, tile);
            if (candidate.isNotEmpty &&
                (choice == null || tile.points > choice.points)) {
              choice = tile;
              valid = candidate;
            }
          }

          if (choice == null) {
            consecutivePasses++;
            turn = (turn + 1) % 4;
            final returnedToBlocker =
                consecutivePasses >= 3 && turn == lastPlayerToPlay;
            final blockerCannotPlay =
                returnedToBlocker &&
                !hands[turn].any((tile) => _validSides(board, tile).isNotEmpty);
            if (blockerCannotPlay || consecutivePasses >= 4) {
              final handPips = <int>[
                for (var player = 0; player < 4; player++)
                  hands[player].fold<int>(0, (sum, tile) => sum + tile.points),
              ];
              final blockingPlayer = lastPlayerToPlay;
              if (blockingPlayer == null) return false;
              final winner = TeamScoringRules.blockedWinnerPlayer(
                blockingPlayer: blockingPlayer,
                handPips: handPips,
              );
              final gained = handPips.fold<int>(
                0,
                (sum, points) => sum + points,
              );
              scores[_teamFor(winner)] += gained;
              handOver = true;
            }
            continue;
          }

          TeamScoringRules.awardRoundPassBonusForPlay(
            teamScores: scores,
            consecutivePasses: consecutivePasses,
            lastPlayerToPlay: lastPlayerToPlay,
            playerPlaying: turn,
          );

          final capicua =
              hand.length == 1 &&
              !choice.isDouble &&
              board.isNotEmpty &&
              board.first.left != board.last.right &&
              valid.length == 2;
          final chuchazo =
              hand.length == 1 && choice.left == 0 && choice.right == 0;
          final side =
              capicua || valid.contains(_ValidationSide.right)
                  ? _ValidationSide.right
                  : valid.first;
          final wasEmpty = board.isEmpty;
          final placed =
              wasEmpty
                  ? choice
                  : side == _ValidationSide.right
                  ? (choice.left == board.last.right ? choice : choice.flipped)
                  : (choice.right == board.first.left
                      ? choice
                      : choice.flipped);
          hand.removeWhere((tile) => tile.id == choice!.id);
          if (side == _ValidationSide.right) {
            board.add(placed);
          } else {
            board.insert(0, placed);
          }
          if (wasEmpty) {
            opening = placed;
            openingPlayer = turn;
          }
          lastPlayerToPlay = turn;
          consecutivePasses = 0;

          if (!_validatePhysicalState(deck, hands, board)) return false;
          final openingTile = opening;
          if (openingTile == null) return false;
          final openingIndex = board.indexWhere(
            (tile) => tile.id == openingTile.id,
          );
          if (openingIndex < 0) return false;
          final rivalsOpened = openingPlayer.isOdd;
          final openingVertical =
              openingTile.isDouble ? rivalsOpened : !rivalsOpened;
          final startsHorizontally =
              openingTile.isDouble ? openingVertical : !openingVertical;
          final visualBoard = [
            for (final tile in board)
              TeamBoardTileSpec(
                isDouble: tile.isDouble,
                left: tile.left,
                right: tile.right,
              ),
          ];
          final placements = layoutEngine.build(
            board: visualBoard,
            openingIndex: openingIndex,
            openingVertical: openingVertical,
            startsHorizontally: startsHorizontally,
          );
          if (!TeamBoardLayoutEngine.debugValidatePlacements(placements) ||
              !TeamBoardLayoutEngine.validateVisualConnections(
                board: visualBoard,
                placements: placements,
                openingIndex: openingIndex,
              )) {
            return false;
          }

          if (hand.isEmpty) {
            final remaining = hands
                .expand((tiles) => tiles)
                .fold<int>(0, (sum, tile) => sum + tile.points);
            scores[_teamFor(turn)] += _winningPoints(
              remaining,
              capicua: capicua,
              chuchazo: chuchazo,
            );
            previousDominator = turn;
            handOver = true;
          } else {
            turn = (turn + 1) % 4;
          }
        }

        if (scores.any((score) => score < 0)) return false;
        round++;
      }
      if (scores[0] < targetScore && scores[1] < targetScore) return false;
    }
    return true;
  }

  static int _winningPoints(
    int remainingPips, {
    bool capicua = false,
    bool chuchazo = false,
  }) => remainingPips + (capicua || chuchazo ? 25 : 0);

  static int _teamFor(int player) => player.isEven ? 0 : 1;

  static List<_ValidationSide> _validSides(
    List<_ValidationTile> board,
    _ValidationTile tile,
  ) {
    if (board.isEmpty) return const [_ValidationSide.right];
    final sides = <_ValidationSide>[];
    if (tile.left == board.first.left || tile.right == board.first.left) {
      sides.add(_ValidationSide.left);
    }
    if (tile.left == board.last.right || tile.right == board.last.right) {
      sides.add(_ValidationSide.right);
    }
    return sides;
  }

  static bool _validatePhysicalState(
    List<_ValidationTile> deck,
    List<List<_ValidationTile>> hands,
    List<_ValidationTile> board,
  ) {
    for (var index = 1; index < board.length; index++) {
      if (board[index - 1].right != board[index].left) return false;
    }
    final allIds = <int>[
      ...board.map((tile) => tile.id),
      ...hands.expand((hand) => hand).map((tile) => tile.id),
    ];
    return allIds.length == deck.length &&
        allIds.toSet().length == deck.length &&
        allIds.every((id) => id >= 0 && id < 28);
  }

  static List<_ValidationTile> _deck() {
    var id = 0;
    return [
      for (var left = 0; left <= 6; left++)
        for (var right = left; right <= 6; right++)
          _ValidationTile(id++, left, right),
    ];
  }
}

enum _ValidationSide { left, right }

class _ValidationTile {
  const _ValidationTile(this.id, this.left, this.right);

  final int id;
  final int left;
  final int right;

  bool get isDouble => left == right;
  int get points => left + right;
  _ValidationTile get flipped => _ValidationTile(id, right, left);
}
