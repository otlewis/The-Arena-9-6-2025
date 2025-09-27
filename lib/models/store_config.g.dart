// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StoreSubscriptionImpl _$$StoreSubscriptionImplFromJson(
        Map<String, dynamic> json) =>
    _$StoreSubscriptionImpl(
      id: json['id'] as String,
      subscriptionId: json['subscriptionId'] as String,
      title: json['title'] as String,
      priceDisplay: json['priceDisplay'] as String,
      eligibility: json['eligibility'] as String,
      features:
          (json['features'] as List<dynamic>).map((e) => e as String).toList(),
      badge: json['badge'] as String?,
      rcProductId: json['rcProductId'] as String,
      sortOrder: (json['sortOrder'] as num).toInt(),
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$StoreSubscriptionImplToJson(
        _$StoreSubscriptionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subscriptionId': instance.subscriptionId,
      'title': instance.title,
      'priceDisplay': instance.priceDisplay,
      'eligibility': instance.eligibility,
      'features': instance.features,
      'badge': instance.badge,
      'rcProductId': instance.rcProductId,
      'sortOrder': instance.sortOrder,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$StoreCoinImpl _$$StoreCoinImplFromJson(Map<String, dynamic> json) =>
    _$StoreCoinImpl(
      id: json['id'] as String,
      coinPackageId: json['coinPackageId'] as String,
      amount: (json['amount'] as num).toInt(),
      priceDisplay: json['priceDisplay'] as String,
      badge: json['badge'] as String?,
      rcProductId: json['rcProductId'] as String,
      sortOrder: (json['sortOrder'] as num).toInt(),
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$StoreCoinImplToJson(_$StoreCoinImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'coinPackageId': instance.coinPackageId,
      'amount': instance.amount,
      'priceDisplay': instance.priceDisplay,
      'badge': instance.badge,
      'rcProductId': instance.rcProductId,
      'sortOrder': instance.sortOrder,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$StoreEventImpl _$$StoreEventImplFromJson(Map<String, dynamic> json) =>
    _$StoreEventImpl(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      priceDisplay: json['priceDisplay'] as String,
      ctaText: json['ctaText'] as String,
      rcProductId: json['rcProductId'] as String?,
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      sortOrder: (json['sortOrder'] as num).toInt(),
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$StoreEventImplToJson(_$StoreEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'title': instance.title,
      'description': instance.description,
      'priceDisplay': instance.priceDisplay,
      'ctaText': instance.ctaText,
      'rcProductId': instance.rcProductId,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'sortOrder': instance.sortOrder,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$StoreConfigImpl _$$StoreConfigImplFromJson(Map<String, dynamic> json) =>
    _$StoreConfigImpl(
      id: json['id'] as String,
      configKey: json['configKey'] as String,
      configValue: json['configValue'] as String,
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$StoreConfigImplToJson(_$StoreConfigImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'configKey': instance.configKey,
      'configValue': instance.configValue,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$StoreDataImpl _$$StoreDataImplFromJson(Map<String, dynamic> json) =>
    _$StoreDataImpl(
      subscriptions: (json['subscriptions'] as List<dynamic>)
          .map((e) => StoreSubscription.fromJson(e as Map<String, dynamic>))
          .toList(),
      coins: (json['coins'] as List<dynamic>)
          .map((e) => StoreCoin.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List<dynamic>)
          .map((e) => StoreEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      configs: (json['configs'] as List<dynamic>)
          .map((e) => StoreConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$$StoreDataImplToJson(_$StoreDataImpl instance) =>
    <String, dynamic>{
      'subscriptions': instance.subscriptions,
      'coins': instance.coins,
      'events': instance.events,
      'configs': instance.configs,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };
