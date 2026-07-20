import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  static Future<void> logAppOpen() {
    return analytics.logAppOpen();
  }

  static Future<void> logGameStarted() {
    return analytics.logEvent(name: 'game_started');
  }

  static Future<void> logGameCompleted({
    required String winningTeamName,
    required int teamATotal,
    required int teamBTotal,
    required int maxScore,
  }) {
    return analytics.logEvent(
      name: 'game_completed',
      parameters: {
        'winning_team': winningTeamName,
        'team_a_total': teamATotal,
        'team_b_total': teamBTotal,
        'max_score': maxScore,
      },
    );
  }

  static Future<void> logGameReset() {
    return analytics.logEvent(name: 'game_reset');
  }

  static Future<void> logDominoProfileSaved({
    required String countryCode,
    required String avatarKey,
    required String gameMode,
    required bool isFirstProfile,
    required bool isPremium,
  }) {
    return analytics.logEvent(
      name: 'domino_profile_saved',
      parameters: {
        'country_code': countryCode,
        'avatar_key': avatarKey,
        'game_mode': gameMode,
        'profile_action': isFirstProfile ? 'created' : 'edited',
        'is_premium': isPremium ? 1 : 0,
      },
    );
  }

  static Future<void> logDominoCpuGameStarted({
    required String gameMode,
    required String countryCode,
    required String avatarKey,
  }) {
    return analytics.logEvent(
      name: 'domino_cpu_game_started',
      parameters: {
        'game_mode': gameMode,
        'country_code': countryCode,
        'avatar_key': avatarKey,
      },
    );
  }
}
