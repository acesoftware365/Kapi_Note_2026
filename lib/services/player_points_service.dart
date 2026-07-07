import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerPointsService {
  const PlayerPointsService._();

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
    await prefs.setInt('${prefix}_last_round_points', pointsEarned);
    await prefs.setInt('${prefix}_last_player_score', playerScore);
    await prefs.setInt('${prefix}_last_cpu_score', cpuScore);
  }
}
