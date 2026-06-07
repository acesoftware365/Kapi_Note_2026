// lib/team_name_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeamNameNotifier extends ChangeNotifier {
  String _teamAName = 'Team A';
  String _teamBName = 'Team B';

  static const String _teamANameKey = 'teamAName';
  static const String _teamBNameKey = 'teamBName';

  TeamNameNotifier() {
    loadTeamNames();
  }

  String get teamAName => _teamAName;
  String get teamBName => _teamBName;

  Future<void> loadTeamNames() async {
    final prefs = await SharedPreferences.getInstance();
    _teamAName = prefs.getString(_teamANameKey) ?? 'Team A';
    _teamBName = prefs.getString(_teamBNameKey) ?? 'Team B';
    notifyListeners();
  }

  Future<void> setTeamAName(String newName) async {
    if (_teamAName == newName) return;
    _teamAName = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teamANameKey, newName);
    notifyListeners();
  }

  Future<void> setTeamBName(String newName) async {
    if (_teamBName == newName) return;
    _teamBName = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teamBNameKey, newName);
    notifyListeners();
  }
}