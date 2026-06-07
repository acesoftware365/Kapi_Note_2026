// lib/font_size_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeNotifier extends ChangeNotifier {
  double _fontSizeScale = 1.0; // Default scale: 1.0 (medium)
  double _scoreFontSizeScale = 1.0; // Score scale
  static const String _fontSizeKey = 'fontSizeScale';
  static const String _scoreFontSizeKey = 'scoreFontSizeScale';

  FontSizeNotifier() {
    loadFontSize();
  }

  double get fontSizeScale => _fontSizeScale;
  double get scoreFontSizeScale => _scoreFontSizeScale;

  Future<void> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSizeScale = prefs.getDouble(_fontSizeKey) ?? 1.0;
    _scoreFontSizeScale = prefs.getDouble(_scoreFontSizeKey) ?? 1.0;
    notifyListeners();
  }

  Future<void> setFontSizeScale(double newScale) async {
    if (_fontSizeScale == newScale) return;
    _fontSizeScale = newScale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newScale);
    notifyListeners();
  }

  Future<void> setScoreFontSizeScale(double newScale) async {
    if (_scoreFontSizeScale == newScale) return;
    _scoreFontSizeScale = newScale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scoreFontSizeKey, newScale);
    notifyListeners();
  }
}
