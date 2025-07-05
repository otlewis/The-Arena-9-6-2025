import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'dart:math';

import 'notification_model.dart';
import 'notification_types.dart';
import '../../services/challenge_messaging_service.dart';
import '../../services/sound_service.dart';
import '../../constants/appwrite.dart';
import '../../services/appwrite_service.dart';
import '../logging/app_logger.dart';

/// Unified notification service that orchestrates all notification types
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Existing services
  final ChallengeMessagingService _challengeService = ChallengeMessagingService();
  final SoundService _soundService = SoundService();
  final AppwriteService _appwriteService = AppwriteService();

  // Stream controllers for different notification delivery methods
  final _bannerNotificationsController = StreamController<ArenaNotification>.broadcast();
  final _toastNotificationsController = StreamController<ArenaNotification>.broadcast();
  final _notificationHistoryController = StreamController<List<ArenaNotification>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  // State management
  String? _currentUserId;
  List<ArenaNotification> _notificationHistory = [];
  bool _isInitialized = false;
  RealtimeSubscription? _notificationSubscription;

  // Stream getters
  Stream<ArenaNotification> get bannerNotifications => _bannerNotificationsController.stream;
  Stream<ArenaNotification> get toastNotifications => _toastNotificationsController.stream;
  Stream<List<ArenaNotification>> get notificationHistory => _notificationHistoryController.stream;
  Stream<int> get unreadCount => _unreadCountController.stream;

  // Getters
  List<ArenaNotification> get currentNotifications => List.unmodifiable(_notificationHistory);
  int get currentUnreadCount => _notificationHistory.where((n) => !n.isRead && n.isActive).length;
  bool get isInitialized => _isInitialized;

  /// Initialize the notification service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      AppLogger().debug('🔔 NotificationService already initialized for user: $userId');
      return;
    }

    _currentUserId = userId;
    AppLogger().debug('🔔 Initializing NotificationService for user: $userId');

    // Initialize existing challenge messaging service
    await _challengeService.initialize(userId);

    // Load notification history
    await _loadNotificationHistory();

    // Set up listeners for existing challenge system
    _setupChallengeListeners();

    // Start listening for other notification types
    await _startNotificationListening();

    _isInitialized = true;
    AppLogger().debug('🔔 ✅ NotificationService initialized successfully');
  }

  /// Load notification history from storage
  Future<void> _loadNotificationHistory() async {
    if (_currentUserId == null) return;

    try {
      AppLogger().debug('🔔 Loading notification history for user: $_currentUserId');

      // Try to load from notifications collection (if it exists)
      try {
        final response = await _appwriteService.databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'notifications',
          queries: [
            Query.equal('userId', _currentUserId!),
            Query.orderDesc('\$createdAt'),
            Query.limit(100),
          ],
        );

        _notificationHistory = response.documents
            .map((doc) => ArenaNotification.fromMap(doc.data))
            .where((notification) => !notification.isExpired)
            .toList();

        AppLogger().debug('🔔 Loaded ${_notificationHistory.length} notifications from database');
      } catch (e) {
        AppLogger().debug('🔔 Notifications collection not found, will create it');
        _notificationHistory = [];
      }

      // Update streams
      _notificationHistoryController.add(_notificationHistory);
      _unreadCountController.add(currentUnreadCount);

    } catch (e) {
      AppLogger().error('Error loading notification history: $e');
      _notificationHistory = [];
    }
  }

  /// Set up listeners for existing challenge messaging
  void _setupChallengeListeners() {
    // Listen for incoming challenges and convert to notifications
    _challengeService.incomingChallenges.listen((challengeMessage) {
      final notification = ArenaNotification.fromChallengeMessage(challengeMessage);
      handleNewNotification(notification);
    });

    // Listen for arena role invitations
    _challengeService.arenaRoleInvitations.listen((challengeMessage) {
      final notification = ArenaNotification.fromChallengeMessage(challengeMessage);
      handleNewNotification(notification);
    });

    // Listen for challenge updates
    _challengeService.challengeUpdates.listen((challengeMessage) {
      _handleChallengeUpdate(challengeMessage);
    });
  }

  /// Start listening for other notification types
  Future<void> _startNotificationListening() async {
    if (_currentUserId == null) return;

    try {
      AppLogger().debug('🔔 Starting notification subscription');

      // Subscribe to notifications collection (if it exists)
      try {
        final realtime = Realtime(_appwriteService.client);
        _notificationSubscription = realtime.subscribe([
          'databases.${AppwriteConstants.databaseId}.collections.notifications.documents'
        ]);

        _notificationSubscription!.stream.listen(
          (response) => _handleNotificationRealtimeEvent(response),
          onError: (error) => AppLogger().error('Notification subscription error: $error'),
        );

        AppLogger().debug('🔔 ✅ Notification subscription active');
      } catch (e) {
        AppLogger().debug('🔔 Notifications collection not found, notifications will be in-memory only');
      }

    } catch (e) {
      AppLogger().error('Error starting notification subscription: $e');
    }
  }

  /// Handle realtime notification events
  void _handleNotificationRealtimeEvent(RealtimeMessage response) {
    try {
      final events = response.events;
      final payload = response.payload;

      if (payload.isEmpty) return;

      final notificationData = Map<String, dynamic>.from(payload);
      final notification = ArenaNotification.fromMap(notificationData);

      // Only process notifications for current user
      if (notification.userId != _currentUserId) return;

      if (events.any((event) => event.contains('create'))) {
        handleNewNotification(notification, fromRealtime: true);
      } else if (events.any((event) => event.contains('update'))) {
        _handleNotificationUpdate(notification);
      } else if (events.any((event) => event.contains('delete'))) {
        _handleNotificationDeleted(notification);
      }

    } catch (e) {
      AppLogger().error('Error handling notification realtime event: $e');
    }
  }

  /// Handle new notification (public for integration with existing challenge system)
  void handleNewNotification(ArenaNotification notification, {bool fromRealtime = false}) {
    AppLogger().debug('🔔 New notification: ${notification.type.value} - ${notification.title}');

    // Add to history if not already there
    if (!_notificationHistory.any((n) => n.id == notification.id)) {
      _notificationHistory.insert(0, notification);
      _notificationHistoryController.add(_notificationHistory);
      _unreadCountController.add(currentUnreadCount);

      // Save to database if not from realtime
      if (!fromRealtime) {
        _saveNotification(notification);
      }
    }

    // Deliver notification based on delivery methods
    _deliverNotification(notification);
  }

  /// Deliver notification using appropriate methods
  void _deliverNotification(ArenaNotification notification) {
    final methods = notification.deliveryMethods.isNotEmpty 
        ? notification.deliveryMethods 
        : notification.defaultDeliveryMethods;

    AppLogger().debug('🔔 Delivering notification via: ${methods.map((m) => m.name).join(', ')}');

    // Handle sound
    if (methods.contains(NotificationDeliveryMethod.sound)) {
      final soundFile = notification.soundFile ?? notification.defaultSoundFile;
      _soundService.playCustomSound(soundFile);
    }

    // Handle vibration
    if (methods.contains(NotificationDeliveryMethod.vibration)) {
      // Note: Vibration will be handled in Phase 2 with proper permissions
      AppLogger().debug('🔔 Vibration requested (will implement in Phase 2)');
    }

    // Handle banner notifications
    if (methods.contains(NotificationDeliveryMethod.banner)) {
      _bannerNotificationsController.add(notification);
    }

    // Handle toast notifications  
    if (methods.contains(NotificationDeliveryMethod.inApp)) {
      _toastNotificationsController.add(notification);
    }

    // Modal notifications are handled by existing challenge system
    // Push notifications will be handled in Phase 2
  }

  /// Create and send a new notification
  Future<void> sendNotification({
    required NotificationType type,
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic> payload = const {},
    NotificationPriority priority = NotificationPriority.medium,
    DateTime? expiresAt,
    List<NotificationAction> actions = const [],
    String? imageUrl,
    String? deepLink,
    String? soundFile,
    bool enableVibration = false,
    Set<NotificationDeliveryMethod>? deliveryMethods,
  }) async {
    try {
      final notification = ArenaNotification(
        id: _generateNotificationId(),
        type: type,
        userId: userId,
        title: title,
        message: message,
        payload: payload,
        priority: priority,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        actions: actions,
        imageUrl: imageUrl,
        deepLink: deepLink,
        soundFile: soundFile,
        enableVibration: enableVibration,
        deliveryMethods: deliveryMethods ?? {},
      );

      AppLogger().debug('🔔 Sending notification: ${notification.type.value} to $userId');

      // Handle the notification
      if (userId == _currentUserId) {
        handleNewNotification(notification);
      } else {
        // Save to database for other users
        await _saveNotification(notification);
      }

    } catch (e) {
      AppLogger().error('Error sending notification: $e');
      rethrow;
    }
  }

  /// Save notification to database
  Future<void> _saveNotification(ArenaNotification notification) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'notifications',
        documentId: notification.id,
        data: notification.toMap(),
      );
      AppLogger().debug('🔔 Notification saved to database: ${notification.id}');
    } catch (e) {
      AppLogger().debug('🔔 Could not save notification to database (collection may not exist): $e');
      // Don't throw - notifications can work in-memory only
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notificationHistory.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notificationHistory[index] = _notificationHistory[index].copyWith(isRead: true);
        _notificationHistoryController.add(_notificationHistory);
        _unreadCountController.add(currentUnreadCount);

        // Update in database
        await _updateNotificationInDatabase(notificationId, {'isRead': true});
      }
    } catch (e) {
      AppLogger().error('Error marking notification as read: $e');
    }
  }

  /// Mark notification as dismissed
  Future<void> markAsDismissed(String notificationId) async {
    try {
      final index = _notificationHistory.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notificationHistory[index] = _notificationHistory[index].copyWith(isDismissed: true);
        _notificationHistoryController.add(_notificationHistory);
        _unreadCountController.add(currentUnreadCount);

        // Update in database
        await _updateNotificationInDatabase(notificationId, {'isDismissed': true});
      }
    } catch (e) {
      AppLogger().error('Error marking notification as dismissed: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      for (int i = 0; i < _notificationHistory.length; i++) {
        if (!_notificationHistory[i].isRead) {
          _notificationHistory[i] = _notificationHistory[i].copyWith(isRead: true);
        }
      }
      
      _notificationHistoryController.add(_notificationHistory);
      _unreadCountController.add(currentUnreadCount);

      AppLogger().debug('🔔 Marked all notifications as read');
    } catch (e) {
      AppLogger().error('Error marking all notifications as read: $e');
    }
  }

  /// Handle challenge message updates
  void _handleChallengeUpdate(dynamic challengeMessage) {
    final index = _notificationHistory.indexWhere((n) => n.id == challengeMessage.id);
    if (index != -1) {
      // Update notification based on challenge status
      if (challengeMessage.status == 'accepted' || challengeMessage.status == 'declined') {
        _notificationHistory[index] = _notificationHistory[index].copyWith(isRead: true);
        _notificationHistoryController.add(_notificationHistory);
        _unreadCountController.add(currentUnreadCount);
      }
    }
  }

  /// Handle notification updates
  void _handleNotificationUpdate(ArenaNotification notification) {
    final index = _notificationHistory.indexWhere((n) => n.id == notification.id);
    if (index != -1) {
      _notificationHistory[index] = notification;
      _notificationHistoryController.add(_notificationHistory);
      _unreadCountController.add(currentUnreadCount);
    }
  }

  /// Handle notification deletion
  void _handleNotificationDeleted(ArenaNotification notification) {
    _notificationHistory.removeWhere((n) => n.id == notification.id);
    _notificationHistoryController.add(_notificationHistory);
    _unreadCountController.add(currentUnreadCount);
  }

  /// Update notification in database
  Future<void> _updateNotificationInDatabase(String notificationId, Map<String, dynamic> data) async {
    try {
      await _appwriteService.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'notifications',
        documentId: notificationId,
        data: data,
      );
    } catch (e) {
      AppLogger().debug('🔔 Could not update notification in database: $e');
      // Don't throw - notifications can work in-memory only
    }
  }

  /// Generate unique notification ID
  String _generateNotificationId() {
    return 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Clear expired notifications
  Future<void> clearExpiredNotifications() async {
    try {
      final beforeCount = _notificationHistory.length;
      _notificationHistory.removeWhere((n) => n.isExpired);
      
      if (_notificationHistory.length != beforeCount) {
        _notificationHistoryController.add(_notificationHistory);
        _unreadCountController.add(currentUnreadCount);
        AppLogger().debug('🔔 Cleared ${beforeCount - _notificationHistory.length} expired notifications');
      }
    } catch (e) {
      AppLogger().error('Error clearing expired notifications: $e');
    }
  }

  /// Refresh notification history
  Future<void> refresh() async {
    AppLogger().debug('🔔 Refreshing notifications');
    await _loadNotificationHistory();
    await _challengeService.refresh();
  }

  /// Dispose the service
  void dispose() {
    AppLogger().debug('🔔 Disposing NotificationService');
    
    _notificationSubscription?.close();
    _bannerNotificationsController.close();
    _toastNotificationsController.close();
    _notificationHistoryController.close();
    _unreadCountController.close();
    
    _challengeService.dispose();
    
    _currentUserId = null;
    _notificationHistory.clear();
    _isInitialized = false;
  }
}