/// Release-safe validation for a Teams 2 vs 2 domino chain.
///
/// Unlike an `assert`, these checks run in debug and production builds. The
/// game and the online transaction service both use this class before a tile
/// is committed to the table.
typedef TeamDominoEnds = ({int left, int right});

enum TeamDominoChainSide { left, right }

class TeamDominoChainValidator {
  const TeamDominoChainValidator._();

  static bool isValidChain(Iterable<TeamDominoEnds> board) {
    final tiles = board.toList(growable: false);
    for (final tile in tiles) {
      if (!_isValidPip(tile.left) || !_isValidPip(tile.right)) return false;
    }
    for (var index = 1; index < tiles.length; index++) {
      if (tiles[index - 1].right != tiles[index].left) return false;
    }
    return true;
  }

  /// Returns the tile oriented for [side], or `null` if it cannot legally
  /// connect. The current board must already be valid.
  static TeamDominoEnds? orientForPlacement({
    required Iterable<TeamDominoEnds> board,
    required TeamDominoEnds tile,
    required TeamDominoChainSide side,
  }) {
    final current = board.toList(growable: false);
    if (!isValidChain(current) ||
        !_isValidPip(tile.left) ||
        !_isValidPip(tile.right)) {
      return null;
    }
    if (current.isEmpty) return tile;

    if (side == TeamDominoChainSide.right) {
      final open = current.last.right;
      if (tile.left == open) return tile;
      if (tile.right == open) return (left: tile.right, right: tile.left);
      return null;
    }

    final open = current.first.left;
    if (tile.right == open) return tile;
    if (tile.left == open) return (left: tile.right, right: tile.left);
    return null;
  }

  /// Builds and validates the complete result without mutating the live board.
  static List<TeamDominoEnds>? tryPlace({
    required Iterable<TeamDominoEnds> board,
    required TeamDominoEnds tile,
    required TeamDominoChainSide side,
  }) {
    final current = board.toList(growable: false);
    final oriented = orientForPlacement(board: current, tile: tile, side: side);
    if (oriented == null) return null;
    final proposed = <TeamDominoEnds>[
      if (side == TeamDominoChainSide.left && current.isNotEmpty) oriented,
      ...current,
      if (side == TeamDominoChainSide.right || current.isEmpty) oriented,
    ];
    return isValidChain(proposed) ? proposed : null;
  }

  static bool _isValidPip(int value) => value >= 0 && value <= 6;
}
