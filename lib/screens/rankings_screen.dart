import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/gamified_ranking_service.dart';
import '../services/appwrite_service.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final GamifiedRankingService _rankingService = GetIt.instance<GamifiedRankingService>();
  final AppwriteService _appwriteService = AppwriteService();
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final leaderboard = await _rankingService.getCurrentLeaderboard(limit: 50);
      
      // If no real data, use mock data
      if (leaderboard.isEmpty) {
        setState(() {
          _leaderboard = _generateMockData();
          _isLoading = false;
        });
        return;
      }

      // For each user, get their profile for avatar
      for (var user in leaderboard) {
        try {
          final profile = await _appwriteService.getUserProfile(user['userId']);
          if (profile != null) {
            user['avatar'] = profile.avatar;
            user['displayName'] = profile.displayName;
          }
        } catch (e) {
          // Keep the existing display name if profile fetch fails
        }
      }

      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _leaderboard = _generateMockData();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Rankings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showRankingInfoDialog(context, isDarkMode),
            tooltip: 'How rankings work',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _leaderboard.length,
                itemBuilder: (context, index) {
                  final user = _leaderboard[index];
                  return _buildRankingCard(
                    context,
                    rank: user['rank'] ?? (index + 1),
                    name: user['displayName'] ?? 'Unknown User',
                    avatar: user['avatar'],
                    points: user['monthlyPoints'] ?? 0,
                    tier: user['tier'] ?? 'bronze',
                    wins: user['wins'] ?? 0,
                    streak: user['winStreak'] ?? 0,
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildRankingCard(
    BuildContext context, {
    required int rank,
    required String name,
    String? avatar,
    required int points,
    required String tier,
    required int wins,
    required int streak,
    required bool isDarkMode,
  }) {
    // Special styling for top 3
    final isTopThree = rank <= 3;
    final rankColor = _getRankColor(rank);
    final tierColor = _getTierColor(tier);
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTopThree ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? (isTopThree ? const Color(0xFF2D2D2D) : const Color(0xFF252525))
            : (isTopThree ? Colors.white : Colors.white.withOpacity(0.9)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isTopThree
            ? [
                BoxShadow(
                  color: rankColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: isTopThree ? 40 : 35,
              height: isTopThree ? 40 : 35,
              decoration: BoxDecoration(
                color: isTopThree ? rankColor : Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isTopThree
                    ? _getRankIcon(rank)
                    : Text(
                        '$rank',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Avatar
            Container(
              width: isTopThree ? 55 : 50,
              height: isTopThree ? 55 : 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isTopThree ? rankColor : Colors.grey.withOpacity(0.3),
                  width: isTopThree ? 3 : 2,
                ),
              ),
              child: ClipOval(
                child: avatar != null && avatar.isNotEmpty
                    ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(name),
                      )
                    : _buildDefaultAvatar(name),
              ),
            ),
            const SizedBox(width: 12),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: isTopThree ? 17 : 15,
                            fontWeight: isTopThree ? FontWeight.bold : FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (streak >= 3) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 10)),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tier.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tierColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$wins wins',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Points Badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTopThree ? 16 : 12,
                vertical: isTopThree ? 10 : 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isTopThree
                      ? [rankColor.withOpacity(0.8), rankColor]
                      : [tierColor.withOpacity(0.8), tierColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    points >= 1000 ? '${(points / 1000).toStringAsFixed(1)}k' : '$points',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTopThree ? 18 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'pts',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    final initials = name.split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .take(2)
        .join();
    
    return Container(
      color: const Color(0xFF6B46C1),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return const Text('🥇', style: TextStyle(fontSize: 24));
      case 2:
        return const Text('🥈', style: TextStyle(fontSize: 24));
      case 3:
        return const Text('🥉', style: TextStyle(fontSize: 24));
      default:
        return Text(
          '$rank',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return const Color(0xFF00D4FF); // Cyan
      case 'platinum':
        return const Color(0xFF9945FF); // Purple
      case 'gold':
        return const Color(0xFFFFD700); // Gold
      case 'silver':
        return const Color(0xFF8C8C8C); // Silver
      case 'bronze':
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _generateMockData() {
    return [
      {'rank': 1, 'displayName': 'Josh Rees', 'monthlyPoints': 12500, 'tier': 'diamond', 'wins': 38, 'winStreak': 12},
      {'rank': 2, 'displayName': 'Sarah Chen', 'monthlyPoints': 10200, 'tier': 'diamond', 'wins': 32, 'winStreak': 8},
      {'rank': 3, 'displayName': 'Mike Johnson', 'monthlyPoints': 8750, 'tier': 'platinum', 'wins': 28, 'winStreak': 5},
      {'rank': 4, 'displayName': 'Emma Wilson', 'monthlyPoints': 5400, 'tier': 'gold', 'wins': 22, 'winStreak': 3},
      {'rank': 5, 'displayName': 'David Lee', 'monthlyPoints': 3200, 'tier': 'gold', 'wins': 18, 'winStreak': 0},
      {'rank': 6, 'displayName': 'Lisa Martinez', 'monthlyPoints': 2100, 'tier': 'silver', 'wins': 14, 'winStreak': 2},
      {'rank': 7, 'displayName': 'Ryan Park', 'monthlyPoints': 1500, 'tier': 'silver', 'wins': 11, 'winStreak': 0},
      {'rank': 8, 'displayName': 'Amy Taylor', 'monthlyPoints': 900, 'tier': 'silver', 'wins': 8, 'winStreak': 1},
      {'rank': 9, 'displayName': 'Chris Brown', 'monthlyPoints': 450, 'tier': 'bronze', 'wins': 5, 'winStreak': 0},
      {'rank': 10, 'displayName': 'Nina Davis', 'monthlyPoints': 250, 'tier': 'bronze', 'wins': 3, 'winStreak': 0},
    ];
  }

  void _showRankingInfoDialog(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'How Rankings Work',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🏆 Ranking System',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rankings are determined by your monthly points, which are earned through:',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildInfoRow('✅ Winning debates:', '+100 base points', isDarkMode),
                _buildInfoRow('🔥 Win streaks:', 'Bonus multipliers (up to 10x)', isDarkMode),
                _buildInfoRow('📈 Tier bonuses:', 'Extra points vs higher tiers', isDarkMode),
                _buildInfoRow('🎯 Participation:', '+10 points for losses', isDarkMode),
                _buildInfoRow('⚡ Activities:', 'XP for room creation & gifts', isDarkMode),
                
                const SizedBox(height: 16),
                Text(
                  '🏅 Tier System',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                
                _buildTierRow('💠 Diamond:', '7500+ points', const Color(0xFF00D4FF), isDarkMode),
                _buildTierRow('💎 Platinum:', '3500+ points', const Color(0xFF9945FF), isDarkMode),
                _buildTierRow('🥇 Gold:', '1500+ points', const Color(0xFFFFD700), isDarkMode),
                _buildTierRow('🥈 Silver:', '500+ points', const Color(0xFF8C8C8C), isDarkMode),
                _buildTierRow('🥉 Bronze:', '0+ points', const Color(0xFFCD7F32), isDarkMode),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.star, color: Colors.orange),
                      const SizedBox(height: 4),
                      Text(
                        'Monthly Reset',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rankings reset every month. Top player gets 1 month free premium!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it!',
                style: TextStyle(
                  color: isDarkMode ? Colors.blue : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow(String emoji, String requirement, Color color, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}