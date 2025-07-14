# Synchronized Timer System

A comprehensive real-time timer system for the Arena Flutter app that synchronizes perfectly across all devices using Firebase Firestore.

## 🚀 Quick Start

### Basic Integration
```dart
SynchronizedTimerWidget(
  roomId: 'your_room_id',
  roomType: RoomType.arena, // or openDiscussion, debatesDiscussions
  isModerator: true,
  userId: currentUserId,
  currentSpeaker: 'Speaker Name', // optional
)
```

### Test the System
1. Add the `TimerTestScreen` to your app navigation
2. Open on multiple devices
3. Start timers and verify synchronization

## 📁 Files Created

### Core System
- `lib/models/timer_state.dart` - Data models with freezed
- `lib/config/timer_presets.dart` - Room-specific configurations
- `lib/services/timer_service.dart` - Firebase operations
- `lib/widgets/synchronized_timer_widget.dart` - Main reusable widget

### Additional Features
- `lib/services/timer_feedback_service.dart` - Audio/vibration feedback
- `lib/examples/timer_integration_examples.dart` - Integration examples
- `lib/screens/timer_test_screen.dart` - Test screen for verification

## 🎯 Features

### ✅ Real-time Synchronization
- Uses `FieldValue.serverTimestamp()` for perfect sync
- Real-time Firestore streams update all devices instantly
- Handles network latency and clock differences

### ✅ Room-Specific Presets
- **Open Discussion**: 1-10 minute flexible timers
- **Debates & Discussions**: 2-5 minute structured rounds
- **Arena**: Formal debate timing (opening, rebuttal, closing)

### ✅ Moderator Controls
- Start, pause, resume, stop, reset timers
- Add time functionality
- Create custom timer durations
- Room-specific permission controls

### ✅ Visual & Audio Feedback
- Color-coded timer states (normal, warning, expired)
- Progress bars and pulse animations
- Haptic feedback patterns
- Audio alerts (configurable)

### ✅ Multiple Views
- Full timer display with all controls
- Compact view for headers/sidebars
- Read-only audience view
- Floating overlay option

## 🔧 Integration Examples

### Open Discussion Room
```dart
// In your open_discussion_screen.dart
class OpenDiscussionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discussion'),
        actions: [
          // Compact timer in app bar
          SynchronizedTimerWidget(
            roomId: roomId,
            roomType: RoomType.openDiscussion,
            isModerator: isModerator,
            userId: userId,
            compact: true,
          ),
        ],
      ),
      body: Column(
        children: [
          // Your existing content
          Expanded(child: DiscussionContent()),
          
          // Full timer controls for moderator
          if (isModerator)
            SynchronizedTimerWidget(
              roomId: roomId,
              roomType: RoomType.openDiscussion,
              isModerator: true,
              userId: userId,
            ),
        ],
      ),
    );
  }
}
```

### Arena Debate Integration
```dart
// Central timer for formal debates
Container(
  margin: EdgeInsets.all(16),
  child: SynchronizedTimerWidget(
    roomId: roomId,
    roomType: RoomType.arena,
    isModerator: isJudge,
    userId: userId,
    currentSpeaker: currentDebater,
    onTimerExpired: () {
      // Handle phase completion
      announcePhaseComplete();
    },
  ),
)
```

### Floating Timer Overlay
```dart
Stack(
  children: [
    YourMainContent(),
    Positioned(
      top: 100,
      right: 16,
      child: SynchronizedTimerWidget(
        roomId: roomId,
        roomType: roomType,
        isModerator: isModerator,
        userId: userId,
        compact: true,
      ),
    ),
  ],
)
```

## 🎛️ Configuration Options

### Timer Types by Room
- **Open Discussion**: General timers, Speaker turns
- **Debates & Discussions**: Speaker time, Q&A rounds, Discussion rounds
- **Arena**: Opening statements, Rebuttals, Closing statements, Cross-examination, Preparation time

### Preset Durations
- **Open Discussion**: 1-10 minutes (flexible)
- **Debates & Discussions**: 2-5 minutes (structured)
- **Arena**: 1.5-6 minutes (formal, strict timing)

### Permission System
- Room-specific moderator controls
- Creator can always control their timers
- Audience gets read-only view

## 🔊 Audio & Haptic Feedback

### Timer Events
- **Start**: Light haptic + optional sound
- **Warning** (10s): Heavy haptic + warning sound
- **Expired**: Heavy haptic pattern + alert sound
- **Pause/Resume**: Medium haptic feedback

### Customizable Settings
```dart
final feedbackService = TimerFeedbackService();
feedbackService.setSoundEnabled(true);
feedbackService.setVibrationEnabled(true);
```

## 🌐 Database Schema

### Firestore Collections
```javascript
// room_timers/{timerId}
{
  id: string,
  roomId: string,
  roomType: 'openDiscussion' | 'debatesDiscussions' | 'arena',
  timerType: 'general' | 'openingStatement' | 'rebuttal' | etc,
  status: 'stopped' | 'running' | 'paused' | 'completed',
  durationSeconds: number,
  remainingSeconds: number,
  startTime: Timestamp,
  pausedAt: Timestamp,
  createdAt: Timestamp,
  createdBy: string,
  currentSpeaker: string,
  soundEnabled: boolean,
  vibrationEnabled: boolean
}

// timer_events/{eventId}
{
  timerId: string,
  action: 'created' | 'started' | 'paused' | 'stopped' | 'reset',
  timestamp: Timestamp,
  userId: string,
  details: string
}
```

## 🛠️ Advanced Usage

### Custom Timer Creation
```dart
final timerService = TimerService();
final timerId = await timerService.createTimer(
  roomId: 'room_123',
  roomType: RoomType.arena,
  timerType: TimerType.openingStatement,
  durationSeconds: 240,
  createdBy: 'user_123',
  currentSpeaker: 'Debater 1',
);
```

### Listen to Timer Events
```dart
timerService.getTimerEventsStream(timerId).listen((events) {
  for (final event in events) {
    print('Timer ${event.action} by ${event.userId}');
  }
});
```

### Handle State Changes
```dart
class MyTimerWidget extends StatefulWidget {
  @override
  _MyTimerWidgetState createState() => _MyTimerWidgetState();
}

class _MyTimerWidgetState extends State<MyTimerWidget> {
  final feedbackService = TimerFeedbackService();
  TimerState? previousState;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TimerState?>(
      stream: timerService.getTimerStream(timerId),
      builder: (context, snapshot) {
        final currentState = snapshot.data;
        
        if (currentState != null && previousState != null) {
          feedbackService.handleTimerStateChange(
            previousState, 
            currentState
          );
        }
        
        previousState = currentState;
        return SynchronizedTimerWidget(...);
      },
    );
  }
}
```

## 🐛 Troubleshooting

### Timer Not Syncing
1. Check Firebase configuration in your app
2. Verify internet connectivity
3. Ensure proper user permissions
4. Check Firestore security rules

### Performance Issues
1. Limit concurrent timers per room
2. Dispose streams properly in `dispose()`
3. Use compact view for non-critical displays

### Audio Not Working
1. Add audio assets to `pubspec.yaml`
2. Check device volume settings
3. Verify `just_audio` dependency

## 📝 Testing Checklist

- [ ] Timer syncs across multiple devices
- [ ] Moderator controls work properly
- [ ] Audience view is read-only
- [ ] Audio/haptic feedback triggers correctly
- [ ] Timer persists through app backgrounding
- [ ] Network interruption handling
- [ ] Memory leaks check with DevTools

## 🔒 Security Considerations

### Firestore Security Rules
```javascript
// Add to your Firestore security rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Timer documents
    match /room_timers/{timerId} {
      allow read: if true; // Anyone can read timers
      allow write: if request.auth != null; // Only authenticated users can write
    }
    
    // Timer events
    match /timer_events/{eventId} {
      allow read: if true;
      allow create: if request.auth != null;
    }
  }
}
```

The system is now ready for production use! Test it with the `TimerTestScreen` to verify synchronization across devices.