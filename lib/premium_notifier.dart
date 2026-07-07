import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumNotifier extends ChangeNotifier {
  static const bool _screenshotProMode = bool.fromEnvironment(
    'KAPI_SCREENSHOT_PRO',
  );

  PremiumNotifier() {
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

  static const Set<String> _androidProductIds = {
    monthlyProductId,
    yearlyProductId,
  };
  static const Set<String> _iosProductIds = {
    iosMonthlyProductId,
    iosYearlyProductId,
  };

  static const String _premiumKey = 'kapi_premium_enabled';
  static const String _premiumProductKey = 'kapi_premium_product_id';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

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
  bool get isStoreSupported => _isStoreSupported;
  String? get activeProductId => _activeProductId;
  String? get errorMessage => _errorMessage;
  List<ProductDetails> get products => List.unmodifiable(_products);

  String get currentMonthlyProductId =>
      Platform.isIOS ? iosMonthlyProductId : monthlyProductId;
  String get currentYearlyProductId =>
      Platform.isIOS ? iosYearlyProductId : yearlyProductId;

  ProductDetails? get monthlyProduct => _productById(currentMonthlyProductId);
  ProductDetails? get yearlyProduct => _productById(currentYearlyProductId);

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
      _products =
          response.productDetails.toList()..sort((a, b) {
            final order = [currentMonthlyProductId, currentYearlyProductId];
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
      if (!_knownProductIds.contains(purchaseDetails.productID)) {
        continue;
      }

      switch (purchaseDetails.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _enablePremium(purchaseDetails.productID);
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

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
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
