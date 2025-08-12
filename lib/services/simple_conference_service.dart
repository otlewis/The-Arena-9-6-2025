import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:ant_media_flutter/ant_media_flutter.dart'; // Package disabled
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SimpleConferenceService extends ChangeNotifier {
  static final SimpleConferenceService _instance = SimpleConferenceService._internal();
  factory SimpleConferenceService() => _instance;
  SimpleConferenceService._internal();

  // Connection settings
  String? _serverUrl;
  String? _currentRoomId;
  String? _currentStreamId;
  
  // State
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isDisposed = false;
  
  // Video renderers
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  
  // Streams
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  
  // Known participants - we'll manually track these
  final Set<String> _knownParticipants = {};
  Timer? _participantDiscoveryTimer;
  
  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(String peerId, MediaStream stream)? onRemoteStream;
  Function(String peerId)? onPeerJoined;
  Function(String peerId)? onPeerLeft;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  RTCVideoRenderer get localRenderer => _localRenderer;
  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;

  Future<void> initialize() async {
    try {
      debugPrint('🎥 Initializing Simple Conference Service...');
      
      // Initialize local renderer
      await _localRenderer.initialize();
      
      // AntMediaFlutter.requestPermissions(); // Package disabled
      
      debugPrint('✅ Simple Conference Service initialized');
    } catch (e) {
      debugPrint('❌ Simple Conference Service initialization failed: $e');
      onError?.call('Initialization failed: $e');
    }
  }

  Future<void> joinConference({
    required String serverUrl,
    required String roomId,
    required String streamId,
    required List<String> otherParticipants, // Pass known participants
    bool audioOnly = false,
  }) async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      _serverUrl = serverUrl;
      _currentRoomId = roomId;
      _currentStreamId = streamId;
      _isVideoEnabled = !audioOnly;
      _knownParticipants.addAll(otherParticipants.where((p) => p != streamId));

      debugPrint('🔌 Joining Simple Conference...');
      debugPrint('🔌 Server: $_serverUrl');
      debugPrint('🔌 Room ID: $_currentRoomId');
      debugPrint('🔌 Stream ID: $_currentStreamId');
      debugPrint('🔌 Other participants: $otherParticipants');

      // Use conference mode but with participant discovery
      await _connectToConference();
      
      // Start trying to discover participants
      _startParticipantDiscovery();

    } catch (e) {
      debugPrint('❌ Conference join failed: $e');
      onError?.call('Conference join failed: $e');
      rethrow;
    }
  }

  Future<void> _connectToConference() async {
    debugPrint('📤 Connecting to conference: $_currentStreamId');
    
    // AntMedia package disabled - placeholder implementation
    _isConnected = false;
  }

  void _startParticipantDiscovery() {
    debugPrint('🔍 Starting participant discovery...');
    
    // Start a timer to periodically try to discover participants
    _participantDiscoveryTimer = Timer.periodic(
      const Duration(seconds: 5), 
      (timer) {
        _tryDiscoverParticipants();
      }
    );
  }

  void _tryDiscoverParticipants() {
    debugPrint('🔍 Trying to discover participants: $_knownParticipants');
    debugPrint('🔍 Current room: $_currentRoomId');
    debugPrint('🔍 My stream: $_currentStreamId');
    
    // In conference mode, we don't manually discover participants
    // The server should automatically send us participants when they join
    // and we should receive them via the conference update callback
    
    for (String participantId in _knownParticipants) {
      debugPrint('🔍 Known participant: $participantId');
      // Check if we already have this participant's stream
      if (_remoteStreams.containsKey(participantId)) {
        debugPrint('✅ Already have stream for: $participantId');
      } else {
        debugPrint('⏳ Waiting for stream from: $participantId');
      }
    }
  }

  // AntMedia package disabled - placeholder methods

  Future<void> toggleMute() async {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
      debugPrint('🎤 Audio ${_isMuted ? 'muted' : 'unmuted'}');
      notifyListeners();
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null) {
      _isVideoEnabled = !_isVideoEnabled;
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = _isVideoEnabled;
      });
      debugPrint('📹 Video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_isDisposed || !_isConnected) return;
    
    debugPrint('🔌 Disconnecting from Simple Conference...');
    
    try {
      // Stop participant discovery
      _participantDiscoveryTimer?.cancel();
      _participantDiscoveryTimer = null;
      
      // AntMedia package disabled - skip connection close
      // if (AntMediaFlutter.anthelper != null) {
      //   AntMediaFlutter.anthelper?.bye();
      // }
      
      // Stop local stream
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream?.dispose();
      _localStream = null;
      _localRenderer.srcObject = null;
      
      // Clear remote streams and renderers
      for (final stream in _remoteStreams.values) {
        stream.dispose();
      }
      _remoteStreams.clear();
      
      for (final renderer in _remoteRenderers.values) {
        renderer.dispose();
      }
      _remoteRenderers.clear();
      
      // Clear state
      _isConnected = false;
      _serverUrl = null;
      _currentRoomId = null;
      _currentStreamId = null;
      _knownParticipants.clear();
      
      debugPrint('✅ Disconnected from Simple Conference');
      
    } catch (e) {
      debugPrint('❌ Error during disconnect: $e');
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    disconnect();
    _localRenderer.dispose();
    super.dispose();
  }
}