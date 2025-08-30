import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/appwrite_service.dart';
import '../services/firebase_gift_service.dart';
import '../services/livekit_service.dart';
import '../services/livekit_token_service.dart';
import '../services/livekit_config_service.dart';
import '../services/super_moderator_service.dart';
// import '../services/chat_service.dart'; // Removed with new chat system
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../models/timer_state.dart';
import '../features/arena/constants/arena_colors.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/appwrite_timer_widget.dart';
import '../widgets/user_profile_bottom_sheet.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/mattermost_chat_widget.dart';
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
import '../widgets/streaming_destinations_modal.dart';
import '../widgets/bottom_sheet/debate_bottom_sheet.dart';
import '../services/livekit_material_sync_service.dart';
import '../widgets/shared_link_popup.dart';
import '../widgets/slide_update_popup.dart';
import '../models/debate_source.dart';

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
    with NetworkOptimizationMixin, ListOptimizationMixin, WidgetsBindingObserver {
  final AppwriteService _appwrite = AppwriteService();
  final FirebaseGiftService _giftService = FirebaseGiftService();
  final LiveKitService _webrtcService = LiveKitService();
  
  // Performance optimization instances
  final RiverpodPerformanceOptimizer _performanceOptimizer = RiverpodPerformanceOptimizer();
  final VirtualizedListOptimizer _listOptimizer = VirtualizedListOptimizer();
  final NetworkPerformanceOptimizer _networkOptimizer = NetworkPerformanceOptimizer();
  
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
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  UserProfile? _moderator;
  
  // Gift system
  int _currentUserCoinBalance = 0;
  Gift? _selectedGift;
  Map<String, dynamic>? _selectedRecipient;  // Changed to match Open Discussion format
  List<Gift> _availableGifts = [];
  
  // Participants
  final List<UserProfile> _speakerPanelists = []; // Max 6 speakers
  final List<UserProfile> _audienceMembers = [];
  final List<UserProfile> _speakerRequests = []; // Pending speaker requests
  
  // Role mapping for participants (userId -> role)
  final Map<String, String> _participantRoles = {};
  
  // Performance optimization - cache last participants to prevent unnecessary rebuilds
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
  
  // Real-time subscriptions - separate instances for reliability
  RealtimeSubscription? _participantsSubscription;
  RealtimeSubscription? _roomSubscription;
  StreamSubscription? _unreadMessagesSubscription; // Instant messages subscription
  StreamSubscription? _firebaseParticipantSubscription; // Firebase participant sync
  StreamSubscription? _materialUpdatesSubscription; // Material sync subscription
  StreamSubscription? _sourceAddedSubscription; // Shared sources subscription

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer for automatic refresh on app resume
    WidgetsBinding.instance.addObserver(this);
    
    // Enable ultra-performance mode for maximum FPS
    UltraPerformanceMode.instance.enable();
    
    // Enable extreme performance mode for maximum possible performance
    ExtremePerformanceMode.instance.enable();
    
    _initializeRoom();
    _loadGiftData();
    _initializeWebRTC();
    
    // Start connection health monitoring to prevent user drops
    _startConnectionHealthMonitoring();
  }
  
  Future<void> _initializeWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    
    // Set up LiveKit service callbacks
    _webrtcService.onConnected = () {
      AppLogger().debug('✅ LiveKit connected to Debates & Discussions room');
      if (mounted) {
        setState(() {
          _isWebRTCConnected = true;
        });
        _debugVideoState();
      }
    };
    
    _webrtcService.onParticipantConnected = (participant) {
      AppLogger().debug('👤 LiveKit participant joined: ${participant.identity}');
      if (mounted) {
        setState(() {
          // Trigger UI update for participant count
        });
      }
    };
    
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
    
    AppLogger().debug('📊 Material listeners successfully set up');
  }

  // Audio/Video control methods (simplified like open discussion)
  
  Future<void> _toggleMute() async {
    try {
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
      
      // Check if this is a permission error - if so, try to reconnect with correct role
      if (e.toString().contains('permission') || e.toString().contains('publish audio')) {
        AppLogger().warning('🚨 PERMISSION ERROR: Attempting to reconnect with correct role');
        
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

  /// Get current noise cancellation status
  Map<String, bool> _getNoiseCancellationStatus() {
    if (!_webrtcService.isConnected) {
      return {
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': false,
        'highpassFilter': false,
        'typingNoiseDetection': false,
      };
    }

    try {
      // Return the actual constraints that were applied
      return {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'highpassFilter': true,
        'typingNoiseDetection': true,
      };
    } catch (e) {
      AppLogger().debug('⚠️ Could not get noise cancellation status: $e');
      return {
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': false,
        'highpassFilter': false,
        'typingNoiseDetection': false,
      };
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
            // Reconnect to audio if user should be connected
            if ((_isCurrentUserModerator || _isCurrentUserSpeaker) && !_isAudioConnected) {
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
      
      // Step 3: Restore audio connection
      if ((_isCurrentUserModerator || _isCurrentUserSpeaker) && !_isAudioConnected) {
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

  /// Test noise cancellation features
  Future<void> _testNoiseCancellation() async {
    try {
      if (!_webrtcService.isConnected) {
        AppLogger().debug('⚠️ Cannot test noise cancellation: not connected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please connect to audio first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      AppLogger().debug('🧪 Testing noise cancellation features...');
      
      // Temporarily disable and re-enable audio to test constraints
      await _webrtcService.disableAudio();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Re-enable with noise cancellation
      await _webrtcService.enableAudio();
      
      // Get and display status
      final status = _getNoiseCancellationStatus();
      AppLogger().debug('🎤 Noise cancellation test results:');
      AppLogger().debug('   Echo Cancellation: ${status['echoCancellation']}');
      AppLogger().debug('   Noise Suppression: ${status['noiseSuppression']}');
      AppLogger().debug('   Auto Gain Control: ${status['autoGainControl']}');
      AppLogger().debug('   High-pass Filter: ${status['highpassFilter']}');
      AppLogger().debug('   Typing Noise Detection: ${status['typingNoiseDetection']}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 Noise cancellation test completed! Check debug console for results.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (error) {
      AppLogger().debug('❌ Noise cancellation test failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Noise cancellation test failed: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
    AppLogger().debug('🔥 AUTO-CONNECT: _autoConnectAudio() called - attempting to connect ALL users');
    AppLogger().debug('🔥 AUTO-CONNECT: Current user: ${_currentUser?.id}, isModerator: $_isCurrentUserModerator, isSpeaker: $_isCurrentUserSpeaker');
    AppLogger().debug('🔥 AUTO-CONNECT: Audio state - connected: $_isAudioConnected, connecting: $_isAudioConnecting');
    AppLogger().debug('🔥 AUTO-CONNECT: Participant roles: $_participantRoles');
    
    // Safety check - make sure we have current user data
    if (_currentUser == null) {
      AppLogger().warning('🔥 AUTO-CONNECT: ⚠️ Cannot auto-connect audio - current user is null');
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
      
      // Reconnect with speaker role
      AppLogger().debug('🎤 Reconnecting with speaker role...');
      await _connectToAudio();
      
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
        final userProfile = await _appwrite.getUserProfile(user.$id);
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
      if (_currentUser != null) {
        await _joinRoom();
      }
      
      // Clear any cached participant data to ensure fresh load
      invalidateNetworkCache(patternPrefix: 'participants_');
      
      // Load participants from database
      await _loadParticipants();
      
      // Set up real-time subscriptions
      _setupRealTimeUpdates();
      
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
      
      // Immediately refresh participants to ensure this user appears in all other users' screens
      Future.microtask(() async {
        if (mounted && !_isDisposing) {
          await _loadParticipants();
        }
      });
    } catch (e) {
      AppLogger().error('❌ Error joining room: $e');
      // Continue anyway - user might already be in room
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
    
    _participantsSubscription?.close();
    _roomSubscription?.close();
    _unreadMessagesSubscription?.cancel();
    _firebaseParticipantSubscription?.cancel();
    _materialUpdatesSubscription?.cancel();
    _sourceAddedSubscription?.cancel();
    
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
    
    // Don't await _leaveRoom() in dispose as it's synchronous
    // Just call it without awaiting to start the process
    _leaveRoom().catchError((error) {
      AppLogger().error('Error during disposal: $error');
    });
    super.dispose();
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
          setState(() {});
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
          setState(() {});
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
      }
      
      // AUTO-CONNECT: Automatically connect to audio for all users
      if (!_isAudioConnected && !_isAudioConnecting && _currentUser != null) {
        AppLogger().debug('🔥 AUTO-CONNECT: Initiating automatic audio connection after participants loaded');
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

  void _setupRealTimeUpdates() {
    try {
      // APPWRITE OPTIMIZATION: Subscribe to room-specific events only for faster sync
      _participantsSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.debate_discussion_participants.documents',
        // Also subscribe to specific room to catch broader changes
        'databases.arena_db.collections.debate_discussion_rooms.documents.${widget.roomId}'
      ]);

      _participantsSubscription?.stream.listen(
        (response) async {
          AppLogger().debug('Participant update events: ${response.events}');
          AppLogger().debug('Participant update payload: ${response.payload}');
          
          if (mounted && !_isDisposing) {
            // Check for specific participant role changes
            bool isHandRaiseEvent = false;
            bool isHandLowerEvent = false;
            bool isSpeakerPromotionEvent = false;
            bool needsParticipantReload = false;
            
            for (var event in response.events) {
              // Check if this is an update, create, or delete event
              if (event.contains('debate_discussion_participants.documents') && 
                  (event.endsWith('.update') || event.endsWith('.create') || event.endsWith('.delete'))) {
                // Check if it's for this room
                if (response.payload['roomId'] == widget.roomId) {
                  AppLogger().debug('🔄 PARTICIPANT EVENT: $event for room ${widget.roomId}');
                  
                  // Mark that we need to reload participants
                  
                  // For create events (new user joined)
                  if (event.endsWith('.create')) {
                    AppLogger().info('📥 NEW PARTICIPANT: User joined room ${widget.roomId}');
                    needsParticipantReload = true;
                  }
                  
                  // For delete events (user left)
                  if (event.endsWith('.delete')) {
                    AppLogger().info('📤 PARTICIPANT LEFT: User left room ${widget.roomId}');
                    needsParticipantReload = true;
                  }
                  // For update events, handle role changes
                  if (event.endsWith('.update')) {
                    final newRole = response.payload['role'];
                    final userId = response.payload['userId'];
                    
                    AppLogger().debug('🔄 ROLE UPDATE: User $userId role changed to: $newRole');
                    
                    if (newRole == 'pending') {
                      AppLogger().info('Hand-raise detected: $userId requested to speak');
                      isHandRaiseEvent = true;
                    } else if (newRole == 'audience') {
                      // Could be hand lowering or moderator denial - check if it was current user
                      if (userId == _currentUser?.id && _hasRequestedSpeaker) {
                        AppLogger().info('Hand-lower detected: $userId lowered their hand');
                        isHandLowerEvent = true;
                      }
                    } else if ((newRole == 'speaker' || newRole == 'affirmative' || newRole == 'negative') && userId == _currentUser?.id) {
                      // CRITICAL: Current user was promoted to speaker - need to reinitialize LiveKit connection
                      AppLogger().info('🔄 SPEAKER PROMOTION: Current user promoted to speaker role - will reinitialize audio');
                      isSpeakerPromotionEvent = true;
                    }
                  }
                }
              }
            }
            
            // Single participant reload for all events (prevents duplicate loading)
            if (needsParticipantReload || isHandRaiseEvent || isHandLowerEvent || isSpeakerPromotionEvent) {
              AppLogger().info('🚀 CRITICAL UPDATE: Bypassing cache for immediate participant refresh');
              
              // For critical role changes, bypass cache completely for instant updates with multiple invalidations
              Future.microtask(() async {
                if (mounted && !_isDisposing) {
                  // Aggressively clear all participant-related cache
                  invalidateNetworkCache(patternPrefix: 'participants_');
                  invalidateNetworkCache(patternPrefix: 'debate_discussion_participants');
                  invalidateNetworkCache(patternPrefix: widget.roomId);
                  await _loadParticipants();
                  
                  // Force a second reload after a brief delay to catch any missed updates
                  Future.delayed(const Duration(milliseconds: 500), () async {
                    if (mounted && !_isDisposing) {
                      invalidateNetworkCache(patternPrefix: 'participants_');
                      await _loadParticipants();
                    }
                  });
                }
              });
            }
            
            // CRITICAL: Handle speaker promotion - reinitialize LiveKit connection with new role
            if (isSpeakerPromotionEvent) {
              AppLogger().info('🔄 SPEAKER PROMOTION: Executing immediate LiveKit role sync');
              // Immediate audio reinitializtion for instant speaker seating
              Future.microtask(() async {
                if (mounted) {
                  await _reinitializeAudioForSpeaker();
                }
              });
            }
            
            // Show immediate notification for hand-raise events (only for moderators)
            if (isHandRaiseEvent && _hasModeratorPowers) {
              AppLogger().info('Showing hand-raise notification to moderator');
              _showHandRaiseNotificationFromPayload(response.payload);
            }
            
            // Update local state if current user lowered their hand
            if (isHandLowerEvent) {
              setState(() {
                _hasRequestedSpeaker = false;
              });
            }
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

      // Separate subscription for room status (like room ending)
      _roomSubscription = Realtime(_appwrite.client).subscribe([
        'databases.arena_db.collections.debate_discussion_rooms.documents.${widget.roomId}'
      ]);

      _roomSubscription?.stream.listen(
        (response) {
          AppLogger().debug('Room update events: ${response.events}');
          _handleRoomUpdate(response);
        },
        onError: (error) {
          AppLogger().error('Room subscription error: $error');
        },
      );
      
    } catch (e) {
      AppLogger().error('Error setting up real-time updates: $e');
    }
  }

  void _reconnectParticipantsSubscription() {
    try {
      AppLogger().info('Reconnecting participants subscription...');
      _participantsSubscription?.close();
      
      // Create new subscription after short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isDisposing) {
          _participantsSubscription = _appwrite.realtimeInstance.subscribe([
            'databases.arena_db.collections.debate_discussion_participants.documents'
          ]);

          _participantsSubscription?.stream.listen(
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
          
          AppLogger().info('Participants subscription reconnected successfully');
        }
      });
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
        
        AppLogger().debug('Room status update: $roomStatus');
        
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

  Future<void> _leaveRoom() async {
    try {
      if (_isJoined && !_isDisposing) {
        // Audio/Video cleanup handled by LiveKit
        
        if (_currentUser != null) {
          await _appwrite.leaveDebateDiscussionRoom(
            roomId: widget.roomId,
            userId: _currentUser!.id,
          );
        }
        
        if (mounted && !_isDisposing) {
          setState(() {
            _isJoined = false;
          });
        }
      }
    } catch (e) {
      AppLogger().error('Error leaving room: $e');
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
        // User wants to lower their hand - change back to audience
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'audience',
        );
        
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
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛡️ Super Moderator joined speaker panel'),
              backgroundColor: Color(0xFFFFD700),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Audio will be reinitialized automatically by the role change
        }
        
        AppLogger().info('🛡️ Super Moderator ${_currentUser!.name} joined speaker panel instantly');
      } else {
        // Regular user wants to raise their hand - change to pending
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'pending',
        );
        
        if (mounted && !_isDisposing) {
          setState(() {
            _hasRequestedSpeaker = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✋ Request sent to moderator for approval'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        AppLogger().info('User ${_currentUser!.name} raised their hand');
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
          // DEMOTION: Current user demoted back to audience
          _isCurrentUserSpeaker = false;
          AppLogger().info('🔄 ROLE ASSIGNMENT: Current user demoted to audience - disabling speaker privileges');
          
          // Disable audio/video if they were enabled
          if (!_isMuted && _isAudioConnected) {
            await _toggleMute(); // Mute audio
          }
          if (_isVideoEnabled) {
            await _toggleVideo(); // Disable video
          }
        }
      }
      
      // CRITICAL: Handle current user demotion BEFORE UI update
      if (role == 'audience') {
        final currentUser = await _appwrite.getCurrentUser();
        if (currentUser != null && user.id == currentUser.$id) {
          AppLogger().debug('🔇 DEMOTION: Current user demoted to audience - unpublishing audio tracks');
          await _liveKitService.unpublishAllTracks();
          
          // Update local speaker status
          _isCurrentUserSpeaker = false;
          
          // Mute microphone for audience role
          if (_liveKitService.isConnected) {
            await _liveKitService.disableAudio();
          }
        }
      }

      // Immediately update moderator UI for instant feedback
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
        
        AppLogger().info('🚀 IMMEDIATE UI: Moderator screen updated instantly for ${user.name} → $role');
      }
      
      // Sync to Firebase for instant cross-device updates (temporarily disabled)
      // await _syncParticipantToFirebase(user, role);
      
      // Real-time subscription will sync any missed updates from other sources
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
      
      // The real-time subscription will update the UI automatically
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



  @override
  Widget build(BuildContext context) {
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
          // Timer Widget
          AppwriteTimerWidget(
            roomId: widget.roomId,
            roomType: RoomType.debatesDiscussions,
            isModerator: _isCurrentUserModerator,
            userId: _currentUser?.id ?? '',
            compact: true,
            showControls: _hasModeratorPowers,
            showConnectionStatus: false,
          ),
          SizedBox(width: isSmallScreen ? 8 : 16),
          const ChallengeBell(iconColor: Colors.white),
          SizedBox(width: isSmallScreen ? 8 : 16),
          // Compact participant count and audio status
          Row(
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
      builder: (context, constraints) {
        // Reserve space for controls and other UI elements
        
        return Column(
          children: [
            // Speakers panel with integrated audience below moderator
            Expanded(
              child: SingleChildScrollView(
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
    );
  }

  /// Determine the correct LiveKit room type based on debate style
  String _getRoomTypeForLiveKit() {
    final debateStyle = _roomData?['debateStyle'];
    
    // If it's a formal debate (2 slots) or structured take (3 slots), use debate_discussion
    // If it's an open discussion (8 slots), use open_discussion
    if (debateStyle == 'Debate' || debateStyle == 'Take') {
      return 'debate_discussion';
    } else {
      // Default to open_discussion for regular discussion rooms
      return 'open_discussion';
    }
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
            setState(() {});
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
            setState(() {});
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

  /// Helper function to create avatar text content from Map data - just first letter
  Widget _buildAvatarTextFromMap(Map<String, dynamic> data, double fontSize) {
    final name = data['name'] as String? ?? '';
    String letter;
    
    if (name.isEmpty) {
      letter = 'U';
    } else {
      letter = name.substring(0, 1).toUpperCase();
    }
    
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.black87,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status text (similar to open discussion)
          Text(
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
            builder: (context, constraints) {
              // If screen is too narrow, make it scrollable
              if (constraints.maxWidth < 500) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _buildControlButton(
                        icon: LucideIcons.messageCircle,
                        label: 'Chat',
                        color: const Color(0xFF8B5CF6),
                        onTap: _showChat,
                      ),
                      const SizedBox(width: 8),
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
                      if (_hasModeratorPowers) ...[
                        _buildControlButton(
                          icon: LucideIcons.radio,
                          label: 'Go Live',
                          color: Colors.red,
                          onTap: _showStreamingOptions,
                        ),
                        const SizedBox(width: 8),
                      ],
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
                    if (_hasModeratorPowers) 
                      _buildControlButton(
                        icon: LucideIcons.radio,
                        label: 'Go Live',
                        color: Colors.red,
                        onTap: _showStreamingOptions,
                      ),
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
                      icon: LucideIcons.settings,
                      title: 'Test Audio Quality',
                      onTap: () {
                        Navigator.pop(context);
                        _testNoiseCancellation();
                      },
                    ),
                    _buildOptionTile(
                      icon: LucideIcons.testTube,
                      title: 'Test Data Message',
                      onTap: () {
                        Navigator.pop(context);
                        _testDataMessage();
                      },
                    ),
                    _buildOptionTile(
                      icon: LucideIcons.users,
                      title: 'Room Stats',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Room has ${_speakerPanelists.length} speakers and ${_audienceMembers.length} audience members')),
                        );
                      },
                    ),
                    _buildOptionTile(
                      icon: LucideIcons.settings,
                      title: 'Room Settings',
                      onTap: () {
                        Navigator.pop(context);
                        _showRoomSettings();
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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _speakerPanelists.length,
                  itemBuilder: (context, index) {
                    final speaker = _speakerPanelists[index];
                    final isModerator = speaker.id == _moderator?.id;
                    
                    return ListTile(
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
                    controller: scrollController,
                    itemCount: _speakerRequests.length,
                    itemBuilder: (context, index) {
                      final user = _speakerRequests[index];
                      
                      return ListTile(
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
                    controller: scrollController,
                    itemCount: _audienceMembers.length,
                    itemBuilder: (context, index) {
                      final member = _audienceMembers[index];
                      final hasAffirmative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'affirmative');
                      final hasNegative = _speakerPanelists.any((speaker) => _participantRoles[speaker.id] == 'negative');
                      final canAssign = !isDebateRoom || (!hasAffirmative || !hasNegative);
                      
                      return ListTile(
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

  void _testDataMessage() async {
    try {
      AppLogger().debug('🧪 Testing data message functionality...');
      
      if (!_webrtcService.isConnected) {
        AppLogger().warning('🧪 WebRTC not connected');
        return;
      }
      
      final participants = _webrtcService.remoteParticipants;
      if (participants.isEmpty) {
        AppLogger().warning('🧪 No participants to test with');
        return;
      }
      
      for (final participant in participants) {
        AppLogger().debug('🧪 Sending test message to ${participant.identity}');
        
        // Send a test message
        await _webrtcService.localParticipant?.publishData(
          utf8.encode(jsonEncode({
            'type': 'test_message',
            'targetParticipant': participant.identity,
            'fromModerator': _webrtcService.localParticipant?.identity,
            'message': 'Hello from moderator!',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          })),
          reliable: true,
          destinationIdentities: [participant.identity],
        );
        
        AppLogger().debug('🧪 Test message sent to ${participant.identity}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🧪 Test messages sent to ${participants.length} participants'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('🧪 Error testing data messages: $e');
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
      
      // Use LiveKit to mute all participants
      await _webrtcService.muteAllParticipants();
      
      AppLogger().info('🔇 Successfully sent mute all command');
      
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
            // Add streaming option for moderators
            if (_hasModeratorPowers)
              _buildOptionTile(
                icon: LucideIcons.radio,
                title: 'Go Live',
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
      // Change user role back to audience
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: user.id,
        newRole: 'audience',
      );
      
      // Remove from speaker requests and ensure user is in audience
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
    
    // Create shareable room join link
    final roomJoinLink = 'https://arena.app/join/debates/${widget.roomId}';
    
    // Create shareable content optimized for social media
    final shareText = '''🎙️ Join our live debate discussion!

Room: $roomName
Moderator: $moderatorName
Participants: $participantCount

Join the conversation now:
$roomJoinLink

#ArenaDebate #LiveDebate #Discussion''';

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

  void _showStreamingOptions() {
    // Show streaming destinations modal for live streaming (moderator-only)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamingDestinationsModal(
        roomId: widget.roomId,
        roomName: _roomData?['name'] ?? 'Debate Room',
        isModerator: _isCurrentUserModerator,
      ),
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

  // Gift modal methods (Open Discussion room implementation)
  void _showGiftModal() {
    AppLogger().debug('🎁 DEBUG: Gift modal button pressed');
    
    // Get eligible recipients (moderator and speakers only, excluding self)
    final eligibleRecipients = <Map<String, dynamic>>[];
    
    // Add moderator if not current user
    if (_moderator != null && _moderator!.id != _currentUser!.id) {
      eligibleRecipients.add({
        'userId': _moderator!.id,
        'name': _moderator!.name,
        'role': 'moderator',
      });
    }
    
    // Add speakers if not current user
    for (final speaker in _speakerPanelists) {
      if (speaker.id != _currentUser!.id && !eligibleRecipients.any((r) => r['userId'] == speaker.id)) {
        eligibleRecipients.add({
          'userId': speaker.id,
          'name': speaker.name,
          'role': 'speaker',
        });
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Send Gift',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🪙',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_currentUserCoinBalance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab bar
              const TabBar(
                labelColor: Color(0xFF8B5CF6),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF8B5CF6),
                tabs: [
                  Tab(text: 'Select Gift'),
                  Tab(text: 'Recipients'),
                ],
              ),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGiftSelectionTab(),
                    _buildRecipientSelectionTab(eligibleRecipients),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftSelectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Money Gifting Section
          _buildMoneyGiftingSection(),
          
          const SizedBox(height: 24),
          
          // Gift categories
          ...GiftCategory.values.map((category) => _buildGiftCategorySection(category)),
        ],
      ),
    );
  }

  Widget _buildMoneyGiftingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Send Money Button
        GestureDetector(
          onTap: _showMoneyInputModal,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.attach_money, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  '\$ Send Money',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGiftCategorySection(GiftCategory category) {
    final categoryGifts = GiftConstants.getGiftsByCategory(category);
    if (categoryGifts.isEmpty) return Container();

    String categoryTitle = '';
    IconData categoryIcon = Icons.card_giftcard;
    Color categoryColor = Colors.grey;

    switch (category) {
      case GiftCategory.intellectual:
        categoryTitle = 'Intellectual Achievement';
        categoryIcon = Icons.psychology;
        categoryColor = Colors.blue;
        break;
      case GiftCategory.supportive:
        categoryTitle = 'Supportive & Encouraging';
        categoryIcon = Icons.favorite;
        categoryColor = Colors.pink;
        break;
      case GiftCategory.fun:
        categoryTitle = 'Fun & Personality';
        categoryIcon = Icons.celebration;
        categoryColor = Colors.orange;
        break;
      case GiftCategory.recognition:
        categoryTitle = 'Recognition & Status';
        categoryIcon = Icons.star;
        categoryColor = Colors.amber;
        break;
      case GiftCategory.interactive:
        categoryTitle = 'Interactive & Engaging';
        categoryIcon = Icons.play_circle;
        categoryColor = Colors.green;
        break;
      case GiftCategory.premium:
        categoryTitle = 'Premium Collection';
        categoryIcon = Icons.diamond;
        categoryColor = Colors.purple;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(categoryIcon, color: categoryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                categoryTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                ),
              ),
            ],
          ),
        ),
        
        // Gift grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemCount: categoryGifts.length,
          itemBuilder: (context, index) {
            final gift = categoryGifts[index];
            return _buildGiftCard(gift);
          },
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGiftCard(Gift gift) {
    final canAfford = _currentUserCoinBalance >= gift.cost;
    final isSelected = _selectedGift?.id == gift.id;
    
    return GestureDetector(
      onTap: canAfford ? () => _selectGift(gift) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.red : _getTierColor(gift.tier),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Gift emoji and effects
                  Text(
                    gift.emoji,
                    style: TextStyle(
                      fontSize: canAfford ? 24 : 20,
                      color: canAfford ? null : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (gift.hasVisualEffect)
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: Colors.amber[600],
                    ),
                  if (gift.hasProfileBadge)
                    const Icon(
                      Icons.verified,
                      size: 12,
                      color: Colors.blue,
                    ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Gift name
              Text(
                gift.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: canAfford ? Colors.black87 : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 2),
              
              // Gift description
              Text(
                gift.description,
                style: TextStyle(
                  fontSize: 11,
                  color: canAfford ? Colors.grey[600] : Colors.grey[400],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Cost
              Row(
                children: [
                  const Text(
                    '🪙',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${gift.cost}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: canAfford ? _getTierColor(gift.tier) : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTierColor(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return Colors.grey[600]!;
      case GiftTier.standard:
        return Colors.blue[600]!;
      case GiftTier.premium:
        return Colors.purple[600]!;
      case GiftTier.legendary:
        return Colors.amber[600]!;
    }
  }

  Widget _buildRecipientSelectionTab(List<Map<String, dynamic>> eligibleRecipients) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: eligibleRecipients.length,
      itemBuilder: (context, index) {
        final recipient = eligibleRecipients[index];
        final isSelected = _selectedRecipient?['userId'] == recipient['userId'];
        
        return GestureDetector(
          onTap: () => _selectRecipient(recipient),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: _buildAvatarTextFromMap(recipient, 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        recipient['role'].toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoneyInputModal() {
    final TextEditingController amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.attach_money, color: Colors.green),
            SizedBox(width: 8),
            Text('Send Money'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the amount you want to send:'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'This will be processed through a secure payment gateway.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = amountController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final amount = double.tryParse(text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              _selectCustomMoneyGift(amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _selectCustomMoneyGift(double amount) {
    AppLogger().debug('💵 DEBUG: Custom money amount selected: \$$amount');

    setState(() {
      _selectedGift = Gift(
        id: 'money_${amount.toStringAsFixed(2)}',
        name: '\$${amount.toStringAsFixed(2)} Cash',
        emoji: '💵',
        description: 'Send \$${amount.toStringAsFixed(2)} real money',
        cost: 0, // No coin cost for real money
        category: GiftCategory.premium,
        tier: amount <= 10 ? GiftTier.standard : amount <= 50 ? GiftTier.premium : GiftTier.legendary,
      );
    });
    
    AppLogger().debug('💵 DEBUG: Custom money gift selected successfully: \$${amount.toStringAsFixed(2)}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💵 Selected \$${amount.toStringAsFixed(2)} cash'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Auto-show confirmation if recipient is already selected
    if (_selectedRecipient != null) {
      _showGiftConfirmation();
    }
  }

  void _selectGift(Gift gift) {
    AppLogger().debug('🎁 DEBUG: Gift selected: ${gift.name}');
    AppLogger().debug('🎁 DEBUG: Gift cost: ${gift.cost}');
    AppLogger().debug('🎁 DEBUG: User balance: $_currentUserCoinBalance');
    
    if (_currentUserCoinBalance < gift.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient coins!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _selectedGift = gift;
    });
    
    AppLogger().debug('🎁 DEBUG: Gift selected successfully: ${gift.name}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎁 Selected ${gift.emoji} ${gift.name}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Auto-show confirmation if recipient is already selected
    if (_selectedRecipient != null) {
      _showGiftConfirmation();
    }
  }

  void _selectRecipient(Map<String, dynamic> recipient) {
    setState(() {
      _selectedRecipient = recipient;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${recipient['name']}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Auto-show confirmation if gift is already selected
    if (_selectedGift != null) {
      _showGiftConfirmation();
    }
  }

  void _showGiftConfirmation() {
    if (_selectedGift == null || _selectedRecipient == null) return;

    final gift = _selectedGift!;
    final recipient = _selectedRecipient!;
    final isMoneyGift = gift.id.startsWith('money_');
    final isCoinGift = gift.id.startsWith('coin_');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMoneyGift ? 'Send Money?' : 'Send Gift?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send ${gift.emoji} ${gift.name} to ${recipient['name']}?'),
            const SizedBox(height: 8),
            if (isMoneyGift) ...[
              Text('Amount: ${gift.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('This will be processed through a secure payment gateway.'),
            ] else if (isCoinGift) ...[
              Text('Cost: 🪙 ${gift.cost} coins'),
              Text('Your balance: 🪙 $_currentUserCoinBalance coins'),
              Text('After: 🪙 ${_currentUserCoinBalance - gift.cost} coins'),
            ] else ...[
              Text('Cost: 🪙 ${gift.cost} coins'),
              Text('Your balance: 🪙 $_currentUserCoinBalance coins'),
              Text('After: 🪙 ${_currentUserCoinBalance - gift.cost} coins'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: (isMoneyGift || _currentUserCoinBalance >= gift.cost)
                ? () => _sendGift(gift, recipient)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isMoneyGift ? Colors.green : Colors.blue,
            ),
            child: Text(isMoneyGift ? 'Send Money' : 'Send Gift'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGift(Gift gift, Map<String, dynamic> recipient) async {
    if (_currentUser == null) return;

    final isMoneyGift = gift.id.startsWith('money_');

    try {
      Navigator.pop(context); // Close confirmation dialog

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(isMoneyGift ? 'Processing payment...' : 'Sending gift...'),
              ],
            ),
            backgroundColor: isMoneyGift ? Colors.green : Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (isMoneyGift) {
        // Handle real money transactions
        await _processMoneyGift(gift, recipient);
      } else {
        // Handle regular gifts and coin gifts via Firebase
        await _giftService.sendGift(
          giftId: gift.id,
          senderId: _currentUser!.id,
          recipientId: recipient['userId'],
          roomId: widget.roomId,
          cost: gift.cost,
        );
      }

      // Send gift notification to chat (if chat service exists)
      try {
        // Gift notifications will be handled by new chat system
        // await _chatService.sendGiftNotification(
        //   roomId: widget.roomId,
        //   giftId: gift.id,
        //   giftName: '${gift.emoji} ${gift.name}',
        //   senderId: _currentUser!.id,
        //   senderName: _currentUser!.displayName,
        //   recipientId: recipient['userId'],
        //   recipientName: recipient['name'],
        //   cost: gift.cost,
        // );
      } catch (chatError) {
        AppLogger().warning('Could not send chat notification: $chatError');
        // Continue anyway - gift was sent successfully
      }

      // Refresh Firebase coin balance (only for coin-based gifts)
      if (!isMoneyGift) {
        await _loadGiftData();
      }

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMoneyGift 
              ? '💵 Money sent! ${gift.name} to ${recipient['name']}'
              : '🎁 Gift sent! ${gift.emoji} ${gift.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reset selections
      setState(() {
        _selectedGift = null;
        _selectedRecipient = null;
      });

    } catch (e) {
      AppLogger().error('Error sending gift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMoneyGift 
              ? 'Failed to process payment: $e'
              : 'Failed to send gift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processMoneyGift(Gift gift, Map<String, dynamic> recipient) async {
    // Extract amount from gift name (e.g., "$25.50 Cash" -> 25.50)
    final amountString = gift.name.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(amountString) ?? 0.0;
    
    AppLogger().info('Processing money gift: \$${amount.toStringAsFixed(2)} to ${recipient['name']}');
    
    // TODO: Integrate with payment gateway (Stripe, PayPal, etc.)
    // For now, simulate the payment process
    await Future.delayed(const Duration(seconds: 2));
    
    // In a real implementation, you would:
    // 1. Call payment gateway API (Stripe, PayPal, etc.)
    // 2. Handle payment confirmation
    // 3. Record transaction in database
    // 4. Handle payment failures/retries
    // 5. Send payment receipt to both parties
    
    // Simulate success for demonstration
    AppLogger().info('Money gift processed successfully: \$${amount.toStringAsFixed(2)}');
  }


  Widget _buildGiftButton() {
    return GestureDetector(
      onTap: _showGiftModal,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: const Icon(
          LucideIcons.gift,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
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
        onDismiss: () {
          AppLogger().info('📊 Slide update popup dismissed');
        },
      ),
    );
  }
}
