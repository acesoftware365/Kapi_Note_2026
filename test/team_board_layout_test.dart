import 'package:dominoes_note2025/screens/domino_teams/team_board_layout.dart';
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
}
