import 'package:dominoes_note2025/services/domino_match_mode.dart';
import 'package:dominoes_note2025/widgets/game_invitation_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('game invitation mode compatibility', () {
    test('legacy and explicit Block documents remain Block', () {
      expect(
        GameInvitationInboxLogic.modeFromData(const {}),
        DominoMatchMode.block,
      );
      expect(
        GameInvitationInboxLogic.modeFromData(const {'gameType': 'block'}),
        DominoMatchMode.block,
      );
      expect(
        GameInvitationInboxLogic.modeFromData(const {'mode': 'block'}),
        DominoMatchMode.block,
      );
    });

    test('draw_pool is preserved from mode or gameType', () {
      expect(
        GameInvitationInboxLogic.modeFromData(const {'mode': 'draw_pool'}),
        DominoMatchMode.drawPool,
      );
      expect(
        GameInvitationInboxLogic.modeFromData(const {'gameType': 'draw_pool'}),
        DominoMatchMode.drawPool,
      );
      expect(
        GameInvitationInboxLogic.modeFromData(const {
          'mode': 'block',
          'gameType': 'draw_pool',
        }),
        DominoMatchMode.drawPool,
      );
    });

    test('uses the correct visible game name', () {
      expect(GameInvitationInboxLogic.visibleGameName(const {}), 'Block');
      expect(
        GameInvitationInboxLogic.visibleGameName(const {'mode': 'draw_pool'}),
        'Draw / Pool',
      );
      expect(
        GameInvitationInboxLogic.visibleGameName(const {
          'gameType': 'teams2v2',
        }),
        'Teams 2 vs 2',
      );
    });
  });
}
