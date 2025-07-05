import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import 'notification_model.dart';
import 'notification_types.dart';
import 'notification_service.dart';
import 'notification_preferences.dart';
import '../logging/app_logger.dart';
import '../../services/appwrite_service.dart';
import '../../constants/appwrite.dart';

/// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger().debug('🔔 📱 Handling background message: ${message.messageId}');
  
  // Initialize Firebase if needed
  // await Firebase.initializeApp();
  
  // Handle the message in background
  await PushNotificationService._handleBackgroundMessage(message);
}

/// Service for handling Firebase Cloud Messaging push notifications
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AppwriteService _appwriteService = AppwriteService();
  final NotificationPreferencesService _preferencesService = NotificationPreferencesService();
  
  String? _fcmToken;
  String? _currentUserId;
  bool _isInitialized = false;
  
  // Stream controllers for push notification events
  final _tokenUpdatedController = StreamController<String>.broadcast();
  final _messageReceivedController = StreamController<RemoteMessage>.broadcast();
  
  // Getters
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  Stream<String> get tokenUpdated => _tokenUpdatedController.stream;
  Stream<RemoteMessage> get messageReceived => _messageReceivedController.stream;

  /// Initialize push notification service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      AppLogger().debug('🔔 📱 PushNotificationService already initialized for user: $userId');
      return;
    }

    _currentUserId = userId;
    AppLogger().debug('🔔 📱 Initializing PushNotificationService for user: $userId');

    try {
      // Request notification permissions
      await _requestPermissions();
      
      // Get FCM token
      await _getFcmToken();
      
      // Set up message handlers
      _setupMessageHandlers();
      
      // Listen for token refreshes
      _setupTokenRefreshListener();
      
      // Register device token with backend
      if (_fcmToken != null) {
        await _registerDeviceToken();
      }
      
      _isInitialized = true;
      AppLogger().debug('🔔 📱 ✅ PushNotificationService initialized successfully');
      
    } catch (e) {
      AppLogger().error('Error initializing PushNotificationService: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      AppLogger().debug('🔔 📱 Requesting notification permissions');
      
      // Request Firebase Messaging permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger().debug('🔔 📱 ✅ Firebase notification permissions granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger().debug('🔔 📱 ⚠️ Firebase notification permissions granted (provisional)');
      } else {
        AppLogger().warning('🔔 📱 ❌ Firebase notification permissions denied');
      }

      // Request system notification permissions
      final systemPermission = await Permission.notification.request();
      if (systemPermission.isGranted) {
        AppLogger().debug('🔔 📱 ✅ System notification permissions granted');
      } else {
        AppLogger().warning('🔔 📱 ❌ System notification permissions denied');
      }

    } catch (e) {
      AppLogger().error('Error requesting notification permissions: $e');
    }
  }

  /// Get FCM token
  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        AppLogger().debug('🔔 📱 FCM token obtained: ${_fcmToken!.substring(0, 20)}...');
      } else {
        AppLogger().warning('🔔 📱 Failed to obtain FCM token');
      }
    } catch (e) {
      AppLogger().error('Error getting FCM token: $e');
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger().debug('🔔 📱 Received foreground message: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // Handle when user taps notification to open app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger().debug('🔔 📱 App opened from notification: ${message.messageId}');
      _handleNotificationTap(message);
    });

    // Handle initial message when app is opened from terminated state
    _handleInitialMessage();
  }

  /// Handle initial message when app opens from terminated state
  Future<void> _handleInitialMessage() async {
    try {
      final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger().debug('🔔 📱 App opened from terminated state via notification: ${initialMessage.messageId}');
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      AppLogger().error('Error handling initial message: $e');
    }
  }

  /// Set up token refresh listener
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      AppLogger().debug('🔔 📱 FCM token refreshed: ${newToken.substring(0, 20)}...');
      _fcmToken = newToken;
      _tokenUpdatedController.add(newToken);
      
      // Re-register with backend
      if (_currentUserId != null) {
        _registerDeviceToken();
      }
    });
  }

  /// Register device token with backend
  Future<void> _registerDeviceToken() async {
    if (_fcmToken == null || _currentUserId == null) return;

    try {
      AppLogger().debug('🔔 📱 Registering device token with backend');
      
      // Create or update device token document
      final deviceData = {
        'userId': _currentUserId!,
        'fcmToken': _fcmToken!,
        'platform': defaultTargetPlatform.name,
        'lastUpdated': DateTime.now().toIso8601String(),
        'isActive': true,
      };

      // Try to create/update device token in database
      try {
        await _appwriteService.databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'device_tokens',
          documentId: 'device_$_currentUserId', // Use consistent ID per user
          data: deviceData,
        );
        AppLogger().debug('🔔 📱 ✅ Device token registered successfully');
      } catch (e) {
        // If document exists, update it
        try {
          await _appwriteService.databases.updateDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: 'device_tokens',
            documentId: 'device_$_currentUserId',
            data: deviceData,
          );
          AppLogger().debug('🔔 📱 ✅ Device token updated successfully');
        } catch (updateError) {
          AppLogger().warning('🔔 📱 Could not register device token (collection may not exist): $updateError');
        }
      }

    } catch (e) {
      AppLogger().error('Error registering device token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger().debug('🔔 📱 Processing foreground message: ${message.notification?.title}');
    
    // Convert to ArenaNotification and pass to NotificationService
    final arenaNotification = _convertToArenaNotification(message);
    if (arenaNotification != null) {
      final notificationService = NotificationService();
      notificationService.handleNewNotification(arenaNotification, fromRealtime: true);
    }
    
    _messageReceivedController.add(message);
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    AppLogger().debug('🔔 📱 Processing notification tap: ${message.notification?.title}');
    
    // Handle deep linking from notification data
    final data = message.data;
    if (data.containsKey('deepLink')) {
      final deepLink = data['deepLink'] as String;
      AppLogger().debug('🔔 📱 Deep link from notification: $deepLink');
      // TODO: Implement deep link navigation
    }
    
    // Mark as read if notification ID is provided
    if (data.containsKey('notificationId')) {
      final notificationId = data['notificationId'] as String;
      final notificationService = NotificationService();
      notificationService.markAsRead(notificationId);
    }
  }

  /// Handle background messages (static method for top-level function)
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    AppLogger().debug('🔔 📱 Processing background message: ${message.notification?.title}');
    
    // Store message for when app resumes
    // Note: In background, we have limited capabilities
    // Main handling will occur when app is reopened
  }

  /// Convert RemoteMessage to ArenaNotification
  ArenaNotification? _convertToArenaNotification(RemoteMessage message) {
    try {
      final data = message.data;
      final notification = message.notification;
      
      if (notification == null) return null;
      
      // Extract notification type from data
      final typeString = data['type'] ?? 'system_announcement';
      final type = NotificationType.fromString(typeString);
      
      // Extract priority
      final priorityValue = int.tryParse(data['priority'] ?? '3') ?? 3;
      final priority = NotificationPriority.fromInt(priorityValue);
      
      // Create ArenaNotification
      return ArenaNotification(
        id: data['notificationId'] ?? 'push_${message.messageId}',
        type: type,
        userId: _currentUserId ?? '',
        title: notification.title ?? 'Notification',
        message: notification.body ?? '',
        payload: Map<String, dynamic>.from(data),
        priority: priority,
        createdAt: DateTime.now(),
        imageUrl: notification.android?.imageUrl ?? notification.apple?.imageUrl,
        deepLink: data['deepLink'],
        deliveryMethods: {NotificationDeliveryMethod.push},
      );
    } catch (e) {
      AppLogger().error('Error converting RemoteMessage to ArenaNotification: $e');
      return null;
    }
  }

  /// Send push notification to specific user
  Future<void> sendPushNotification({
    required String targetUserId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic> data = const {},
    String? imageUrl,
    NotificationPriority priority = NotificationPriority.medium,
  }) async {
    try {
      AppLogger().debug('🔔 📱 Sending push notification to user: $targetUserId');
      
      // Get user's FCM token
      final userToken = await _getUserFcmToken(targetUserId);
      if (userToken == null) {
        AppLogger().warning('🔔 📱 No FCM token found for user: $targetUserId');
        return;
      }
      
      // Check user's notification preferences
      if (!await _shouldSendPushNotification(targetUserId, type, priority)) {
        AppLogger().debug('🔔 📱 Push notification blocked by user preferences');
        return;
      }
      
      // Prepare notification payload
      final notificationData = <String, String>{
        'type': type.value,
        'priority': priority.value.toString(),
        'notificationId': 'push_${DateTime.now().millisecondsSinceEpoch}',
      };
      
      // Add additional data as strings
      data.forEach((key, value) {
        notificationData[key] = value.toString();
      });
      
      // Create platform-specific payloads (currently unused)
      // final androidConfig = AndroidConfig(
      //   notification: AndroidNotification(
      //     title: title,
      //     body: body,
      //     imageUrl: imageUrl,
      //     priority: _getAndroidPriority(priority),
      //     channelId: _getChannelId(type),
      //   ),
      //   priority: AndroidMessagePriority.high,
      //   data: notificationData,
      // );
      
      // final apnsConfig = ApnsConfig(
      //   payload: ApnsPayload(
      //     aps: Aps(
      //       alert: ApsAlert(title: title, body: body),
      //       badge: 1,
      //       sound: 'default',
      //     ),
      //   ),
      //   headers: {
      //     'apns-priority': '10',
      //     'apns-push-type': 'alert',
      //   },
      // );
      
      // Send via Firebase Admin SDK (would need server-side implementation)
      // For now, log the notification details
      AppLogger().debug('🔔 📱 Push notification prepared for: $targetUserId');
      AppLogger().debug('🔔 📱 Title: $title');
      AppLogger().debug('🔔 📱 Body: $body');
      AppLogger().debug('🔔 📱 Type: ${type.value}');
      AppLogger().debug('🔔 📱 Priority: ${priority.value}');
      
      // TODO: Implement actual sending via server-side Firebase Admin SDK
      // This would typically be done through your backend API
      
    } catch (e) {
      AppLogger().error('Error sending push notification: $e');
      rethrow;
    }
  }

  /// Get user's FCM token from database
  Future<String?> _getUserFcmToken(String userId) async {
    try {
      final response = await _appwriteService.databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'device_tokens',
        documentId: 'device_$userId',
      );
      
      final data = response.data;
      final isActive = data['isActive'] as bool? ?? false;
      
      if (isActive) {
        return data['fcmToken'] as String?;
      } else {
        AppLogger().debug('🔔 📱 Device token for user $userId is inactive');
        return null;
      }
      
    } catch (e) {
      AppLogger().debug('🔔 📱 Could not get FCM token for user $userId: $e');
      return null;
    }
  }

  /// Check if push notification should be sent based on user preferences
  Future<bool> _shouldSendPushNotification(
    String userId, 
    NotificationType type, 
    NotificationPriority priority
  ) async {
    try {
      // For other users, assume they want notifications
      // In a real implementation, you'd fetch their preferences from the database
      if (userId != _currentUserId) {
        return true;
      }
      
      // Check current user's preferences
      if (!_preferencesService.isLoaded) {
        await _preferencesService.loadPreferences();
      }
      
      final prefs = _preferencesService.preferences;
      
      // Check global settings
      if (!prefs.enablePushNotifications || !prefs.enableNotifications) {
        return false;
      }
      
      // Check do not disturb
      if (prefs.isInDoNotDisturbPeriod) {
        // Only allow urgent notifications during DND
        return priority == NotificationPriority.urgent;
      }
      
      // Check type-specific settings
      if (!prefs.isTypeEnabled(type)) {
        return false;
      }
      
      // Check priority requirements
      if (!prefs.meetsPriorityRequirement(type, priority)) {
        return false;
      }
      
      return true;
      
    } catch (e) {
      AppLogger().error('Error checking push notification preferences: $e');
      return true; // Default to allowing notifications
    }
  }



  /// Unregister device token when user logs out
  Future<void> unregisterDevice() async {
    if (_currentUserId == null) return;
    
    try {
      AppLogger().debug('🔔 📱 Unregistering device for user: $_currentUserId');
      
      await _appwriteService.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'device_tokens',
        documentId: 'device_$_currentUserId',
        data: {'isActive': false},
      );
      
      AppLogger().debug('🔔 📱 ✅ Device unregistered successfully');
    } catch (e) {
      AppLogger().debug('🔔 📱 Could not unregister device: $e');
    }
  }

  /// Dispose the service
  void dispose() {
    AppLogger().debug('🔔 📱 Disposing PushNotificationService');
    
    _tokenUpdatedController.close();
    _messageReceivedController.close();
    
    _fcmToken = null;
    _currentUserId = null;
    _isInitialized = false;
  }
}

// Platform-specific classes (these would be imported from firebase_messaging)
class AndroidConfig {
  final AndroidNotification? notification;
  final AndroidMessagePriority? priority;
  final Map<String, String>? data;
  
  AndroidConfig({this.notification, this.priority, this.data});
}

class AndroidNotification {
  final String? title;
  final String? body;
  final String? imageUrl;
  final AndroidNotificationPriority? priority;
  final String? channelId;
  
  AndroidNotification({
    this.title,
    this.body,
    this.imageUrl,
    this.priority,
    this.channelId,
  });
}

enum AndroidNotificationPriority {
  minPriority,
  lowPriority,
  defaultPriority,
  highPriority,
  maxPriority,
}

enum AndroidMessagePriority { normal, high }

class ApnsConfig {
  final ApnsPayload? payload;
  final Map<String, String>? headers;
  
  ApnsConfig({this.payload, this.headers});
}

class ApnsPayload {
  final Aps? aps;
  
  ApnsPayload({this.aps});
}

class Aps {
  final ApsAlert? alert;
  final int? badge;
  final String? sound;
  
  Aps({this.alert, this.badge, this.sound});
}

class ApsAlert {
  final String? title;
  final String? body;
  
  ApsAlert({this.title, this.body});
}