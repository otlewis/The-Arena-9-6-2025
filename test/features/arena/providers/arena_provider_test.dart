import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:mockito/mockito.dart';  // Unused
import 'package:mockito/annotations.dart';
import 'package:arena/features/arena/providers/arena_provider.dart';
import 'package:arena/features/arena/models/arena_state.dart';
import 'package:arena/services/appwrite_service.dart';
import 'package:arena/core/logging/app_logger.dart';
import 'package:arena/services/sound_service.dart';

import 'arena_provider_test.mocks.dart';

@GenerateMocks([AppwriteService, AppLogger, SoundService])
void main() {
  group('ArenaProvider', () {
    late MockAppwriteService mockAppwrite;
    late MockAppLogger mockLogger;
    late MockSoundService mockSound;
    late ProviderContainer container;
    const testRoomId = 'test-room-123';

    setUp(() {
      mockAppwrite = MockAppwriteService();
      mockLogger = MockAppLogger();
      mockSound = MockSoundService();
      
      container = ProviderContainer(
        overrides: [
          // Override the providers with mocks
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with correct room ID and loading state', () {
      // Create a direct instance for testing
      final arenaNotifier = ArenaNotifier(
        roomId: testRoomId,
        logger: mockLogger,
        appwrite: mockAppwrite,
        sound: mockSound,
      );

      expect(arenaNotifier.state.roomId, testRoomId);
      expect(arenaNotifier.state.topic, '');
      expect(arenaNotifier.state.status, ArenaStatus.waiting);
      expect(arenaNotifier.state.currentPhase, DebatePhase.preDebate);
    });

    test('should update arena state correctly', () {
      final arenaNotifier = ArenaNotifier(
        roomId: testRoomId,
        logger: mockLogger,
        appwrite: mockAppwrite,
        sound: mockSound,
      );

      // Test state updates
      final newState = arenaNotifier.state.copyWith(
        topic: 'Test Debate Topic',
        status: ArenaStatus.speaking,
        currentPhase: DebatePhase.openingAffirmative,
      );

      arenaNotifier.state = newState;

      expect(arenaNotifier.state.topic, 'Test Debate Topic');
      expect(arenaNotifier.state.status, ArenaStatus.speaking);
      expect(arenaNotifier.state.currentPhase, DebatePhase.openingAffirmative);
    });

    test('should calculate ready to start correctly', () {
      final arenaNotifier = ArenaNotifier(
        roomId: testRoomId,
        logger: mockLogger,
        appwrite: mockAppwrite,
        sound: mockSound,
      );

      // Add participants
      final participants = {
        'user1': const ArenaParticipant(
          userId: 'user1',
          name: 'Debater 1',
          role: ArenaRole.affirmative,
          isReady: true,
        ),
        'user2': const ArenaParticipant(
          userId: 'user2',
          name: 'Debater 2',
          role: ArenaRole.negative,
          isReady: true,
        ),
        'user3': const ArenaParticipant(
          userId: 'user3',
          name: 'Moderator 1',
          role: ArenaRole.moderator,
          isReady: true,
        ),
      };

      arenaNotifier.state = arenaNotifier.state.copyWith(participants: participants);

      expect(arenaNotifier.state.isReadyToStart, true);
    });

    test('should not be ready if participants are not ready', () {
      final arenaNotifier = ArenaNotifier(
        roomId: testRoomId,
        logger: mockLogger,
        appwrite: mockAppwrite,
        sound: mockSound,
      );

      final participants = {
        'user1': const ArenaParticipant(
          userId: 'user1',
          name: 'Debater 1',
          role: ArenaRole.affirmative,
          isReady: false, // Not ready
        ),
        'user2': const ArenaParticipant(
          userId: 'user2',
          name: 'Debater 2',
          role: ArenaRole.negative,
          isReady: true,
        ),
      };

      arenaNotifier.state = arenaNotifier.state.copyWith(participants: participants);

      expect(arenaNotifier.state.isReadyToStart, false);
    });

    test('should get participants by role correctly', () {
      final arenaNotifier = ArenaNotifier(
        roomId: testRoomId,
        logger: mockLogger,
        appwrite: mockAppwrite,
        sound: mockSound,
      );

      final participants = {
        'user1': const ArenaParticipant(
          userId: 'user1',
          name: 'Debater 1',
          role: ArenaRole.affirmative,
        ),
        'user2': const ArenaParticipant(
          userId: 'user2',
          name: 'Judge 1',
          role: ArenaRole.judge1,
        ),
        'user3': const ArenaParticipant(
          userId: 'user3',
          name: 'Judge 2',
          role: ArenaRole.judge1,
        ),
      };

      arenaNotifier.state = arenaNotifier.state.copyWith(participants: participants);

      final judges = arenaNotifier.state.getParticipantsByRole(ArenaRole.judge1);
      final debaters = arenaNotifier.state.getParticipantsByRole(ArenaRole.affirmative);

      expect(judges, hasLength(2));
      expect(debaters, hasLength(1));
      expect(judges.first.name, 'Judge 1');
      expect(debaters.first.name, 'Debater 1');
    });

    test('should get correct phase duration', () {
      final arenaNotifier = ArenaNotifier(
        roomId: testRoomId,
        logger: mockLogger,
        appwrite: mockAppwrite,
        sound: mockSound,
      );

      expect(arenaNotifier.state.currentPhase.defaultDurationSeconds, isNotNull);
      expect(DebatePhase.preDebate.defaultDurationSeconds, 300);
      expect(DebatePhase.openingAffirmative.defaultDurationSeconds, 300);
      expect(DebatePhase.rebuttalAffirmative.defaultDurationSeconds, 180);
      expect(DebatePhase.closingAffirmative.defaultDurationSeconds, 240);
      expect(DebatePhase.judging.defaultDurationSeconds, isNull);
    });

    test('should determine user speaking permissions correctly', () {
      final arenaNotifier = ArenaNotifier(
        roomId: testRoomId,
        logger: mockLogger,
        appwrite: mockAppwrite,
        sound: mockSound,
      );

      final participants = {
        'debater1': const ArenaParticipant(
          userId: 'debater1',
          name: 'Debater 1',
          role: ArenaRole.affirmative,
        ),
        'moderator1': const ArenaParticipant(
          userId: 'moderator1',
          name: 'Moderator 1',
          role: ArenaRole.moderator,
        ),
        'audience1': const ArenaParticipant(
          userId: 'audience1',
          name: 'Audience 1',
          role: ArenaRole.audience,
        ),
      };

      arenaNotifier.state = arenaNotifier.state.copyWith(
        participants: participants,
        currentPhase: DebatePhase.openingAffirmative,
      );

      expect(arenaNotifier.state.canUserSpeak('debater1'), true);
      expect(arenaNotifier.state.canUserSpeak('moderator1'), false);
      expect(arenaNotifier.state.canUserSpeak('audience1'), false);

      // Change to preparation phase - only moderator can speak
      arenaNotifier.state = arenaNotifier.state.copyWith(
        currentPhase: DebatePhase.preDebate,
      );

      expect(arenaNotifier.state.canUserSpeak('debater1'), false);
      expect(arenaNotifier.state.canUserSpeak('moderator1'), true);
      expect(arenaNotifier.state.canUserSpeak('audience1'), false);
    });
  });

  group('ArenaTimerProvider', () {
    test('should emit timer values when running', () {
      // This would require more complex setup to test the timer stream
      // For now, we verify the basic structure exists
      expect(arenaTimerProvider, isA<StreamProviderFamily<int, String>>());
    });
  });
}