import 'package:flutter/foundation.dart';

class LegalContent {
  static const String termsTitle = 'Terms & Conditions';
  static const String privacyTitle = 'Privacy Policy';

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static String get termsBody => _isIOS ? _iosTermsBody : _defaultTermsBody;
  static String get privacyBody =>
      _isIOS ? _iosPrivacyBody : _defaultPrivacyBody;

  static const String _defaultTermsBody = '''
By using Kapi Note, you agree to use the app responsibly and only for lawful personal entertainment, scorekeeping, and related domino game activities.

Kapi Note is provided as-is. We work hard to keep the app reliable, but we cannot guarantee that it will always be available, error-free, or fit every situation.

You are responsible for checking scores, game settings, and any information you enter in the app. Kapi Note is a helper tool and does not replace your own judgment during play.

Free features may include ads. Pro features may remove ads and unlock premium tools when a valid subscription is active through the App Store or Google Play.

Subscriptions, billing, cancellations, and refunds are handled by the store where you purchased Pro. If a subscription cannot be verified, the app may keep Free mode active until the store confirms access.

We may update the app, improve features, change available tools, or require updates to keep the app working safely.
''';

  static const String _iosTermsBody = '''
By using Kapi Note, you agree to use the app responsibly and only for lawful personal entertainment, scorekeeping, and related domino game activities.

Kapi Note is provided as-is. We work hard to keep the app reliable, but we cannot guarantee that it will always be available, error-free, or fit every situation.

You are responsible for checking scores, game settings, and any information you enter in the app. Kapi Note is a helper tool and does not replace your own judgment during play.

Free features may include ads. Pro features may remove ads and unlock premium tools when a valid subscription is active through the App Store.

Subscriptions, billing, cancellations, and refunds are handled by Apple through your App Store account. If a subscription cannot be verified, the app may keep Free mode active until the App Store confirms access.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

We may update the app, improve features, change available tools, or require updates to keep the app working safely.
''';

  static const String _defaultPrivacyBody = '''
Your privacy is important to us. Kapi Note is designed to respect your personal data and keep your scorekeeping experience simple.

The app may store preferences, game settings, scores, premium status, and legal acceptance locally on your device so the app can work correctly.

We use services such as Google Analytics, Google Mobile Ads, Firebase Remote Config, App Store / Google Play purchases, and app review tools where available. These services may process device, usage, purchase, ad interaction, or diagnostic data according to their own privacy policies.

We do not sell your personal information. We use app data to operate Kapi Note, improve the experience, support ads or Pro access, and keep the app working.

You can review Google privacy information from the About and Privacy screen in the app. Store purchase and subscription information is managed by Apple or Google depending on your device.
''';

  static const String _iosPrivacyBody = '''
Your privacy is important to us. Kapi Note is designed to respect your personal data and keep your scorekeeping experience simple.

The app may store preferences, game settings, scores, premium status, and legal acceptance locally on your device so the app can work correctly.

On iOS, Kapi Note uses Apple App Store purchases, app review tools, Firebase services, analytics, ads, and remote configuration where available. These services may process device, usage, purchase, ad interaction, or diagnostic data according to their own privacy policies.

We do not sell your personal information. We use app data to operate Kapi Note, improve the experience, support ads or Pro access, and keep the app working.

Store purchase and subscription information is managed by Apple through your App Store account.
''';
}
