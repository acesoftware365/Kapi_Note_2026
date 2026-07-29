import 'package:dominoes_note2025/widgets/domino_special_play_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget effect(DominoSpecialEffectKind kind) => MaterialApp(
    home: Scaffold(
      body: DominoSpecialPlayEffect(
        kind: kind,
        sequence: 1,
        spanish: true,
        playerName: 'Juan',
      ),
    ),
  );

  testWidgets('shows the centered pass effect', (tester) async {
    await tester.pumpWidget(effect(DominoSpecialEffectKind.pass));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('¡PASO!'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
  });

  testWidgets('shows the capicua celebration and bonus', (tester) async {
    await tester.pumpWidget(effect(DominoSpecialEffectKind.capicua));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('¡CAPICÚA!'), findsOneWidget);
    expect(find.text('JUGADA ESPECIAL  ·  +25'), findsOneWidget);
  });

  testWidgets('shows the blocked-hand effect before results', (tester) async {
    await tester.pumpWidget(effect(DominoSpecialEffectKind.blocked));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('¡BLOQUEO!'), findsOneWidget);
    expect(find.text('TRES PASES  ·  MANO TRANCADA'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('shows the domino celebration before results', (tester) async {
    await tester.pumpWidget(effect(DominoSpecialEffectKind.domino));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('¡DOMINÓ!'), findsOneWidget);
    expect(find.text('Juan  ·  MANO GANADA'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsWidgets);
  });
}
