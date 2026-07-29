import 'package:dominoes_note2025/screens/domino_player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DominoPlayerProfile display name', () {
    test('accepts public Latin names and derives legacy initials', () {
      expect(DominoPlayerProfile.isValidDisplayName('Juan'), isTrue);
      expect(DominoPlayerProfile.isValidDisplayName('María José'), isTrue);
      expect(DominoPlayerProfile.isValidDisplayName("D'Angelo"), isTrue);
      expect(DominoPlayerProfile.isValidDisplayName('Jean-Luc'), isTrue);
      expect(DominoPlayerProfile.initialsForDisplayName('María José'), 'MJ');
      expect(DominoPlayerProfile.initialsForDisplayName('Éloi'), 'EL');
      expect(DominoPlayerProfile.initialsForDisplayName('Jean-Luc'), 'JL');
    });

    test('rejects unsupported or out-of-range public names', () {
      expect(DominoPlayerProfile.isValidDisplayName('J'), isFalse);
      expect(
        DominoPlayerProfile.isValidDisplayName('NombreDemasiadoLargo'),
        isFalse,
      );
      expect(DominoPlayerProfile.isValidDisplayName('Juan_1'), isFalse);
      expect(DominoPlayerProfile.isValidDisplayName('Juan1'), isFalse);
      expect(DominoPlayerProfile.isValidDisplayName('Juan 😀'), isFalse);
      expect(DominoPlayerProfile.isValidDisplayName(' Juan  Pérez '), isTrue);
      expect(
        DominoPlayerProfile.normalizeDisplayName(' Juan  Pérez '),
        'Juan Pérez',
      );
    });

    test('accepts 16 characters and rejects 17 including separators', () {
      const sixteenLetters = 'abcdefghijklmnop';
      const seventeenLetters = 'abcdefghijklmnopq';
      const sixteenWithSeparators = 'Maria-Jose Lopez';
      const seventeenWithSeparators = 'Maria-Jose LopezX';

      expect(sixteenLetters.length, 16);
      expect(seventeenLetters.length, 17);
      expect(DominoPlayerProfile.isValidDisplayName(sixteenLetters), isTrue);
      expect(DominoPlayerProfile.isValidDisplayName(seventeenLetters), isFalse);

      expect(sixteenWithSeparators.length, 16);
      expect(seventeenWithSeparators.length, 17);
      expect(
        DominoPlayerProfile.isValidDisplayName(sixteenWithSeparators),
        isTrue,
      );
      expect(
        DominoPlayerProfile.isValidDisplayName(seventeenWithSeparators),
        isFalse,
      );
    });

    test('keeps the legacy Dominican public ID stable', () async {
      SharedPreferences.setMockInitialValues({
        'kapi_player_profile_initials': 'JP',
        'kapi_player_profile_country': 'DR',
        'kapi_player_profile_code': 'ABC123',
        'kapi_player_profile_avatar': 'person',
        'kapi_player_profile_saved': true,
      });

      final profile = await DominoPlayerProfile.load();
      final prefs = await SharedPreferences.getInstance();

      expect(profile.displayName, isEmpty);
      expect(profile.effectiveDisplayName, 'JP');
      expect(profile.countryCode, 'DR');
      expect(profile.publicId, 'JP.DR.ABC123');
      expect(prefs.getString('kapi_player_profile_country'), 'DR');
    });

    test(
      'round-trips display name through local and account storage',
      () async {
        SharedPreferences.setMockInitialValues({});
        const profile = DominoPlayerProfile(
          initials: 'MJ',
          displayName: 'María José',
          countryCode: 'DR',
          code: 'ABC123',
          avatarKey: 'woman',
        );

        await profile.saveLocally();
        final local = await DominoPlayerProfile.load();
        final account = DominoPlayerProfile.fromAccountMap(
          profile.toAccountMap(),
        );

        expect(local.displayName, 'María José');
        expect(local.effectiveDisplayName, 'María José');
        expect(local.countryCode, 'DR');
        expect(account, isNotNull);
        expect(account!.displayName, 'María José');
        expect(account.countryCode, 'DR');
        expect(account.publicId, 'MJ.DR.ABC123');
      },
    );

    test('recovers an old account map without displayName', () {
      final profile = DominoPlayerProfile.fromAccountMap({
        'initials': 'JP',
        'countryCode': 'US',
        'code': 'ABC123',
        'avatarKey': 'person',
      });

      expect(profile, isNotNull);
      expect(profile!.displayName, isEmpty);
      expect(profile.effectiveDisplayName, 'JP');
    });

    test('legacy account recovery clears another local display name', () async {
      SharedPreferences.setMockInitialValues({
        'kapi_player_profile_display_name': 'Juan',
      });
      const legacyUpdate = DominoPlayerProfile(
        initials: 'JP',
        countryCode: 'US',
        code: 'ABC123',
        avatarKey: 'robot',
      );

      await legacyUpdate.saveLocally();
      final profile = await DominoPlayerProfile.load();

      expect(profile.displayName, isEmpty);
      expect(profile.effectiveDisplayName, 'JP');
      expect(profile.avatarKey, 'robot');
    });
  });
}
