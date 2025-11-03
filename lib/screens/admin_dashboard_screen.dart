import 'package:flutter/material.dart';
import '../services/admin_analytics_service.dart';
import '../core/logging/app_logger.dart';
import 'admin_user_management_screen.dart';

/// Admin Dashboard Screen
/// Comprehensive analytics and management interface for administrators
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminAnalyticsService _analytics = AdminAnalyticsService();

  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _topDebaters = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      AppLogger().info('📊 ADMIN DASHBOARD: Loading data...');

      final results = await Future.wait([
        _analytics.getDashboardMetrics(),
        _analytics.getTopDebaters(limit: 5),
      ]);

      if (mounted) {
        setState(() {
          _metrics = results[0] as Map<String, dynamic>;
          _topDebaters = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }

      AppLogger().info('✅ ADMIN DASHBOARD: Data loaded successfully');
    } catch (e) {
      AppLogger().error('❌ ADMIN DASHBOARD: Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.people, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminUserManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key Metrics Section
                    _buildSectionHeader('Key Metrics'),
                    const SizedBox(height: 12),
                    _buildMetricsGrid(isSmallScreen),
                    const SizedBox(height: 24),

                    // User Stats Section
                    _buildSectionHeader('User Statistics'),
                    const SizedBox(height: 12),
                    _buildUserStatsGrid(isSmallScreen),
                    const SizedBox(height: 24),

                    // Debate Stats Section
                    _buildSectionHeader('Debate Statistics'),
                    const SizedBox(height: 12),
                    _buildDebateStatsGrid(isSmallScreen),
                    const SizedBox(height: 24),

                    // Economy Section
                    _buildSectionHeader('Economy'),
                    const SizedBox(height: 12),
                    _buildEconomyStats(isSmallScreen),
                    const SizedBox(height: 24),

                    // Top Debaters Section
                    _buildSectionHeader('Top Debaters'),
                    const SizedBox(height: 12),
                    _buildTopDebatersSection(isSmallScreen),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMetricsGrid(bool isSmallScreen) {
    final crossAxisCount = isSmallScreen ? 2 : 4;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isSmallScreen ? 1.3 : 1.5,
      children: [
        _buildMetricCard(
          'Total Users',
          _metrics['totalUsers']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
        ),
        _buildMetricCard(
          'Active Today',
          _metrics['activeUsersToday']?.toString() ?? '0',
          Icons.online_prediction,
          Colors.green,
        ),
        _buildMetricCard(
          'Total Debates',
          _metrics['totalDebates']?.toString() ?? '0',
          Icons.gavel,
          Colors.orange,
        ),
        _buildMetricCard(
          'This Week',
          _metrics['debatesThisWeek']?.toString() ?? '0',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildUserStatsGrid(bool isSmallScreen) {
    final crossAxisCount = isSmallScreen ? 2 : 3;
    final participationMetrics =
        _metrics['debateParticipation'] as Map<String, dynamic>? ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isSmallScreen ? 1.3 : 1.5,
      children: [
        _buildMetricCard(
          'Active (7 days)',
          _metrics['activeUsersWeek']?.toString() ?? '0',
          Icons.how_to_reg,
          Colors.teal,
        ),
        _buildMetricCard(
          'New This Week',
          _metrics['newUsersThisWeek']?.toString() ?? '0',
          Icons.person_add,
          Colors.cyan,
        ),
        _buildMetricCard(
          'Participants',
          participationMetrics['totalParticipants']?.toString() ?? '0',
          Icons.sports,
          Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildDebateStatsGrid(bool isSmallScreen) {
    final crossAxisCount = isSmallScreen ? 2 : 3;
    final acceptanceRate = _metrics['challengeAcceptanceRate'] ?? 0.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isSmallScreen ? 1.3 : 1.5,
      children: [
        _buildMetricCard(
          'Total Challenges',
          _metrics['totalChallenges']?.toString() ?? '0',
          Icons.flag,
          Colors.red,
        ),
        _buildMetricCard(
          'Acceptance Rate',
          '${acceptanceRate.toStringAsFixed(1)}%',
          Icons.check_circle,
          Colors.green,
        ),
        _buildMetricCard(
          'Debates/Week',
          _metrics['debatesThisWeek']?.toString() ?? '0',
          Icons.schedule,
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildEconomyStats(bool isSmallScreen) {
    final totalCoins = _metrics['totalCoins'] ?? 0;
    final avgCoinsPerUser = _metrics['totalUsers'] != null &&
            _metrics['totalUsers'] > 0
        ? (totalCoins / _metrics['totalUsers']).toStringAsFixed(0)
        : '0';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallScreen ? 2 : 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isSmallScreen ? 1.3 : 1.5,
      children: [
        _buildMetricCard(
          'Total Coins',
          totalCoins.toString(),
          Icons.monetization_on,
          Colors.yellow,
        ),
        _buildMetricCard(
          'Avg Per User',
          avgCoinsPerUser,
          Icons.account_balance_wallet,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDebatersSection(bool isSmallScreen) {
    if (_topDebaters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No debaters yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topDebaters.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey[800],
          height: 1,
        ),
        itemBuilder: (context, index) {
          final debater = _topDebaters[index];
          final rank = index + 1;
          final name = debater['name'] ?? 'Unknown';
          final wins = debater['totalWins'] ?? 0;
          final losses = debater['totalLosses'] ?? 0;
          final reputation = debater['reputation'] ?? 0;
          final coins = debater['coinBalance'] ?? 0;

          Color rankColor = Colors.grey;
          if (rank == 1) rankColor = Colors.amber;
          if (rank == 2) rankColor = Colors.grey[300]!;
          if (rank == 3) rankColor = Colors.brown[300]!;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: rankColor.withOpacity(0.2),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'W: $wins | L: $losses | Rep: $reputation | Coins: $coins',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            trailing: Icon(
              Icons.emoji_events,
              color: rankColor,
            ),
          );
        },
      ),
    );
  }
}
