// lib/locale_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for shared_preferences

class LocaleNotifier extends ChangeNotifier {
  Locale _locale = const Locale('es'); // Default to Spanish
  static const String _localeKey = 'appLocale';

  LocaleNotifier() {
    loadLocale(); // Load locale when notifier is created (now public)
  }

  Locale get locale => _locale;

  Future<void> loadLocale() async { // Made public by removing '_'
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString(_localeKey);
    if (languageCode != null) {
      _locale = Locale(languageCode);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, newLocale.languageCode);
    notifyListeners();
  }
}
