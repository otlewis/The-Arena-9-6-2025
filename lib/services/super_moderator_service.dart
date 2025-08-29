import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../models/super_moderator.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

class SuperModeratorService {
  static final SuperModeratorService _instance = SuperModeratorService._internal();
  factory SuperModeratorService() => _instance;
  SuperModeratorService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();
  
  // Cache of super moderators
  final Map<String, SuperModerator> _superModCache = {};
  StreamController<List<SuperModerator>>? _superModsController;
  RealtimeSubscription? _superModsSubscription;
  
  // Database configuration
  static const String _databaseId = 'arena_db';
  static const String _collectionId = 'super_moderators';
  
  /// Initialize the service and set up real-time subscriptions
  Future<void> initialize() async {
    try {
      _superModsController = StreamController<List<SuperModerator>>.broadcast();
      await _loadSuperModerators();
      _setupRealtimeSubscription();
    } catch (e) {
      _logger.error('Failed to initialize SuperModeratorService: $e');
    }
  }
  
  /// Load all active super moderators
  Future<void> _loadSuperModerators() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('isActive', true),
        ],
      );
      
      _superModCache.clear();
      for (final doc in response.documents) {
        final docData = doc.data;
        final superMod = SuperModerator(
          id: doc.$id,
          userId: docData['userId'],
          username: docData['username'],
          profileImageUrl: docData['profileImageUrl'],
          grantedAt: DateTime.parse(docData['grantedAt']),
          grantedBy: docData['grantedBy'],
          isActive: docData['isActive'],
          permissions: List<String>.from(docData['permissions']),
          metadata: docData['metadata'] != null 
              ? jsonDecode(docData['metadata']) 
              : <String, dynamic>{},
        );
        _superModCache[superMod.userId] = superMod;
      }
      
      _superModsController?.add(_superModCache.values.toList());
      _logger.info('🛡️ Loaded ${_superModCache.length} super moderators');
    } catch (e) {
      _logger.error('Failed to load super moderators: $e');
    }
  }
  
  /// Set up real-time subscription for super moderator changes
  void _setupRealtimeSubscription() {
    try {
      const channel = 'databases.arena_db.collections.super_moderators.documents';
      _superModsSubscription = _appwrite.realtime.subscribe([channel])
        ..stream.listen((event) {
          _handleRealtimeUpdate(event);
        });
    } catch (e) {
      _logger.error('Failed to setup super mods subscription: $e');
    }
  }
  
  /// Handle real-time updates
  void _handleRealtimeUpdate(RealtimeMessage event) {
    try {
      if (event.payload.isEmpty) return;
      
      final eventType = event.events.first.split('.').last;
      final data = event.payload;
      
      switch (eventType) {
        case 'create':
        case 'update':
          final superMod = SuperModerator(
            id: data['\$id'],
            userId: data['userId'],
            username: data['username'],
            profileImageUrl: data['profileImageUrl'],
            grantedAt: DateTime.parse(data['grantedAt']),
            grantedBy: data['grantedBy'],
            isActive: data['isActive'],
            permissions: List<String>.from(data['permissions']),
            metadata: data['metadata'] != null 
                ? jsonDecode(data['metadata']) 
                : <String, dynamic>{},
          );
          if (superMod.isActive) {
            _superModCache[superMod.userId] = superMod;
          } else {
            _superModCache.remove(superMod.userId);
          }
          break;
        case 'delete':
          final userId = data['userId'] as String?;
          if (userId != null) {
            _superModCache.remove(userId);
          }
          break;
      }
      
      _superModsController?.add(_superModCache.values.toList());
    } catch (e) {
      _logger.error('Error handling super mod realtime update: $e');
    }
  }
  
  /// Check if a user is a super moderator
  bool isSuperModerator(String userId) {
    // Hardcoded: Kritik is always a Super Moderator
    if (userId == '6843c3781d2c1c7154a0') {
      return true;
    }
    return _superModCache.containsKey(userId);
  }
  
  /// Check if a user has a specific permission
  bool hasPermission(String userId, String permission) {
    // Hardcoded: Kritik has all permissions
    if (userId == '6843c3781d2c1c7154a0') {
      return SuperModPermissions.allPermissions.contains(permission);
    }
    final superMod = _superModCache[userId];
    if (superMod == null) return false;
    return superMod.permissions.contains(permission);
  }
  
  /// Grant super moderator status to a user
  Future<SuperModerator?> grantSuperModeratorStatus({
    required String userId,
    required String username,
    required String grantedBy,
    String? profileImageUrl,
    List<String>? customPermissions,
  }) async {
    try {
      // Check if granter has permission to promote
      if (!hasPermission(grantedBy, SuperModPermissions.promoteSupermods) && 
          grantedBy != 'system') {
        throw Exception('User does not have permission to promote super moderators');
      }
      
      final metadataMap = {
        'grantedByUserId': grantedBy,
        'grantedByUsername': await _getUsername(grantedBy),
      };

      // Create database document with JSON string metadata
      final doc = await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: _collectionId,
        documentId: 'unique()',
        data: {
          'userId': userId,
          'username': username,
          'profileImageUrl': profileImageUrl,
          'grantedAt': DateTime.now().toIso8601String(),
          'grantedBy': grantedBy,
          'isActive': true,
          'permissions': customPermissions ?? SuperModPermissions.allPermissions,
          'metadata': jsonEncode(metadataMap),
        },
      );
      
      // Convert back to SuperModerator model with parsed metadata
      final docData = doc.data;
      final created = SuperModerator(
        id: doc.$id,
        userId: docData['userId'],
        username: docData['username'],
        profileImageUrl: docData['profileImageUrl'],
        grantedAt: DateTime.parse(docData['grantedAt']),
        grantedBy: docData['grantedBy'],
        isActive: docData['isActive'],
        permissions: List<String>.from(docData['permissions']),
        metadata: docData['metadata'] != null 
            ? jsonDecode(docData['metadata']) 
            : <String, dynamic>{},
      );
      _superModCache[userId] = created;
      _superModsController?.add(_superModCache.values.toList());
      
      _logger.info('🎖️ Granted super moderator status to $username by $grantedBy');
      return created;
    } catch (e) {
      _logger.error('Failed to grant super moderator status: $e');
      return null;
    }
  }
  
  /// Revoke super moderator status
  Future<bool> revokeSuperModeratorStatus(String userId, String revokedBy) async {
    try {
      // Find the super mod document
      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('isActive', true),
        ],
      );
      
      if (response.documents.isEmpty) return false;
      
      // Update to inactive
      await _appwrite.databases.updateDocument(
        databaseId: _databaseId,
        collectionId: _collectionId,
        documentId: response.documents.first.$id,
        data: {
          'isActive': false,
          'metadata': jsonEncode({
            'revokedBy': revokedBy,
            'revokedAt': DateTime.now().toIso8601String(),
          }),
        },
      );
      
      _superModCache.remove(userId);
      _superModsController?.add(_superModCache.values.toList());
      
      _logger.info('🚫 Revoked super moderator status for user $userId');
      return true;
    } catch (e) {
      _logger.error('Failed to revoke super moderator status: $e');
      return false;
    }
  }
  
  /// Ban a user from a room (Super Mod action)
  Future<bool> banUserFromRoom({
    required String superModId,
    required String targetUserId,
    required String roomId,
    required String roomType,
    String? reason,
    int? durationMinutes,
  }) async {
    try {
      if (!hasPermission(superModId, SuperModPermissions.banUsers)) {
        throw Exception('Super moderator does not have ban permission');
      }
      
      final banData = {
        'userId': targetUserId,
        'roomId': roomId,
        'roomType': roomType,
        'bannedBy': superModId,
        'reason': reason ?? 'Banned by super moderator',
        'bannedAt': DateTime.now().toIso8601String(),
        'expiresAt': durationMinutes != null 
            ? DateTime.now().add(Duration(minutes: durationMinutes)).toIso8601String()
            : null,
        'isActive': true,
      };
      
      await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'room_bans',
        documentId: 'unique()',
        data: banData,
      );
      
      _logger.info('🔨 User $targetUserId banned from room $roomId by super mod $superModId');
      return true;
    } catch (e) {
      _logger.error('Failed to ban user: $e');
      return false;
    }
  }
  
  /// Kick a user from a room (temporary removal)
  Future<bool> kickUserFromRoom({
    required String superModId,
    required String targetUserId,
    required String roomId,
    String? reason,
  }) async {
    try {
      if (!hasPermission(superModId, SuperModPermissions.kickUsers)) {
        throw Exception('Super moderator does not have kick permission');
      }
      
      // Send kick event through realtime
      final kickEvent = {
        'type': 'user_kicked',
        'userId': targetUserId,
        'roomId': roomId,
        'kickedBy': superModId,
        'reason': reason ?? 'Kicked by super moderator',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // This will be picked up by the room's real-time listeners
      await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'room_events',
        documentId: 'unique()',
        data: kickEvent,
      );
      
      _logger.info('👢 User $targetUserId kicked from room $roomId by super mod $superModId');
      return true;
    } catch (e) {
      _logger.error('Failed to kick user: $e');
      return false;
    }
  }
  
  /// Lock/unlock microphones in a room
  Future<bool> setMicrophoneLock({
    required String superModId,
    required String roomId,
    required bool locked,
    List<String>? exemptUserIds,
  }) async {
    try {
      if (!hasPermission(superModId, SuperModPermissions.lockMics)) {
        throw Exception('Super moderator does not have mic lock permission');
      }
      
      final lockEvent = {
        'type': 'mic_lock_status',
        'roomId': roomId,
        'locked': locked,
        'lockedBy': superModId,
        'exemptUsers': exemptUserIds ?? [],
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'room_events',
        documentId: 'unique()',
        data: lockEvent,
      );
      
      _logger.info('🔇 Microphones ${locked ? 'locked' : 'unlocked'} in room $roomId by super mod $superModId');
      return true;
    } catch (e) {
      _logger.error('Failed to set microphone lock: $e');
      return false;
    }
  }
  
  /// Get username helper
  Future<String> _getUsername(String userId) async {
    try {
      if (userId == 'system') return 'System';
      final profile = await _appwrite.getUserProfile(userId);
      return profile?.name ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Get stream of super moderators
  Stream<List<SuperModerator>> get superModsStream => 
      _superModsController?.stream ?? const Stream.empty();
  
  /// Get all current super moderators
  List<SuperModerator> get allSuperMods => _superModCache.values.toList();
  
  /// Dispose of resources
  void dispose() {
    _superModsSubscription?.close();
    _superModsController?.close();
  }
}