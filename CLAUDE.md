# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Arena is a Flutter application for real-time debates and discussions with multiple integrated systems:
1. **Arena System**: Challenge-based 1v1 debates with judges and scoring
2. **Debates & Discussions**: Open discussion rooms with moderator controls and speaker panels
3. **Instant Messaging**: Private messaging between users using Appwrite backend
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

### LiveKit Server
```bash
# IMPORTANT: ALWAYS deploy LiveKit to the Linode server (172.236.109.9)
# NEVER run LiveKit locally - it must be accessible to all beta testers
# Server location: /opt/livekit-arena/
# Deploy with: ./fix-livekit-config-v2.sh or ./deploy-livekit-linode.sh
```

## Architecture Overview

### State Management
- **Riverpod** for all state management
- Providers are generated using `riverpod_generator`
- Key providers: `arenaProvider`, `arenaStateProvider`, `userProfileProvider`

### Service Layer Pattern
All external integrations go through service classes:
- `AppwriteService` - Backend database, auth, storage (singleton pattern)
- `LiveKitService` - Real-time voice/video communication with WebRTC
- `ChallengeMessagingService` - Challenge notifications and messaging
- `AppwriteService` - Instant messaging and data persistence
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
- LiveKit for real-time voice/video communication
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

### LiveKit Voice/Video System
- **WebRTC-based**: Industry-standard real-time communication protocol
- **Automatic Fallback**: Graceful degradation if voice/video fails
- **Role-based Permissions**: Different audio/video capabilities per user role
- **Speaking Detection**: Real-time audio level monitoring and speaking indicators
- **Memory Management**: Automatic cleanup of tracks and connections
- **Cloud Infrastructure**: Scalable SFU (Selective Forwarding Unit) architecture

### Debates & Discussions Room
- **Floating Speakers Panel**: Always show 7 slots (1 moderator + 6 speakers)
- **Hand-raising Flow**: audience → pending → speaker (requires moderator approval)
- **Role Transitions**: Keep users visible in audience when pending
- **Room Ending**: Must navigate ALL users out when moderator ends room

### Instant Messaging System
- **Appwrite Integration**: Database-backed messaging with real-time subscriptions
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

### Room Type Collections - IMPORTANT DISTINCTION:
- `discussion_rooms` - **Open Discussion rooms** (moderator + speakers + audience)
- `room_participants` - **Open Discussion participants** with roles
- `debate_discussion_rooms` - **Debates & Discussions rooms** (structured debates)
- `debate_discussion_participants` - **Debates & Discussions participants** with roles

### Other Collections
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
2. **Always** handle LiveKit initialization failures gracefully - room should work without voice
3. **Check** for document_not_found errors when joining rooms
4. **Use** withValues() instead of deprecated withOpacity()
5. **Avoid** using BuildContext across async gaps without mounted checks
6. **Dispose** timer subscriptions properly to prevent memory leaks
7. **Handle** instant messaging initialization separately from voice/video
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
- **ALWAYS deploy LiveKit to the Linode server (172.236.109.9) - NEVER run LiveKit locally**
  - LiveKit server must be accessible to all beta testers
  - Local LiveKit instances won't work for production testing
  - All LiveKit configurations should be deployed to `/opt/livekit-arena/` on the server
  - Use SSH key authentication or password to deploy: `ssh root@172.236.109.9`

## Appwrite API Deprecation Warnings (Info Only)

### Current Status (January 2025)
The Appwrite Flutter SDK v18.0.0 shows deprecation warnings for methods like:
- `listDocuments` → `TablesDB.listRows`
- `getDocument` → `TablesDB.getRow` 
- `createDocument` → `TablesDB.createRow`
- `updateDocument` → `TablesDB.updateRow`
- `deleteDocument` → `TablesDB.deleteRow`

**IMPORTANT**: These warnings are premature. The TablesDB API is not yet available in the Flutter SDK v18.0.0, despite the deprecation messages. The current document-based methods still work correctly and should continue to be used until TablesDB is actually implemented in the Flutter SDK.

### When to Migrate
- Monitor Appwrite Flutter SDK releases for TablesDB support
- Only migrate once TablesDB methods are confirmed available in the SDK
- Test thoroughly as this will be a major API change
- The migration should maintain all current functionality while updating to the new relational model

### Migration Preparation
- All database calls are centralized in `AppwriteService`
- Service layer abstraction makes future migration easier
- Current method names map directly to TablesDB equivalents
- Real-time subscriptions will also need updates

## New Feature Integration Guidelines

### Instant Messaging
- Initialize messaging service after successful authentication
- Use Appwrite real-time subscriptions for message delivery
- Handle message persistence in Appwrite collections
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
- livekit-metrics: Voice/video SDK performance monitoring

### Claude Code Workflows

#### Pre-Launch Quality Assurance
"Analyze Arena's current state and identify any launch blockers"

#### Performance Optimization  
"Optimize Arena for 10,000+ concurrent users"

#### Bug Triage and Fixing
"Fix the most critical Arena bugs blocking launch"