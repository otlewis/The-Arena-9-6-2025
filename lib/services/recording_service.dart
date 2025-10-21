import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/appwrite_service.dart';
import '../services/ionos_storage_service.dart';
import '../core/logging/app_logger.dart';

class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  final AppwriteService _appwriteService = GetIt.instance<AppwriteService>();
  final IonosStorageService _storageService = IonosStorageService();

  String? _currentEgressId;
  String? _currentRoomId;
  bool _isRecording = false;
  // UNUSED FIELD: String? _localRecordingPath;

  // Client-side recording fallback
  FlutterSoundRecorder? _localRecorder;
  bool _isLocalRecording = false;
  String? _localRecordingFilePath;

  bool get isRecording => _isRecording || _isLocalRecording;
  String? get currentEgressId => _currentEgressId;

  // LiveKit credentials - PRODUCTION: Set via environment variables
  static const String _liveKitApiKey = String.fromEnvironment('LIVEKIT_API_KEY',
      defaultValue: 'APIwzQr7qFmXHcy');
  static const String _liveKitApiSecret = String.fromEnvironment('LIVEKIT_API_SECRET',
      defaultValue: '2gVhXTdGbSJ4bPSpomxfaHjCA8PBdmJ4N7h89dZAJT9');
  static const String _liveKitUrl = String.fromEnvironment('LIVEKIT_URL',
      defaultValue: 'ws://34.171.185.205:7879');

  // HTTP endpoint for Egress API
  static String get _liveKitHttpUrl {
    String url = _liveKitUrl.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://');
    return url;
  }

  // IONOS S3 configuration for recordings
  // UNUSED FIELD: static const String _ionosAccessKey = String.fromEnvironment('IONOS_ACCESS_KEY', defaultValue: '');
  // UNUSED FIELD: static const String _ionosSecretKey = String.fromEnvironment('IONOS_SECRET_KEY', defaultValue: '');
  // UNUSED FIELD: static const String _ionosBucket = String.fromEnvironment('IONOS_BUCKET', defaultValue: 'arena-recordings');
  // UNUSED FIELD: static const String _ionosRegion = String.fromEnvironment('IONOS_REGION', defaultValue: 'eu-central-1');
  // UNUSED FIELD: static const String _ionosEndpoint = String.fromEnvironment('IONOS_ENDPOINT', defaultValue: 'https://s3.eu-central-1.ionoscloud.com');

  Future<bool> startRecording({
    required String roomId,
    required String roomName,
  }) async {
    try {
      AppLogger().info('🎬 RECORDING START - Room: $roomId, Name: $roomName');
      AppLogger().info('📊 Recording state - _isRecording: $_isRecording, _isLocalRecording: $_isLocalRecording');

      if (_isRecording) {
        AppLogger().warning('Recording already in progress');
        return false;
      }

      AppLogger().info('📝 Calling startArenaRecording in Appwrite...');
      await _appwriteService.startArenaRecording(roomId);
      AppLogger().info('✅ Appwrite startArenaRecording completed');

      // Generate timestamp-based filename
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.T]'), '-').split('.').first;
      final filename = 'arena_${roomId}_$timestamp.mp4';

      final egressRequest = {
        'room_name': roomName,
        'file': {
          'filepath': '/tmp/livekit-recordings/$filename',  // Save locally, n8n will upload to Appwrite
        },
        'options': {
          'audio_only': true,
          'file_type': 'MP3',  // MP3 format for better compatibility
          'advanced': {
            'audio_codec': 'OPUS',  // Optimal for voice
            'audio_bitrate': 64,    // 64 kbps for good quality
            'audio_frequency': 48000,
          }
        }
      };

      AppLogger().info('🚀 Attempting LiveKit Egress recording...');
      final success = await _callLiveKitEgress('start', egressRequest);

      if (success) {
        _currentRoomId = roomId;
        _isRecording = true;
        AppLogger().info('✅ RECORDING ACTIVE - LiveKit Egress started successfully');
        AppLogger().info('📊 Final state - _currentRoomId: $_currentRoomId, _isRecording: $_isRecording');
        return true;
      } else {
        AppLogger().error('❌ LiveKit Egress failed, trying client-side recording fallback');

        // Fallback to client-side recording
        AppLogger().info('🎤 Attempting client-side recording fallback...');
        final clientSuccess = await _startClientSideRecording(roomId);
        if (clientSuccess) {
          _currentRoomId = roomId;
          AppLogger().info('✅ RECORDING ACTIVE - Client-side recording started as fallback');
          AppLogger().info('📊 Final state - _currentRoomId: $_currentRoomId, _isLocalRecording: $_isLocalRecording');
          return true;
        } else {
          AppLogger().error('❌ Both server and client recording failed');
          return false;
        }
      }

    } catch (e) {
      AppLogger().error('❌ Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      AppLogger().info('🛑 RECORDING STOP - Called for room: $_currentRoomId');
      AppLogger().info('📊 Recording state - _isRecording: $_isRecording, _isLocalRecording: $_isLocalRecording');

      // Check if client-side recording is active
      if (_isLocalRecording) {
        AppLogger().info('🎬 Stopping client-side recording for room: $_currentRoomId');

        final recordingUrl = await _stopClientSideRecording();

        if (recordingUrl != null && _currentRoomId != null) {
          AppLogger().info('💾 Creating playback entry with client recording URL: $recordingUrl');

          // Create playback entry with client recording
          final playbackId = await _appwriteService.stopArenaRecording(
            roomId: _currentRoomId!,
            audioUrl: recordingUrl,
            duration: 0, // Will be updated after processing
            fileSize: 0, // Will be updated after processing
          );

          AppLogger().info('✅ PLAYBACK CREATED - ID: $playbackId');

          // Clean up
          _currentRoomId = null;
          _localRecordingFilePath = null;
          _isLocalRecording = false;  // Reset recording state

          AppLogger().info('✅ Client-side recording stopped, playback created: $playbackId');
          return playbackId;
        } else {
          AppLogger().error('❌ Client recording failed - recordingUrl: $recordingUrl, roomId: $_currentRoomId');
        }
      }

      // Handle server-side recording
      if (!_isRecording || _currentRoomId == null) {
        AppLogger().warning('⚠️ No server-side recording in progress - _isRecording: $_isRecording, _currentRoomId: $_currentRoomId');
        return null;
      }

      AppLogger().info('🎬 Stopping server-side recording for room: $_currentRoomId');

      final success = await _callLiveKitEgress('stop', {
        'egress_id': _currentEgressId,
      });

      if (success) {
        AppLogger().info('⏳ Waiting for recording completion...');
        final downloadUrl = await _waitForRecordingCompletion();

        if (downloadUrl != null) {
          AppLogger().info('💾 Creating playback entry with server recording URL: $downloadUrl');

          final playbackId = await _appwriteService.stopArenaRecording(
            roomId: _currentRoomId!,
            audioUrl: downloadUrl,
            duration: 0, // Will be updated after processing
            fileSize: 0, // Will be updated after processing
          );

          AppLogger().info('✅ PLAYBACK CREATED - ID: $playbackId');

          // Clean up recording state
          _isRecording = false;
          _currentRoomId = null;
          _currentEgressId = null;

          AppLogger().info('✅ Server-side recording stopped, playback created: $playbackId');
          return playbackId;
        } else {
          AppLogger().error('❌ Server recording completion failed - no download URL');
        }
      } else {
        AppLogger().error('❌ Server recording stop failed - recording may have already failed');
        AppLogger().info('💡 Will attempt to fall back to client-side recording if available');
      }

      // If we reach here, recording stop failed or no recording was active
      AppLogger().error('❌ RECORDING STOP FAILED - No recording was active or stop failed');
      AppLogger().info('📊 Final cleanup - _isRecording: $_isRecording, _isLocalRecording: $_isLocalRecording');

      // Clean up recording state
      _isRecording = false;
      _isLocalRecording = false;
      _currentRoomId = null;
      _currentEgressId = null;

      AppLogger().info('🧹 Recording state cleaned up - no playback created');
      return null;

    } catch (e) {
      AppLogger().error('❌ Error stopping recording: $e');
      return null;
    }
  }

  Future<bool> _callLiveKitEgress(String action, Map<String, dynamic> payload) async {
    try {
      // Check if LiveKit credentials are configured
      if (_liveKitApiKey.isEmpty || _liveKitApiSecret.isEmpty) {
        AppLogger().info('⚠️ LiveKit credentials not configured - recording disabled');
        AppLogger().info('   Set LIVEKIT_API_KEY and LIVEKIT_API_SECRET environment variables');
        return false;
      }

      final endpoint = action == 'start' ? 'StartRoomCompositeEgress' : 'StopEgress';
      final url = Uri.parse('$_liveKitHttpUrl/twirp/livekit.Egress/$endpoint');

      AppLogger().info('🔌 Calling LiveKit Egress API: $url');
      AppLogger().debug('📦 Payload: ${jsonEncode(payload)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_generateJWT()}',
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 30),  // Increased timeout for slower connections
        onTimeout: () {
          throw Exception('LiveKit Egress API timeout after 30 seconds');
        },
      );

      AppLogger().info('📡 Response status: ${response.statusCode}');
      AppLogger().debug('📝 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (action == 'start') {
          // Handle Livekit Egress response format
          _currentEgressId = responseData['egressId'] ?? responseData['egress_id'];
          AppLogger().info('✅ Recording started with egress ID: $_currentEgressId');
          AppLogger().debug('📋 Full Egress response: $responseData');
        } else {
          AppLogger().info('✅ Recording stopped');
        }
        return true;
      } else if (response.statusCode == 404) {
        AppLogger().error('❌ LiveKit Egress endpoint not found - server may not have Egress installed');
        AppLogger().info('💡 Will attempt client-side recording as fallback');
        return false;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger().error('❌ LiveKit authentication failed - check API credentials');
        return false;
      } else if (response.statusCode == 412) {
        final responseData = jsonDecode(response.body);
        AppLogger().error('❌ LiveKit Egress precondition failed: ${responseData['msg']}');
        AppLogger().info('💡 This usually means the room doesn\'t exist or recording is already in progress');
        return false;
      } else {
        AppLogger().error('❌ LiveKit Egress API error: ${response.statusCode}');
        AppLogger().error('   Response: ${response.body}');
        return false;
      }

    } catch (e) {
      AppLogger().error('❌ Error calling LiveKit Egress API: $e');
      if (e.toString().contains('SocketException')) {
        AppLogger().error('   Network error - LiveKit server may be unreachable');
      } else if (e.toString().contains('timeout')) {
        AppLogger().error('   Request timeout - LiveKit server may be overloaded');
      }
      return false;
    }
  }

  Future<String?> _waitForRecordingCompletion() async {
    try {
      AppLogger().info('⏳ Waiting for recording to complete processing...');

      // Check if LiveKit is configured
      if (_liveKitApiKey.isEmpty || _currentEgressId == null) {
        AppLogger().info('⚠️ Recording not active - no file will be saved');
        return null;
      }

      // Poll LiveKit for recording status
      for (int i = 0; i < 30; i++) { // Wait up to 5 minutes
        await Future.delayed(const Duration(seconds: 10));

        final status = await _getEgressStatus(_currentEgressId!);
        if (status?['status'] == 'EGRESS_COMPLETE') {
          // Download from LiveKit and upload to IONOS
          final liveKitUrl = status?['file_results']?[0]?['download_url'];
          if (liveKitUrl != null) {
            final localPath = await _downloadFromLiveKit(liveKitUrl);
            if (localPath != null) {
              return await _storageService.uploadRecording(
                localFilePath: localPath,
                roomId: _currentRoomId!,
                format: 'mp3',
              );
            }
          }
        } else if (status?['status'] == 'EGRESS_FAILED') {
          throw Exception('Recording failed during processing');
        }
      }

      throw Exception('Recording processing timeout');

    } catch (e) {
      AppLogger().error('Error waiting for recording completion: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getEgressStatus(String egressId) async {
    try {
      if (_liveKitApiKey.isEmpty || _liveKitApiSecret.isEmpty) {
        return null;
      }

      final url = Uri.parse('$_liveKitHttpUrl/twirp/livekit.Egress/ListEgress');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_generateJWT()}',
        },
        body: jsonEncode({
          'room_name': _currentRoomId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final egresses = responseData['items'] as List?;

        return egresses?.firstWhere(
          (egress) => egress['egress_id'] == egressId,
          orElse: () => null,
        );
      }

      return null;
    } catch (e) {
      AppLogger().error('Error getting egress status: $e');
      return null;
    }
  }

  String _generateJWT() {
    // Generate a proper JWT token for LiveKit API authentication
    if (_liveKitApiKey.isEmpty || _liveKitApiSecret.isEmpty) {
      AppLogger().warning('LiveKit credentials not configured for JWT generation');
      return '';
    }

    final jwt = JWT({
      'iss': _liveKitApiKey,
      'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      'nbf': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'video': {
        'roomRecord': true,
        'room': _currentRoomId ?? '',
      },
      'roomAdmin': true,
      'roomCreate': true,
    });

    return jwt.sign(SecretKey(_liveKitApiSecret), algorithm: JWTAlgorithm.HS256);
  }

  Future<void> createTimelineForRecording({
    required String playbackId,
    required List<Map<String, dynamic>> segments,
  }) async {
    try {
      AppLogger().info('📝 Creating timeline for playback: $playbackId');

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];

        await _appwriteService.createTimelineSegment(
          playbackId: playbackId,
          startTime: segment['startTime'] ?? 0,
          endTime: segment['endTime'] ?? 60,
          segmentType: segment['type'] ?? 'speech',
          speakerId: segment['speakerId'],
          speakerRole: segment['role'],
          phase: segment['phase'],
          title: segment['title'],
          description: segment['description'],
          isSkippable: segment['isSkippable'] ?? true,
          order: i,
        );
      }

      AppLogger().info('✅ Timeline created with ${segments.length} segments');
    } catch (e) {
      AppLogger().error('❌ Error creating timeline: $e');
    }
  }

  Future<void> recordEvent({
    required String playbackId,
    required int timestamp,
    required String eventType,
    String? userId,
    String? userName,
    String? userRole,
    String? content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _appwriteService.recordPlaybackEvent(
        playbackId: playbackId,
        timestamp: timestamp,
        eventType: eventType,
        userId: userId,
        userName: userName,
        userRole: userRole,
        content: content,
        metadata: metadata,
      );
    } catch (e) {
      AppLogger().error('Error recording playback event: $e');
    }
  }

  /// Download recording from LiveKit (for production use)
  Future<String?> _downloadFromLiveKit(String liveKitUrl) async {
    try {
      AppLogger().info('⬇️ Downloading recording from LiveKit...');

      final response = await http.get(Uri.parse(liveKitUrl));
      if (response.statusCode == 200) {
        final localPath = '/tmp/livekit_recording_$_currentRoomId.mp3';
        final localFile = File(localPath);

        await localFile.writeAsBytes(response.bodyBytes);
        AppLogger().info('✅ Downloaded recording from LiveKit: $localPath');

        return localPath;
      } else {
        throw Exception('Failed to download from LiveKit: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger().error('❌ Error downloading from LiveKit: $e');
      return null;
    }
  }

  /// Test IONOS server connection
  Future<bool> testStorageConnection() async {
    return await _storageService.testConnection();
  }

  /// Setup recording storage directory
  Future<bool> setupStorage() async {
    return await _storageService.setupRecordingDirectory();
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    return await _storageService.getStorageStats();
  }

  void dispose() {
    if (_isRecording) {
      stopRecording();
    }
    _localRecorder?.closeRecorder();
  }

  /// Client-side recording fallback methods
  Future<bool> _startClientSideRecording(String roomId) async {
    try {
      AppLogger().info('🎤 Starting client-side audio recording for room: $roomId');

      // Initialize recorder if needed
      if (_localRecorder == null) {
        _localRecorder = FlutterSoundRecorder();
        await _localRecorder!.openRecorder();
      }

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        AppLogger().error('❌ Microphone permission denied');
        return false;
      }

      // Get app documents directory for recording
      final dir = await getApplicationDocumentsDirectory();
      _localRecordingFilePath = '${dir.path}/arena_recording_$roomId.aac';

      // Start recording
      await _localRecorder!.startRecorder(
        toFile: _localRecordingFilePath,
        codec: Codec.aacADTS,
      );

      _isLocalRecording = true;
      AppLogger().info('✅ Client-side recording started: $_localRecordingFilePath');
      return true;
    } catch (e) {
      AppLogger().error('❌ Failed to start client-side recording: $e');
      return false;
    }
  }

  Future<String?> _stopClientSideRecording() async {
    try {
      if (!_isLocalRecording || _localRecorder == null) {
        return null;
      }

      AppLogger().info('🛑 Stopping client-side recording');

      await _localRecorder!.stopRecorder();
      _isLocalRecording = false;

      if (_localRecordingFilePath != null && File(_localRecordingFilePath!).existsSync()) {
        AppLogger().info('✅ Client-side recording saved: $_localRecordingFilePath');

        // Upload to storage
        final uploadedUrl = await _storageService.uploadRecording(
          localFilePath: _localRecordingFilePath!,
          roomId: _currentRoomId!,
          format: 'aac',
        );

        if (uploadedUrl != null) {
          AppLogger().info('☁️ Recording uploaded: $uploadedUrl');
          return uploadedUrl;
        } else {
          // Return local path if upload fails
          return _localRecordingFilePath;
        }
      }

      return null;
    } catch (e) {
      AppLogger().error('❌ Failed to stop client-side recording: $e');
      return null;
    }
  }
}