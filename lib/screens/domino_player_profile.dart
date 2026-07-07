import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DominoPlayerProfile {
  const DominoPlayerProfile({
    required this.initials,
    required this.countryCode,
    required this.code,
    required this.avatarKey,
  });

  final String initials;
  final String countryCode;
  final String code;
  final String avatarKey;

  String get publicId => '$initials.$countryCode.$code';
  String get shortId => code;

  IconData get icon {
    switch (avatarKey) {
      case 'woman':
        return Icons.face_3_rounded;
      case 'robot':
        return Icons.smart_toy_rounded;
      case 'rainbow':
        return Icons.auto_awesome_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'person':
      default:
        return Icons.person_rounded;
    }
  }

  Color get color {
    switch (avatarKey) {
      case 'woman':
        return const Color(0xFFE91E63);
      case 'robot':
        return const Color(0xFF26C6DA);
      case 'rainbow':
        return const Color(0xFFAB47BC);
      case 'game':
        return const Color(0xFF43A047);
      case 'star':
        return const Color(0xFFFFB300);
      case 'person':
      default:
        return const Color(0xFF1E88E5);
    }
  }

  static Future<DominoPlayerProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('kapi_player_profile_code');
    final code =
        _isValidCode(savedCode)
            ? savedCode!.toUpperCase()
            : _generatePlayerCodeValue();
    if (savedCode == null || savedCode.toUpperCase() != code) {
      await prefs.setString('kapi_player_profile_code', code);
    }
    return DominoPlayerProfile(
      initials:
          (prefs.getString('kapi_player_profile_initials') ?? 'JP')
              .toUpperCase(),
      countryCode:
          (prefs.getString('kapi_player_profile_country') ?? 'US')
              .toUpperCase(),
      code: code,
      avatarKey: prefs.getString('kapi_player_profile_avatar') ?? 'person',
    );
  }

  static bool _isValidCode(String? value) {
    return value != null &&
        RegExp(r'^[A-NP-Z1-9]{6}$').hasMatch(value.toUpperCase());
  }

  static String _generatePlayerCodeValue() {
    const chars = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
