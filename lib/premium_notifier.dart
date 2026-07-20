import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef CoinPurchaseClaimer = Future<bool> Function(String claimId, int amount);

@immutable
class KapiCoinPack {
  const KapiCoinPack({
    required this.productId,
    required this.coins,
    required this.fallbackPrice,
    this.badgeEn,
    this.badgeEs,
  });

  final String productId;
  final int coins;
  final String fallbackPrice;
  final String? badgeEn;
  final String? badgeEs;
}

class PremiumNotifier extends ChangeNotifier {
  static const bool _screenshotProMode = bool.fromEnvironment(
    'KAPI_SCREENSHOT_PRO',
  );

  PremiumNotifier({CoinPurchaseClaimer? coinPurchaseClaimer})
    : _coinPurchaseClaimer = coinPurchaseClaimer {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  static const String monthlyProductId = 'kapi_premium_monthly';
  static const String yearlyProductId = 'kapi_premium_yearly';

  static const String iosMonthlyProductId = 'kapi_premium_monthly';
  static const String iosYearlyProductId = 'kapi_premium_yearly';

  static const List<KapiCoinPack> coinPacks = [
    KapiCoinPack(
      productId: 'kapi_coins_300',
      coins: 300,
      fallbackPrice: r'$1.99',
    ),
    KapiCoinPack(
      productId: 'kapi_coins_550',
      coins: 550,
      fallbackPrice: r'$2.99',
    ),
    KapiCoinPack(
      productId: 'kapi_coins_2000',
      coins: 2000,
      fallbackPrice: r'$9.99',
      badgeEn: 'POPULAR',
      badgeEs: 'POPULAR',
    ),
    KapiCoinPack(
      productId: 'kapi_coins_4500',
      coins: 4500,
      fallbackPrice: r'$19.99',
      badgeEn: 'BEST VALUE',
      badgeEs: 'MEJOR VALOR',
    ),
  ];

  static const Set<String> _premiumProductIds = {
    monthlyProductId,
    yearlyProductId,
  };
  static final Set<String> _coinProductIds =
      coinPacks.map((pack) => pack.productId).toSet();
  static final Set<String> _androidProductIds = {
    ..._premiumProductIds,
    ..._coinProductIds,
  };
  static final Set<String> _iosProductIds = {
    ..._premiumProductIds,
    ..._coinProductIds,
  };

  static const String _premiumKey = 'kapi_premium_enabled';
  static const String _premiumProductKey = 'kapi_premium_product_id';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final CoinPurchaseClaimer? _coinPurchaseClaimer;

  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  bool _isPremium = false;
  bool _isAvailable = false;
  bool _isLoading = false;
  bool _isReady = false;
  String? _activeProductId;
  String? _errorMessage;
  List<ProductDetails> _products = [];

  bool get isPremium => _isPremium;
  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get canBuyPremium => _isStoreSupported && _isAvailable;
  bool get canBuyCoins =>
      _isStoreSupported && _isAvailable && _coinPurchaseClaimer != null;
  bool get isStoreSupported => _isStoreSupported;
  String? get activeProductId => _activeProductId;
  String? get errorMessage => _errorMessage;
  List<ProductDetails> get products => List.unmodifiable(_products);
  List<ProductDetails> get coinProducts => List.unmodifiable(
    _products.where((item) => _coinProductIds.contains(item.id)),
  );

  String get currentMonthlyProductId =>
      Platform.isIOS ? iosMonthlyProductId : monthlyProductId;
  String get currentYearlyProductId =>
      Platform.isIOS ? iosYearlyProductId : yearlyProductId;

  ProductDetails? get monthlyProduct => _productById(currentMonthlyProductId);
  ProductDetails? get yearlyProduct => _productById(currentYearlyProductId);

  ProductDetails? productForCoinPack(KapiCoinPack pack) =>
      _productById(pack.productId);

  Future<void> loadPremium() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = _screenshotProMode || (prefs.getBool(_premiumKey) ?? false);
    _activeProductId =
        _screenshotProMode
            ? currentYearlyProductId
            : prefs.getString(_premiumProductKey);

    if (!_isStoreSupported) {
      _isReady = true;
      notifyListeners();
      return;
    }

    _isReady = false;
    _isLoading = true;
    notifyListeners();
    unawaited(loadProducts());
  }

  Future<void> loadProducts() async {
    if (!_isStoreSupported) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      if (!_isAvailable) {
        _isLoading = false;
        _isReady = true;
        notifyListeners();
        return;
      }

      final ids = _productIdsForCurrentPlatform;
      final response = await _inAppPurchase.queryProductDetails(ids);
      final order = [
        currentMonthlyProductId,
        currentYearlyProductId,
        ...coinPacks.map((pack) => pack.productId),
      ];
      _products =
          response.productDetails.toList()..sort((a, b) {
            final aIndex = order.indexOf(a.id);
            final bIndex = order.indexOf(b.id);
            return (aIndex == -1 ? 99 : aIndex).compareTo(
              bIndex == -1 ? 99 : bIndex,
            );
          });

      if (response.error != null) {
        _errorMessage = response.error!.message;
      } else if (response.notFoundIDs.isNotEmpty) {
        _errorMessage =
            'Products not found: ${response.notFoundIDs.join(', ')}';
      }
    } catch (error) {
      _errorMessage = 'Unable to load products: $error';
    } finally {
      _isLoading = false;
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (!_isStoreSupported) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!started) {
        _isLoading = false;
        _errorMessage = 'Purchase could not be started.';
        notifyListeners();
      }
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'Purchase could not be started: $error';
      notifyListeners();
    }
  }

  Future<bool> buyCoinPack(KapiCoinPack pack) async {
    if (!canBuyCoins) return false;
    final product = productForCoinPack(pack);
    if (product == null) {
      _errorMessage = 'This coin pack is not available in the store yet.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final started = await _inAppPurchase.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: true,
      );
      if (!started) {
        _isLoading = false;
        _errorMessage = 'Purchase could not be started.';
        notifyListeners();
      }
      return started;
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'Purchase could not be started: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_isStoreSupported) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _inAppPurchase.restorePurchases();
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'Restore could not be started: $error';
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  ProductDetails? _productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (!_knownProductIds.contains(purchaseDetails.productID)) continue;

      var shouldComplete = true;
      try {
        switch (purchaseDetails.status) {
          case PurchaseStatus.purchased:
            if (_coinProductIds.contains(purchaseDetails.productID)) {
              await _creditCoinPurchase(purchaseDetails);
            } else {
              await _enablePremium(purchaseDetails.productID);
            }
            break;
          case PurchaseStatus.restored:
            if (_premiumProductIds.contains(purchaseDetails.productID)) {
              await _enablePremium(purchaseDetails.productID);
            } else {
              _isLoading = false;
              notifyListeners();
            }
            break;
          case PurchaseStatus.error:
            _errorMessage = purchaseDetails.error?.message;
            _isLoading = false;
            notifyListeners();
            break;
          case PurchaseStatus.pending:
            _isLoading = true;
            notifyListeners();
            break;
          case PurchaseStatus.canceled:
            _isLoading = false;
            notifyListeners();
            break;
        }
      } catch (error) {
        shouldComplete = false;
        _isLoading = false;
        _errorMessage = 'The purchase could not be verified: $error';
        notifyListeners();
      }

      if (purchaseDetails.pendingCompletePurchase && shouldComplete) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _creditCoinPurchase(PurchaseDetails purchase) async {
    final pack = coinPacks.firstWhere(
      (item) => item.productId == purchase.productID,
    );
    final claimer = _coinPurchaseClaimer;
    if (claimer == null) throw StateError('Coin wallet is not connected.');

    final claimId = _stableClaimId(purchase);
    await claimer(claimId, pack.coins);
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  String _stableClaimId(PurchaseDetails purchase) {
    final purchaseId = purchase.purchaseID?.trim();
    if (purchaseId != null && purchaseId.isNotEmpty) {
      return '${purchase.productID}:$purchaseId';
    }

    final verification =
        purchase.verificationData.serverVerificationData.trim();
    if (verification.isNotEmpty) {
      final digest = sha256.convert(utf8.encode(verification));
      return '${purchase.productID}:$digest';
    }

    throw StateError('The store did not return a stable transaction ID.');
  }

  Future<void> _enablePremium(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setString(_premiumProductKey, productId);

    _isPremium = true;
    _activeProductId = productId;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  bool get _isStoreSupported => Platform.isAndroid || Platform.isIOS;

  Set<String> get _productIdsForCurrentPlatform =>
      Platform.isIOS ? _iosProductIds : _androidProductIds;

  Set<String> get _knownProductIds => {
    ..._androidProductIds,
    ..._iosProductIds,
  };

  @override
  void dispose() {
    _purchaseSubscription.cancel();
    super.dispose();
  }
}
