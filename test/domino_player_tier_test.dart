import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ranking tiers use the same point thresholds on every screen', () {
    expect(DominoTierVisual.fromScore(0).label, 'Iron');
    expect(DominoTierVisual.fromScore(99).label, 'Iron');
    expect(DominoTierVisual.fromScore(100).label, 'Bronze');
    expect(DominoTierVisual.fromScore(250).label, 'Silver');
    expect(DominoTierVisual.fromScore(500).label, 'Gold');
    expect(DominoTierVisual.fromScore(900).label, 'Platinum');
  });
}
