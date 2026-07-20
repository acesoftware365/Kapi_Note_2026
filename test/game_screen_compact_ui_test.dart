import 'package:dominoes_note2025/font_size_notifier.dart';
import 'package:dominoes_note2025/game_settings_notifier.dart';
import 'package:dominoes_note2025/l10n/app_localizations.dart';
import 'package:dominoes_note2025/premium_notifier.dart';
import 'package:dominoes_note2025/screens/game_screen.dart';
import 'package:dominoes_note2025/screens/team_name_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('score cards keep all action buttons inside on a small phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(300, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PremiumNotifier()),
          ChangeNotifierProvider(create: (_) => GameSettingsNotifier()),
          ChangeNotifierProvider(create: (_) => TeamNameNotifier()),
          ChangeNotifierProvider(create: (_) => FontSizeNotifier()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GameScreen(),
        ),
      ),
    );
    await tester.pump();

    final teamPanelRects = [
      tester.getRect(find.byKey(const ValueKey('notes-team-panel-Team A'))),
      tester.getRect(find.byKey(const ValueKey('notes-team-panel-Team B'))),
    ];
    expect(teamPanelRects, hasLength(2));
    expect(find.byType(FloatingActionButton), findsNWidgets(6));
    for (final button in find.byType(FloatingActionButton).evaluate()) {
      final buttonRect = tester.getRect(find.byWidget(button.widget));
      expect(
        teamPanelRects.any(
          (panelRect) =>
              panelRect.inflate(0.5).contains(buttonRect.topLeft) &&
              panelRect.inflate(0.5).contains(buttonRect.bottomRight),
        ),
        isTrue,
        reason: 'Every score action must stay within its team card.',
      );
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
