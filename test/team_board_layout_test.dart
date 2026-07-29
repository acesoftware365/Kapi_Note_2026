import 'dart:math';

import 'package:dominoes_note2025/screens/domino_teams/team_board_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vertical regular opening faces the matching ends of both arms', () {
    const engine = TeamBoardLayoutEngine();
    final placements = engine.build(
      board: const [
        TeamBoardTileSpec(isDouble: false),
        TeamBoardTileSpec(isDouble: false),
        TeamBoardTileSpec(isDouble: false),
      ],
      openingIndex: 1,
      openingVertical: true,
      startsHorizontally: false,
    );

    expect(placements[1].vertical, isTrue);
    expect(
      placements[1].flipped,
      isTrue,
      reason:
          'The logical right end must face the upper arm and the left end the lower arm.',
    );
  });

  test('visual validator catches a reversed regular opening face', () {
    const engine = TeamBoardLayoutEngine();
    const board = [
      TeamBoardTileSpec(isDouble: false, left: 2, right: 6),
      TeamBoardTileSpec(isDouble: false, left: 6, right: 5),
      TeamBoardTileSpec(isDouble: false, left: 5, right: 4),
      TeamBoardTileSpec(isDouble: true, left: 4, right: 4),
      TeamBoardTileSpec(isDouble: false, left: 4, right: 1),
    ];
    final placements = engine.build(
      board: board,
      openingIndex: 2,
      openingVertical: true,
      startsHorizontally: false,
    );

    expect(
      TeamBoardLayoutEngine.validateVisualConnections(
        board: board,
        placements: placements,
        openingIndex: 2,
      ),
      isTrue,
    );

    final reversedOpening = [...placements];
    final opening = reversedOpening[2];
    reversedOpening[2] = TeamBoardPlacement(
      center: opening.center,
      vertical: opening.vertical,
      flipped: false,
      direction: opening.direction,
    );
    expect(
      TeamBoardLayoutEngine.validateVisualConnections(
        board: board,
        placements: reversedOpening,
        openingIndex: 2,
      ),
      isFalse,
    );
  });

  test('vertical double opening stays visually symmetric', () {
    const engine = TeamBoardLayoutEngine();
    final placements = engine.build(
      board: const [TeamBoardTileSpec(isDouble: true)],
      openingIndex: 0,
      openingVertical: true,
      startsHorizontally: true,
    );

    expect(placements.single.flipped, isFalse);
  });

  test('Teams board path keeps every domino connected without overlaps', () {
    expect(TeamBoardLayoutEngine.debugStressTest(), isTrue);
  });

  test('our vertical opening folds back after two transverse tiles', () {
    const openingIndex = 13;
    const engine = TeamBoardLayoutEngine();
    final placements = engine.build(
      board: List.generate(27, (_) => const TeamBoardTileSpec(isDouble: false)),
      openingIndex: openingIndex,
      openingVertical: true,
      startsHorizontally: false,
    );

    final upperArm = [
      for (var index = openingIndex + 1; index < placements.length; index++)
        placements[index].direction,
    ];
    final lowerArm = [
      for (var index = openingIndex - 1; index >= 0; index--)
        placements[index].direction,
    ];

    expect(upperArm, [
      ...List.filled(3, TeamBoardDirection.up),
      ...List.filled(2, TeamBoardDirection.left),
      ...List.filled(6, TeamBoardDirection.down),
      ...List.filled(2, TeamBoardDirection.left),
    ]);
    expect(lowerArm, [
      ...List.filled(3, TeamBoardDirection.down),
      ...List.filled(2, TeamBoardDirection.right),
      ...List.filled(6, TeamBoardDirection.up),
      ...List.filled(2, TeamBoardDirection.right),
    ]);
  });

  test('rival horizontal opening folds back after two transverse tiles', () {
    const openingIndex = 13;
    const engine = TeamBoardLayoutEngine();
    final placements = engine.build(
      board: List.generate(27, (_) => const TeamBoardTileSpec(isDouble: false)),
      openingIndex: openingIndex,
      openingVertical: false,
      startsHorizontally: true,
    );

    final rightArm = [
      for (var index = openingIndex + 1; index < placements.length; index++)
        placements[index].direction,
    ];
    final leftArm = [
      for (var index = openingIndex - 1; index >= 0; index--)
        placements[index].direction,
    ];

    expect(rightArm, [
      ...List.filled(3, TeamBoardDirection.right),
      ...List.filled(2, TeamBoardDirection.up),
      ...List.filled(6, TeamBoardDirection.left),
      ...List.filled(2, TeamBoardDirection.up),
    ]);
    expect(leftArm, [
      ...List.filled(3, TeamBoardDirection.left),
      ...List.filled(2, TeamBoardDirection.down),
      ...List.filled(6, TeamBoardDirection.right),
      ...List.filled(2, TeamBoardDirection.down),
    ]);
  });

  test('after the short connector the next lane reaches the far edge', () {
    const openingIndex = 0;
    const engine = TeamBoardLayoutEngine();
    final placements = engine.build(
      board: List.generate(13, (_) => const TeamBoardTileSpec(isDouble: false)),
      openingIndex: openingIndex,
      openingVertical: false,
      startsHorizontally: true,
    );

    final arm = [
      for (var index = 1; index < placements.length; index++)
        placements[index].direction,
    ];
    expect(arm, [
      ...List.filled(3, TeamBoardDirection.right),
      ...List.filled(2, TeamBoardDirection.up),
      ...List.filled(6, TeamBoardDirection.left),
      TeamBoardDirection.up,
    ]);
  });

  test('a double may be fourth but the following regular tile turns', () {
    const engine = TeamBoardLayoutEngine();
    final placements = engine.build(
      board: [
        const TeamBoardTileSpec(isDouble: true),
        ...List.generate(3, (_) => const TeamBoardTileSpec(isDouble: false)),
        const TeamBoardTileSpec(isDouble: true),
        const TeamBoardTileSpec(isDouble: false),
      ],
      openingIndex: 0,
      openingVertical: true,
      startsHorizontally: true,
    );

    final arm = [
      for (var index = 1; index < placements.length; index++) placements[index],
    ];
    expect(arm.map((placement) => placement.direction), [
      ...List.filled(4, TeamBoardDirection.right),
      TeamBoardDirection.up,
    ]);
    expect(
      arm[3].vertical,
      isTrue,
      reason: 'The fourth double stays across the horizontal line.',
    );
  });

  test('the opening lane contains seven regular tiles in total', () {
    const openingIndex = 3;
    const engine = TeamBoardLayoutEngine();
    final placements = engine.build(
      board: List.generate(8, (_) => const TeamBoardTileSpec(isDouble: false)),
      openingIndex: openingIndex,
      openingVertical: true,
      startsHorizontally: false,
    );

    for (var index = 0; index <= 6; index++) {
      expect(
        placements[index].direction,
        anyOf(TeamBoardDirection.up, TeamBoardDirection.down),
      );
    }
    expect(
      placements[7].direction,
      TeamBoardDirection.left,
      reason: 'The fourth tile on the upper arm must begin the first bend.',
    );
  });

  group('Teams board visual scale', () {
    const engine = TeamBoardLayoutEngine();
    const available = Size(400, 300);
    const margin = 6.0;

    Rect boundsForChain(int count) {
      final placements = engine.build(
        board: List.generate(
          count,
          (_) => const TeamBoardTileSpec(isDouble: false),
        ),
        openingIndex: count ~/ 2,
        openingVertical: false,
        startsHorizontally: true,
      );
      return TeamBoardLayoutEngine.boundsFor(placements, padding: 0);
    }

    test(
      'short and medium chains keep their requested scale when they fit',
      () {
        final shortBounds = boundsForChain(3);
        final mediumBounds = boundsForChain(7);

        expect(shortBounds.size, const Size(162, 30));
        expect(mediumBounds.size, const Size(378, 30));

        final shortScale = TeamBoardLayoutEngine.fitScale(
          bounds: shortBounds,
          availableSize: available,
          preferredScale: 1.75,
          visualMargin: margin,
        );
        final mediumScale = TeamBoardLayoutEngine.fitScale(
          bounds: mediumBounds,
          availableSize: available,
          preferredScale: 1,
          visualMargin: margin,
        );

        expect(
          shortScale,
          1.75,
          reason:
              'A short chain that fits must keep its enlarged visual scale.',
        );
        expect(
          mediumScale,
          1,
          reason: 'A medium chain that fits must stay at its natural scale.',
        );
      },
    );

    test('a long chain shrinks only to the limiting edge and stays inside', () {
      final bounds = boundsForChain(27);
      expect(bounds.size, const Size(378, 462));

      final scale = TeamBoardLayoutEngine.fitScale(
        bounds: bounds,
        availableSize: available,
        preferredScale: 1,
        visualMargin: margin,
      );
      final safeWidth = available.width - margin * 2;
      final safeHeight = available.height - margin * 2;
      final expectedScale = min(
        1.0,
        min(safeWidth / bounds.width, safeHeight / bounds.height),
      );
      final paintedWidth = bounds.width * scale + margin * 2;
      final paintedHeight = bounds.height * scale + margin * 2;

      expect(scale, lessThan(1));
      expect(scale, closeTo(expectedScale, 0.000001));
      expect(paintedWidth, lessThanOrEqualTo(available.width));
      expect(paintedHeight, lessThanOrEqualTo(available.height));
      expect(
        paintedHeight,
        closeTo(available.height, 0.000001),
        reason: 'The limiting edge must be used instead of over-shrinking.',
      );
      expect(
        bounds.height * (scale + 0.001) + margin * 2,
        greaterThan(available.height),
        reason: 'Any larger scale would leave the playable area.',
      );
    });

    test('final visual margin stays fixed after the chain is scaled', () {
      const bounds = Rect.fromLTWH(0, 0, 100, 50);
      const tightAvailable = Size(212, 112);

      final scale = TeamBoardLayoutEngine.fitScale(
        bounds: bounds,
        availableSize: tightAvailable,
        preferredScale: 2,
        visualMargin: margin,
      );

      expect(scale, 2);
      expect(bounds.width * scale + margin * 2, tightAvailable.width);
      expect(bounds.height * scale + margin * 2, tightAvailable.height);
      expect(
        margin,
        6,
        reason:
            'The six-pixel margin is applied after scaling and must not grow '
            'with the dominoes.',
      );
    });

    test('a single opening tile starts centered', () {
      const available = Size(352, 500);
      const preferredScale = 1.4;

      for (final openingVertical in [false, true]) {
        final placements = engine.build(
          board: const [TeamBoardTileSpec(isDouble: false)],
          openingIndex: 0,
          openingVertical: openingVertical,
          startsHorizontally: !openingVertical,
        );
        final openingRect = TeamBoardLayoutEngine.rectFor(placements.single);
        final fit = TeamBoardLayoutEngine.centeredFit(
          bounds: openingRect,
          availableSize: available,
          preferredScale: preferredScale,
        );
        final paintedOpeningCenter =
            fit.translation + openingRect.center * fit.scale;

        expect(fit.scale, preferredScale);
        expect(paintedOpeningCenter, available.center(Offset.zero));
      }
    });

    test(
      'an asymmetric chain centers the composition and moves the opening',
      () {
        const asymmetricEngine = TeamBoardLayoutEngine(
          longRunLength: 1,
          edgeRunLength: 4,
        );
        const available = Size(352, 500);
        const preferredScale = 1.4;
        const openingIndex = 0;
        final placements = asymmetricEngine.build(
          board: List.generate(
            13,
            (index) => TeamBoardTileSpec(isDouble: index % 5 == 0),
          ),
          openingIndex: openingIndex,
          openingVertical: false,
          startsHorizontally: true,
        );
        final bounds = TeamBoardLayoutEngine.boundsFor(placements, padding: 0);
        final openingRect = TeamBoardLayoutEngine.rectFor(
          placements[openingIndex],
        );
        final fit = TeamBoardLayoutEngine.centeredFit(
          bounds: bounds,
          availableSize: available,
          preferredScale: preferredScale,
        );
        final paintedBounds = Rect.fromLTRB(
          fit.translation.dx + bounds.left * fit.scale,
          fit.translation.dy + bounds.top * fit.scale,
          fit.translation.dx + bounds.right * fit.scale,
          fit.translation.dy + bounds.bottom * fit.scale,
        );
        final paintedOpeningCenter =
            fit.translation + openingRect.center * fit.scale;

        expect(
          (paintedBounds.center - available.center(Offset.zero)).distance,
          lessThan(0.000001),
        );
        expect(
          (paintedOpeningCenter - available.center(Offset.zero)).distance,
          greaterThan(1),
          reason:
              'Centering an asymmetric composition is allowed to move its '
              'opening tile.',
        );
        expect(paintedBounds.left, greaterThanOrEqualTo(6 - 0.000001));
        expect(paintedBounds.top, greaterThanOrEqualTo(6 - 0.000001));
        expect(
          paintedBounds.right,
          lessThanOrEqualTo(available.width - 6 + 0.000001),
        );
        expect(
          paintedBounds.bottom,
          lessThanOrEqualTo(available.height - 6 + 0.000001),
        );
      },
    );

    test('red and blue previews center the full composition and fit', () {
      const engine = TeamBoardLayoutEngine(longRunLength: 1, edgeRunLength: 4);
      const available = Size(352, 500);
      const preferredScale = 1.4;
      const openingIndex = 2;
      final board = List.generate(
        13,
        (_) => const TeamBoardTileSpec(isDouble: false),
      );
      final placements = engine.build(
        board: board,
        openingIndex: openingIndex,
        openingVertical: false,
        startsHorizontally: true,
      );
      final boardBounds = TeamBoardLayoutEngine.boundsFor(
        placements,
        padding: 0,
      );
      final leftHypothetical = engine.build(
        board: [const TeamBoardTileSpec(isDouble: false), ...board],
        openingIndex: openingIndex + 1,
        openingVertical: false,
        startsHorizontally: true,
      );
      final rightHypothetical = engine.build(
        board: [...board, const TeamBoardTileSpec(isDouble: false)],
        openingIndex: openingIndex,
        openingVertical: false,
        startsHorizontally: true,
      );
      final leftPreview = TeamBoardLayoutEngine.rectFor(leftHypothetical.first);
      final rightPreview = TeamBoardLayoutEngine.rectFor(
        rightHypothetical.last,
      );
      final contentBounds = <Rect>[
        boardBounds,
        boardBounds.expandToInclude(leftPreview),
        boardBounds.expandToInclude(rightPreview),
        boardBounds.expandToInclude(leftPreview).expandToInclude(rightPreview),
      ];

      for (final content in contentBounds) {
        final fit = TeamBoardLayoutEngine.centeredFit(
          bounds: content,
          availableSize: available,
          preferredScale: preferredScale,
        );
        final paintedContent = Rect.fromLTRB(
          fit.translation.dx + content.left * fit.scale,
          fit.translation.dy + content.top * fit.scale,
          fit.translation.dx + content.right * fit.scale,
          fit.translation.dy + content.bottom * fit.scale,
        );

        expect(
          (paintedContent.center - available.center(Offset.zero)).distance,
          lessThan(0.000001),
        );
        expect(paintedContent.left, greaterThanOrEqualTo(6 - 0.000001));
        expect(paintedContent.top, greaterThanOrEqualTo(6 - 0.000001));
        expect(
          paintedContent.right,
          lessThanOrEqualTo(available.width - 6 + 0.000001),
        );
        expect(
          paintedContent.bottom,
          lessThanOrEqualTo(available.height - 6 + 0.000001),
        );
      }
    });
  });

  group('Teams board responsive runs', () {
    test('uses the intended first-run length at phone and desktop widths', () {
      const expected = <({double width, bool horizontal, int runLength})>[
        (width: 320, horizontal: true, runLength: 1),
        (width: 320, horizontal: false, runLength: 2),
        (width: 400, horizontal: true, runLength: 1),
        (width: 400, horizontal: false, runLength: 2),
        (width: 440, horizontal: true, runLength: 1),
        (width: 440, horizontal: false, runLength: 2),
        (width: 800, horizontal: true, runLength: 3),
        (width: 800, horizontal: false, runLength: 3),
      ];

      for (final scenario in expected) {
        expect(
          TeamBoardLayoutEngine.responsiveLongRunLengthForWidth(
            scenario.width,
            startsHorizontally: scenario.horizontal,
          ),
          scenario.runLength,
          reason:
              '${scenario.width}px, startsHorizontally='
              '${scenario.horizontal}',
        );
      }
    });

    test('phone paths use the intended responsive edge lanes', () {
      const expected = <({double width, bool horizontal, int runLength})>[
        (width: 320, horizontal: true, runLength: 4),
        (width: 320, horizontal: false, runLength: 7),
        (width: 400, horizontal: true, runLength: 4),
        (width: 400, horizontal: false, runLength: 7),
        (width: 440, horizontal: true, runLength: 4),
        (width: 440, horizontal: false, runLength: 7),
        (width: 800, horizontal: true, runLength: 6),
        (width: 800, horizontal: false, runLength: 6),
      ];

      for (final scenario in expected) {
        expect(
          TeamBoardLayoutEngine.responsiveEdgeRunLengthForWidth(
            scenario.width,
            startsHorizontally: scenario.horizontal,
          ),
          scenario.runLength,
          reason:
              '${scenario.width}px, startsHorizontally='
              '${scenario.horizontal}',
        );
      }
    });

    test('responsive phone routes remain connected through full hands', () {
      expect(
        TeamBoardLayoutEngine.debugStressTest(
          iterations: 5000,
          engine: const TeamBoardLayoutEngine(
            longRunLength: 1,
            connectorRunLength: 2,
            edgeRunLength: 4,
          ),
        ),
        isTrue,
      );
      expect(
        TeamBoardLayoutEngine.debugStressTest(
          iterations: 5000,
          engine: const TeamBoardLayoutEngine(
            longRunLength: 2,
            connectorRunLength: 2,
            edgeRunLength: 7,
          ),
        ),
        isTrue,
      );
    });

    test(
      'a long horizontal phone chain uses height before reducing its tiles',
      () {
        const viewportWidth = 440.0;
        const available = Size(352, 500);
        const preferredScale = 1.4;
        const openingIndex = 10;
        final board = List.generate(
          20,
          (_) => const TeamBoardTileSpec(isDouble: false),
        );

        final responsiveEngine = TeamBoardLayoutEngine(
          longRunLength: TeamBoardLayoutEngine.responsiveLongRunLengthForWidth(
            viewportWidth,
            startsHorizontally: true,
          ),
          edgeRunLength: TeamBoardLayoutEngine.responsiveEdgeRunLengthForWidth(
            viewportWidth,
            startsHorizontally: true,
          ),
        );
        const oldPhoneRoute = TeamBoardLayoutEngine(
          longRunLength: 1,
          edgeRunLength: 6,
        );

        Rect boundsFor(TeamBoardLayoutEngine engine) =>
            TeamBoardLayoutEngine.boundsFor(
              engine.build(
                board: board,
                openingIndex: openingIndex,
                openingVertical: false,
                startsHorizontally: true,
              ),
              padding: 0,
            );

        final responsiveBounds = boundsFor(responsiveEngine);
        final oldBounds = boundsFor(oldPhoneRoute);
        final responsiveScale = TeamBoardLayoutEngine.fitScale(
          bounds: responsiveBounds,
          availableSize: available,
          preferredScale: preferredScale,
        );
        final oldScale = TeamBoardLayoutEngine.fitScale(
          bounds: oldBounds,
          availableSize: available,
          preferredScale: preferredScale,
        );

        expect(responsiveBounds.size, const Size(330, 462));
        expect(oldBounds.size, const Size(546, 300));
        expect(
          responsiveScale,
          greaterThan(oldScale * 1.6),
          reason:
              'The taller route must keep late-hand dominoes materially '
              'larger instead of zooming out across unused vertical space.',
        );
        expect(
          responsiveBounds.width * responsiveScale + 12,
          closeTo(352, 0.000001),
        );
        expect(
          responsiveBounds.height * responsiveScale + 12,
          lessThan(available.height),
        );
      },
    );

    test(
      'vertical phone edge run seven uses height and keeps late tiles larger',
      () {
        const available = Size(352, 500);
        const preferredScale = 1.4;
        const openingIndex = 13;
        final board = List.generate(
          26,
          (_) => const TeamBoardTileSpec(isDouble: false),
        );

        Rect boundsFor(int edgeRunLength) => TeamBoardLayoutEngine.boundsFor(
          TeamBoardLayoutEngine(
            longRunLength: 2,
            connectorRunLength: 2,
            edgeRunLength: edgeRunLength,
          ).build(
            board: board,
            openingIndex: openingIndex,
            openingVertical: true,
            startsHorizontally: false,
          ),
          padding: 0,
        );

        final edgeSixBounds = boundsFor(6);
        final edgeSevenBounds = boundsFor(7);
        final edgeSixFit = TeamBoardLayoutEngine.centeredFit(
          bounds: edgeSixBounds,
          availableSize: available,
          preferredScale: preferredScale,
        );
        final edgeSevenFit = TeamBoardLayoutEngine.centeredFit(
          bounds: edgeSevenBounds,
          availableSize: available,
          preferredScale: preferredScale,
        );

        expect(edgeSevenBounds.height, greaterThan(edgeSixBounds.height));
        expect(edgeSevenBounds.width, lessThan(edgeSixBounds.width));
        expect(
          edgeSevenFit.scale,
          greaterThan(edgeSixFit.scale * 1.1),
          reason:
              'The seven-tile lane should trade unused height for narrower '
              'bounds and visibly larger late-hand dominoes.',
        );
      },
    );

    test(
      'responsive run lengths make the real chain turn at each breakpoint',
      () {
        List<TeamBoardDirection> positiveArm({
          required double width,
          required bool startsHorizontally,
        }) {
          final runLength =
              TeamBoardLayoutEngine.responsiveLongRunLengthForWidth(
                width,
                startsHorizontally: startsHorizontally,
              );
          final placements = TeamBoardLayoutEngine(
            longRunLength: runLength,
          ).build(
            board: List.generate(
              5,
              (_) => const TeamBoardTileSpec(isDouble: false),
            ),
            openingIndex: 0,
            openingVertical: !startsHorizontally,
            startsHorizontally: startsHorizontally,
          );
          return [
            for (var index = 1; index < placements.length; index++)
              placements[index].direction,
          ];
        }

        for (final width in [320.0, 400.0, 440.0]) {
          expect(positiveArm(width: width, startsHorizontally: true), [
            TeamBoardDirection.right,
            TeamBoardDirection.up,
            TeamBoardDirection.up,
            TeamBoardDirection.left,
          ]);
        }
        expect(positiveArm(width: 800, startsHorizontally: true), [
          TeamBoardDirection.right,
          TeamBoardDirection.right,
          TeamBoardDirection.right,
          TeamBoardDirection.up,
        ]);
        expect(positiveArm(width: 320, startsHorizontally: false), [
          TeamBoardDirection.up,
          TeamBoardDirection.up,
          TeamBoardDirection.left,
          TeamBoardDirection.left,
        ]);
      },
    );

    test(
      'late phone chain uses the free left lane before turning downward',
      () {
        const available = Size(352, 500);
        const preferredScale = 1.4;
        const openingIndex = 12;
        const doubles = {1, 4, 12};
        final board = [
          for (var index = 0; index < 20; index++)
            TeamBoardTileSpec(isDouble: doubles.contains(index)),
        ];

        final choice = TeamBoardLayoutEngine.bestFit(
          board: board,
          openingIndex: openingIndex,
          openingVertical: true,
          startsHorizontally: true,
          availableSize: available,
          preferredScale: preferredScale,
          baseLongRunLength: 1,
          edgeRunLength: 4,
        );
        final positiveArm = [
          for (var index = openingIndex + 1; index < board.length; index++)
            choice.placements[index].direction,
        ];
        expect(positiveArm.take(4), everyElement(TeamBoardDirection.right));
        expect(positiveArm[4], TeamBoardDirection.up);
        expect(positiveArm[5], TeamBoardDirection.left);
        expect(positiveArm[6], TeamBoardDirection.left);

        const oldEngine = TeamBoardLayoutEngine(
          longRunLength: 3,
          connectorRunLength: 2,
          edgeRunLength: 4,
        );
        final oldBounds = TeamBoardLayoutEngine.boundsFor(
          oldEngine.build(
            board: board,
            openingIndex: openingIndex,
            openingVertical: true,
            startsHorizontally: true,
          ),
          padding: 0,
        );
        final selectedBounds = TeamBoardLayoutEngine.boundsFor(
          choice.placements,
          padding: 0,
        );
        final oldScale = TeamBoardLayoutEngine.fitScale(
          bounds: oldBounds,
          availableSize: available,
          preferredScale: preferredScale,
        );
        final selectedScale = TeamBoardLayoutEngine.fitScale(
          bounds: selectedBounds,
          availableSize: available,
          preferredScale: preferredScale,
        );
        expect(selectedScale, greaterThanOrEqualTo(oldScale));
        expect(
          TeamBoardLayoutEngine.debugValidatePlacements(choice.placements),
          isTrue,
        );
      },
    );

    test(
      'five horizontal tiles plus both previews keep target scale on phones',
      () {
        for (final viewportWidth in [400.0, 440.0]) {
          final engine = TeamBoardLayoutEngine(
            longRunLength:
                TeamBoardLayoutEngine.responsiveLongRunLengthForWidth(
                  viewportWidth,
                  startsHorizontally: true,
                ),
          );
          const openingIndex = 2;
          final board = List.generate(
            5,
            (_) => const TeamBoardTileSpec(isDouble: false),
          );
          final placements = engine.build(
            board: board,
            openingIndex: openingIndex,
            openingVertical: false,
            startsHorizontally: true,
          );
          final boardBounds = TeamBoardLayoutEngine.boundsFor(
            placements,
            padding: 0,
          );
          final leftHypothetical = engine.build(
            board: [const TeamBoardTileSpec(isDouble: false), ...board],
            openingIndex: openingIndex + 1,
            openingVertical: false,
            startsHorizontally: true,
          );
          final rightHypothetical = engine.build(
            board: [...board, const TeamBoardTileSpec(isDouble: false)],
            openingIndex: openingIndex,
            openingVertical: false,
            startsHorizontally: true,
          );
          final contentBounds = boardBounds
              .expandToInclude(
                TeamBoardLayoutEngine.rectFor(leftHypothetical.first),
              )
              .expandToInclude(
                TeamBoardLayoutEngine.rectFor(rightHypothetical.last),
              );

          const sideInset = 38.0;
          final available = Size(viewportWidth - 12 - sideInset * 2, 400);
          final preferredShortEdge = (viewportWidth * 0.10).clamp(36.0, 42.0);
          final preferredScale = preferredShortEdge / 30;
          final scale = TeamBoardLayoutEngine.fitScale(
            bounds: contentBounds,
            availableSize: available,
            preferredScale: preferredScale,
          );

          expect(engine.longRunLength, 1);
          expect(
            scale,
            preferredScale,
            reason:
                'Both temporary previews must fit without shrinking the '
                'played domino target at $viewportWidth px.',
          );
          expect(
            contentBounds.width * scale + 12,
            lessThanOrEqualTo(available.width),
          );
          expect(
            contentBounds.height * scale + 12,
            lessThanOrEqualTo(available.height),
          );
        }
      },
    );
  });
}
