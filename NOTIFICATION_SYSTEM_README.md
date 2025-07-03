# Arena Notification System

A comprehensive real-time notification system for the Arena debate app, featuring in-app notifications, push notifications, user preferences, scheduling, and analytics.

## 🚀 Features

### Phase 1: Enhanced In-App System ✅
- **Unified NotificationService** - Orchestrates all notification types
- **Notification Center** - History panel with badge counts
- **Banner Notifications** - Slide-down notifications with auto-dismiss
- **User Preferences** - Granular settings for sounds, vibration, and types
- **Notification Bell** - App bar widget with unread count

### Phase 2: Push Notifications ✅
- **Firebase Cloud Messaging** - Offline push notifications
- **Device Token Management** - Automatic registration and updates
- **Background Handlers** - Process notifications when app is closed
- **Rich Notifications** - Actions, images, and custom payloads

### Phase 3: Advanced Features ✅
- **Notification Templates** - Pre-built templates for common use cases
- **Scheduling System** - Schedule notifications for future delivery
- **Smart Analytics** - Track engagement and generate insights
- **Batching & Grouping** - Efficient notification management

## 📁 Project Structure

```
lib/core/notifications/
├── notifications.dart              # Main export file
├── notification_types.dart         # Enums and types
├── notification_model.dart         # Core notification model
├── notification_service.dart       # Main notification service
├── notification_preferences.dart   # User preferences
├── push_notification_service.dart  # FCM integration
├── notification_templates.dart     # Pre-built templates
├── notification_scheduler.dart     # Scheduling system
├── notification_analytics.dart     # Analytics and insights
└── widgets/
    ├── notification_center.dart    # History panel UI
    ├── notification_banner.dart    # Banner notifications
    ├── notification_bell.dart      # App bar bell widget
    └── notification_settings_screen.dart # Settings UI
```

## 🔧 Integration Guide

### 1. Basic Setup

The notification system is already integrated into your `main.dart`. The services are registered in the service locator and initialized on app startup.

```dart
import 'package:arena/core/notifications/notifications.dart';

// Services are automatically available via GetIt
final notificationService = getIt<NotificationService>();
final pushService = getIt<PushNotificationService>();
```

### 2. Adding Notification Bell to App Bar

```dart
AppBar(
  title: Text('Arena'),
  actions: [
    NotificationBell(), // Shows notification center on tap
  ],
)
```

### 3. Sending Notifications

#### Using Templates (Recommended)
```dart
// Challenge invitation
await notificationService.sendChallengeInvitation(
  challengerId: 'user123',
  challengedId: 'user456',
  challengerName: 'John Doe',
  topic: 'Climate Change',
  position: 'affirmative',
);

// Arena role invitation
await notificationService.sendArenaRoleInvitation(
  userId: 'user456',
  role: 'judge',
  arenaId: 'arena123',
  topic: 'AI Ethics',
  inviterName: 'Jane Smith',
);

// Achievement
await notificationService.sendAchievement(
  userId: 'user123',
  achievementId: 'first_win',
  title: 'First Victory!',
  description: 'You won your first debate',
  points: 100,
);
```

#### Custom Notifications
```dart
await notificationService.sendNotification(
  type: NotificationType.systemAnnouncement,
  userId: 'user123',
  title: 'System Maintenance',
  message: 'Arena will be offline for maintenance at 2 AM UTC',
  priority: NotificationPriority.medium,
  deliveryMethods: {
    NotificationDeliveryMethod.banner,
    NotificationDeliveryMethod.push,
  },
);
```

### 4. Scheduling Notifications

```dart
final scheduler = NotificationScheduler();

// Vote reminder
await scheduler.scheduleVoteReminder(
  userId: 'user123',
  arenaId: 'arena456',
  topic: 'Future of AI',
  arenaEndTime: DateTime.now().add(Duration(hours: 2)),
  reminderBefore: Duration(minutes: 10),
);

// Follow-up reminder
await scheduler.scheduleFollowUpReminder(
  userId: 'user123',
  challengeId: 'challenge789',
  challengerName: 'John Doe',
  topic: 'Space Exploration',
  followUpAfter: Duration(hours: 12),
);
```

### 5. User Preferences

```dart
// Open settings screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NotificationSettingsScreen(),
  ),
);

// Check preferences programmatically
final prefsService = NotificationPreferencesService();
final prefs = prefsService.preferences;

if (prefs.isTypeEnabled(NotificationType.challenge)) {
  // Send challenge notification
}
```

### 6. Analytics and Insights

```dart
final analytics = NotificationAnalytics();

// Track events
analytics.trackEvent(
  notificationId: 'notif123',
  userId: 'user123',
  type: NotificationType.challenge,
  eventType: NotificationEventType.opened,
);

// Get user stats
final stats = analytics.getUserStats('user123');
print('Open rate: ${stats.openRate}');

// Generate insights
final insights = analytics.generateInsights('user123');
for (final insight in insights) {
  print('${insight.title}: ${insight.description}');
}
```

## 🎨 Notification Types

The system supports these notification types:

- **challenge** - Debate challenges between users
- **arenaRole** - Judge/moderator invitations
- **arenaStarted** - Arena debate has begun
- **arenaEnded** - Arena debate finished
- **tournamentInvite** - Tournament invitations
- **friendRequest** - Social connections
- **mention** - User mentions in chat
- **achievement** - Badges/accomplishments
- **systemAnnouncement** - App updates/news
- **roomChat** - Chat messages in rooms
- **voteReminder** - Remind judges to vote
- **followUp** - Follow up on expired invitations

## 🔔 Notification Priorities

- **Urgent** (8) - Modal + Push + Sound + Vibration (Arena roles, urgent reminders)
- **High** (5) - Banner + Push + Sound (Challenges, important updates)
- **Medium** (3) - Banner + Push (General notifications)
- **Low** (1) - In-app only (Achievements, social updates)

## 📱 Delivery Methods

- **Modal** - Full-screen overlay (urgent notifications)
- **Banner** - Slide-down from top (high/medium priority)
- **In-App** - Notification center only (low priority)
- **Push** - System notifications (when app closed)
- **Sound** - Audio alerts (configurable per type)
- **Vibration** - Haptic feedback (urgent notifications)

## ⚙️ User Preferences

Users can control:
- **Global Settings** - Master switches for notifications, sounds, vibration
- **Do Not Disturb** - Quiet hours with customizable time ranges
- **Per-Type Settings** - Enable/disable, sound, vibration for each type
- **Priority Filtering** - Minimum priority level per type

## 📊 Analytics Features

- **Engagement Tracking** - Open rates, action rates, dismissal rates
- **Performance Metrics** - Delivery rates, response times
- **User Insights** - Personalized recommendations
- **Trend Analysis** - Engagement patterns over time
- **A/B Testing** - Compare notification strategies

## 🔐 Privacy & Data

- Events are stored locally and cleaned up after 30 days
- Analytics data can be exported for compliance
- User preferences are stored locally with SharedPreferences
- Push tokens are managed securely through Firebase

## 🧪 Testing & Demo

Use the demo screen to test all features:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NotificationSystemDemo(),
  ),
);
```

## 🚀 Next Steps

### Backend Integration
1. **Server-Side FCM** - Implement Firebase Admin SDK on your backend
2. **Database Collections** - Create Appwrite collections for notifications and device tokens
3. **API Endpoints** - Add notification sending endpoints to your API

### Production Considerations
1. **Rate Limiting** - Prevent notification spam
2. **Batch Processing** - Efficient bulk notifications
3. **Monitoring** - Track system performance and errors
4. **Compliance** - GDPR, privacy regulations

### Advanced Features
1. **Rich Media** - Images, videos in notifications
2. **Interactive Actions** - Reply, snooze, custom actions
3. **Smart Scheduling** - ML-based optimal timing
4. **Cross-Platform** - Web push notifications

## 📚 API Reference

### NotificationService
- `initialize(userId)` - Initialize for user
- `sendNotification()` - Send custom notification
- `markAsRead(id)` - Mark as read
- `markAllAsRead()` - Mark all as read
- Templates: `sendChallengeInvitation()`, `sendArenaRoleInvitation()`, etc.

### NotificationScheduler
- `start()` / `stop()` - Control scheduler
- `scheduleNotification()` - Schedule custom notification
- `scheduleVoteReminder()` - Schedule vote reminder
- `cancelScheduledNotification()` - Cancel by ID

### NotificationAnalytics
- `trackEvent()` - Track user interaction
- `getUserStats()` - Get user metrics
- `generateInsights()` - Get recommendations
- `exportData()` - Export analytics data

---

**The notification system is now fully integrated and ready to enhance your Arena debate app with comprehensive real-time notifications!** 🎉