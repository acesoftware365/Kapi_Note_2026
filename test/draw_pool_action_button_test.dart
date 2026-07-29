import 'package:dominoes_note2025/widgets/draw_pool_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the English and Spanish labels with the pool counter', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await _pumpButton(
      tester,
      remaining: 14,
      isSpanish: false,
      onPressed: () {},
    );

    expect(find.text('Draw tile'), findsOneWidget);
    expect(find.text('14 in pool'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('draw-pool-action-test')))
          .label,
      'Draw tile from pool, 14 remaining',
    );

    await _pumpButton(tester, remaining: 9, isSpanish: true, onPressed: () {});

    expect(find.text('Tomar ficha'), findsOneWidget);
    expect(find.text('9 en el pozo'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('draw-pool-action-test')))
          .label,
      'Tomar ficha del pozo, 9 restantes',
    );

    semantics.dispose();
  });

  testWidgets('calls back only while the pool action is enabled', (
    tester,
  ) async {
    var taps = 0;

    await _pumpButton(
      tester,
      remaining: 14,
      isSpanish: false,
      onPressed: () => taps++,
    );
    await tester.tap(find.byKey(const ValueKey('draw-pool-action-test')));
    await tester.pump();
    expect(taps, 1);

    await _pumpButton(tester, remaining: 14, isSpanish: false, onPressed: null);
    await tester.tap(find.byKey(const ValueKey('draw-pool-action-test')));
    await tester.pump();
    expect(taps, 1);

    await _pumpButton(
      tester,
      remaining: 0,
      isSpanish: false,
      onPressed: () => taps++,
    );
    await tester.tap(find.byKey(const ValueKey('draw-pool-action-test')));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('keeps a minimum 48 point touch target at 320x720', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpButton(
      tester,
      remaining: 14,
      isSpanish: false,
      compact: true,
      onPressed: () {},
    );

    final size = tester.getSize(
      find.byKey(const ValueKey('draw-pool-action-test')),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('grows without clipping when accessibility text is enlarged', (
    tester,
  ) async {
    await _pumpButton(
      tester,
      remaining: 14,
      isSpanish: true,
      compact: true,
      textScaler: const TextScaler.linear(2),
      onPressed: () {},
    );

    final size = tester.getSize(
      find.byKey(const ValueKey('draw-pool-action-test')),
    );
    expect(size.height, greaterThan(52));
    expect(find.text('Tomar ficha'), findsOneWidget);
    expect(find.text('14 en el pozo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('becomes one full-width notification action', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;

    await _pumpButton(
      tester,
      remaining: 13,
      isSpanish: false,
      fillWidth: true,
      feedbackText: 'You drew 2-4',
      onPressed: () => taps++,
    );

    final action = find.byKey(const ValueKey('draw-pool-action-test'));
    final rect = tester.getRect(action);
    expect(rect.width, 390);
    expect(find.text('You drew 2-4'), findsOneWidget);
    expect(find.text('13 in pool · Tap to draw'), findsOneWidget);

    await tester.tapAt(rect.centerLeft + const Offset(12, 0));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpButton(
  WidgetTester tester, {
  required int remaining,
  required bool isSpanish,
  required VoidCallback? onPressed,
  bool compact = false,
  bool fillWidth = false,
  String? feedbackText,
  TextScaler? textScaler,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder:
          textScaler == null
              ? null
              : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
      home: Scaffold(
        body: Center(
          child: DrawPoolActionButton(
            key: const ValueKey('draw-pool-action-test'),
            remaining: remaining,
            isSpanish: isSpanish,
            compact: compact,
            fillWidth: fillWidth,
            feedbackText: feedbackText,
            onPressed: onPressed,
          ),
        ),
      ),
    ),
  );
}
