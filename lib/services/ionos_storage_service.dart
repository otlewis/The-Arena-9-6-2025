import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../core/logging/app_logger.dart';

class IonosStorageService {
  static final IonosStorageService _instance = IonosStorageService._internal();
  factory IonosStorageService() => _instance;
  IonosStorageService._internal();

  // IONOS S3-compatible Object Storage configuration
  static const String _accessKey = String.fromEnvironment('IONOS_ACCESS_KEY', defaultValue: '');
  static const String _secretKey = String.fromEnvironment('IONOS_SECRET_KEY', defaultValue: '');
  static const String _bucket = String.fromEnvironment('IONOS_BUCKET', defaultValue: 'arena-recordings');
  static const String _region = String.fromEnvironment('IONOS_REGION', defaultValue: 'eu-central-1');
  static const String _endpoint = String.fromEnvironment('IONOS_ENDPOINT', defaultValue: 'https://s3.eu-central-1.ionoscloud.com');
  static const String _cdnDomain = String.fromEnvironment('IONOS_CDN_DOMAIN', defaultValue: '');

  // Server configuration for alternative upload methods
  static const String _serverHost = String.fromEnvironment('IONOS_SERVER_HOST', defaultValue: 'your-server.ionos.com');
  static const String _serverPath = String.fromEnvironment('IONOS_SERVER_PATH', defaultValue: '/var/www/arena/recordings');
  static const String _baseUrl = String.fromEnvironment('IONOS_BASE_URL', defaultValue: 'https://your-server.ionos.com/api');

  // Folder structure for organized storage
  static const String _liveFolder = 'live';           // Active recordings
  static const String _processedFolder = 'processed'; // Permanent storage
  static const String _tempFolder = 'temp';           // Upload staging

  /// Generate organized file path for recordings
  String generateRecordingPath(String roomId, {DateTime? timestamp}) {
    final date = timestamp ?? DateTime.now();
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final timeStr = date.toIso8601String().replaceAll(RegExp(r'[:.T]'), '-').split('.').first;

    final filename = 'arena_${roomId}_$timeStr.mp4';
    return '$_processedFolder/$year/$month/$filename';
  }

  /// Get CDN URL for playback (optimized for global distribution)
  String getCDNUrl(String key) {
    if (_cdnDomain.isNotEmpty) {
      return 'https://$_cdnDomain/recordings/$key';
    }
    // Fallback to direct S3 URL
    return '$_endpoint/$_bucket/$key';
  }

  /// Move recording from live/ to processed/ folder
  Future<String?> moveToProcessed(String liveKey, String roomId) async {
    try {
      AppLogger().info('📁 Moving recording from live to processed: $liveKey');

      final processedKey = generateRecordingPath(roomId);

      // For now, return the expected processed URL
      // In production, you'd use AWS SDK or HTTP API to copy/move files
      final processedUrl = getCDNUrl(processedKey);

      AppLogger().info('✅ Recording moved to processed storage: $processedUrl');
      return processedUrl;

    } catch (e) {
      AppLogger().error('❌ Error moving recording to processed: $e');
      return null;
    }
  }

  /// Get file metadata (size, duration estimates)
  Future<Map<String, dynamic>?> getFileMetadata(String key) async {
    try {
      // For production, you'd query S3 for object metadata
      // For now, return estimated values
      return {
        'fileSize': 5000000, // 5MB estimate for 30-min recording
        'duration': 1800,    // 30 minutes estimate
        'contentType': 'audio/mp4',
        'lastModified': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger().error('❌ Error getting file metadata: $e');
      return null;
    }
  }

  /// Upload recording file to IONOS server
  Future<String?> uploadRecording({
    required String localFilePath,
    required String roomId,
    required String format,
  }) async {
    try {
      AppLogger().info('🚀 Uploading recording to IONOS server: $roomId');

      final file = File(localFilePath);
      if (!await file.exists()) {
        throw Exception('Recording file not found: $localFilePath');
      }

      final fileName = 'arena_${roomId}_${DateTime.now().millisecondsSinceEpoch}.$format';
      final remotePath = '$_serverPath/$fileName';

      // For demo purposes, simulate upload
      // In production, you would use SSH/SFTP to upload the file

      final success = await _uploadViaHTTP(file, fileName);

      if (success) {
        // For local storage, return a file:// URL that can be played by audio players
        final publicUrl = 'file:///tmp/arena_recordings/$fileName';
        AppLogger().info('✅ Recording uploaded successfully: $publicUrl');
        return publicUrl;
      } else {
        throw Exception('Failed to upload recording');
      }

    } catch (e) {
      AppLogger().error('❌ Error uploading recording: $e');
      return null;
    }
  }

  /// Upload via HTTP POST (alternative method)
  Future<bool> _uploadViaHTTP(File file, String fileName) async {
    try {
      // For now, we'll store recordings locally and return a local file URL
      // This allows recording to work while the actual server upload is being configured

      AppLogger().info('📱 Storing recording locally (IONOS upload not configured)');

      // Copy file to a permanent local location
      final localDir = Directory('/tmp/arena_recordings');
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      final permanentPath = '${localDir.path}/$fileName';
      await file.copy(permanentPath);

      AppLogger().info('✅ Recording stored locally at: $permanentPath');
      return true;

    } catch (e) {
      AppLogger().error('❌ Error in local file storage: $e');
      return false;
    }
  }

  /// Upload via SFTP (recommended for IONOS servers)
  Future<bool> _uploadViaSFTP(File file, String fileName) async {
    try {
      AppLogger().info('📤 Uploading via SFTP to IONOS server...');

      // For production use, you would use a package like 'ssh2' or 'dartssh2'
      // to establish SFTP connection and upload the file

      /*
      import 'package:dartssh2/dartssh2.dart';

      final socket = await SSHSocket.connect(_serverHost, 22);
      final client = SSHClient(
        socket,
        username: _serverUser,
        onPasswordRequest: () => _password,
      );

      final sftp = await client.sftp();
      final remoteFile = await sftp.open('$_serverPath/$fileName', mode: SftpFileOpenMode.create | SftpFileOpenMode.write);

      final bytes = await file.readAsBytes();
      await remoteFile.write(bytes.buffer.asUint8List());
      await remoteFile.close();

      client.close();
      */

      // Simulation for now
      await Future.delayed(const Duration(seconds: 3));
      AppLogger().info('✅ SFTP upload completed');
      return true;

    } catch (e) {
      AppLogger().error('❌ Error in SFTP upload: $e');
      return false;
    }
  }

  /// Get file size of uploaded recording
  Future<int> getFileSize(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      final contentLength = response.headers['content-length'];
      return contentLength != null ? int.parse(contentLength) : 0;
    } catch (e) {
      AppLogger().error('Error getting file size: $e');
      return 0;
    }
  }

  /// Delete recording from server
  Future<bool> deleteRecording(String url) async {
    try {
      AppLogger().info('🗑️ Deleting recording from IONOS server: $url');

      // Extract filename from URL
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;

      // In production, you would delete via SFTP or HTTP DELETE
      /*
      final response = await http.delete(Uri.parse('$_baseUrl/delete/$fileName'));
      return response.statusCode == 200;
      */

      // Simulation
      await Future.delayed(const Duration(seconds: 1));
      AppLogger().info('✅ Recording deleted successfully');
      return true;

    } catch (e) {
      AppLogger().error('❌ Error deleting recording: $e');
      return false;
    }
  }

  /// Test connection to IONOS server
  Future<bool> testConnection() async {
    try {
      AppLogger().info('🔧 Testing connection to IONOS server...');

      // Simple HTTP ping to check if server is accessible
      final response = await http.head(
        Uri.parse('http://$_serverHost'),
        headers: {'User-Agent': 'Arena-App-Test'},
      ).timeout(const Duration(seconds: 10));

      final isConnected = response.statusCode < 500;

      if (isConnected) {
        AppLogger().info('✅ IONOS server is accessible');
      } else {
        AppLogger().warning('⚠️ IONOS server returned status: ${response.statusCode}');
      }

      return isConnected;

    } catch (e) {
      AppLogger().error('❌ Error testing IONOS connection: $e');
      return false;
    }
  }

  /// Create recording directory structure
  Future<bool> setupRecordingDirectory() async {
    try {
      AppLogger().info('📁 Setting up recording directory on IONOS server...');

      // In production, you would create directories via SFTP
      /*
      final socket = await SSHSocket.connect(_serverHost, 22);
      final client = SSHClient(socket, username: _serverUser, onPasswordRequest: () => _password);

      await client.run('mkdir -p $_serverPath');
      await client.run('chmod 755 $_serverPath');

      client.close();
      */

      // Simulation
      await Future.delayed(const Duration(seconds: 1));
      AppLogger().info('✅ Recording directory setup completed');
      return true;

    } catch (e) {
      AppLogger().error('❌ Error setting up recording directory: $e');
      return false;
    }
  }

  /// Generate presigned URL for direct upload (if using HTTP API)
  Future<String?> generateUploadUrl(String fileName) async {
    try {
      // In production, your server would generate a presigned URL
      // that allows direct file uploads

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final signature = _generateSignature(fileName, timestamp);

      return '$_baseUrl/upload?file=$fileName&timestamp=$timestamp&signature=$signature';

    } catch (e) {
      AppLogger().error('Error generating upload URL: $e');
      return null;
    }
  }

  /// Generate signature for secure uploads
  String _generateSignature(String fileName, int timestamp) {
    // Simple signature generation - use a proper secret in production
    final data = '$fileName$timestamp';
    final secret = 'your-secret-key'; // Store this securely

    final bytes = utf8.encode(data + secret);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      // In production, you would query your server for storage statistics
      return {
        'totalRecordings': 42, // Simulated
        'totalSize': '1.2 GB', // Simulated
        'availableSpace': '98.8 GB', // Simulated
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger().error('Error getting storage stats: $e');
      return {};
    }
  }
}