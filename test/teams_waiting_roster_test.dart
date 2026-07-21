import 'package:flutter_test/flutter_test.dart';
import 'package:dominoes_note2025/services/teams_online_service.dart';

TeamsOnlinePlayer player(String id) => TeamsOnlinePlayer(
  id: id,
  initials: id.split('.').first,
  countryCode: 'US',
  avatarKey: 'person',
  points: 10,
  isCpu: false,
);

void main() {
  test('selected partner appears in the partner seat for both players', () {
    final host = player('MP.US.HOST01');
    final partner = player('MM.DO.PART01');
    final players = [host, partner];

    final hostView = TeamsOnlineRoster.relativeWaitingSeats(
      players: players,
      currentPlayerId: host.id,
      preferredPartnerId: partner.id,
    );
    final partnerView = TeamsOnlineRoster.relativeWaitingSeats(
      players: players,
      currentPlayerId: partner.id,
      preferredPartnerId: partner.id,
    );

    expect(hostView[0]?.id, host.id);
    expect(hostView[2]?.id, partner.id);
    expect(partnerView[0]?.id, partner.id);
    expect(partnerView[2]?.id, host.id);
    expect(hostView[1], isNull);
    expect(hostView[3], isNull);
  });
}
