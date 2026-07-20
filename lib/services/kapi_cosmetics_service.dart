import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/domino_player_profile.dart';
import 'player_account_service.dart';

enum KapiCosmeticType {
  table,
  centerpiece,
  domino,
  handTray,
  avatar,
  flag,
  dice,
}

class KapiCosmeticItem {
  const KapiCosmeticItem({
    required this.id,
    required this.type,
    required this.nameEs,
    required this.nameEn,
    required this.price,
    required this.primary,
    this.secondary = Colors.white,
    this.emoji = '',
    this.previewAsset,
    this.avatarKey,
    this.exclusive = false,
    this.storeVisible = true,
  });

  final String id;
  final KapiCosmeticType type;
  final String nameEs;
  final String nameEn;
  final int price;
  final Color primary;
  final Color secondary;
  final String emoji;
  final String? previewAsset;
  final String? avatarKey;
  final bool exclusive;
  final bool storeVisible;

  String nameFor(Locale locale) =>
      locale.languageCode == 'es' ? nameEs : nameEn;
}

class KapiCosmeticsService extends ChangeNotifier {
  KapiCosmeticsService();

  static final KapiCosmeticsService instance = KapiCosmeticsService();

  static const _balanceKey = 'kapi_cosmetics_balance_v1';
  static const _revisionKey = 'kapi_cosmetics_revision_v1';
  static const _welcomeKey = 'kapi_cosmetics_welcome_v1';
  static const _ownedKey = 'kapi_cosmetics_owned_v1';
  static const _claimsKey = 'kapi_cosmetics_reward_claims_v1';
  static const _equippedPrefix = 'kapi_cosmetics_equipped_';
  static const int welcomeCoins = 150;
  static const int winReward = 10;
  static const bool testCoinToolsEnabled =
      !kReleaseMode || bool.fromEnvironment('KAPI_TEST_COIN_TOOLS');

  static const List<KapiCosmeticItem> catalog = [
    KapiCosmeticItem(
      id: 'table_classic',
      type: KapiCosmeticType.table,
      nameEs: 'Mesa clásica',
      nameEn: 'Classic table',
      price: 0,
      primary: Color(0xFF064C3B),
      secondary: Color(0xFFFFD36B),
      emoji: '🟢',
      previewAsset: 'assets/kapi_shop/tables/table_classic.png',
    ),
    KapiCosmeticItem(
      id: 'table_night',
      type: KapiCosmeticType.table,
      nameEs: 'Noche azul',
      nameEn: 'Blue night',
      price: 300,
      primary: Color(0xFF12365A),
      secondary: Color(0xFF64B5F6),
      emoji: '🌌',
      previewAsset: 'assets/kapi_shop/tables/table_night.png',
    ),
    KapiCosmeticItem(
      id: 'table_mahogany',
      type: KapiCosmeticType.table,
      nameEs: 'Caoba',
      nameEn: 'Mahogany',
      price: 600,
      primary: Color(0xFF5A291D),
      secondary: Color(0xFFD7A35D),
      emoji: '🪵',
      previewAsset: 'assets/kapi_shop/tables/table_mahogany.png',
    ),
    KapiCosmeticItem(
      id: 'table_caribbean',
      type: KapiCosmeticType.table,
      nameEs: 'Caribe',
      nameEn: 'Caribbean',
      price: 1200,
      primary: Color(0xFF006D77),
      secondary: Color(0xFF83E5DB),
      emoji: '🌊',
      previewAsset: 'assets/kapi_shop/tables/table_caribbean.png',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'table_obsidian',
      type: KapiCosmeticType.table,
      nameEs: 'Club obsidiana',
      nameEn: 'Obsidian Club',
      price: 800,
      primary: Color(0xFF15171B),
      secondary: Color(0xFFD6B35A),
      emoji: '◼️',
      previewAsset: 'assets/kapi_shop/tables/table_obsidian.png',
    ),
    KapiCosmeticItem(
      id: 'table_royal_velvet',
      type: KapiCosmeticType.table,
      nameEs: 'Terciopelo real',
      nameEn: 'Royal Velvet',
      price: 1000,
      primary: Color(0xFF3B1769),
      secondary: Color(0xFFD8B96B),
      emoji: '👑',
      previewAsset: 'assets/kapi_shop/tables/table_royal_velvet.png',
    ),
    KapiCosmeticItem(
      id: 'table_arctic_glass',
      type: KapiCosmeticType.table,
      nameEs: 'Cristal ártico',
      nameEn: 'Arctic Glass',
      price: 1500,
      primary: Color(0xFFDCECF2),
      secondary: Color(0xFF5BD6E8),
      emoji: '❄️',
      previewAsset: 'assets/kapi_shop/tables/table_arctic_glass.png',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'table_coqui',
      type: KapiCosmeticType.table,
      nameEs: 'Coquí boricua',
      nameEn: 'Boricua coquí',
      price: 900,
      primary: Color(0xFF073F32),
      secondary: Color(0xFFD9B96E),
      emoji: '🐸',
      previewAsset: 'assets/kapi_shop/tables/table_coqui.png',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'table_plantain',
      type: KapiCosmeticType.table,
      nameEs: 'Plátano caribeño',
      nameEn: 'Caribbean plantain',
      price: 950,
      primary: Color(0xFF123F2B),
      secondary: Color(0xFFC28B55),
      emoji: '🌿',
      previewAsset: 'assets/kapi_shop/tables/table_plantain.png',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'table_eagle',
      type: KapiCosmeticType.table,
      nameEs: 'Águila americana',
      nameEn: 'American eagle',
      price: 1100,
      primary: Color(0xFF102747),
      secondary: Color(0xFFBFC7D1),
      emoji: '🦅',
      previewAsset: 'assets/kapi_shop/tables/table_eagle.png',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'table_agave',
      type: KapiCosmeticType.table,
      nameEs: 'Agave mexicano',
      nameEn: 'Mexican agave',
      price: 1500,
      primary: Color(0xFF073F32),
      secondary: Color(0xFFD2A248),
      emoji: '🌵',
      previewAsset: 'assets/kapi_shop/tables/table_agave.png',
      exclusive: true,
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'centerpiece_none',
      type: KapiCosmeticType.centerpiece,
      nameEs: 'Sin centro',
      nameEn: 'No centerpiece',
      price: 0,
      primary: Color(0xFF142433),
      secondary: Color(0xFFD9B96E),
      emoji: '—',
    ),
    KapiCosmeticItem(
      id: 'centerpiece_quisqueya_shield',
      type: KapiCosmeticType.centerpiece,
      nameEs: 'Escudo Quisqueya',
      nameEn: 'Quisqueya Shield',
      price: 650,
      primary: Color(0xFF173F79),
      secondary: Color(0xFFD9B96E),
      emoji: '🛡️',
      previewAsset:
          'assets/kapi_shop/centerpieces/centerpiece_quisqueya_shield.png',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'centerpiece_coqui',
      type: KapiCosmeticType.centerpiece,
      nameEs: 'Coquí de luna',
      nameEn: 'Moonlight Coquí',
      price: 500,
      primary: Color(0xFF075A45),
      secondary: Color(0xFF8DE3B6),
      emoji: '🐸',
      previewAsset: 'assets/kapi_shop/centerpieces/centerpiece_coqui.png',
    ),
    KapiCosmeticItem(
      id: 'centerpiece_plantain_party',
      type: KapiCosmeticType.centerpiece,
      nameEs: 'Fiesta de plátano',
      nameEn: 'Plantain Party',
      price: 550,
      primary: Color(0xFF31582D),
      secondary: Color(0xFFD8AA5A),
      emoji: '🍌',
      previewAsset:
          'assets/kapi_shop/centerpieces/centerpiece_plantain_party.png',
    ),
    KapiCosmeticItem(
      id: 'centerpiece_maracas',
      type: KapiCosmeticType.centerpiece,
      nameEs: 'Ritmo de fiesta',
      nameEn: 'Fiesta Rhythm',
      price: 450,
      primary: Color(0xFF9B2335),
      secondary: Color(0xFFF6C64D),
      emoji: '🪇',
      previewAsset: 'assets/kapi_shop/centerpieces/centerpiece_maracas.png',
    ),
    KapiCosmeticItem(
      id: 'centerpiece_golden_eagle',
      type: KapiCosmeticType.centerpiece,
      nameEs: 'Águila dorada',
      nameEn: 'Golden Eagle',
      price: 650,
      primary: Color(0xFF152D55),
      secondary: Color(0xFFE4C16A),
      emoji: '🦅',
      previewAsset:
          'assets/kapi_shop/centerpieces/centerpiece_golden_eagle.png',
    ),
    KapiCosmeticItem(
      id: 'centerpiece_tropical_coffee',
      type: KapiCosmeticType.centerpiece,
      nameEs: 'Café tropical',
      nameEn: 'Tropical Coffee',
      price: 500,
      primary: Color(0xFF4E2D1F),
      secondary: Color(0xFFD8A45A),
      emoji: '☕',
      previewAsset:
          'assets/kapi_shop/centerpieces/centerpiece_tropical_coffee.png',
    ),
    KapiCosmeticItem(
      id: 'domino_ivory',
      type: KapiCosmeticType.domino,
      nameEs: 'Marfil clásico',
      nameEn: 'Classic ivory',
      price: 0,
      primary: Color(0xFFFFF4D6),
      secondary: Color(0xFF191919),
      emoji: '🁫',
    ),
    KapiCosmeticItem(
      id: 'domino_midnight',
      type: KapiCosmeticType.domino,
      nameEs: 'Medianoche',
      nameEn: 'Midnight',
      price: 300,
      primary: Color(0xFF20252B),
      secondary: Color(0xFFF5F7FA),
      emoji: '⚫',
    ),
    KapiCosmeticItem(
      id: 'domino_sky',
      type: KapiCosmeticType.domino,
      nameEs: 'Azul cielo',
      nameEn: 'Sky blue',
      price: 550,
      primary: Color(0xFF1E88E5),
      secondary: Color(0xFFFFFFFF),
      emoji: '🔵',
    ),
    KapiCosmeticItem(
      id: 'domino_coral',
      type: KapiCosmeticType.domino,
      nameEs: 'Coral',
      nameEn: 'Coral',
      price: 1100,
      primary: Color(0xFFE74C3C),
      secondary: Color(0xFFFFFFFF),
      emoji: '🔴',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'domino_jade',
      type: KapiCosmeticType.domino,
      nameEs: 'Jade',
      nameEn: 'Jade',
      price: 450,
      primary: Color(0xFF167A57),
      secondary: Color(0xFFFFF4D6),
      emoji: '🟢',
    ),
    KapiCosmeticItem(
      id: 'domino_pearl',
      type: KapiCosmeticType.domino,
      nameEs: 'Perla',
      nameEn: 'Pearl',
      price: 650,
      primary: Color(0xFFF1EEE4),
      secondary: Color(0xFF162A44),
      emoji: '🦪',
    ),
    KapiCosmeticItem(
      id: 'domino_amethyst',
      type: KapiCosmeticType.domino,
      nameEs: 'Amatista',
      nameEn: 'Amethyst',
      price: 850,
      primary: Color(0xFF6B3FA0),
      secondary: Color(0xFFB8F3FF),
      emoji: '💜',
    ),
    KapiCosmeticItem(
      id: 'domino_rose_gold',
      type: KapiCosmeticType.domino,
      nameEs: 'Oro rosa',
      nameEn: 'Rose Gold',
      price: 1000,
      primary: Color(0xFFE3A19B),
      secondary: Color(0xFF40272B),
      emoji: '🌹',
    ),
    KapiCosmeticItem(
      id: 'domino_neon_lime',
      type: KapiCosmeticType.domino,
      nameEs: 'Lima neón',
      nameEn: 'Neon Lime',
      price: 1200,
      primary: Color(0xFF101410),
      secondary: Color(0xFFB7FF32),
      emoji: '⚡',
    ),
    KapiCosmeticItem(
      id: 'domino_obsidian_gold',
      type: KapiCosmeticType.domino,
      nameEs: 'Obsidiana dorada',
      nameEn: 'Obsidian Gold',
      price: 1600,
      primary: Color(0xFF111318),
      secondary: Color(0xFFFFD36B),
      emoji: '✨',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'tray_classic',
      type: KapiCosmeticType.handTray,
      nameEs: 'Panel clásico',
      nameEn: 'Classic tray',
      price: 0,
      primary: Color(0xFFD8C9AE),
      secondary: Color(0xFFD8B765),
      emoji: '▤',
    ),
    KapiCosmeticItem(
      id: 'tray_midnight',
      type: KapiCosmeticType.handTray,
      nameEs: 'Panel medianoche',
      nameEn: 'Midnight tray',
      price: 300,
      primary: Color(0xFF102D4A),
      secondary: Color(0xFF6CB6FF),
      emoji: '🌙',
    ),
    KapiCosmeticItem(
      id: 'tray_mahogany',
      type: KapiCosmeticType.handTray,
      nameEs: 'Panel caoba',
      nameEn: 'Mahogany tray',
      price: 500,
      primary: Color(0xFF5A241B),
      secondary: Color(0xFFE1B45B),
      emoji: '🪵',
    ),
    KapiCosmeticItem(
      id: 'tray_caribbean',
      type: KapiCosmeticType.handTray,
      nameEs: 'Panel caribe',
      nameEn: 'Caribbean tray',
      price: 750,
      primary: Color(0xFF005C64),
      secondary: Color(0xFF48D1C5),
      emoji: '🌊',
    ),
    KapiCosmeticItem(
      id: 'tray_royal',
      type: KapiCosmeticType.handTray,
      nameEs: 'Panel real',
      nameEn: 'Royal tray',
      price: 1100,
      primary: Color(0xFF3E1C66),
      secondary: Color(0xFFE9C66A),
      emoji: '👑',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'avatar_person',
      type: KapiCosmeticType.avatar,
      nameEs: 'Jugador',
      nameEn: 'Player',
      price: 0,
      primary: Color(0xFF1E88E5),
      emoji: '🙂',
      previewAsset: 'assets/kapi_shop/avatars/avatar_person.png',
      avatarKey: 'person',
    ),
    KapiCosmeticItem(
      id: 'avatar_woman',
      type: KapiCosmeticType.avatar,
      nameEs: 'Estrella',
      nameEn: 'Star player',
      price: 300,
      primary: Color(0xFFE91E63),
      emoji: '👩',
      previewAsset: 'assets/kapi_shop/avatars/avatar_woman.png',
      avatarKey: 'woman',
    ),
    KapiCosmeticItem(
      id: 'avatar_robot',
      type: KapiCosmeticType.avatar,
      nameEs: 'Robot',
      nameEn: 'Robot',
      price: 450,
      primary: Color(0xFF26C6DA),
      emoji: '🤖',
      previewAsset: 'assets/kapi_shop/avatars/avatar_robot.png',
      avatarKey: 'robot',
    ),
    KapiCosmeticItem(
      id: 'avatar_game',
      type: KapiCosmeticType.avatar,
      nameEs: 'Gamer',
      nameEn: 'Gamer',
      price: 700,
      primary: Color(0xFF43A047),
      emoji: '🎮',
      previewAsset: 'assets/kapi_shop/avatars/avatar_game.png',
      avatarKey: 'game',
    ),
    KapiCosmeticItem(
      id: 'avatar_star',
      type: KapiCosmeticType.avatar,
      nameEs: 'Campeón',
      nameEn: 'Champion',
      price: 1400,
      primary: Color(0xFFFFB300),
      emoji: '⭐',
      previewAsset: 'assets/kapi_shop/avatars/avatar_star.png',
      avatarKey: 'star',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'avatar_caribbean_man',
      type: KapiCosmeticType.avatar,
      nameEs: 'Campeón dorado',
      nameEn: 'Golden Champion',
      price: 500,
      primary: Color(0xFF174B8B),
      secondary: Color(0xFFD9B96E),
      emoji: '🏆',
      previewAsset: 'assets/kapi_shop/avatars/avatar_caribbean_man.png',
      avatarKey: 'caribbean_man',
    ),
    KapiCosmeticItem(
      id: 'avatar_boricua_woman',
      type: KapiCosmeticType.avatar,
      nameEs: 'As carmesí',
      nameEn: 'Crimson Ace',
      price: 600,
      primary: Color(0xFFB23B58),
      secondary: Color(0xFFD9B96E),
      emoji: '♦️',
      previewAsset: 'assets/kapi_shop/avatars/avatar_boricua_woman.png',
      avatarKey: 'boricua_woman',
    ),
    KapiCosmeticItem(
      id: 'avatar_mexico_man',
      type: KapiCosmeticType.avatar,
      nameEs: 'Táctico verde',
      nameEn: 'Green Tactician',
      price: 700,
      primary: Color(0xFF116A4D),
      secondary: Color(0xFFD9B96E),
      emoji: '🎯',
      previewAsset: 'assets/kapi_shop/avatars/avatar_mexico_man.png',
      avatarKey: 'mexico_man',
    ),
    KapiCosmeticItem(
      id: 'avatar_asian_woman',
      type: KapiCosmeticType.avatar,
      nameEs: 'As violeta',
      nameEn: 'Violet Ace',
      price: 800,
      primary: Color(0xFF6A3AA8),
      secondary: Color(0xFFD9B96E),
      emoji: '💜',
      previewAsset: 'assets/kapi_shop/avatars/avatar_asian_woman.png',
      avatarKey: 'asian_woman',
    ),
    KapiCosmeticItem(
      id: 'avatar_india_man',
      type: KapiCosmeticType.avatar,
      nameEs: 'Caballero rubí',
      nameEn: 'Ruby Gentleman',
      price: 900,
      primary: Color(0xFF7B2039),
      secondary: Color(0xFFD9B96E),
      emoji: '♟️',
      previewAsset: 'assets/kapi_shop/avatars/avatar_india_man.png',
      avatarKey: 'india_man',
    ),
    KapiCosmeticItem(
      id: 'avatar_spanish_woman',
      type: KapiCosmeticType.avatar,
      nameEs: 'Campeona escarlata',
      nameEn: 'Scarlet Champion',
      price: 1000,
      primary: Color(0xFF9A2835),
      secondary: Color(0xFFD9B96E),
      emoji: '🌟',
      previewAsset: 'assets/kapi_shop/avatars/avatar_spanish_woman.png',
      avatarKey: 'spanish_woman',
    ),
    KapiCosmeticItem(
      id: 'avatar_android_emerald',
      type: KapiCosmeticType.avatar,
      nameEs: 'Androide esmeralda',
      nameEn: 'Emerald Android',
      price: 1600,
      primary: Color(0xFF008A68),
      secondary: Color(0xFFD9B96E),
      emoji: '🤖',
      previewAsset: 'assets/kapi_shop/avatars/avatar_android_emerald.png',
      avatarKey: 'android_emerald',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'avatar_midnight_strategist',
      type: KapiCosmeticType.avatar,
      nameEs: 'Estratega nocturna',
      nameEn: 'Midnight Strategist',
      price: 950,
      primary: Color(0xFF132342),
      secondary: Color(0xFFD9B96E),
      emoji: '♟️',
      previewAsset: 'assets/kapi_shop/avatars/avatar_midnight_strategist.png',
      avatarKey: 'midnight_strategist',
    ),
    KapiCosmeticItem(
      id: 'avatar_silver_tactician',
      type: KapiCosmeticType.avatar,
      nameEs: 'Táctico plateado',
      nameEn: 'Silver Tactician',
      price: 1050,
      primary: Color(0xFF315F66),
      secondary: Color(0xFFC7D1D6),
      emoji: '🧠',
      previewAsset: 'assets/kapi_shop/avatars/avatar_silver_tactician.png',
      avatarKey: 'silver_tactician',
    ),
    KapiCosmeticItem(
      id: 'avatar_sunrise_champion',
      type: KapiCosmeticType.avatar,
      nameEs: 'Campeón del alba',
      nameEn: 'Sunrise Champion',
      price: 1150,
      primary: Color(0xFFD96F2E),
      secondary: Color(0xFFFFE0A0),
      emoji: '🏆',
      previewAsset: 'assets/kapi_shop/avatars/avatar_sunrise_champion.png',
      avatarKey: 'sunrise_champion',
      exclusive: true,
    ),
    KapiCosmeticItem(
      id: 'flag_none',
      type: KapiCosmeticType.flag,
      nameEs: 'Sin insignia',
      nameEn: 'No badge',
      price: 0,
      primary: Color(0xFF607D8B),
      emoji: '➖',
    ),
    KapiCosmeticItem(
      id: 'flag_do',
      type: KapiCosmeticType.flag,
      nameEs: 'Rep. Dominicana',
      nameEn: 'Dominican Republic',
      price: 350,
      primary: Color(0xFFCE1126),
      secondary: Color(0xFF002D62),
      emoji: '🇩🇴',
    ),
    KapiCosmeticItem(
      id: 'flag_us',
      type: KapiCosmeticType.flag,
      nameEs: 'Estados Unidos',
      nameEn: 'United States',
      price: 350,
      primary: Color(0xFFB22234),
      secondary: Color(0xFF3C3B6E),
      emoji: '🇺🇸',
    ),
    KapiCosmeticItem(
      id: 'flag_pr',
      type: KapiCosmeticType.flag,
      nameEs: 'Puerto Rico',
      nameEn: 'Puerto Rico',
      price: 350,
      primary: Color(0xFFED0000),
      secondary: Color(0xFF0050F0),
      emoji: '🇵🇷',
    ),
    KapiCosmeticItem(
      id: 'flag_mx',
      type: KapiCosmeticType.flag,
      nameEs: 'México',
      nameEn: 'Mexico',
      price: 350,
      primary: Color(0xFF006847),
      secondary: Color(0xFFCE1126),
      emoji: '🇲🇽',
    ),
    KapiCosmeticItem(
      id: 'flag_co',
      type: KapiCosmeticType.flag,
      nameEs: 'Colombia',
      nameEn: 'Colombia',
      price: 350,
      primary: Color(0xFFFCD116),
      secondary: Color(0xFF003893),
      emoji: '🇨🇴',
    ),
    KapiCosmeticItem(
      id: 'flag_ve',
      type: KapiCosmeticType.flag,
      nameEs: 'Venezuela',
      nameEn: 'Venezuela',
      price: 350,
      primary: Color(0xFFFFCC00),
      secondary: Color(0xFF00247D),
      emoji: '🇻🇪',
    ),
    KapiCosmeticItem(
      id: 'flag_cu',
      type: KapiCosmeticType.flag,
      nameEs: 'Cuba',
      nameEn: 'Cuba',
      price: 350,
      primary: Color(0xFF002A8F),
      secondary: Color(0xFFCF142B),
      emoji: '🇨🇺',
    ),
    KapiCosmeticItem(
      id: 'flag_es',
      type: KapiCosmeticType.flag,
      nameEs: 'España',
      nameEn: 'Spain',
      price: 350,
      primary: Color(0xFFAA151B),
      secondary: Color(0xFFF1BF00),
      emoji: '🇪🇸',
    ),
    KapiCosmeticItem(
      id: 'flag_pa',
      type: KapiCosmeticType.flag,
      nameEs: 'Panamá',
      nameEn: 'Panama',
      price: 350,
      primary: Color(0xFF005293),
      secondary: Color(0xFFD21034),
      emoji: '🇵🇦',
    ),
    KapiCosmeticItem(
      id: 'flag_br',
      type: KapiCosmeticType.flag,
      nameEs: 'Brasil',
      nameEn: 'Brazil',
      price: 350,
      primary: Color(0xFF009C3B),
      secondary: Color(0xFFFFDF00),
      emoji: '🇧🇷',
    ),
    KapiCosmeticItem(
      id: 'flag_jm',
      type: KapiCosmeticType.flag,
      nameEs: 'Jamaica',
      nameEn: 'Jamaica',
      price: 350,
      primary: Color(0xFF009B3A),
      secondary: Color(0xFFFED100),
      emoji: '🇯🇲',
    ),
    KapiCosmeticItem(
      id: 'flag_ht',
      type: KapiCosmeticType.flag,
      nameEs: 'Haití',
      nameEn: 'Haiti',
      price: 350,
      primary: Color(0xFF00209F),
      secondary: Color(0xFFD21034),
      emoji: '🇭🇹',
    ),
    KapiCosmeticItem(
      id: 'flag_in',
      type: KapiCosmeticType.flag,
      nameEs: 'India',
      nameEn: 'India',
      price: 350,
      primary: Color(0xFFFF9933),
      secondary: Color(0xFF138808),
      emoji: '🇮🇳',
    ),
    KapiCosmeticItem(
      id: 'flag_jp',
      type: KapiCosmeticType.flag,
      nameEs: 'Japón',
      nameEn: 'Japan',
      price: 350,
      primary: Color(0xFFBC002D),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇯🇵',
    ),
    KapiCosmeticItem(
      id: 'flag_kr',
      type: KapiCosmeticType.flag,
      nameEs: 'Corea del Sur',
      nameEn: 'South Korea',
      price: 350,
      primary: Color(0xFFCD2E3A),
      secondary: Color(0xFF0047A0),
      emoji: '🇰🇷',
    ),
    KapiCosmeticItem(
      id: 'flag_ca',
      type: KapiCosmeticType.flag,
      nameEs: 'Canadá',
      nameEn: 'Canada',
      price: 350,
      primary: Color(0xFFFF0000),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇨🇦',
    ),
    KapiCosmeticItem(
      id: 'flag_ar',
      type: KapiCosmeticType.flag,
      nameEs: 'Argentina',
      nameEn: 'Argentina',
      price: 350,
      primary: Color(0xFF74ACDF),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇦🇷',
    ),
    KapiCosmeticItem(
      id: 'flag_cl',
      type: KapiCosmeticType.flag,
      nameEs: 'Chile',
      nameEn: 'Chile',
      price: 350,
      primary: Color(0xFFD52B1E),
      secondary: Color(0xFF0039A6),
      emoji: '🇨🇱',
    ),
    KapiCosmeticItem(
      id: 'flag_pe',
      type: KapiCosmeticType.flag,
      nameEs: 'Perú',
      nameEn: 'Peru',
      price: 350,
      primary: Color(0xFFD91023),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇵🇪',
    ),
    KapiCosmeticItem(
      id: 'flag_ec',
      type: KapiCosmeticType.flag,
      nameEs: 'Ecuador',
      nameEn: 'Ecuador',
      price: 350,
      primary: Color(0xFFFFDD00),
      secondary: Color(0xFF034EA2),
      emoji: '🇪🇨',
    ),
    KapiCosmeticItem(
      id: 'flag_cr',
      type: KapiCosmeticType.flag,
      nameEs: 'Costa Rica',
      nameEn: 'Costa Rica',
      price: 350,
      primary: Color(0xFFCE1126),
      secondary: Color(0xFF002B7F),
      emoji: '🇨🇷',
    ),
    KapiCosmeticItem(
      id: 'flag_gt',
      type: KapiCosmeticType.flag,
      nameEs: 'Guatemala',
      nameEn: 'Guatemala',
      price: 350,
      primary: Color(0xFF4997D0),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇬🇹',
    ),
    KapiCosmeticItem(
      id: 'flag_hn',
      type: KapiCosmeticType.flag,
      nameEs: 'Honduras',
      nameEn: 'Honduras',
      price: 350,
      primary: Color(0xFF00BCE4),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇭🇳',
    ),
    KapiCosmeticItem(
      id: 'flag_sv',
      type: KapiCosmeticType.flag,
      nameEs: 'El Salvador',
      nameEn: 'El Salvador',
      price: 350,
      primary: Color(0xFF0F47AF),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇸🇻',
    ),
    KapiCosmeticItem(
      id: 'flag_ni',
      type: KapiCosmeticType.flag,
      nameEs: 'Nicaragua',
      nameEn: 'Nicaragua',
      price: 350,
      primary: Color(0xFF0067C6),
      secondary: Color(0xFFFFFFFF),
      emoji: '🇳🇮',
    ),
    KapiCosmeticItem(
      id: 'flag_pt',
      type: KapiCosmeticType.flag,
      nameEs: 'Portugal',
      nameEn: 'Portugal',
      price: 350,
      primary: Color(0xFF046A38),
      secondary: Color(0xFFDA291C),
      emoji: '🇵🇹',
    ),
    KapiCosmeticItem(
      id: 'flag_it',
      type: KapiCosmeticType.flag,
      nameEs: 'Italia',
      nameEn: 'Italy',
      price: 350,
      primary: Color(0xFF009246),
      secondary: Color(0xFFCE2B37),
      emoji: '🇮🇹',
    ),
    KapiCosmeticItem(
      id: 'flag_fr',
      type: KapiCosmeticType.flag,
      nameEs: 'Francia',
      nameEn: 'France',
      price: 350,
      primary: Color(0xFF0055A4),
      secondary: Color(0xFFEF4135),
      emoji: '🇫🇷',
    ),
    KapiCosmeticItem(
      id: 'flag_de',
      type: KapiCosmeticType.flag,
      nameEs: 'Alemania',
      nameEn: 'Germany',
      price: 350,
      primary: Color(0xFF000000),
      secondary: Color(0xFFFFCE00),
      emoji: '🇩🇪',
    ),
    KapiCosmeticItem(
      id: 'flag_ph',
      type: KapiCosmeticType.flag,
      nameEs: 'Filipinas',
      nameEn: 'Philippines',
      price: 350,
      primary: Color(0xFF0038A8),
      secondary: Color(0xFFCE1126),
      emoji: '🇵🇭',
    ),
    KapiCosmeticItem(
      id: 'flag_gb',
      type: KapiCosmeticType.flag,
      nameEs: 'Reino Unido',
      nameEn: 'United Kingdom',
      price: 350,
      primary: Color(0xFF012169),
      secondary: Color(0xFFC8102E),
      emoji: '🇬🇧',
    ),
    KapiCosmeticItem(
      id: 'dice_classic',
      type: KapiCosmeticType.dice,
      nameEs: 'Dado clásico',
      nameEn: 'Classic die',
      price: 0,
      primary: Color(0xFFFFF4D6),
      secondary: Color(0xFF191919),
      emoji: '🎲',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'dice_gold',
      type: KapiCosmeticType.dice,
      nameEs: 'Dado dorado',
      nameEn: 'Golden die',
      price: 1000,
      primary: Color(0xFFFFC107),
      secondary: Color(0xFF3E2A00),
      emoji: '✨',
      exclusive: true,
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'dice_midnight_gold',
      type: KapiCosmeticType.dice,
      nameEs: 'Medianoche dorada',
      nameEn: 'Golden midnight',
      price: 350,
      primary: Color(0xFF101A2A),
      secondary: Color(0xFFFFD36B),
      emoji: '🌙',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'dice_caribbean',
      type: KapiCosmeticType.dice,
      nameEs: 'Turquesa Caribe',
      nameEn: 'Caribbean teal',
      price: 500,
      primary: Color(0xFF008C91),
      secondary: Color(0xFFFFFFFF),
      emoji: '🌊',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'dice_ruby',
      type: KapiCosmeticType.dice,
      nameEs: 'Rubí marfil',
      nameEn: 'Ivory ruby',
      price: 700,
      primary: Color(0xFFB3263B),
      secondary: Color(0xFFFFE8B5),
      emoji: '♦️',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'dice_amethyst',
      type: KapiCosmeticType.dice,
      nameEs: 'Amatista neón',
      nameEn: 'Neon amethyst',
      price: 900,
      primary: Color(0xFF5B2D91),
      secondary: Color(0xFF64F4FF),
      emoji: '💜',
      storeVisible: false,
    ),
    KapiCosmeticItem(
      id: 'dice_sun_blue',
      type: KapiCosmeticType.dice,
      nameEs: 'Sol azul',
      nameEn: 'Blue sun',
      price: 1300,
      primary: Color(0xFFF4C542),
      secondary: Color(0xFF123E8A),
      emoji: '☀️',
      exclusive: true,
      storeVisible: false,
    ),
  ];

  bool _loaded = false;
  int _balance = 0;
  int _revision = 0;
  Set<String> _owned = <String>{};
  Set<String> _claims = <String>{};
  final Map<KapiCosmeticType, String> _equipped = {};

  bool get loaded => _loaded;
  int get balance => _balance;
  int get revision => _revision;
  Set<String> get owned => Set.unmodifiable(_owned);

  static String defaultId(KapiCosmeticType type) => switch (type) {
    KapiCosmeticType.table => 'table_classic',
    KapiCosmeticType.centerpiece => 'centerpiece_none',
    KapiCosmeticType.domino => 'domino_ivory',
    KapiCosmeticType.handTray => 'tray_classic',
    KapiCosmeticType.avatar => 'avatar_person',
    KapiCosmeticType.flag => 'flag_none',
    KapiCosmeticType.dice => 'dice_classic',
  };

  static KapiCosmeticItem byId(String id) =>
      catalog.firstWhere((item) => item.id == id, orElse: () => catalog.first);

  KapiCosmeticItem equipped(KapiCosmeticType type) {
    final id = _equipped[type] ?? defaultId(type);
    return catalog.firstWhere(
      (item) => item.id == id && item.type == type,
      orElse: () => catalog.firstWhere((item) => item.id == defaultId(type)),
    );
  }

  bool owns(KapiCosmeticItem item) =>
      item.price == 0 || _owned.contains(item.id);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getInt(_balanceKey) ?? 0;
    _revision = prefs.getInt(_revisionKey) ?? 0;
    if (!(prefs.getBool(_welcomeKey) ?? false)) {
      _balance += welcomeCoins;
      _revision += 1;
      await prefs.setBool(_welcomeKey, true);
    }
    _owned = (prefs.getStringList(_ownedKey) ?? const <String>[]).toSet();
    _claims = (prefs.getStringList(_claimsKey) ?? const <String>[]).toSet();
    for (final type in KapiCosmeticType.values) {
      final selected = prefs.getString('$_equippedPrefix${type.name}');
      _equipped[type] = selected ?? defaultId(type);
    }
    _loaded = true;
    await _persist();
    notifyListeners();
    unawaited(_mergeRemote());
  }

  /// Connects the local wallet to the account that just signed in.
  ///
  /// A recovered account must win over unrelated coins left on this device.
  /// A newly protected account keeps the wallet that was earned locally.
  Future<void> connectAuthenticatedAccount({required bool recovered}) async {
    if (!_loaded) await load();
    await _mergeRemote(preferRemote: recovered);
  }

  Future<bool> purchase(KapiCosmeticItem item) async {
    if (!_loaded || owns(item) || _balance < item.price) return false;
    _balance -= item.price;
    _owned.add(item.id);
    _bumpRevision();
    await _persist();
    notifyListeners();
    unawaited(_syncRemote());
    return true;
  }

  Future<bool> equip(KapiCosmeticItem item) async {
    if (!_loaded || !owns(item)) return false;
    if (_equipped[item.type] == item.id) return true;
    _equipped[item.type] = item.id;
    _bumpRevision();
    await _persist();
    if (item.type == KapiCosmeticType.avatar && item.avatarKey != null) {
      final profile = await DominoPlayerProfile.load();
      final updated = DominoPlayerProfile(
        initials: profile.initials,
        countryCode: profile.countryCode,
        code: profile.code,
        avatarKey: item.avatarKey!,
      );
      await updated.saveLocally();
      if (Firebase.apps.isNotEmpty) {
        unawaited(PlayerAccountService.instance.syncCurrentProfile());
      }
    }
    notifyListeners();
    unawaited(_syncRemote());
    return true;
  }

  Future<bool> claimVictory({String? rewardKey}) async {
    if (!_loaded) await load();
    final key = rewardKey?.trim();
    if (key != null && key.isNotEmpty && !_claims.add(key)) return false;
    _balance += winReward;
    _bumpRevision();
    await _persist();
    notifyListeners();
    unawaited(_syncRemote());
    return true;
  }

  Future<bool> claimPurchasedCoins({
    required String claimId,
    required int amount,
  }) async {
    final cleanClaimId = claimId.trim();
    if (cleanClaimId.isEmpty || amount <= 0) return false;
    if (!_loaded) await load();
    final key = 'iap:$cleanClaimId';
    if (!_claims.add(key)) return false;
    _balance += amount;
    _bumpRevision();
    await _persist();
    notifyListeners();
    unawaited(_syncRemote());
    return true;
  }

  Future<bool> addTestCoins([int amount = 500]) async {
    if (!testCoinToolsEnabled || amount <= 0) return false;
    if (!_loaded) await load();
    _balance += amount;
    _bumpRevision();
    await _persist();
    notifyListeners();
    unawaited(_syncRemote());
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_balanceKey, _balance);
    await prefs.setInt(_revisionKey, _revision);
    await prefs.setStringList(_ownedKey, _owned.toList()..sort());
    await prefs.setStringList(_claimsKey, _claims.toList()..sort());
    for (final entry in _equipped.entries) {
      await prefs.setString('$_equippedPrefix${entry.key.name}', entry.value);
    }
  }

  Map<String, dynamic> toMap() => {
    'balance': _balance,
    'revision': _revision,
    'owned': _owned.toList()..sort(),
    'rewardClaims': _claims.toList()..sort(),
    'equipped': {
      for (final entry in _equipped.entries) entry.key.name: entry.value,
    },
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Future<void> _mergeRemote({bool preferRemote = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      final ref = FirebaseFirestore.instance
          .collection(PlayerAccountService.collection)
          .doc(user.uid);
      final snapshot = await ref.get();
      final remote = Map<String, dynamic>.from(
        snapshot.data()?['cosmetics'] as Map? ?? const {},
      );
      if (remote.isEmpty) {
        await _syncRemote();
        return;
      }
      final remoteRevision = (remote['revision'] as num? ?? 0).toInt();
      if (!preferRemote && remoteRevision <= _revision) {
        await _syncRemote();
        return;
      }

      _revision = remoteRevision;
      _balance = (remote['balance'] as num? ?? 0).toInt().clamp(0, 1 << 31);
      final validIds = catalog.map((item) => item.id).toSet();
      _owned =
          (remote['owned'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .where(validIds.contains)
              .toSet();
      _claims =
          (remote['rewardClaims'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toSet();
      final selected = Map<String, dynamic>.from(
        remote['equipped'] as Map? ?? const {},
      );
      for (final type in KapiCosmeticType.values) {
        final id = selected[type.name] as String?;
        final validItem = catalog.where(
          (item) => item.id == id && item.type == type,
        );
        if (validItem.isNotEmpty && owns(validItem.first)) {
          _equipped[type] = validItem.first.id;
        } else {
          _equipped[type] = defaultId(type);
        }
      }
      await _persist();
      notifyListeners();
    } catch (_) {
      // The local wallet remains available while the network is offline.
    }
  }

  Future<void> _syncRemote() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      await FirebaseFirestore.instance
          .collection(PlayerAccountService.collection)
          .doc(user.uid)
          .set({'cosmetics': toMap()}, SetOptions(merge: true));
    } catch (_) {
      // A future load will retry synchronization.
    }
  }

  void _bumpRevision() {
    _revision += 1;
  }
}
