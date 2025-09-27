import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

class RankingSyncService {
  static final RankingSyncService _instance = RankingSyncService._internal();
  factory RankingSyncService() => _instance;
  RankingSyncService._internal();
  
  final AppwriteService _appwriteService = AppwriteService();
  Functions? _functions;
  
  void initialize() {
    _functions ??= Functions(_appwriteService.client);
  }
  
  /// Sync rankings for a specific user
  Future<Map<String, dynamic>?> syncUserRanking(String userId) async {
    try {
      AppLogger().info('🎯 Syncing rankings for user: $userId');
      
      final execution = await _functions!.createExecution(
        functionId: 'ranking-sync',
        body: jsonEncode({
          'action': 'sync-user',
          'userId': userId,
        }),
      );
      
      if (execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        if (response['success']) {
          AppLogger().info('✅ Successfully synced user ranking');
          return response['data'];
        } else {
          AppLogger().error('❌ Function returned error: ${response['error']}');
          return null;
        }
      } else {
        AppLogger().error('❌ Function execution failed: ${execution.errors}');
        return null;
      }
    } catch (e) {
      AppLogger().error('❌ Error syncing user ranking: $e');
      return null;
    }
  }
  
  /// Sync rankings for all users (admin function)
  Future<Map<String, dynamic>?> syncAllRankings() async {
    try {
      AppLogger().info('🚀 Starting full ranking sync...');
      
      final execution = await _functions!.createExecution(
        functionId: 'ranking-sync',
        body: jsonEncode({
          'action': 'sync-all',
        }),
      );
      
      if (execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        AppLogger().info('✅ Full sync completed: ${response['message']}');
        return response['data'];
      } else {
        AppLogger().error('❌ Full sync failed: ${execution.errors}');
        return null;
      }
    } catch (e) {
      AppLogger().error('❌ Error in full sync: $e');
      return null;
    }
  }
  
  /// Sync rankings for multiple users
  Future<List<Map<String, dynamic>>?> syncMultipleUsers(List<String> userIds) async {
    try {
      AppLogger().info('🎯 Syncing rankings for ${userIds.length} users');
      
      final execution = await _functions!.createExecution(
        functionId: 'ranking-sync',
        body: jsonEncode({
          'action': 'sync-multiple',
          'userIds': userIds,
        }),
      );
      
      if (execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        if (response['success']) {
          AppLogger().info('✅ Multiple user sync completed');
          return List<Map<String, dynamic>>.from(response['data']);
        }
      }
      
      AppLogger().error('❌ Multiple user sync failed');
      return null;
    } catch (e) {
      AppLogger().error('❌ Error syncing multiple users: $e');
      return null;
    }
  }
  
  /// Recalculate global ranks only (faster operation)
  Future<bool> recalculateGlobalRanks() async {
    try {
      AppLogger().info('🔄 Recalculating global ranks...');
      
      final execution = await _functions!.createExecution(
        functionId: 'ranking-sync',
        body: jsonEncode({
          'action': 'recalculate-ranks',
        }),
      );
      
      if (execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        if (response['success']) {
          AppLogger().info('✅ Global ranks recalculated');
          return true;
        }
      }
      
      AppLogger().error('❌ Failed to recalculate global ranks');
      return false;
    } catch (e) {
      AppLogger().error('❌ Error recalculating ranks: $e');
      return false;
    }
  }
}