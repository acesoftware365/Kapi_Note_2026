import 'dart:io';

import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:dominoes_note2025/services/kapi_cosmetics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new wallet receives one welcome gift and keeps it after reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = KapiCosmeticsService();
      await first.load();
      expect(first.balance, KapiCosmeticsService.welcomeCoins);
      expect(first.revision, 1);

      final second = KapiCosmeticsService();
      await second.load();
      expect(second.balance, KapiCosmeticsService.welcomeCoins);
      expect(second.revision, 1);
    },
  );

  test('purchase subtracts coins, owns item and can equip it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KapiCosmeticsService();
    await store.load();
    final item = KapiCosmeticsService.byId('domino_midnight');

    expect(await store.purchase(item), isFalse);
    for (var hand = 1; hand <= 15; hand += 1) {
      expect(await store.claimVictory(rewardKey: 'earned-$hand'), isTrue);
    }

    expect(await store.purchase(item), isTrue);
    expect(
      store.balance,
      KapiCosmeticsService.welcomeCoins +
          (15 * KapiCosmeticsService.winReward) -
          item.price,
    );
    expect(store.revision, 17);
    expect(store.owns(item), isTrue);
    expect(await store.equip(item), isTrue);
    expect(store.equipped(KapiCosmeticType.domino).id, item.id);
    expect(store.revision, 18);
  });

  test('every paid item respects the balanced starter price floor', () {
    final firstAffordableBalance = KapiCosmeticsService.welcomeCoins;
    final paidItems = KapiCosmeticsService.catalog.where(
      (item) => item.price > 0,
    );

    expect(paidItems, isNotEmpty);
    expect(
      paidItems.every((item) => item.price >= firstAffordableBalance),
      isTrue,
    );
    expect(paidItems.where((item) => item.exclusive), isNotEmpty);
  });

  test('cannot purchase an item without enough coins', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KapiCosmeticsService();
    await store.load();
    final item = KapiCosmeticsService.byId('table_caribbean');

    expect(await store.purchase(item), isFalse);
    expect(store.owns(item), isFalse);
    expect(store.balance, KapiCosmeticsService.welcomeCoins);
  });

  test('reward key makes a victory award idempotent', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KapiCosmeticsService();
    await store.load();

    expect(await store.claimVictory(rewardKey: 'match-1'), isTrue);
    expect(await store.claimVictory(rewardKey: 'match-1'), isFalse);
    expect(
      store.balance,
      KapiCosmeticsService.welcomeCoins + KapiCosmeticsService.winReward,
    );
  });

  test('test coin tool adds coins and persists them', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KapiCosmeticsService();
    await store.load();

    expect(KapiCosmeticsService.testCoinToolsEnabled, isTrue);
    expect(await store.addTestCoins(), isTrue);
    expect(store.balance, KapiCosmeticsService.welcomeCoins + 500);

    final reloaded = KapiCosmeticsService();
    await reloaded.load();
    expect(reloaded.balance, KapiCosmeticsService.welcomeCoins + 500);
  });

  test('a purchased coin transaction is credited only once', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KapiCosmeticsService();
    await store.load();

    expect(
      await store.claimPurchasedCoins(claimId: 'transaction-1', amount: 300),
      isTrue,
    );
    expect(
      await store.claimPurchasedCoins(claimId: 'transaction-1', amount: 300),
      isFalse,
    );
    expect(store.balance, KapiCosmeticsService.welcomeCoins + 300);

    final reloaded = KapiCosmeticsService();
    await reloaded.load();
    expect(reloaded.balance, KapiCosmeticsService.welcomeCoins + 300);
    expect(
      await reloaded.claimPurchasedCoins(claimId: 'transaction-1', amount: 300),
      isFalse,
    );
  });

  test('an invalid equipped id falls back within the same category', () async {
    SharedPreferences.setMockInitialValues({
      'kapi_cosmetics_welcome_v1': true,
      'kapi_cosmetics_equipped_domino': 'table_night',
    });
    final store = KapiCosmeticsService();
    await store.load();

    expect(
      store.equipped(KapiCosmeticType.domino).id,
      KapiCosmeticsService.defaultId(KapiCosmeticType.domino),
    );
  });

  test(
    'centerpieces are independent and the visible catalog stays neutral',
    () {
      final ids = KapiCosmeticsService.catalog.map((item) => item.id).toList();
      expect(ids.toSet().length, ids.length);

      const centerpieceIds = <String>{
        'centerpiece_none',
        'centerpiece_quisqueya_shield',
        'centerpiece_coqui',
        'centerpiece_plantain_party',
        'centerpiece_maracas',
        'centerpiece_golden_eagle',
        'centerpiece_tropical_coffee',
      };
      expect(ids, containsAll(centerpieceIds));

      final visibleTables =
          KapiCosmeticsService.catalog
              .where(
                (item) =>
                    item.type == KapiCosmeticType.table && item.storeVisible,
              )
              .map((item) => item.id)
              .toSet();
      expect(visibleTables, <String>{
        'table_classic',
        'table_night',
        'table_mahogany',
        'table_caribbean',
        'table_obsidian',
        'table_royal_velvet',
        'table_arctic_glass',
      });

      for (final id in <String>{
        'table_coqui',
        'table_plantain',
        'table_eagle',
        'table_agave',
      }) {
        expect(KapiCosmeticsService.byId(id).storeVisible, isFalse);
      }

      const premiumGeneratedIds = <String>{
        'table_obsidian',
        'table_royal_velvet',
        'table_arctic_glass',
        'avatar_midnight_strategist',
        'avatar_silver_tactician',
        'avatar_sunrise_champion',
      };
      final generatedItems = KapiCosmeticsService.catalog.where(
        (item) =>
            (centerpieceIds.contains(item.id) ||
                premiumGeneratedIds.contains(item.id)) &&
            item.previewAsset != null,
      );
      expect(generatedItems, isNotEmpty);
      for (final item in generatedItems) {
        expect(
          File(item.previewAsset!).existsSync(),
          isTrue,
          reason: 'Missing shop asset for ${item.id}: ${item.previewAsset}',
        );
      }

      const forbiddenAvatarLabels = <String>{
        'asian',
        'india',
        'spanish',
        'spain',
        'boricua',
        'mexico',
        'mexican',
        'caribbean',
        'dominican',
      };
      final visibleAvatars = KapiCosmeticsService.catalog.where(
        (item) => item.type == KapiCosmeticType.avatar && item.storeVisible,
      );
      final visibleDominoes = KapiCosmeticsService.catalog.where(
        (item) => item.type == KapiCosmeticType.domino && item.storeVisible,
      );
      final visibleFlags = KapiCosmeticsService.catalog.where(
        (item) => item.type == KapiCosmeticType.flag && item.storeVisible,
      );
      expect(visibleTables.length, greaterThanOrEqualTo(7));
      expect(visibleDominoes.length, greaterThanOrEqualTo(10));
      expect(visibleAvatars.length, greaterThanOrEqualTo(15));
      expect(visibleFlags.length, greaterThanOrEqualTo(30));
      for (final avatar in visibleAvatars) {
        final labels = '${avatar.nameEn} ${avatar.nameEs}'.toLowerCase();
        expect(
          forbiddenAvatarLabels.every((term) => !labels.contains(term)),
          isTrue,
          reason:
              'Avatar ${avatar.id} has a country or ethnicity label: $labels',
        );
        expect(
          DominoPlayerProfile.avatarAssetForKey(avatar.avatarKey!),
          avatar.previewAsset,
          reason: 'Avatar ${avatar.id} is not connected to its profile asset.',
        );
      }
    },
  );

  test('colored dice have distinct body and pip colors', () {
    final dice = KapiCosmeticsService.catalog.where(
      (item) => item.type == KapiCosmeticType.dice,
    );
    expect(dice.length, greaterThanOrEqualTo(7));
    expect(dice.every((item) => item.primary != item.secondary), isTrue);
    expect(
      dice.every((item) => !item.storeVisible),
      isTrue,
      reason:
          'Legacy dice assets must stay compatible but hidden from Kapi Shop.',
    );
  });

  test('table, centerpiece, avatar and dice persist independently', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KapiCosmeticsService();
    await store.load();
    for (var index = 0; index < 6; index += 1) {
      expect(await store.addTestCoins(), isTrue);
    }

    for (final id in <String>[
      'table_caribbean',
      'centerpiece_coqui',
      'avatar_caribbean_man',
      'dice_midnight_gold',
    ]) {
      final item = KapiCosmeticsService.byId(id);
      expect(await store.purchase(item), isTrue, reason: id);
      expect(await store.equip(item), isTrue, reason: id);
      expect(store.equipped(item.type).id, id);
    }

    final reloaded = KapiCosmeticsService();
    await reloaded.load();
    expect(reloaded.equipped(KapiCosmeticType.table).id, 'table_caribbean');
    expect(
      reloaded.equipped(KapiCosmeticType.centerpiece).id,
      'centerpiece_coqui',
    );
    expect(
      reloaded.equipped(KapiCosmeticType.avatar).id,
      'avatar_caribbean_man',
    );
    expect(reloaded.equipped(KapiCosmeticType.dice).id, 'dice_midnight_gold');

    final playerProfile = await DominoPlayerProfile.load();
    expect(playerProfile.avatarKey, 'caribbean_man');
    expect(
      DominoPlayerProfile.avatarAssetForKey(playerProfile.avatarKey),
      KapiCosmeticsService.byId('avatar_caribbean_man').previewAsset,
    );
  });

  test(
    'every visible shop item purchases, equips, switches and survives reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = KapiCosmeticsService();
      await store.load();

      final visibleItems = KapiCosmeticsService.catalog
          .where((item) => item.storeVisible)
          .toList(growable: false);
      final paidItems = visibleItems
          .where((item) => item.price > 0)
          .toList(growable: false);
      final totalPrice = paidItems.fold<int>(
        0,
        (total, item) => total + item.price,
      );
      const reserve = 1000;
      expect(
        await store.claimPurchasedCoins(
          claimId: 'complete-catalog-audit',
          amount: totalPrice + reserve,
        ),
        isTrue,
      );
      final fundedBalance = store.balance;
      final lastEquipped = <KapiCosmeticType, String>{};

      for (final item in visibleItems) {
        final beforePurchase = store.balance;
        if (item.price == 0) {
          expect(store.owns(item), isTrue, reason: item.id);
          expect(await store.purchase(item), isFalse, reason: item.id);
          expect(store.balance, beforePurchase, reason: item.id);
        } else {
          expect(store.owns(item), isFalse, reason: item.id);
          expect(await store.purchase(item), isTrue, reason: item.id);
          expect(store.owns(item), isTrue, reason: item.id);
          expect(
            store.balance,
            beforePurchase - item.price,
            reason: 'Incorrect price charged for ${item.id}',
          );

          final afterFirstPurchase = store.balance;
          expect(
            await store.purchase(item),
            isFalse,
            reason: 'A second purchase charged ${item.id} twice',
          );
          expect(store.balance, afterFirstPurchase, reason: item.id);
        }

        expect(await store.equip(item), isTrue, reason: item.id);
        expect(store.equipped(item.type).id, item.id, reason: item.id);
        lastEquipped[item.type] = item.id;

        if (item.type == KapiCosmeticType.avatar) {
          final profile = await DominoPlayerProfile.load();
          expect(profile.avatarKey, item.avatarKey, reason: item.id);
          expect(
            DominoPlayerProfile.avatarAssetForKey(profile.avatarKey),
            item.previewAsset,
            reason: 'Avatar profile did not update for ${item.id}',
          );
        }
      }

      expect(store.balance, fundedBalance - totalPrice);
      expect(store.balance, reserve + KapiCosmeticsService.welcomeCoins);

      for (final type in lastEquipped.keys) {
        final typeItems =
            visibleItems.where((item) => item.type == type).toList();
        expect(typeItems, isNotEmpty);
        expect(await store.equip(typeItems.first), isTrue, reason: type.name);
        expect(store.equipped(type).id, typeItems.first.id);
        expect(
          await store.equip(KapiCosmeticsService.byId(lastEquipped[type]!)),
          isTrue,
          reason: type.name,
        );
      }

      final reloaded = KapiCosmeticsService();
      await reloaded.load();
      expect(reloaded.balance, reserve + KapiCosmeticsService.welcomeCoins);
      for (final item in paidItems) {
        expect(reloaded.owns(item), isTrue, reason: item.id);
        final beforeDuplicate = reloaded.balance;
        expect(await reloaded.purchase(item), isFalse, reason: item.id);
        expect(reloaded.balance, beforeDuplicate, reason: item.id);
      }
      for (final entry in lastEquipped.entries) {
        expect(
          reloaded.equipped(entry.key).id,
          entry.value,
          reason: '${entry.key.name} did not persist',
        );
      }
    },
  );
}
