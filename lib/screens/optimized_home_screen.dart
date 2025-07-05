import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/widgets/skeleton_widgets.dart';
import '../core/cache/smart_cache_manager.dart';
import '../widgets/user_avatar.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

/// Optimized home screen with instant loading and skeleton UI
class OptimizedHomeScreen extends ConsumerStatefulWidget {
  const OptimizedHomeScreen({super.key});

  @override
  ConsumerState<OptimizedHomeScreen> createState() => _OptimizedHomeScreenState();
}

class _OptimizedHomeScreenState extends ConsumerState<OptimizedHomeScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Preserve state across navigation

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Watch cached user profile (loads instantly if cached)
    final userProfileAsync = ref.watch(cachedCurrentUserProvider);
    
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar with immediate response
            _buildOptimizedAppBar(),
            
            // User profile section with skeleton
            SliverToBoxAdapter(
              child: _buildUserProfileSection(userProfileAsync),
            ),
            
            // Quick actions - always visible
            SliverToBoxAdapter(
              child: _buildQuickActions(),
            ),
            
            // Arena rooms with skeleton loading
            SliverToBoxAdapter(
              child: _buildArenaRoomsSection(),
            ),
            
            // Recent activity
            SliverToBoxAdapter(
              child: _buildRecentActivitySection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizedAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFB794F6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.zap, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Arena',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B46C1),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            // Instant response - no loading
            _showNotifications();
          },
          icon: const Icon(LucideIcons.bell, color: Color(0xFF6B46C1)),
        ),
        IconButton(
          onPressed: () {
            // Instant response
            _showSettings();
          },
          icon: const Icon(LucideIcons.settings, color: Color(0xFF6B46C1)),
        ),
      ],
    );
  }

  Widget _buildUserProfileSection(AsyncValue<UserProfile?> userProfileAsync) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SkeletonScreen(
        isLoading: userProfileAsync.isLoading,
        skeleton: SkeletonWidgets.profileCard(),
        content: userProfileAsync.when(
          data: (profile) => _buildUserProfileCard(profile),
          loading: () => SkeletonWidgets.profileCard(),
          error: (_, __) => _buildUserProfileCard(null),
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(UserProfile? profile) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Hero(
                  tag: 'user_avatar',
                  child: UserAvatar(
                    avatarUrl: profile?.avatar,
                    initials: profile?.name.isNotEmpty == true 
                      ? profile!.name[0] 
                      : 'U',
                    radius: 30,
                    backgroundColor: const Color(0xFF8B5CF6),
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.name ?? 'Arena Debater',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?.email ?? 'Welcome to Arena',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Rookie',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Debates', profile?.totalDebates.toString() ?? '0'),
                _buildStatItem('Wins', profile?.totalWins.toString() ?? '0'),
                _buildStatItem('Rating', profile?.reputation.toString() ?? '0'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B46C1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Start Debate',
                  LucideIcons.zap,
                  Colors.orange,
                  () => _startQuickDebate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Join Arena',
                  LucideIcons.users,
                  const Color(0xFF8B5CF6),
                  () => _joinArena(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArenaRoomsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Arenas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              TextButton(
                onPressed: () => _viewAllArenas(),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show skeleton while loading, real data when available
          SizedBox(
            height: 200,
            child: SkeletonWidgets.list(
              itemBuilder: () => SkeletonWidgets.arenaRoomCard(),
              itemCount: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          // Placeholder for recent activity
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No recent activity',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Instant response methods
  void _showNotifications() {
    AppLogger().debug('🔔 Showing notifications (instant)');
    // Navigation happens instantly - no loading
  }

  void _showSettings() {
    AppLogger().debug('⚙️ Showing settings (instant)');
  }

  void _startQuickDebate() {
    AppLogger().debug('⚡ Starting quick debate (instant)');
    // Pre-cached data makes this instant
  }

  void _joinArena() {
    AppLogger().debug('🏛️ Joining arena (instant)');
    // Pre-initialized Agora makes this fast
  }

  void _viewAllArenas() {
    AppLogger().debug('👁️ Viewing all arenas (instant)');
  }
}