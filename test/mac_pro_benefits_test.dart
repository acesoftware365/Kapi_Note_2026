import 'dart:io';

import 'package:dominoes_note2025/premium_notifier.dart';
import 'package:dominoes_note2025/services/kapi_cosmetics_service.dart';
import 'package:dominoes_note2025/services/mac_pro_features_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('macOS Pro collection contains the promised eight items', () {
    final collection =
        KapiCosmeticsService.catalog.where((item) => item.macProOnly).toList();
    expect(collection, hasLength(8));
    expect(
      collection.where((item) => item.type == KapiCosmeticType.table),
      hasLength(2),
    );
    expect(
      collection.where((item) => item.type == KapiCosmeticType.domino),
      hasLength(2),
    );
    expect(
      collection.map((item) => item.type).toSet(),
      containsAll({
        KapiCosmeticType.centerpiece,
        KapiCosmeticType.handTray,
        KapiCosmeticType.avatar,
        KapiCosmeticType.specialEffect,
      }),
    );
  });

  test('Pro cosmetic access is removed when the entitlement ends', () async {
    if (!Platform.isMacOS) return;
    final store = KapiCosmeticsService();
    await store.load();
    final item = KapiCosmeticsService.byId('mac_pro_domino_aurora');

    expect(store.owns(item), isFalse);
    expect(await store.purchase(item), isFalse);
    await store.setMacProAccess(true);
    expect(store.owns(item), isTrue);
    expect(await store.equip(item), isTrue);
    expect(store.equipped(KapiCosmeticType.domino).id, item.id);

    await store.setMacProAccess(false);
    expect(store.owns(item), isFalse);
    expect(
      store.equipped(KapiCosmeticType.domino).id,
      KapiCosmeticsService.defaultId(KapiCosmeticType.domino),
    );
  });

  test('monthly 150 KC reward is idempotent', () async {
    final store = KapiCosmeticsService();
    await store.load();
    final claim = PremiumNotifier.macMonthlyClaimId(DateTime.utc(2026, 7, 15));
    expect(
      await store.claimPurchasedCoins(
        claimId: claim,
        amount: PremiumNotifier.macMonthlyCoins,
      ),
      isTrue,
    );
    expect(
      await store.claimPurchasedCoins(
        claimId: claim,
        amount: PremiumNotifier.macMonthlyCoins,
      ),
      isFalse,
    );
    expect(
      store.balance,
      KapiCosmeticsService.welcomeCoins + PremiumNotifier.macMonthlyCoins,
    );
  });

  test('monthly and yearly products receive distinct expiry periods', () {
    final start = DateTime.utc(2026, 7, 22, 12);
    expect(
      PremiumNotifier.macExpirationFor(PremiumNotifier.monthlyProductId, start),
      DateTime.utc(2026, 8, 22, 12),
    );
    expect(
      PremiumNotifier.macExpirationFor(PremiumNotifier.yearlyProductId, start),
      DateTime.utc(2027, 7, 22, 12),
    );
    expect(
      PremiumNotifier.macExpirationFor(
        PremiumNotifier.monthlyProductId,
        DateTime.utc(2026, 1, 31, 12),
      ),
      DateTime.utc(2026, 2, 28, 12),
    );
  });

  test('custom room score persists only through supported values', () async {
    if (!Platform.isMacOS) return;
    await MacProFeaturesService.instance.setTargetScore(50);
    expect(await MacProFeaturesService.instance.targetScore(), 50);
    await MacProFeaturesService.instance.setTargetScore(75);
    expect(await MacProFeaturesService.instance.targetScore(), 50);
  });
}
