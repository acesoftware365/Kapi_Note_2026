import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kapi_cosmetics_service.dart';

class PlayerPointsService {
  const PlayerPointsService._();

  static String seasonIdFor([DateTime? date]) {
    final value = (date ?? DateTime.now()).toUtc();
    return '${value.year}-${value.month.toString().padLeft(2, '0')}';
  }

  static List<String> previousSeasonIds({int count = 12, DateTime? now}) {
    final value = (now ?? DateTime.now()).toUtc();
    return List<String>.generate(count, (index) {
      final month = DateTime.utc(value.year, value.month - index - 1);
      return seasonIdFor(month);
    });
  }

  static DocumentReference<Map<String, dynamic>> _seasonPlayerRef(
    FirebaseFirestore db,
    String seasonId,
    String code,
  ) => db
      .collection('kapi_ranking_seasons')
      .doc(seasonId)
      .collection('players')
      .doc(code);

  static Future<void> _ensureLocalSeason(
    SharedPreferences prefs,
    String code,
  ) async {
    final prefix = 'kapi_player_points_$code';
    final seasonId = seasonIdFor();
    if (prefs.getString('${prefix}_season_id') == seasonId) return;
    await prefs.setString('${prefix}_season_id', seasonId);
    for (final suffix in <String>[
      'total',
      'rounds',
      'wins',
      'losses',
      'streak',
      'last_round_points',
      'last_player_score',
      'last_cpu_score',
    ]) {
      await prefs.setInt('${prefix}_$suffix', 0);
    }
  }

  static Future<int> loadLocalTotalPoints(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = code.toUpperCase();
    await _ensureLocalSeason(prefs, cleanCode);
    return prefs.getInt('kapi_player_points_${cleanCode}_total') ?? 0;
  }

  static Future<int> applyAbandonmentPenalty({
    required String code,
    required String publicId,
    int penalty = 30,
  }) async {
    final cleanCode = code.toUpperCase();
    final cleanPublicId = publicId.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'kapi_player_points_$cleanCode';
    await _ensureLocalSeason(prefs, cleanCode);
    final updated = ((prefs.getInt('${prefix}_total') ?? 0) - penalty).clamp(
      0,
      1 << 30,
    );
    await prefs.setInt('${prefix}_total', updated);
    await prefs.setInt(
      '${prefix}_losses',
      (prefs.getInt('${prefix}_losses') ?? 0) + 1,
    );
    await prefs.setInt('${prefix}_streak', 0);
    await prefs.setInt('${prefix}_last_round_points', -penalty);
    try {
      final db = FirebaseFirestore.instance;
      final pointsRef = db.collection('kapi_player_points').doc(cleanCode);
      final seasonId = seasonIdFor();
      final seasonRef = _seasonPlayerRef(db, seasonId, cleanCode);
      final lobbyRef = db.collection('kapi_lobby_profiles').doc(cleanPublicId);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(seasonRef);
        final current =
            (snapshot.data()?['totalPoints'] as num?)?.toInt() ?? updated;
        final remoteUpdated = (current - penalty).clamp(0, 1 << 30);
        final changes = <String, Object>{
          'code': cleanCode,
          'publicId': cleanPublicId,
          'totalPoints': remoteUpdated,
          'roundsPlayed': FieldValue.increment(1),
          'roundsLost': FieldValue.increment(1),
          'currentStreak': 0,
          'lastRoundPoints': -penalty,
          'lastMode': 'teams_2v2_abandoned',
          'updatedAt': FieldValue.serverTimestamp(),
          'seasonId': seasonId,
        };
        transaction.set(seasonRef, changes, SetOptions(merge: true));
        transaction.set(pointsRef, changes, SetOptions(merge: true));
        transaction.set(lobbyRef, {
          'totalPoints': remoteUpdated,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // The local penalty remains authoritative until the next profile sync.
    }
    return updated;
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
    await _ensureLocalSeason(prefs, cleanCode);
    final localPoints = prefs.getInt('${prefix}_total') ?? 0;
    final localRounds = prefs.getInt('${prefix}_rounds') ?? 0;
    final localWins = prefs.getInt('${prefix}_wins') ?? 0;
    final localLosses = prefs.getInt('${prefix}_losses') ?? 0;
    final localStreak = prefs.getInt('${prefix}_streak') ?? 0;

    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('kapi_player_points').doc(cleanCode);
      final seasonId = seasonIdFor();
      final seasonRef = _seasonPlayerRef(db, seasonId, cleanCode);
      final seasonInfoRef = db.collection('kapi_ranking_seasons').doc(seasonId);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final seasonSnapshot = await transaction.get(seasonRef);
        final identity = <String, Object>{
          'code': cleanCode,
          'hashtag': '#$cleanCode',
          'publicId': publicId.toUpperCase(),
          'initials': initials.toUpperCase(),
          'countryCode': countryCode.toUpperCase(),
          'updatedAt': FieldValue.serverTimestamp(),
          'seasonId': seasonId,
        };
        final initialStats = <String, Object>{
          ...identity,
          'lastMode': 'block',
          'totalPoints': localPoints,
          'roundsPlayed': localRounds,
          'roundsWon': localWins,
          'roundsLost': localLosses,
          'currentStreak': localStreak,
        };
        final sameSeason = snapshot.data()?['seasonId'] == seasonId;
        transaction.set(
          ref,
          sameSeason ? identity : initialStats,
          SetOptions(merge: sameSeason),
        );
        transaction.set(
          seasonRef,
          seasonSnapshot.exists ? identity : initialStats,
          SetOptions(merge: seasonSnapshot.exists),
        );
        transaction.set(seasonInfoRef, {
          'seasonId': seasonId,
          'year': DateTime.now().toUtc().year,
          'month': DateTime.now().toUtc().month,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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
    bool awardCoins = false,
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
    if (wonRound && awardCoins) {
      await KapiCosmeticsService.instance.claimVictory(rewardKey: rewardKey);
    }

    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('kapi_player_points').doc(cleanCode);
      final seasonId = seasonIdFor();
      final seasonRef = _seasonPlayerRef(db, seasonId, cleanCode);
      final seasonInfoRef = db.collection('kapi_ranking_seasons').doc(seasonId);
      await db.runTransaction((transaction) async {
        final seasonSnapshot = await transaction.get(seasonRef);
        final seasonData = seasonSnapshot.data();
        final currentPoints =
            (seasonData?['totalPoints'] as num?)?.toInt() ?? 0;
        final currentRounds =
            (seasonData?['roundsPlayed'] as num?)?.toInt() ?? 0;
        final currentWins = (seasonData?['roundsWon'] as num?)?.toInt() ?? 0;
        final currentLosses = (seasonData?['roundsLost'] as num?)?.toInt() ?? 0;
        final currentStreak =
            (seasonData?['currentStreak'] as num?)?.toInt() ?? 0;
        final changes = <String, Object>{
          'code': cleanCode,
          'hashtag': hashtag,
          'publicId': publicId.toUpperCase(),
          'initials': initials.toUpperCase(),
          'countryCode': countryCode.toUpperCase(),
          'lastMode': mode,
          'totalPoints': (currentPoints + pointsEarned).clamp(0, 1 << 30),
          'roundsPlayed': currentRounds + 1,
          'roundsWon': currentWins + (wonRound ? 1 : 0),
          'roundsLost': currentLosses + (wonRound ? 0 : 1),
          'currentStreak': wonRound ? currentStreak + 1 : 0,
          'lastRoundPoints': pointsEarned,
          'lastPlayerScore': playerScore,
          'lastCpuScore': cpuScore,
          'updatedAt': FieldValue.serverTimestamp(),
          'seasonId': seasonId,
        };
        transaction.set(seasonRef, changes, SetOptions(merge: true));
        transaction.set(ref, changes, SetOptions(merge: true));
        transaction.set(seasonInfoRef, {
          'seasonId': seasonId,
          'year': DateTime.now().toUtc().year,
          'month': DateTime.now().toUtc().month,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
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
    await _ensureLocalSeason(prefs, code);
    final prefix = 'kapi_player_points_$code';
    await prefs.setInt(
      '${prefix}_total',
      ((prefs.getInt('${prefix}_total') ?? 0) + pointsEarned).clamp(0, 1 << 30),
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
