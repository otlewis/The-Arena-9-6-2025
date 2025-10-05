import 'dart:async';
import 'dart:convert';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'ionos_storage_service.dart';
import 'chapter_detection_service.dart';

/// Service for handling RevenueCat and Livekit Egress webhooks
class WebhookService {
  static final WebhookService _instance = WebhookService._internal();
  factory WebhookService() => _instance;
  WebhookService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  final IonosStorageService _storageService = IonosStorageService();
  final ChapterDetectionService _chapterService = ChapterDetectionService();

  /// Process RevenueCat webhook payload
  Future<bool> processRevenueCatWebhook(Map<String, dynamic> payload) async {
    try {
      AppLogger().debug('🪝 Processing RevenueCat webhook: ${payload['event_type']}');
      
      final eventType = payload['event_type'] as String;
      final event = payload['event'] as Map<String, dynamic>;
      
      // Extract user and subscription info
      final appUserId = event['app_user_id'] as String?;
      final productId = event['product_id'] as String?;
      final eventTimeMs = event['event_timestamp_ms'] as int?;
      final environment = event['environment'] as String?; // 'SANDBOX' or 'PRODUCTION'
      
      if (appUserId == null) {
        AppLogger().warning('Webhook missing app_user_id');
        return false;
      }

      // Store webhook event for audit trail
      await _storeWebhookEvent(eventType, payload, appUserId);

      // Process different event types
      switch (eventType) {
        case 'INITIAL_PURCHASE':
        case 'RENEWAL':
        case 'PRODUCT_CHANGE':
          return await _handleSubscriptionActivation(appUserId, productId, environment, eventTimeMs);
          
        case 'CANCELLATION':
          return await _handleSubscriptionCancellation(appUserId, eventTimeMs);
          
        case 'EXPIRATION':
          return await _handleSubscriptionExpiration(appUserId, eventTimeMs);
          
        case 'BILLING_ISSUE':
          return await _handleBillingIssue(appUserId, eventTimeMs);
          
        case 'SUBSCRIBER_ALIAS':
          return await _handleSubscriberAlias(event);
          
        default:
          AppLogger().info('Unhandled webhook event type: $eventType');
          return true; // Don't fail for unknown events
      }
      
    } catch (e) {
      AppLogger().error('Failed to process RevenueCat webhook: $e');
      return false;
    }
  }

  /// Store webhook event for audit trail
  Future<void> _storeWebhookEvent(String eventType, Map<String, dynamic> payload, String userId) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'webhook_events',
        documentId: 'unique()',
        data: {
          'eventType': eventType,
          'userId': userId,
          'payload': jsonEncode(payload),
          'processedAt': DateTime.now().toIso8601String(),
          'source': 'revenuecat',
        },
      );
    } catch (e) {
      AppLogger().warning('Failed to store webhook event: $e');
      // Don't fail the main process if audit logging fails
    }
  }

  /// Handle subscription activation (purchase, renewal, upgrade)
  Future<bool> _handleSubscriptionActivation(String userId, String? productId, String? environment, int? eventTimeMs) async {
    try {
      final isTestSubscription = environment == 'SANDBOX';
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Calculate expiry based on product type
      Duration subscriptionDuration;
      String premiumType;
      
      if (productId?.contains('yearly') == true) {
        subscriptionDuration = const Duration(days: 365);
        premiumType = 'yearly';
      } else {
        subscriptionDuration = const Duration(days: 30);
        premiumType = 'monthly';
      }
      
      final expiryDate = eventTime.add(subscriptionDuration);
      
      // Update user profile
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': true,
          'premiumType': premiumType,
          'premiumExpiry': expiryDate.toIso8601String(),
          'isTestSubscription': isTestSubscription,
          'lastWebhookUpdate': DateTime.now().toIso8601String(),
        },
      );

      // Store subscription record
      await _storeSubscriptionRecord(userId, productId, 'active', eventTime, expiryDate, isTestSubscription);
      
      AppLogger().info('✅ Subscription activated for user $userId: $premiumType ($productId)');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscription activation: $e');
      return false;
    }
  }

  /// Handle subscription cancellation
  Future<bool> _handleSubscriptionCancellation(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Don't immediately revoke premium - let it expire naturally
      // Just update the subscription status
      await _storeSubscriptionRecord(userId, null, 'cancelled', eventTime, null, false);
      
      AppLogger().info('📋 Subscription cancelled for user $userId (will expire at natural end date)');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscription cancellation: $e');
      return false;
    }
  }

  /// Handle subscription expiration
  Future<bool> _handleSubscriptionExpiration(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Revoke premium status
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': false,
          'premiumType': null,
          'premiumExpiry': null,
          'lastWebhookUpdate': DateTime.now().toIso8601String(),
        },
      );

      // Store expiration record
      await _storeSubscriptionRecord(userId, null, 'expired', eventTime, null, false);
      
      AppLogger().info('⏰ Subscription expired for user $userId');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscription expiration: $e');
      return false;
    }
  }

  /// Handle billing issues
  Future<bool> _handleBillingIssue(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Store billing issue record (don't revoke premium immediately - give grace period)
      await _storeSubscriptionRecord(userId, null, 'billing_issue', eventTime, null, false);
      
      AppLogger().warning('💳 Billing issue for user $userId');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle billing issue: $e');
      return false;
    }
  }

  /// Handle subscriber alias (user ID changes)
  Future<bool> _handleSubscriberAlias(Map<String, dynamic> event) async {
    try {
      final originalAppUserId = event['original_app_user_id'] as String?;
      final newAppUserId = event['new_app_user_id'] as String?;
      
      if (originalAppUserId == null || newAppUserId == null) {
        AppLogger().warning('Webhook missing user IDs for alias');
        return false;
      }

      // Store alias record for tracking
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'user_aliases',
        documentId: 'unique()',
        data: {
          'originalUserId': originalAppUserId,
          'newUserId': newAppUserId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('🔄 Subscriber alias: $originalAppUserId -> $newAppUserId');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscriber alias: $e');
      return false;
    }
  }

  /// Store subscription record for history/audit
  Future<void> _storeSubscriptionRecord(
    String userId,
    String? productId,
    String status,
    DateTime eventTime,
    DateTime? expiryDate,
    bool isTest,
  ) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'subscription_records',
        documentId: 'unique()',
        data: {
          'userId': userId,
          'productId': productId,
          'status': status, // active, cancelled, expired, billing_issue
          'eventTime': eventTime.toIso8601String(),
          'expiryDate': expiryDate?.toIso8601String(),
          'isTestSubscription': isTest,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger().warning('Failed to store subscription record: $e');
      // Don't fail the main process
    }
  }

  /// Clean up expired test subscriptions (for maintenance)
  Future<void> cleanupExpiredTestSubscriptions() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      // This would typically be done via a scheduled function
      // For now, just log that it should be done
      AppLogger().info('🧹 Cleanup needed for test subscriptions older than ${cutoffDate.toIso8601String()}');

    } catch (e) {
      AppLogger().error('Failed to cleanup test subscriptions: $e');
    }
  }

  // ========================================
  // LIVEKIT EGRESS RECORDING WEBHOOKS
  // ========================================

  /// Process Livekit Egress webhook for recording lifecycle events
  Future<bool> processEgressWebhook(Map<String, dynamic> payload) async {
    try {
      AppLogger().info('🎵 Processing Livekit Egress webhook');
      AppLogger().debug('Webhook payload: ${jsonEncode(payload)}');

      final egressInfo = payload['egress_info'] as Map<String, dynamic>?;
      if (egressInfo == null) {
        AppLogger().warning('Webhook missing egress_info');
        return false;
      }

      final egressId = egressInfo['egress_id'] as String?;
      final roomName = egressInfo['room_name'] as String?;
      final status = egressInfo['status'] as String?;

      if (egressId == null || roomName == null || status == null) {
        AppLogger().warning('Webhook missing required fields: egressId=$egressId, roomName=$roomName, status=$status');
        return false;
      }

      // Store webhook event for audit trail
      await _storeEgressWebhookEvent(egressId, roomName, status, payload);

      // Process different status types
      switch (status.toLowerCase()) {
        case 'egress_starting':
          return await _handleRecordingStarted(egressId, roomName, egressInfo);

        case 'egress_active':
          return await _handleRecordingActive(egressId, roomName, egressInfo);

        case 'egress_ending':
          return await _handleRecordingEnding(egressId, roomName, egressInfo);

        case 'egress_complete':
          return await _handleRecordingCompleted(egressId, roomName, egressInfo);

        case 'egress_failed':
          return await _handleRecordingFailed(egressId, roomName, egressInfo);

        default:
          AppLogger().info('Unhandled egress status: $status');
          return true; // Don't fail for unknown statuses
      }

    } catch (e) {
      AppLogger().error('Failed to process Egress webhook: $e');
      return false;
    }
  }

  /// Store egress webhook event for audit trail
  Future<void> _storeEgressWebhookEvent(String egressId, String roomName, String status, Map<String, dynamic> payload) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'webhook_events',
        documentId: 'unique()',
        data: {
          'eventType': 'egress_$status',
          'egressId': egressId,
          'roomName': roomName,
          'payload': jsonEncode(payload),
          'processedAt': DateTime.now().toIso8601String(),
          'source': 'livekit_egress',
        },
      );
    } catch (e) {
      AppLogger().warning('Failed to store egress webhook event: $e');
      // Don't fail the main process if audit logging fails
    }
  }

  /// Handle recording started event
  Future<bool> _handleRecordingStarted(String egressId, String roomName, Map<String, dynamic> egressInfo) async {
    try {
      AppLogger().info('🎬 Recording started for room: $roomName (egress: $egressId)');

      // Update room recording status
      await _updateRoomRecordingStatus(roomName, 'recording', {
        'egressId': egressId,
        'recordingStartedAt': DateTime.now().toIso8601String(),
        'status': 'starting',
      });

      return true;

    } catch (e) {
      AppLogger().error('Failed to handle recording started: $e');
      return false;
    }
  }

  /// Handle recording active event
  Future<bool> _handleRecordingActive(String egressId, String roomName, Map<String, dynamic> egressInfo) async {
    try {
      AppLogger().info('📹 Recording active for room: $roomName (egress: $egressId)');

      // Update room recording status to active
      await _updateRoomRecordingStatus(roomName, 'recording', {
        'egressId': egressId,
        'status': 'active',
        'lastActiveAt': DateTime.now().toIso8601String(),
      });

      return true;

    } catch (e) {
      AppLogger().error('Failed to handle recording active: $e');
      return false;
    }
  }

  /// Handle recording ending event
  Future<bool> _handleRecordingEnding(String egressId, String roomName, Map<String, dynamic> egressInfo) async {
    try {
      AppLogger().info('⏹️ Recording ending for room: $roomName (egress: $egressId)');

      // Update room recording status to ending
      await _updateRoomRecordingStatus(roomName, 'recording', {
        'egressId': egressId,
        'status': 'ending',
        'recordingEndedAt': DateTime.now().toIso8601String(),
      });

      return true;

    } catch (e) {
      AppLogger().error('Failed to handle recording ending: $e');
      return false;
    }
  }

  /// Handle recording completed successfully
  Future<bool> _handleRecordingCompleted(String egressId, String roomName, Map<String, dynamic> egressInfo) async {
    try {
      AppLogger().info('✅ Recording completed for room: $roomName (egress: $egressId)');

      // Extract file information from egress response
      final fileResults = egressInfo['file_results'] as List<dynamic>?;
      if (fileResults == null || fileResults.isEmpty) {
        AppLogger().warning('No file results in completed egress');
        return false;
      }

      final fileResult = fileResults.first as Map<String, dynamic>;
      final filename = fileResult['filename'] as String?;
      final downloadUrl = fileResult['download_url'] as String?;
      final size = fileResult['size'] as int?;
      final duration = fileResult['duration'] as int?; // in nanoseconds

      if (filename == null) {
        AppLogger().warning('No filename in egress file result');
        return false;
      }

      // Move file from live/ to processed/ folder in IONOS storage
      final liveKey = 'live/$filename';
      final processedUrl = await _storageService.moveToProcessed(liveKey, roomName);

      // Create playback record in Appwrite
      final playbackData = {
        'roomName': roomName,
        'egressId': egressId,
        'title': 'Arena Recording - $roomName',
        'audioUrl': processedUrl ?? downloadUrl,
        'originalFilename': filename,
        'fileSizeBytes': size,
        'durationMs': duration != null ? (duration / 1000000).round() : null, // Convert nanoseconds to milliseconds
        'status': 'available',
        'recordingStartedAt': null, // Will be updated from room data
        'recordingCompletedAt': DateTime.now().toIso8601String(),
        'viewCount': 0,
        'chapters': null, // Will be added later via speaker detection
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final playbackDocument = await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        documentId: 'unique()',
        data: playbackData,
      );

      final playbackId = playbackDocument.data['\$id'] as String;

      // Update room with completed recording info
      await _updateRoomRecordingStatus(roomName, 'completed', {
        'egressId': egressId,
        'status': 'completed',
        'playbackId': playbackId,
        'audioUrl': processedUrl ?? downloadUrl,
        'recordingCompletedAt': DateTime.now().toIso8601String(),
      });

      AppLogger().info('🎵 Playback record created: $playbackId for room: $roomName');

      // Generate chapters for the completed recording
      _processChaptersAsync(playbackId);

      return true;

    } catch (e) {
      AppLogger().error('Failed to handle recording completed: $e');
      return false;
    }
  }

  /// Handle recording failed event
  Future<bool> _handleRecordingFailed(String egressId, String roomName, Map<String, dynamic> egressInfo) async {
    try {
      final error = egressInfo['error'] as String?;
      AppLogger().error('❌ Recording failed for room: $roomName (egress: $egressId) - Error: $error');

      // Update room recording status to failed
      await _updateRoomRecordingStatus(roomName, 'failed', {
        'egressId': egressId,
        'status': 'failed',
        'error': error,
        'recordingFailedAt': DateTime.now().toIso8601String(),
      });

      // Store failure record for analysis
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'recording_failures',
        documentId: 'unique()',
        data: {
          'roomName': roomName,
          'egressId': egressId,
          'error': error,
          'egressInfo': jsonEncode(egressInfo),
          'failedAt': DateTime.now().toIso8601String(),
        },
      );

      return true;

    } catch (e) {
      AppLogger().error('Failed to handle recording failed: $e');
      return false;
    }
  }

  /// Update room recording status in appropriate collection
  Future<void> _updateRoomRecordingStatus(String roomName, String recordingStatus, Map<String, dynamic> recordingData) async {
    try {
      // Try to find the room in different collections
      final collections = ['arena_rooms', 'debate_discussion_rooms', 'discussion_rooms'];

      for (final collection in collections) {
        try {
          final result = await _appwriteService.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: collection,
            queries: [
              'equal("roomName", "$roomName")',
              'orderDesc("\$createdAt")',
              'limit(1)',
            ],
          );

          if (result.documents.isNotEmpty) {
            final roomId = result.documents.first.data['\$id'] as String;

            await _appwriteService.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: collection,
              documentId: roomId,
              data: {
                'recordingStatus': recordingStatus,
                'recordingData': jsonEncode(recordingData),
                'updatedAt': DateTime.now().toIso8601String(),
              },
            );

            AppLogger().info('Updated recording status in $collection for room: $roomName');
            return;
          }
        } catch (e) {
          // Continue to next collection if this one fails
          AppLogger().debug('Room not found in $collection: $e');
        }
      }

      AppLogger().warning('Room not found in any collection: $roomName');

    } catch (e) {
      AppLogger().error('Failed to update room recording status: $e');
    }
  }

  /// Get recording status for a room
  Future<Map<String, dynamic>?> getRecordingStatus(String roomName) async {
    try {
      final collections = ['arena_rooms', 'debate_discussion_rooms', 'discussion_rooms'];

      for (final collection in collections) {
        try {
          final result = await _appwriteService.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: collection,
            queries: [
              'equal("roomName", "$roomName")',
              'orderDesc("\$createdAt")',
              'limit(1)',
            ],
          );

          if (result.documents.isNotEmpty) {
            final room = result.documents.first.data;
            final recordingStatus = room['recordingStatus'] as String?;
            final recordingDataStr = room['recordingData'] as String?;

            Map<String, dynamic>? recordingData;
            if (recordingDataStr != null) {
              try {
                recordingData = jsonDecode(recordingDataStr) as Map<String, dynamic>;
              } catch (e) {
                AppLogger().warning('Failed to parse recording data: $e');
              }
            }

            return {
              'roomId': room['\$id'],
              'roomName': roomName,
              'collection': collection,
              'recordingStatus': recordingStatus,
              'recordingData': recordingData,
            };
          }
        } catch (e) {
          AppLogger().debug('Room not found in $collection: $e');
        }
      }

      return null;

    } catch (e) {
      AppLogger().error('Failed to get recording status: $e');
      return null;
    }
  }

  /// Process chapters asynchronously after recording completion
  void _processChaptersAsync(String playbackId) {
    // Run chapter generation in background without blocking webhook response
    Timer(const Duration(seconds: 5), () async {
      try {
        AppLogger().info('🎭 Starting async chapter generation for playback: $playbackId');
        await _chapterService.processPlaybackChapters(playbackId);
        AppLogger().info('✅ Completed async chapter generation for playback: $playbackId');
      } catch (e) {
        AppLogger().error('Failed to generate chapters asynchronously: $e');
      }
    });
  }
}