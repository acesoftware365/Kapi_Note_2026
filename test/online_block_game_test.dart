import 'package:dominoes_note2025/screens/domino_online_game_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Block online keeps matching tips and round rules', () {
    expect(OnlineGameFactory.debugValidateBlockRules(), isTrue);
  });

  test('Block online board rectangles stay connected through turns', () {
    expect(OnlineGameFactory.debugValidateBoardGeometry(), isTrue);
  });

  test('Block online survives forty rapid deterministic games', () {
    expect(OnlineGameFactory.debugValidateRapidGames(), isTrue);
  });
}
