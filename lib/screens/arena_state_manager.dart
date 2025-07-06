import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:async';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

class ArenaStateManager {
  // Services
  final AppwriteService _appwrite;
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  String? _currentUserId;
  String _userRole = 'audience';
  String? _winner;
  final bool _judgingComplete = false;
  bool _judgingEnabled = false;
  bool _hasCurrentUserSubmittedVote = false;
  String _currentSpeaker = '';
  bool _speakingEnabled = false;
  bool _bothDebatersPresent = false;
  bool _invitationsInProgress = false;
  
  // Participants and audience
  final Map<String, UserProfile> _participants = {};
  final List<UserProfile> _audience = [];
  
  // Invitation tracking
  final List<String> _affirmativeSelections = [];
  final List<String> _negativeSelections = [];
  bool _affirmativeCompletedSelection = false;
  bool _negativeCompletedSelection = false;
  bool _invitationModalShown = false;
  bool _waitingForOtherDebater = false;
  bool _resultsModalShown = false;
  final bool _roomClosingModalShown = false;
  
  // Real-time subscriptions
  RealtimeSubscription? _realtimeSubscription;
  Timer? _roomStatusChecker;
  Timer? _roomCompletionTimer;
  
  // State change callbacks
  VoidCallback? onStateChanged;
  Function(String)? onNavigateHome;
  Function(String)? onShowSnackBar;
  Function(VoidCallback)? onShowDialog;
  
  ArenaStateManager({
    required AppwriteService appwrite,
    this.onStateChanged,
    this.onNavigateHome,
    this.onShowSnackBar,
    this.onShowDialog,
  }) : _appwrite = appwrite;
  
  // Getters
  Map<String, dynamic>? get roomData => _roomData;
  UserProfile? get currentUser => _currentUser;
  String? get currentUserId => _currentUserId;
  String get userRole => _userRole;
  String? get winner => _winner;
  bool get judgingComplete => _judgingComplete;
  bool get judgingEnabled => _judgingEnabled;
  bool get hasCurrentUserSubmittedVote => _hasCurrentUserSubmittedVote;
  String get currentSpeaker => _currentSpeaker;
  bool get speakingEnabled => _speakingEnabled;
  bool get bothDebatersPresent => _bothDebatersPresent;
  bool get invitationsInProgress => _invitationsInProgress;
  Map<String, UserProfile> get participants => _participants;
  List<UserProfile> get audience => _audience;
  bool get invitationModalShown => _invitationModalShown;
  bool get waitingForOtherDebater => _waitingForOtherDebater;
  bool get resultsModalShown => _resultsModalShown;
  bool get roomClosingModalShown => _roomClosingModalShown;
  
  // Setters for external updates
  set currentSpeaker(String speaker) {
    _currentSpeaker = speaker;
    _notifyStateChanged();
  }
  
  set speakingEnabled(bool enabled) {
    _speakingEnabled = enabled;
    _notifyStateChanged();
  }
  
  void _notifyStateChanged() {
    onStateChanged?.call();
  }
  
  // Initialize state manager
  Future<void> initialize(String roomId) async {
    try {
      await _loadRoomData(roomId);
      await _loadParticipants(roomId);
      _setupRealtimeSubscription(roomId);
      _startRoomStatusChecker(roomId);
    } catch (e) {
      AppLogger().error('Failed to initialize arena state: $e');
      rethrow;
    }
  }
  
  // Load room data
  Future<void> _loadRoomData(String roomId) async {
    try {
      final roomDoc = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_rooms',
        documentId: roomId,
      );
      _roomData = roomDoc.data;
      
      final currentAppwriteUser = await _appwrite.getCurrentUser();
      _currentUserId = currentAppwriteUser?.$id;
      
      AppLogger().info('Room data loaded successfully');
      _notifyStateChanged();
    } catch (e) {
      AppLogger().error('Error loading room data: $e');
      rethrow;
    }
  }
  
  // Load participants
  Future<void> _loadParticipants(String roomId) async {
    try {
      final participantsData = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
        ],
      );
      
      await _processParticipants(participantsData.documents.map((doc) => doc.data).toList());
      _notifyStateChanged();
    } catch (e) {
      AppLogger().error('Error loading participants: $e');
    }
  }
  
  // Process participants data
  Future<void> _processParticipants(List<dynamic> participantsData) async {
    _participants.clear();
    _audience.clear();
    
    for (var participantData in participantsData) {
      try {
        final userId = participantData['userId'];
        final role = participantData['role'];
        
        final userProfile = await _loadUserDataOptimized(userId);
        if (userProfile != null) {
          if (role == 'audience') {
            _audience.add(userProfile);
            AppLogger().info('Added ${userProfile.name} to audience (Total audience: ${_audience.length})');
          } else {
            _participants[role] = userProfile;
            AppLogger().info('Added ${userProfile.name} as $role');
          }
          
          // Set current user role
          if (userId == _currentUserId) {
            _userRole = role;
            AppLogger().info('Current user role: $_userRole');
          }
        }
      } catch (e) {
        AppLogger().warning('Error processing participant: $e');
      }
    }
    
    _bothDebatersPresent = _participants.containsKey('affirmative') && _participants.containsKey('negative');
    AppLogger().info('Both debaters present: $_bothDebatersPresent');
  }
  
  // Load user data with optimization
  Future<UserProfile?> _loadUserDataOptimized(String userId) async {
    try {
      final userData = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'user_profiles',
        documentId: userId,
      );
      
      return UserProfile(
        id: userData.$id,
        name: userData.data['name'] ?? 'Unknown User',
        email: userData.data['email'] ?? '',
        avatar: userData.data['avatar'],
        bio: userData.data['bio'],
        reputation: userData.data['reputation'] ?? 0,
        totalWins: userData.data['totalWins'] ?? 0,
        totalDebates: userData.data['totalDebates'] ?? 0,
        createdAt: DateTime.parse(userData.$createdAt),
        updatedAt: DateTime.parse(userData.$updatedAt),
      );
    } catch (e) {
      AppLogger().warning('Error loading user data for $userId: $e');
      return null;
    }
  }
  
  // Setup real-time subscription
  void _setupRealtimeSubscription(String roomId) {
    try {
      _realtimeSubscription = _appwrite.realtime.subscribe([
        'databases.arena_db.collections.room_participants.documents',
        'databases.arena_db.collections.debate_rooms.documents.$roomId',
      ]);
      
      _realtimeSubscription?.stream.listen((response) {
        if (response.events.isNotEmpty) {
          AppLogger().debug('Realtime update received: ${response.events.first}');
          _handleRealtimeUpdate(response, roomId);
        }
      });
      
      AppLogger().info('Real-time subscription established');
    } catch (e) {
      AppLogger().error('Error setting up real-time subscription: $e');
    }
  }
  
  // Handle real-time updates
  void _handleRealtimeUpdate(RealtimeMessage response, String roomId) {
    try {
      final eventType = response.events.first;
      
      if (eventType.contains('room_participants')) {
        _loadParticipants(roomId);
      } else if (eventType.contains('debate_rooms')) {
        _loadRoomData(roomId);
      }
    } catch (e) {
      AppLogger().warning('Error handling real-time update: $e');
    }
  }
  
  // Start room status checker
  void _startRoomStatusChecker(String roomId) {
    _roomStatusChecker = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final roomStatus = await _appwrite.databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'debate_rooms',
          documentId: roomId,
        );
        
        final status = roomStatus.data['status'];
        if (status == 'closed' || status == 'completed') {
          timer.cancel();
          _handleClosedRoom(status);
        }
      } catch (e) {
        AppLogger().warning('Error checking room status: $e');
      }
    });
  }
  
  // Handle closed room
  void _handleClosedRoom(String roomStatus) {
    AppLogger().info('Room closed with status: $roomStatus');
    onShowSnackBar?.call('Room has been closed');
    onNavigateHome?.call('Room closed');
  }
  
  // Assign role to user
  Future<void> assignRoleToUser(UserProfile user, String role) async {
    try {
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        documentId: '${_roomData?['\$id']}_${user.id}_$role',
        data: {
          'roomId': _roomData?['\$id'],
          'userId': user.id,
          'role': role,
          'assignedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('Assigned ${user.name} to role: $role');
      onShowSnackBar?.call('${user.name} assigned as $role');
    } catch (e) {
      AppLogger().error('Error assigning role: $e');
      onShowSnackBar?.call('Error assigning role: $e');
    }
  }
  
  // Assign moderator from audience
  Future<void> assignModeratorFromAudience(UserProfile selectedUser) async {
    try {
      // Remove from audience
      await _appwrite.databases.deleteDocument(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        documentId: '${_roomData?['\$id']}_${selectedUser.id}_audience',
      );
      
      // Add as moderator
      await assignRoleToUser(selectedUser, 'moderator');
      
      AppLogger().info('${selectedUser.name} promoted from audience to moderator');
    } catch (e) {
      AppLogger().error('Error promoting to moderator: $e');
    }
  }
  
  // Assign judge from audience
  Future<void> assignJudgeFromAudience(UserProfile selectedUser) async {
    try {
      final availableJudgeSlots = _getAvailableJudgeSlots();
      if (availableJudgeSlots.isEmpty) {
        onShowSnackBar?.call('No judge slots available');
        return;
      }
      
      final judgeRole = availableJudgeSlots.first;
      
      // Remove from audience
      await _appwrite.databases.deleteDocument(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        documentId: '${_roomData?['\$id']}_${selectedUser.id}_audience',
      );
      
      // Add as judge
      await assignRoleToUser(selectedUser, judgeRole);
      
      AppLogger().info('${selectedUser.name} promoted from audience to $judgeRole');
    } catch (e) {
      AppLogger().error('Error promoting to judge: $e');
    }
  }
  
  // Get available judge slots
  List<String> _getAvailableJudgeSlots() {
    const maxJudges = 3;
    final availableSlots = <String>[];
    
    for (int i = 1; i <= maxJudges; i++) {
      final judgeRole = 'judge$i';
      if (!_participants.containsKey(judgeRole)) {
        availableSlots.add(judgeRole);
      }
    }
    
    return availableSlots;
  }
  
  // Check for both debaters and trigger invitations
  void checkForBothDebatersAndTriggerInvitations() {
    if (_bothDebatersPresent && !_invitationModalShown && _userRole == 'moderator') {
      _invitationModalShown = true;
      onShowDialog?.call(() {
        // Show invitation modal logic
      });
    }
  }
  
  // Handle invitation selection complete
  void handleInviteSelectionComplete() {
    if (_affirmativeCompletedSelection && _negativeCompletedSelection) {
      _performMixedInvitations();
    }
  }
  
  // Perform mixed invitations
  void _performMixedInvitations() {
    _invitationsInProgress = true;
    
    // Send invitations to selected users
    for (String userId in _affirmativeSelections) {
      _sendSingleModeratorInvitation(userId);
    }
    for (String userId in _negativeSelections) {
      _sendSingleModeratorInvitation(userId);
    }
    
    AppLogger().info('Mixed invitations sent to ${_affirmativeSelections.length + _negativeSelections.length} users');
    _notifyStateChanged();
  }
  
  // Send single moderator invitation
  void _sendSingleModeratorInvitation(String moderatorId) {
    // TODO: Implement sendModeratorInvitation method in ChallengeMessagingService
    AppLogger().info('Sending moderator invitation to: $moderatorId');
    // _messagingService.sendModeratorInvitation(
    //   challengeId: _roomData?['challengeId'] ?? '',
    //   moderatorId: moderatorId,
    //   debateRoomId: _roomData?['\$id'] ?? '',
    // );
  }
  
  // Handle approval response
  void handleApprovalResponse(bool approved) {
    if (approved) {
      onShowSnackBar?.call('Invitation accepted!');
    } else {
      onShowSnackBar?.call('Invitation declined');
      _resetInvitationProcess();
    }
  }
  
  // Reset invitation process
  void _resetInvitationProcess() {
    _affirmativeSelections.clear();
    _negativeSelections.clear();
    _affirmativeCompletedSelection = false;
    _negativeCompletedSelection = false;
    _invitationModalShown = false;
    _waitingForOtherDebater = false;
    _invitationsInProgress = false;
    _notifyStateChanged();
  }
  
  // Determine winner and show results
  void determineWinnerAndShowResults() {
    // Placeholder for winner determination logic
    // This would typically involve counting votes
    _resultsModalShown = true;
    _notifyStateChanged();
  }
  
  // Toggle judging
  void toggleJudging() {
    _judgingEnabled = !_judgingEnabled;
    AppLogger().info('Judging ${_judgingEnabled ? 'enabled' : 'disabled'}');
    _notifyStateChanged();
  }
  
  // Toggle speaking
  void toggleSpeakingEnabled() {
    _speakingEnabled = !_speakingEnabled;
    AppLogger().info('Speaking ${_speakingEnabled ? 'enabled' : 'disabled'}');
    _notifyStateChanged();
  }
  
  // Force speaker change
  void forceSpeakerChange(String newSpeaker) {
    _currentSpeaker = newSpeaker;
    _speakingEnabled = true;
    AppLogger().info('Speaker changed to: $newSpeaker');
    _notifyStateChanged();
  }
  
  // Helper methods
  bool hasRoleAssigned(String role) {
    return _participants.containsKey(role);
  }
  
  String getUserRole(UserProfile user) {
    for (var entry in _participants.entries) {
      if (entry.value.id == user.id) {
        return entry.key;
      }
    }
    return 'audience';
  }
  
  String getRoleDisplayName(String roleId) {
    switch (roleId) {
      case 'affirmative':
        return 'Affirmative Debater';
      case 'negative':
        return 'Negative Debater';
      case 'moderator':
        return 'Moderator';
      case 'judge1':
      case 'judge2':
      case 'judge3':
        return 'Judge ${roleId.replaceAll('judge', '')}';
      default:
        return 'Audience';
    }
  }
  
  String getModeratorName(String moderatorId) {
    final moderator = _participants['moderator'];
    return moderator?.name ?? 'Unknown Moderator';
  }
  
  // Submit vote
  Future<void> submitVote(String winner) async {
    if (_hasCurrentUserSubmittedVote || _currentUserId == null) {
      return;
    }
    
    try {
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        documentId: '${_roomData?['\$id']}_${_currentUserId}_vote',
        data: {
          'roomId': _roomData?['\$id'],
          'voterId': _currentUserId,
          'winner': winner,
          'submittedAt': DateTime.now().toIso8601String(),
        },
      );
      
      _hasCurrentUserSubmittedVote = true;
      AppLogger().info('Vote submitted for: $winner');
      onShowSnackBar?.call('Vote submitted successfully!');
      _notifyStateChanged();
    } catch (e) {
      AppLogger().error('Error submitting vote: $e');
      onShowSnackBar?.call('Error submitting vote: $e');
    }
  }
  
  // Close room
  Future<void> closeRoom() async {
    try {
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_rooms',
        documentId: _roomData?['\$id'] ?? '',
        data: {
          'status': 'closed',
          'closedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('Room closed successfully');
      onShowSnackBar?.call('Room has been closed');
      
      // Start countdown timer for navigation
      _roomCompletionTimer = Timer(const Duration(seconds: 10), () {
        onNavigateHome?.call('Room closed');
      });
    } catch (e) {
      AppLogger().error('Error closing room: $e');
      onShowSnackBar?.call('Error closing room: $e');
    }
  }
  
  // Cleanup
  void dispose() {
    _realtimeSubscription?.close();
    _roomStatusChecker?.cancel();
    _roomCompletionTimer?.cancel();
    AppLogger().info('Arena state manager disposed');
  }
}