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
    this.displayName = '',
    required this.countryCode,
    required this.code,
    required this.avatarKey,
  });

  final String initials;
  final String displayName;
  final String countryCode;
  final String code;
  final String avatarKey;

  String get publicId => '$initials.${countryCode.trim().toUpperCase()}.$code';
  String get shortId => code;
  String get effectiveDisplayName {
    final normalized = normalizeDisplayName(displayName);
    return isValidDisplayName(normalized) ? normalized : initials;
  }

  String? get avatarAssetPath => avatarAssetForKey(avatarKey);

  static String? avatarAssetForKey(String key) => switch (key) {
    'person' => 'assets/kapi_shop/avatars/avatar_person.png',
    'woman' => 'assets/kapi_shop/avatars/avatar_woman.png',
    'robot' => 'assets/kapi_shop/avatars/avatar_robot.png',
    'game' => 'assets/kapi_shop/avatars/avatar_game.png',
    'star' => 'assets/kapi_shop/avatars/avatar_star.png',
    'caribbean_man' => 'assets/kapi_shop/avatars/avatar_caribbean_man.png',
    'boricua_woman' => 'assets/kapi_shop/avatars/avatar_boricua_woman.png',
    'mexico_man' => 'assets/kapi_shop/avatars/avatar_mexico_man.png',
    'asian_woman' => 'assets/kapi_shop/avatars/avatar_asian_woman.png',
    'india_man' => 'assets/kapi_shop/avatars/avatar_india_man.png',
    'spanish_woman' => 'assets/kapi_shop/avatars/avatar_spanish_woman.png',
    'android_emerald' => 'assets/kapi_shop/avatars/avatar_android_emerald.png',
    'midnight_strategist' =>
      'assets/kapi_shop/avatars/avatar_midnight_strategist.png',
    'silver_tactician' =>
      'assets/kapi_shop/avatars/avatar_silver_tactician.png',
    'sunrise_champion' =>
      'assets/kapi_shop/avatars/avatar_sunrise_champion.png',
    'pro_master' => 'assets/kapi_shop/avatars/avatar_pro_master.png',
    _ => null,
  };

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
      case 'caribbean_man':
        return Icons.wb_sunny_rounded;
      case 'boricua_woman':
        return Icons.local_florist_rounded;
      case 'mexico_man':
        return Icons.eco_rounded;
      case 'asian_woman':
        return Icons.diamond_rounded;
      case 'india_man':
        return Icons.auto_awesome_rounded;
      case 'spanish_woman':
        return Icons.local_florist_rounded;
      case 'android_emerald':
        return Icons.smart_toy_rounded;
      case 'midnight_strategist':
        return Icons.psychology_alt_rounded;
      case 'silver_tactician':
        return Icons.workspace_premium_rounded;
      case 'sunrise_champion':
        return Icons.emoji_events_rounded;
      case 'pro_master':
        return Icons.workspace_premium_rounded;
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
      case 'caribbean_man':
        return const Color(0xFF174B8B);
      case 'boricua_woman':
        return const Color(0xFFB23B58);
      case 'mexico_man':
        return const Color(0xFF116A4D);
      case 'asian_woman':
        return const Color(0xFF6A3AA8);
      case 'india_man':
        return const Color(0xFF7B2039);
      case 'spanish_woman':
        return const Color(0xFF9A2835);
      case 'android_emerald':
        return const Color(0xFF008A68);
      case 'midnight_strategist':
        return const Color(0xFF17365D);
      case 'silver_tactician':
        return const Color(0xFF287A78);
      case 'sunrise_champion':
        return const Color(0xFFE97832);
      case 'pro_master':
        return const Color(0xFFD6B56B);
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
    final savedDisplayName =
        prefs.getString('kapi_player_profile_display_name') ?? '';
    final normalizedDisplayName = normalizeDisplayName(savedDisplayName);
    final savedCountry = prefs.getString('kapi_player_profile_country') ?? 'US';
    final normalizedCountry = normalizeCountryCode(savedCountry);
    return DominoPlayerProfile(
      initials:
          (prefs.getString('kapi_player_profile_initials') ?? 'JP')
              .toUpperCase(),
      displayName:
          isValidDisplayName(normalizedDisplayName)
              ? normalizedDisplayName
              : '',
      countryCode: normalizedCountry,
      code: code,
      avatarKey: prefs.getString('kapi_player_profile_avatar') ?? 'person',
    );
  }

  Map<String, dynamic> toAccountMap() => {
    'initials': initials.toUpperCase(),
    'displayName':
        isValidDisplayName(displayName)
            ? normalizeDisplayName(displayName)
            : '',
    'countryCode': countryCode.trim().toUpperCase(),
    'code': code.toUpperCase(),
    'publicId': publicId.toUpperCase(),
    'avatarKey': avatarKey,
  };

  static DominoPlayerProfile? fromAccountMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final initials = (data['initials'] as String? ?? '').toUpperCase();
    final displayName = normalizeDisplayName(
      data['displayName'] as String? ?? '',
    );
    final country = normalizeCountryCode(data['countryCode'] as String? ?? '');
    final code = (data['code'] as String? ?? '').toUpperCase();
    final avatar = data['avatarKey'] as String? ?? 'person';
    if (initials.length != 2 || country.length != 2 || !_isValidCode(code)) {
      return null;
    }
    return DominoPlayerProfile(
      initials: initials,
      displayName: isValidDisplayName(displayName) ? displayName : '',
      countryCode: country,
      code: code,
      avatarKey: avatar,
    );
  }

  Future<void> saveLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'kapi_player_profile_initials',
      initials.toUpperCase(),
    );
    if (isValidDisplayName(displayName)) {
      await prefs.setString(
        'kapi_player_profile_display_name',
        normalizeDisplayName(displayName),
      );
    } else {
      await prefs.remove('kapi_player_profile_display_name');
    }
    await prefs.setString(
      'kapi_player_profile_country',
      countryCode.trim().toUpperCase(),
    );
    await prefs.setString('kapi_player_profile_code', code.toUpperCase());
    await prefs.setString('kapi_player_profile_avatar', avatarKey);
    await prefs.setBool('kapi_player_profile_saved', true);
  }

  static String normalizeDisplayName(String value) =>
      value.trim().replaceAll(RegExp(' +'), ' ');

  static bool isValidDisplayName(String value) {
    final normalized = normalizeDisplayName(value);
    if (normalized.length < 2 || normalized.length > 16) return false;
    return RegExp(
      r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-ž\u1E00-\u1EFF]+(?:[ '\u2019-][A-Za-zÀ-ÖØ-öø-ÿĀ-ž\u1E00-\u1EFF]+)*$",
    ).hasMatch(normalized);
  }

  static String initialsForDisplayName(String value) {
    final normalized = normalizeDisplayName(value);
    final words = normalized
        .split(RegExp(r"[ '\u2019-]+"))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final source =
        words.length >= 2
            ? '${words.first[0]}${words[1][0]}'
            : (words.isEmpty ? '' : words.first);
    final ascii = _latinLettersToAscii(
      source,
    ).replaceAll(RegExp('[^A-Za-z]'), '');
    if (ascii.length >= 2) return ascii.substring(0, 2).toUpperCase();
    return ascii.toUpperCase().padRight(2, 'X');
  }

  static String normalizeCountryCode(String value) {
    return value.trim().toUpperCase();
  }

  static String _latinLettersToAscii(String value) {
    var result = value;
    const replacements = <String, String>{
      'A': 'ÀÁÂÃÄÅĀĂĄǍǞǠǺȀȂẠẢẤẦẨẪẬẮẰẲẴẶ',
      'C': 'ÇĆĈĊČ',
      'D': 'ÐĎĐ',
      'E': 'ÈÉÊËĒĔĖĘĚȄȆẸẺẼẾỀỂỄỆ',
      'G': 'ĜĞĠĢǦ',
      'H': 'ĤĦ',
      'I': 'ÌÍÎÏĨĪĬĮİǏȈȊỊỈ',
      'J': 'Ĵ',
      'K': 'Ķ',
      'L': 'ĹĻĽĿŁ',
      'N': 'ÑŃŅŇŊǸ',
      'O': 'ÒÓÔÕÖØŌŎŐǑǪǬȌȎỌỎỐỒỔỖỘỚỜỞỠỢ',
      'R': 'ŔŖŘ',
      'S': 'ŚŜŞŠȘ',
      'T': 'ŢŤŦȚ',
      'U': 'ÙÚÛÜŨŪŬŮŰŲǓȔȖỤỦỨỪỬỮỰ',
      'W': 'ŴẀẂẄ',
      'Y': 'ÝŶŸỲỴỶỸ',
      'Z': 'ŹŻŽ',
    };
    for (final entry in replacements.entries) {
      for (final character in entry.value.split('')) {
        result = result.replaceAll(character, entry.key);
        result = result.replaceAll(
          character.toLowerCase(),
          entry.key.toLowerCase(),
        );
      }
    }
    return result;
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

class DominoAvatarVisual extends StatelessWidget {
  const DominoAvatarVisual({
    required this.avatarKey,
    required this.fallbackIcon,
    required this.backgroundColor,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String avatarKey;
  final IconData fallbackIcon;
  final Color backgroundColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final asset = DominoPlayerProfile.avatarAssetForKey(avatarKey);
    if (asset == null) {
      return ColoredBox(
        color: backgroundColor,
        child: Center(child: Icon(fallbackIcon, color: Colors.white)),
      );
    }
    return ColoredBox(
      color: backgroundColor,
      child: Image.asset(
        asset,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder:
            (_, _, _) => Center(child: Icon(fallbackIcon, color: Colors.white)),
      ),
    );
  }
}
