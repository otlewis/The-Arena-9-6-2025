import 'package:freezed_annotation/freezed_annotation.dart';

part 'store_config.freezed.dart';
part 'store_config.g.dart';

/// Model for store subscription plans (teen, adult, etc.)
@freezed
class StoreSubscription with _$StoreSubscription {
  const factory StoreSubscription({
    required String id,
    required String subscriptionId,
    required String title,
    required String priceDisplay,
    required String eligibility,
    required List<String> features,
    String? badge,
    required String rcProductId,
    required int sortOrder,
    required bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoreSubscription;

  factory StoreSubscription.fromJson(Map<String, dynamic> json) =>
      _$StoreSubscriptionFromJson(json);

  factory StoreSubscription.fromAppwrite(Map<String, dynamic> data) {
    return StoreSubscription(
      id: data['\$id'] ?? '',
      subscriptionId: data['subscription_id'] ?? '',
      title: data['title'] ?? '',
      priceDisplay: data['price_display'] ?? '',
      eligibility: data['eligibility'] ?? '',
      features: data['features'] != null 
          ? (data['features'] as String).split(',').map((e) => e.trim()).toList()
          : [],
      badge: data['badge'],
      rcProductId: data['rc_product_id'] ?? '',
      sortOrder: data['sort_order'] ?? 0,
      isActive: data['is_active'] ?? true,
      createdAt: data['\$createdAt'] != null ? DateTime.parse(data['\$createdAt']) : null,
      updatedAt: data['\$updatedAt'] != null ? DateTime.parse(data['\$updatedAt']) : null,
    );
  }
}

/// Model for Arena Coins packages
@freezed
class StoreCoin with _$StoreCoin {
  const factory StoreCoin({
    required String id,
    required String coinPackageId,
    required int amount,
    required String priceDisplay,
    String? badge,
    required String rcProductId,
    required int sortOrder,
    required bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoreCoin;

  factory StoreCoin.fromJson(Map<String, dynamic> json) =>
      _$StoreCoinFromJson(json);

  factory StoreCoin.fromAppwrite(Map<String, dynamic> data) {
    return StoreCoin(
      id: data['\$id'] ?? '',
      coinPackageId: data['coin_package_id'] ?? '',
      amount: data['amount'] ?? 0,
      priceDisplay: data['price_display'] ?? '',
      badge: data['badge'],
      rcProductId: data['rc_product_id'] ?? '',
      sortOrder: data['sort_order'] ?? 0,
      isActive: data['is_active'] ?? true,
      createdAt: data['\$createdAt'] != null ? DateTime.parse(data['\$createdAt']) : null,
      updatedAt: data['\$updatedAt'] != null ? DateTime.parse(data['\$updatedAt']) : null,
    );
  }
}

/// Model for special events and tournaments
@freezed
class StoreEvent with _$StoreEvent {
  const factory StoreEvent({
    required String id,
    required String eventId,
    required String title,
    String? description,
    required String priceDisplay,
    required String ctaText,
    String? rcProductId,
    DateTime? startDate,
    DateTime? endDate,
    required int sortOrder,
    required bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoreEvent;

  factory StoreEvent.fromJson(Map<String, dynamic> json) =>
      _$StoreEventFromJson(json);

  factory StoreEvent.fromAppwrite(Map<String, dynamic> data) {
    return StoreEvent(
      id: data['\$id'] ?? '',
      eventId: data['event_id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      priceDisplay: data['price_display'] ?? '',
      ctaText: data['cta_text'] ?? '',
      rcProductId: data['rc_product_id'],
      startDate: data['start_date'] != null ? DateTime.parse(data['start_date']) : null,
      endDate: data['end_date'] != null ? DateTime.parse(data['end_date']) : null,
      sortOrder: data['sort_order'] ?? 0,
      isActive: data['is_active'] ?? true,
      createdAt: data['\$createdAt'] != null ? DateTime.parse(data['\$createdAt']) : null,
      updatedAt: data['\$updatedAt'] != null ? DateTime.parse(data['\$updatedAt']) : null,
    );
  }
}

/// Model for general store configuration
@freezed
class StoreConfig with _$StoreConfig {
  const factory StoreConfig({
    required String id,
    required String configKey,
    required String configValue,
    required bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoreConfig;

  factory StoreConfig.fromJson(Map<String, dynamic> json) =>
      _$StoreConfigFromJson(json);

  factory StoreConfig.fromAppwrite(Map<String, dynamic> data) {
    return StoreConfig(
      id: data['\$id'] ?? '',
      configKey: data['config_key'] ?? '',
      configValue: data['config_value'] ?? '',
      isActive: data['is_active'] ?? true,
      createdAt: data['\$createdAt'] != null ? DateTime.parse(data['\$createdAt']) : null,
      updatedAt: data['\$updatedAt'] != null ? DateTime.parse(data['\$updatedAt']) : null,
    );
  }
}

/// Complete store configuration combining all store data
@freezed
class StoreData with _$StoreData {
  const factory StoreData({
    required List<StoreSubscription> subscriptions,
    required List<StoreCoin> coins,
    required List<StoreEvent> events,
    required List<StoreConfig> configs,
    DateTime? lastUpdated,
  }) = _StoreData;

  factory StoreData.fromJson(Map<String, dynamic> json) =>
      _$StoreDataFromJson(json);
      
  factory StoreData.empty() {
    return const StoreData(
      subscriptions: [],
      coins: [],
      events: [],
      configs: [],
    );
  }
}

/// Enums for eligibility and other types
enum SubscriptionEligibility {
  age13To17('age_13_17'),
  age18Plus('age_18_plus'),
  anyAge('any_age');

  const SubscriptionEligibility(this.value);
  final String value;

  static SubscriptionEligibility fromString(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => anyAge,
    );
  }
}

/// Extensions for convenience
extension StoreDataExtensions on StoreData {
  /// Get active subscriptions sorted by sort order
  List<StoreSubscription> get activeSubscriptions {
    return subscriptions
        .where((sub) => sub.isActive)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get active coins sorted by sort order
  List<StoreCoin> get activeCoins {
    return coins
        .where((coin) => coin.isActive)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get active events sorted by sort order
  List<StoreEvent> get activeEvents {
    return events
        .where((event) => event.isActive)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get subscriptions eligible for a specific age
  List<StoreSubscription> getEligibleSubscriptions(int age) {
    return activeSubscriptions.where((sub) {
      switch (sub.eligibility) {
        case 'age_13_17':
          return age >= 13 && age <= 17;
        case 'age_18_plus':
          return age >= 18;
        case 'any_age':
          return true;
        default:
          return true;
      }
    }).toList();
  }

  /// Get config value by key
  String? getConfigValue(String key) {
    try {
      return configs
          .firstWhere((config) => config.configKey == key && config.isActive)
          .configValue;
    } catch (e) {
      return null;
    }
  }

  /// Check if teen plans are enabled
  bool get teenPlansEnabled {
    final config = getConfigValue('teen_plans_enabled');
    return config?.toLowerCase() == 'true';
  }

  /// Check if coin purchases are enabled
  bool get coinPurchasesEnabled {
    final config = getConfigValue('coin_purchases_enabled');
    return config?.toLowerCase() != 'false'; // Default to true
  }

  /// Check if events are enabled
  bool get eventsEnabled {
    final config = getConfigValue('events_enabled');
    return config?.toLowerCase() != 'false'; // Default to true
  }
}