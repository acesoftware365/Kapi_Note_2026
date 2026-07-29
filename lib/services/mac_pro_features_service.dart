import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class MacProFeaturesService {
  MacProFeaturesService._();

  static final instance = MacProFeaturesService._();
  static const _targetScoreKey = 'kapi_mac_pro_custom_target_score';
  static const _eventRegistrationsKey = 'kapi_mac_pro_event_registrations';
  static const supportedTargetScores = <int>[30, 50, 100, 150];

  Future<int> targetScore() async {
    if (!Platform.isMacOS) return 100;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_targetScoreKey) ?? 100;
    return supportedTargetScores.contains(value) ? value : 100;
  }

  Future<void> setTargetScore(int value) async {
    if (!Platform.isMacOS || !supportedTargetScores.contains(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_targetScoreKey, value);
  }

  Future<Set<String>> eventRegistrations() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_eventRegistrationsKey) ?? const []).toSet();
  }

  Future<bool> toggleEventRegistration(String eventId) async {
    if (!Platform.isMacOS) return false;
    final prefs = await SharedPreferences.getInstance();
    final values = await eventRegistrations();
    final registered = values.add(eventId);
    if (!registered) values.remove(eventId);
    await prefs.setStringList(_eventRegistrationsKey, values.toList()..sort());
    return registered;
  }
}
