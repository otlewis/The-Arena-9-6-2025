import 'dart:developer';
import 'package:appwrite/appwrite.dart';
import '../models/store_config.dart';
import '../services/appwrite_service.dart';

/// Service for managing dynamic store configuration from Appwrite
/// Handles caching, real-time updates, and fallback configurations
class StoreConfigService {
  // static const String _cacheKey = 'store_data_cache';
  // static const Duration _cacheExpiration = Duration(hours: 6);

  StoreData? _cachedStoreData;
  // DateTime? _cacheTimestamp;

  static final StoreConfigService _instance = StoreConfigService._internal();
  factory StoreConfigService() => _instance;
  StoreConfigService._internal();

  /// Initialize the store config service
  Future<void> initialize() async {
    try {
      await _loadFromCache();
      await refreshStoreConfig();
    } catch (e) {
      log('Store config initialization failed: $e', name: 'StoreConfigService');
      // Use empty fallback if everything fails
      _cachedStoreData = StoreData.empty();
    }
  }

  /// Get the current store data (cached or fresh)
  StoreData? get storeData => _cachedStoreData;

  /// Refresh store configuration from Appwrite
  Future<StoreData> refreshStoreConfig() async {
    try {
      log('Fetching store configuration from Appwrite...', name: 'StoreConfigService');

      final appwriteService = AppwriteService();
      const databaseId = 'arena_db';

      // Fetch all store data in parallel
      final results = await Future.wait([
        _fetchSubscriptions(appwriteService, databaseId),
        _fetchCoins(appwriteService, databaseId),
        _fetchEvents(appwriteService, databaseId),
        _fetchConfigs(appwriteService, databaseId),
      ]);

      final storeData = StoreData(
        subscriptions: results[0] as List<StoreSubscription>,
        coins: results[1] as List<StoreCoin>,
        events: results[2] as List<StoreEvent>,
        configs: results[3] as List<StoreConfig>,
        lastUpdated: DateTime.now(),
      );

      _cachedStoreData = storeData;
      // _cacheTimestamp = DateTime.now();

      // Cache the data locally
      await _saveToCache(storeData);

      log('Store configuration updated successfully', name: 'StoreConfigService');
      return storeData;

    } catch (e) {
      log('Failed to refresh store config: $e', name: 'StoreConfigService');

      // Return cached data if available, otherwise empty data
      if (_cachedStoreData != null) {
        return _cachedStoreData!;
      } else {
        final fallbackData = _getFallbackStoreData();
        _cachedStoreData = fallbackData;
        return fallbackData;
      }
    }
  }

  /// Fetch subscriptions from Appwrite
  Future<List<StoreSubscription>> _fetchSubscriptions(
    AppwriteService appwriteService,
    String databaseId
  ) async {
    try {
      final response = await appwriteService.databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        queries: [
          Query.equal('is_active', true),
          Query.orderAsc('sort_order'),
        ],
      );

      return response.documents
          .map((doc) => StoreSubscription.fromAppwrite(doc.data))
          .toList();
    } catch (e) {
      log('Failed to fetch subscriptions: $e', name: 'StoreConfigService');
      return [];
    }
  }

  /// Fetch coins from Appwrite
  Future<List<StoreCoin>> _fetchCoins(
    AppwriteService appwriteService,
    String databaseId
  ) async {
    try {
      final response = await appwriteService.databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'store_coins',
        queries: [
          Query.equal('is_active', true),
          Query.orderAsc('sort_order'),
        ],
      );

      return response.documents
          .map((doc) => StoreCoin.fromAppwrite(doc.data))
          .toList();
    } catch (e) {
      log('Failed to fetch coins: $e', name: 'StoreConfigService');
      return [];
    }
  }

  /// Fetch events from Appwrite
  Future<List<StoreEvent>> _fetchEvents(
    AppwriteService appwriteService,
    String databaseId
  ) async {
    try {
      final response = await appwriteService.databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'store_events',
        queries: [
          Query.equal('is_active', true),
          Query.orderAsc('sort_order'),
        ],
      );

      return response.documents
          .map((doc) => StoreEvent.fromAppwrite(doc.data))
          .toList();
    } catch (e) {
      log('Failed to fetch events: $e', name: 'StoreConfigService');
      return [];
    }
  }

  /// Fetch configs from Appwrite
  Future<List<StoreConfig>> _fetchConfigs(
    AppwriteService appwriteService,
    String databaseId
  ) async {
    try {
      final response = await appwriteService.databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'store_config',
        queries: [
          Query.equal('is_active', true),
        ],
      );

      return response.documents
          .map((doc) => StoreConfig.fromAppwrite(doc.data))
          .toList();
    } catch (e) {
      log('Failed to fetch configs: $e', name: 'StoreConfigService');
      return [];
    }
  }


  /// Load store data from local cache
  Future<void> _loadFromCache() async {
    try {
      // In a real app, you'd use SharedPreferences, Hive, or SQLite
      // For now, we'll just keep the in-memory cache
      log('Loading store data from cache...', name: 'StoreConfigService');
      // TODO: Implement persistent caching with SharedPreferences
    } catch (e) {
      log('Failed to load from cache: $e', name: 'StoreConfigService');
    }
  }

  /// Save store data to local cache
  Future<void> _saveToCache(StoreData storeData) async {
    try {
      // In a real app, you'd use SharedPreferences, Hive, or SQLite
      // For now, we'll just keep the in-memory cache
      log('Saving store data to cache...', name: 'StoreConfigService');
      // TODO: Implement persistent caching with SharedPreferences
    } catch (e) {
      log('Failed to save to cache: $e', name: 'StoreConfigService');
    }
  }

  /// Get fallback store data when everything else fails
  StoreData _getFallbackStoreData() {
    log('Using fallback store configuration', name: 'StoreConfigService');

    return StoreData(
      subscriptions: [
        StoreSubscription(
          id: 'fallback_teen',
          subscriptionId: 'teen_monthly',
          title: 'Teen Plan (13–17)',
          priceDisplay: '\$4.99/mo',
          eligibility: 'age_13_17',
          features: ['Join debates', 'Ranked profile', 'Basic analytics'],
          badge: 'Requires parent OK',
          rcProductId: 'arena_teen_monthly',
          sortOrder: 1,
          isActive: true,
        ),
        StoreSubscription(
          id: 'fallback_adult',
          subscriptionId: 'adult_monthly',
          title: 'Adult Plan (18+)',
          priceDisplay: '\$9.99/mo',
          eligibility: 'age_18_plus',
          features: ['Join & host debates', 'Advanced analytics', 'Priority queue'],
          badge: 'Most popular',
          rcProductId: 'arena_adult_monthly',
          sortOrder: 2,
          isActive: true,
        ),
      ],
      coins: [
        StoreCoin(
          id: 'fallback_100',
          coinPackageId: 'coins_100',
          amount: 100,
          priceDisplay: '\$0.99',
          rcProductId: 'arena_coins_100',
          sortOrder: 1,
          isActive: true,
        ),
        StoreCoin(
          id: 'fallback_600',
          coinPackageId: 'coins_600',
          amount: 600,
          priceDisplay: '\$4.99',
          badge: 'Most Popular',
          rcProductId: 'arena_coins_600',
          sortOrder: 2,
          isActive: true,
        ),
      ],
      events: [],
      configs: [
        StoreConfig(
          id: 'fallback_teen_enabled',
          configKey: 'teen_plans_enabled',
          configValue: 'true',
          isActive: true,
        ),
        StoreConfig(
          id: 'fallback_coin_enabled',
          configKey: 'coin_purchases_enabled',
          configValue: 'true',
          isActive: true,
        ),
      ],
      lastUpdated: DateTime.now(),
    );
  }

  /// Get subscriptions eligible for a specific user age
  List<StoreSubscription> getEligibleSubscriptions(int userAge) {
    if (_cachedStoreData == null) return [];
    return _cachedStoreData!.getEligibleSubscriptions(userAge);
  }

  /// Check if teen plans are currently enabled
  bool get teenPlansEnabled {
    if (_cachedStoreData == null) return true; // Default to enabled
    return _cachedStoreData!.teenPlansEnabled;
  }

  /// Check if coin purchases are currently enabled
  bool get coinPurchasesEnabled {
    if (_cachedStoreData == null) return true; // Default to enabled
    return _cachedStoreData!.coinPurchasesEnabled;
  }

  /// Check if events are currently enabled
  bool get eventsEnabled {
    if (_cachedStoreData == null) return true; // Default to enabled
    return _cachedStoreData!.eventsEnabled;
  }

  /// Force refresh store config (bypass cache)
  Future<StoreData> forceRefresh() async {
    // _cacheTimestamp = null; // Invalidate cache
    return await refreshStoreConfig();
  }

  /// Clear all cached data
  void clearCache() {
    _cachedStoreData = null;
    // _cacheTimestamp = null;
  }
}