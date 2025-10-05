import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Simple audio-only recording service for Arena debates
/// Records locally and uploads to Appwrite Storage
class SimpleAudioRecordingService {
  static final SimpleAudioRecordingService _instance = SimpleAudioRecordingService._internal();
  factory SimpleAudioRecordingService() => _instance;
  SimpleAudioRecordingService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  FlutterSoundRecorder? _recorder;

  String? _currentFilePath;
  String? _currentRoomId;
  DateTime? _recordingStartTime;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Initialize the recorder
  Future<void> _initRecorder() async {
    if (_recorder != null) {
      return; // Already initialized
    }

    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    AppLogger().info('🎙️ Audio recorder initialized');
  }

  /// Start recording audio for a room
  Future<bool> startRecording({
    required String roomId,
    required String roomName,
  }) async {
    try {
      AppLogger().info('🎬 Starting audio recording for room: $roomId');

      // Check microphone permission
      final status = await ph.Permission.microphone.request();
      if (!status.isGranted) {
        AppLogger().error('❌ Microphone permission not granted');
        return false;
      }

      // Initialize recorder if needed
      await _initRecorder();

      if (_isRecording) {
        AppLogger().warning('⚠️ Recording already in progress');
        return false;
      }

      // Generate file path
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentFilePath = '${directory.path}/arena_${roomId}_$timestamp.aac';
      _currentRoomId = roomId;
      _recordingStartTime = DateTime.now();

      // Start recording
      await _recorder!.startRecorder(
        toFile: _currentFilePath,
        codec: Codec.aacADTS, // AAC format for good quality and compatibility
        bitRate: 128000, // 128kbps - good quality for voice
        sampleRate: 44100,
      );

      _isRecording = true;
      AppLogger().info('✅ Audio recording started: $_currentFilePath');

      // Update room status in Appwrite
      await _appwriteService.startArenaRecording(roomId);

      return true;
    } catch (e) {
      AppLogger().error('❌ Error starting audio recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and upload to Appwrite
  Future<String?> stopRecording() async {
    try {
      AppLogger().info('🛑 Stopping audio recording');

      if (!_isRecording || _recorder == null || _currentFilePath == null) {
        AppLogger().warning('⚠️ No active recording to stop');
        return null;
      }

      // Stop the recorder
      await _recorder!.stopRecorder();
      _isRecording = false;

      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : 0;

      AppLogger().info('✅ Recording stopped. Duration: ${duration}s');

      // Check if file exists
      final file = File(_currentFilePath!);
      if (!await file.exists()) {
        AppLogger().error('❌ Recording file not found: $_currentFilePath');
        return null;
      }

      final fileSize = await file.length();
      AppLogger().info('📊 Recording file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Upload to Appwrite Storage
      AppLogger().info('📤 Uploading recording to Appwrite...');
      final audioUrl = await _uploadToAppwrite(file, _currentRoomId!);

      if (audioUrl == null) {
        AppLogger().error('❌ Failed to upload recording');
        return null;
      }

      AppLogger().info('✅ Recording uploaded: $audioUrl');

      // Create playback document in arena_playbacks collection
      final playbackId = await _createPlaybackDocument(
        roomId: _currentRoomId!,
        audioUrl: audioUrl,
        duration: duration,
      );

      // Clean up local file
      try {
        await file.delete();
        AppLogger().info('🧹 Local recording file deleted');
      } catch (e) {
        AppLogger().warning('⚠️ Could not delete local file: $e');
      }

      // Reset state
      _currentFilePath = null;
      _currentRoomId = null;
      _recordingStartTime = null;

      AppLogger().info('✅ Playback created with ID: $playbackId');
      return playbackId;

    } catch (e) {
      AppLogger().error('❌ Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Upload audio file to Appwrite Storage
  Future<String?> _uploadToAppwrite(File file, String roomId) async {
    try {
      final storage = Storage(_appwriteService.client);
      final bucketId = 'arena-playbacks'; // Create this bucket in Appwrite

      // Upload file
      final uploadedFile = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: file.path,
          filename: 'arena_${roomId}_${DateTime.now().millisecondsSinceEpoch}.aac',
        ),
      );

      // Get file URL
      final fileUrl = '${_appwriteService.client.endPoint}/storage/buckets/$bucketId/files/${uploadedFile.$id}/view?project=${_appwriteService.client.config['project']}';

      AppLogger().info('✅ File uploaded to Appwrite: ${uploadedFile.$id}');
      return fileUrl;

    } catch (e) {
      AppLogger().error('❌ Error uploading to Appwrite: $e');
      return null;
    }
  }

  /// Create playback document in arena_playbacks collection
  Future<String?> _createPlaybackDocument({
    required String roomId,
    required String audioUrl,
    required int duration,
  }) async {
    try {
      // Get room details
      final roomDoc = await _appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
      );

      final roomData = roomDoc.data;
      final topic = roomData['topic'] ?? 'Untitled Debate';

      // Create playback document
      final playback = await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        documentId: ID.unique(),
        data: {
          'roomId': roomId,
          'title': topic,
          'recordingUrl': audioUrl,
          'duration': duration,
          'status': 'ready',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      // Update room status to completed with playback ready
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': 'completed',
          'playbackStatus': 'ready',
          'playbackId': playback.$id,
        },
      );

      AppLogger().info('✅ Playback document created: ${playback.$id}');
      return playback.$id;

    } catch (e) {
      AppLogger().error('❌ Error creating playback document: $e');
      return null;
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_recorder != null) {
      await _recorder!.closeRecorder();
      _recorder = null;
    }
  }
}
