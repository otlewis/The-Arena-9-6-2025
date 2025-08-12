import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging/app_logger.dart';

/// Conflict resolution strategies for offline edits
enum ConflictResolutionStrategy {
  /// Client changes always win
  clientWins,
  
  /// Server changes always win
  serverWins,
  
  /// Last write wins based on timestamp
  lastWriteWins,
  
  /// Merge changes where possible
  merge,
  
  /// Ask user to resolve manually
  manual
}

/// Represents a conflict between local and server data
class DataConflict {
  final String documentId;
  final String collectionId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime localTimestamp;
  final DateTime serverTimestamp;
  final ConflictResolutionStrategy suggestedStrategy;
  
  DataConflict({
    required this.documentId,
    required this.collectionId,
    required this.localData,
    required this.serverData,
    required this.localTimestamp,
    required this.serverTimestamp,
    this.suggestedStrategy = ConflictResolutionStrategy.lastWriteWins,
  });
  
  /// Get conflicting fields
  Map<String, ConflictDetail> getConflictingFields() {
    final conflicts = <String, ConflictDetail>{};
    
    // Find fields that exist in both but have different values
    for (final key in localData.keys) {
      if (serverData.containsKey(key)) {
        final localValue = localData[key];
        final serverValue = serverData[key];
        
        if (!_areValuesEqual(localValue, serverValue)) {
          conflicts[key] = ConflictDetail(
            fieldName: key,
            localValue: localValue,
            serverValue: serverValue,
          );
        }
      }
    }
    
    return conflicts;
  }
  
  bool _areValuesEqual(dynamic a, dynamic b) {
    if (a == b) return true;
    
    // Deep equality check for collections
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_areValuesEqual(a[i], b[i])) return false;
      }
      return true;
    }
    
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_areValuesEqual(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    
    return false;
  }
}

/// Details about a specific field conflict
class ConflictDetail {
  final String fieldName;
  final dynamic localValue;
  final dynamic serverValue;
  
  ConflictDetail({
    required this.fieldName,
    required this.localValue,
    required this.serverValue,
  });
}

/// Service for resolving conflicts between offline edits and server data
class OfflineConflictResolver {
  static final OfflineConflictResolver _instance = OfflineConflictResolver._internal();
  factory OfflineConflictResolver() => _instance;
  OfflineConflictResolver._internal();
  
  // Store unresolved conflicts
  final List<DataConflict> _unresolvedConflicts = [];
  
  // Conflict resolution rules per collection
  final Map<String, ConflictResolutionStrategy> _collectionStrategies = {
    'users': ConflictResolutionStrategy.merge,
    'messages': ConflictResolutionStrategy.clientWins,
    'rooms': ConflictResolutionStrategy.serverWins,
    'participants': ConflictResolutionStrategy.lastWriteWins,
  };
  
  // Field-specific merge rules
  final Map<String, MergeRule> _fieldMergeRules = {
    'participants': MergeRule.union,
    'tags': MergeRule.union,
    'votes': MergeRule.sum,
    'viewCount': MergeRule.max,
    'lastActive': MergeRule.max,
  };
  
  /// Resolve a conflict between local and server data
  Future<Map<String, dynamic>> resolveConflict(DataConflict conflict) async {
    AppLogger().info('🔧 Resolving conflict for ${conflict.collectionId}/${conflict.documentId}');
    
    // Get strategy for this collection
    final strategy = _collectionStrategies[conflict.collectionId] ?? 
                     conflict.suggestedStrategy;
    
    switch (strategy) {
      case ConflictResolutionStrategy.clientWins:
        return _resolveClientWins(conflict);
        
      case ConflictResolutionStrategy.serverWins:
        return _resolveServerWins(conflict);
        
      case ConflictResolutionStrategy.lastWriteWins:
        return _resolveLastWriteWins(conflict);
        
      case ConflictResolutionStrategy.merge:
        return _resolveMerge(conflict);
        
      case ConflictResolutionStrategy.manual:
        return _resolveManual(conflict);
    }
  }
  
  /// Client changes always win
  Map<String, dynamic> _resolveClientWins(DataConflict conflict) {
    AppLogger().debug('🔧 Resolution: Client wins');
    return conflict.localData;
  }
  
  /// Server changes always win
  Map<String, dynamic> _resolveServerWins(DataConflict conflict) {
    AppLogger().debug('🔧 Resolution: Server wins');
    return conflict.serverData;
  }
  
  /// Last write wins based on timestamp
  Map<String, dynamic> _resolveLastWriteWins(DataConflict conflict) {
    final clientWins = conflict.localTimestamp.isAfter(conflict.serverTimestamp);
    AppLogger().debug('🔧 Resolution: Last write wins (${clientWins ? "client" : "server"})');
    return clientWins ? conflict.localData : conflict.serverData;
  }
  
  /// Merge changes where possible
  Map<String, dynamic> _resolveMerge(DataConflict conflict) {
    AppLogger().debug('🔧 Resolution: Merging changes');
    
    final merged = Map<String, dynamic>.from(conflict.serverData);
    final conflicts = conflict.getConflictingFields();
    
    for (final entry in conflicts.entries) {
      final fieldName = entry.key;
      final conflictDetail = entry.value;
      
      // Check if we have a specific merge rule for this field
      if (_fieldMergeRules.containsKey(fieldName)) {
        merged[fieldName] = _applyMergeRule(
          _fieldMergeRules[fieldName]!,
          conflictDetail.localValue,
          conflictDetail.serverValue,
        );
      } else {
        // Default: Use more recent change
        merged[fieldName] = conflict.localTimestamp.isAfter(conflict.serverTimestamp)
            ? conflictDetail.localValue
            : conflictDetail.serverValue;
      }
    }
    
    // Add any fields that only exist in local data
    for (final key in conflict.localData.keys) {
      if (!merged.containsKey(key)) {
        merged[key] = conflict.localData[key];
      }
    }
    
    return merged;
  }
  
  /// Apply specific merge rule to a field
  dynamic _applyMergeRule(MergeRule rule, dynamic localValue, dynamic serverValue) {
    switch (rule) {
      case MergeRule.union:
        // Combine lists without duplicates
        if (localValue is List && serverValue is List) {
          final combined = {...localValue, ...serverValue}.toList();
          return combined;
        }
        return serverValue;
        
      case MergeRule.sum:
        // Add numeric values
        if (localValue is num && serverValue is num) {
          return localValue + serverValue;
        }
        return serverValue;
        
      case MergeRule.max:
        // Take the maximum value
        if (localValue is Comparable && serverValue is Comparable) {
          return localValue.compareTo(serverValue) > 0 ? localValue : serverValue;
        }
        return serverValue;
        
      case MergeRule.concat:
        // Concatenate strings or lists
        if (localValue is String && serverValue is String) {
          return '$serverValue\n$localValue';
        }
        if (localValue is List && serverValue is List) {
          return [...serverValue, ...localValue];
        }
        return serverValue;
    }
  }
  
  /// Manual resolution - store for user to resolve
  Map<String, dynamic> _resolveManual(DataConflict conflict) {
    AppLogger().debug('🔧 Resolution: Manual (storing for user resolution)');
    
    _unresolvedConflicts.add(conflict);
    _saveUnresolvedConflicts();
    
    // Default to server data until user resolves
    return conflict.serverData;
  }
  
  /// Check if there are unresolved conflicts
  bool hasUnresolvedConflicts() {
    return _unresolvedConflicts.isNotEmpty;
  }
  
  /// Get all unresolved conflicts
  List<DataConflict> getUnresolvedConflicts() {
    return List.unmodifiable(_unresolvedConflicts);
  }
  
  /// Resolve a manual conflict with user's choice
  Future<void> resolveManualConflict(
    String documentId,
    Map<String, dynamic> resolvedData,
  ) async {
    _unresolvedConflicts.removeWhere((c) => c.documentId == documentId);
    await _saveUnresolvedConflicts();
    
    AppLogger().info('🔧 Manual conflict resolved for: $documentId');
  }
  
  /// Save unresolved conflicts to storage
  Future<void> _saveUnresolvedConflicts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conflictsJson = _unresolvedConflicts.map((c) => {
        'documentId': c.documentId,
        'collectionId': c.collectionId,
        'localData': jsonEncode(c.localData),
        'serverData': jsonEncode(c.serverData),
        'localTimestamp': c.localTimestamp.toIso8601String(),
        'serverTimestamp': c.serverTimestamp.toIso8601String(),
      }).toList();
      
      await prefs.setString('unresolved_conflicts', jsonEncode(conflictsJson));
    } catch (e) {
      AppLogger().error('🔧 Failed to save unresolved conflicts: $e');
    }
  }
  
  /// Load unresolved conflicts from storage
  Future<void> loadUnresolvedConflicts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conflictsJson = prefs.getString('unresolved_conflicts');
      
      if (conflictsJson != null) {
        final conflictsList = jsonDecode(conflictsJson) as List;
        _unresolvedConflicts.clear();
        
        for (final json in conflictsList) {
          _unresolvedConflicts.add(DataConflict(
            documentId: json['documentId'],
            collectionId: json['collectionId'],
            localData: jsonDecode(json['localData']),
            serverData: jsonDecode(json['serverData']),
            localTimestamp: DateTime.parse(json['localTimestamp']),
            serverTimestamp: DateTime.parse(json['serverTimestamp']),
          ));
        }
        
        AppLogger().info('🔧 Loaded ${_unresolvedConflicts.length} unresolved conflicts');
      }
    } catch (e) {
      AppLogger().error('🔧 Failed to load unresolved conflicts: $e');
    }
  }
  
  /// Clear all unresolved conflicts
  Future<void> clearUnresolvedConflicts() async {
    _unresolvedConflicts.clear();
    await _saveUnresolvedConflicts();
    AppLogger().info('🔧 Cleared all unresolved conflicts');
  }
  
  /// Set custom resolution strategy for a collection
  void setCollectionStrategy(String collectionId, ConflictResolutionStrategy strategy) {
    _collectionStrategies[collectionId] = strategy;
    AppLogger().debug('🔧 Set resolution strategy for $collectionId: $strategy');
  }
  
  /// Set custom merge rule for a field
  void setFieldMergeRule(String fieldName, MergeRule rule) {
    _fieldMergeRules[fieldName] = rule;
    AppLogger().debug('🔧 Set merge rule for $fieldName: $rule');
  }
}

/// Merge rules for specific fields
enum MergeRule {
  /// Combine lists without duplicates
  union,
  
  /// Add numeric values
  sum,
  
  /// Take the maximum value
  max,
  
  /// Concatenate values
  concat,
}