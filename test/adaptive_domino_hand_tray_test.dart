import 'package:dominoes_note2025/widgets/adaptive_domino_hand_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark dominoes receive a light contrast surface', () {
    expect(
      AdaptiveDominoHandTray.needsLightSurface(const Color(0xFF20252B)),
      isTrue,
    );
  });

  test('light dominoes retain a dark contrast surface', () {
    expect(
      AdaptiveDominoHandTray.needsLightSurface(const Color(0xFFF5EBD2)),
      isFalse,
    );
  });

  testWidgets('adaptive tray lays out in a compact hand area', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              height: 70,
              child: AdaptiveDominoHandTray(
                dominoColor: Color(0xFF20252B),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AdaptiveDominoHandTray), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
