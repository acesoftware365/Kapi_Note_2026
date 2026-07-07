import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LegalAcceptanceNotifier extends ChangeNotifier {
  static const String _acceptedKey = 'legal_terms_privacy_accepted';

  bool _hasAccepted = false;
  bool _isLoaded = false;

  bool get hasAccepted => _hasAccepted;
  bool get isLoaded => _isLoaded;

  Future<void> loadAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    _hasAccepted = prefs.getBool(_acceptedKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
    _hasAccepted = true;
    _isLoaded = true;
    notifyListeners();
  }
}
