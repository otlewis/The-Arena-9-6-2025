import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/gamified_ranking_service.dart';
import 'animated_fade_in.dart';

class RankingsCard extends StatefulWidget {
  const RankingsCard({super.key});

  @override
  State<RankingsCard> createState() => _RankingsCardState();
}

class _RankingsCardState extends State<RankingsCard> {
  final GamifiedRankingService _rankingService = GetIt.instance<GamifiedRankingService>();
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final leaderboard = await _rankingService.getCurrentLeaderboard(limit: 9);
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
          // Fall back to mock data if real data fails
          _leaderboard = _generateMockData();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Image.asset(
                    'assets/icons/rank1.png',
                    width: 24,
                    height: 24,
                    color: isDarkMode ? Colors.white : const Color(0xFF6B46C1),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rankings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Rankings Grid (3x3 = 9 items)
              _isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _leaderboard.length.clamp(0, 9),
                      itemBuilder: (context, index) {
                        final user = _leaderboard[index];
                        return _buildRankingItem(
                          context,
                          user['rank'] ?? (index + 1),
                          user['displayName'] ?? 'Unknown',
                          user['monthlyPoints'] ?? 0,
                          user['tierEmoji'] ?? '🥉',
                          isDarkMode,
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingItem(
    BuildContext context,
    int rank,
    String userName,
    int points,
    String tierEmoji,
    bool isDarkMode,
  ) {
    final rankColor = _getRankColor(rank);
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rankColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rank Number with Color
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // User Name
          Text(
            userName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          
          // Points and Tier
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tierEmoji,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 2),
              Text(
                '$points',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        return const Color(0xFF6B46C1); // Purple
    }
  }

  List<Map<String, dynamic>> _generateMockData() {
    final mockUsers = [
      {'rank': 1, 'displayName': 'Alex K.', 'monthlyPoints': 2450, 'tierEmoji': '💎'},
      {'rank': 2, 'displayName': 'Maria S.', 'monthlyPoints': 2100, 'tierEmoji': '💎'},
      {'rank': 3, 'displayName': 'John D.', 'monthlyPoints': 1850, 'tierEmoji': '🥇'},
      {'rank': 4, 'displayName': 'Sarah L.', 'monthlyPoints': 1600, 'tierEmoji': '🥇'},
      {'rank': 5, 'displayName': 'Mike R.', 'monthlyPoints': 1200, 'tierEmoji': '🥈'},
      {'rank': 6, 'displayName': 'Emma W.', 'monthlyPoints': 900, 'tierEmoji': '🥈'},
      {'rank': 7, 'displayName': 'David C.', 'monthlyPoints': 650, 'tierEmoji': '🥈'},
      {'rank': 8, 'displayName': 'Lisa M.', 'monthlyPoints': 400, 'tierEmoji': '🥉'},
      {'rank': 9, 'displayName': 'Ryan P.', 'monthlyPoints': 250, 'tierEmoji': '🥉'},
    ];
    return mockUsers;
  }
}