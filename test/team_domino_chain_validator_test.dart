import 'package:dominoes_note2025/services/team_domino_chain_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orients and validates a tile before placing it on the right', () {
    final result = TeamDominoChainValidator.tryPlace(
      board: const [(left: 2, right: 6), (left: 6, right: 5)],
      tile: const (left: 4, right: 5),
      side: TeamDominoChainSide.right,
    );

    expect(result, isNotNull);
    expect(result!.last, const (left: 5, right: 4));
    expect(TeamDominoChainValidator.isValidChain(result), isTrue);
  });

  test('orients and validates a tile before placing it on the left', () {
    final result = TeamDominoChainValidator.tryPlace(
      board: const [(left: 2, right: 6), (left: 6, right: 5)],
      tile: const (left: 2, right: 4),
      side: TeamDominoChainSide.left,
    );

    expect(result, isNotNull);
    expect(result!.first, const (left: 4, right: 2));
    expect(TeamDominoChainValidator.isValidChain(result), isTrue);
  });

  test('rejects a tile whose pips do not match the selected end', () {
    final result = TeamDominoChainValidator.tryPlace(
      board: const [(left: 2, right: 6), (left: 6, right: 5)],
      tile: const (left: 1, right: 4),
      side: TeamDominoChainSide.right,
    );

    expect(result, isNull);
  });

  test('rejects a board that already contains a broken connection', () {
    expect(
      TeamDominoChainValidator.isValidChain(const [
        (left: 2, right: 6),
        (left: 4, right: 5),
      ]),
      isFalse,
    );
  });

  test('rejects pip values outside a double-six set', () {
    expect(
      TeamDominoChainValidator.isValidChain(const [(left: 2, right: 7)]),
      isFalse,
    );
  });
}
