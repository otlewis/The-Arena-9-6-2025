import 'dart:async';
import 'package:flutter/material.dart';
import '../services/appwrite_offline_service.dart';

/// Visual sync indicator showing connection status and pending actions
/// 
/// Displays:
/// - Connection status (online/offline)
/// - Pending actions count
/// - Sync in progress indicator
/// - Manual sync button
class TimerSyncIndicator extends StatefulWidget {
  final bool compact;
  final bool showSyncButton;
  final VoidCallback? onSyncPressed;

  const TimerSyncIndicator({
    super.key,
    this.compact = false,
    this.showSyncButton = true,
    this.onSyncPressed,
  });

  @override
  State<TimerSyncIndicator> createState() => _TimerSyncIndicatorState();
}

class _TimerSyncIndicatorState extends State<TimerSyncIndicator>
    with TickerProviderStateMixin {
  final AppwriteOfflineService _offlineService = AppwriteOfflineService();
  
  StreamSubscription<OfflineStatus>? _statusSubscription;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  
  OfflineStatus? _currentStatus;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupStatusStream();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.linear,
    ));
  }

  void _setupStatusStream() {
    _statusSubscription = _offlineService.offlineStatus.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
        
        _updateAnimations(status);
      }
    });
  }

  void _updateAnimations(OfflineStatus status) {
    if (!status.isConnected && status.hasPendingActions) {
      // Pulse when offline with pending actions
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Future<void> _onSyncPressed() async {
    if (_isSyncing || !_offlineService.isConnected) return;
    
    setState(() => _isSyncing = true);
    _rotateController.repeat();
    
    try {
      await _offlineService.forceSyncNow();
      widget.onSyncPressed?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        _rotateController.stop();
        _rotateController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStatus == null) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompactIndicator();
    }

    return _buildFullIndicator();
  }

  Widget _buildCompactIndicator() {
    final status = _currentStatus!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(status, size: 14),
          if (status.hasPendingActions) ...[
            const SizedBox(width: 4),
            Text(
              '${status.pendingActionsCount}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(status),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullIndicator() {
    final status = _currentStatus!;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildStatusIcon(status),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                      if (status.hasPendingActions)
                        Text(
                          '${status.pendingActionsCount} pending action${status.pendingActionsCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.showSyncButton && status.isConnected && status.hasPendingActions)
                  _buildSyncButton(),
              ],
            ),
            if (!status.isConnected && status.hasPendingActions) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Changes will sync when you\'re back online',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(OfflineStatus status, {double size = 20}) {
    Widget icon;
    
    if (_isSyncing) {
      icon = RotationTransition(
        turns: _rotateAnimation,
        child: Icon(
          Icons.sync,
          size: size,
          color: Colors.blue,
        ),
      );
    } else if (status.isConnected) {
      if (status.hasPendingActions) {
        icon = Icon(
          Icons.sync_problem,
          size: size,
          color: Colors.orange,
        );
      } else {
        icon = Icon(
          Icons.cloud_done,
          size: size,
          color: Colors.green,
        );
      }
    } else {
      icon = Icon(
        Icons.cloud_off,
        size: size,
        color: Colors.red,
      );
    }

    // Apply pulse animation if needed
    if (!status.isConnected && status.hasPendingActions) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: icon,
          );
        },
      );
    }

    return icon;
  }

  Widget _buildSyncButton() {
    return InkWell(
      onTap: _isSyncing ? null : _onSyncPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSyncing)
              RotationTransition(
                turns: _rotateAnimation,
                child: const Icon(
                  Icons.sync,
                  size: 14,
                  color: Colors.blue,
                ),
              )
            else
              const Icon(
                Icons.sync,
                size: 14,
                color: Colors.blue,
              ),
            const SizedBox(width: 4),
            Text(
              _isSyncing ? 'Syncing...' : 'Sync',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OfflineStatus status) {
    if (_isSyncing) return Colors.blue;
    if (!status.isConnected) return Colors.red;
    if (status.hasPendingActions) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(OfflineStatus status) {
    if (_isSyncing) return 'Syncing...';
    if (!status.isConnected) return 'Offline';
    if (status.hasPendingActions) return 'Sync needed';
    return 'Synchronized';
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }
}

/// Connection status widget for app bars
class ConnectionStatusBadge extends StatefulWidget {
  const ConnectionStatusBadge({super.key});

  @override
  State<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<ConnectionStatusBadge> {
  final AppwriteOfflineService _offlineService = AppwriteOfflineService();
  StreamSubscription<bool>? _connectionSubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _connectionSubscription = _offlineService.connectionStatus.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: 14,
            color: Colors.white,
          ),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

/// Bottom sheet for detailed sync status
class SyncStatusBottomSheet extends StatelessWidget {
  const SyncStatusBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SyncStatusBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          const Text(
            'Sync Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Full sync indicator
          const TimerSyncIndicator(
            compact: false,
            showSyncButton: true,
          ),
          
          const SizedBox(height: 16),
          
          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    try {
                      await AppwriteOfflineService().clearCache();
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Cache cleared successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to clear cache: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}