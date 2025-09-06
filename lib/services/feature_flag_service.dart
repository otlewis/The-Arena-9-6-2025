import 'dart:async';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service for managing remote feature flags
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  
  // Cache feature flags to avoid repeated API calls
  final Map<String, bool> _flagCache = {};
  DateTime? _lastFetch;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Check if payments are enabled (kill switch)
  Future<bool> isPaymentsEnabled() async {
    return await _getFlag('payments_enabled', defaultValue: false);
  }

  /// Check if premium features are enabled
  Future<bool> isPremiumEnabled() async {
    return await _getFlag('premium_enabled', defaultValue: true);
  }

  /// Check if gift system is enabled
  Future<bool> isGiftsEnabled() async {
    return await _getFlag('gifts_enabled', defaultValue: true);
  }

  /// Check if challenges are enabled
  Future<bool> isChallengesEnabled() async {
    return await _getFlag('challenges_enabled', defaultValue: true);
  }

  /// Check if sandbox purchases are allowed
  Future<bool> isSandboxEnabled() async {
    return await _getFlag('sandbox_enabled', defaultValue: true);
  }

  /// Generic method to get any feature flag
  Future<bool> _getFlag(String flagName, {bool defaultValue = false}) async {
    try {
      // Check cache first
      if (_flagCache.containsKey(flagName) && 
          _lastFetch != null && 
          DateTime.now().difference(_lastFetch!) < _cacheTimeout) {
        return _flagCache[flagName] ?? defaultValue;
      }

      // Fetch from Appwrite
      await _fetchFlags();
      return _flagCache[flagName] ?? defaultValue;
      
    } catch (e) {
      AppLogger().warning('Failed to get feature flag $flagName: $e');
      return defaultValue;
    }
  }

  /// Fetch all feature flags from Appwrite
  Future<void> _fetchFlags() async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'feature_flags',
      );

      // Update cache
      _flagCache.clear();
      for (final doc in response.documents) {
        final flagName = doc.data['name'] as String;
        final isEnabled = doc.data['enabled'] as bool;
        _flagCache[flagName] = isEnabled;
      }
      
      _lastFetch = DateTime.now();
      AppLogger().debug('🏁 Feature flags loaded: $_flagCache');
      
    } catch (e) {
      AppLogger().warning('Failed to fetch feature flags: $e');
      // Keep existing cache if fetch fails
    }
  }

  /// Manually refresh flags (call on app start or critical moments)
  Future<void> refreshFlags() async {
    _lastFetch = null; // Force refresh
    await _fetchFlags();
  }

  /// Clear cache (for testing)
  void clearCache() {
    _flagCache.clear();
    _lastFetch = null;
  }
}