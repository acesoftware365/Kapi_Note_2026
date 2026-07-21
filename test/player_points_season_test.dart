import 'package:flutter_test/flutter_test.dart';
import 'package:dominoes_note2025/services/player_points_service.dart';

void main() {
  group('monthly player ranking seasons', () {
    test('uses a stable UTC year-month id', () {
      expect(
        PlayerPointsService.seasonIdFor(DateTime.utc(2026, 7, 21)),
        '2026-07',
      );
    });

    test('past months cross the year boundary correctly', () {
      expect(
        PlayerPointsService.previousSeasonIds(
          count: 3,
          now: DateTime.utc(2026, 1, 10),
        ),
        <String>['2025-12', '2025-11', '2025-10'],
      );
    });
  });
}
