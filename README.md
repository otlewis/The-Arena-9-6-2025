# Arena - Advanced Debate Platform 🥊

A sophisticated Flutter application for real-time debate competitions featuring live voice chat, intelligent role management, and comprehensive debate scoring.

## 🌟 Features

### Core Functionality
- **Real-time Voice Debates** - Live audio communication using Agora Voice SDK
- **Smart Role Management** - Automatic assignment of debaters, judges, and moderators
- **Live Chat System** - Real-time messaging during debates with role-based permissions
- **Debate Scoring** - Comprehensive scoring system with judge evaluations
- **Challenge System** - Send and receive debate challenges with topic proposals
- **Club Management** - Create and manage debate clubs with member hierarchies
- **Debates & Discussions** - Open discussion rooms with moderator controls and speaker panels

### Technical Highlights
- **Modular Architecture** - Feature-first architecture with clean separation of concerns
- **State Management** - Reactive UI using Riverpod providers and state notifiers
- **Real-time Sync** - Appwrite backend with real-time database subscriptions
- **Voice Integration** - Cross-platform voice chat with role-based audio permissions
- **Comprehensive Testing** - Unit, widget, and integration test suites
- **Structured Logging** - Professional logging system with categorized output

## 🏗️ Architecture

### Project Structure
```
lib/
├── core/                   # Core utilities and shared components
│   ├── error/             # Error handling and custom exceptions
│   ├── logging/           # Structured logging system
│   ├── state/             # Global state management
│   ├── validation/        # Input validation utilities
│   └── widgets/           # Reusable UI components
├── features/              # Feature-specific modules
│   ├── arena/             # Arena debate functionality
│   │   ├── models/        # Arena data models
│   │   ├── providers/     # State management for arena
│   │   ├── screens/       # Arena UI screens
│   │   └── widgets/       # Arena-specific widgets
│   └── discussion/        # Debates & Discussions functionality
│       ├── screens/       # Discussion room screens
│       └── widgets/       # Discussion-specific widgets
├── models/                # Global data models
├── screens/               # Application screens
├── services/              # Business logic and external integrations
└── widgets/               # Global reusable widgets
```

### Key Design Patterns
- **Provider Pattern** - Riverpod for reactive state management
- **Repository Pattern** - Clean data access layer
- **Factory Pattern** - Service instantiation and dependency injection
- **Observer Pattern** - Real-time updates and state synchronization

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (2.17.0 or higher)
- Android Studio / VS Code with Flutter extensions
- iOS development: Xcode (for iOS builds)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd arena
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   - Copy `.env.example` to `.env`
   - Update Appwrite endpoint and project credentials
   - Configure Agora app ID and tokens

4. **Run the application**
   ```bash
   flutter run
   ```

### Environment Setup

Create a `.env` file in the project root:
```env
APPWRITE_ENDPOINT=https://your-appwrite-endpoint
APPWRITE_PROJECT_ID=your-project-id
AGORA_APP_ID=your-agora-app-id
```

## 🧪 Testing

The project includes comprehensive testing infrastructure:

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/
```

### Test Categories
- **Unit Tests** - Business logic and service layer testing
- **Widget Tests** - UI component testing with mock dependencies
- **Integration Tests** - End-to-end user workflow testing

## 📱 Key Components

### Arena System
The arena is the core debate environment where users engage in structured debates:

- **Arena Provider** (`lib/features/arena/providers/arena_provider.dart`)
  - Manages arena state and real-time updates
  - Handles user roles and permissions
  - Coordinates debate phases and timing

- **Arena Screen** (`lib/features/arena/screens/arena_screen_modular.dart`)
  - Main debate interface with responsive layout
  - Integrates voice chat, messaging, and controls
  - Supports both mobile and tablet layouts

- **Arena Widgets**
  - `arena_debate_controls.dart` - Speaking controls and phase management
  - `arena_participants_panel.dart` - User roles and participant display
  - `arena_chat_panel.dart` - Real-time messaging interface

### Voice Integration
Real-time voice communication using Agora Voice SDK:

- **Agora Service** (`lib/services/agora_service_mobile.dart`)
  - Cross-platform voice implementation
  - Dynamic token generation for security
  - Role-based audio permissions (speaker/audience)

### Challenge System
Debate invitation and matchmaking system:

- **Challenge Messaging Service** (`lib/services/challenge_messaging_service.dart`)
  - Real-time challenge delivery
  - Automatic room creation and role assignment
  - Judge and moderator invitation system

### Debates & Discussions System
Open discussion rooms with flexible participation:

- **Room Types** (`lib/screens/debates_discussions_screen.dart`)
  - Discussion - Open conversation and exchange of ideas
  - Debate - Structured argument with opposing sides
  - Take - Hot takes and quick opinions (First Take style)

- **Key Features**
  - **Floating Speakers Panel** - Dynamic 7-slot panel (1 moderator + 6 speakers)
  - **Hand-Raising System** - Audience members request to speak with moderator approval
  - **Moderator Tools** - Complete room control including:
    - Speaker management with approve/deny requests
    - Mute/unmute all participants
    - Room settings and configuration
    - End room functionality with automatic user navigation
  - **Real-time Synchronization** - All changes instantly reflected across devices
  - **Smart Role Management**
    - Moderator - Room creator with full control
    - Speakers - Active participants in the discussion
    - Audience - Listeners who can request to speak

- **Room Creation** (`lib/screens/create_discussion_room_screen.dart`)
  - Category selection (Religion, Sports, Science, etc.)
  - Custom categories supported
  - Private/public room settings
  - Scheduled rooms for future discussions

## 🔧 Development

### Code Style
- Follow Dart/Flutter style guidelines
- Use `flutter analyze` for static analysis
- Maintain test coverage above 80%
- Document public APIs with dart doc comments

### Debugging
The application includes comprehensive logging:

```dart
// Use AppLogger for structured logging
AppLogger().debug('Debug information');
AppLogger().info('Important events');
AppLogger().warning('Potential issues');
AppLogger().error('Error conditions');
```

### Performance
- Optimized database queries with connection pooling
- Efficient state management with selective rebuilds
- Image caching and lazy loading
- Voice chat with bandwidth optimization

## 🛠️ Services Integration

### Appwrite Backend
- **Authentication** - User registration and login
- **Database** - Real-time data storage and sync
- **Storage** - File uploads for avatars and assets
- **Functions** - Server-side logic for complex operations

### Agora Voice SDK
- **Real-time Audio** - Low-latency voice communication
- **Token Security** - Dynamic token generation
- **Role Management** - Speaker/audience role switching

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Guide](https://riverpod.dev/)
- [Appwrite Documentation](https://appwrite.io/docs)
- [Agora Voice SDK](https://docs.agora.io/en/voice-calling/overview/product-overview)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔍 Code Quality

- **Static Analysis**: 454 → 0 issues (100% reduction achieved)
- **Test Coverage**: Comprehensive test suites across all modules
- **Architecture**: Modular, scalable, and maintainable codebase
- **Performance**: Optimized for real-time operations and scalability
- **Recent Improvements**:
  - Eliminated all Flutter analyzer issues
  - Implemented floating speakers panel with pixel-perfect layouts
  - Added real-time moderator tools with instant notifications
  - Zero pixel overflow on all device sizes

---

**Built with ❤️ using Flutter and modern development practices**