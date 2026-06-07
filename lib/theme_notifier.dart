// lib/theme_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for shared_preferences

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme
  static const String _themeModeKey = 'appThemeMode';

  ThemeNotifier() {
    loadThemeMode(); // Load theme mode when notifier is created (now public)
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> loadThemeMode() async { // Made public by removing '_'
    final prefs = await SharedPreferences.getInstance();
    final String? themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString != null) {
      _themeMode = ThemeMode.values.firstWhere(
            (e) => e.toString() == 'ThemeMode.$themeModeString',
        orElse: () => ThemeMode.system,
      );
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode newThemeMode) async {
    if (_themeMode == newThemeMode) return;
    _themeMode = newThemeMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, newThemeMode.name); // Use .name for enum string
    notifyListeners();
  }
}