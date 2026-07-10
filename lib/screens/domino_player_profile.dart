import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DominoPlayerTier { unranked, iron, bronze, silver, gold, platinum }

class DominoTierVisual {
  const DominoTierVisual({
    required this.tier,
    required this.label,
    required this.accent,
    required this.deep,
    required this.icon,
    required this.level,
    required this.glow,
  });

  final DominoPlayerTier tier;
  final String label;
  final Color accent;
  final Color deep;
  final IconData icon;
  final int level;
  final double glow;

  bool get isRanked => tier != DominoPlayerTier.unranked;

  Color frameColor({bool active = false}) {
    if (!isRanked) return Colors.white.withValues(alpha: active ? 0.38 : 0.18);
    return accent.withValues(alpha: active ? 1 : 0.78);
  }

  Color avatarBackground(Color baseColor) {
    if (!isRanked) return baseColor;
    return Color.lerp(baseColor, deep, 0.42) ?? baseColor;
  }

  List<BoxShadow> shadows({bool active = false}) {
    if (!isRanked && !active) return const [];
    return [
      BoxShadow(
        color: (active ? const Color(0xFFFFD36B) : accent).withValues(
          alpha: isRanked ? 0.30 : 0.16,
        ),
        blurRadius: active ? 18 : glow,
        spreadRadius: active ? 1 : 0,
      ),
    ];
  }

  static DominoTierVisual fromScore(int score, {bool ranked = true}) {
    if (!ranked) return forTier(DominoPlayerTier.unranked);
    if (score >= 900) return forTier(DominoPlayerTier.platinum);
    if (score >= 500) return forTier(DominoPlayerTier.gold);
    if (score >= 250) return forTier(DominoPlayerTier.silver);
    if (score >= 100) return forTier(DominoPlayerTier.bronze);
    return forTier(DominoPlayerTier.iron);
  }

  static DominoTierVisual forLabel(String label) {
    switch (label.toLowerCase()) {
      case 'platinum':
        return forTier(DominoPlayerTier.platinum);
      case 'gold':
        return forTier(DominoPlayerTier.gold);
      case 'silver':
        return forTier(DominoPlayerTier.silver);
      case 'bronze':
        return forTier(DominoPlayerTier.bronze);
      case 'iron':
        return forTier(DominoPlayerTier.iron);
      default:
        return forTier(DominoPlayerTier.unranked);
    }
  }

  static DominoTierVisual forTier(DominoPlayerTier tier) {
    switch (tier) {
      case DominoPlayerTier.platinum:
        return const DominoTierVisual(
          tier: DominoPlayerTier.platinum,
          label: 'Platinum',
          accent: Color(0xFFBFE8FF),
          deep: Color(0xFF2D4154),
          icon: Icons.diamond_rounded,
          level: 5,
          glow: 22,
        );
      case DominoPlayerTier.gold:
        return const DominoTierVisual(
          tier: DominoPlayerTier.gold,
          label: 'Gold',
          accent: Color(0xFFFFD36B),
          deep: Color(0xFF6B4A13),
          icon: Icons.workspace_premium_rounded,
          level: 4,
          glow: 16,
        );
      case DominoPlayerTier.silver:
        return const DominoTierVisual(
          tier: DominoPlayerTier.silver,
          label: 'Silver',
          accent: Color(0xFFC9D4E5),
          deep: Color(0xFF3D4756),
          icon: Icons.shield_rounded,
          level: 3,
          glow: 11,
        );
      case DominoPlayerTier.bronze:
        return const DominoTierVisual(
          tier: DominoPlayerTier.bronze,
          label: 'Bronze',
          accent: Color(0xFFC28B62),
          deep: Color(0xFF5B3828),
          icon: Icons.military_tech_rounded,
          level: 2,
          glow: 8,
        );
      case DominoPlayerTier.iron:
        return const DominoTierVisual(
          tier: DominoPlayerTier.iron,
          label: 'Iron',
          accent: Color(0xFF8A8F93),
          deep: Color(0xFF252A2E),
          icon: Icons.shield_rounded,
          level: 1,
          glow: 5,
        );
      case DominoPlayerTier.unranked:
        return const DominoTierVisual(
          tier: DominoPlayerTier.unranked,
          label: 'Unranked',
          accent: Color(0xFFA7B0B8),
          deep: Color(0xFF252A2E),
          icon: Icons.remove_moderator_rounded,
          level: 0,
          glow: 0,
        );
    }
  }
}

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
        return const Color(0xFFC28B62);
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
