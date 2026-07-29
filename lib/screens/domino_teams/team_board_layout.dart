import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/team_domino_chain_validator.dart';

/// A deterministic domino path used by Teams 2 vs 2.
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
    this.leftLongRunLength,
    this.rightLongRunLength,
    this.leftConnectorRunLength,
    this.rightConnectorRunLength,
  });

  final int longRunLength;
  final int connectorRunLength;
  final int edgeRunLength;
  final int? leftLongRunLength;
  final int? rightLongRunLength;
  final int? leftConnectorRunLength;
  final int? rightConnectorRunLength;

  /// Keeps portrait-phone chains from becoming one long line before they use
  /// the free space above and below the opening tile.
  static int responsiveLongRunLengthForWidth(
    double viewportWidth, {
    bool startsHorizontally = false,
  }) {
    if (viewportWidth < 600 && startsHorizontally) return 1;
    if (viewportWidth < 600) return 2;
    return 3;
  }

  /// Uses the taller phone table before consuming its limited center width.
  ///
  /// A horizontal opening otherwise reaches a six-tile cross-table lane very
  /// early and forces every domino to shrink while large areas above and below
  /// the chain are still empty.
  static int responsiveEdgeRunLengthForWidth(
    double viewportWidth, {
    bool startsHorizontally = false,
  }) {
    if (viewportWidth < 600 && startsHorizontally) return 4;
    if (viewportWidth < 600) return 7;
    return 6;
  }

  /// Returns the largest uniform scale that fits [bounds] in [availableSize].
  ///
  /// [visualMargin] is measured after scaling, so a large domino does not
  /// accidentally multiply the intended screen-edge padding.
  static double fitScale({
    required Rect bounds,
    required Size availableSize,
    required double preferredScale,
    double visualMargin = 6,
  }) {
    if (bounds.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
      return preferredScale;
    }
    final safeWidth = max(1.0, availableSize.width - visualMargin * 2);
    final safeHeight = max(1.0, availableSize.height - visualMargin * 2);
    return min(
      preferredScale,
      min(safeWidth / bounds.width, safeHeight / bounds.height),
    );
  }

  /// Fits and centers the complete visible chain in the available area.
  ///
  /// The opening tile starts centered when it is alone. As either arm grows,
  /// the complete composition can move so the dominoes use all free space
  /// before their size is reduced.
  static ({double scale, Offset translation}) centeredFit({
    required Rect bounds,
    required Size availableSize,
    required double preferredScale,
    double visualMargin = 6,
  }) {
    final scale = fitScale(
      bounds: bounds,
      availableSize: availableSize,
      preferredScale: preferredScale,
      visualMargin: visualMargin,
    );
    final translation =
        availableSize.center(Offset.zero) - bounds.center * scale;
    return (scale: scale, translation: translation);
  }

  /// Chooses independent runs for both arms so the chain uses the available
  /// table before its dominoes are reduced. This is recalculated after every
  /// play, allowing a short arm to keep travelling straight while the longer
  /// arm folds earlier.
  static ({TeamBoardLayoutEngine engine, List<TeamBoardPlacement> placements})
  bestFit({
    required List<TeamBoardTileSpec> board,
    required int openingIndex,
    required bool openingVertical,
    required bool startsHorizontally,
    required Size availableSize,
    required double preferredScale,
    required int baseLongRunLength,
    int connectorRunLength = 2,
    int edgeRunLength = 6,
    int maxLongRunLength = 5,
    double visualMargin = 6,
  }) {
    final leftTileCount = openingIndex;
    final rightTileCount = board.length - openingIndex - 1;
    final leftMaximum = max(
      baseLongRunLength,
      min(maxLongRunLength, max(1, leftTileCount)),
    );
    final rightMaximum = max(
      baseLongRunLength,
      min(maxLongRunLength, max(1, rightTileCount)),
    );
    final connectorMinimum = startsHorizontally ? 1 : connectorRunLength;
    const comparisonTolerance = 0.000001;

    bool validPlacements(List<TeamBoardPlacement> placements) {
      if (!debugValidatePlacements(placements, const Size(30, 54), false)) {
        return false;
      }
      return !board.every((tile) => tile.left != null && tile.right != null) ||
          validateVisualConnections(
            board: board,
            placements: placements,
            openingIndex: openingIndex,
          );
    }

    // On a mature horizontal chain, balance the two arms before exploring
    // generic candidates. The shorter arm can use four open positions while
    // the longer arm folds after two; a one-tile connector then sends the
    // chain back across the table. Keep this route only when it is at least as
    // large as the previous symmetric 3/3 layout.
    if (startsHorizontally &&
        board.length >= 12 &&
        leftTileCount >= 4 &&
        rightTileCount >= 4 &&
        leftTileCount != rightTileCount) {
      final rightIsShorter = rightTileCount < leftTileCount;
      final balancedEngine = TeamBoardLayoutEngine(
        longRunLength: baseLongRunLength,
        connectorRunLength: connectorRunLength,
        edgeRunLength: edgeRunLength,
        leftLongRunLength: rightIsShorter ? 2 : 4,
        rightLongRunLength: rightIsShorter ? 4 : 2,
        leftConnectorRunLength: rightIsShorter ? connectorRunLength : 1,
        rightConnectorRunLength: rightIsShorter ? 1 : connectorRunLength,
      );
      final balancedPlacements = balancedEngine.build(
        board: board,
        openingIndex: openingIndex,
        openingVertical: openingVertical,
        startsHorizontally: startsHorizontally,
      );
      final referenceEngine = TeamBoardLayoutEngine(
        longRunLength: max(3, baseLongRunLength),
        connectorRunLength: connectorRunLength,
        edgeRunLength: edgeRunLength,
      );
      final referencePlacements = referenceEngine.build(
        board: board,
        openingIndex: openingIndex,
        openingVertical: openingVertical,
        startsHorizontally: startsHorizontally,
      );
      final balancedScale = fitScale(
        bounds: boundsFor(balancedPlacements, padding: 0),
        availableSize: availableSize,
        preferredScale: preferredScale,
        visualMargin: visualMargin,
      );
      final referenceScale = fitScale(
        bounds: boundsFor(referencePlacements, padding: 0),
        availableSize: availableSize,
        preferredScale: preferredScale,
        visualMargin: visualMargin,
      );
      if (balancedScale + comparisonTolerance >= referenceScale &&
          validPlacements(balancedPlacements)) {
        return (engine: balancedEngine, placements: balancedPlacements);
      }
    }

    TeamBoardLayoutEngine? bestEngine;
    List<TeamBoardPlacement>? bestPlacements;
    var bestScale = -1.0;
    var bestPaintedArea = -1.0;
    var bestDistanceFromBase = 1 << 30;

    // On an iPad/Mac, do not make an early 90-degree turn while the straight
    // lane still has clear room. This keeps a 5-2 moving along its current
    // edge before the chain uses the free vertical space.
    final minimumLongRun =
        availableSize.shortestSide >= 600 ? min(5, baseLongRunLength) : 1;
    for (var leftRun = minimumLongRun; leftRun <= leftMaximum; leftRun++) {
      for (
        var rightRun = minimumLongRun;
        rightRun <= rightMaximum;
        rightRun++
      ) {
        for (
          var leftConnector = connectorMinimum;
          leftConnector <= connectorRunLength;
          leftConnector++
        ) {
          for (
            var rightConnector = connectorMinimum;
            rightConnector <= connectorRunLength;
            rightConnector++
          ) {
            final engine = TeamBoardLayoutEngine(
              longRunLength: baseLongRunLength,
              connectorRunLength: connectorRunLength,
              edgeRunLength: edgeRunLength,
              leftLongRunLength: leftRun,
              rightLongRunLength: rightRun,
              leftConnectorRunLength: leftConnector,
              rightConnectorRunLength: rightConnector,
            );
            final placements = engine.build(
              board: board,
              openingIndex: openingIndex,
              openingVertical: openingVertical,
              startsHorizontally: startsHorizontally,
            );
            if (!validPlacements(placements)) continue;
            final bounds = boundsFor(placements, padding: 0);
            final scale = fitScale(
              bounds: bounds,
              availableSize: availableSize,
              preferredScale: preferredScale,
              visualMargin: visualMargin,
            );
            final paintedArea = bounds.width * scale * bounds.height * scale;
            final distanceFromBase =
                (leftRun - baseLongRunLength).abs() +
                (rightRun - baseLongRunLength).abs() +
                (leftConnector - connectorRunLength).abs() +
                (rightConnector - connectorRunLength).abs();
            final improvesScale = scale > bestScale + comparisonTolerance;
            final tiesScale = (scale - bestScale).abs() <= comparisonTolerance;
            final usesMoreTable =
                paintedArea > bestPaintedArea + comparisonTolerance;
            final tiesArea =
                (paintedArea - bestPaintedArea).abs() <= comparisonTolerance;
            if (improvesScale ||
                (tiesScale && usesMoreTable) ||
                (tiesScale &&
                    tiesArea &&
                    distanceFromBase < bestDistanceFromBase)) {
              bestEngine = engine;
              bestPlacements = placements;
              bestScale = scale;
              bestPaintedArea = paintedArea;
              bestDistanceFromBase = distanceFromBase;
            }
          }
        }
      }
    }

    final fallbackEngine = TeamBoardLayoutEngine(
      longRunLength: baseLongRunLength,
      connectorRunLength: connectorRunLength,
      edgeRunLength: edgeRunLength,
    );
    return (
      engine: bestEngine ?? fallbackEngine,
      placements:
          bestPlacements ??
          fallbackEngine.build(
            board: board,
            openingIndex: openingIndex,
            openingVertical: openingVertical,
            startsHorizontally: startsHorizontally,
          ),
    );
  }

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
      if (segmentCount >= _segmentLimit(turnCount, side)) {
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

  int _segmentLimit(int turnCount, TeamBoardSide side) {
    if (turnCount == 0) {
      return switch (side) {
        TeamBoardSide.left => leftLongRunLength ?? longRunLength,
        TeamBoardSide.right => rightLongRunLength ?? longRunLength,
      };
    }
    if (turnCount.isOdd) {
      return switch (side) {
        TeamBoardSide.left => leftConnectorRunLength ?? connectorRunLength,
        TeamBoardSide.right => rightConnectorRunLength ?? connectorRunLength,
      };
    }
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
    List<TeamBoardPlacement> placements, {
    Size tileSize = const Size(30, 54),
    double padding = 8,
  }) {
    var bounds = Rect.zero;
    for (final placement in placements) {
      final rect = rectFor(placement, tileSize);
      bounds = bounds == Rect.zero ? rect : bounds.expandToInclude(rect);
    }
    return padding > 0 ? bounds.inflate(padding) : bounds;
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
  static bool debugStressTest({
    int iterations = 4000,
    TeamBoardLayoutEngine engine = const TeamBoardLayoutEngine(),
  }) {
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
    bool logFailures = true,
  ]) {
    for (var index = 1; index < placements.length; index++) {
      if (!adjacentTilesTouch(
        placements[index - 1],
        placements[index],
        tileSize,
      )) {
        if (logFailures) {
          debugPrint('Teams layout disconnected at $index.');
        }
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
          if (logFailures) {
            debugPrint(
              'Teams layout false contact: $a/$b first=$first second=$second '
              'intersection=$intersection',
            );
          }
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
