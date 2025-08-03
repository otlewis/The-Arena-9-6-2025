# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Arena is a Flutter application for real-time debates and discussions with multiple integrated systems:
1. **Arena System**: Challenge-based 1v1 debates with judges and scoring
2. **Debates & Discussions**: Open discussion rooms with moderator controls and speaker panels
3. **Instant Messaging**: Private messaging between users using Agora Chat SDK
4. **Timer System**: Synchronized timers across all participants with audio feedback
5. **Notification System**: Real-time notifications for challenges, messages, and room events

## Essential Commands

### Development
```bash
flutter pub get              # Install dependencies
flutter run                  # Run on connected device/emulator
flutter run -d chrome        # Run on web browser
flutter analyze              # Check for code issues (must be 0)
flutter test                 # Run all tests
flutter test --coverage      # Run tests with coverage report
flutter build apk            # Build Android APK
flutter build ios            # Build iOS app
```

### Code Generation
```bash
flutter pub run build_runner build --delete-conflicting-outputs  # Generate code for freezed, json_serializable, riverpod_generator
```

### Agora Token Server (if needed)
```bash
cd agora_token_server
npm install
npm start                    # Runs on port 3000
```

## Architecture Overview

### State Management
- **Riverpod** for all state management
- Providers are generated using `riverpod_generator`
- Key providers: `arenaProvider`, `arenaStateProvider`, `userProfileProvider`

### Service Layer Pattern
All external integrations go through service classes:
- `AppwriteService` - Backend database, auth, storage (singleton pattern)
- `AgoraService` - Voice chat integration
- `AgoraChatService` - Instant messaging via Agora Chat SDK
- `AgoraInstantMessagingService` - Extended IM functionality with conversation management
- `FirebaseService` - Additional backend services
- `TimerService` - Firebase-based timer synchronization
- `AppwriteTimerService` - Appwrite-based timer implementation
- `ChallengeMessagingService` - Challenge notifications and messaging
- `SoundService` - Audio feedback and sound effects
- Services use dependency injection via `get_it`

### Real-time Updates
- Appwrite realtime subscriptions for database changes
- Pattern: Subscribe in `initState/onMount`, update local state, dispose properly
- Critical for: participant lists, room status, speaker requests, timer sync, instant messages
- Agora Chat SDK for instant message delivery
- Firebase Realtime Database for timer synchronization

### Feature Structure
```
lib/features/[feature_name]/
├── models/      # Data models (use freezed for immutability)
├── providers/   # Riverpod state management
├── screens/     # UI screens
├── services/    # Feature-specific services
└── widgets/     # Feature-specific widgets
```

## Critical Implementation Details

### Debates & Discussions Room
- **Floating Speakers Panel**: Always show 7 slots (1 moderator + 6 speakers)
- **Hand-raising Flow**: audience → pending → speaker (requires moderator approval)
- **Role Transitions**: Keep users visible in audience when pending
- **Room Ending**: Must navigate ALL users out when moderator ends room

### Instant Messaging System
- **Agora Chat Integration**: Uses same App ID as RTC for unified ecosystem
- **Message Deduplication**: Prevents duplicate messages with unique IDs
- **Unread Counts**: Real-time tracking of unread messages per conversation
- **Floating Widget**: Always accessible IM interface with badge notifications

### Timer System
- **Dual Implementation**: Both Firebase and Appwrite backends supported
- **Audio Feedback**: 30-second warning (30sec.mp3), expiration (arenazero.mp3)
- **Server Time Sync**: Calculates offset for accurate synchronization
- **Offline Support**: Caches state and syncs when connection restored
- **Room Types**: Different timer configs for Arena, Debates & Discussions, Open rooms

### Pixel Overflow Prevention
- Use responsive sizing: `screenWidth < 360 ? smallSize : normalSize`
- Floor calculations for grid layouts: `(availableWidth / 3).floor().toDouble()`
- Test on small Android devices (pixel overflow common issue)

### Async Safety
- Always check `mounted` before `setState`
- Capture `Navigator` reference before async gaps
- Use `_isDisposing` flag in dispose methods

### Real-time Participant Management
```dart
// Roles: 'moderator', 'speaker', 'pending', 'audience'
// Always update via updateDebateDiscussionParticipantRole()
// UI updates automatically via real-time subscriptions
```

## Appwrite Collections

### Primary Collections
- `users` - User profiles with social links
- `arena_rooms` - Challenge-based debate rooms
- `arena_participants` - Arena participant tracking
- `arena_judgments` - Judge scoring for arena debates
- `debate_discussion_rooms` - Open discussion rooms
- `debate_discussion_participants` - Participant tracking with roles
- `challenges` - Debate challenges between users
- `challenge_messages` - Challenge notifications and instant messages
- `instant_messages` - Private messages between users
- `room_hand_raises` - Hand-raise requests in discussion rooms
- `timers` - Server-controlled timer states
- `timer_events` - Timer action audit trail
- `timer_configs` - Reusable timer configurations (optional)

### Key Indexes
- Most collections indexed on `userId`, `status`, `createdAt`
- Participants indexed on `roomId` + `userId` for uniqueness
- Instant messages indexed on `senderId`, `receiverId`, `conversationId`
- Challenge messages indexed on `challengerId`, `challengedId`, `status`
- Timers indexed on `roomId` + `roomType` for uniqueness

## Testing Requirements
- Run `flutter analyze` before EVERY commit - must show 0 issues
- Test on both iOS and Android for UI layouts
- Verify real-time updates work across multiple devices
- Check for setState after dispose errors

## Common Pitfalls to Avoid
1. **Never** auto-approve speaker requests - always require moderator action
2. **Always** handle Agora initialization failures gracefully - room should work without voice
3. **Check** for document_not_found errors when joining rooms
4. **Use** withValues() instead of deprecated withOpacity()
5. **Avoid** using BuildContext across async gaps without mounted checks
6. **Dispose** timer subscriptions properly to prevent memory leaks
7. **Handle** Agora Chat SDK initialization separately from RTC
8. **Prevent** duplicate instant messages with proper deduplication
9. **Test** timer sync on multiple devices with different network conditions
10. **Check** audio permissions before playing timer sounds

## Performance Considerations
- Limit Firestore queries with proper indexes
- Use pagination for large lists (not yet implemented everywhere)
- Cache user profiles to avoid repeated lookups
- Dispose subscriptions properly to prevent memory leaks
- Batch instant message updates to reduce UI rebuilds
- Use message deduplication to prevent duplicate processing
- Implement exponential backoff for failed timer sync attempts
- Cache timer configurations to reduce database queries
- Optimize audio file loading with preloading for timer sounds

## Development Guidelines
- Never change the UI layout and design of the code when fixing issues/errors
- Never change the features of this app
- **DO NOT commit code unless explicitly asked by the user**

## New Feature Integration Guidelines

### Instant Messaging
- Initialize Agora Chat SDK after successful authentication
- Use the same Agora App ID for both RTC and Chat SDKs
- Handle message persistence in both Agora Chat and Appwrite
- Show unread counts in the floating IM widget

### Timer Integration
- Choose between Firebase or Appwrite timer service based on requirements
- Always preload timer audio files on app startup
- Handle network disconnections gracefully with local timer fallback
- Sync timer state when users join mid-session

### Notification Bells
- Use `ChallengeBell` widget for challenge notifications
- Use `InstantMessageBell` widget for IM notifications
- Animate bells on new notifications (shake animation)
- Clear notification counts when messages are read

## MCP Integration for Arena Development

### Available MCP Tools
- arena-analytics: Real-time app performance and user behavior data
- arena-launch: Launch readiness assessment and critical flow testing
- appwrite-data: Direct access to Arena collections for analysis
- agora-metrics: Voice/chat SDK performance monitoring

### Claude Code Workflows

#### Pre-Launch Quality Assurance
"Analyze Arena's current state and identify any launch blockers"

#### Performance Optimization  
"Optimize Arena for 10,000+ concurrent users"

#### Bug Triage and Fixing
"Fix the most critical Arena bugs blocking launch"