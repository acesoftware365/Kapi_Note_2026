import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

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
    Locale('en'),
    Locale('es'),
    Locale('it'),
    Locale('pt'),
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
  /// **'Welcome to Domino Scorer!'**
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
  /// **'About This App'**
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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'it', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
