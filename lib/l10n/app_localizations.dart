import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('pt'),
    Locale('ru'),
    Locale('ur'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Domino Scorer'**
  String get appTitle;

  /// No description provided for @homeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Domino Scorer Home'**
  String get homeScreenTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kapi Note!'**
  String get welcomeMessage;

  /// No description provided for @homeScreenDescription.
  ///
  /// In en, this message translates to:
  /// **'This is where you can start scoring your domino players.'**
  String get homeScreenDescription;

  /// No description provided for @startGameButton.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGameButton;

  /// No description provided for @settingsButton.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsButton;

  /// No description provided for @settingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreenTitle;

  /// No description provided for @settingsOptions.
  ///
  /// In en, this message translates to:
  /// **'Settings Options'**
  String get settingsOptions;

  /// No description provided for @manageProfile.
  ///
  /// In en, this message translates to:
  /// **'Manage Profile'**
  String get manageProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemTheme;

  /// No description provided for @aboutScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'About And Privacy'**
  String get aboutScreenTitle;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'This app does not share or use your personal data.'**
  String get aboutPrivacy;

  /// No description provided for @aboutEnjoy.
  ///
  /// In en, this message translates to:
  /// **'I hope you like it.'**
  String get aboutEnjoy;

  /// No description provided for @aboutHobby.
  ///
  /// In en, this message translates to:
  /// **'I programmed it as a hobby.'**
  String get aboutHobby;

  /// No description provided for @aboutPurpose.
  ///
  /// In en, this message translates to:
  /// **'Its purpose is to keep a record of domino scores.'**
  String get aboutPurpose;

  /// No description provided for @gameScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Domino Game'**
  String get gameScreenTitle;

  /// No description provided for @teamA.
  ///
  /// In en, this message translates to:
  /// **'Team A'**
  String get teamA;

  /// No description provided for @teamB.
  ///
  /// In en, this message translates to:
  /// **'Team B'**
  String get teamB;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @addBonus.
  ///
  /// In en, this message translates to:
  /// **'Add Bonus'**
  String get addBonus;

  /// No description provided for @enterBonusPoints.
  ///
  /// In en, this message translates to:
  /// **'Enter Bonus Points'**
  String get enterBonusPoints;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @enterPoints.
  ///
  /// In en, this message translates to:
  /// **'Enter Points'**
  String get enterPoints;

  /// No description provided for @resetGame.
  ///
  /// In en, this message translates to:
  /// **'Reset Game'**
  String get resetGame;

  /// No description provided for @maxScoreSetting.
  ///
  /// In en, this message translates to:
  /// **'Max Score'**
  String get maxScoreSetting;

  /// No description provided for @defaultBonusSetting.
  ///
  /// In en, this message translates to:
  /// **'Default Bonus'**
  String get defaultBonusSetting;

  /// No description provided for @fireworksScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Over!'**
  String get fireworksScreenTitle;

  /// No description provided for @maxScoreReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! Max score reached!'**
  String get maxScoreReachedMessage;

  /// No description provided for @bonusPointsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bonus Points'**
  String get bonusPointsLabel;

  /// No description provided for @fontSizeSetting.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSizeSetting;

  /// No description provided for @smallFont.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get smallFont;

  /// No description provided for @mediumFont.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get mediumFont;

  /// No description provided for @largeFont.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get largeFont;

  /// No description provided for @changeTeamName.
  ///
  /// In en, this message translates to:
  /// **'Change Team Name'**
  String get changeTeamName;

  /// No description provided for @enterNewTeamName.
  ///
  /// In en, this message translates to:
  /// **'Enter New Team Name'**
  String get enterNewTeamName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @bothTeams.
  ///
  /// In en, this message translates to:
  /// **'Both Teams'**
  String get bothTeams;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy Overview'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is important to us. Our mobile app is designed to respect your personal data. We do not store, sell, or share your personal data outside of your device. Any personal information stays securely on your phone and is used only to improve your experience with the app.\n\nHowever, we do use Google Analytics to understand general app usage and performance. This helps us improve the app, but it may involve Google collecting some usage data (such as device type, session duration, or features used). This data is anonymized where possible and is never used to personally identify you by us.\n\nWe also use Google Ads to show relevant advertisements within the app. Google may use device information and ad interaction data to personalize ads, depending on your device settings and preferences.\n\nWe do not sell or directly share your personal information with any third parties. All data collected through these services is handled by Google according to their privacy policies.\n\nFor more information:'**
  String get privacyPolicyDescription;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy Link'**
  String get privacyPolicyLink;

  /// No description provided for @privacyGoogleLink.
  ///
  /// In en, this message translates to:
  /// **'Google’s Privacy Policy'**
  String get privacyGoogleLink;

  /// No description provided for @privacyGoogleUseDataInApps.
  ///
  /// In en, this message translates to:
  /// **'How Google uses data in apps'**
  String get privacyGoogleUseDataInApps;

  /// No description provided for @aboutThisApp.
  ///
  /// In en, this message translates to:
  /// **'About the App\n\nThis tool was developed with a focus on simplicity and functionality. I created it as a personal project because, like you, I\'m passionate about dominoes and wanted an easier way to keep track of my scores.\n\nIts main purpose is to serve as a reliable system for scorekeeping, eliminating the need for paper and pencil. It was designed to be intuitive, allowing you to manage your games quickly and effortlessly. I appreciate your feedback for future improvements.'**
  String get aboutThisApp;

  /// No description provided for @noMoreThan200.
  ///
  /// In en, this message translates to:
  /// **'Massimo 200 punti'**
  String get noMoreThan200;

  /// No description provided for @shareAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Kapi Note — the easy way to track your domino points.\nWeb: https://liisgo.com/#/apps/KapiNote\nAndroid: https://play.google.com/store/apps/details?id=com.liisgo.kapi.note&hl=en_US\niOS: https://apps.apple.com/us/app/kapi-note/id6752557170'**
  String get shareAppMessage;

  /// No description provided for @shareAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Share the app'**
  String get shareAppTitle;

  /// No description provided for @shareAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Text / WhatsApp'**
  String get shareAppSubtitle;

  /// No description provided for @confirmEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish?'**
  String get confirmEndTitle;

  /// No description provided for @confirmEndMessage.
  ///
  /// In en, this message translates to:
  /// **'Max score reached.'**
  String get confirmEndMessage;

  /// No description provided for @confirmEndOk.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get confirmEndOk;

  /// No description provided for @scoreSizeSetting.
  ///
  /// In en, this message translates to:
  /// **'Score Size'**
  String get scoreSizeSetting;

  /// No description provided for @forceUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get forceUpdateTitle;

  /// No description provided for @forceUpdateMessage.
  ///
  /// In en, this message translates to:
  /// **'A new version is required to continue.'**
  String get forceUpdateMessage;

  /// No description provided for @forceUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get forceUpdateButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bn',
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'pt',
    'ru',
    'ur',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'ur':
      return AppLocalizationsUr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
