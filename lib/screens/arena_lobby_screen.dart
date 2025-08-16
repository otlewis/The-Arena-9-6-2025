import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../features/arena/providers/arena_lobby_provider.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/instant_message_bell.dart';
import 'arena_screen.dart';
import 'dart:async';
import '../core/logging/app_logger.dart';

class ArenaLobbyScreen extends ConsumerStatefulWidget {
  const ArenaLobbyScreen({super.key});

  @override
  ConsumerState<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends ConsumerState<ArenaLobbyScreen> with WidgetsBindingObserver {
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  String? _currentUserId;

  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
    // Trigger initial load of arenas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(arenaLobbyProvider.notifier).loadActiveArenas();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app becomes active (user returns from arena)
    if (state == AppLifecycleState.resumed) {
      AppLogger().debug('🔄 App resumed - refreshing arena lobby');
      ref.read(arenaLobbyProvider.notifier).loadActiveArenas(isBackgroundRefresh: true);
    }
  }


  Future<void> _loadCurrentUser() async {
    final user = await _appwrite.getCurrentUser();
    if (user != null) {
      _currentUserId = user.$id;
    }
  }

  Future<void> _joinArenaAsAudience(String roomId, String challengeId, String topic) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to join The Arena')),
      );
      return;
    }

    try {
      // First, check if the room is scheduled and user is not the moderator
      final roomDoc = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
      );
      
      final roomStatus = roomDoc.data['status'] as String?;
      
      if (roomStatus == 'scheduled') {
        // Check if user is the moderator/creator of this room
        final participants = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('userId', _currentUserId!),
            Query.equal('role', 'moderator'),
          ],
        );
        
        if (participants.documents.isEmpty) {
          // User is not the moderator, show warning
          if (mounted) {
            // Extract scheduled time from metadata in description
            String scheduledTimeText = 'the scheduled time';
            
            // For scheduled rooms, try to extract time info from room ID or status
            if (roomId.startsWith('scheduled_')) {
              scheduledTimeText = 'its scheduled time';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔒 Scheduled Room',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('This room is scheduled for later and can only be accessed by the room creator before $scheduledTimeText.'),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      
      // Check if room is private and requires password
      final description = roomDoc.data['description'] as String? ?? '';
      if (description.contains('[METADATA]')) {
        // Extract metadata from description
        final metadataStart = description.indexOf('[METADATA]');
        final metadataStr = description.substring(metadataStart + '[METADATA]'.length);
        
        // Check if room is private by looking for isPrivate: true in metadata
        if (metadataStr.contains('isPrivate: true')) {
          // Check if user is the moderator (moderators don't need password)
          final participants = await _appwrite.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            queries: [
              Query.equal('roomId', roomId),
              Query.equal('userId', _currentUserId!),
              Query.equal('role', 'moderator'),
            ],
          );
          
          if (participants.documents.isEmpty) {
            // User is not moderator, validate password
            final passwordValid = await _validateRoomPassword(metadataStr);
            if (!passwordValid) {
              return; // Password validation failed or user cancelled
            }
          }
        }
      }
      
      // For manual rooms, use the joinArenaRoom method, for challenge rooms use assignArenaRole
      final isManualRoom = roomId.startsWith('manual_arena_') || roomId.startsWith('scheduled_');
      
      if (isManualRoom) {
        await _appwrite.joinArenaRoom(
          roomId: roomId,
          userId: _currentUserId!,
        );
      } else {
        // Assign user as audience member for challenge-based rooms
        await _appwrite.assignArenaRole(
          roomId: roomId,
          userId: _currentUserId!,
          role: 'audience',
        );
      }

      // Navigate to Arena and refresh lobby when returning
      if (mounted) {
        await Navigator.push(
          context,
        MaterialPageRoute(
          builder: (context) => ArenaScreen(
            roomId: roomId,
            challengeId: challengeId.isNotEmpty ? challengeId : roomId,
            topic: topic,
          ),
        ),
      );
      
        // Refresh the lobby when user returns from arena
        AppLogger().debug('🔄 User returned from arena - refreshing lobby');
        ref.read(arenaLobbyProvider.notifier).refreshArenas();
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining arena: $e')),
        );
      }
    }
  }

  Future<void> _handleScheduledRoomTap(String roomId, String topic, String challengeId) async {
    if (_currentUserId == null) return;
    
    try {
      // Check if user is the moderator/creator of this room
      final participants = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', _currentUserId!),
          Query.equal('role', 'moderator'),
        ],
      );
      
      if (participants.documents.isNotEmpty) {
        // User is the moderator, show options to start room or enter
        if (mounted) {
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Scheduled Room'),
              content: const Text('This room is scheduled for later. What would you like to do?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'enter'),
                  child: const Text('Enter Now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Start Room Early'),
                ),
              ],
            ),
          );
          
          if (result == 'start') {
            // Change room status from 'scheduled' to 'waiting'
            await _appwrite.updateArenaRoomStatus(roomId, 'waiting');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Room started! Users can now join.'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh the lobby to show updated status
              ref.read(arenaLobbyProvider.notifier).refreshArenas();
            }
          } else if (result == 'enter') {
            // Enter the room as-is
            await _joinArenaAsAudience(roomId, challengeId, topic);
          }
        }
      } else {
        // User is not the moderator, show the same warning as before
        await _joinArenaAsAudience(roomId, challengeId, topic);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<bool> _validateRoomPassword(String metadataStr) async {
    // Extract actual password from metadata
    String roomPassword = '';
    final passwordMatch = RegExp(r'password: ([^,}]+)').firstMatch(metadataStr);
    if (passwordMatch != null) {
      roomPassword = passwordMatch.group(1)?.trim() ?? '';
    }
    
    if (roomPassword.isEmpty) {
      return true; // No password required
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PasswordValidationDialog(requiredPassword: roomPassword),
    ) ?? false;
  }

  Future<void> _createManualArena() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create an arena')),
      );
      return;
    }

    // Show dialog to get room details
    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateArenaDialog(),
    );

    if (dialogResult != null) {
      try {
        final topic = dialogResult['topic'] as String;
        final affirmativeName = dialogResult['affirmativeName'] as String;
        final negativeName = dialogResult['negativeName'] as String;
        final affirmativeTeam2 = dialogResult['affirmativeTeam2'] as String?;
        final negativeTeam2 = dialogResult['negativeTeam2'] as String?;
        final category = dialogResult['category'] as String;
        final teamSize = dialogResult['teamSize'] as String;
        final isScheduled = dialogResult['isScheduled'] as bool? ?? false;
        final scheduledTime = dialogResult['scheduledTime'] as DateTime?;
        final isPrivate = dialogResult['isPrivate'] as bool? ?? false;
        final password = dialogResult['password'] as String?;
        
        // Build debaters description with additional metadata
        String debatersNames;
        if (teamSize == '2v2') {
          debatersNames = '$affirmativeName & $affirmativeTeam2 vs $negativeName & $negativeTeam2';
        } else {
          debatersNames = '$affirmativeName vs $negativeName';
        }
        
        // Add metadata to description for features not supported by current schema
        final metadata = {
          'teamSize': teamSize,
          'category': category,
          'isPrivate': isPrivate,
          'password': password,
          'affirmativeName': affirmativeName,
          'negativeName': negativeName,
          'affirmativeTeam2': affirmativeTeam2,
          'negativeTeam2': negativeTeam2,
        };
        final fullDescription = '$debatersNames\n[METADATA]${metadata.toString()}';
        
        // For scheduled rooms, create them but don't start immediately
        if (isScheduled && scheduledTime != null) {
          // Create scheduled arena room
          final roomId = await _appwrite.createScheduledArenaRoom(
            creatorId: _currentUserId!,
            topic: topic,
            description: fullDescription,
            scheduledTime: scheduledTime,
          );
          
          AppLogger().info('Scheduled arena created: $roomId');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Arena scheduled for ${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} at ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          
          // Don't navigate to the room - it's scheduled for later
        } else {
          // Create and start room immediately
          final roomId = await _appwrite.createManualArenaRoom(
            creatorId: _currentUserId!,
            topic: topic,
            description: fullDescription,
          );

          // Navigate to the created arena
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArenaScreen(
                  roomId: roomId,
                  challengeId: roomId,
                  topic: topic,
                  description: fullDescription,
                ),
              ),
            );
          }
        }

        // Refresh the lobby when user returns from created arena
        AppLogger().debug('🔄 User returned from created arena - refreshing lobby');
        ref.read(arenaLobbyProvider.notifier).refreshArenas();

        // Show success message
        if (mounted) {
          final timeText = isScheduled && scheduledTime != null 
              ? ' scheduled for ${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year}'
              : '';
          final privacyText = isPrivate ? ' (Private)' : '';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🏛️ Arena created$timeText$privacyText! You are the moderator.'),
              backgroundColor: const Color(0xFF8B5CF6),
            ),
          );
        }

        // Refresh the list again to ensure consistency
        ref.read(arenaLobbyProvider.notifier).refreshArenas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating arena: $e')),
          );
        }
      }
    }
  }

  Future<void> _createDemoArena() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create demo arena')),
      );
      return;
    }

    try {
      // Create a demo arena room
      final roomId = await _appwrite.createArenaRoom(
        challengeId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        challengerId: _currentUserId!,
        challengedId: 'demo_opponent',
        topic: 'Should AI replace human judges in debates?',
        description: 'Demo Arena - Experience The Arena interface',
      );

      // Assign current user as audience
      await _appwrite.assignArenaRole(
        roomId: roomId,
        userId: _currentUserId!,
        role: 'audience',
      );

      // Navigate to demo arena
      if (mounted) {
        await Navigator.push(
          context,
        MaterialPageRoute(
          builder: (context) => ArenaScreen(
            roomId: roomId,
            challengeId: 'demo_challenge',
            topic: 'Should AI replace human judges in debates?',
            description: 'Demo Arena - Experience The Arena interface',
          ),
        ),
      );

        // Refresh the lobby when user returns from demo arena
        AppLogger().debug('🔄 User returned from demo arena - refreshing lobby');
        ref.read(arenaLobbyProvider.notifier).refreshArenas();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎭 Demo Arena created! This is how real debates look.'),
            backgroundColor: Color(0xFF8B5CF6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating demo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(arenaLobbyProvider);
    final activeArenas = lobbyState.rooms;
    final isLoading = lobbyState.isLoading;
    final isRefreshing = lobbyState.isRefreshing;
    
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
      appBar: AppBar(
        title: Text(
          'The Arena',
          style: TextStyle(
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        elevation: 0,
        leading: _buildNeumorphicIcon(
          icon: Icons.home_outlined,
          onTap: () => Navigator.pop(context),
          tooltip: 'Back to Home',
        ),
        actions: [
          // Message notification icon
          InstantMessageBell(
            iconColor: _themeService.isDarkMode ? Colors.white70 : deepPurple,
            iconSize: 24,
          ),
          const SizedBox(width: 8),
          // Challenge notification bell
          ChallengeBell(
            iconColor: _themeService.isDarkMode ? Colors.white70 : deepPurple,
            iconSize: 24,
          ),
          const SizedBox(width: 8),
          if (isRefreshing)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _themeService.isDarkMode ? Colors.white70 : deepPurple
                    ),
                  ),
                ),
              ),
            )
          else
            _buildNeumorphicIcon(
              icon: Icons.refresh,
              onTap: () => ref.read(arenaLobbyProvider.notifier).refreshArenas(),
              tooltip: 'Refresh',
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(arenaLobbyProvider.notifier).refreshArenas(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 50),
                child: Column(
                  children: [
                    _buildArenaHeader(),
                    const SizedBox(height: 12),
                    if (activeArenas.isNotEmpty) ...[
                      _buildActiveArenasList(activeArenas),
                      const SizedBox(height: 12),
                    ],
                    _buildDemoSection(),
                    const SizedBox(height: 12),
                    _buildHowItWorksSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildArenaHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: scarletRed,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Color(0xFF8B5CF6),
                  BlendMode.srcIn,
                ),
                child: Image(
                  image: AssetImage('assets/images/Arenalogo.png'),
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to',
                      style: TextStyle(
                        color: scarletRed,
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      'The Arena',
                      style: TextStyle(
                        color: scarletRed,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Join live debates as an audience member or challenge someone to debate!',
            style: TextStyle(
              color: scarletRed,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveArenasList(List<ArenaRoom> activeArenas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _themeService.isDarkMode 
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFE8E8E8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: const Icon(Icons.live_tv, color: scarletRed, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'Live Debates',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : deepPurple,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scarletRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${activeArenas.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...activeArenas.map((arena) => _buildArenaCard(
          arena.id, 
          arena.topic, 
          arena.status, 
          arena.challengeId ?? '', 
          arena.description ?? '', 
          arena.currentParticipants, 
          arena.isManual, 
          arena.category ?? '', 
          arena.teamSize, 
          arena.moderatorId,
          arena.moderatorProfile,
        )),
      ],
    );
  }

  Widget _buildArenaCard(String roomId, String topic, String status, String challengeId, String description, int currentParticipants, bool isManual, String category, int teamSize, String? moderatorId, Map<String, dynamic>? moderatorProfile) {
    const maxParticipants = 1000; // Allow unlimited participants
    
    // Check if room is private by looking in the description metadata
    final isPrivate = description.contains('[METADATA]') && description.contains('isPrivate: true');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.5)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
            offset: const Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: status == 'scheduled' 
              ? () => _handleScheduledRoomTap(roomId, topic, challengeId)
              : () => _joinArenaAsAudience(roomId, challengeId, topic),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: status == 'active' 
                            ? Colors.green 
                            : status == 'scheduled' 
                                ? Colors.blue 
                                : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status == 'active' 
                          ? 'LIVE' 
                          : status == 'scheduled' 
                              ? 'SCHEDULED' 
                              : 'WAITING',
                      style: TextStyle(
                        color: status == 'active' 
                            ? Colors.green 
                            : status == 'scheduled' 
                                ? Colors.blue 
                                : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isManual ? accentPurple : deepPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isManual ? 'OPEN' : 'CHALLENGE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (teamSize > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${teamSize}v$teamSize',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (isPrivate) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 10,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'PRIVATE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      Icons.people, 
                      size: 16, 
                      color: _themeService.isDarkMode ? Colors.white60 : Colors.grey[600]
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$currentParticipants/$maxParticipants',
                      style: TextStyle(
                        color: _themeService.isDarkMode ? Colors.white60 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  topic,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _themeService.isDarkMode ? Colors.white : deepPurple,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: accentPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: _themeService.isDarkMode ? Colors.white60 : Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // Moderator info - always show for arena rooms
                Row(
                  children: [
                    // Moderator profile picture
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentPurple.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: moderatorProfile?['avatar'] != null && moderatorProfile!['avatar'].toString().isNotEmpty
                          ? Image.network(
                              moderatorProfile['avatar'],
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: accentPurple.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 12,
                                    color: accentPurple,
                                  ),
                                );
                              },
                            )
                          : Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: accentPurple.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 12,
                                color: accentPurple,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        moderatorProfile != null && moderatorProfile['name'] != null
                          ? 'Moderator: ${moderatorProfile['name']}'
                          : moderatorId != null && moderatorId.isNotEmpty 
                              ? 'Moderator' 
                              : 'Moderator: Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isManual ? Icons.person_add : Icons.visibility, 
                      size: 16, 
                      color: accentPurple
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isManual ? 'Tap to join room' : 'Tap to watch debate',
                        style: const TextStyle(
                          color: accentPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ]
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _themeService.isDarkMode 
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFE8E8E8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: const Icon(Icons.add_circle, color: accentPurple, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Create or Try Arena',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Create New Arena Card
        Container(
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFF0F0F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scarletRed.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.8),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _createManualArena,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _themeService.isDarkMode 
                            ? const Color(0xFF2D2D2D)
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.black.withValues(alpha: 0.6)
                                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.8),
                            offset: const Offset(-2, -2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: scarletRed, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Arena',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _themeService.isDarkMode ? Colors.white : deepPurple,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Start your own debate room and invite participants',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? Colors.white60 : Colors.grey[600],
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios, 
                      color: _themeService.isDarkMode ? Colors.white70 : scarletRed, 
                      size: 16
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Demo Arena Card
        Container(
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFF0F0F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentPurple.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.8),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _createDemoArena,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _themeService.isDarkMode 
                            ? const Color(0xFF2D2D2D)
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.black.withValues(alpha: 0.6)
                                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.8),
                            offset: const Offset(-2, -2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.smart_toy, color: accentPurple, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Demo Arena',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _themeService.isDarkMode ? Colors.white : deepPurple,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Experience The Arena interface with sample debate',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? Colors.white60 : Colors.grey[600],
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios, 
                      color: _themeService.isDarkMode ? Colors.white70 : accentPurple, 
                      size: 16
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _themeService.isDarkMode 
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFE8E8E8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Icon(
                Icons.help_outline, 
                color: _themeService.isDarkMode ? Colors.white70 : deepPurple, 
                size: 16
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'How to Start an Instant Debate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFF0F0F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (_themeService.isDarkMode ? Colors.white : Colors.grey).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.8),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStepItem(
                  '1',
                  'Visit User Profiles',
                  'Go to any user\'s profile page',
                  Icons.person,
                ),
                _buildStepItem(
                  '2',
                  'Send Challenge',
                  'Challenge them to a debate on any topic',
                  Icons.flash_on,
                ),
                _buildStepItem(
                  '3',
                  'Arena Opens',
                  'When accepted, you\'ll both enter The Arena',
                  Icons.stadium,
                ),
                _buildStepItem(
                  '4',
                  'Others Join',
                  'People can watch as audience members',
                  Icons.people,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String title, String description, IconData icon, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _themeService.isDarkMode 
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scarletRed,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: scarletRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _themeService.isDarkMode 
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFE8E8E8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                  BoxShadow(
                    color: _themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.8),
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon, 
                color: _themeService.isDarkMode ? Colors.white70 : deepPurple, 
                size: 16
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _themeService.isDarkMode ? Colors.white : deepPurple,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: _themeService.isDarkMode ? Colors.white60 : Colors.grey[600],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.only(left: 16),
            width: 2,
            height: 10,
            color: _themeService.isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildNeumorphicIcon({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF0F0F3),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.7),
              offset: const Offset(-3, -3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: _themeService.isDarkMode ? Colors.white70 : accentPurple,
        ),
      ),
    );
  }
}

// Create Arena Dialog Widget
class CreateArenaDialog extends StatefulWidget {
  const CreateArenaDialog({super.key});

  @override
  State<CreateArenaDialog> createState() => _CreateArenaDialogState();
}

class _CreateArenaDialogState extends State<CreateArenaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _debateTitleController = TextEditingController();
  final _affirmativeNameController = TextEditingController();
  final _negativeNameController = TextEditingController();
  final _affirmativeTeam2Controller = TextEditingController();
  final _negativeTeam2Controller = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _passwordController = TextEditingController();

  // Form state
  String? _selectedCategory;
  String _teamSize = '1v1'; // Default to 1v1
  bool _isCustomCategory = false;
  bool _isScheduled = false;
  bool _isPrivate = false;
  DateTime? _scheduledTime;

  // Categories
  final List<String> _categories = [
    'Religion',
    'Sports', 
    'Politics',
    'Science',
    'Entertainment',
    'Technology',
    'Philosophy',
    'Education',
    'Custom'
  ];

  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void dispose() {
    _debateTitleController.dispose();
    _affirmativeNameController.dispose();
    _negativeNameController.dispose();
    _affirmativeTeam2Controller.dispose();
    _negativeTeam2Controller.dispose();
    _customCategoryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showDateTimePicker() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (time != null && mounted) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      } else if (mounted) {
        setState(() {
          _isScheduled = false;
        });
      }
    } else {
      setState(() {
        _isScheduled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85, // Limit height to 85% of screen
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildForm(),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [accentPurple, deepPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Create New Arena',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debate Title
            const Text(
              'Debate Title *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _debateTitleController,
              decoration: InputDecoration(
                hintText: 'Enter debate title (e.g., "Should AI replace human teachers?")',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a debate title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Debaters Names
            const Text(
              'Debater Names *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            
            // Affirmative Side
            const Text(
              'Affirmative Side (Pro)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _affirmativeNameController,
              decoration: InputDecoration(
                hintText: 'Affirmative debater name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter affirmative debater name';
                }
                return null;
              },
            ),
            
            if (_teamSize == '2v2') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _affirmativeTeam2Controller,
                decoration: InputDecoration(
                  hintText: 'Second affirmative debater name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: accentPurple, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (_teamSize == '2v2' && (value == null || value.trim().isEmpty)) {
                    return 'Please enter second affirmative debater name';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Negative Side
            const Text(
              'Negative Side (Con)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _negativeNameController,
              decoration: InputDecoration(
                hintText: 'Negative debater name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter negative debater name';
                }
                return null;
              },
            ),
            
            if (_teamSize == '2v2') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _negativeTeam2Controller,
                decoration: InputDecoration(
                  hintText: 'Second negative debater name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: accentPurple, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (_teamSize == '2v2' && (value == null || value.trim().isEmpty)) {
                    return 'Please enter second negative debater name';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),

            // Team Size Selection
            const Text(
              'Format',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTeamSizeOption('1v1', 'Traditional\nOne vs One'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTeamSizeOption('2v2', 'Team Debate\nTwo vs Two'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scheduling and Privacy Options
            Card(
              elevation: 0,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Schedule for later'),
                      subtitle: _scheduledTime != null 
                        ? Text('Scheduled for: ${_scheduledTime!.day}/${_scheduledTime!.month}/${_scheduledTime!.year} at ${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}')
                        : const Text('Start immediately or schedule for a specific time'),
                      value: _isScheduled,
                      onChanged: (value) {
                        setState(() {
                          _isScheduled = value ?? false;
                          if (_isScheduled) {
                            _showDateTimePicker();
                          } else {
                            _scheduledTime = null;
                          }
                        });
                      },
                      activeColor: accentPurple,
                    ),
                    CheckboxListTile(
                      title: const Text('Private Room'),
                      subtitle: const Text('Requires password to join'),
                      value: _isPrivate,
                      onChanged: (value) {
                        setState(() {
                          _isPrivate = value ?? false;
                        });
                      },
                      activeColor: accentPurple,
                    ),
                    
                    if (_isPrivate) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Room Password *',
                          hintText: 'Enter password for private room',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentPurple, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (value) {
                          if (_isPrivate && (value == null || value.trim().isEmpty)) {
                            return 'Please enter a password for private room';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Selection
            const Text(
              'Category *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              hint: const Text('Select a category'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                  _isCustomCategory = value == 'Custom';
                  if (!_isCustomCategory) {
                    _customCategoryController.clear();
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            
            // Custom Category Field
            if (_isCustomCategory) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customCategoryController,
                decoration: InputDecoration(
                  hintText: 'Enter custom category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: accentPurple, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (_isCustomCategory && (value == null || value.trim().isEmpty)) {
                    return 'Please enter a custom category';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _createArena,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Create Arena',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTeamSizeOption(String value, String label) {
    final isSelected = _teamSize == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _teamSize = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentPurple.withValues(alpha: 0.1) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? accentPurple : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              value == '1v1' ? Icons.person : Icons.people,
              color: isSelected ? accentPurple : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? accentPurple : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? accentPurple : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createArena() {
    if (_formKey.currentState?.validate() ?? false) {
      final category = _isCustomCategory 
          ? _customCategoryController.text.trim()
          : _selectedCategory!;
          
      Navigator.pop(context, <String, dynamic>{
        'topic': _debateTitleController.text.trim(),
        'affirmativeName': _affirmativeNameController.text.trim(),
        'negativeName': _negativeNameController.text.trim(),
        'affirmativeTeam2': _teamSize == '2v2' ? _affirmativeTeam2Controller.text.trim() : null,
        'negativeTeam2': _teamSize == '2v2' ? _negativeTeam2Controller.text.trim() : null,
        'category': category,
        'teamSize': _teamSize,
        'isScheduled': _isScheduled,
        'scheduledTime': _scheduledTime,
        'isPrivate': _isPrivate,
        'password': _isPrivate ? _passwordController.text.trim() : null,
      });
    }
  }
}

class _PasswordValidationDialog extends StatefulWidget {
  final String requiredPassword;
  
  const _PasswordValidationDialog({
    required this.requiredPassword,
  });

  @override
  State<_PasswordValidationDialog> createState() => _PasswordValidationDialogState();
}

class _PasswordValidationDialogState extends State<_PasswordValidationDialog> {
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isValidating = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _validatePassword() async {
    if (_isValidating) return;
    
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    final enteredPassword = _passwordController.text.trim();
    
    if (enteredPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password';
        _isValidating = false;
      });
      return;
    }

    // Add a small delay to prevent rapid submissions
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (enteredPassword == widget.requiredPassword) {
      // Password is correct, close dialog and return true
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Password is incorrect
      setState(() {
        _errorMessage = 'Incorrect password. Please try again.';
        _isValidating = false;
      });
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock, color: Colors.orange),
          SizedBox(width: 8),
          Text('Private Room'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This room is password protected. Please enter the password to continue:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            enabled: !_isValidating,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key),
              hintText: 'Enter room password',
              errorText: _errorMessage,
            ),
            onSubmitted: (_) => _validatePassword(),
          ),
          if (_isValidating) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Validating...', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isValidating ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValidating ? null : _validatePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isValidating 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Enter'),
        ),
      ],
    );
  }
}