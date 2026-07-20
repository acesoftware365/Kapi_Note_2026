import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/team_domino_chain_validator.dart';

/// A deterministic, opening-anchored domino path used by Teams 2 vs 2.
///
/// Both arms grow away from the opening tile in separate regions of the
/// table. The opening lane uses three tiles on each side of the opening tile,
/// so the first straight line contains seven tiles in total. A double may be a
/// fourth tile because doubles stay across the current line and never cause a
/// turn. After the first bend, a perpendicular run uses two tiles. The second
/// bend then returns toward the opening axis: the lower arm turns upward and
/// the upper arm turns downward. From there, each long lane continues toward
/// the table edge before another short connector turns it again.
class TeamBoardLayoutEngine {
  const TeamBoardLayoutEngine({
    this.longRunLength = 3,
    this.connectorRunLength = 2,
    this.edgeRunLength = 6,
  });

  final int longRunLength;
  final int connectorRunLength;
  final int edgeRunLength;

  List<TeamBoardPlacement> build({
    required List<TeamBoardTileSpec> board,
    required int openingIndex,
    required bool openingVertical,
    required bool startsHorizontally,
    Size tileSize = const Size(30, 54),
  }) {
    if (board.isEmpty) return const [];
    if (openingIndex < 0 || openingIndex >= board.length) {
      throw RangeError.index(openingIndex, board, 'openingIndex');
    }

    final placements = List<TeamBoardPlacement?>.filled(board.length, null);
    final positiveDirection =
        startsHorizontally ? TeamBoardDirection.right : TeamBoardDirection.up;
    placements[openingIndex] = TeamBoardPlacement(
      center: Offset.zero,
      vertical: openingVertical,
      // A vertical regular opening sends its logical right end upward and its
      // logical left end downward. Flip only its painted faces so both arms
      // visibly meet the matching pip. Doubles are symmetric and need no flip.
      flipped: openingVertical && !board[openingIndex].isDouble,
      direction: positiveDirection,
    );

    _layoutArm(
      board: board,
      placements: placements,
      openingIndex: openingIndex,
      side: TeamBoardSide.right,
      startsHorizontally: startsHorizontally,
      tileSize: tileSize,
    );
    _layoutArm(
      board: board,
      placements: placements,
      openingIndex: openingIndex,
      side: TeamBoardSide.left,
      startsHorizontally: startsHorizontally,
      tileSize: tileSize,
    );

    return [for (final placement in placements) placement!];
  }

  void _layoutArm({
    required List<TeamBoardTileSpec> board,
    required List<TeamBoardPlacement?> placements,
    required int openingIndex,
    required TeamBoardSide side,
    required bool startsHorizontally,
    required Size tileSize,
  }) {
    final indices =
        side == TeamBoardSide.right
            ? [
              for (var index = openingIndex + 1; index < board.length; index++)
                index,
            ]
            : [for (var index = openingIndex - 1; index >= 0; index--) index];
    if (indices.isEmpty) return;

    var direction = _initialDirection(side, startsHorizontally);
    var segmentCount = 0;
    var turnPending = false;
    var turnCount = 0;
    var previous = placements[openingIndex]!;

    for (final index in indices) {
      final tile = board[index];
      // A double is displayed across the current line. It can extend a run,
      // but it never causes the path itself to turn.
      if (turnPending && !tile.isDouble) {
        direction = _nextDirection(
          direction,
          side: side,
          startsHorizontally: startsHorizontally,
          turnCount: turnCount,
        );
        turnCount++;
        segmentCount = 0;
        turnPending = false;
      }

      final vertical = _isVertical(direction, tile.isDouble);
      final center = _nextCenter(
        previous: previous,
        direction: direction,
        vertical: vertical,
        tileSize: tileSize,
      );
      final placement = TeamBoardPlacement(
        center: center,
        vertical: vertical,
        flipped: _shouldFlip(side, direction),
        direction: direction,
      );
      placements[index] = placement;
      previous = placement;
      segmentCount++;
      if (segmentCount >= _segmentLimit(turnCount)) {
        turnPending = true;
      }
    }
  }

  TeamBoardDirection _initialDirection(
    TeamBoardSide side,
    bool startsHorizontally,
  ) {
    if (startsHorizontally) {
      return side == TeamBoardSide.right
          ? TeamBoardDirection.right
          : TeamBoardDirection.left;
    }
    // The positive end is shown upward for a vertical opening path. This
    // matches the requested opening after our team places a horizontal double.
    return side == TeamBoardSide.right
        ? TeamBoardDirection.up
        : TeamBoardDirection.down;
  }

  int _segmentLimit(int turnCount) {
    if (turnCount == 0) return longRunLength;
    if (turnCount.isOdd) return connectorRunLength;
    return edgeRunLength;
  }

  TeamBoardDirection _nextDirection(
    TeamBoardDirection direction, {
    required TeamBoardSide side,
    required bool startsHorizontally,
    required int turnCount,
  }) {
    if (startsHorizontally) {
      if (side == TeamBoardSide.right) {
        if (direction == TeamBoardDirection.right) {
          return TeamBoardDirection.up;
        }
        if (direction == TeamBoardDirection.left) {
          return TeamBoardDirection.up;
        }
        return turnCount % 4 == 1
            ? TeamBoardDirection.left
            : TeamBoardDirection.right;
      }
      if (direction == TeamBoardDirection.left) {
        return TeamBoardDirection.down;
      }
      if (direction == TeamBoardDirection.right) {
        return TeamBoardDirection.down;
      }
      return turnCount % 4 == 1
          ? TeamBoardDirection.right
          : TeamBoardDirection.left;
    }

    if (side == TeamBoardSide.right) {
      if (direction == TeamBoardDirection.up) {
        return TeamBoardDirection.left;
      }
      if (direction == TeamBoardDirection.down) {
        return TeamBoardDirection.left;
      }
      return turnCount % 4 == 1
          ? TeamBoardDirection.down
          : TeamBoardDirection.up;
    }
    if (direction == TeamBoardDirection.down) {
      return TeamBoardDirection.right;
    }
    if (direction == TeamBoardDirection.up) {
      return TeamBoardDirection.right;
    }
    return turnCount % 4 == 1 ? TeamBoardDirection.up : TeamBoardDirection.down;
  }

  bool _isVertical(TeamBoardDirection direction, bool isDouble) {
    final lineIsVertical =
        direction == TeamBoardDirection.up ||
        direction == TeamBoardDirection.down;
    return isDouble ? !lineIsVertical : lineIsVertical;
  }

  bool _shouldFlip(TeamBoardSide side, TeamBoardDirection direction) {
    if (side == TeamBoardSide.right) {
      return direction == TeamBoardDirection.left ||
          direction == TeamBoardDirection.up;
    }
    return direction == TeamBoardDirection.right ||
        direction == TeamBoardDirection.down;
  }

  Offset _nextCenter({
    required TeamBoardPlacement previous,
    required TeamBoardDirection direction,
    required bool vertical,
    required Size tileSize,
  }) {
    // Exact edge contact keeps neighboring tiles connected without letting a
    // corner intrude into a non-neighbor and create a false visual branch.
    const contactOverlap = 0.0;
    final previousRect = rectFor(previous, tileSize);
    final currentSize = drawSize(tileSize, vertical);
    return switch (direction) {
      TeamBoardDirection.right => Offset(
        previousRect.right + currentSize.width / 2 - contactOverlap,
        previous.direction == TeamBoardDirection.up
            ? previousRect.top + currentSize.height / 2
            : previous.direction == TeamBoardDirection.down
            ? previousRect.bottom - currentSize.height / 2
            : previous.center.dy,
      ),
      TeamBoardDirection.left => Offset(
        previousRect.left - currentSize.width / 2 + contactOverlap,
        previous.direction == TeamBoardDirection.up
            ? previousRect.top + currentSize.height / 2
            : previous.direction == TeamBoardDirection.down
            ? previousRect.bottom - currentSize.height / 2
            : previous.center.dy,
      ),
      TeamBoardDirection.down => Offset(
        previous.direction == TeamBoardDirection.right
            ? previousRect.right - currentSize.width / 2
            : previous.direction == TeamBoardDirection.left
            ? previousRect.left + currentSize.width / 2
            : previous.center.dx,
        previousRect.bottom + currentSize.height / 2 - contactOverlap,
      ),
      TeamBoardDirection.up => Offset(
        previous.direction == TeamBoardDirection.right
            ? previousRect.right - currentSize.width / 2
            : previous.direction == TeamBoardDirection.left
            ? previousRect.left + currentSize.width / 2
            : previous.center.dx,
        previousRect.top - currentSize.height / 2 + contactOverlap,
      ),
    };
  }

  static Size drawSize(Size tileSize, bool vertical) =>
      vertical ? tileSize : Size(tileSize.height, tileSize.width);

  static Rect rectFor(
    TeamBoardPlacement placement, [
    Size tileSize = const Size(30, 54),
  ]) {
    final size = drawSize(tileSize, placement.vertical);
    return Rect.fromCenter(
      center: placement.center,
      width: size.width,
      height: size.height,
    );
  }

  static Rect boundsFor(
    List<TeamBoardPlacement> placements, [
    Size tileSize = const Size(30, 54),
  ]) {
    var bounds = Rect.zero;
    for (final placement in placements) {
      final rect = rectFor(placement, tileSize);
      bounds = bounds == Rect.zero ? rect : bounds.expandToInclude(rect);
    }
    return bounds.inflate(8);
  }

  static bool adjacentTilesTouch(
    TeamBoardPlacement first,
    TeamBoardPlacement second, [
    Size tileSize = const Size(30, 54),
  ]) {
    final a = rectFor(first, tileSize);
    final b = rectFor(second, tileSize);
    const tolerance = 1.35;
    bool near(double x, double y) => (x - y).abs() <= tolerance;
    final horizontalContact =
        (near(a.right, b.left) || near(a.left, b.right)) &&
        max(a.top, b.top) < min(a.bottom, b.bottom);
    final verticalContact =
        (near(a.bottom, b.top) || near(a.top, b.bottom)) &&
        max(a.left, b.left) < min(a.right, b.right);
    final smallOverlap = a.intersect(b);
    return horizontalContact ||
        verticalContact ||
        (!smallOverlap.isEmpty &&
            smallOverlap.width <= 1.35 &&
            smallOverlap.height > 1) ||
        (!smallOverlap.isEmpty &&
            smallOverlap.height <= 1.35 &&
            smallOverlap.width > 1);
  }

  /// Confirms that the logical chain and its painted orientation agree.
  /// This is intentionally release-safe and is called before the board is
  /// rendered, so a bad visual connection can never be shown to the player.
  static bool validateVisualConnections({
    required List<TeamBoardTileSpec> board,
    required List<TeamBoardPlacement> placements,
    required int openingIndex,
  }) {
    if (board.isEmpty ||
        board.length != placements.length ||
        openingIndex < 0 ||
        openingIndex >= board.length) {
      return false;
    }
    if (board.any((tile) => tile.left == null || tile.right == null)) {
      return false;
    }
    final values = <TeamDominoEnds>[
      for (final tile in board) (left: tile.left!, right: tile.right!),
    ];
    if (!TeamDominoChainValidator.isValidChain(values)) return false;

    int displayedLeft(int index) =>
        placements[index].flipped ? values[index].right : values[index].left;
    int displayedRight(int index) =>
        placements[index].flipped ? values[index].left : values[index].right;

    for (var index = openingIndex + 1; index < board.length; index++) {
      final innerValue = switch (placements[index].direction) {
        TeamBoardDirection.right ||
        TeamBoardDirection.down => displayedLeft(index),
        TeamBoardDirection.left ||
        TeamBoardDirection.up => displayedRight(index),
      };
      if (innerValue != values[index].left) return false;
    }
    for (var index = openingIndex - 1; index >= 0; index--) {
      final innerValue = switch (placements[index].direction) {
        TeamBoardDirection.right ||
        TeamBoardDirection.down => displayedLeft(index),
        TeamBoardDirection.left ||
        TeamBoardDirection.up => displayedRight(index),
      };
      if (innerValue != values[index].right) return false;
    }

    int openingFaceToward(TeamBoardDirection direction) {
      final placement = placements[openingIndex];
      if (placement.vertical) {
        return switch (direction) {
          TeamBoardDirection.up => displayedLeft(openingIndex),
          TeamBoardDirection.down => displayedRight(openingIndex),
          // A vertical tile only grows sideways when it is a symmetric double.
          TeamBoardDirection.left ||
          TeamBoardDirection.right => displayedLeft(openingIndex),
        };
      }
      return switch (direction) {
        TeamBoardDirection.left => displayedLeft(openingIndex),
        TeamBoardDirection.right => displayedRight(openingIndex),
        // A horizontal tile only grows vertically when it is a symmetric double.
        TeamBoardDirection.up ||
        TeamBoardDirection.down => displayedLeft(openingIndex),
      };
    }

    if (openingIndex + 1 < board.length &&
        openingFaceToward(placements[openingIndex + 1].direction) !=
            values[openingIndex].right) {
      return false;
    }
    if (openingIndex > 0 &&
        openingFaceToward(placements[openingIndex - 1].direction) !=
            values[openingIndex].left) {
      return false;
    }
    return true;
  }

  /// Verifies thousands of possible partial/final boards, including opening
  /// positions near either end and every opening orientation.
  static bool debugStressTest({int iterations = 4000}) {
    const engine = TeamBoardLayoutEngine();
    final random = Random(7322026);
    for (var run = 0; run < iterations; run++) {
      final count = 1 + random.nextInt(28);
      final doubleSlots = <int>{};
      final desiredDoubles = random.nextInt(min(7, count) + 1);
      while (doubleSlots.length < desiredDoubles) {
        doubleSlots.add(random.nextInt(count));
      }
      final board = [
        for (var index = 0; index < count; index++)
          TeamBoardTileSpec(isDouble: doubleSlots.contains(index)),
      ];
      final openingIndex = random.nextInt(count);
      for (final startsHorizontally in const [true, false]) {
        for (final openingVertical in const [true, false]) {
          final placements = engine.build(
            board: board,
            openingIndex: openingIndex,
            openingVertical: openingVertical,
            startsHorizontally: startsHorizontally,
          );
          if (placements.length != count ||
              !debugValidatePlacements(placements)) {
            debugPrint(
              'Teams layout failed: run=$run count=$count opening=$openingIndex '
              'horizontal=$startsHorizontally openingVertical=$openingVertical '
              'doubles=$doubleSlots',
            );
            return false;
          }
        }
      }
    }
    return true;
  }

  static bool debugValidatePlacements(
    List<TeamBoardPlacement> placements, [
    Size tileSize = const Size(30, 54),
  ]) {
    for (var index = 1; index < placements.length; index++) {
      if (!adjacentTilesTouch(
        placements[index - 1],
        placements[index],
        tileSize,
      )) {
        debugPrint('Teams layout disconnected at $index.');
        return false;
      }
    }
    for (var a = 0; a < placements.length; a++) {
      for (var b = a + 2; b < placements.length; b++) {
        final first = rectFor(placements[a], tileSize);
        final second = rectFor(placements[b], tileSize);
        final intersection = first.intersect(second);
        if ((!intersection.isEmpty &&
                intersection.width > 1.35 &&
                intersection.height > 1.35) ||
            adjacentTilesTouch(placements[a], placements[b], tileSize)) {
          debugPrint(
            'Teams layout false contact: $a/$b first=$first second=$second '
            'intersection=$intersection',
          );
          return false;
        }
      }
    }
    return true;
  }
}

class TeamBoardTileSpec {
  const TeamBoardTileSpec({required this.isDouble, this.left, this.right})
    : assert(
        (left == null) == (right == null),
        'Both pip values must be provided together.',
      );

  final bool isDouble;
  final int? left;
  final int? right;
}

class TeamBoardPlacement {
  const TeamBoardPlacement({
    required this.center,
    required this.vertical,
    required this.flipped,
    required this.direction,
  });

  final Offset center;
  final bool vertical;
  final bool flipped;
  final TeamBoardDirection direction;
}

enum TeamBoardSide { left, right }

enum TeamBoardDirection { right, down, left, up }
