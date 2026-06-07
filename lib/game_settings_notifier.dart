// lib/game_settings_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSettingsNotifier extends ChangeNotifier {
  int _maxScore = 100;
  int _defaultBonus = 10;

  static const String _maxScoreKey = 'maxScore';
  static const String _defaultBonusKey = 'defaultBonus';

  GameSettingsNotifier() {
    loadSettings();
  }

  int get maxScore => _maxScore;
  int get defaultBonus => _defaultBonus;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _maxScore = prefs.getInt(_maxScoreKey) ?? 100;
    _defaultBonus = prefs.getInt(_defaultBonusKey) ?? 10;
    notifyListeners();
  }

  Future<void> setMaxScore(int newMaxScore) async {
    if (_maxScore == newMaxScore) return;
    _maxScore = newMaxScore;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxScoreKey, newMaxScore);
    notifyListeners();
  }

  Future<void> setDefaultBonus(int newDefaultBonus) async {
    if (_defaultBonus == newDefaultBonus) return;
    _defaultBonus = newDefaultBonus;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultBonusKey, newDefaultBonus);
    notifyListeners();
  }
}