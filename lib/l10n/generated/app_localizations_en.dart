// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Arena';

  @override
  String get welcome => 'Welcome';

  @override
  String get home => 'Home';

  @override
  String get arena => 'Arena';

  @override
  String get debates => 'Debates & Discussions';

  @override
  String get openDiscussion => 'Open Discussion';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get join => 'Join';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get send => 'Send';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get roomName => 'Room Name';

  @override
  String get roomDescription => 'Room Description';

  @override
  String get participants => 'Participants';

  @override
  String participantCount(int count) {
    return '$count participants';
  }

  @override
  String get speakingTime => 'Speaking Time';

  @override
  String get timer => 'Timer';

  @override
  String get startTimer => 'Start Timer';

  @override
  String get pauseTimer => 'Pause Timer';

  @override
  String get resetTimer => 'Reset Timer';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get raiseHand => 'Raise Hand';

  @override
  String get lowerHand => 'Lower Hand';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get beFirstToSend => 'Be the first to send a message!';

  @override
  String get moderator => 'Moderator';

  @override
  String get speaker => 'Speaker';

  @override
  String get audience => 'Audience';

  @override
  String get judge => 'Judge';

  @override
  String get affirmative => 'Affirmative';

  @override
  String get negative => 'Negative';

  @override
  String get createRoom => 'Create Room';

  @override
  String get joinRoom => 'Join Room';

  @override
  String get leaveRoom => 'Leave Room';

  @override
  String get endRoom => 'End Room';

  @override
  String get privateRoom => 'Private Room';

  @override
  String get publicRoom => 'Public Room';

  @override
  String get password => 'Password';

  @override
  String get incorrectPassword => 'Incorrect password';

  @override
  String get roomRequiresPassword => 'This room requires a password to enter.';

  @override
  String get activeDiscussions => 'Active Discussions';

  @override
  String get noActiveDiscussions => 'No active discussions';

  @override
  String get beFirstToCreate => 'Be the first to create a discussion room!';

  @override
  String roomsAvailable(int count) {
    return '$count rooms available';
  }

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get largeText => 'Large Text';

  @override
  String get highContrast => 'High Contrast';

  @override
  String get screenReader => 'Screen Reader Support';

  @override
  String get connectionStatus => 'Connection Status';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get reconnecting => 'Reconnecting...';

  @override
  String get offline => 'Offline';

  @override
  String get retryConnection => 'Retry Connection';
}
