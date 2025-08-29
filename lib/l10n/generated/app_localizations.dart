import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('fr')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Arena'**
  String get appTitle;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Home screen title
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Arena section title
  ///
  /// In en, this message translates to:
  /// **'Arena'**
  String get arena;

  /// Debates and discussions section title
  ///
  /// In en, this message translates to:
  /// **'Debates & Discussions'**
  String get debates;

  /// Open discussion section title
  ///
  /// In en, this message translates to:
  /// **'Open Discussion'**
  String get openDiscussion;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Settings section title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Join button text
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// Create button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button text
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Send button text
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error indicator text
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Success indicator text
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Room name field label
  ///
  /// In en, this message translates to:
  /// **'Room Name'**
  String get roomName;

  /// Room description field label
  ///
  /// In en, this message translates to:
  /// **'Room Description'**
  String get roomDescription;

  /// Participants label
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// Participant count display
  ///
  /// In en, this message translates to:
  /// **'{count} participants'**
  String participantCount(int count);

  /// Speaking time label
  ///
  /// In en, this message translates to:
  /// **'Speaking Time'**
  String get speakingTime;

  /// Timer label
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// Start timer button text
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get startTimer;

  /// Pause timer button text
  ///
  /// In en, this message translates to:
  /// **'Pause Timer'**
  String get pauseTimer;

  /// Reset timer button text
  ///
  /// In en, this message translates to:
  /// **'Reset Timer'**
  String get resetTimer;

  /// Mute button text
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// Unmute button text
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// Raise hand button text
  ///
  /// In en, this message translates to:
  /// **'Raise Hand'**
  String get raiseHand;

  /// Lower hand button text
  ///
  /// In en, this message translates to:
  /// **'Lower Hand'**
  String get lowerHand;

  /// Chat label
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Chat input placeholder
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// Empty chat state message
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// Empty chat state encouragement
  ///
  /// In en, this message translates to:
  /// **'Be the first to send a message!'**
  String get beFirstToSend;

  /// Moderator role label
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderator;

  /// Speaker role label
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// Audience role label
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get audience;

  /// Judge role label
  ///
  /// In en, this message translates to:
  /// **'Judge'**
  String get judge;

  /// Affirmative side label
  ///
  /// In en, this message translates to:
  /// **'Affirmative'**
  String get affirmative;

  /// Negative side label
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get negative;

  /// Create room button text
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoom;

  /// Join room button text
  ///
  /// In en, this message translates to:
  /// **'Join Room'**
  String get joinRoom;

  /// Leave room button text
  ///
  /// In en, this message translates to:
  /// **'Leave Room'**
  String get leaveRoom;

  /// End room button text
  ///
  /// In en, this message translates to:
  /// **'End Room'**
  String get endRoom;

  /// Private room label
  ///
  /// In en, this message translates to:
  /// **'Private Room'**
  String get privateRoom;

  /// Public room label
  ///
  /// In en, this message translates to:
  /// **'Public Room'**
  String get publicRoom;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Incorrect password error message
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get incorrectPassword;

  /// Private room password prompt
  ///
  /// In en, this message translates to:
  /// **'This room requires a password to enter.'**
  String get roomRequiresPassword;

  /// Active discussions section title
  ///
  /// In en, this message translates to:
  /// **'Active Discussions'**
  String get activeDiscussions;

  /// Empty discussions state message
  ///
  /// In en, this message translates to:
  /// **'No active discussions'**
  String get noActiveDiscussions;

  /// Empty discussions state encouragement
  ///
  /// In en, this message translates to:
  /// **'Be the first to create a discussion room!'**
  String get beFirstToCreate;

  /// Available rooms count
  ///
  /// In en, this message translates to:
  /// **'{count} rooms available'**
  String roomsAvailable(int count);

  /// Dark mode setting label
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Notifications setting label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Accessibility settings section
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// Large text accessibility option
  ///
  /// In en, this message translates to:
  /// **'Large Text'**
  String get largeText;

  /// High contrast accessibility option
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get highContrast;

  /// Screen reader support option
  ///
  /// In en, this message translates to:
  /// **'Screen Reader Support'**
  String get screenReader;

  /// Connection status label
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatus;

  /// Connected status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Disconnected status
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Reconnecting status
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get reconnecting;

  /// Offline status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// Retry connection button text
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnection;
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
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

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
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
