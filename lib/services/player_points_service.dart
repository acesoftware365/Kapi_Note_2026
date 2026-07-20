import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kapi_cosmetics_service.dart';

class PlayerPointsService {
  const PlayerPointsService._();

  static Future<int> loadLocalTotalPoints(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = code.toUpperCase();
    return prefs.getInt('kapi_player_points_${cleanCode}_total') ?? 0;
  }

  static Future<void> ensureProfileRegistered({
    required String code,
    required String publicId,
    required String initials,
    required String countryCode,
  }) async {
    final cleanCode = code.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'kapi_player_points_$cleanCode';
    final localPoints = prefs.getInt('${prefix}_total') ?? 0;
    final localRounds = prefs.getInt('${prefix}_rounds') ?? 0;
    final localWins = prefs.getInt('${prefix}_wins') ?? 0;
    final localLosses = prefs.getInt('${prefix}_losses') ?? 0;
    final localStreak = prefs.getInt('${prefix}_streak') ?? 0;

    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('kapi_player_points').doc(cleanCode);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final identity = <String, Object>{
          'code': cleanCode,
          'hashtag': '#$cleanCode',
          'publicId': publicId.toUpperCase(),
          'initials': initials.toUpperCase(),
          'countryCode': countryCode.toUpperCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (snapshot.exists) {
          transaction.set(ref, identity, SetOptions(merge: true));
          return;
        }
        transaction.set(ref, {
          ...identity,
          'lastMode': 'block',
          'totalPoints': localPoints,
          'roundsPlayed': localRounds,
          'roundsWon': localWins,
          'roundsLost': localLosses,
          'currentStreak': localStreak,
        });
      });
    } catch (_) {
      // The local profile still works while Firestore is unavailable.
    }
  }

  static Future<void> recordRound({
    required String code,
    required String publicId,
    required String initials,
    required String countryCode,
    required String mode,
    required int pointsEarned,
    required int playerScore,
    required int cpuScore,
    required bool wonRound,
    String? rewardKey,
  }) async {
    final cleanCode = code.toUpperCase();
    final hashtag = '#$cleanCode';
    await _recordLocal(
      code: cleanCode,
      pointsEarned: pointsEarned,
      playerScore: playerScore,
      cpuScore: cpuScore,
      wonRound: wonRound,
    );
    if (wonRound) {
      await KapiCosmeticsService.instance.claimVictory(rewardKey: rewardKey);
    }

    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('kapi_player_points').doc(cleanCode);
      await ref.set({
        'code': cleanCode,
        'hashtag': hashtag,
        'publicId': publicId.toUpperCase(),
        'initials': initials.toUpperCase(),
        'countryCode': countryCode.toUpperCase(),
        'lastMode': mode,
        'totalPoints': FieldValue.increment(pointsEarned),
        'roundsPlayed': FieldValue.increment(1),
        'roundsWon': FieldValue.increment(wonRound ? 1 : 0),
        'roundsLost': FieldValue.increment(wonRound ? 0 : 1),
        'currentStreak': wonRound ? FieldValue.increment(1) : 0,
        'lastRoundPoints': pointsEarned,
        'lastPlayerScore': playerScore,
        'lastCpuScore': cpuScore,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Local storage is the fallback; Firestore can sync on a future online pass.
    }
  }

  static Future<void> _recordLocal({
    required String code,
    required int pointsEarned,
    required int playerScore,
    required int cpuScore,
    required bool wonRound,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'kapi_player_points_$code';
    await prefs.setInt(
      '${prefix}_total',
      (prefs.getInt('${prefix}_total') ?? 0) + pointsEarned,
    );
    await prefs.setInt(
      '${prefix}_rounds',
      (prefs.getInt('${prefix}_rounds') ?? 0) + 1,
    );
    await prefs.setInt(
      '${prefix}_wins',
      (prefs.getInt('${prefix}_wins') ?? 0) + (wonRound ? 1 : 0),
    );
    await prefs.setInt(
      '${prefix}_losses',
      (prefs.getInt('${prefix}_losses') ?? 0) + (wonRound ? 0 : 1),
    );
    await prefs.setInt(
      '${prefix}_streak',
      wonRound ? (prefs.getInt('${prefix}_streak') ?? 0) + 1 : 0,
    );
    await prefs.setInt('${prefix}_last_round_points', pointsEarned);
    await prefs.setInt('${prefix}_last_player_score', playerScore);
    await prefs.setInt('${prefix}_last_cpu_score', cpuScore);
  }
}
