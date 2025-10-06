import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/firebase_gift_service.dart';
import '../widgets/simple_gift_bottom_sheet.dart';
import '../services/livekit_service.dart';
import '../services/livekit_token_service.dart';
import '../services/livekit_config_service.dart';
import '../services/super_moderator_service.dart';
import '../services/user_timeout_service.dart';
// import '../services/chat_service.dart'; // Removed with new chat system
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../features/arena/constants/arena_colors.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/user_profile_bottom_sheet.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/mattermost_chat_widget.dart';
import '../widgets/real_time_coin_balance.dart';
import 'email_compose_screen.dart';
import '../models/discussion_chat_message.dart';
// import '../widgets/floating_im_widget.dart'; // Unused import
import '../core/logging/app_logger.dart';
import '../utils/performance_optimizations.dart';
import '../utils/optimized_state_manager.dart';
import '../utils/token_debugger.dart';
import '../utils/ultra_performance_mode.dart';
import '../utils/extreme_performance_mode.dart';
import '../widgets/performance_optimized_audience_grid.dart';
import '../core/performance/riverpod_performance_optimizer.dart';
import '../core/performance/virtualized_list_optimizer.dart';
import '../core/performance/network_performance_optimizer.dart';
import '../widgets/bottom_sheet/debate_bottom_sheet.dart';
import '../services/livekit_material_sync_service.dart';
import '../widgets/shared_link_popup.dart';
import '../widgets/slide_update_popup.dart';
import '../models/debate_source.dart';
import '../services/participant_recruitment_service.dart';
import '../services/audio_clip_service.dart';
import '../services/realtime_ai_moderation_service.dart';
import '../services/audio_volume_service.dart';
import '../services/room_realtime_manager.dart';
import '../services/participant_diff_manager.dart';
import '../services/granular_state_manager.dart';
import '../services/disposal_tracking_system.dart';
import '../services/weak_reference_manager.dart';
import '../services/batch_user_profile_service.dart';
import '../services/audio_preloader_service.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

// Reaction data model for displaying emoji reactions and gifts
class ReactionData {
  final String emoji;
  final String targetUserId;
  final String senderUserId;
  final String? senderName;
  final DateTime timestamp;
  final String id;
  final bool isGift;
  final int? giftValue;
  final String? giftName;

  ReactionData({
    required this.emoji,
    required this.targetUserId,
    required this.senderUserId,
    this.senderName,
    required this.timestamp,
    String? id,
    this.isGift = false,
    this.giftValue,
    this.giftName,
  }) : id = id ?? '${DateTime.now().millisecondsSinceEpoch}_${targetUserId}_${senderUserId}';

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'targetUserId': targetUserId,
      'senderUserId': senderUserId,
      'senderName': senderName,
      'timestamp': timestamp.toIso8601String(),
      'isGift': isGift,
      'giftValue': giftValue,
      'giftName': giftName,
    };
  }

  factory ReactionData.fromMap(Map<String, dynamic> map, String id) {
    return ReactionData(
      id: id,
      emoji: map['emoji'] ?? '👍',
      targetUserId: map['targetUserId'] ?? '',
      senderUserId: map['senderUserId'] ?? '',
      senderName: map['senderName'],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isGift: map['isGift'] ?? false,
      giftValue: map['giftValue'],
      giftName: map['giftName'],
    );
  }
}

class DebatesDiscussionsScreen extends StatefulWidget {
  final String roomId;
  final String? roomName;
  final String? moderatorName;

  const DebatesDiscussionsScreen({
    super.key,
    required this.roomId,
    this.roomName,
    this.moderatorName,
  });

  @override
  State<DebatesDiscussionsScreen> createState() => _DebatesDiscussionsScreenState();
}

class _DebatesDiscussionsScreenState extends State<DebatesDiscussionsScreen>
    with NetworkOptimizationMixin, ListOptimizationMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin, DisposalTrackingMixin, WeakReferenceMixin {
  final AppwriteService _appwrite = AppwriteService();
  final FirebaseGiftService _giftService = FirebaseGiftService();
  final LiveKitService _webrtcService = LiveKitService();
  
  // Performance optimization instances
  final RiverpodPerformanceOptimizer _performanceOptimizer = RiverpodPerformanceOptimizer();
  final VirtualizedListOptimizer _listOptimizer = VirtualizedListOptimizer();
  final NetworkPerformanceOptimizer _networkOptimizer = NetworkPerformanceOptimizer();
  final GranularStateManager _granularStateManager = GranularStateManager();
  final BatchUserProfileService _batchProfileService = BatchUserProfileService();
  late final AudioPreloaderService _audioPreloader;
  
  // Video/Audio WebRTC state
  bool _isWebRTCConnected = false;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  
  // User-to-peer mapping for video streams
  final Map<String, String> _userToPeerMapping = {}; // userId -> peerId
  final Map<String, String> _peerToUserMapping = {}; // peerId -> userId
  
  // Audio stream management
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  
  // Simple audio state (replacing complex WebRTC logic)
  bool _isAudioConnected = false;
  bool _isAudioConnecting = false;
  final LiveKitService _liveKitService = LiveKitService();
  
  // Audio clipping state
  final AudioClipService _audioClipService = AudioClipService();
  bool _isRecordingClip = false;

  // AI Moderation and Audio Volume services
  final RealtimeAIModerationService _aiModerationService = RealtimeAIModerationService();
  final AudioVolumeService _audioVolumeService = AudioVolumeService();
  
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  UserProfile? _moderator;
  
  // Gift system
  int _currentUserCoinBalance = 0;
  List<Gift> _availableGifts = [];

  // Reaction system
  final List<ReactionData> _activeReactions = [];

  // Participants
  final List<UserProfile> _speakerPanelists = []; // Max 6 speakers
  final List<UserProfile> _audienceMembers = [];
  final List<UserProfile> _speakerRequests = []; // Pending speaker requests

  // Speaker Queue System for Discussions Mode
  final List<String> _speakerQueue = []; // Queue of speaker user IDs waiting to speak
  String? _currentSpeaker; // Current speaker from the queue
  bool _queueEnabled = true; // Toggle for queue mode

  // Real-time speaker queue sync
  RealtimeSubscription? _speakerQueueSubscription;

  // Real-time reactions sync
  RealtimeSubscription? _reactionsSubscription;

  // Role mapping for participants (userId -> role)
  final Map<String, String> _participantRoles = {};

  // In-flight fetch tracking to prevent redundant database calls
  final Set<String> _inFlightFetches = {};

  // Performance optimization - cache last participants to prevent unnecessary rebuilds
  final ParticipantDiffManager _diffManager = ParticipantDiffManager();
  List<dynamic> _lastParticipants = [];
  
  // Connection stability monitoring
  Timer? _connectionHealthTimer;
  Timer? _reconnectionTimer;
  Timer? _participantSyncTimer;
  bool _wasOffline = false;
  
  // Materials system
  LiveKitMaterialSyncService? _materialSyncService;
  bool _isReconnecting = false;
  int _connectionDropCount = 0;
  DateTime? _lastConnectionDrop;
  
  // Connection stability thresholds
  int _consecutiveUnhealthyChecks = 0;
  static const int _unhealthyThreshold = 3; // Require 3 consecutive unhealthy checks
  static const int _minTimeBetweenReconnections = 60; // Minimum 60 seconds between reconnection attempts
  
  // Audio variables (handled by LiveKit)
  // Note: These are no longer used but kept for any remaining references
  
  // Room state
  bool _isLoading = true;
  bool _isJoined = false;
  bool _isCurrentUserModerator = false;
  bool _isCurrentUserSpeaker = false;
  bool _isCurrentUserTimedOut = false;
  bool _hasRequestedSpeaker = false;
  bool _isDisposing = false;
  
  // Video conference state removed - audio-only mode
  // Future update will restore video functionality
  
  // Helper method to check if current user has moderator powers (regular mod OR Super Moderator)
  bool get _hasModeratorPowers {
    if (_isCurrentUserModerator) return true;
    
    final superModService = SuperModeratorService();
    if (_currentUser != null && superModService.isSuperModerator(_currentUser!.id)) {
      return true;
    }
    
    return false;
  }
  
  // Consolidated real-time subscription manager
  final RoomRealtimeManager _realtimeManager = RoomRealtimeManager();
  RoomSubscription? _roomSubscription;

  // Separate subscription stream listeners
  StreamSubscription? _participantStreamListener;
  StreamSubscription? _chatStreamListener;
  StreamSubscription? _roomStatusStreamListener;
  StreamSubscription? _handRaiseStreamListener;
  StreamSubscription? _timerStreamListener;
  StreamSubscription? _materialStreamListener;

  // Legacy subscriptions to be phased out
  StreamSubscription? _unreadMessagesSubscription; // Instant messages subscription
  StreamSubscription? _firebaseParticipantSubscription; // Firebase participant sync
  StreamSubscription? _materialUpdatesSubscription; // Material updates subscription
  StreamSubscription? _sourceAddedSubscription; // Source added subscription

  @override
  bool get wantKeepAlive => true; // Keep widget alive to prevent recreation

  @override
  void initState() {
    super.initState();

    // Initialize disposal tracking system
    initDisposalTracking(customId: 'debates_${widget.roomId}');

    // Initialize weak reference management
    initWeakReferences(customId: 'debates_${widget.roomId}');

    // Initialize audio preloader service
    _audioPreloader = getIt<AudioPreloaderService>();

    // Add lifecycle observer for automatic refresh on app resume
    WidgetsBinding.instance.addObserver(this);
    
    // Enable ultra-performance mode for maximum FPS
    UltraPerformanceMode.instance.enable();
    
    // Enable extreme performance mode for maximum possible performance
    ExtremePerformanceMode.instance.enable();
    
    // Initialize participant diff manager
    _diffManager.initializeRoom(widget.roomId);

    _initializeRoom();
    _loadGiftData();
    _initializeWebRTC();
    _initializeSpeakerQueueSync();
    _initializeReactionsSync();

    // Add LiveKit service listener to sync mute state changes from data messages
    _liveKitService.addListener(_onLiveKitStateChanged);

    // Set up speaking detection callback to trigger UI updates
    _liveKitService.onSpeakingChanged = (String userId, bool isSpeaking) {
      AppLogger().debug('🗣️ Speaking state changed for $userId: $isSpeaking');
      if (mounted) {
        setState(() {
          // Trigger UI rebuild when speaking state changes
        });
      }
    };

    // Configure audio for maximum volume
    _configureAudio();

    // Start connection health monitoring to prevent user drops
    _startConnectionHealthMonitoring();
  }

  /// Handle LiveKit service state changes (especially mute state from data messages)
  void _onLiveKitStateChanged() {
    if (!mounted) return;

    // Sync mute state from LiveKit service to local UI state
    if (_isMuted != _liveKitService.isMuted) {
      setState(() {
        _isMuted = _liveKitService.isMuted;
      });
      AppLogger().debug('🔄 UI mute state synced from LiveKit: $_isMuted');
    }
  }

  Future<void> _initializeWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    
    // Set up LiveKit service callbacks with weak references
    _webrtcService.onConnected = () {
      AppLogger().debug('✅ LiveKit connected to Debates & Discussions room');
      if (mounted) {
        setState(() {
          _isWebRTCConnected = true;
        });
        _debugVideoState();
      }
    };
    // Register weak reference for connected callback
    registerWeakListener('livekit_connected', () => _webrtcService.onConnected = null);
    
    _webrtcService.onParticipantConnected = (participant) {
      AppLogger().debug('👤 LiveKit participant joined: ${participant.identity}');
      if (mounted) {
        setState(() {
          // Trigger UI update for participant count
        });
      }
    };
    // Register weak reference for participant connected callback
    registerWeakListener('livekit_participant_connected', () => _webrtcService.onParticipantConnected = null);
    
    _webrtcService.onParticipantDisconnected = (participant) {
      AppLogger().debug('👋 LiveKit participant left: ${participant.identity}');
      if (mounted) {
        setState(() {
          // Update UI for participant leaving
        });
      }
    };
    
    _webrtcService.onTrackSubscribed = (publication, participant) {
      AppLogger().debug('🎵 LiveKit track subscribed from ${participant.identity}');
      if (mounted) {
        setState(() {
          // Handle new audio track
        });
      }
    };
    
    _webrtcService.onDisconnected = () {
      AppLogger().debug('📡 LiveKit disconnected from Debates & Discussions room');
      if (mounted) {
        setState(() {
          _isWebRTCConnected = false;
        });
      }
    };
    
    _webrtcService.onError = (error) {
      AppLogger().debug('❌ LiveKit error: $error');
      if (mounted) {
        setState(() {
        });
      }
    };
    
    AppLogger().debug('📹 WebRTC renderers and MediaSoup service initialized for Debates & Discussions');
  }
  
  void _initializeMaterialsService() {
    // Initialize materials service for ALL users in debate format rooms
    // Everyone can view slides, but only moderators/debaters can control them
    if (_roomData?['debateStyle'] == 'Debate') {
      AppLogger().debug('📊 Initializing materials service for debate room...');
      AppLogger().debug('📊 LiveKit room status: ${_liveKitService.room != null ? "Available" : "NULL"}');
      AppLogger().debug('📊 Current user: ${_currentUser?.name} (${_currentUser?.id})');
      AppLogger().debug('📊 User roles - moderator: $_hasModeratorPowers, speaker: $_isCurrentUserSpeaker');
      
      _materialSyncService = LiveKitMaterialSyncService(
        appwrite: _appwrite,
        room: _liveKitService.room, // Pass the LiveKit room instance
        roomId: widget.roomId,
        userId: _currentUser?.id ?? '',
        userName: _currentUser?.name,
        isHost: _hasModeratorPowers || _isCurrentUserSpeaker, // Only moderators/debaters can control slides
      );
      AppLogger().debug('📊 Materials service created - isHost: ${_hasModeratorPowers || _isCurrentUserSpeaker}');
      
      // Set up material updates listeners for audience popup notifications
      _setupMaterialListeners();
    } else {
      AppLogger().debug('📊 Skipping materials service - not a debate room (style: ${_roomData?['debateStyle']})');
    }
  }
  
  void _setupMaterialListeners() {
    if (_materialSyncService == null) {
      AppLogger().warning('📊 Cannot setup material listeners - service is null');
      return;
    }
    
    final currentUserId = _currentUser?.id ?? '';
    AppLogger().debug('📊 Setting up material listeners for user: $currentUserId');
    
    // Listen for shared sources
    _sourceAddedSubscription = _materialSyncService!.sourceAdded.listen((source) {
      AppLogger().debug('📌 Received shared source event: ${source.title} from ${source.sharedBy}');
      if (mounted && !_isDisposing) {
        // Only show popup if current user is not the one who shared the link
        if (source.sharedBy != currentUserId) {
          AppLogger().info('📌 Showing shared link popup: ${source.title}');
          _showSharedLinkPopup(source);
        } else {
          AppLogger().debug('📌 Skipping popup for own shared link: ${source.title}');
        }
      }
    });
    trackSubscription('source_added', _sourceAddedSubscription!);
    
    // Listen for material updates and only show popup for NEW slide uploads (pdf_upload), not slide navigation (slide_change)
    _materialUpdatesSubscription = _materialSyncService!.materialUpdates.listen((materialSync) {
      AppLogger().debug('📊 Received material sync event: ${materialSync.type} from ${materialSync.userId}');
      if (mounted && !_isDisposing) {
        // Only show popup for pdf_upload events (new slides shared), not slide_change events (slide navigation)
        if (materialSync.type == 'pdf_upload' && materialSync.userId != currentUserId) {
          AppLogger().info('📊 Showing slide upload popup from ${materialSync.userName}');
          _showSlideUpdatePopup(materialSync);
        } else {
          AppLogger().debug('📊 Skipping popup - type: ${materialSync.type}, own content: ${materialSync.userId == currentUserId}');
        }
      }
    });
    trackSubscription('material_updates', _materialUpdatesSubscription!);

    AppLogger().debug('📊 Material listeners successfully set up');
  }

  // Audio/Video control methods (simplified like open discussion)
  
  Future<void> _toggleMute() async {
    try {
      // Only allow audio toggle for moderators and speakers
      if (!_isCurrentUserModerator && !_isCurrentUserSpeaker) {
        AppLogger().debug('🔇 Mute Toggle: Audience members are listen-only');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔇 Audience members are listen-only. Raise your hand to request speaking permission.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Check if user is timed out
      if (_currentUser?.id != null) {
        final timeoutService = UserTimeoutService();
        final isTimedOut = await timeoutService.isUserTimedOut(_currentUser!.id, widget.roomId);

        if (isTimedOut) {
          final remainingMinutes = await timeoutService.getRemainingTimeoutMinutes(_currentUser!.id, widget.roomId);
          AppLogger().debug('⏰ User is timed out - cannot unmute (${remainingMinutes ?? 0} minutes remaining)');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⏰ You are timed out and cannot speak for ${remainingMinutes ?? 0} more minute(s)'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      
      // Connect to audio first if not connected
      if (!_isAudioConnected) {
        await _connectToAudio();
        return;
      }
      
      // Toggle mute state using LiveKit service
      if (_isMuted) {
        await _liveKitService.enableAudio();
      } else {
        await _liveKitService.disableAudio();
      }
      
      if (mounted) {
        setState(() {
          _isMuted = _liveKitService.isMuted;
        });
      }
      
      AppLogger().debug('🔇 LiveKit audio ${_isMuted ? 'muted' : 'unmuted'}');
    } catch (e) {
      AppLogger().error('❌ Error toggling mute: $e');
      
      // Check if this is a permission/token error - if so, try to reconnect with correct role
      if (e.toString().contains('permission') ||
          e.toString().contains('publish audio') ||
          e.toString().contains('TrackPublishException') ||
          e.toString().contains('Failed to publish track')) {
        AppLogger().warning('🚨 TOKEN/PERMISSION ERROR: Attempting to reconnect with correct role');
        
        // Force disconnect and reconnect with updated permissions
        try {
          if (_isAudioConnected) {
            await _liveKitService.disconnect();
            setState(() {
              _isAudioConnected = false;
              _isAudioConnecting = false;
            });
          }
          
          // Brief delay to ensure cleanup
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Reconnect with corrected role
          await _connectToAudio();
          
          // Try to unmute again after successful reconnection
          if (_isAudioConnected && _isMuted) {
            await _liveKitService.enableAudio();
            if (mounted) {
              setState(() {
                _isMuted = _liveKitService.isMuted;
              });
            }
          }
          
        } catch (reconnectError) {
          AppLogger().error('❌ Reconnection failed: $reconnectError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to enable audio: $reconnectError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
      
      // Sync local state with service state on error
      if (mounted) {
        setState(() {
          _isMuted = _liveKitService.isMuted;
        });
      }
    }
  }


  /// Start connection health monitoring to prevent user drops
  void _startConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 30), (timer) { // Increased from 10 to 30 seconds
      if (!mounted || _isDisposing) {
        timer.cancel();
        return;
      }
      _checkConnectionHealth();
    });
    
    AppLogger().debug('🔍 Started connection health monitoring for speakers panel (30s intervals)');
  }

  /// Stop connection health monitoring
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    AppLogger().debug('🛑 Stopped connection health monitoring');
  }

  /// Check connection health and trigger reconnection if needed
  void _checkConnectionHealth() {
    if (!mounted || _isDisposing || _isReconnecting) return;
    
    try {
      // Check if current user is still in speakers panel
      final isStillSpeaker = _speakerPanelists.any((speaker) => speaker.id == _currentUser?.id);
      final isStillModerator = _moderator?.id == _currentUser?.id;
      
      // Check if WebRTC connection is healthy - be more lenient
      final isWebRTCConnected = _webrtcService.isConnected;
      final hasRemoteStreams = _remoteStreams.isNotEmpty;
      
      // Only consider connection unhealthy if:
      // 1. WebRTC is completely disconnected, OR
      // 2. User is moderator/speaker but has no remote streams (after a reasonable delay)
      // Note: isWebRTCHealthy is calculated but not used in current logic - kept for future use
      // final isWebRTCHealthy = isWebRTCConnected && (hasRemoteStreams || !_isCurrentUserModerator && !_isCurrentUserSpeaker);
      
      // Log connection state for debugging (but not too frequently)
      if (_consecutiveUnhealthyChecks == 0 || _consecutiveUnhealthyChecks % 5 == 0) {
        AppLogger().debug('🔍 Connection health check: WebRTC=${isWebRTCConnected ? 'Connected' : 'Disconnected'}, Streams=${hasRemoteStreams ? 'Yes' : 'No'}, Role=${_isCurrentUserModerator ? 'Moderator' : _isCurrentUserSpeaker ? 'Speaker' : 'Audience'}');
      }
      
      // If user should be a speaker/moderator but isn't, trigger reconnection
      if ((_isCurrentUserModerator || _isCurrentUserSpeaker) && 
          (!isStillSpeaker && !isStillModerator)) {
        AppLogger().warning('⚠️ User dropped from speakers panel - triggering reconnection');
        _handleUserDrop();
        return; // Don't check WebRTC health if we're already reconnecting
      }
      
      // Only attempt WebRTC restoration if:
      // 1. User is moderator/speaker
      // 2. WebRTC is completely disconnected (not just missing streams)
      // 3. We're not already reconnecting
      // 4. We haven't attempted reconnection recently
      // 5. We've had multiple consecutive unhealthy checks
      if (_isCurrentUserModerator || _isCurrentUserSpeaker) {
        if (!isWebRTCConnected && !_isReconnecting) {
          _consecutiveUnhealthyChecks++;
          
          // Check if we've attempted reconnection recently to prevent loops
          final timeSinceLastAttempt = _lastConnectionDrop != null 
              ? DateTime.now().difference(_lastConnectionDrop!).inSeconds 
              : 60;
          
          // Only attempt reconnection if:
          // - We've had enough consecutive unhealthy checks
          // - Enough time has passed since last attempt
          if (_consecutiveUnhealthyChecks >= _unhealthyThreshold && timeSinceLastAttempt > _minTimeBetweenReconnections) {
            AppLogger().warning('⚠️ WebRTC disconnected for $_consecutiveUnhealthyChecks consecutive checks - attempting restoration');
            // Reconnect to audio for all users
            if (!_isAudioConnected) {
              AppLogger().debug('🔄 Health Monitor: Reconnecting audio for all users');
              _connectToAudio();
            }
            _consecutiveUnhealthyChecks = 0; // Reset counter
          } else {
            AppLogger().debug('⏳ Skipping WebRTC restoration - checks: $_consecutiveUnhealthyChecks/$_unhealthyThreshold, time: ${timeSinceLastAttempt}s/$_minTimeBetweenReconnections');
          }
        } else if (isWebRTCConnected) {
          // Reset unhealthy check counter when connection is healthy
          _consecutiveUnhealthyChecks = 0;
        }
      }
      
    } catch (e) {
      AppLogger().error('❌ Error checking connection health: $e');
    }
  }

  /// Handle user drop from speakers panel
  void _handleUserDrop() {
    if (_isReconnecting) return; // Prevent multiple reconnection attempts
    
    _connectionDropCount++;
    _lastConnectionDrop = DateTime.now();
    
    AppLogger().warning('🔴 User drop detected! Count: $_connectionDropCount');
    
    // Show user feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Connection issue detected. Attempting to restore your speaker status...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    // Attempt automatic reconnection
    _attemptAutomaticReconnection();
  }

  /// Attempt automatic reconnection to restore speaker status
  void _attemptAutomaticReconnection() async {
    if (_isReconnecting) return;
    
    _isReconnecting = true;
    AppLogger().debug('🔄 Starting automatic reconnection process...');
    
    try {
      // Step 1: Refresh room data
      await _loadRoomData();
      
      // Step 2: Refresh participants
      await _loadParticipants();
      
      // Step 3: Restore audio connection for all users
      if (!_isAudioConnected) {
        AppLogger().debug('🔄 Automatic Reconnect: Restoring audio for all users');
        await _connectToAudio();
      }
      
      // Step 4: Verify speaker status
      await _verifySpeakerStatus();
      
      AppLogger().debug('✅ Automatic reconnection completed successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Speaker status restored successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('❌ Automatic reconnection failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restore speaker status: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Schedule retry
      _scheduleReconnectionRetry();
      
    } finally {
      _isReconnecting = false;
    }
  }

  /// Restore WebRTC connection

  /// Verify speaker status is properly restored
  Future<void> _verifySpeakerStatus() async {
    // Wait a moment for state to settle
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Refresh participants again to ensure latest state
    await _loadParticipants();
    
    // Verify user is back in speakers panel
    final isSpeakerRestored = _speakerPanelists.any((speaker) => speaker.id == _currentUser?.id);
    final isModeratorRestored = _moderator?.id == _currentUser?.id;
    
    if (isSpeakerRestored || isModeratorRestored) {
      AppLogger().debug('✅ Speaker status verified - user restored to panel');
    } else {
      throw Exception('Speaker status not restored after reconnection');
    }
  }

  /// Schedule reconnection retry with exponential backoff
  void _scheduleReconnectionRetry() {
    final retryDelay = Duration(seconds: (2 * _connectionDropCount).clamp(5, 60));
    
    AppLogger().debug('⏰ Scheduling reconnection retry in ${retryDelay.inSeconds} seconds...');
    
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(retryDelay, () {
      if (mounted && !_isDisposing && !_isReconnecting) {
        AppLogger().debug('🔄 Executing scheduled reconnection retry...');
        _attemptAutomaticReconnection();
      }
    });
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }


  void _resumeWebAudioContext() async {
    if (kIsWeb) {
      // Resume web audio context for browser autoplay policy
      AppLogger().debug('🔊 Attempting to resume web audio context');
      // The actual implementation would depend on web-specific imports
      // For now, just trigger the audio activation
      if (_remoteStreams.isNotEmpty) {
        // Enable remote audio tracks to activate audio context
        for (final stream in _remoteStreams.values) {
          final audioTracks = stream.getAudioTracks();
          for (var track in audioTracks) {
            track.enabled = true;
          }
        }
      }
    }
  }

  Future<void> _toggleVideo() async {
    AppLogger().debug('🎥 _toggleVideo called - current state: $_isVideoEnabled, service connected: $_isWebRTCConnected');
    
    try {
      if (_isWebRTCConnected) {
        // Video not supported in Debates & Discussions (audio-only mode)
        AppLogger().debug('🎥 Video toggle not supported - Debates & Discussions are audio-only');
        
        if (mounted) {
          setState(() {
            _isVideoEnabled = false; // Video not supported
          });
        }
        
        AppLogger().debug('🎥 Video ${_isVideoEnabled ? 'enabled' : 'disabled'} - UI will ${_isVideoEnabled ? 'show video' : 'show avatar'}');
      } else {
        AppLogger().warning('🎥 Cannot toggle video - MediaSoup service not connected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for connection to establish before enabling video'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger().error('🎥 Error toggling video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _autoConnectAudio() {
    AppLogger().debug('🔥 AUTO-CONNECT: _autoConnectAudio() called - checking permissions for moderators/speakers only');
    AppLogger().debug('🔥 AUTO-CONNECT: Current user: ${_currentUser?.id}, isModerator: $_isCurrentUserModerator, isSpeaker: $_isCurrentUserSpeaker');
    AppLogger().debug('🔥 AUTO-CONNECT: Audio state - connected: $_isAudioConnected, connecting: $_isAudioConnecting');
    AppLogger().debug('🔥 AUTO-CONNECT: Participant roles: $_participantRoles');
    
    // Safety check - make sure we have current user data
    if (_currentUser == null) {
      AppLogger().warning('🔥 AUTO-CONNECT: ⚠️ Cannot auto-connect audio - current user is null');
      return;
    }
    
    // Only auto-connect for users with speaking permissions
    if (!_isCurrentUserModerator && !_isCurrentUserSpeaker) {
      AppLogger().debug('🔇 AUTO-CONNECT: Skipping auto-connect for audience member (listen-only)');
      return;
    }
    
    // FINAL ROLE CHECK: Verify role before connecting
    if (_currentUser != null) {
      final isInSpeakerPanel = _speakerPanelists.any((speaker) => speaker.id == _currentUser!.id);
      AppLogger().debug('🔥 AUTO-CONNECT: Final check - user in speaker panel: $isInSpeakerPanel');
      
      if (isInSpeakerPanel && !_isCurrentUserSpeaker && !_isCurrentUserModerator) {
        AppLogger().warning('🔥 AUTO-CONNECT: ⚠️ User in speaker panel but not marked as speaker - correcting role immediately');
        _isCurrentUserSpeaker = true;
      }
    }
    
    // Load participants first to set proper roles before connecting to audio
    AppLogger().debug('🔥 AUTO-CONNECT: Loading participants before audio connection...');
    _loadParticipants().then((_) {
      AppLogger().debug('🔥 AUTO-CONNECT: Participants loaded, proceeding with auto-connect for user: ${_currentUser!.name} (final role: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker)');
      return _connectToAudio();
    }).then((_) {
      AppLogger().debug('🔥 AUTO-CONNECT: _connectToAudio() completed successfully');
    }).catchError((error) {
      AppLogger().error('🔥 AUTO-CONNECT: Failed during participants load or audio connect: $error');
    });
  }

  /// Reinitialize audio connection for newly promoted speakers
  Future<void> _reinitializeAudioForSpeaker() async {
    try {
      AppLogger().debug('🔄 Reinitializing LiveKit audio connection for speaker role...');
      AppLogger().debug('🔄 Current state: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker');

      // Verify the speaker flag is set
      if (!_isCurrentUserSpeaker && !_isCurrentUserModerator) {
        AppLogger().error('❌ Cannot reinitialize audio for speaker - user is not marked as speaker/moderator!');
        return;
      }

      // Disconnect existing audio service if connected
      if (_isAudioConnected) {
        AppLogger().debug('🔌 Disconnecting existing LiveKit audio connection...');
        await _liveKitService.disconnect();
        if (mounted) {
          setState(() {
            _isAudioConnected = false;
            _isAudioConnecting = false;
          });
        }
      }

      // Brief delay to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 500));

      // Double-check role before reconnecting
      final expectedRole = _computeInitialRole();
      AppLogger().debug('🔄 Expected role for reconnection: $expectedRole');

      if (expectedRole == 'audience') {
        AppLogger().error('❌ Role mismatch - computed role is "audience" but should be speaker/moderator!');
        AppLogger().error('❌ State: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker');
        return;
      }

      // Reconnect with speaker role
      AppLogger().debug('🎤 Reconnecting with $expectedRole role...');
      await _connectToAudio();

      AppLogger().debug('✅ Audio reinitialization complete');

    } catch (e) {
      AppLogger().error('❌ Error reinitializing LiveKit audio for speaker: $e');
      // Continue anyway - user can try manual connect
    }
  }
  
  void _debugVideoState() {
    AppLogger().debug('=== VIDEO DEBUG STATE ===');
    AppLogger().debug('🎥 Current user role: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker');
    AppLogger().debug('🎥 Video enabled: $_isVideoEnabled');
    AppLogger().debug('🎥 WebRTC connected: $_isWebRTCConnected');
    AppLogger().debug('🎥 WebRTC connected: $_isWebRTCConnected');
    AppLogger().debug('🎥 Local stream: ${_localStream != null}');
    if (_localStream != null) {
      AppLogger().debug('🎥 Local video tracks: ${_localStream!.getVideoTracks().length}');
      AppLogger().debug('🎥 Local audio tracks: ${_localStream!.getAudioTracks().length}');
    }
    AppLogger().debug('🎥 Remote streams: ${_remoteStreams.length}');
    AppLogger().debug('🎥 Speaker panelists: ${_speakerPanelists.length}');
    AppLogger().debug('🎥 User to peer mappings: $_userToPeerMapping');
    AppLogger().debug('🎥 Peer to user mappings: $_peerToUserMapping');
    AppLogger().debug('🎥 Remote renderers: ${_remoteRenderers.keys.join(', ')}');
    AppLogger().debug('========================');
  }


  Future<void> _initializeRoom() async {
    try {
      AppLogger().debug('🏠 Initializing Debates & Discussions room: ${widget.roomId}');

      // Get current user
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        final userProfile = await _batchProfileService.getUserProfile(user.$id);
        if (mounted && !_isDisposing) {
          setState(() {
            _currentUser = userProfile;
          });
        }
        AppLogger().debug('👤 Current user loaded: ${userProfile?.name}');
      }
      
      // Load room data
      await _loadRoomData();
      
      // Join the room as a participant
      AppLogger().debug('Current user check - _currentUser: ${_currentUser?.name}');
      if (_currentUser != null) {
        await _joinRoom();
      } else {
        AppLogger().error('_currentUser is null, cannot join room');
      }
      
      // Clear any cached participant data to ensure fresh load
      invalidateNetworkCache(patternPrefix: 'participants_');

      // Preload participant profiles for optimal performance
      await _preloadParticipantProfiles();

      // Load participants from database
      await _loadParticipants();
      
      // Set up real-time subscriptions
      _setupRealTimeUpdates();

      // Play room joined audio feedback
      _playAudioFeedback('room_joined');
      
      // Setup Firebase real-time participant sync (temporarily disabled)
      // _setupFirebaseParticipantSync();
      
      // Sync initial participants to Firebase (temporarily disabled)
      // await _syncAllParticipantsToFirebase();
      
      // Start periodic participant synchronization to ensure consistency
      _startPeriodicParticipantSync();
      
      // RACE CONDITION FIX: Longer delay to ensure fallback role checks complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      // DEBUG: Check role states before auto-connecting
      AppLogger().debug('🔍 PRE-AUDIO-CONNECT DEBUG:');
      AppLogger().debug('🔍 Current user: ${_currentUser?.id} (${_currentUser?.name})');
      AppLogger().debug('🔍 _isCurrentUserModerator: $_isCurrentUserModerator');
      AppLogger().debug('🔍 _isCurrentUserSpeaker: $_isCurrentUserSpeaker');
      AppLogger().debug('🔍 Participant roles map: $_participantRoles');
      AppLogger().debug('🔍 Speaker panel members: ${_speakerPanelists.map((s) => s.id).toList()}');
      if (_currentUser != null) {
        final currentUserRole = _participantRoles[_currentUser!.id];
        AppLogger().debug('🔍 Current user role in map: $currentUserRole');
        final isInSpeakerPanel = _speakerPanelists.any((speaker) => speaker.id == _currentUser!.id);
        AppLogger().debug('🔍 Current user in speaker panel: $isInSpeakerPanel');
      }
      
      // Auto-connect all users to audio (now with correct roles)
      AppLogger().debug('🚀 About to call _autoConnectAudio() after role determination...');
      _autoConnectAudio();
      AppLogger().debug('✅ _autoConnectAudio() call completed');
      
      // Room initialization complete
      if (mounted && !_isDisposing) {
        setState(() {
          _isLoading = false;
        });
      }
      
      AppLogger().debug('✅ Room initialization complete');
      
    } catch (e) {
      AppLogger().error('❌ Room initialization failed: $e');
      if (mounted && !_isDisposing) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRoomData() async {
    try {
      AppLogger().debug('📦 Loading room data for: ${widget.roomId}');
      
      // Optimize room data request with caching
      final roomData = await optimizedNetworkRequest(
        requestId: 'room_data_${widget.roomId}',
        requestBuilder: () => _appwrite.getDebateDiscussionRoom(widget.roomId),
        cacheExpiry: const Duration(minutes: 2),
      );
      
      if (roomData != null && mounted && !_isDisposing) {
        // Use optimized state update
        final optimizedRoomData = _performanceOptimizer.optimizeProvider(
          'room_data_${widget.roomId}', 
          roomData,
        );
        setState(() {
          _roomData = optimizedRoomData;

          // Initialize queue state from room data (default to true if not set)
          if (roomData['queueEnabled'] != null) {
            _queueEnabled = roomData['queueEnabled'];
            AppLogger().debug('🔄 Loaded queue state from database: $_queueEnabled');
          } else {
            // Default to enabled for new rooms or rooms without this field
            _queueEnabled = true;
            AppLogger().debug('🔄 No queue state in database, defaulting to enabled');
          }
        });
        
        // Load moderator profile if available
        final moderatorId = roomData['createdBy'];
        if (moderatorId != null) {
          final moderatorProfile = await optimizedNetworkRequest(
            requestId: 'moderator_$moderatorId',
            requestBuilder: () => _appwrite.getUserProfile(moderatorId),
            cacheExpiry: const Duration(minutes: 5),
          );
          if (moderatorProfile != null && mounted && !_isDisposing) {
            setState(() {
              _moderator = moderatorProfile;
            });
          }
        }
        
        AppLogger().debug('✅ Room data loaded: ${roomData['name']}');
        AppLogger().info('📊 ROOM DATA LOADED - Room style: ${roomData['debateStyle']}');
        
        // Initialize materials service now that we have room data
        AppLogger().info('📊 ROOM DATA LOADED - Attempting to initialize materials service');
        _initializeMaterialsService();
      }
    } catch (e) {
      AppLogger().error('❌ Error loading room data: $e');
      // Continue with initialization even if room data fails
    }
  }

  Future<void> _joinRoom() async {
    try {
      if (_currentUser == null) {
        AppLogger().warning('Cannot join room - no current user');
        return;
      }
      
      AppLogger().debug('🚪 Joining Debates & Discussions room: ${widget.roomId}');
      
      // Determine initial role - creator is moderator, others start as audience
      final isCreator = _roomData?['createdBy'] == _currentUser!.id;
      final initialRole = isCreator ? 'moderator' : 'audience';
      
      // Join the room in the database
      await _appwrite.joinDebateDiscussionRoom(
        roomId: widget.roomId,
        userId: _currentUser!.id,
        role: initialRole,
      );
      
      if (mounted && !_isDisposing) {
        setState(() {
          _isJoined = true;
          if (isCreator) {
            _isCurrentUserModerator = true;
          }
        });
      }
      
      AppLogger().debug('✅ Joined room ${widget.roomId} as $initialRole');

      // Start AI moderation for this room
      await _aiModerationService.startRoomMonitoring(widget.roomId);
      AppLogger().info('🛡️ AI moderation started for Debates & Discussions room: ${widget.roomId}');

      // Check if user is timed out
      await _checkTimeoutStatus();

      // Immediately refresh participants to ensure this user appears in all other users' screens
      Future.microtask(() async {
        if (mounted && !_isDisposing) {
          await _loadParticipants();
        }
      });
    } catch (e) {
      AppLogger().error('❌ Error joining room: $e');

      // Check if user is banned
      if (e.toString().contains('You are banned from this room')) {
        AppLogger().warning('🚫 User is banned from room - navigating to home');

        // Show ban modal to user
        if (mounted && !_isDisposing) {
          await _showRemovalModal();

          // Navigate back to home screen
          if (mounted && !_isDisposing) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
        return; // Don't continue with room initialization
      }

      // For other errors, continue anyway - user might already be in room
      if (mounted && !_isDisposing) {
        setState(() {
          _isJoined = true; // Allow room to continue loading
        });
      }
    }
  }

  void _showUserProfileModal(UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserProfileBottomSheet(
        user: user,
        roomId: widget.roomId,
        roomType: 'debate_discussion',
        isCurrentUserModerator: _isCurrentUserModerator,
        onFollow: () {
          // TODO: Implement follow functionality
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Following ${user.name}'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
        onChallenge: () {
          // Challenge functionality is now handled directly by UserProfileBottomSheet
          AppLogger().debug('Challenge functionality delegated to UserProfileBottomSheet');
        },
        onEmail: () {
          if (mounted && _currentUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailComposeScreen(
                  currentUserId: _currentUser!.id,
                  currentUsername: _currentUser!.name,
                  recipient: user,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Check if current user is timed out
  Future<void> _checkTimeoutStatus() async {
    if (_currentUser == null) return;

    try {
      final timeoutService = UserTimeoutService();
      final isTimedOut = await timeoutService.isUserTimedOut(_currentUser!.id, widget.roomId);

      // If status changed from not timed out to timed out, show modal
      if (mounted && !_isCurrentUserTimedOut && isTimedOut) {
        final remainingMinutes = await timeoutService.getRemainingTimeoutMinutes(_currentUser!.id, widget.roomId);

        setState(() {
          _isCurrentUserTimedOut = isTimedOut;
        });

        // Show timeout modal
        if (mounted) {
          _showTimeoutModal(remainingMinutes ?? 0);
        }
      } else if (mounted && _isCurrentUserTimedOut != isTimedOut) {
        setState(() {
          _isCurrentUserTimedOut = isTimedOut;
        });
      }
    } catch (e) {
      AppLogger().error('Error checking timeout status: $e');
    }
  }

  /// Show timeout notification modal
  void _showTimeoutModal(int remainingMinutes) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.timer,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'You\'ve Been Timed Out',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$remainingMinutes minute${remainingMinutes != 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You cannot:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.mic_off, size: 14, color: Colors.black54),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Speak or unmute',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 14, color: Colors.black54),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Send messages',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can still listen. Privileges will be restored when timeout expires.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showDebateParticipantOptions(UserProfile user) {
    final currentRole = _participantRoles[user.id] ?? 'speaker';
    final hasAffirmative = _participantRoles.values.contains('affirmative');
    final hasNegative = _participantRoles.values.contains('negative');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage ${user.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current position: ${currentRole == 'affirmative' ? 'Affirmative' : currentRole == 'negative' ? 'Negative' : 'Speaker'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text('Choose new position:'),
            const SizedBox(height: 8),
            // Move to Affirmative
            if (currentRole != 'affirmative')
              ListTile(
                leading: Icon(
                  Icons.thumb_up,
                  color: hasAffirmative ? Colors.grey : Colors.green,
                ),
                title: Text(
                  'Assign to Affirmative',
                  style: TextStyle(
                    color: hasAffirmative ? Colors.grey : Colors.black,
                  ),
                ),
                subtitle: Text(hasAffirmative ? 'Position occupied' : 'Argues FOR the topic'),
                enabled: !hasAffirmative,
                onTap: hasAffirmative ? null : () {
                  Navigator.pop(context);
                  _assignUserToRole(user, 'affirmative');
                },
              ),
            // Move to Negative
            if (currentRole != 'negative')
              ListTile(
                leading: Icon(
                  Icons.thumb_down,
                  color: hasNegative ? Colors.grey : Colors.red,
                ),
                title: Text(
                  'Assign to Negative',
                  style: TextStyle(
                    color: hasNegative ? Colors.grey : Colors.black,
                  ),
                ),
                subtitle: Text(hasNegative ? 'Position occupied' : 'Argues AGAINST the topic'),
                enabled: !hasNegative,
                onTap: hasNegative ? null : () {
                  Navigator.pop(context);
                  _assignUserToRole(user, 'negative');
                },
              ),
            // Remove from debate panel
            ListTile(
              leading: const Icon(Icons.remove_circle, color: Colors.orange),
              title: const Text('Move to Audience'),
              subtitle: const Text('Remove from debate panel'),
              onTap: () {
                Navigator.pop(context);
                _assignUserToRole(user, 'audience');
              },
            ),
            // View Profile
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                _showUserProfileModal(user);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAudiencePromotionOptions(UserProfile user) {
    final hasAffirmative = _participantRoles.values.contains('affirmative');
    final hasNegative = _participantRoles.values.contains('negative');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Promote ${user.name} to Debate Position'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose which debate position to assign:'),
            const SizedBox(height: 16),
            // Promote to Affirmative
            ListTile(
              leading: Icon(
                Icons.thumb_up,
                color: hasAffirmative ? Colors.grey : Colors.green,
              ),
              title: Text(
                'Promote to Affirmative',
                style: TextStyle(
                  color: hasAffirmative ? Colors.grey : Colors.black,
                ),
              ),
              subtitle: Text(hasAffirmative ? 'Position already occupied' : 'Argues FOR the topic'),
              enabled: !hasAffirmative,
              onTap: hasAffirmative ? null : () {
                Navigator.pop(context);
                _assignUserToRole(user, 'affirmative');
              },
            ),
            // Promote to Negative
            ListTile(
              leading: Icon(
                Icons.thumb_down,
                color: hasNegative ? Colors.grey : Colors.red,
              ),
              title: Text(
                'Promote to Negative',
                style: TextStyle(
                  color: hasNegative ? Colors.grey : Colors.black,
                ),
              ),
              subtitle: Text(hasNegative ? 'Position already occupied' : 'Argues AGAINST the topic'),
              enabled: !hasNegative,
              onTap: hasNegative ? null : () {
                Navigator.pop(context);
                _assignUserToRole(user, 'negative');
              },
            ),
            const Divider(),
            // View Profile option
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                _showUserProfileModal(user);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWebRTCVideoContent(UserProfile participant, bool isModerator) {
    // Check if this participant has a video stream
    bool hasVideo = false;
    Widget? videoWidget;
    
    // Check local video for current user
    if (participant.id == _currentUser?.id) {
      // Show local video only if current user is moderator or speaker AND video is enabled
      if ((_isCurrentUserModerator || _isCurrentUserSpeaker) &&
          _localStream != null && 
          _localStream!.getVideoTracks().isNotEmpty &&
          _isVideoEnabled) {
        videoWidget = RTCVideoView(_localRenderer, mirror: true);
        hasVideo = true;
        AppLogger().debug('🎥 Showing local video for ${participant.name}');
      }
    } else {
      // For remote participants, use the user-to-peer mapping
      final peerId = _userToPeerMapping[participant.id];
      
      if (peerId != null && _remoteRenderers.containsKey(peerId)) {
        final renderer = _remoteRenderers[peerId]!;
        try {
          if (renderer.srcObject != null) {
            final stream = renderer.srcObject!;
            final videoTracks = stream.getVideoTracks();
            if (videoTracks.isNotEmpty) {
              videoWidget = RTCVideoView(renderer);
              hasVideo = true;
              AppLogger().debug('🎥 Showing remote video for ${participant.name} (peer: $peerId)');
            }
          }
        } catch (e) {
          AppLogger().warning('Error showing video for ${participant.name}: $e');
        }
      } else {
        AppLogger().debug('🎥 No video stream found for ${participant.name} (userId: ${participant.id})');
        if (peerId == null) {
          AppLogger().debug('🎥 No peer mapping found for user ${participant.id}');
        } else {
          AppLogger().debug('🎥 Peer $peerId found but no renderer');
        }
      }
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasVideo && videoWidget != null
          ? Stack(
              children: [
                SizedBox.expand(child: videoWidget),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: CircleAvatar(
                radius: isModerator ? 32 : 24,
                backgroundColor: const Color(0xFF8B5CF6),
                backgroundImage: participant.avatar != null && participant.avatar!.isNotEmpty
                    ? NetworkImage(participant.avatar!)
                    : null,
                child: participant.avatar == null || participant.avatar!.isEmpty
                    ? _buildAvatarText(participant, isModerator ? 18 : 14)
                    : null,
              ),
            ),
      ),
    );
  }

  /// Start intelligent participant synchronization that adapts to issues
  void _startPeriodicParticipantSync() {
    int consecutiveFailures = 0;
    int lastParticipantCount = 0;
    
    // Ultra-aggressive sync for immediate participant visibility (5-second intervals)
    _participantSyncTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted && !_isDisposing) {
        // Check timeout status periodically
        _checkTimeoutStatus();

        try {
          final currentCount = _audienceMembers.length + _speakerPanelists.length;
          
          // Detect potential issues
          bool needsSync = false;
          
          // 1. No participants at all (suspicious)
          if (currentCount == 0) {
            AppLogger().warning('⚠️ Empty participant list detected - forcing sync');
            needsSync = true;
          }
          
          // 2. Participant count dropped significantly (possible disconnect)
          if (currentCount < lastParticipantCount - 1 && lastParticipantCount > 2) {
            AppLogger().warning('⚠️ Participant count dropped from $lastParticipantCount to $currentCount - forcing sync');
            needsSync = true;
          }
          
          // 3. Regular maintenance sync less frequently
          if (timer.tick % 4 == 0) { // Every 3 minutes (45s * 4)
            AppLogger().debug('🔄 Regular maintenance sync');
            needsSync = true;
          }
          
          if (needsSync) {
            // Force refresh participants from database
            invalidateNetworkCache(patternPrefix: 'participants_');
            await _loadParticipants();
            
            consecutiveFailures = 0;
            lastParticipantCount = _audienceMembers.length + _speakerPanelists.length;
            
            AppLogger().debug('✅ Smart sync completed - ${_audienceMembers.length} audience, ${_speakerPanelists.length} speakers');
          } else {
            AppLogger().debug('🔍 Participant sync check - no issues detected ($currentCount participants)');
          }
          
        } catch (e) {
          consecutiveFailures++;
          AppLogger().warning('Smart participant sync failed ($consecutiveFailures consecutive): $e');
          
          // If we have multiple failures, try to reconnect real-time subscription
          if (consecutiveFailures >= 3) {
            AppLogger().error('🔥 Multiple sync failures - reconnecting real-time subscription');
            _reconnectParticipantsSubscription();
            consecutiveFailures = 0;
          }
        }
      }
    });
    trackTimer('participant_sync', _participantSyncTimer!);

    AppLogger().info('🚀 Started periodic participant synchronization (every 15s)');
  }

  // Handle app lifecycle changes for automatic refresh
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isDisposing) {
      // App came back to foreground - refresh participants in case we missed updates
      AppLogger().info('🔄 App resumed - refreshing participants to ensure sync');
      Future.microtask(() async {
        try {
          invalidateNetworkCache(patternPrefix: 'participants_');
          await _loadParticipants();
        } catch (e) {
          AppLogger().warning('App resume participant refresh failed: $e');
        }
      });
    }
  }
  
  @override
  void dispose() {
    _isDisposing = true;

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // CRITICAL: Remove participant from room when leaving
    if (_isJoined && _currentUser != null) {
      AppLogger().info('🚪 User leaving room - removing from participants');
      _appwrite.leaveDebateDiscussionRoom(
        roomId: widget.roomId,
        userId: _currentUser!.id,
      ).catchError((e) {
        AppLogger().error('Failed to leave room cleanly: $e');
      });
    }


    // Clean up consolidated subscriptions
    _realtimeManager.unsubscribeFromRoom(widget.roomId);
    _participantStreamListener?.cancel();
    _chatStreamListener?.cancel();
    _roomStatusStreamListener?.cancel();
    _handRaiseStreamListener?.cancel();
    _timerStreamListener?.cancel();
    _materialStreamListener?.cancel();

    // Legacy subscriptions
    _unreadMessagesSubscription?.cancel();
    _firebaseParticipantSubscription?.cancel();
    _materialUpdatesSubscription?.cancel();
    _sourceAddedSubscription?.cancel();

    // Speaker queue subscription
    _speakerQueueSubscription?.close();

    // Reactions subscription
    _reactionsSubscription?.close();

    // Clean up Firebase when leaving room (temporarily disabled)
    // _firebaseSync.clearRoom(widget.roomId);
    
    // Clean up performance optimizations
    PerformanceOptimizations.dispose();
    _performanceOptimizer.clearCache();
    _listOptimizer.disposeList('debates_${widget.roomId}');
    _networkOptimizer.invalidateCache(patternPrefix: widget.roomId);
    
    // Stop connection health monitoring
    _stopConnectionHealthMonitoring();
    _reconnectionTimer?.cancel();
    _participantSyncTimer?.cancel();
    
    // Stop AI moderation
    _aiModerationService.stopRoomMonitoring(widget.roomId);

    // Clean up diff manager
    _diffManager.clearRoom(widget.roomId);

    // Clean up granular state manager
    _granularStateManager.dispose();

    // Log batch profile service statistics before cleanup
    _batchProfileService.logStatistics();

    // Remove LiveKit service listener to prevent memory leaks
    _liveKitService.removeListener(_onLiveKitStateChanged);

    // Clean up audio connection
    if (_liveKitService.isConnected) {
      _liveKitService.disconnect();
    }
    
    // Dispose material sync service
    _materialSyncService?.dispose();
    
    // Clean up performance optimizations
    OptimizedStateManager.clearKey('participants_${widget.roomId}');
    OptimizedParticipantManager.clearKey('audience_${widget.roomId}');
    OptimizedParticipantManager.clearKey('speakers_${widget.roomId}');
    
    // Disable ultra-performance mode
    UltraPerformanceMode.instance.disable();
    
    // Disable extreme performance mode
    ExtremePerformanceMode.instance.disable();
    
    // Don't await room leaving in dispose as it's synchronous
    // Just call it without awaiting to start the process
    // Clean up all tracked disposable resources
    disposeTrackedResources();

    // Clean up weak references
    cleanupWeakReferences();

    _performLeaveRoom().catchError((error) {
      AppLogger().error('Error during disposal: $error');
    });
    super.dispose();
  }

  /// Configure audio for maximum volume and speaker output
  Future<void> _configureAudio() async {
    try {
      // Configure loud speaker audio
      await _audioVolumeService.configureLoudAudio();
      AppLogger().info('🔊 Audio configured for maximum volume in Debates & Discussions');
    } catch (e) {
      AppLogger().error('Failed to configure audio: $e');
    }
  }

  Future<void> _connectToAudio() async {
    AppLogger().debug('🔥 CONNECT-AUDIO: _connectToAudio called - connecting: $_isAudioConnecting, connected: $_isAudioConnected');
    
    // Don't connect if already connected or connecting
    if (_isAudioConnected || _isAudioConnecting) {
      AppLogger().debug('🔥 CONNECT-AUDIO: ⚠️ Audio connection skipped - already connecting or connected');
      return;
    }
    
    AppLogger().debug('🔥 CONNECT-AUDIO: 🚀 Starting audio connection process...');
    setState(() {
      _isAudioConnecting = true;
    });

    // ✅ Compute role synchronously - no race conditions
    String userRole = _computeInitialRole();
    AppLogger().debug('🎯 INITIAL ROLE for token: "$userRole"');
    
    // SAFETY CHECK: If user should have audio permissions but is computed as audience, 
    // this indicates a timing/state sync issue - force moderator for room creators
    if (userRole == 'audience' && _roomData != null && _currentUser != null) {
      final isCreator = _roomData!['createdBy'] == _currentUser!.id;
      if (isCreator) {
        AppLogger().warning('🚨 ROLE OVERRIDE: Creator detected as audience - forcing moderator role for audio connection');
        _isCurrentUserModerator = true;
        if (mounted) {
          setState(() {
            // Update UI after correcting moderator status
          });
        }
        // Recompute role with corrected state
        userRole = _computeInitialRole();
        AppLogger().debug('🎯 CORRECTED ROLE for token: "$userRole"');
      }
    }

    try {
      final roomId = 'debates-discussion-${widget.roomId}';
      
      // Ensure we have a valid user ID, never use 'unknown'
      if (_currentUser?.id == null || _currentUser!.id.isEmpty) {
        throw Exception('Cannot connect to audio without a valid user ID');
      }
      final userId = _currentUser!.id;
      
      AppLogger().debug('🔥 CONNECT-AUDIO: 🎤 Connecting to LiveKit Audio for Debates & Discussions');
      AppLogger().debug('🔥 CONNECT-AUDIO: 🎤 Room: $roomId, User: $userId, Role: $userRole');
      
      // Generate LiveKit token
      AppLogger().debug('🔥 CONNECT-AUDIO: 🔑 Generating LiveKit token for $userId with role $userRole');
      final token = LiveKitTokenService.generateToken(
        roomName: roomId,
        identity: userId,
        userRole: userRole,
        roomType: _getRoomTypeForLiveKit(),
        userId: userId,
        ttl: const Duration(hours: 2),
      );
      AppLogger().debug('🔥 CONNECT-AUDIO: 🔑 Generated LiveKit token successfully: ${token.substring(0, 50)}...');
      AppLogger().debug('🔥 CONNECT-AUDIO: 🔑 Token contains role: $userRole');
      
      // Debug token to verify role permissions (development only)
      if (kDebugMode) {
        TokenDebugger.debugToken(token, label: 'Debates & Discussions - $userRole');
        
        // Additional verification: print decoded token payload
        final metadata = LiveKitTokenService.getTokenMetadata(token);
        AppLogger().debug('🔍 TOKEN METADATA: $metadata');
      }
      
      // Connect using LiveKit service with Arena's memory management
      await _liveKitService.connect(
        serverUrl: LiveKitConfigService.instance.effectiveServerUrl,
        roomName: roomId,
        token: token,
        userId: userId,
        userRole: userRole,
        roomType: _getRoomTypeForLiveKit(),
      );
      
      AppLogger().debug('🔥 CONNECT-AUDIO: ✅ Audio connected successfully as $userRole');
      AppLogger().debug('🔥 CONNECT-AUDIO: ✅ LiveKit service connected: ${_liveKitService.isConnected}');
      AppLogger().debug('🔥 CONNECT-AUDIO: ✅ LiveKit service role: ${_liveKitService.userRole}');
      
      // Log server-granted permissions for verification  
      await Future.delayed(const Duration(milliseconds: 500)); // Allow connection to stabilize
      final room = _liveKitService.room;
      final perms = room?.localParticipant?.permissions;
      if (perms != null) {
        AppLogger().debug('🔐 SERVER PERMS: canPublish=${perms.canPublish}, canSubscribe=${perms.canSubscribe}');
      } else {
        AppLogger().debug('⚠️ SERVER PERMS: Could not retrieve permissions (room or participant null)');
      }
      
      if (mounted) {
        setState(() {
          _isAudioConnected = true;
          _isAudioConnecting = false;
          _isMuted = _liveKitService.isMuted;
        });
        AppLogger().debug('🔥 CONNECT-AUDIO: ✅ UI state updated - connected: $_isAudioConnected, muted: $_isMuted');
        
        // Reinitialize materials service now that LiveKit room is connected
        if (_roomData?['debateStyle'] == 'Debate' && _liveKitService.room != null) {
          AppLogger().info('📊 🔥 LIVEKIT CONNECTED - Reinitializing materials service with connected LiveKit room');
          AppLogger().info('📊 🔥 Room style: ${_roomData?['debateStyle']}, LiveKit room: ${_liveKitService.room != null}');
          // Dispose old service if it exists
          if (_materialSyncService != null) {
            AppLogger().info('📊 🔥 Disposing existing materials service');
            _materialUpdatesSubscription?.cancel();
            _sourceAddedSubscription?.cancel();
            _materialSyncService?.dispose();
          }
          _initializeMaterialsService();
        } else {
          AppLogger().warning('📊 🔥 LIVEKIT CONNECTED - NOT reinitializing materials: debateStyle=${_roomData?['debateStyle']}, room=${_liveKitService.room != null}');
        }
      }
      
    } catch (e) {
      AppLogger().error('🔥 CONNECT-AUDIO: ❌ Failed to connect to audio: $e');
      
      // Enhanced error handling similar to Arena
      final errorString = e.toString().toLowerCase();
      String userMessage = 'Failed to connect to audio. Please try again.';
      
      if (errorString.contains('memory') || errorString.contains('pthread') || errorString.contains('native crash')) {
        userMessage = 'Memory error: Please close other apps and try again.';
      } else if (errorString.contains('timeout') || errorString.contains('network')) {
        userMessage = 'Connection timeout: Please check your internet and try again.';
      } else if (errorString.contains('token') || errorString.contains('auth')) {
        userMessage = 'Authentication error: Please restart the app.';
      }
      
      if (mounted) {
        setState(() {
          _isAudioConnecting = false;
          _isAudioConnected = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _connectToAudio(),
            ),
          ),
        );
      }
    }
  }


  Future<void> _loadParticipants() async {
    try {
      AppLogger().debug('Loading participants for room: ${widget.roomId}');
      
      
      // Optimize network request with shorter cache for faster role updates
      final participants = await optimizedNetworkRequest(
        requestId: 'participants_${widget.roomId}',
        requestBuilder: () => _appwrite.getDebateDiscussionParticipants(widget.roomId),
        cacheExpiry: const Duration(seconds: 5), // Shorter cache for real-time updates
      );
      
      if (mounted && !_isDisposing) {
        // Check if participants actually changed to avoid unnecessary rebuilds
        if (!PerformanceOptimizations.participantsChanged(_lastParticipants, participants)) {
          AppLogger().debug('Participants unchanged, skipping rebuild');
          return;
        }
        _lastParticipants = List.from(participants);
        
        // Use batched operations to minimize UI updates
        final List<VoidCallback> operations = [];
        
        operations.add(() {
          _speakerPanelists.clear();
          _audienceMembers.clear();
          _speakerRequests.clear();
          
          // Reset current user status flags
          _isCurrentUserModerator = false;
          _isCurrentUserSpeaker = false;
          _hasRequestedSpeaker = false;
        });
        
        // Process participants efficiently
        final List<UserProfile> newSpeakers = [];
        final List<UserProfile> newAudience = [];
        final List<UserProfile> newRequests = [];
        
        for (var participant in participants) {
          final userProfileData = participant['userProfile'];
          if (userProfileData != null) {
            final userProfile = UserProfile.fromMap(userProfileData);
            final role = participant['role'] ?? 'audience';
            
            // Store role mapping for this participant
            _participantRoles[userProfile.id] = role;
            
            // Efficiently sort participants by role
            if (role == 'moderator') {
              if (!newSpeakers.any((p) => p.id == userProfile.id)) {
                newSpeakers.add(userProfile);
              }
              if (userProfile.id == _currentUser?.id) {
                AppLogger().debug('🔍 ROLE ASSIGNMENT: Adding moderator operation for ${userProfile.name}');
                operations.add(() {
                  _isCurrentUserModerator = true;
                  AppLogger().debug('🔍 ROLE ASSIGNMENT: Set _isCurrentUserModerator = true');
                });
              }
            } else if (role == 'speaker' || role == 'affirmative' || role == 'negative') {
              if (!newSpeakers.any((p) => p.id == userProfile.id)) {
                newSpeakers.add(userProfile);
              }
              if (userProfile.id == _currentUser?.id) {
                AppLogger().info('🎤 SPEAKER ROLE: Current user found as speaker with role: $role');
                AppLogger().debug('🔍 ROLE ASSIGNMENT: Adding speaker operation for ${userProfile.name}');
                operations.add(() {
                  _isCurrentUserSpeaker = true;
                  AppLogger().debug('🔍 ROLE ASSIGNMENT: Set _isCurrentUserSpeaker = true');
                });
              }
            } else if (role == 'pending') {
              if (!newRequests.any((p) => p.id == userProfile.id)) {
                newRequests.add(userProfile);
              }
              if (!newAudience.any((p) => p.id == userProfile.id)) {
                newAudience.add(userProfile);
              }
              if (userProfile.id == _currentUser?.id) {
                operations.add(() => _hasRequestedSpeaker = true);
              }
            } else {
              if (!newAudience.any((p) => p.id == userProfile.id)) {
                newAudience.add(userProfile);
              }
            }
          }
        }
        
        // Add final operation to update all lists at once
        operations.add(() {
          _speakerPanelists.addAll(newSpeakers);
          _audienceMembers.addAll(newAudience);
          _speakerRequests.addAll(newRequests);
        });
        
        // RACE CONDITION FIX: Execute role operations immediately instead of batching
        // This ensures role flags are set before _autoConnectAudio() is called
        AppLogger().debug('🔍 IMMEDIATE OPERATIONS: About to execute ${operations.length} operations immediately');
        for (final operation in operations) {
          operation();
        }
        AppLogger().debug('🔍 IMMEDIATE OPERATIONS: All operations completed immediately');
        
        // Single setState for UI update
        if (mounted) {
          setState(() {
            // Update UI after participant role change
          });
        }
        
        // Preload avatar images for better scroll performance
        final avatarUrls = newAudience.map((p) => p.avatar).toList() +
                          newSpeakers.map((p) => p.avatar).toList() +
                          newRequests.map((p) => p.avatar).toList();
        PerformanceOptimizations.preloadAvatarImages(avatarUrls, context);
      }
      
      // ENHANCED FALLBACK: If current user is in the speaker panelists but not marked as speaker, mark them as speaker
      // This handles cases where guest speakers might not have explicit roles but are on the panel
      if (_currentUser != null) {
        bool isInSpeakerPanel = _speakerPanelists.any((speaker) => speaker.id == _currentUser!.id);
        AppLogger().debug('🔍 FALLBACK CHECK: User in speaker panel: $isInSpeakerPanel, isModerator: $_isCurrentUserModerator, isSpeaker: $_isCurrentUserSpeaker');
        AppLogger().debug('🔍 FALLBACK CHECK: Speaker panel contains: ${_speakerPanelists.map((s) => s.id).toList()}');
        AppLogger().debug('🔍 FALLBACK CHECK: Current user ID: ${_currentUser!.id}');
        
        if (!_isCurrentUserModerator && !_isCurrentUserSpeaker && isInSpeakerPanel) {
          AppLogger().info('🎤 FALLBACK: Current user found in speaker panel without explicit speaker role - granting speaker permissions');
          _isCurrentUserSpeaker = true;
          
          // CRITICAL: Reinitialize LiveKit connection with speaker role
          AppLogger().info('🔄 FALLBACK: Speaker detected - reinitializing audio connection with speaker role');
          await _reinitializeAudioForSpeaker();
        }
        
        // ADDITIONAL CHECK: Even if user thinks they're a speaker, verify they're actually on the panel
        if (_isCurrentUserSpeaker && !isInSpeakerPanel && !_isCurrentUserModerator) {
          AppLogger().warning('⚠️ ROLE MISMATCH: User marked as speaker but not in speaker panel - reverting to audience');
          _isCurrentUserSpeaker = false;
        }
      }
      
      AppLogger().debug('Loaded ${participants.length} participants: ${_speakerPanelists.length} speakers, ${_audienceMembers.length} audience, ${_speakerRequests.length} pending requests');
      AppLogger().debug('📈 PARTICIPANT SUMMARY: Total=${participants.length}, Speakers=${_speakerPanelists.length}, Audience=${_audienceMembers.length}, Pending=${_speakerRequests.length}');
      
      // Enhanced debugging: Log all participant IDs and roles
      if (participants.isNotEmpty) {
        final participantSummary = participants.map((p) => {
          'id': p['userProfile']?['userId'] ?? p['userProfile']?['id'] ?? 'unknown',
          'name': p['userProfile']?['name'] ?? 'unknown',
          'role': p['role'] ?? 'unknown'
        }).toList();
        AppLogger().debug('📈 DETAILED PARTICIPANTS: $participantSummary');
      } else {
        AppLogger().warning('⚠️ EMPTY PARTICIPANT LIST for room ${widget.roomId}');
      }
      AppLogger().info('🎤 ROLE DEBUG: Current user status: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker, requested=$_hasRequestedSpeaker');
      
      // Additional debug: Show current user's actual role in database
      if (_currentUser != null) {
        final currentUserParticipant = participants.firstWhere(
          (p) => p['userProfile']?['userId'] == _currentUser!.id || p['userProfile']?['id'] == _currentUser!.id,
          orElse: () => <String, dynamic>{},
        );
        final currentUserRole = currentUserParticipant['role'] ?? 'not found';
        AppLogger().info('🎤 ROLE DEBUG: Current user database role: $currentUserRole');
        AppLogger().info('🎤 ROLE DEBUG: Current user in speaker panel: ${_speakerPanelists.any((s) => s.id == _currentUser!.id)}');

        // CHECK: If current user is not in participants list, they were kicked/banned
        if (currentUserRole == 'not found' && mounted && !_isDisposing) {
          AppLogger().warning('🚪 Current user not found in participants - was removed (kicked/banned) - navigating to home screen');

          // Clean up LiveKit connection before navigating
          try {
            await _liveKitService.disconnect();
          } catch (e) {
            AppLogger().error('Error disconnecting LiveKit after kick: $e');
          }

          // Show modal with kick/ban details
          await _showRemovalModal();

          // Navigate to home screen
          if (mounted && !_isDisposing) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }

          // Return early - don't continue with audio connection
          return;
        }
      }
      
      // AUTO-CONNECT: Automatically connect to audio for all users
      if (!_isAudioConnected && !_isAudioConnecting && _currentUser != null) {
        // Connect audio for all users (moderators, speakers, and audience)
        AppLogger().debug('🔥 AUTO-CONNECT: Initiating automatic audio connection for all users');
        AppLogger().debug('🔥 AUTO-CONNECT: User role - moderator: $_isCurrentUserModerator, speaker: $_isCurrentUserSpeaker');
        _connectToAudio().then((_) {
          AppLogger().debug('🔥 AUTO-CONNECT: Audio connection successful');
        }).catchError((error) {
          AppLogger().error('🔥 AUTO-CONNECT: Audio connection failed: $error');
        });
      }
      
      // Participant loading completed
    } catch (e) {
      AppLogger().error('Error loading participants: $e');
      
      // Check if this might be a connectivity issue
      final isNetworkError = e.toString().contains('network') || 
                             e.toString().contains('connection') || 
                             e.toString().contains('timeout') ||
                             e.toString().toLowerCase().contains('unreachable');
      
      if (isNetworkError) {
        _wasOffline = true;
        AppLogger().warning('🌐 Network connectivity issue detected');
      }
      
      // Retry once after a short delay before showing error state
      Future.delayed(const Duration(seconds: 2), () async {
        if (mounted && !_isDisposing) {
          try {
            AppLogger().info('♾️ Retrying participant load after error...');
            final retryParticipants = await _appwrite.getDebateDiscussionParticipants(widget.roomId);
            
            if (mounted && !_isDisposing && retryParticipants.isNotEmpty) {
              AppLogger().info('✅ Retry successful - loaded ${retryParticipants.length} participants');
              
              // Check if we're back online after being offline
              if (_wasOffline) {
                AppLogger().info('🌐 Connection restored - forcing full participant refresh');
                _wasOffline = false;
                
                // Also reconnect real-time subscription to catch up on missed events
                _reconnectParticipantsSubscription();
              }
              
              // Clear cache and reload with fresh data
              invalidateNetworkCache(patternPrefix: 'participants_');
              await _loadParticipants();
              return;
            }
          } catch (retryError) {
            AppLogger().warning('Retry failed: $retryError - showing error state');
          }
        }
        
        // Show error state instead of mock data
        if (mounted && !_isDisposing) {
          AppLogger().error('❌ Unable to load participants after retry - showing error state');
          
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Unable to load participants. Please check your connection and try refreshing.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          
          // Keep UI functional but show that participants couldn't be loaded
          // At minimum, show the current user in the audience
          if (_currentUser != null && !_audienceMembers.any((p) => p.id == _currentUser!.id) && !_isCurrentUserModerator) {
            setState(() {
              _audienceMembers.clear();
              _audienceMembers.add(_currentUser!);
            });
          }
        }
      });
    }
  }

  // Mock participants method removed - we now handle errors properly
  // instead of showing fake data that misleads users

  void _setupRealTimeUpdates() async {
    try {
      AppLogger().info('📡 Setting up consolidated real-time subscriptions for room: ${widget.roomId}');

      // Use centralized subscription manager
      _roomSubscription = await _realtimeManager.subscribeToRoom(
        roomId: widget.roomId,
        roomType: 'debate_discussion',
      );

      // Listen to participant updates stream with weak reference
      _participantStreamListener = _roomSubscription!.participants.listen(
        (response) async {
          AppLogger().debug('Participant update events: ${response.events}');
          AppLogger().debug('Participant update payload: ${response.payload}');

          if (mounted && !_isDisposing) {
            await _handleParticipantUpdate(response);
          }
        },
        onError: (error) {
          AppLogger().error('Participants subscription error: $error');
          // Attempt immediate reconnect after error (more aggressive)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isDisposing) {
              AppLogger().warning('🔄 Reconnecting participants subscription due to error');
              _reconnectParticipantsSubscription();
            }
          });
        },
        onDone: () {
          AppLogger().warning('Participants subscription closed - attempting reconnect');
          if (mounted && !_isDisposing) {
            _reconnectParticipantsSubscription();
          }
        },
      );
      // Register weak reference for participant subscription
      registerWeakSubscription('participant_updates', _participantStreamListener!);
      // Track subscription for memory leak prevention
      trackSubscription('participant_stream', _participantStreamListener!);

      // Listen to room status updates
      _roomStatusStreamListener = _roomSubscription!.roomStatus.listen(
        (response) {
          AppLogger().debug('Room update events: ${response.events}');
          _handleRoomUpdate(response);
        },
        onError: (error) {
          AppLogger().error('Room subscription error: $error');
        },
      );
      // Track room status subscription
      trackSubscription('room_status_stream', _roomStatusStreamListener!);
      
    } catch (e) {
      AppLogger().error('Error setting up real-time updates: $e');
    }
  }

  /// Handle participant updates using diff-based approach
  Future<void> _handleParticipantUpdate(dynamic response) async {
    final handlerStartTime = DateTime.now();
    AppLogger().info('📥 SUBSCRIPTION: Received update at ${handlerStartTime.millisecondsSinceEpoch}');

    try {
      // Extract update information
      String updateType = 'unknown';
      if (response.events.any((e) => e.endsWith('.create'))) {
        updateType = 'create';
      } else if (response.events.any((e) => e.endsWith('.delete'))) {
        updateType = 'delete';
      } else if (response.events.any((e) => e.endsWith('.update'))) {
        updateType = 'update';
      }

      // Check if this update is for our room
      if (response.payload['roomId'] != widget.roomId) {
        return;
      }

      final processingStartTime = DateTime.now();
      final subscriptionLatency = processingStartTime.difference(handlerStartTime).inMilliseconds;
      AppLogger().info('🔄 DIFF UPDATE: Processing $updateType event for room ${widget.roomId} (subscription latency: ${subscriptionLatency}ms)');

      // Get current participant state
      final currentParticipants = <String, UserProfile>{};
      for (final speaker in _speakerPanelists) {
        currentParticipants[speaker.id] = speaker;
      }
      for (final audience in _audienceMembers) {
        currentParticipants[audience.id] = audience;
      }
      for (final request in _speakerRequests) {
        currentParticipants[request.id] = request;
      }

      // Calculate diff
      final diff = _diffManager.calculateDiff(
        roomId: widget.roomId,
        currentParticipants: currentParticipants,
        updatePayload: response.payload,
        updateType: updateType,
      );

      if (diff.hasChanges) {
        AppLogger().info('🔄 DIFF: ${diff.summary}');
        await _applyParticipantDiff(diff);

        // Apply granular state updates for affected participants
        for (final userId in diff.addedIds) {
          final role = diff.newRoles[userId] ?? 'audience';
          _granularStateManager.updateParticipant(
            roomId: widget.roomId,
            userId: userId,
            role: role,
            type: ParticipantUpdateType.added,
          );
        }

        for (final userId in diff.removedIds) {
          _granularStateManager.updateParticipant(
            roomId: widget.roomId,
            userId: userId,
            type: ParticipantUpdateType.removed,
          );
        }

        for (final entry in diff.roleChanges.entries) {
          _granularStateManager.updateParticipant(
            roomId: widget.roomId,
            userId: entry.key,
            role: entry.value.newRole,
            type: ParticipantUpdateType.roleChanged,
          );
        }
      } else {
        AppLogger().debug('🔄 DIFF: No relevant changes detected');
      }

    } catch (e) {
      AppLogger().error('Error handling participant update: $e');
      // Fallback to full reload on error
      await _loadParticipants();
    }
  }



  /// Play audio feedback using preloaded assets
  void _playAudioFeedback(String eventType) {
    try {
      switch (eventType) {
        case 'room_joined':
          _audioPreloader.playRoomJoined();
          break;
        case 'speaker_joined':
          _audioPreloader.playSpeakerJoined();
          break;
        case 'speaker_left':
          _audioPreloader.playSpeakerLeft();
          break;
        case 'hand_raise':
          _audioPreloader.playHandRaise();
          break;
        case 'message_received':
          _audioPreloader.playMessageReceived();
          break;
        case 'button_click':
          _audioPreloader.playButtonClick();
          break;
        case 'success':
          _audioPreloader.playSuccess();
          break;
        case 'error':
          _audioPreloader.playError();
          break;
        case 'timer_warning':
          _audioPreloader.playTimerWarning();
          break;
        case 'timer_zero':
          _audioPreloader.playTimerZero();
          break;
        default:
          AppLogger().debug('🔊 Unknown audio event: $eventType');
      }
    } catch (e) {
      AppLogger().error('Failed to play audio feedback: $e');
    }
  }

  /// Apply participant diff to UI state
  Future<void> _applyParticipantDiff(ParticipantDiff diff) async {
    bool needsUIUpdate = false;
    bool needsLiveKitUpdate = false;
    // Note: isHandRaiseEvent and isHandLowerEvent were unused legacy variables
    bool isHandLowerEvent = false;

    // Handle removals
    for (final userId in diff.removedIds) {
      _removeParticipantFromLists(userId);
      needsUIUpdate = true;
      AppLogger().info('📤 DIFF: Removed participant $userId');

      // CHECK: If the removed user is the current user, they were kicked/banned - navigate to home
      final isCurrentUser = userId == _currentUser?.id;
      if (isCurrentUser && mounted && !_isDisposing) {
        AppLogger().warning('🚪 Current user was removed from room (kicked/banned) - navigating to home screen');

        // Clean up LiveKit connection before navigating
        try {
          await _liveKitService.disconnect();
        } catch (e) {
          AppLogger().error('Error disconnecting LiveKit after kick: $e');
        }

        // Show modal with kick/ban details
        await _showRemovalModal();

        // Navigate to home screen
        if (mounted && !_isDisposing) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }

        // Return early - no need to continue processing updates
        return;
      }
    }

    // Handle additions (use stub-first for instant UI)
    for (final userId in diff.addedIds) {
      final role = diff.newRoles[userId] ?? 'audience';

      // Create stub immediately for instant feedback
      var userProfile = _createStubParticipant(userId);
      _addParticipantToList(userProfile, role);
      needsUIUpdate = true;
      AppLogger().info('📥 DIFF: Added stub participant $userId with role $role');

      // Hydrate in background
      _fetchUserProfile(userId).then((fullProfile) {
        if (fullProfile != null && mounted && !_isDisposing) {
          _mergeParticipantProfile(userProfile, fullProfile);
          if (mounted) {
            setState(() {
              // UI updates with full profile
            });
          }
        }
      }).catchError((e) {
        AppLogger().error('Failed to hydrate new participant $userId: $e');
      });
    }

    // Handle role changes
    for (final entry in diff.roleChanges.entries) {
      final userId = entry.key;
      final roleChange = entry.value;

      var userProfile = _findParticipantById(userId);

      // OPTIMIZED FIX: If user not found, use stub-first hydration for instant UI
      if (userProfile == null) {
        AppLogger().warning('⚠️ DRIFT FIX: User $userId not found in local state');

        // Create lightweight stub immediately
        userProfile = _createStubParticipant(userId);
        _addParticipantToList(userProfile, roleChange.oldRole);
        AppLogger().info('⚡ STUB: Created instant stub for $userId with role ${roleChange.oldRole}');

        // Hydrate full profile in background (don't await)
        _fetchUserProfile(userId).then((fullProfile) {
          if (fullProfile != null && mounted && !_isDisposing) {
            _mergeParticipantProfile(userProfile!, fullProfile);
            if (mounted) {
              setState(() {
                // UI will update with full profile data
              });
            }
          }
        }).catchError((e) {
          AppLogger().error('Failed to hydrate profile for $userId: $e');
        });
      }

      // OPTIMISTIC UPDATE: If this role change affects the current user, update UI IMMEDIATELY
      final isCurrentUser = userId == _currentUser?.id;
      if (isCurrentUser) {
        // Apply role change instantly for current user (before waiting for full batch processing)
        _moveParticipantToRole(userProfile, roleChange.newRole);

        // Trigger immediate UI update for current user's perspective
        if (mounted && !_isDisposing) {
          setState(() {
            // Current user sees their role change instantly
          });
          AppLogger().info('⚡ INSTANT: Current user role changed to ${roleChange.newRole} - UI updated immediately');
        }
      } else {
        // For other users, apply normally
        _moveParticipantToRole(userProfile, roleChange.newRole);
      }

      needsUIUpdate = true;

      // Check for special role changes
      if (roleChange.newRole == 'pending') {
        // INSTANT NOTIFICATION: Show hand-raise dialog immediately for moderator
        // Note: userProfile is guaranteed non-null here due to stub creation above
        if (_hasModeratorPowers) {
          final notificationTime = DateTime.now();
          AppLogger().info('⚡ INSTANT: Hand raise detected for ${userProfile.name} at ${notificationTime.millisecondsSinceEpoch}, showing notification NOW');
          // Don't wait for batch processing, show notification immediately
          Future.microtask(() {
            if (mounted && !_isDisposing) {
              _showHandRaiseNotificationFromPayload({'userId': userId});
            }
          });
        }
      } else if (roleChange.newRole == 'speaker') {
        // Check if this user is a Super Moderator joining the speaker panel
        final superModService = SuperModeratorService();
        final isSuperMod = superModService.isSuperModerator(userId);
        if (isSuperMod) {
          final userName = userProfile.name.isNotEmpty ? userProfile.name : 'Super Moderator';
          AppLogger().info('🛡️ Super Moderator $userName joined speaker panel');
          // Show notification to ALL users (not just the super mod)
          Future.microtask(() {
            if (mounted && !_isDisposing) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🛡️ Super Moderator $userName joined speaker panel'),
                  backgroundColor: const Color(0xFF6B46C1), // Purple for super mod
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      } else if (roleChange.newRole == 'audience') {
        // User demoted/moved to audience
        if (isCurrentUser) {
          if (roleChange.oldRole == 'pending' && _hasRequestedSpeaker) {
            isHandLowerEvent = true;
          }

          // FORCE MUTE when current user is demoted to audience
          if (['speaker', 'affirmative', 'negative'].contains(roleChange.oldRole)) {
            AppLogger().info('🔇 SUBSCRIPTION: Current user demoted from ${roleChange.oldRole} to audience - FORCE MUTING');

            _isCurrentUserSpeaker = false;

            // Force unpublish audio tracks
            Future.microtask(() async {
              await _liveKitService.unpublishAllTracks();
              if (_liveKitService.isConnected) {
                await _liveKitService.disableAudio();
              }
              if (mounted) {
                setState(() {
                  _isMuted = true;
                  _isVideoEnabled = false;
                });
              }
            });
          }
        }
      } else if (['speaker', 'affirmative', 'negative'].contains(roleChange.newRole) && isCurrentUser) {
        needsLiveKitUpdate = true;
      }

      AppLogger().info('🔄 DIFF: Role change for $userId: ${roleChange.oldRole} -> ${roleChange.newRole}');
    }

    // Update UI if needed
    if (needsUIUpdate && mounted && !_isDisposing) {
      setState(() {
        // UI will rebuild with updated participant lists
      });
    }

    if (isHandLowerEvent) {
      setState(() {
        _hasRequestedSpeaker = false;
      });
    }

    if (needsLiveKitUpdate) {
      Future.microtask(() async {
        if (mounted) {
          await _reinitializeAudioForSpeaker();
        }
      });
    }
  }

  /// Helper methods for participant management
  void _removeParticipantFromLists(String userId) {
    _speakerPanelists.removeWhere((p) => p.id == userId);
    _audienceMembers.removeWhere((p) => p.id == userId);
    _speakerRequests.removeWhere((p) => p.id == userId);
    _participantRoles.remove(userId);
  }

  void _addParticipantToList(UserProfile user, String role) {
    _participantRoles[user.id] = role;
    switch (role) {
      case 'moderator':
      case 'speaker':
      case 'affirmative':
      case 'negative':
        if (!_speakerPanelists.any((p) => p.id == user.id)) {
          _speakerPanelists.add(user);
        }
        break;
      case 'pending':
        if (!_speakerRequests.any((p) => p.id == user.id)) {
          _speakerRequests.add(user);
        }
        break;
      case 'audience':
      default:
        if (!_audienceMembers.any((p) => p.id == user.id)) {
          _audienceMembers.add(user);
        }
        break;
    }
  }

  void _moveParticipantToRole(UserProfile user, String newRole) {
    // Remove from all lists first
    _removeParticipantFromLists(user.id);
    // Add to appropriate list
    _addParticipantToList(user, newRole);
  }

  UserProfile? _findParticipantById(String userId) {
    for (final participant in [..._speakerPanelists, ..._audienceMembers, ..._speakerRequests]) {
      if (participant.id == userId) {
        return participant;
      }
    }
    return null;
  }

  /// Fetch a single user profile (with batching and caching)
  Future<UserProfile?> _fetchUserProfile(String userId) async {
    try {
      // Check if fetch is already in-flight
      if (_inFlightFetches.contains(userId)) {
        AppLogger().debug('⏳ Fetch already in-flight for $userId, skipping duplicate request');
        return null;
      }

      // Mark as in-flight
      _inFlightFetches.add(userId);

      try {
        final profile = await _batchProfileService.getUserProfile(userId);
        return profile;
      } finally {
        // Always remove from in-flight set
        _inFlightFetches.remove(userId);
      }
    } catch (e) {
      AppLogger().error('Failed to fetch user profile for $userId: $e');
      _inFlightFetches.remove(userId);
      return null;
    }
  }

  /// Create a lightweight stub participant for instant UI feedback
  UserProfile _createStubParticipant(String userId) {
    return UserProfile(
      id: userId,
      name: 'Loading...',
      email: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      avatar: null, // Will show default avatar
    );
  }

  /// Merge full profile data into existing stub participant
  void _mergeParticipantProfile(UserProfile stub, UserProfile fullProfile) {
    // Find the stub in all lists and replace with full profile
    final role = _participantRoles[stub.id];
    if (role != null) {
      // Remove stub
      _removeParticipantFromLists(stub.id);
      // Add full profile
      _addParticipantToList(fullProfile, role);
      AppLogger().debug('✅ Merged full profile for ${fullProfile.name} (was stub)');
    }
  }

  /// Preload all participant profiles for optimal performance
  Future<void> _preloadParticipantProfiles() async {
    try {
      final participants = await _appwrite.getDebateDiscussionParticipants(widget.roomId);

      // Extract all user IDs from participants
      final userIds = participants
          .where((p) => p['userId'] != null)
          .map((p) => p['userId'] as String)
          .toSet()
          .toList();

      if (userIds.isNotEmpty) {
        AppLogger().info('📊 Preloading ${userIds.length} participant profiles for room ${widget.roomId}');
        await _batchProfileService.preloadRoomProfiles(userIds);
        AppLogger().debug('✅ Participant profiles preloaded successfully');
      }
    } catch (e) {
      AppLogger().warning('Failed to preload participant profiles: $e');
    }
  }

  void _reconnectParticipantsSubscription() async {
    try {
      AppLogger().info('Reconnecting consolidated room subscriptions...');

      // Cancel existing listeners
      _participantStreamListener?.cancel();
      _chatStreamListener?.cancel();
      _roomStatusStreamListener?.cancel();
      _handRaiseStreamListener?.cancel();
      _timerStreamListener?.cancel();
      _materialStreamListener?.cancel();

      // Recreate subscription after short delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted && !_isDisposing) {
        // Recreate consolidated subscription
        _roomSubscription = await _realtimeManager.subscribeToRoom(
          roomId: widget.roomId,
          roomType: 'debate_discussion',
        );

        // Re-establish participant listener
        _participantStreamListener = _roomSubscription!.participants.listen(
            (response) async {
              AppLogger().debug('Reconnected - Participant update events: ${response.events}');
              
              if (mounted && !_isDisposing) {
                // Check for hand-raise and hand-lower events
                bool isHandRaiseEvent = false;
                bool isHandLowerEvent = false;
                
                for (var event in response.events) {
                  if (event.contains('debate_discussion_participants.documents') && 
                      (event.endsWith('.update') || event.endsWith('.create') || event.endsWith('.delete'))) {
                    if (response.payload['roomId'] == widget.roomId) {
                      
                      // Mark that we need to reload participants (done at end)
                      
                      // Handle specific role update events
                      if (event.endsWith('.update')) {
                        final newRole = response.payload['role'];
                        final userId = response.payload['userId'];
                        
                        if (newRole == 'pending') {
                          AppLogger().info('Hand-raise detected after reconnect: $userId');
                          isHandRaiseEvent = true;
                        } else if (newRole == 'audience') {
                          if (userId == _currentUser?.id && _hasRequestedSpeaker) {
                            AppLogger().info('Hand-lower detected after reconnect: $userId');
                            isHandLowerEvent = true;
                          }
                        }
                      }
                    }
                  }
                }
                
                // Force immediate reload after reconnection
                invalidateNetworkCache(patternPrefix: 'participants_');
                await _loadParticipants();
                
                if (isHandRaiseEvent && _hasModeratorPowers) {
                  _showHandRaiseNotificationFromPayload(response.payload);
                }
                
                if (isHandLowerEvent) {
                  setState(() {
                    _hasRequestedSpeaker = false;
                  });
                }
              }
            },
            onError: (error) {
              AppLogger().error('Reconnected subscription error: $error');
            },
            onDone: () {
              AppLogger().warning('Reconnected subscription closed');
              if (mounted && !_isDisposing) {
                _reconnectParticipantsSubscription();
              }
            },
          );
        // Track reconnected participant subscription
        trackSubscription('participant_stream', _participantStreamListener!);

        // Re-establish room status listener
        _roomStatusStreamListener = _roomSubscription!.roomStatus.listen(
          (response) {
            AppLogger().debug('Reconnected - Room update events: ${response.events}');
            _handleRoomUpdate(response);
          },
          onError: (error) {
            AppLogger().error('Reconnected room subscription error: $error');
          },
        );
        // Track reconnected room status subscription
        trackSubscription('room_status_stream', _roomStatusStreamListener!);

        AppLogger().info('All room subscriptions reconnected successfully');
      }
    } catch (e) {
      AppLogger().error('Error reconnecting participants subscription: $e');
    }
  }

  void _showHandRaiseNotificationFromPayload(Map<String, dynamic> payload) async {
    try {
      final userId = payload['userId'];
      if (userId == null) return;
      
      // Get user profile for the notification
      final userProfile = await _appwrite.getUserProfile(userId);
      if (userProfile == null) {
        AppLogger().warning('Could not find user profile for hand-raise notification: $userId');
        return;
      }
      
      AppLogger().info('Showing immediate hand-raise notification for: ${userProfile.name}');

      // Play hand raise audio feedback
      _playAudioFeedback('hand_raise');

      if (mounted && !_isDisposing) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            final screenHeight = MediaQuery.of(context).size.height;
            final isSmallScreen = screenHeight < 700; // iPhone 12 is ~844px
            
            return Dialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact Title Row
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.hand,
                            color: const Color(0xFF8B5CF6),
                            size: isSmallScreen ? 20 : 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Hand Raised!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 14),
                    // Compact Content
                    Flexible(
                      child: Text(
                        '${userProfile.name} wants to join the speakers panel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 14 : 15,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    // Compact Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _denySpeakerRequest(userProfile);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 8 : 10,
                              ),
                            ),
                            child: Text(
                              'Deny',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: isSmallScreen ? 14 : 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _approveSpeakerRequest(userProfile);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 8 : 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              'Approve',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      AppLogger().error('Error showing hand-raise notification: $e');
      // Fallback to the old method
      _showNewSpeakerRequestNotification();
    }
  }

  void _showNewSpeakerRequestNotification() {
    // Get the latest speaker request
    if (_speakerRequests.isEmpty) return;
    
    final latestRequest = _speakerRequests.last;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.hand,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Speaker Request',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '${latestRequest.name} wants to join the speakers panel',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _denySpeakerRequest(latestRequest);
              },
              child: const Text(
                'Deny',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveSpeakerRequest(latestRequest);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Approve',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleRoomUpdate(dynamic response) async {
    try {
      // Check if this update is for our current room
      if (response.payload != null && response.payload['\$id'] == widget.roomId) {
        final roomStatus = response.payload['status'];
        final queueEnabled = response.payload['queueEnabled'];

        AppLogger().debug('Room update - status: $roomStatus, queueEnabled: $queueEnabled');

        // Handle queue status changes
        if (queueEnabled != null && queueEnabled != _queueEnabled && mounted && !_isDisposing) {
          AppLogger().info('Queue status changed by moderator: $queueEnabled');

          setState(() {
            _queueEnabled = queueEnabled;
            if (!_queueEnabled) {
              // Clear queue and current speaker when disabled by moderator
              _speakerQueue.clear();
              _currentSpeaker = null;
              _speakerRequests.clear();
            }
          });

          // Show notification to all users about queue status change
          if (!_isCurrentUserModerator) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  queueEnabled
                    ? '✅ Moderator enabled speaker queue'
                    : '❌ Moderator disabled speaker queue'
                ),
                backgroundColor: queueEnabled ? Colors.green : Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }

        // If room is ended and current user is not the moderator (who ended it)
        if (roomStatus == 'ended' && !_isCurrentUserModerator && mounted && !_isDisposing) {
          AppLogger().debug('Room ended by moderator, navigating all users out');

          // Show notification that room was ended
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚪 Room ended by moderator'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );

          // Audio/Video cleanup handled by LiveKit

          // Navigate back to home screen
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
      }
    } catch (e) {
      AppLogger().error('Error handling room update: $e');
    }
  }



  void _requestToJoinSpeakers() async {
    if (_isCurrentUserModerator || _currentUser == null) {
      return;
    }

    // Check if current user is a Super Moderator
    final superModService = SuperModeratorService();
    final isSuperMod = superModService.isSuperModerator(_currentUser!.id);

    try {
      if (_hasRequestedSpeaker) {
        // CRITICAL: Mute audio FIRST, BEFORE database update when lowering hand
        AppLogger().info('🔇 HAND LOWER: Force muting IMMEDIATELY for ${_currentUser!.name}');
        _isCurrentUserSpeaker = false;
        _isMuted = true;
        _isVideoEnabled = false;

        // Force unpublish audio tracks BEFORE database update
        await _liveKitService.unpublishAllTracks();

        // Force disable audio for audience role
        if (_liveKitService.isConnected) {
          await _liveKitService.disableAudio();
        }

        // Update UI immediately
        if (mounted) {
          setState(() {});
        }

        AppLogger().info('✅ HAND LOWER: Audio muted instantly, now updating database');

        // Now update database (audio already muted)
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'audience',
        );

        AppLogger().info('🔇 HAND LOWER: Audio cleanup complete for ${_currentUser!.name} returning to audience');

        if (mounted && !_isDisposing) {
          setState(() {
            _hasRequestedSpeaker = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✋ Hand lowered - request cancelled'),
              backgroundColor: Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        }

        AppLogger().info('User ${_currentUser!.name} lowered their hand');
      } else if (isSuperMod) {
        // Super Moderator - instant promotion to speaker
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'speaker',
        );

        if (mounted && !_isDisposing) {
          setState(() {
            _isCurrentUserSpeaker = true;
            _hasRequestedSpeaker = false;
          });

          // Note: Notification will be shown to ALL users via real-time update handler
          // No need for local notification here

          // Audio will be reinitialized automatically by the role change
        }

        AppLogger().info('🛡️ Super Moderator ${_currentUser!.name} joined speaker panel instantly');
      } else {
        // Regular user wants to raise their hand - change to pending
        // OPTIMISTIC: Update local state first for instant user feedback
        if (mounted && !_isDisposing) {
          setState(() {
            _hasRequestedSpeaker = true;
          });
        }

        final handRaiseStartTime = DateTime.now();
        AppLogger().info('⏱️ HAND RAISE: Starting database update at ${handRaiseStartTime.millisecondsSinceEpoch}');

        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'pending',
        );

        final handRaiseEndTime = DateTime.now();
        final handRaiseDuration = handRaiseEndTime.difference(handRaiseStartTime).inMilliseconds;
        AppLogger().info('⏱️ HAND RAISE: Database updated in ${handRaiseDuration}ms');

        if (mounted && !_isDisposing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✋ Request sent to moderator for approval'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }

        AppLogger().info('✋ User ${_currentUser!.name} raised their hand - waiting for moderator subscription to trigger...');
      }
      
      // The real-time subscription will update the UI automatically
    } catch (e) {
      AppLogger().error('Error with hand raise/lower: $e');
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle speaker leaving the panel with warning dialog
  Future<void> _requestToLeaveSpeakerPanel() async {
    if (_currentUser == null) return;

    // Show warning dialog
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                'Leave Speaker Panel?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'You will be moved back to the audience and lose speaking privileges. You can raise your hand again to rejoin the panel.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Leave Panel'),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true) {
      try {
        // Move user back to audience
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'audience',
        );

        if (mounted) {
          setState(() {
            _isCurrentUserSpeaker = false;
            _hasRequestedSpeaker = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📤 You have left the speaker panel'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }

        AppLogger().info('User ${_currentUser!.name} left the speaker panel');
      } catch (e) {
        AppLogger().error('Error leaving speaker panel: $e');
        if (mounted && !_isDisposing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error leaving panel: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _approveSpeakerRequest(UserProfile user) async {
    if (!_hasModeratorPowers) return;
    
    // Check if this is a debate room
    final isDebateRoom = _roomData?['debateStyle'] == 'Debate';
    AppLogger().debug('🏛️ Approving speaker request for ${user.name}, isDebateRoom: $isDebateRoom, debateStyle: ${_roomData?['debateStyle']}');
    
    if (isDebateRoom) {
      // For debate rooms, show position selection dialog
      AppLogger().debug('🏛️ Showing debate position selection dialog');
      _showDebatePositionSelectionDialog(user);
    } else {
      // For regular rooms, use the original logic
      final otherSpeakersCount = _speakerPanelists.where((speaker) => speaker.id != _moderator?.id).length;
      if (otherSpeakersCount >= 6) {
        return;
      }
      
      AppLogger().debug('🏛️ Assigning user to regular speaker role');
      await _assignUserToRole(user, 'speaker');
    }
  }

  void _showDebatePositionSelectionDialog(UserProfile user) {
    // Check current position occupancy using actual role data
    final hasAffirmative = _participantRoles.values.contains('affirmative');
    final hasNegative = _participantRoles.values.contains('negative');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign ${user.name} to Debate Position'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose which side of the debate this participant will argue for:'),
            const SizedBox(height: 16),
            // Affirmative option
            ListTile(
              leading: Icon(
                Icons.thumb_up,
                color: hasAffirmative ? Colors.grey : Colors.green,
              ),
              title: Text(
                'Affirmative',
                style: TextStyle(
                  color: hasAffirmative ? Colors.grey : Colors.black,
                ),
              ),
              subtitle: Text(hasAffirmative ? 'Position occupied' : 'Argues FOR the topic'),
              enabled: !hasAffirmative,
              onTap: hasAffirmative ? null : () {
                Navigator.pop(context);
                _assignUserToRole(user, 'affirmative');
              },
            ),
            // Negative option  
            ListTile(
              leading: Icon(
                Icons.thumb_down,
                color: hasNegative ? Colors.grey : Colors.red,
              ),
              title: Text(
                'Negative',
                style: TextStyle(
                  color: hasNegative ? Colors.grey : Colors.black,
                ),
              ),
              subtitle: Text(hasNegative ? 'Position occupied' : 'Argues AGAINST the topic'),
              enabled: !hasNegative,
              onTap: hasNegative ? null : () {
                Navigator.pop(context);
                _assignUserToRole(user, 'negative');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignUserToRole(UserProfile user, String role) async {
    // INSTANT MUTE: If demoting to audience, send mute command IMMEDIATELY via LiveKit
    if (role == 'audience') {
      AppLogger().info('🔇 INSTANT MUTE: Sending mute command for ${user.name} BEFORE database update');

      // If demoting current user, mute locally immediately
      if (user.id == _currentUser?.id) {
        _isCurrentUserSpeaker = false;
        _isMuted = true;
        _isVideoEnabled = false;

        // Force unpublish immediately
        _liveKitService.unpublishAllTracks();
        if (_liveKitService.isConnected) {
          _liveKitService.disableAudio();
        }

        if (mounted) {
          setState(() {});
        }
      } else {
        // If demoting OTHER user, send LiveKit mute command via data channel IMMEDIATELY
        if (_liveKitService.isConnected && _hasModeratorPowers) {
          AppLogger().info('🔇 LIVEKIT MUTE: Sending instant mute command to ${user.name} via data channel');
          await _liveKitService.muteParticipant(user.id);
          AppLogger().info('✅ LIVEKIT MUTE: Command sent to ${user.name}');
        }
      }
    }

    // Check if user is a Super Moderator being moved to audience (kicked/removed)
    final superModService = SuperModeratorService();
    if (superModService.isSuperModerator(user.id) && role == 'audience') {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: const Icon(
                Icons.shield,
                color: Color(0xFFFFD700),
                size: 32,
              ),
              title: const Text(
                'Super Moderator Protection',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              content: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  children: [
                    TextSpan(
                      text: user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: ' is a Super Moderator and cannot be moved to the audience or removed from the room. Super Moderators have permanent immunity.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD700),
                  ),
                  child: const Text('Understood'),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    try {
      // OPTIMISTIC UPDATE: Update moderator UI BEFORE database call for instant feedback
      if (mounted && !_isDisposing) {
        setState(() {
          // Remove user from speaker requests list (applies to all role changes)
          _speakerRequests.removeWhere((participant) => participant.id == user.id);

          // Update participant role mapping
          _participantRoles[user.id] = role;

          if (role == 'audience') {
            // DEMOTION: Move user from speakers back to audience
            _speakerPanelists.removeWhere((participant) => participant.id == user.id);
            if (!_audienceMembers.any((p) => p.id == user.id)) {
              _audienceMembers.add(user);
            }
          } else {
            // PROMOTION: Move user from audience to speakers
            _audienceMembers.removeWhere((participant) => participant.id == user.id);
            if (!_speakerPanelists.any((p) => p.id == user.id)) {
              _speakerPanelists.add(user);
            }
          }
        });

        AppLogger().info('⚡ OPTIMISTIC: Moderator UI updated instantly BEFORE database call for ${user.name} → $role');
      }

      // Now update database (moderator already sees the change)
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: user.id,
        newRole: role,
      );

      if (mounted) {
        final roleDisplayName = role == 'affirmative' ? 'Affirmative' :
                               role == 'negative' ? 'Negative' : 'Speakers Panel';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${user.name} assigned to $roleDisplayName'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // If the approved user is the current user, update their role and permissions immediately
      if (user.id == _currentUser?.id) {
        AppLogger().info('🔄 ROLE ASSIGNMENT: Current user assigned to role: $role');
        
        // Update local role state
        if (role == 'speaker' || role == 'affirmative' || role == 'negative') {
          _isCurrentUserSpeaker = true;
          AppLogger().info('🔄 ROLE ASSIGNMENT: Updated local speaker status to true');
          
          // CRITICAL: Reinitialize LiveKit connection with new speaker role
          AppLogger().info('🔄 ROLE ASSIGNMENT: User promoted to speaker - reinitializing audio connection');
          await _reinitializeAudioForSpeaker();
          _showSpeakerActivationDialog();
        } else if (role == 'audience') {
          // DEMOTION: Current user demoted back to audience - FORCE MUTE
          _isCurrentUserSpeaker = false;
          AppLogger().info('🔄 ROLE ASSIGNMENT: Current user demoted to audience - FORCE MUTING');

          // Force unpublish all audio/video tracks
          await _liveKitService.unpublishAllTracks();

          // Force disable audio
          if (_liveKitService.isConnected) {
            await _liveKitService.disableAudio();
          }

          // Force local mute state
          _isMuted = true;
          _isVideoEnabled = false;

          if (mounted) {
            setState(() {});
          }

          AppLogger().info('🔇 DEMOTION: Current user force muted and disabled');
        }
      }

      // Real-time subscription will sync the promoted user's screen and any other participants
    } catch (e) {
      AppLogger().error('Error assigning user to role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeSpeaker(UserProfile user) async {
    // Check if user is a Super Moderator - they cannot be removed
    final superModService = SuperModeratorService();
    if (superModService.isSuperModerator(user.id)) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: const Icon(
                Icons.shield,
                color: Color(0xFFFFD700),
                size: 32,
              ),
              title: const Text(
                'Super Moderator Protection',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              content: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  children: [
                    TextSpan(
                      text: user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: ' is a Super Moderator and cannot be removed from the speaker panel. Super Moderators have immunity from kicks and removals.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD700),
                  ),
                  child: const Text('Understood'),
                ),
              ],
            );
          },
        );
      }
      return;
    }
    
    if (!_isCurrentUserModerator || user.id == _moderator?.id) {
      return;
    }

    try {
      // OPTIMISTIC UPDATE: Update moderator UI BEFORE database call
      if (mounted && !_isDisposing) {
        setState(() {
          // Remove from speakers, add to audience
          _speakerPanelists.removeWhere((participant) => participant.id == user.id);
          if (!_audienceMembers.any((p) => p.id == user.id)) {
            _audienceMembers.add(user);
          }
          _participantRoles[user.id] = 'audience';
        });

        AppLogger().info('⚡ OPTIMISTIC: Moderator sees ${user.name} demoted to audience instantly');
      }

      // Now update database
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: user.id,
        newRole: 'audience',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} moved to audience'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // The real-time subscription will update the demoted user's screen
    } catch (e) {
      AppLogger().error('Error removing speaker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing speaker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // Show dialog to offer video/audio activation when user becomes speaker
  void _showSpeakerActivationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '🎉 You\'re now a speaker!',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Would you like to enable your video and audio to participate in the discussion?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Connect to audio if not connected, then unmute
                if (!_isAudioConnected) {
                  await _connectToAudio();
                }
                // Then unmute
                if (_isAudioConnected && _isMuted) {
                  _toggleMute();
                }
              },
              child: const Text('Audio Only', style: TextStyle(color: Colors.green)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Connect to audio if not connected, then unmute
                if (!_isAudioConnected) {
                  await _connectToAudio();
                }
                // Then unmute
                if (_isAudioConnected && _isMuted) {
                  _toggleMute();
                }
                _toggleVideo();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Video + Audio', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }



  /// Show warning dialog before leaving room for critical roles
  Future<bool> _showLeaveRoomWarning() async {
    AppLogger().debug('🚪 _showLeaveRoomWarning called - moderator: $_isCurrentUserModerator, speaker: $_isCurrentUserSpeaker');

    // Determine user's current role and impact of leaving
    String userRole = 'audience';
    String warningMessage = 'Are you sure you want to leave the room?';
    String impact = '';
    bool isCriticalRole = false;

    if (_isCurrentUserModerator) {
      userRole = 'moderator';
      isCriticalRole = true;
      impact = 'The room will be closed for all participants.';
      warningMessage = '⚠️ As the moderator, leaving will end the debate for everyone.';
    } else if (_isCurrentUserSpeaker) {
      // Check if user is in a speaking position
      final userInSpeakingRole = _speakerPanelists.any((p) => p.id == _currentUser?.id);
      if (userInSpeakingRole) {
        userRole = 'speaker';
        isCriticalRole = true;
        impact = 'Your speaking slot will become available to others.';
        warningMessage = '⚠️ You are currently in a speaking position.';
      }
    }

    // For non-critical roles, just leave without warning
    if (!isCriticalRole) {
      AppLogger().debug('🚪 Non-critical role detected, leaving without warning');
      await _performLeaveRoom();
      return true;
    }

    AppLogger().debug('🚪 Critical role detected ($userRole), showing warning dialog');

    // Show warning dialog for critical roles
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _isCurrentUserModerator ? Icons.gavel : Icons.record_voice_over,
                color: _isCurrentUserModerator ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'Leave as ${userRole.toUpperCase()}?',
                style: TextStyle(
                  color: _isCurrentUserModerator ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                warningMessage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              if (impact.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          impact,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Show participant count for context
              Builder(
                builder: (context) {
                  final totalParticipants = _audienceMembers.length + _speakerPanelists.length;
                  if (totalParticipants > 0) {
                    return Text(
                      '👥 $totalParticipants participant${totalParticipants != 1 ? 's' : ''} currently in room',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await _performLeaveRoom();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCurrentUserModerator ? Colors.red : Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(_isCurrentUserModerator ? 'End Room' : 'Leave'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Perform the actual room leaving process
  Future<void> _performLeaveRoom() async {
    try {
      AppLogger().info('🚪 User leaving room - role: ${_isCurrentUserModerator ? 'moderator' : _isCurrentUserSpeaker ? 'speaker' : 'audience'}');

      if (_isJoined && _currentUser != null) {
        await _appwrite.leaveDebateDiscussionRoom(
          roomId: widget.roomId,
          userId: _currentUser!.id,
        );
      }
    } catch (e) {
      AppLogger().error('Failed to leave room cleanly: $e');
    }
  }

  /// Show modal dialog when user is kicked or banned from room
  Future<void> _showRemovalModal() async {
    if (!mounted || _isDisposing || _currentUser == null) return;

    // Check if user is banned to show appropriate message
    String title = '⚠️ Removed from Room';
    String message = 'You have been kicked from this room.';
    String? banDetails;
    Color titleColor = Colors.orange;

    try {
      // Check for active ban
      final banQuery = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_bans',
        queries: [
          Query.equal('userId', _currentUser!.id),
          Query.equal('roomId', widget.roomId),
          Query.equal('isActive', true),
          Query.limit(1),
        ],
      );

      if (banQuery.documents.isNotEmpty) {
        final ban = banQuery.documents.first;
        final banData = ban.data;
        final bannedBy = banData['bannedByUsername'] ?? 'moderator';
        final reason = banData['reason'] ?? 'No reason provided';
        final expiresAtStr = banData['expiresAt'] as String?;

        title = '🚫 Banned from Room';
        message = 'You have been banned from this room by $bannedBy.';
        titleColor = Colors.red;

        if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
          final expiresAt = DateTime.parse(expiresAtStr);
          final duration = expiresAt.difference(DateTime.now());

          if (duration.inMinutes > 0) {
            final hours = duration.inHours;
            final minutes = duration.inMinutes % 60;

            if (hours > 0) {
              banDetails = 'Ban duration: $hours hour${hours > 1 ? 's' : ''} ${minutes > 0 ? 'and $minutes minute${minutes > 1 ? 's' : ''}' : ''}';
            } else {
              banDetails = 'Ban duration: $minutes minute${minutes > 1 ? 's' : ''}';
            }
          }
        } else {
          banDetails = 'This is a permanent ban.';
        }

        if (reason.isNotEmpty && reason != 'No reason provided') {
          banDetails = '${banDetails != null ? '$banDetails\n' : ''}Reason: $reason';
        }
      }
    } catch (e) {
      AppLogger().error('Error checking ban status for modal: $e');
    }

    if (!mounted || _isDisposing) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              banDetails != null ? Icons.block : Icons.warning,
              color: titleColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (banDetails != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        banDetails,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: titleColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return PopScope(
      canPop: false, // Prevent immediate pop to show warning first
      onPopInvokedWithResult: (didPop, result) async {
        AppLogger().debug('🚪 PopScope triggered - didPop: $didPop, joined: $_isJoined, disposing: $_isDisposing');
        AppLogger().debug('🚪 User role - moderator: $_isCurrentUserModerator, speaker: $_isCurrentUserSpeaker');

        if (!didPop && _isJoined && _currentUser != null && !_isDisposing) {
          // Capture navigator before async operation
          final navigator = Navigator.of(context);
          // Show warning before leaving if user has critical role
          final shouldLeave = await _showLeaveRoomWarning();
          AppLogger().debug('🚪 Should leave: $shouldLeave');
          if (shouldLeave && mounted) {
            navigator.pop();
          }
        }
      },
      child: _buildMainContent(context),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              SizedBox(height: 16),
              Text(
                'Joining room...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildRoomTitleSection(),
            Expanded(
              child: _buildVideoGrid(),
            ),
            _buildControlsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final participantCount = _speakerPanelists.length + _audienceMembers.length;
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                LucideIcons.arrowLeft,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          // Coin Balance
          const RealTimeCoinBalance(
            textStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            backgroundColor: Colors.transparent,
            showCoinIcon: true,
            iconSize: 12,
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
          SizedBox(width: isSmallScreen ? 8 : 16),
          const ChallengeBell(
            key: ValueKey('debates_challenge_bell'),
            iconColor: Colors.white,
          ),
          SizedBox(width: isSmallScreen ? 8 : 16),
          // Compact participant count and audio status
          Row(
            key: const ValueKey('debates_header_stats'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.users,
                color: Colors.white,
                size: isSmallScreen ? 14 : 16,
              ),
              const SizedBox(width: 2),
              Text(
                '$participantCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                _webrtcService.isConnected 
                  ? (_isMuted ? LucideIcons.micOff : LucideIcons.mic)
                  : LucideIcons.micOff,
                color: _webrtcService.isConnected 
                  ? (_isMuted ? Colors.orange : Colors.green)
                  : Colors.grey,
                size: isSmallScreen ? 12 : 14,
              ),
            ],
          ),
          
          
          // Connection status indicator
          if (_isReconnecting) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Reconnecting...',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_hasModeratorPowers) ...[
            SizedBox(width: isSmallScreen ? 8 : 16),
            GestureDetector(
                  key: const ValueKey('debates_moderator_tools'),
                  onTap: _showModeratorTools,
                  child: Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          LucideIcons.settings,
                          color: const Color(0xFF8B5CF6),
                          size: isSmallScreen ? 16 : 20,
                        ),
                      ),
                      // Show badge if there are pending speaker requests
                      if (_speakerRequests.isNotEmpty)
                        Positioned(
                          key: ValueKey('moderator_badge_${_speakerRequests.length}'),
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                '${_speakerRequests.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
          // Materials button - only visible to moderators and debaters in debate format rooms
          if (_roomData?['debateStyle'] == 'Debate' && (_hasModeratorPowers || _isCurrentUserSpeaker)) ...[ 
            SizedBox(width: isSmallScreen ? 6 : 16),
            GestureDetector(
              key: const ValueKey('debates_materials_button'),
              onTap: _showMaterialsSheet,
              child: Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  LucideIcons.presentation,
                  color: const Color(0xFF8B5CF6),
                  size: isSmallScreen ? 16 : 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomTitleSection() {
    final roomName = _roomData?['name'] ?? widget.roomName ?? 'Debate Room';
    final moderatorName = _moderator?.name ?? widget.moderatorName ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Room name
          Text(
            roomName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Moderator info - stacked
          Column(
            children: [
              const Text(
                'Moderated by',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                moderatorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          

        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    return LayoutBuilder(
      key: const ValueKey('debates_video_grid_layout'),
      builder: (context, constraints) {
        // Reserve space for controls and other UI elements
        
        return Column(
          key: const ValueKey('debates_video_grid_column'),
          children: [
            // Speakers panel with integrated audience below moderator
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('debates_speaker_panel_scroll'),
                child: _buildSpeakerPanel(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpeakerPanel() {
    // Prepare data for performance-optimized speakers panel
    List<Map<String, dynamic>> speakers = _speakerPanelists
        .where((speaker) => speaker.id != _moderator?.id)
        .map((speaker) => {
              'userId': speaker.id,
              'name': speaker.name,
              'userName': speaker.name,
              'avatarUrl': speaker.avatar,
              'avatar': speaker.avatar,
              'role': _participantRoles[speaker.id] ?? 'speaker', // Use actual role
              'isSpeaking': _liveKitService.isUserSpeaking(speaker.id), // Add speaking state
            })
        .toList();

    Map<String, dynamic>? moderatorData;
    if (_moderator != null) {
      moderatorData = {
        'userId': _moderator!.id,
        'name': _moderator!.name,
        'userName': _moderator!.name,
        'avatarUrl': _moderator!.avatar,
        'avatar': _moderator!.avatar,
        'role': 'moderator',
        'isSpeaking': _liveKitService.isUserSpeaking(_moderator!.id), // Add speaking state
      };
    }

    // Prepare audience data for the speakers panel
    List<Map<String, dynamic>> audience = _audienceMembers.map((member) => {
      'userId': member.id,
      'name': member.name,
      'userName': member.name,
      'avatarUrl': member.avatar,
      'avatar': member.avatar,
      'role': 'audience',
    }).toList();

    // Prepare speaker requests data for the speakers panel
    List<Map<String, dynamic>> speakerRequests = _speakerRequests.map((request) => {
      'userId': request.id,
      'name': request.name,
      'userName': request.name,
      'avatarUrl': request.avatar,
      'avatar': request.avatar,
      'role': 'pending',
    }).toList();

    return PerformanceOptimizedSpeakersPanel(
      speakers: speakers,
      moderator: moderatorData,
      audience: audience, // Pass audience data
      speakerRequests: speakerRequests, // Pass speaker requests data
      debateStyle: _roomData?['debateStyle'], // Pass the debate style from room data
      isCurrentUserModerator: _isCurrentUserModerator, // Pass moderator status
      activeReactions: _activeReactions, // Pass active reactions
      onSpeakerTap: (userId) {
        final speaker = _speakerPanelists.firstWhere((s) => s.id == userId);
        final isDebateRoom = _roomData?['debateStyle'] == 'Debate';
        AppLogger().debug('🏛️ Speaker tapped: ${speaker.name}, isDebateRoom: $isDebateRoom, isModerator: $_isCurrentUserModerator');
        
        if (_hasModeratorPowers && isDebateRoom) {
          AppLogger().debug('🏛️ Showing debate participant options');
          _showDebateParticipantOptions(speaker);
        } else {
          AppLogger().debug('🏛️ Showing regular user profile modal');
          _showUserProfileModal(speaker);
        }
      },
      onAudienceTap: (userId) {
        final member = _audienceMembers.firstWhere((m) => m.id == userId);
        AppLogger().debug('🏛️ Audience member tapped: ${member.name}');
        _showUserProfileModal(member);
      },
      onSpeakerRequestApprove: (userId) {
        final user = _speakerRequests.firstWhere((u) => u.id == userId);
        _approveSpeakerRequest(user);
      },

      // Speaker Queue Parameters (only for discussions mode, not debate/take)
      speakerQueue: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _speakerQueue : null,
      currentSpeaker: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _currentSpeaker : null,
      queueEnabled: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _queueEnabled : false,
      onJoinQueue: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _joinSpeakerQueue : null,
      onLeaveQueue: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _leaveSpeakerQueue : null,
      onNextSpeaker: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _nextSpeakerInQueue : null,
      onRemoveFromQueue: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _removeSpeakerFromQueue : null,
      onToggleQueue: _roomData?['debateStyle'] == null || _roomData?['debateStyle'] == 'Discussion' ? _toggleQueueMode : null,
    );
  }

  /// Determine the correct LiveKit room type based on debate style
  String _getRoomTypeForLiveKit() {
    // All three room types (Debate, Take, Discussion) use debate_discussion
    return 'debate_discussion';
  }

  /// Compute user role synchronously - bulletproof against race conditions
  String _computeInitialRole() {
    AppLogger().debug('🎯 ROLE COMPUTATION: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker');
    
    // If you created the room, you're the moderator
    if (_isCurrentUserModerator == true) {
      AppLogger().debug('🎯 ROLE: User is moderator - granting moderator permissions');
      return 'moderator';
    }
    
    if (_isCurrentUserSpeaker == true) {
      AppLogger().debug('🎯 ROLE: User is speaker - granting speaker permissions');
      return 'speaker';
    }
    
    // Additional check: if current user is the room creator, they should be moderator
    if (_roomData != null && _currentUser != null) {
      final isCreator = _roomData!['createdBy'] == _currentUser!.id;
      if (isCreator) {
        AppLogger().debug('🎯 ROLE: User is room creator, assigning moderator role and updating state');
        // Update the moderator state if not already set
        if (!_isCurrentUserModerator) {
          _isCurrentUserModerator = true;
          if (mounted) {
            setState(() {
              // Update UI after setting current user as moderator
            });
          }
        }
        return 'moderator';
      }
    }
    
    // Check if user is in speaker panel (this handles promoted speakers)
    if (_currentUser != null) {
      final isInSpeakerPanel = _speakerPanelists.any((speaker) => speaker.id == _currentUser!.id);
      if (isInSpeakerPanel) {
        AppLogger().debug('🎯 ROLE: User is in speaker panel - granting speaker permissions');
        // Update the speaker state if not already set
        if (!_isCurrentUserSpeaker) {
          _isCurrentUserSpeaker = true;
          if (mounted) {
            setState(() {
              // Update UI after setting current user as speaker
            });
          }
        }
        return 'speaker';
      }
    }
    
    AppLogger().debug('🎯 ROLE: User defaulting to audience role');
    return 'audience';
  }

  /// Helper function to create avatar text content - just first letter
  Widget _buildAvatarText(UserProfile participant, double fontSize) {
    String letter;
    
    if (participant.name.isEmpty) {
      letter = participant.email.isNotEmpty ? participant.email.substring(0, 1).toUpperCase() : 'U';
    } else {
      letter = participant.name.substring(0, 1).toUpperCase();
    }
    
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }


  // Unused method - kept for potential future use
  // ignore: unused_element
  Widget _buildVideoTile(UserProfile participant, {bool isModerator = false, bool showControls = false}) {
    return AnimatedFadeIn(
      child: GestureDetector(
        onTap: () => _showUserProfileModal(participant),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isModerator ? const Color(0xFF8B5CF6) : Colors.grey[700]!,
              width: isModerator ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
            // Video feed or placeholder
            _buildVideoContent(participant, isModerator),
            
            // Name label at bottom
            Positioned(
              bottom: 4,
              left: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isModerator 
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isModerator) ...[
                      const Icon(
                        LucideIcons.crown,
                        color: Colors.white,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(
                        isModerator ? '${participant.name} (Mod)' : participant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Remove button for moderator
            if (showControls && !isModerator)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeSpeaker(participant),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
              ),
            
            // Video disabled - audio-only mode
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Icon(
                  LucideIcons.videoOff,
                  color: Colors.white,
                  size: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // Unused method - kept for potential future use
  // ignore: unused_element
  Widget _buildEmptySlot(int slotNumber) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.userPlus,
              color: Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Slot $slotNumber',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(UserProfile participant, bool isModerator) {
    // WebRTC implementation
    if (_isWebRTCConnected) {
      return _buildWebRTCVideoContent(participant, isModerator);
    }
    
    // Fallback when not connected
    return _buildEmptyVideoContent(participant, isModerator);
  }
  
  Widget _buildEmptyVideoContent(UserProfile participant, bool isModerator) {
    
    // When WebRTC is not connected, show avatar only
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Center(
              // Fallback to avatar when no video
              child: CircleAvatar(
                radius: isModerator ? 32 : 24,
                backgroundColor: const Color(0xFF8B5CF6),
                backgroundImage: participant.avatar != null && participant.avatar!.isNotEmpty
                    ? NetworkImage(participant.avatar!)
                    : null,
                child: participant.avatar == null || participant.avatar!.isEmpty
                    ? _buildAvatarText(participant, isModerator ? 20 : 16)
                    : null,
              ),
            ),
      ),
    );
  }


  // Unused method - kept for potential future use
  // ignore: unused_element
  Widget _buildAudienceMember(UserProfile member) {
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth < 360 ? 36.0 : 42.0;
    final fontSize = screenWidth < 360 ? 9.0 : 10.0;
    
    return GestureDetector(
      onTap: () {
        final isDebateRoom = _roomData?['debateStyle'] == 'Debate';
        if (_hasModeratorPowers && isDebateRoom) {
          _showAudiencePromotionOptions(member);
        } else {
          _showUserProfileModal(member);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withValues(alpha: 0.3),
          borderRadius: BorderRadius.zero, // No border radius for flush look
          border: Border.all(
            color: Colors.grey[700]!,
            width: 0.5,
          ),
        ),
        padding: EdgeInsets.zero, // No padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: const Color(0xFF8B5CF6),
                backgroundImage: member.avatar != null && member.avatar!.isNotEmpty
                    ? NetworkImage(member.avatar!)
                    : null,
                child: member.avatar == null || member.avatar!.isEmpty
                    ? _buildAvatarText(member, avatarSize * 0.35)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              member.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
    );
  }





  Widget _buildControlsBar() {
    return Container(
      key: const ValueKey('debates_controls_bar'),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status text (similar to open discussion)
          Text(
            key: ValueKey('debates_status_${_isCurrentUserModerator ? 'mod' : _isCurrentUserSpeaker ? 'speaker' : _hasRequestedSpeaker ? 'pending' : 'audience'}'),
            _isCurrentUserModerator
              ? '👑 You are the moderator'
              : _isCurrentUserSpeaker
                ? '🎙️ You are a speaker'
                : '👂 You are in the audience${_hasRequestedSpeaker ? ' • Speaker request pending' : ''}',
            style: TextStyle(
              color: _isCurrentUserModerator
                ? Colors.green
                : _isCurrentUserSpeaker
                  ? Colors.green
                  : ArenaColors.accentPurple,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Control buttons - responsive layout for narrow screens
          LayoutBuilder(
            key: const ValueKey('debates_controls_layout'),
            builder: (context, constraints) {
              // If screen is too narrow, make it scrollable
              if (constraints.maxWidth < 500) {
                return SingleChildScrollView(
                  key: const ValueKey('debates_controls_scroll'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    key: const ValueKey('debates_controls_row_narrow'),
                    children: [
                      // Hide chat button if user is timed out
                      if (!_isCurrentUserTimedOut) ...[
                        _buildControlButton(
                          icon: LucideIcons.messageCircle,
                          label: 'Chat',
                          color: const Color(0xFF8B5CF6),
                          onTap: _showChat,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (!_isCurrentUserModerator) ...[
                        _buildControlButton(
                          icon: LucideIcons.hand,
                          label: _isCurrentUserSpeaker 
                            ? 'Leave Panel' 
                            : (_hasRequestedSpeaker ? 'Pending' : 'Raise Hand'),
                          color: _isCurrentUserSpeaker 
                            ? Colors.amber
                            : (_hasRequestedSpeaker ? Colors.orange : ArenaColors.accentPurple),
                          onTap: _isCurrentUserSpeaker ? _requestToLeaveSpeakerPanel : _requestToJoinSpeakers,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildControlButton(
                        icon: LucideIcons.share2,
                        label: 'Share',
                        color: Colors.blue,
                        onTap: _shareRoomToSocial,
                      ),
                      const SizedBox(width: 8),
                      // Audio clip button - only show for speakers and moderators
                      if (_isCurrentUserModerator || _isCurrentUserSpeaker) ...[
                        _buildControlButton(
                          icon: _isRecordingClip ? LucideIcons.square : LucideIcons.scissors,
                          label: _isRecordingClip ? 'Stop Clip' : 'Clip Audio',
                          color: _isRecordingClip ? Colors.red : Colors.purple,
                          onTap: _toggleAudioClip,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildReactionButton(),
                      const SizedBox(width: 8),
                      _buildGiftButton(),
                      const SizedBox(width: 8),
                      _buildControlButton(
                        icon: _isAudioConnected 
                          ? (_isMuted ? Icons.volume_off : Icons.volume_up)
                          : (_isAudioConnecting ? Icons.hourglass_empty : Icons.speaker),
                        label: _isAudioConnected 
                          ? ((_isCurrentUserModerator || _isCurrentUserSpeaker) 
                              ? (_isMuted ? 'Unmute' : 'Mute')
                              : 'Listening')
                          : (_isAudioConnecting ? 'Connecting...' : 'Audio Off'),
                        color: _isAudioConnected 
                          ? ((_isCurrentUserModerator || _isCurrentUserSpeaker)
                              ? (_isMuted ? Colors.red : Colors.green)
                              : Colors.grey)
                          : (_isAudioConnecting ? Colors.orange : Colors.grey),
                        onTap: _isAudioConnected 
                          ? ((_isCurrentUserModerator || _isCurrentUserSpeaker) 
                              ? () => _toggleMute()
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Only speakers and moderators can use mic. Raise your hand to become a speaker!'),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                })
                          : (_isAudioConnecting ? () {} : () {
                              // Retry connection if it failed
                              AppLogger().debug('🔄 RETRY: Retrying audio connection');
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              _connectToAudio().then((_) {
                                AppLogger().debug('🔄 RETRY: Audio reconnection successful');
                              }).catchError((error) {
                                AppLogger().error('🔄 RETRY: Audio reconnection failed: $error');
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to connect audio: ${error.toString()}'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              });
                            }),
                      ),
                      if (kIsWeb && _remoteStreams.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextButton.icon(
                            onPressed: () {
                              _resumeWebAudioContext();
                            },
                            icon: const Icon(Icons.volume_up, size: 16),
                            label: const Text('Enable Audio', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange,
                              backgroundColor: Colors.orange.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _buildControlButton(
                        icon: LucideIcons.logOut,
                        label: 'Leave',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
        ], // End of Row children
      ), // End of Row
    ); // End of SingleChildScrollView
              } else {
                // For wider screens, use normal spaced layout
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Hide chat button if user is timed out
                    if (!_isCurrentUserTimedOut)
                      _buildControlButton(
                        icon: LucideIcons.messageCircle,
                        label: 'Chat',
                        color: const Color(0xFF8B5CF6),
                        onTap: _showChat,
                      ),
                    if (!_isCurrentUserModerator)
                      _buildControlButton(
                        icon: LucideIcons.hand,
                        label: _isCurrentUserSpeaker 
                          ? 'Leave Panel' 
                          : (_hasRequestedSpeaker ? 'Pending' : 'Raise Hand'),
                        color: _isCurrentUserSpeaker 
                          ? Colors.amber
                          : (_hasRequestedSpeaker ? Colors.orange : ArenaColors.accentPurple),
                        onTap: _isCurrentUserSpeaker ? _requestToLeaveSpeakerPanel : _requestToJoinSpeakers,
                      ),
                    _buildControlButton(
                      icon: LucideIcons.share2,
                      label: 'Share',
                      color: Colors.blue,
                      onTap: _shareRoomToSocial,
                    ),
                    // Audio clip button - only show for speakers and moderators
                    if (_isCurrentUserModerator || _isCurrentUserSpeaker)
                      _buildControlButton(
                        icon: _isRecordingClip ? LucideIcons.square : LucideIcons.scissors,
                        label: _isRecordingClip ? 'Stop Clip' : 'Clip Audio',
                        color: _isRecordingClip ? Colors.red : Colors.purple,
                        onTap: _toggleAudioClip,
                      ),
                    _buildReactionButton(),
                    _buildGiftButton(),
                    _buildControlButton(
                      icon: _isAudioConnected
                        ? (_isMuted ? Icons.volume_off : Icons.volume_up)
                        : (_isAudioConnecting ? Icons.hourglass_empty : Icons.speaker),
                      label: _isAudioConnected 
                        ? ((_isCurrentUserModerator || _isCurrentUserSpeaker) 
                            ? (_isMuted ? 'Unmute' : 'Mute')
                            : 'Listening')
                        : (_isAudioConnecting ? 'Connecting...' : 'Audio Off'),
                      color: _isAudioConnected 
                        ? ((_isCurrentUserModerator || _isCurrentUserSpeaker)
                            ? (_isMuted ? Colors.red : Colors.green)
                            : Colors.grey)
                        : (_isAudioConnecting ? Colors.orange : Colors.grey),
                      onTap: _isAudioConnected 
                        ? ((_isCurrentUserModerator || _isCurrentUserSpeaker) 
                            ? () => _toggleMute()
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Only speakers and moderators can use mic. Raise your hand to become a speaker!'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              })
                        : (_isAudioConnecting ? () {} : () {
                            // Retry connection if it failed
                            AppLogger().debug('🔄 RETRY: Retrying audio connection');
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            _connectToAudio().then((_) {
                              AppLogger().debug('🔄 RETRY: Audio reconnection successful');
                            }).catchError((error) {
                              AppLogger().error('🔄 RETRY: Audio reconnection failed: $error');
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to connect audio: ${error.toString()}'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            });
                          }),
                    ),
                    if (kIsWeb && _remoteStreams.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextButton.icon(
                          onPressed: () {
                            _resumeWebAudioContext();
                          },
                          icon: const Icon(Icons.volume_up, size: 16),
                          label: const Text('Enable Audio', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                            backgroundColor: Colors.orange.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ),
                    _buildControlButton(
                      icon: LucideIcons.logOut,
                      label: 'Leave',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                );
              }
            },
          ),
      ], // End of Column children
    ), // End of Column
  ); // End of Container
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D), // Dark background like arena theme
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Show chat modal
  void _showChat() {
    if (_currentUser == null) return;

    // Prevent opening chat if user is timed out
    if (_isCurrentUserTimedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ You are timed out and cannot access chat'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Create participants list for chat
    final chatParticipants = <ChatParticipant>[
      // Add moderator
      if (_moderator != null)
        ChatParticipant(
          userId: _moderator!.id,
          username: _moderator!.name,
          role: 'moderator',
          avatar: _moderator!.avatar,
        ),
      // Add speakers
      ..._speakerPanelists.map((speaker) => ChatParticipant(
        userId: speaker.id,
        username: speaker.name,
        role: 'speaker',
        avatar: speaker.avatar,
      )),
      // Add audience members
      ..._audienceMembers.map((audience) => ChatParticipant(
        userId: audience.id,
        username: audience.name,
        role: 'audience',
        avatar: audience.avatar,
      )),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => MattermostChatWidget(
        currentUserId: _currentUser!.id,
        currentUser: _currentUser!,
        roomId: widget.roomId,
        participants: chatParticipants,
        onClose: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
      ),
    );
  }


  void _showModeratorTools() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const Text(
              'Moderator Tools',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildOptionTile(
                      icon: LucideIcons.userPlus,
                      title: 'Manage Speakers',
                      onTap: () {
                        Navigator.pop(context);
                        _showSpeakerManagement();
                      },
                    ),
                    _buildOptionTile(
                      icon: LucideIcons.users2,
                      title: 'Assign Roles',
                      onTap: () {
                        Navigator.pop(context);
                        _showRoleAssignment();
                      },
                    ),
                    _buildOptionTile(
                      icon: LucideIcons.micOff,
                      title: 'Mute All',
                      onTap: () {
                        Navigator.pop(context);
                        _muteAllParticipants();
                      },
                    ),
                    _buildOptionTile(
                      icon: LucideIcons.clock,
                      title: 'Room Duration',
                      onTap: () {
                        Navigator.pop(context);
                        _showRoomDurationInfo();
                      },
                    ),
                    _buildOptionTile(
                      icon: _queueEnabled ? LucideIcons.pauseCircle : LucideIcons.playCircle,
                      title: _queueEnabled ? 'Disable Speaker Queue' : 'Enable Speaker Queue',
                      onTap: () {
                        Navigator.pop(context);
                        _toggleQueueMode();
                      },
                    ),
                                _buildOptionTile(
              icon: LucideIcons.alertTriangle,
              title: 'End Room',
              onTap: () {
                Navigator.pop(context);
                _showEndRoomConfirmation();
              },
            ),
            
            // Connection health info
            if (_connectionDropCount > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          color: Colors.orange,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Connection Health',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drops detected: $_connectionDropCount',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                    if (_lastConnectionDrop != null) ...[
                      Text(
                        'Last drop: ${_formatTimestamp(_lastConnectionDrop!)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Auto-reconnection is active and monitoring your connection.',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  void _showSpeakerManagement() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Speaker Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Current Speakers
              if (_speakerPanelists.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Current Speakers',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  key: const ValueKey('speaker_panelists_list'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _speakerPanelists.length,
                  itemBuilder: (context, index) {
                    final speaker = _speakerPanelists[index];
                    final isModerator = speaker.id == _moderator?.id;
                    
                    return ListTile(
                      key: ValueKey('speaker_${speaker.id}'),
                      leading: CircleAvatar(
                        backgroundColor: isModerator ? const Color(0xFF8B5CF6) : Colors.grey[600],
                        child: _buildAvatarText(speaker, 14),
                      ),
                      title: Text(
                        speaker.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        isModerator ? 'Moderator' : 'Speaker',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: !isModerator ? IconButton(
                        icon: const Icon(LucideIcons.userX, color: Colors.red),
                        onPressed: () => _removeSpeaker(speaker),
                      ) : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
              
              // Pending Requests
              if (_speakerRequests.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pending Speaker Requests',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('speaker_requests_list'),
                    controller: scrollController,
                    itemCount: _speakerRequests.length,
                    itemBuilder: (context, index) {
                      final user = _speakerRequests[index];

                      return ListTile(
                        key: ValueKey('speaker_request_${user.id}'),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: _buildAvatarText(user, 14),
                        ),
                        title: Text(
                          user.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Wants to join speakers',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.check, color: Colors.green),
                              onPressed: () => _approveSpeakerRequest(user),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x, color: Colors.red),
                              onPressed: () => _denySpeakerRequest(user),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Text(
                      'No pending speaker requests',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleAssignment() {
    final isDebateRoom = _roomData?['debateStyle'] == 'Debate';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Assign Roles',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Show position availability for debate rooms
              if (isDebateRoom) ...[
                _buildPositionStatus(),
                const SizedBox(height: 20),
              ],
              
              // Show all audience members for role assignment
              if (_audienceMembers.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Audience Members',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('audience_members_list'),
                    controller: scrollController,
                    itemCount: _audienceMembers.length,
                    itemBuilder: (context, index) {
                      final member = _audienceMembers[index];
                      final hasAffirmative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'affirmative');
                      final hasNegative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'negative');
                      final canAssign = !isDebateRoom || (!hasAffirmative || !hasNegative);
                      
                      return ListTile(
                        key: ValueKey('audience_member_${member.id}'),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF8B5CF6),
                          child: _buildAvatarText(member, 14),
                        ),
                        title: Text(
                          member.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          isDebateRoom && !canAssign
                              ? 'All positions filled'
                              : 'Audience Member',
                          style: TextStyle(
                            color: isDebateRoom && !canAssign
                                ? Colors.orange[400]
                                : Colors.grey[400],
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            canAssign ? LucideIcons.userCheck : LucideIcons.userX,
                            color: canAssign ? const Color(0xFF8B5CF6) : Colors.grey[600],
                          ),
                          onPressed: canAssign ? () => _showRoleSelectionDialog(member) : null,
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Text(
                      'No audience members available',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionStatus() {
    final hasAffirmative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'affirmative');
    final hasNegative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'negative');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debate Positions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPositionIndicator(
                  icon: LucideIcons.thumbsUp,
                  title: 'Affirmative',
                  isOccupied: hasAffirmative,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPositionIndicator(
                  icon: LucideIcons.thumbsDown,
                  title: 'Negative',
                  isOccupied: hasNegative,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionIndicator({
    required IconData icon,
    required String title,
    required bool isOccupied,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOccupied ? Colors.red[900]?.withValues(alpha: 0.3) : Colors.green[900]?.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOccupied ? Colors.red[700]! : Colors.green[700]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isOccupied ? Colors.red[400] : Colors.green[400],
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: isOccupied ? Colors.red[400] : Colors.green[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isOccupied ? 'FILLED' : 'OPEN',
            style: TextStyle(
              color: isOccupied ? Colors.red[300] : Colors.green[300],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showRoleSelectionDialog(UserProfile member) {
    final isDebateRoom = _roomData?['debateStyle'] == 'Debate';
    
    if (isDebateRoom) {
      // Check which debate positions are already occupied
      final hasAffirmative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'affirmative');
      final hasNegative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'negative');
      
      AppLogger().debug('🏛️ Debate positions check - Affirmative: $hasAffirmative, Negative: $hasNegative');
      
      // If both positions are filled, show error
      if (hasAffirmative && hasNegative) {
        _showPositionFullDialog();
        return;
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Assign Role to ${member.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show available positions only
              if (!hasAffirmative) ...[
                _buildRoleOption(
                  icon: LucideIcons.thumbsUp,
                  title: 'Affirmative',
                  subtitle: 'Pro side of the debate',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Close role assignment sheet
                    _assignRole(member, 'affirmative');
                  },
                ),
                if (!hasNegative) const SizedBox(height: 8),
              ],
              if (!hasNegative) ...[
                _buildRoleOption(
                  icon: LucideIcons.thumbsDown,
                  title: 'Negative',
                  subtitle: 'Against side of the debate',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Close role assignment sheet
                    _assignRole(member, 'negative');
                  },
                ),
              ],
              
              // Show occupied positions with indicators
              if (hasAffirmative) ...[
                _buildOccupiedRoleOption(
                  icon: LucideIcons.thumbsUp,
                  title: 'Affirmative',
                  subtitle: 'Position already filled',
                ),
                if (!hasNegative) const SizedBox(height: 8),
              ],
              if (hasNegative) ...[
                _buildOccupiedRoleOption(
                  icon: LucideIcons.thumbsDown,
                  title: 'Negative', 
                  subtitle: 'Position already filled',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
    } else {
      // For discussion rooms, show Speaker option (no restrictions)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Assign Role to ${member.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRoleOption(
                icon: LucideIcons.mic,
                title: 'Speaker',
                subtitle: 'Can participate in discussion',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Close role assignment sheet
                  _assignRole(member, 'speaker');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRoleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupiedRoleOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.lock, color: Colors.grey[600], size: 16),
        ],
      ),
    );
  }

  void _showPositionFullDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Debate Positions Full',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.users,
              color: Colors.orange,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Both Affirmative and Negative positions are already filled.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You must remove a current debater before assigning a new one.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );
  }

  Future<void> _assignRole(UserProfile member, String role) async {
    try {
      AppLogger().info('Assigning role "$role" to ${member.name}');
      
      // Update the participant's role in the database
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: member.id,
        newRole: role,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${member.name} assigned as $role'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // The real-time subscription will update the UI automatically
    } catch (e) {
      AppLogger().error('Error assigning role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _muteAllParticipants() async {
    try {
      AppLogger().debug('🔇 Attempting to mute all participants...');
      AppLogger().debug('🔇 WebRTC connected: ${_webrtcService.isConnected}');
      AppLogger().debug('🔇 Current user role: ${_webrtcService.userRole}');
      AppLogger().debug('🔇 Is moderator: $_isCurrentUserModerator');
      AppLogger().debug('🔇 Remote participants count: ${_webrtcService.remoteParticipants.length}');
      
      if (!_webrtcService.isConnected) {
        AppLogger().warning('🔇 WebRTC not connected, cannot mute participants');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Not connected to audio service'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Check if user is moderator OR super moderator
      final superModService = SuperModeratorService();
      final currentUserId = _currentUser?.id ?? '';
      final isSuperMod = superModService.isSuperModerator(currentUserId);
      
      if (!_hasModeratorPowers && !isSuperMod) {
        AppLogger().warning('🔇 User is not moderator or super mod, cannot mute all');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Only moderators and super moderators can mute all participants'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show confirmation dialog to prevent accidental mute all
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🔇 Mute All Participants'),
          content: Text('Are you sure you want to mute all ${_webrtcService.remoteParticipants.length} participants? This will silence everyone in the room.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Mute All'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Use LiveKit to mute all participants
      await _webrtcService.muteAllParticipants();

      AppLogger().info('🔇 Successfully sent confirmed mute all command');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔇 Muting all participants (${_webrtcService.remoteParticipants.length} users)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Error muting all participants: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error muting participants: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ignore: unused_element
  void _showRoomSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Room Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: LucideIcons.users,
              title: 'Speaker Limit (Currently: ${_speakerPanelists.length}/7)',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room supports up to 6 speakers + 1 moderator')),
                );
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.clock,
              title: 'Room Duration',
              onTap: () {
                Navigator.pop(context);
                _showRoomDurationInfo();
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.share,
              title: 'Share Room',
              onTap: () {
                Navigator.pop(context);
                _shareRoomToSocial();
              },
            ),
            // Add recruitment option for moderators
            if (_hasModeratorPowers)
              _buildOptionTile(
                icon: LucideIcons.users,
                title: 'Recruit Participants',
                onTap: () {
                  Navigator.pop(context);
                  _showStreamingOptions();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEndRoomConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'End Room',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to end this room? All participants will be disconnected and the room will be closed permanently.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endRoom();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Room'),
          ),
        ],
      ),
    );
  }

  void _denySpeakerRequest(UserProfile user) async {
    try {
      // OPTIMISTIC UPDATE: Update moderator UI BEFORE database call
      if (mounted) {
        setState(() {
          _speakerRequests.removeWhere((request) => request.id == user.id);

          // Make sure user is in audience (not speakers)
          if (!_audienceMembers.any((p) => p.id == user.id)) {
            _audienceMembers.add(user);
          }

          // Update participant role mapping
          _participantRoles[user.id] = 'audience';
        });

        AppLogger().info('⚡ OPTIMISTIC: Moderator sees ${user.name} denied instantly');
      }

      // Change user role back to audience
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: user.id,
        newRole: 'audience',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Denied speaker request from ${user.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      AppLogger().info('Moderator denied speaker request from ${user.name}');
    } catch (e) {
      AppLogger().error('Error denying speaker request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error denying request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== SPEAKER QUEUE MANAGEMENT ====================

  /// Join the speaker queue (for speakers in the 8-panel)
  Future<void> _joinSpeakerQueue() async {
    if (!mounted || _currentUser == null) return;

    final currentUserId = _currentUser!.id;
    final isCurrentUserSpeaker = _speakerPanelists.any((s) => s.id == currentUserId);

    // Only speakers in the panel can join the queue
    if (!isCurrentUserSpeaker) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Only speakers in the panel can join the queue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if already in queue
    if (_speakerQueue.contains(currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ You are already in the speaker queue'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if already speaking
    if (_currentSpeaker == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎤 You are already the current speaker'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    try {
      // Add to Appwrite collection
      final queuePosition = _speakerQueue.length + 1;
      await _appwrite.addToSpeakerQueue(
        roomId: widget.roomId,
        userId: currentUserId,
        userName: _currentUser!.name,
        queuePosition: queuePosition,
      );

      // Local state will be updated by real-time subscription
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added to queue (position $queuePosition)'),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger().info('User ${_currentUser!.name} joined speaker queue at position $queuePosition');
    } catch (e) {
      AppLogger().error('❌ Failed to join speaker queue: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to join speaker queue'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Leave the speaker queue
  Future<void> _leaveSpeakerQueue() async {
    if (!mounted || _currentUser == null) return;

    final currentUserId = _currentUser!.id;

    if (!_speakerQueue.contains(currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You are not in the speaker queue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Remove from Appwrite collection
      await _appwrite.removeFromSpeakerQueue(
        roomId: widget.roomId,
        userId: currentUserId,
      );

      // Local state will be updated by real-time subscription
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Removed from speaker queue'),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger().info('User ${_currentUser!.name} left speaker queue');
    } catch (e) {
      AppLogger().error('❌ Failed to leave speaker queue: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to leave speaker queue'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Moderator: Advance to next speaker in queue
  Future<void> _nextSpeakerInQueue() async {
    if (!mounted || !_hasModeratorPowers) return;

    if (_speakerQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Speaker queue is empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final nextSpeakerId = _speakerQueue.first;

    try {
      // Update in Appwrite - set status to 'speaking'
      await _appwrite.setCurrentSpeaker(
        roomId: widget.roomId,
        userId: nextSpeakerId,
      );

      // Find speaker name for notification
      final nextSpeaker = _speakerPanelists.firstWhere(
        (s) => s.id == nextSpeakerId,
        orElse: () => UserProfile(
          id: nextSpeakerId,
          name: 'Unknown Speaker',
          email: '',
          avatar: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Local state will be updated by real-time subscription
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎤 ${nextSpeaker.name} is now speaking'),
          backgroundColor: Colors.green,
        ),
      );

      AppLogger().info('Moderator advanced queue: ${nextSpeaker.name} is now speaking');
    } catch (e) {
      AppLogger().error('❌ Failed to advance speaker queue: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to advance speaker queue'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Moderator: Remove speaker from queue
  Future<void> _removeSpeakerFromQueue(String userId) async {
    if (!mounted || !_hasModeratorPowers) return;

    if (!_speakerQueue.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Speaker not in queue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Remove from Appwrite collection
      await _appwrite.removeFromSpeakerQueue(
        roomId: widget.roomId,
        userId: userId,
      );

      // Find speaker name for notification
      final speaker = _speakerPanelists.firstWhere(
        (s) => s.id == userId,
        orElse: () => UserProfile(
          id: userId,
          name: 'Unknown Speaker',
          email: '',
          avatar: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Local state will be updated by real-time subscription
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Removed ${speaker.name} from queue'),
          backgroundColor: Colors.orange,
        ),
      );

      AppLogger().info('Moderator removed ${speaker.name} from speaker queue');
    } catch (e) {
      AppLogger().error('❌ Failed to remove speaker from queue: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to remove speaker from queue'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  /// Toggle queue mode on/off - now syncs across all users
  void _toggleQueueMode() async {
    if (!mounted || !_hasModeratorPowers) return;

    final newQueueState = !_queueEnabled;

    try {
      // Update room document in database to sync across all users
      await _appwrite.updateDebateDiscussionRoom(
        roomId: widget.roomId,
        data: {
          'queueEnabled': newQueueState,
        },
      );

      // Update local state
      setState(() {
        _queueEnabled = newQueueState;
        if (!_queueEnabled) {
          // Clear queue and current speaker when disabling
          _speakerQueue.clear();
          _currentSpeaker = null;

          // Also clear any pending speaker requests
          _speakerRequests.clear();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _queueEnabled
              ? '✅ Speaker queue enabled for all participants'
              : '❌ Speaker queue disabled for all participants'
          ),
          backgroundColor: _queueEnabled ? Colors.green : Colors.orange,
        ),
      );

      AppLogger().info('Moderator ${_queueEnabled ? "enabled" : "disabled"} speaker queue - synced to all users');
    } catch (e) {
      AppLogger().error('Failed to update queue status: $e');

      // Check if this is a field-not-found error (older rooms without queueEnabled field)
      if (e.toString().contains('Server Error (500)') ||
          e.toString().contains('document') ||
          e.toString().contains('queueEnabled')) {

        AppLogger().info('Attempting to initialize queueEnabled field for older room');

        try {
          // Try to initialize the field by getting current room data and adding queueEnabled
          final currentRoomData = await _appwrite.getDebateDiscussionRoom(widget.roomId);
          if (currentRoomData != null) {
            // Create a complete update with all existing data plus queueEnabled
            final updateData = Map<String, dynamic>.from(currentRoomData);
            updateData['queueEnabled'] = newQueueState;

            // Try update again with full data
            await _appwrite.updateDebateDiscussionRoom(
              roomId: widget.roomId,
              data: {
                'queueEnabled': newQueueState,
              },
            );

            // Update local state on success
            setState(() {
              _queueEnabled = newQueueState;
              if (!_queueEnabled) {
                _speakerQueue.clear();
                _currentSpeaker = null;
                _speakerRequests.clear();
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _queueEnabled
                    ? '✅ Speaker queue enabled for all participants'
                    : '❌ Speaker queue disabled for all participants'
                ),
                backgroundColor: _queueEnabled ? Colors.green : Colors.orange,
              ),
            );

            AppLogger().info('Successfully initialized and updated queue status');
            return; // Exit successfully
          }
        } catch (initError) {
          AppLogger().error('Failed to initialize queueEnabled field: $initError');
        }
      }

      // Show error feedback if initialization failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update queue status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRoomDurationInfo() {
    final startTime = _roomData?['createdAt'];
    final duration = startTime != null ? 
      DateTime.now().difference(DateTime.parse(startTime)) : 
      const Duration(minutes: 0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Room has been active for ${duration.inHours}h ${duration.inMinutes % 60}m',
        ),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }



  void _shareRoomToSocial() async {
    final roomName = _roomData?['name'] ?? 'Debate Room';
    final moderatorName = _moderator?.name ?? 'Unknown';
    final participantCount = _speakerPanelists.length + _audienceMembers.length;
    
    // Create shareable room info for beta testing
    final shareText = '''🎙️ Join our live debate discussion!

Room: $roomName
Moderator: $moderatorName
Participants: $participantCount

Room ID: ${widget.roomId}

To join this debate:
1. Download Arena from TestFlight (iOS) or APK (Android)
2. Open Arena app
3. Use Room ID: ${widget.roomId} to join

#ArenaDebate #LiveDebate #Discussion #beta''';

    try {
      // Direct native share - this should show the grid of apps like in your image
      // Including Facebook, Instagram, TikTok, X (Twitter), Messages, WhatsApp etc.
      await Share.share(
        shareText,
        subject: '🎙️ Join our live debate discussion!',
      );
    } catch (e) {
      // Fallback to clipboard if native share fails
      Clipboard.setData(ClipboardData(text: shareText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room details copied to clipboard - paste in any app to share!'),
            backgroundColor: Color(0xFF8B5CF6),
          ),
        );
      }
    }
  }

  void _showStreamingOptions() async {
    // Use participant recruitment service to grow debate audience
    await ParticipantRecruitmentService().showRecruitmentOptions(
      context, 
      widget.roomId, 
      _roomData?['name'] ?? 'Debate Room'
    );
  }

  void _endRoom() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ending room...'),
          backgroundColor: Colors.orange,
        ),
      );

      // Update room status to ended
      await _appwrite.updateDebateDiscussionRoom(
        roomId: widget.roomId,
        data: {
          'status': 'ended',
        },
      );

      // Audio cleanup handled by LiveKit

      // Navigate back to room list
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      AppLogger().info('Room ended by moderator');
    } catch (e) {
      AppLogger().error('Error ending room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadGiftData() async {
    try {
      // Load user coin balance
      if (_currentUser != null) {
        final balance = await _giftService.getUserCoinBalance(_currentUser!.id);
        if (mounted) {
          setState(() {
            _currentUserCoinBalance = balance;
          });
        }
      }
      
      // Load available gifts
      setState(() {
        _availableGifts = GiftConstants.allGifts;
      });
      
      AppLogger().debug('Loaded gift data - Balance: $_currentUserCoinBalance, Gifts: ${_availableGifts.length}');
    } catch (e) {
      AppLogger().error('Error loading gift data: $e');
    }
  }

  /// Initialize real-time speaker queue synchronization via Appwrite
  Future<void> _initializeSpeakerQueueSync() async {
    if (!mounted) return;

    try {
      // Load existing queue from Appwrite
      await _loadSpeakerQueueFromAppwrite();

      // Subscribe to real-time updates
      _speakerQueueSubscription = _appwrite.subscribeToSpeakerQueue(
        roomId: widget.roomId,
        onUpdate: _onSpeakerQueueUpdate,
      );

      AppLogger().info('🔄 Speaker queue real-time sync initialized for room ${widget.roomId}');
    } catch (e) {
      AppLogger().error('❌ Failed to initialize speaker queue sync: $e');
    }
  }

  /// Load existing speaker queue from Appwrite
  Future<void> _loadSpeakerQueueFromAppwrite() async {
    try {
      final queueItems = await _appwrite.getSpeakerQueue(widget.roomId);

      if (mounted) {
        setState(() {
          _speakerQueue.clear();
          for (final item in queueItems) {
            _speakerQueue.add(item['userId']);
          }
        });
      }

      AppLogger().info('📋 Loaded ${_speakerQueue.length} items from speaker queue');
    } catch (e) {
      AppLogger().error('❌ Failed to load speaker queue: $e');
    }
  }

  /// Handle real-time speaker queue updates
  void _onSpeakerQueueUpdate(Map<String, dynamic> queueData) {
    if (!mounted) return;

    try {
      final String roomId = queueData['roomId'];
      if (roomId != widget.roomId) return;

      // Handle reload event (triggered by delete operations)
      if (queueData['type'] == 'reload') {
        _loadSpeakerQueueFromAppwrite();
        AppLogger().info('🔄 Reloading speaker queue due to delete event');
        return;
      }

      final String userId = queueData['userId'];
      final String status = queueData['status'];
      final int queuePosition = queueData['queuePosition'];

      if (status == 'queued') {
        // Add user to queue if not already present
        if (!_speakerQueue.contains(userId)) {
          setState(() {
            // Insert at correct position
            if (queuePosition <= _speakerQueue.length) {
              _speakerQueue.insert(queuePosition - 1, userId);
            } else {
              _speakerQueue.add(userId);
            }
          });
          AppLogger().info('➕ Added $userId to speaker queue at position $queuePosition');
        }
      } else if (status == 'speaking') {
        // Set as current speaker and remove from queue
        setState(() {
          _currentSpeaker = userId;
          _speakerQueue.remove(userId);
        });
        AppLogger().info('🎤 User $userId is now speaking');
      }
    } catch (e) {
      AppLogger().error('❌ Error handling speaker queue update: $e');
    }
  }

  /// Initialize real-time reactions sync
  Future<void> _initializeReactionsSync() async {
    if (!mounted) return;

    try {
      // Subscribe to reactions for this room
      final realtime = _appwrite.realtime;

      _reactionsSubscription = realtime.subscribe([
        'databases.arena_db.collections.room_reactions.documents'
      ]);

      _reactionsSubscription!.stream.listen((response) {
        if (!mounted) return;

        try {
          final payload = response.payload;

          // Only process create events
          if (response.events.any((event) => event.contains('.create'))) {
            final roomId = payload['roomId'];

            // Only process reactions for this room
            if (roomId == widget.roomId) {
              final reaction = ReactionData.fromMap(payload, payload['\$id']);

              // Add to active reactions
              setState(() {
                _activeReactions.add(reaction);
              });

              // Remove after duration (gifts stay longer)
              final duration = reaction.isGift
                  ? const Duration(seconds: 7)  // Gifts stay 7 seconds
                  : const Duration(seconds: 3); // Reactions stay 3 seconds

              Future.delayed(duration, () {
                if (mounted) {
                  setState(() {
                    _activeReactions.removeWhere((r) => r.id == reaction.id);
                  });
                }
              });

              if (reaction.isGift) {
                AppLogger().info('🎁 Received gift: ${reaction.emoji} (${reaction.giftName}) from ${reaction.senderName} to ${reaction.targetUserId}');
              } else {
                AppLogger().info('✨ Received reaction: ${reaction.emoji} for ${reaction.targetUserId}');
              }
            }
          }
        } catch (e) {
          AppLogger().error('❌ Error processing reaction update: $e');
        }
      });

      AppLogger().info('🔄 Reactions real-time sync initialized for room ${widget.roomId}');
    } catch (e) {
      AppLogger().error('❌ Failed to initialize reactions sync: $e');
    }
  }

  // Gift modal methods - simplified to use working gift bottom sheet
  void _showGiftModal() {
    AppLogger().debug('🎁 DEBUG: Gift modal button pressed');
    
    // Get eligible recipients (moderator and speakers only, excluding self)
    final eligibleRecipients = <UserProfile>[];
    
    // Add moderator if not current user
    if (_moderator != null && _moderator!.id != _currentUser!.id) {
      eligibleRecipients.add(_moderator!);
    }
    
    // Add speakers if not current user
    for (final speaker in _speakerPanelists) {
      if (speaker.id != _currentUser!.id && !eligibleRecipients.any((r) => r.id == speaker.id)) {
        eligibleRecipients.add(speaker);
      }
    }

    if (eligibleRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No eligible recipients. Only moderators and speakers can receive gifts.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Simple recipient selection modal that opens working gift bottom sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Gift Recipient',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...eligibleRecipients.map((recipient) => ListTile(
              leading: CircleAvatar(
                child: Text(recipient.initials),
              ),
              title: Text(recipient.displayName),
              subtitle: Text(_moderator?.id == recipient.id ? 'Moderator' : 'Speaker'),
              onTap: () {
                Navigator.pop(context);
                showSimpleGiftBottomSheet(
                  context,
                  recipient: recipient,
                  roomId: widget.roomId,
                  onGiftSent: (emoji, giftName, giftValue, senderName) {
                    _broadcastGift(emoji, giftName, giftValue, senderName, recipient.id);
                  },
                );
              },
            )).toList(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }













  Widget _buildReactionButton() {
    return GestureDetector(
      onTap: _showReactionPicker,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: const Icon(
          LucideIcons.smile,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildGiftButton() {
    return GestureDetector(
      onTap: _showGiftModal,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.card_giftcard,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _showReactionPicker() {
    // Get all speakers (moderator + speakers in slots)
    final speakers = <Map<String, dynamic>>[];

    // Add moderator
    if (_moderator != null) {
      speakers.add({
        'userId': _moderator!.id,
        'name': _moderator!.name,
        'avatarUrl': _moderator!.avatar ?? '',
        'role': 'moderator',
      });
    }

    // Add speakers
    for (final speaker in _speakerPanelists) {
      speakers.add({
        'userId': speaker.id,
        'name': speaker.name,
        'avatarUrl': speaker.avatar ?? '',
        'role': 'speaker',
      });
    }

    if (speakers.isEmpty) {
      // No speakers available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No speakers available to react to'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show speaker selection bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade400,
              offset: const Offset(8, 8),
              blurRadius: 16,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-8, -8),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'Send Reaction To',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            // Speaker list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: speakers.length,
                itemBuilder: (context, index) {
                  final speaker = speakers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF8B5CF6),
                      backgroundImage: speaker['avatarUrl'].isNotEmpty
                          ? NetworkImage(speaker['avatarUrl'])
                          : null,
                      child: speaker['avatarUrl'].isEmpty
                          ? Text(
                              speaker['name'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      speaker['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    subtitle: Text(
                      speaker['role'] == 'moderator' ? 'Moderator' : 'Speaker',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showEmojiPicker(speaker);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(Map<String, dynamic> targetSpeaker) {
    // Common reaction emojis
    final emojis = [
      '👍', // Thumbs up
      '👎', // Thumbs down
      '😂', // Laughing
      '😮', // Wow
      '💯', // 100
      '❤️', // Heart
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade400,
                offset: const Offset(8, 8),
                blurRadius: 16,
              ),
              const BoxShadow(
                color: Colors.white,
                offset: Offset(-8, -8),
                blurRadius: 16,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    'React to ${targetSpeaker['name']}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Emoji grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = emojis[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _sendReaction(emoji, targetSpeaker);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  offset: const Offset(4, 4),
                                  blurRadius: 8,
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-4, -4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendReaction(String emoji, Map<String, dynamic> targetSpeaker) async {
    if (!mounted || _currentUser == null) return;

    try {
      // Create reaction data
      final reaction = ReactionData(
        emoji: emoji,
        targetUserId: targetSpeaker['userId'],
        senderUserId: _currentUser!.id,
        timestamp: DateTime.now(),
      );

      // Save to Appwrite to broadcast to all users
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'room_reactions',
        documentId: ID.unique(),
        data: {
          ...reaction.toMap(),
          'roomId': widget.roomId,
        },
      );

      AppLogger().info('✅ Reaction sent: $emoji to ${targetSpeaker['name']}');
    } catch (e) {
      AppLogger().error('❌ Error sending reaction: $e');
    }
  }

  Future<void> _broadcastGift(
    String emoji,
    String giftName,
    int giftValue,
    String senderName,
    String targetUserId,
  ) async {
    AppLogger().debug('🎁 _broadcastGift called: $emoji ($giftName) value=$giftValue from=$senderName to=$targetUserId');

    if (!mounted || _currentUser == null) {
      AppLogger().warning('⚠️ Cannot broadcast gift - mounted=$mounted, currentUser=${_currentUser != null}');
      return;
    }

    try {
      // Create gift reaction data
      final giftReaction = ReactionData(
        emoji: emoji,
        targetUserId: targetUserId,
        senderUserId: _currentUser!.id,
        senderName: senderName,
        timestamp: DateTime.now(),
        isGift: true,
        giftValue: giftValue,
        giftName: giftName,
      );

      AppLogger().debug('🎁 Creating Appwrite document for gift...');

      // Save to Appwrite to broadcast to all users
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'room_reactions',
        documentId: ID.unique(),
        data: {
          ...giftReaction.toMap(),
          'roomId': widget.roomId,
        },
      );

      AppLogger().info('✅ Gift sent to Appwrite: $emoji ($giftName) value=$giftValue to $targetUserId');
    } catch (e) {
      AppLogger().error('❌ Error broadcasting gift: $e');
    }
  }

  // void _showUserProfile(UserProfile userProfile, String? userRole) {
  //   showDialog(
  //     context: context,
  //     barrierColor: Colors.transparent,
  //     builder: (context) => UserProfileModal(
  //       userProfile: userProfile,
  //       userRole: userRole,
  //       currentUser: _currentUser,
  //       onClose: () => Navigator.of(context).pop(),
  //     ),
  //   );
  // }



  void _showMaterialsSheet() {
    AppLogger().info('📊 MATERIALS BUTTON CLICKED - Service available: ${_materialSyncService != null}');
    if (_materialSyncService == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DebateBottomSheet(
        roomId: widget.roomId,
        userId: _currentUser?.id ?? "",
        isHost: _hasModeratorPowers || _isCurrentUserSpeaker,
        syncService: _materialSyncService!,
        appwriteService: _appwrite,
        onClose: () => Navigator.pop(context),
      ),
      ),
    );
  }

  void _showSharedLinkPopup(DebateSource sharedLink) {
    if (!mounted || _isDisposing) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SharedLinkPopup(
        sharedLink: sharedLink,
        onDismiss: () {
          AppLogger().info('📌 Shared link popup dismissed');
        },
      ),
    );
  }

  void _showSlideUpdatePopup(dynamic materialSync) {
    if (!mounted || _isDisposing || _materialSyncService == null) return;
    
    // Create SlideData from material sync data
    final slideData = SlideData(
      fileId: materialSync.slideFileId ?? '',
      fileName: materialSync.fileName ?? 'Presentation',
      currentSlide: materialSync.currentSlide ?? 1,
      totalSlides: materialSync.totalSlides ?? 0,
      pdfUrl: materialSync.pdfUrl,
      uploadedBy: materialSync.userId ?? '',
      uploadedByName: materialSync.userName,
      uploadedAt: materialSync.timestamp ?? DateTime.now(),
    );
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SlideUpdatePopup(
        slideData: slideData,
        syncService: _materialSyncService!,
        appwriteService: _appwrite,
        currentUserId: _currentUser?.id ?? '',
        roomId: widget.roomId,
        onDismiss: () {
          AppLogger().info('📊 Slide update popup dismissed');
        },
      ),
    );
  }

  /// Handle audio clip recording toggle
  Future<void> _toggleAudioClip() async {
    try {
      if (!_isRecordingClip) {
        // Start recording audio clip
        AppLogger().info('🎙️ Starting audio clip recording');
        
        // Show dialog to get clip title
        final clipTitle = await _showClipTitleDialog();
        if (clipTitle == null || clipTitle.trim().isEmpty) {
          return; // User cancelled or didn't enter a title
        }
        
        final success = await _audioClipService.startAudioClip(
          roomId: widget.roomId,
          userId: _currentUser?.id ?? '',
          clipTitle: clipTitle,
        );
        
        if (success) {
          if (mounted) {
            setState(() {
              _isRecordingClip = true;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎙️ Recording 30-second audio clip...'),
                backgroundColor: Colors.purple,
                duration: Duration(seconds: 2),
              ),
            );
            
            // Auto-stop after 30 seconds
            Timer(const Duration(seconds: 30), () {
              if (mounted && _isRecordingClip) {
                setState(() {
                  _isRecordingClip = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Audio clip saved!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Failed to start audio recording'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // Stop recording
        AppLogger().info('🛑 Stopping audio clip recording');
        await _audioClipService.cancelRecording();
        
        if (mounted) {
          setState(() {
            _isRecordingClip = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛑 Audio clip recording stopped'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger().error('Error toggling audio clip: $e');
      if (mounted) {
        setState(() {
          _isRecordingClip = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Audio clip error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show dialog to get clip title from user
  Future<String?> _showClipTitleDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.mic, color: Colors.purple, size: 20),
            SizedBox(width: 8),
            Text('Audio Clip Title'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Give your 30-second audio clip a title:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: 'e.g., "Great point about healthcare"',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = controller.text.trim();
              Navigator.pop(context, title.isNotEmpty ? title : null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: const Text('Start Recording', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
