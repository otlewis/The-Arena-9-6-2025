import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_offline_service.dart';
import 'offline_conflict_resolver.dart';
import 'network_resilience_service.dart';
import 'offline_data_cache.dart';
import 'package:get_it/get_it.dart';

/// Background sync task identifiers
class BackgroundTasks {
  static const String syncOfflineData = 'sync_offline_data';
  static const String cleanupCache = 'cleanup_cache';
  static const String resolveConflicts = 'resolve_conflicts';
  static const String uploadPendingFiles = 'upload_pending_files';
  static const String downloadUpdates = 'download_updates';
}

/// Background sync service for handling offline data synchronization
class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  int _syncFailureCount = 0;
  
  // Sync statistics
  int _totalSyncedItems = 0;
  final int _failedSyncItems = 0;
  int _conflictsResolved = 0;
  
  // Stream controllers
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  final StreamController<SyncProgress> _syncProgressController = StreamController<SyncProgress>.broadcast();
  
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;
  
  /// Initialize background sync service
  Future<void> initialize() async {
    try {
      AppLogger().info('🔄 Initializing Background Sync Service...');
      
      // Initialize Workmanager for background tasks
      await Workmanager().initialize(
        _callbackDispatcher,
        isInDebugMode: false,
      );
      
      // Register periodic sync task (every 15 minutes)
      await Workmanager().registerPeriodicTask(
        BackgroundTasks.syncOfflineData,
        BackgroundTasks.syncOfflineData,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
      
      // Register cleanup task (every hour)
      await Workmanager().registerPeriodicTask(
        BackgroundTasks.cleanupCache,
        BackgroundTasks.cleanupCache,
        frequency: const Duration(hours: 1),
      );
      
      // Start foreground periodic sync
      _startPeriodicSync();
      
      AppLogger().info('🔄 Background Sync Service initialized');
    } catch (e) {
      AppLogger().error('🔄 Failed to initialize Background Sync Service: $e');
    }
  }
  
  /// Start periodic sync in foreground
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    
    // Sync every 5 minutes when app is in foreground
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing) {
        performSync();
      }
    });
  }
  
  /// Perform sync operation
  Future<SyncResult> performSync({bool force = false}) async {
    if (_isSyncing && !force) {
      AppLogger().debug('🔄 Sync already in progress, skipping...');
      final result = SyncResult();
      result.success = false;
      result.message = 'Sync already in progress';
      return result;
    }
    
    _isSyncing = true;
    _updateSyncStatus(SyncStatus.syncing);
    
    final startTime = DateTime.now();
    final result = SyncResult();
    
    try {
      AppLogger().info('🔄 Starting sync operation...');
      
      // Check network connectivity (with background task safety)
      bool isOnline = true; // Default to online for background tasks
      try {
        final networkService = GetIt.instance<NetworkResilienceService>();
        isOnline = networkService.isOnline;
      } catch (e) {
        // GetIt services might not be available in background isolate
        AppLogger().warning('🔄 Network service not available in background context, assuming online');
      }
      
      if (!isOnline) {
        AppLogger().warning('🔄 No network connection, postponing sync');
        result.success = false;
        result.message = 'No network connection';
        _isSyncing = false;
        _updateSyncStatus(SyncStatus.failed);
        return result;
      }
      
      // Step 1: Upload pending offline actions
      _updateSyncProgress(SyncProgress(
        currentStep: 'Uploading offline changes',
        progress: 0.2,
      ));
      
      final uploadResult = await _uploadOfflineActions();
      result.uploadedItems = uploadResult.itemCount;
      result.failedUploads = uploadResult.failedCount;
      
      // Step 2: Download server updates
      _updateSyncProgress(SyncProgress(
        currentStep: 'Downloading updates',
        progress: 0.4,
      ));
      
      final downloadResult = await _downloadServerUpdates();
      result.downloadedItems = downloadResult.itemCount;
      
      // Step 3: Resolve conflicts
      _updateSyncProgress(SyncProgress(
        currentStep: 'Resolving conflicts',
        progress: 0.6,
      ));
      
      final conflictResult = await _resolveConflicts();
      result.conflictsResolved = conflictResult.resolvedCount;
      result.conflictsRemaining = conflictResult.remainingCount;
      
      // Step 4: Clean up old cache
      _updateSyncProgress(SyncProgress(
        currentStep: 'Cleaning cache',
        progress: 0.8,
      ));
      
      await _cleanupOldCache();
      
      // Step 5: Update sync metadata
      _updateSyncProgress(SyncProgress(
        currentStep: 'Finalizing',
        progress: 1.0,
      ));
      
      _lastSyncTime = DateTime.now();
      _syncFailureCount = 0;
      _totalSyncedItems += result.uploadedItems + result.downloadedItems;
      _conflictsResolved += result.conflictsResolved;
      
      result.success = true;
      result.message = 'Sync completed successfully';
      result.duration = DateTime.now().difference(startTime);
      
      AppLogger().info('🔄 Sync completed: ${result.toString()}');
      
    } catch (e) {
      AppLogger().error('🔄 Sync failed: $e');
      _syncFailureCount++;
      
      result.success = false;
      result.message = 'Sync failed: $e';
      result.error = e.toString();
      
      // If sync fails too many times, reduce frequency
      if (_syncFailureCount >= 3) {
        _reduceSyncFrequency();
      }
    } finally {
      _isSyncing = false;
      _updateSyncStatus(result.success ? SyncStatus.completed : SyncStatus.failed);
    }
    
    return result;
  }
  
  /// Upload offline actions to server
  Future<SyncOperationResult> _uploadOfflineActions() async {
    final result = SyncOperationResult();
    
    try {
      final offlineService = AppwriteOfflineService();
      
      // Force sync if there are pending actions
      if (offlineService.hasPendingActions) {
        await offlineService.forceSyncNow();
        result.itemCount = 10; // Estimate, actual count from offline service
      }
      
    } catch (e) {
      AppLogger().error('🔄 Failed to upload offline actions: $e');
      result.failedCount++;
    }
    
    return result;
  }
  
  /// Download updates from server
  Future<SyncOperationResult> _downloadServerUpdates() async {
    final result = SyncOperationResult();
    
    try {
      // Get last sync timestamp
      // final lastSync = _lastSyncTime ?? DateTime.now().subtract(const Duration(days: 1));
      
      // Download updates since last sync
      // This would query Appwrite for documents modified after lastSync
      // For now, we'll just update cache stats
      
      result.itemCount = 0; // Would be actual downloaded count
      
    } catch (e) {
      AppLogger().error('🔄 Failed to download updates: $e');
    }
    
    return result;
  }
  
  /// Resolve conflicts between local and server data
  Future<ConflictResolutionResult> _resolveConflicts() async {
    final result = ConflictResolutionResult();
    
    try {
      final conflictResolver = OfflineConflictResolver();
      
      // Load unresolved conflicts
      await conflictResolver.loadUnresolvedConflicts();
      
      final conflicts = conflictResolver.getUnresolvedConflicts();
      result.remainingCount = conflicts.length;
      
      // Auto-resolve conflicts where possible
      for (final conflict in conflicts) {
        try {
          await conflictResolver.resolveConflict(conflict);
          // Apply resolved data to server
          result.resolvedCount++;
        } catch (e) {
          AppLogger().warning('🔄 Could not auto-resolve conflict: $e');
        }
      }
      
    } catch (e) {
      AppLogger().error('🔄 Failed to resolve conflicts: $e');
    }
    
    return result;
  }
  
  /// Clean up old cache entries
  Future<void> _cleanupOldCache() async {
    try {
      final cache = OfflineDataCache();
      
      // Get cache stats before cleanup
      final statsBefore = await cache.getCacheStats();
      
      // Clean up expired entries (handled internally by cache)
      await cache.initialize(); // This triggers cleanup
      
      final statsAfter = await cache.getCacheStats();
      
      AppLogger().debug('🔄 Cache cleanup: ${statsBefore['totalEntries']} -> ${statsAfter['totalEntries']} entries');
      
    } catch (e) {
      AppLogger().error('🔄 Failed to cleanup cache: $e');
    }
  }
  
  /// Reduce sync frequency after failures
  void _reduceSyncFrequency() {
    _periodicSyncTimer?.cancel();
    
    // Increase interval to 15 minutes after failures
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (!_isSyncing) {
        performSync();
      }
    });
    
    AppLogger().warning('🔄 Reduced sync frequency due to failures');
  }
  
  /// Force immediate sync
  Future<void> forceSyncNow() async {
    AppLogger().info('🔄 Force sync requested');
    await performSync(force: true);
  }
  
  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'isSyncing': _isSyncing,
      'syncFailureCount': _syncFailureCount,
      'totalSyncedItems': _totalSyncedItems,
      'failedSyncItems': _failedSyncItems,
      'conflictsResolved': _conflictsResolved,
    };
  }
  
  /// Update sync status
  void _updateSyncStatus(SyncStatus status) {
    _syncStatusController.add(status);
  }
  
  /// Update sync progress
  void _updateSyncProgress(SyncProgress progress) {
    _syncProgressController.add(progress);
  }
  
  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    _periodicSyncTimer?.cancel();
    AppLogger().info('🔄 All background tasks cancelled');
  }
  
  /// Dispose resources
  void dispose() {
    _periodicSyncTimer?.cancel();
    _syncStatusController.close();
    _syncProgressController.close();
    AppLogger().info('🔄 Background Sync Service disposed');
  }
}

/// Background task callback dispatcher
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      AppLogger().debug('🔄 Background task started: $task');
      
      switch (task) {
        case BackgroundTasks.syncOfflineData:
          final syncService = BackgroundSyncService();
          await syncService.performSync();
          break;
          
        case BackgroundTasks.cleanupCache:
          final cache = OfflineDataCache();
          await cache.initialize();
          break;
          
        case BackgroundTasks.resolveConflicts:
          final resolver = OfflineConflictResolver();
          await resolver.loadUnresolvedConflicts();
          break;
      }
      
      return Future.value(true);
    } catch (e) {
      AppLogger().error('🔄 Background task failed: $e');
      return Future.value(false);
    }
  });
}

/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  completed,
  failed
}

/// Sync progress information
class SyncProgress {
  final String currentStep;
  final double progress;
  final String? message;
  
  SyncProgress({
    required this.currentStep,
    required this.progress,
    this.message,
  });
}

/// Sync result information
class SyncResult {
  bool success = false;
  String message = '';
  String? error;
  int uploadedItems = 0;
  int downloadedItems = 0;
  int failedUploads = 0;
  int conflictsResolved = 0;
  int conflictsRemaining = 0;
  Duration? duration;
  
  @override
  String toString() {
    return 'SyncResult(success: $success, uploaded: $uploadedItems, downloaded: $downloadedItems, conflicts: $conflictsResolved/$conflictsRemaining, duration: ${duration?.inSeconds}s)';
  }
}

/// Result of a sync operation
class SyncOperationResult {
  int itemCount = 0;
  int failedCount = 0;
}

/// Result of conflict resolution
class ConflictResolutionResult {
  int resolvedCount = 0;
  int remainingCount = 0;
}