# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Arena is a Flutter application for real-time debates and discussions with two main systems:
1. **Arena System**: Challenge-based 1v1 debates with judges and scoring
2. **Debates & Discussions**: Open discussion rooms with moderator controls and speaker panels

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
- `FirebaseService` - Additional backend services
- Services use dependency injection via `get_it`

### Real-time Updates
- Appwrite realtime subscriptions for database changes
- Pattern: Subscribe in `initState/onMount`, update local state, dispose properly
- Critical for: participant lists, room status, speaker requests

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
- `debate_discussion_rooms` - Open discussion rooms
- `debate_discussion_participants` - Participant tracking with roles
- `challenges` - Debate challenges between users

### Key Indexes
- Most collections indexed on `userId`, `status`, `createdAt`
- Participants indexed on `roomId` + `userId` for uniqueness

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

## Performance Considerations
- Limit Firestore queries with proper indexes
- Use pagination for large lists (not yet implemented everywhere)
- Cache user profiles to avoid repeated lookups
- Dispose subscriptions properly to prevent memory leaks

## Development Guidelines
- Never change the UI layout and design of the code when fixing issues/errors
- Never change the features of this app