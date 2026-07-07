import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewPromptService {
  ReviewPromptService._();

  static const int _minimumCompletedGames = 3;
  static const String _completedGamesKey = 'review_completed_games';
  static const String _lastPromptedVersionKey = 'review_last_prompted_version';

  static final InAppReview _inAppReview = InAppReview.instance;

  static Future<void> recordCompletedGameAndMaybeRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    final completedGames = (prefs.getInt(_completedGamesKey) ?? 0) + 1;
    await prefs.setInt(_completedGamesKey, completedGames);

    if (completedGames < _minimumCompletedGames) {
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (prefs.getString(_lastPromptedVersionKey) == currentVersion) {
      return;
    }

    final isAvailable = await _inAppReview.isAvailable();
    if (!isAvailable) {
      return;
    }

    await _inAppReview.requestReview();
    await prefs.setString(_lastPromptedVersionKey, currentVersion);
  }
}
