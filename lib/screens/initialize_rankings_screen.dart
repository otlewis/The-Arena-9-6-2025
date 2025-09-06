import 'package:flutter/material.dart';
import 'dart:math';
import '../services/appwrite_service.dart';
import '../services/gamified_ranking_service.dart';
import '../core/logging/app_logger.dart';

class InitializeRankingsScreen extends StatefulWidget {
  const InitializeRankingsScreen({super.key});

  @override
  State<InitializeRankingsScreen> createState() => _InitializeRankingsScreenState();
}

class _InitializeRankingsScreenState extends State<InitializeRankingsScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  bool _isRunning = false;
  List<String> _logs = [];
  int _successCount = 0;
  int _totalUsers = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initialize Rankings'),
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  '🎮 Initialize Rankings System',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will create sample rankings for all existing users',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isRunning ? null : _initializeRankings,
                  child: Text(_isRunning ? 'Running...' : 'Start Initialization'),
                ),
                if (_successCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      '✅ Initialized $_successCount/$_totalUsers users',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) => Text(
                _logs[index],
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _logs[index].contains('✅') ? Colors.green
                      : _logs[index].contains('❌') ? Colors.red
                      : _logs[index].contains('💠') ? Colors.blue
                      : _logs[index].contains('💎') ? Colors.purple
                      : _logs[index].contains('🥇') ? Colors.orange
                      : _logs[index].contains('🥈') ? Colors.grey
                      : _logs[index].contains('🥉') ? Colors.brown
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _initializeRankings() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
      _successCount = 0;
      _totalUsers = 0;
    });

    try {
      _addLog('🚀 Initializing rankings for existing users...\n');

      // Get current month key
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      _addLog('📅 Current month: $monthKey\n');

      // Get all users from the database
      _addLog('📊 Fetching existing users...');
      final usersResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [],
      );

      final users = usersResponse.documents;
      _totalUsers = users.length;
      _addLog('✅ Found ${users.length} users\n');

      if (users.isEmpty) {
        _addLog('⚠️  No users found in database. Create some user accounts first!');
        setState(() => _isRunning = false);
        return;
      }

      _addLog('🎯 Creating initial rankings with sample data...\n');

      final random = Random();

      for (int i = 0; i < users.length; i++) {
        final user = users[i];
        final userId = user.$id;
        final userName = user.data['name'] ?? 'User $i';

        try {
          // Generate random but realistic-looking stats
          final rankPosition = i + 1;
          final isTopTier = rankPosition <= 3;
          final isMidTier = rankPosition <= 10;

          int monthlyPoints = 0;
          int monthlyWins = 0;
          int monthlyLosses = 0;
          int winStreak = 0;
          String tier = 'bronze';
          String tierEmoji = '🥉';

          if (isTopTier) {
            // Top 3 users - Diamond/Platinum tier
            monthlyPoints = 7500 + random.nextInt(5000); // 7500-12500 points
            monthlyWins = 25 + random.nextInt(15); // 25-40 wins
            monthlyLosses = random.nextInt(5); // 0-5 losses
            winStreak = 5 + random.nextInt(10); // 5-15 streak
            if (monthlyPoints > 10000) {
              tier = 'diamond';
              tierEmoji = '💠';
            } else {
              tier = 'platinum';
              tierEmoji = '💎';
            }
          } else if (isMidTier) {
            // Top 4-10 users - Gold/Silver tier
            monthlyPoints = 1500 + random.nextInt(4000); // 1500-5500 points
            monthlyWins = 10 + random.nextInt(15); // 10-25 wins
            monthlyLosses = 3 + random.nextInt(7); // 3-10 losses
            winStreak = random.nextInt(5); // 0-5 streak
            if (monthlyPoints > 3500) {
              tier = 'gold';
              tierEmoji = '🥇';
            } else {
              tier = 'silver';
              tierEmoji = '🥈';
            }
          } else {
            // Rest of users - Silver/Bronze tier
            monthlyPoints = random.nextInt(1500); // 0-1500 points
            monthlyWins = random.nextInt(10); // 0-10 wins
            monthlyLosses = random.nextInt(10); // 0-10 losses
            winStreak = 0;
            if (monthlyPoints > 500) {
              tier = 'silver';
              tierEmoji = '🥈';
            } else {
              tier = 'bronze';
              tierEmoji = '🥉';
            }
          }

          // Add some activity XP
          final activityXP = 50 + random.nextInt(200); // 50-250 XP

          // Check if ranking already exists
          final existingRankings = await _appwriteService.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'monthly_rankings',
            queries: [],
          );

          // Look for existing record for this user and month
          dynamic existingRecord;
          try {
            existingRecord = existingRankings.documents.firstWhere(
              (doc) => doc.data['userId'] == userId && doc.data['monthKey'] == monthKey,
            );
          } catch (e) {
            existingRecord = null;
          }

          if (existingRecord != null) {
            // Update existing record
            await _appwriteService.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'monthly_rankings',
              documentId: existingRecord.$id,
              data: {
                'monthlyPoints': monthlyPoints,
                'monthlyWins': monthlyWins,
                'monthlyLosses': monthlyLosses,
                'currentWinStreak': winStreak,
                'bestWinStreak': winStreak,
                'activityXP': activityXP,
                'tier': tier,
                'globalRank': rankPosition,
                'lastUpdated': DateTime.now().toIso8601String(),
              },
            );
            _addLog('📝 #$rankPosition $tierEmoji $userName - $monthlyPoints pts');
          } else {
            // Create new ranking record
            await _appwriteService.databases.createDocument(
              databaseId: 'arena_db',
              collectionId: 'monthly_rankings',
              documentId: 'unique()',
              data: {
                'userId': userId,
                'monthKey': monthKey,
                'monthlyPoints': monthlyPoints,
                'monthlyWins': monthlyWins,
                'monthlyLosses': monthlyLosses,
                'currentWinStreak': winStreak,
                'bestWinStreak': winStreak,
                'activityXP': activityXP,
                'tier': tier,
                'globalRank': rankPosition,
                'lastUpdated': DateTime.now().toIso8601String(),
              },
            );
            _addLog('✨ #$rankPosition $tierEmoji $userName - $monthlyPoints pts');
          }

          setState(() => _successCount++);
        } catch (e) {
          _addLog('❌ Error for $userName: ${e.toString().split('\n').first}');
        }
      }

      _addLog('\n' + '═' * 30);
      _addLog('🎉 Rankings initialized successfully!');
      _addLog('📊 Created rankings for $_successCount/${users.length} users');
      _addLog('\n🎮 Go back and tap "Rankings" to see the leaderboard!');
    } catch (e) {
      _addLog('💥 Error: ${e.toString()}');
    }

    setState(() => _isRunning = false);
  }
}