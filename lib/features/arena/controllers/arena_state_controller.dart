import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../core/logging/app_logger.dart';
import '../models/debate_phase.dart';

/// Arena State Controller - DO NOT MODIFY STATE LOGIC
/// This controller manages all arena state exactly as the original
class ArenaStateController extends ChangeNotifier {

  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  String? _currentUserId;
  String? _userRole;
  String? _winner; // Track the debate winner
  bool _judgingComplete = false;
  bool _judgingEnabled = false; // Track if judges can submit votes
  bool _hasCurrentUserSubmittedVote = false;
  bool _resultsModalShown = false; // Track if results modal has been shown
  bool _roomClosingModalShown = false; // Track if room closing modal has been shown
  bool _hasNavigated = false; // Track if we've already navigated to prevent duplicate navigation
  bool _isExiting = false; // Prevent state updates during exit
  Timer? _roomStatusChecker; // Periodic room status checker
  StreamSubscription? _realtimeSubscription; // Track realtime subscription

  // Enhanced Timer and Debate Management
  DebatePhase _currentPhase = DebatePhase.preDebate;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  bool _isPaused = false;
  bool _hasPlayed30SecWarning = false; // Track if 30-sec warning was played

  // Speaking Management
  String _currentSpeaker = '';
  bool _speakingEnabled = false;

  // Participants by role
  Map<String, UserProfile?> _participants = {
    'affirmative': null,
    'negative': null,
    'moderator': null,
    'judge1': null,
    'judge2': null,
    'judge3': null,
  };

  List<UserProfile> _audience = [];

  // Two-stage invitation system state
  bool _bothDebatersPresent = false;
  bool _invitationModalShown = false;
  bool _invitationsInProgress = false;
  final bool _affirmativeCompletedSelection = false;
  final bool _negativeCompletedSelection = false;
  final bool _waitingForOtherDebater = false;

  // Getters for all state
  Map<String, dynamic>? get roomData => _roomData;
  UserProfile? get currentUser => _currentUser;
  String? get currentUserId => _currentUserId;
  String? get userRole => _userRole;
  String? get winner => _winner;
  bool get judgingComplete => _judgingComplete;
  bool get judgingEnabled => _judgingEnabled;
  bool get hasCurrentUserSubmittedVote => _hasCurrentUserSubmittedVote;
  bool get resultsModalShown => _resultsModalShown;
  bool get roomClosingModalShown => _roomClosingModalShown;
  bool get hasNavigated => _hasNavigated;
  bool get isExiting => _isExiting;
  DebatePhase get currentPhase => _currentPhase;
  int get remainingSeconds => _remainingSeconds;
  bool get isTimerRunning => _isTimerRunning;
  bool get isPaused => _isPaused;
  bool get hasPlayed30SecWarning => _hasPlayed30SecWarning;
  String get currentSpeaker => _currentSpeaker;
  bool get speakingEnabled => _speakingEnabled;
  Map<String, UserProfile?> get participants => _participants;
  List<UserProfile> get audience => _audience;
  bool get bothDebatersPresent => _bothDebatersPresent;
  bool get invitationModalShown => _invitationModalShown;
  bool get invitationsInProgress => _invitationsInProgress;
  bool get affirmativeCompletedSelection => _affirmativeCompletedSelection;
  bool get negativeCompletedSelection => _negativeCompletedSelection;
  bool get waitingForOtherDebater => _waitingForOtherDebater;

  // Convenience getters
  bool get isModerator => _userRole == 'moderator';
  bool get isJudge => _userRole?.startsWith('judge') ?? false;
  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // State setters that notify listeners
  void setWinner(String? winner) {
    _winner = winner;
    notifyListeners();
  }

  void setJudgingComplete(bool complete) {
    _judgingComplete = complete;
    notifyListeners();
  }

  void setJudgingEnabled(bool enabled) {
    _judgingEnabled = enabled;
    notifyListeners();
  }

  void setCurrentUserSubmittedVote(bool submitted) {
    _hasCurrentUserSubmittedVote = submitted;
    notifyListeners();
  }

  void setResultsModalShown(bool shown) {
    _resultsModalShown = shown;
    notifyListeners();
  }

  void setRoomClosingModalShown(bool shown) {
    _roomClosingModalShown = shown;
    notifyListeners();
  }

  void setHasNavigated(bool navigated) {
    _hasNavigated = navigated;
    notifyListeners();
  }

  void setIsExiting(bool exiting) {
    _isExiting = exiting;
    notifyListeners();
  }

  void setCurrentPhase(DebatePhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void setRemainingSeconds(int seconds) {
    _remainingSeconds = seconds;
    notifyListeners();
  }

  void setTimerRunning(bool running) {
    _isTimerRunning = running;
    notifyListeners();
  }

  void setPaused(bool paused) {
    _isPaused = paused;
    notifyListeners();
  }

  void setHasPlayed30SecWarning(bool played) {
    _hasPlayed30SecWarning = played;
    notifyListeners();
  }

  void setCurrentSpeaker(String speaker) {
    _currentSpeaker = speaker;
    notifyListeners();
  }

  void setSpeakingEnabled(bool enabled) {
    _speakingEnabled = enabled;
    notifyListeners();
  }

  void setParticipants(Map<String, UserProfile?> participants) {
    _participants = participants;
    notifyListeners();
  }

  void setAudience(List<UserProfile> audience) {
    _audience = audience;
    notifyListeners();
  }

  void setBothDebatersPresent(bool present) {
    _bothDebatersPresent = present;
    notifyListeners();
  }

  void setInvitationModalShown(bool shown) {
    _invitationModalShown = shown;
    notifyListeners();
  }

  void setInvitationsInProgress(bool inProgress) {
    _invitationsInProgress = inProgress;
    notifyListeners();
  }

  void setUserRole(String? role) {
    _userRole = role;
    notifyListeners();
  }

  void setCurrentUser(UserProfile? user) {
    _currentUser = user;
    _currentUserId = user?.id;
    notifyListeners();
  }

  void setRoomData(Map<String, dynamic>? data) {
    _roomData = data;
    notifyListeners();
  }

  // Timer management
  void advancePhase() {
    final nextPhase = _currentPhase.nextPhase;
    if (nextPhase != null) {
      setCurrentPhase(nextPhase);
      setRemainingSeconds(nextPhase.defaultDurationSeconds ?? 0);
      setHasPlayed30SecWarning(false);
    }
  }

  void resetTimer() {
    setRemainingSeconds(_currentPhase.defaultDurationSeconds ?? 0);
    setTimerRunning(false);
    setPaused(false);
    setSpeakingEnabled(false);
    setHasPlayed30SecWarning(false);
  }

  void startTimer() {
    setTimerRunning(true);
    setPaused(false);
  }

  void pauseTimer() {
    setPaused(true);
    setTimerRunning(false);
  }

  void resumeTimer() {
    setPaused(false);
    setTimerRunning(true);
  }

  void stopTimer() {
    setTimerRunning(false);
    setPaused(false);
  }

  void extendTime(int seconds) {
    setRemainingSeconds(_remainingSeconds + seconds);
  }

  void setCustomTime(int seconds) {
    setRemainingSeconds(seconds);
    setTimerRunning(false);
    setPaused(false);
  }

  // State management for navigation and exit
  void cancelAllTimersAndSubscriptions() {
    try {
      if (_roomStatusChecker != null) {
        _roomStatusChecker!.cancel();
        _roomStatusChecker = null;
        AppLogger().debug('🛑 Exit timer cancelled and nulled');
      }
      _realtimeSubscription?.cancel();
      AppLogger().info('All timers and subscriptions cancelled');
    } catch (e) {
      AppLogger().warning('Error cancelling timers: $e');
    }
  }

  @override
  void dispose() {
    cancelAllTimersAndSubscriptions();
    super.dispose();
  }
}