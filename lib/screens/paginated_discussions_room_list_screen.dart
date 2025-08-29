import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/challenge_bell.dart';
import '../features/discussion/providers/paginated_rooms_provider.dart';
import 'create_discussion_room_screen.dart';
import 'debates_discussions_screen.dart';
import '../services/theme_service.dart';
import '../services/accessibility_service.dart';
import '../services/responsive_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/logging/app_logger.dart';

class PaginatedDiscussionsRoomListScreen extends ConsumerStatefulWidget {
  const PaginatedDiscussionsRoomListScreen({super.key});

  @override
  ConsumerState<PaginatedDiscussionsRoomListScreen> createState() => _PaginatedDiscussionsRoomListScreenState();
}

class _PaginatedDiscussionsRoomListScreenState extends ConsumerState<PaginatedDiscussionsRoomListScreen> {
  // Purple theme colors
  static const Color primaryPurple = Color(0xFF8B5CF6);

  final ThemeService _themeService = ThemeService();
  final AccessibilityService _accessibilityService = AccessibilityService();
  final ResponsiveService _responsiveService = ResponsiveService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedRoomsProvider.notifier).loadInitial();
    });
    
    // Set up infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more when near bottom
      final paginationState = ref.read(paginatedRoomsProvider);
      if (paginationState.canLoadMore) {
        ref.read(paginatedRoomsProvider.notifier).loadMore();
      }
    }
  }

  void _joinRoom(Map<String, dynamic> roomData) {
    AppLogger().debug('📋 Attempting to join room: ${roomData['name']}');
    AppLogger().debug('📋 Room data: $roomData');
    
    final isPrivate = roomData['isPrivate'] as bool? ?? false;
    AppLogger().debug('🏁 Is room private: $isPrivate');
    
    if (isPrivate) {
      AppLogger().debug('🏁 Showing password dialog for private room');
      _showPasswordDialog(roomData);
    } else {
      AppLogger().debug('🏁 Room is public, navigating directly');
      _navigateToRoom(roomData);
    }
  }

  void _showPasswordDialog(Map<String, dynamic> roomData) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This room requires a password to enter.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _validateAndJoin(roomData, passwordController.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _validateAndJoin(roomData, passwordController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _validateAndJoin(Map<String, dynamic> roomData, String password) {
    final correctPassword = roomData['password'] as String? ?? '';
    
    if (password == correctPassword) {
      Navigator.of(context).pop(); // Close dialog
      _navigateToRoom(roomData);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToRoom(Map<String, dynamic> roomData) {
    AppLogger().debug('🚀 Navigating to room: ${roomData['name']} with ID: ${roomData['id']}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebatesDiscussionsScreen(
          roomId: roomData['id'],
          roomName: roomData['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(paginatedRoomsProvider);
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
      appBar: AppBar(
        backgroundColor: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        elevation: 0,
        title: Semantics(
          header: true,
          label: '${l10n.debates} screen. ${_accessibilityService.getParticipantCountSemanticLabel(paginationState.items.length)} available.',
          child: Text(
            l10n.debates,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              fontSize: 20 * _accessibilityService.textScaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
        actions: [
          Semantics(
            label: 'Challenge notifications',
            hint: 'Tap to view pending challenges',
            child: _buildNeumorphicAppBarIcon(
              const ChallengeBell(iconColor: Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Header section with stats
          Container(
            margin: _responsiveService.getResponsiveMargin(context),
            padding: _responsiveService.getResponsivePadding(context),
            constraints: BoxConstraints(
              maxWidth: _responsiveService.getMaxContentWidth(context),
            ),
            decoration: BoxDecoration(
              color: _themeService.isDarkMode 
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFFF0F0F3),
              borderRadius: BorderRadius.circular(
                _responsiveService.getBorderRadius(context, type: BorderRadiusType.large),
              ),
              boxShadow: [
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.black.withValues(alpha: 0.6)
                      : const Color(0xFFA3B1C6).withValues(alpha: 0.4),
                  offset: const Offset(3, 3),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.9),
                  offset: const Offset(-3, -3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        label: '${l10n.activeDiscussions} section',
                        child: Text(
                          l10n.activeDiscussions,
                          style: TextStyle(
                            color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 18 * _accessibilityService.textScaleFactor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: l10n.roomsAvailable(paginationState.items.length),
                        child: Text(
                          l10n.roomsAvailable(paginationState.items.length),
                          style: TextStyle(
                            color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 14 * _accessibilityService.textScaleFactor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: l10n.createRoom,
                  hint: 'Tap to create a new discussion room',
                  button: true,
                  child: _buildNeumorphicIconButton(
                    Icons.add_rounded,
                    primaryPurple,
                    () {
                      _accessibilityService.provideHapticFeedback();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateDiscussionRoomScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Rooms list
          Expanded(
            child: paginationState.isEmpty && !paginationState.isLoading
                ? _buildEmptyState()
                : _buildRoomsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: _themeService.isDarkMode ? Colors.white54 : Colors.black38,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: l10n.noActiveDiscussions,
            child: Text(
              l10n.noActiveDiscussions,
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 18 * _accessibilityService.textScaleFactor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.beFirstToCreate,
            child: Text(
              l10n.beFirstToCreate,
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white54 : Colors.black38,
                fontSize: 14 * _accessibilityService.textScaleFactor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateDiscussionRoomScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList() {
    final paginationState = ref.watch(paginatedRoomsProvider);
    final deviceType = _responsiveService.getDeviceType(context);
    
    // Use grid layout for larger screens (tablet/desktop)
    // Note: App is locked to portrait orientation
    if (deviceType != DeviceType.mobile) {
      return _buildResponsiveGrid(paginationState);
    }
    
    // Use list layout for mobile devices
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(paginatedRoomsProvider.notifier).loadInitial();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: _responsiveService.getResponsivePadding(context).copyWith(top: 0),
        itemCount: paginationState.items.length + (paginationState.canLoadMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == paginationState.items.length) {
            // Loading indicator at bottom
            return Padding(
              padding: _responsiveService.getResponsivePadding(context),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          
          final room = paginationState.items[index];
          return _buildRoomCard(room);
        },
      ),
    );
  }

  Widget _buildResponsiveGrid(dynamic paginationState) {
    final columns = _responsiveService.getResponsiveColumnCount(context, maxColumns: 3);
    final spacing = _responsiveService.getGridSpacing(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(paginatedRoomsProvider.notifier).loadInitial();
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: _responsiveService.getResponsivePadding(context).copyWith(top: 0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 1.2, // Adjust based on content
        ),
        itemCount: paginationState.items.length + (paginationState.canLoadMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == paginationState.items.length) {
            // Loading indicator at bottom
            return const Center(child: CircularProgressIndicator());
          }
          
          final room = paginationState.items[index];
          return _buildRoomCard(room);
        },
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final isPrivate = room['isPrivate'] as bool? ?? false;
    final participantCount = room['participantCount'] as int? ?? 0;
    final roomName = room['name'] ?? 'Unnamed Room';
    final roomDescription = room['description'] ?? '';
    final l10n = AppLocalizations.of(context);
    
    // Create comprehensive accessibility label
    String accessibilityLabel = '$roomName.';
    if (roomDescription.isNotEmpty) {
      accessibilityLabel += ' $roomDescription.';
    }
    accessibilityLabel += ' ${l10n.participantCount(participantCount)}.';
    if (isPrivate) {
      accessibilityLabel += ' ${l10n.privateRoom}.';
    }
    accessibilityLabel += ' Double tap to join.';
    
    return Container(
      margin: EdgeInsets.only(
        bottom: _responsiveService.getDeviceType(context) == DeviceType.mobile ? 16 : 0,
      ),
      constraints: BoxConstraints(
        minHeight: _responsiveService.hasPixelOverflowRisk(context) ? 100 : 120,
      ),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(
          _responsiveService.getBorderRadius(context, type: BorderRadiusType.normal),
        ),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.9),
            offset: const Offset(-3, -3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Semantics(
        label: accessibilityLabel,
        button: true,
        child: InkWell(
          onTap: () {
            _accessibilityService.provideHapticFeedback();
            _joinRoom(room);
          },
          borderRadius: BorderRadius.circular(
            _responsiveService.getBorderRadius(context, type: BorderRadiusType.normal),
          ),
          child: Padding(
          padding: _responsiveService.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        roomName,
                        style: TextStyle(
                          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 16 * _accessibilityService.textScaleFactor * _responsiveService.getFontSizeMultiplier(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (isPrivate)
                    Icon(
                      Icons.lock,
                      color: primaryPurple,
                      size: _responsiveService.getIconSize(context, type: IconSizeType.small),
                    ),
                ],
              ),
              if (room['description'] != null && room['description'].isNotEmpty) ...[
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Text(
                    roomDescription,
                    style: TextStyle(
                      color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 14 * _accessibilityService.textScaleFactor * _responsiveService.getFontSizeMultiplier(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    color: primaryPurple,
                    size: _responsiveService.getIconSize(context, type: IconSizeType.small),
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Text(
                      l10n.participantCount(participantCount),
                      style: TextStyle(
                        color: _themeService.isDarkMode ? Colors.white60 : Colors.black45,
                        fontSize: 12 * _accessibilityService.textScaleFactor * _responsiveService.getFontSizeMultiplier(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryPurple.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        l10n.join,
                        style: TextStyle(
                          color: primaryPurple,
                          fontSize: 12 * _accessibilityService.textScaleFactor * _responsiveService.getFontSizeMultiplier(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicAppBarIcon(Widget child) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.4),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.9),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildNeumorphicIconButton(IconData icon, Color iconColor, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF0F0F3),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.6)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.4),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.9),
              offset: const Offset(-3, -3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }
}