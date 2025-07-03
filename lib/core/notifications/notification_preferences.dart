import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_types.dart';
import '../logging/app_logger.dart';

/// User preferences for notification settings
class NotificationPreferences {
  static const String _prefsKey = 'notification_preferences';
  
  // Global settings
  bool enableNotifications;
  bool enableSounds;
  bool enableVibration;
  bool enableBanners;
  bool enablePushNotifications;
  
  // Do not disturb settings
  bool enableDoNotDisturb;
  TimeOfDay? doNotDisturbStart;
  TimeOfDay? doNotDisturbEnd;
  
  // Per-type settings
  Map<NotificationType, bool> typeEnabled;
  Map<NotificationType, bool> typeSoundEnabled;
  Map<NotificationType, bool> typeVibrateEnabled;
  Map<NotificationType, NotificationPriority> typeMinPriority;

  NotificationPreferences({
    this.enableNotifications = true,
    this.enableSounds = true,
    this.enableVibration = true,
    this.enableBanners = true,
    this.enablePushNotifications = true,
    this.enableDoNotDisturb = false,
    this.doNotDisturbStart,
    this.doNotDisturbEnd,
    Map<NotificationType, bool>? typeEnabled,
    Map<NotificationType, bool>? typeSoundEnabled,
    Map<NotificationType, bool>? typeVibrateEnabled,
    Map<NotificationType, NotificationPriority>? typeMinPriority,
  }) : 
    typeEnabled = typeEnabled ?? _getDefaultTypeEnabled(),
    typeSoundEnabled = typeSoundEnabled ?? _getDefaultTypeSoundEnabled(),
    typeVibrateEnabled = typeVibrateEnabled ?? _getDefaultTypeVibrateEnabled(),
    typeMinPriority = typeMinPriority ?? _getDefaultTypeMinPriority();

  /// Get default enabled state for each notification type
  static Map<NotificationType, bool> _getDefaultTypeEnabled() {
    return {
      NotificationType.challenge: true,
      NotificationType.arenaRole: true,
      NotificationType.arenaStarted: true,
      NotificationType.arenaEnded: true,
      NotificationType.tournamentInvite: true,
      NotificationType.friendRequest: true,
      NotificationType.mention: true,
      NotificationType.achievement: true,
      NotificationType.systemAnnouncement: true,
      NotificationType.roomChat: false, // Disabled by default - can be noisy
      NotificationType.voteReminder: true,
      NotificationType.followUp: true,
    };
  }

  /// Get default sound enabled state for each notification type
  static Map<NotificationType, bool> _getDefaultTypeSoundEnabled() {
    return {
      NotificationType.challenge: true,
      NotificationType.arenaRole: true,
      NotificationType.arenaStarted: true,
      NotificationType.arenaEnded: false,
      NotificationType.tournamentInvite: true,
      NotificationType.friendRequest: false,
      NotificationType.mention: true,
      NotificationType.achievement: false,
      NotificationType.systemAnnouncement: false,
      NotificationType.roomChat: false,
      NotificationType.voteReminder: true,
      NotificationType.followUp: false,
    };
  }

  /// Get default vibration enabled state for each notification type
  static Map<NotificationType, bool> _getDefaultTypeVibrateEnabled() {
    return {
      NotificationType.challenge: true,
      NotificationType.arenaRole: true,
      NotificationType.arenaStarted: false,
      NotificationType.arenaEnded: false,
      NotificationType.tournamentInvite: false,
      NotificationType.friendRequest: false,
      NotificationType.mention: false,
      NotificationType.achievement: false,
      NotificationType.systemAnnouncement: false,
      NotificationType.roomChat: false,
      NotificationType.voteReminder: true,
      NotificationType.followUp: false,
    };
  }

  /// Get default minimum priority for each notification type
  static Map<NotificationType, NotificationPriority> _getDefaultTypeMinPriority() {
    return {
      NotificationType.challenge: NotificationPriority.medium,
      NotificationType.arenaRole: NotificationPriority.high,
      NotificationType.arenaStarted: NotificationPriority.medium,
      NotificationType.arenaEnded: NotificationPriority.low,
      NotificationType.tournamentInvite: NotificationPriority.medium,
      NotificationType.friendRequest: NotificationPriority.low,
      NotificationType.mention: NotificationPriority.medium,
      NotificationType.achievement: NotificationPriority.low,
      NotificationType.systemAnnouncement: NotificationPriority.medium,
      NotificationType.roomChat: NotificationPriority.low,
      NotificationType.voteReminder: NotificationPriority.high,
      NotificationType.followUp: NotificationPriority.low,
    };
  }

  /// Check if notification type is enabled
  bool isTypeEnabled(NotificationType type) {
    if (!enableNotifications) return false;
    return typeEnabled[type] ?? false;
  }

  /// Check if sound is enabled for notification type
  bool isSoundEnabled(NotificationType type) {
    if (!enableSounds) return false;
    if (!isTypeEnabled(type)) return false;
    return typeSoundEnabled[type] ?? false;
  }

  /// Check if vibration is enabled for notification type
  bool isVibrationEnabled(NotificationType type) {
    if (!enableVibration) return false;
    if (!isTypeEnabled(type)) return false;
    return typeVibrateEnabled[type] ?? false;
  }

  /// Check if notification meets minimum priority requirement
  bool meetsPriorityRequirement(NotificationType type, NotificationPriority priority) {
    final minPriority = typeMinPriority[type] ?? NotificationPriority.low;
    return priority.value >= minPriority.value;
  }

  /// Check if currently in do not disturb period
  bool get isInDoNotDisturbPeriod {
    if (!enableDoNotDisturb || doNotDisturbStart == null || doNotDisturbEnd == null) {
      return false;
    }

    final now = TimeOfDay.now();
    final start = doNotDisturbStart!;
    final end = doNotDisturbEnd!;

    // Handle same day period
    if (start.hour < end.hour || (start.hour == end.hour && start.minute < end.minute)) {
      return _isTimeBetween(now, start, end);
    } 
    // Handle overnight period (crosses midnight)
    else {
      return _isTimeBetween(now, start, const TimeOfDay(hour: 23, minute: 59)) ||
             _isTimeBetween(now, const TimeOfDay(hour: 0, minute: 0), end);
    }
  }

  bool _isTimeBetween(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'enableNotifications': enableNotifications,
      'enableSounds': enableSounds,
      'enableVibration': enableVibration,
      'enableBanners': enableBanners,
      'enablePushNotifications': enablePushNotifications,
      'enableDoNotDisturb': enableDoNotDisturb,
      'doNotDisturbStart': doNotDisturbStart != null ? '${doNotDisturbStart!.hour}:${doNotDisturbStart!.minute}' : null,
      'doNotDisturbEnd': doNotDisturbEnd != null ? '${doNotDisturbEnd!.hour}:${doNotDisturbEnd!.minute}' : null,
      'typeEnabled': typeEnabled.map((k, v) => MapEntry(k.value, v)),
      'typeSoundEnabled': typeSoundEnabled.map((k, v) => MapEntry(k.value, v)),
      'typeVibrateEnabled': typeVibrateEnabled.map((k, v) => MapEntry(k.value, v)),
      'typeMinPriority': typeMinPriority.map((k, v) => MapEntry(k.value, v.value)),
    };
  }

  /// Create from map
  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      enableNotifications: map['enableNotifications'] ?? true,
      enableSounds: map['enableSounds'] ?? true,
      enableVibration: map['enableVibration'] ?? true,
      enableBanners: map['enableBanners'] ?? true,
      enablePushNotifications: map['enablePushNotifications'] ?? true,
      enableDoNotDisturb: map['enableDoNotDisturb'] ?? false,
      doNotDisturbStart: map['doNotDisturbStart'] != null ? 
          _parseTimeOfDay(map['doNotDisturbStart']) : null,
      doNotDisturbEnd: map['doNotDisturbEnd'] != null ? 
          _parseTimeOfDay(map['doNotDisturbEnd']) : null,
      typeEnabled: _parseTypeMap<bool>(map['typeEnabled'], (v) => v as bool, _getDefaultTypeEnabled()),
      typeSoundEnabled: _parseTypeMap<bool>(map['typeSoundEnabled'], (v) => v as bool, _getDefaultTypeSoundEnabled()),
      typeVibrateEnabled: _parseTypeMap<bool>(map['typeVibrateEnabled'], (v) => v as bool, _getDefaultTypeVibrateEnabled()),
      typeMinPriority: _parseTypeMap<NotificationPriority>(
        map['typeMinPriority'], 
        (v) => NotificationPriority.fromInt(v as int), 
        _getDefaultTypeMinPriority()
      ),
    );
  }

  static TimeOfDay? _parseTimeOfDay(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  static Map<NotificationType, T> _parseTypeMap<T>(
    dynamic mapData, 
    T Function(dynamic) converter,
    Map<NotificationType, T> defaultValues,
  ) {
    if (mapData == null) return defaultValues;
    
    final result = <NotificationType, T>{};
    final map = Map<String, dynamic>.from(mapData);
    
    for (final type in NotificationType.values) {
      if (map.containsKey(type.value)) {
        try {
          result[type] = converter(map[type.value]);
        } catch (e) {
          result[type] = defaultValues[type]!;
        }
      } else {
        result[type] = defaultValues[type]!;
      }
    }
    
    return result;
  }

  /// Copy with updated values
  NotificationPreferences copyWith({
    bool? enableNotifications,
    bool? enableSounds,
    bool? enableVibration,
    bool? enableBanners,
    bool? enablePushNotifications,
    bool? enableDoNotDisturb,
    TimeOfDay? doNotDisturbStart,
    TimeOfDay? doNotDisturbEnd,
    Map<NotificationType, bool>? typeEnabled,
    Map<NotificationType, bool>? typeSoundEnabled,
    Map<NotificationType, bool>? typeVibrateEnabled,
    Map<NotificationType, NotificationPriority>? typeMinPriority,
  }) {
    return NotificationPreferences(
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableSounds: enableSounds ?? this.enableSounds,
      enableVibration: enableVibration ?? this.enableVibration,
      enableBanners: enableBanners ?? this.enableBanners,
      enablePushNotifications: enablePushNotifications ?? this.enablePushNotifications,
      enableDoNotDisturb: enableDoNotDisturb ?? this.enableDoNotDisturb,
      doNotDisturbStart: doNotDisturbStart ?? this.doNotDisturbStart,
      doNotDisturbEnd: doNotDisturbEnd ?? this.doNotDisturbEnd,
      typeEnabled: typeEnabled ?? this.typeEnabled,
      typeSoundEnabled: typeSoundEnabled ?? this.typeSoundEnabled,
      typeVibrateEnabled: typeVibrateEnabled ?? this.typeVibrateEnabled,
      typeMinPriority: typeMinPriority ?? this.typeMinPriority,
    );
  }
}

/// Service to manage notification preferences
class NotificationPreferencesService {
  static final NotificationPreferencesService _instance = NotificationPreferencesService._internal();
  factory NotificationPreferencesService() => _instance;
  NotificationPreferencesService._internal();

  NotificationPreferences _preferences = NotificationPreferences();
  bool _isLoaded = false;

  NotificationPreferences get preferences => _preferences;
  bool get isLoaded => _isLoaded;

  /// Load preferences from storage
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(NotificationPreferences._prefsKey);
      
      if (jsonString != null) {
        final map = json.decode(jsonString) as Map<String, dynamic>;
        _preferences = NotificationPreferences.fromMap(map);
        AppLogger().debug('🔔 Loaded notification preferences');
      } else {
        _preferences = NotificationPreferences();
        AppLogger().debug('🔔 Using default notification preferences');
      }
      
      _isLoaded = true;
    } catch (e) {
      AppLogger().error('Error loading notification preferences: $e');
      _preferences = NotificationPreferences();
      _isLoaded = true;
    }
  }

  /// Save preferences to storage
  Future<void> savePreferences(NotificationPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(preferences.toMap());
      await prefs.setString(NotificationPreferences._prefsKey, jsonString);
      
      _preferences = preferences;
      AppLogger().debug('🔔 Saved notification preferences');
    } catch (e) {
      AppLogger().error('Error saving notification preferences: $e');
      rethrow;
    }
  }

  /// Update specific preference
  Future<void> updatePreference<T>(T Function(NotificationPreferences) updater) async {
    final updated = updater(_preferences);
    if (updated is NotificationPreferences) {
      await savePreferences(updated);
    }
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    await savePreferences(NotificationPreferences());
  }
}

class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  static TimeOfDay now() {
    final now = DateTime.now();
    return TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeOfDay && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}