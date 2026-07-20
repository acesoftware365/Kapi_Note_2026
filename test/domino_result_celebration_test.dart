import 'package:dominoes_note2025/widgets/domino_result_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('result celebration fits a small phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DominoResultCelebration(
            showConfetti: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('RA wins the game'),
                Text('RA 30/30 · CPU 18/30'),
                Text('CPU tiles: 6-6, 5-4, 3-2'),
                Text('Your tiles: none'),
                FilledButton(onPressed: null, child: Text('Play Again')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    expect(find.text('Play Again'), findsOneWidget);
  });
}
