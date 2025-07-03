# Architecture Documentation

## Overview

Arena is built using a modern Flutter architecture that emphasizes modularity, testability, and maintainability. The application follows clean architecture principles with clear separation of concerns.

## Core Architectural Principles

### 1. Feature-First Architecture
The codebase is organized by features rather than technical layers, making it easier to locate and modify functionality.

```
lib/
├── core/           # Shared utilities and infrastructure
├── features/       # Feature-specific modules
│   └── arena/      # Arena debate functionality
├── models/         # Global data models
├── screens/        # Application screens
├── services/       # Business logic services
└── widgets/        # Reusable UI components
```

### 2. State Management with Riverpod
- **Providers**: Manage application state reactively
- **State Notifiers**: Handle complex state mutations
- **Consumer Widgets**: Reactive UI updates
- **Family Providers**: Parameterized state management

### 3. Dependency Injection
Services are registered using get_it for clean dependency management:

```dart
// Service registration
getIt.registerSingleton<AppwriteService>(AppwriteService());
getIt.registerSingleton<ChallengeMessagingService>(ChallengeMessagingService());

// Service consumption
final appwrite = getIt<AppwriteService>();
```

## Layer Architecture

### 1. Presentation Layer (`lib/screens/`, `lib/widgets/`, `lib/features/*/widgets/`)
- **Responsibility**: UI components and user interaction
- **Dependencies**: State providers, view models
- **Key Components**:
  - Screen widgets (full-page interfaces)
  - Reusable widgets (buttons, cards, etc.)
  - Feature-specific widgets (arena controls, chat panels)

### 2. State Management Layer (`lib/features/*/providers/`, `lib/core/state/`)
- **Responsibility**: Application state and business logic
- **Dependencies**: Services, models
- **Key Components**:
  - Provider classes (ArenaProvider, AuthProvider)
  - State models (ArenaState, AppState)
  - State notifiers for complex mutations

### 3. Service Layer (`lib/services/`)
- **Responsibility**: External integrations and complex business logic
- **Dependencies**: Models, external APIs
- **Key Components**:
  - AppwriteService (backend integration)
  - AgoraService (voice communication)
  - ChallengeMessagingService (real-time messaging)

### 4. Data Layer (`lib/models/`, `lib/core/`)
- **Responsibility**: Data structures and core utilities
- **Dependencies**: None (pure data)
- **Key Components**:
  - Data models (User, Arena, Message)
  - Error handling (AppError, ValidationError)
  - Utilities (validators, logging)

## Key Design Patterns

### 1. Provider Pattern
Used throughout for reactive state management:

```dart
@riverpod
class ArenaNotifier extends _$ArenaNotifier {
  @override
  ArenaState build(String roomId) {
    return ArenaState.initial();
  }
  
  Future<void> loadArenaData() async {
    // State mutation logic
  }
}
```

### 2. Repository Pattern
Service classes act as repositories for data access:

```dart
class AppwriteService {
  Future<List<Arena>> getActiveArenas() async {
    // Data access logic
  }
}
```

### 3. Factory Pattern
Used for service instantiation and configuration:

```dart
class AgoraServiceFactory {
  static AgoraService create() {
    if (kIsWeb) {
      return AgoraServiceWeb();
    } else {
      return AgoraServiceMobile();
    }
  }
}
```

### 4. Observer Pattern
Real-time updates using Riverpod's reactive system:

```dart
Consumer(
  builder: (context, ref, child) {
    final arenaState = ref.watch(arenaProvider);
    return arenaState.when(
      data: (arena) => ArenaWidget(arena: arena),
      loading: () => LoadingWidget(),
      error: (error, stack) => ErrorWidget(error),
    );
  },
)
```

## Data Flow

### 1. User Interaction
1. User interacts with UI widget
2. Widget calls provider method
3. Provider updates state
4. UI automatically rebuilds

### 2. Real-time Updates
1. External event (Appwrite subscription)
2. Service receives update
3. Service notifies relevant providers
4. Providers update state
5. UI reflects changes

### 3. API Communication
1. Provider calls service method
2. Service makes API request
3. Service processes response
4. Service returns data to provider
5. Provider updates state with new data

## Testing Architecture

### 1. Unit Tests
- Test individual functions and classes
- Mock external dependencies
- Focus on business logic validation

### 2. Widget Tests
- Test UI components in isolation
- Mock provider dependencies
- Verify user interaction behaviors

### 3. Integration Tests
- Test complete user workflows
- Use real providers with mock services
- Validate end-to-end functionality

## Performance Considerations

### 1. State Management
- Selective rebuilds using Consumer widgets
- Efficient provider selection with ref.watch
- State normalization to prevent deep object comparisons

### 2. Database Operations
- Connection pooling for Appwrite
- Optimistic updates for better UX
- Pagination for large data sets

### 3. Voice Communication
- Efficient token management with caching
- Role-based audio permissions
- Bandwidth optimization for mobile

## Security Architecture

### 1. Authentication
- JWT tokens from Appwrite
- Secure token storage
- Automatic token refresh

### 2. Voice Security
- Dynamic Agora token generation
- Server-side token validation
- Role-based audio permissions

### 3. Data Protection
- Input validation at multiple layers
- Sanitized error messages
- Secure API communication

## Future Architectural Improvements

### 1. Offline Support
- Local database caching
- Conflict resolution strategies
- Progressive sync capabilities

### 2. Microservices
- Service layer decomposition
- API gateway integration
- Independent service scaling

### 3. Advanced State Management
- State persistence
- Time-travel debugging
- Undo/redo functionality

This architecture provides a solid foundation for scaling the Arena application while maintaining code quality and developer productivity.