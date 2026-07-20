import 'package:dominoes_note2025/premium_notifier.dart';
import 'package:dominoes_note2025/screens/kapi_store_screen.dart';
import 'package:dominoes_note2025/services/kapi_cosmetics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapi Shop fits and completes a purchase on a 320px phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = KapiCosmeticsService();
    await store.load();
    final premium = PremiumNotifier();
    addTearDown(premium.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<KapiCosmeticsService>.value(value: store),
          ChangeNotifierProvider<PremiumNotifier>.value(value: premium),
        ],
        child: MaterialApp(
          home: KapiStoreScreen(ensureCoinAccount: (_) async => true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Kapi Shop'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('Classic table'), findsOneWidget);
    expect(find.text('Blue night'), findsOneWidget);
    expect(find.text('TEST +500'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(find.text('Buy Kapi Coins'), findsOneWidget);
    expect(find.text(r'$0.99'), findsOneWidget);
    expect(find.text(r'$2.99'), findsOneWidget);
    expect(find.text(r'$4.99'), findsOneWidget);
    expect(find.text(r'$9.99'), findsOneWidget);
    expect(find.text(r'$19.99'), findsOneWidget);
    expect(find.text('POPULAR'), findsOneWidget);
    expect(find.text('BEST VALUE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TEST +500'));
    await tester.pump();
    expect(store.balance, 650);

    await tester.tap(find.text('250').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.balance, 400);
    expect(store.equipped(KapiCosmeticType.table).id, 'table_night');
    expect(find.text('400'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(store.equipped(KapiCosmeticType.table).id, 'table_classic');
    expect(find.text('Equipped'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(store.equipped(KapiCosmeticType.table).id, 'table_night');
    expect(tester.takeException(), isNull);

    final centerpieceTab = find.text('Centerpieces', skipOffstage: false);
    await tester.ensureVisible(centerpieceTab);
    await tester.pumpAndSettle();
    await tester.tap(centerpieceTab);
    await tester.pumpAndSettle();
    expect(find.text('No centerpiece'), findsOneWidget);
    expect(find.text('Moonlight Coquí'), findsOneWidget);
    expect(find.text('Plantain Party'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final avatarTab = find.text('Avatars', skipOffstage: false);
    await tester.ensureVisible(avatarTab);
    await tester.pumpAndSettle();
    await tester.tap(avatarTab);
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Star player'), findsOneWidget);
    expect(find.text('Robot'), findsOneWidget);
    await tester.drag(find.byType(GridView), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('Golden Champion'), findsOneWidget);
    expect(
      KapiCosmeticsService.catalog
          .where(
            (item) => item.type == KapiCosmeticType.avatar && item.storeVisible,
          )
          .map((item) => item.nameEn),
      containsAll(<String>['Crimson Ace', 'Emerald Android']),
    );
    expect(tester.takeException(), isNull);

    final flagsTab = find.text('Flags', skipOffstage: false);
    await tester.ensureVisible(flagsTab);
    await tester.pumpAndSettle();
    await tester.tap(flagsTab);
    await tester.pumpAndSettle();
    expect(find.text('No badge'), findsOneWidget);
    expect(find.text('Dominican Republic'), findsOneWidget);
    expect(
      KapiCosmeticsService.catalog
          .where((item) => item.type == KapiCosmeticType.flag)
          .map((item) => item.nameEn),
      containsAll(<String>['Mexico', 'Colombia', 'Jamaica', 'Haiti']),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('Dice', skipOffstage: false), findsNothing);
    expect(find.text('Golden midnight'), findsNothing);
    expect(find.text('Caribbean teal'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
