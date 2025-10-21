import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/coin_service.dart';
import '../core/logging/app_logger.dart';

/// A widget that displays the user's coin balance in real-time
/// Automatically updates when the balance changes in the database
class RealTimeCoinBalance extends StatefulWidget {
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool showCoinIcon;
  final double? iconSize;
  final Function(RealTimeCoinBalanceController)? onControllerCreated;

  const RealTimeCoinBalance({
    super.key,
    this.textStyle,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.showCoinIcon = true,
    this.iconSize = 20,
    this.onControllerCreated,
  });

  @override
  State<RealTimeCoinBalance> createState() => _RealTimeCoinBalanceState();
}

/// Controller for optimistic updates to the coin balance
class RealTimeCoinBalanceController {
  final _RealTimeCoinBalanceState _state;

  RealTimeCoinBalanceController(this._state);

  /// Optimistically deduct coins from the displayed balance
  /// The real-time subscription will correct it if the deduction fails
  void optimisticallyDeduct(int amount) {
    _state._optimisticallyDeduct(amount);
  }

  /// Optimistically add coins to the displayed balance
  void optimisticallyAdd(int amount) {
    _state._optimisticallyAdd(amount);
  }
}

class _RealTimeCoinBalanceState extends State<RealTimeCoinBalance> {
  final AppwriteService _appwriteService = AppwriteService();
  final CoinService _coinService = CoinService();
  
  int _coinBalance = 0;
  bool _isLoading = true;
  String? _userId;
  RealtimeSubscription? _subscription;
  bool _hasOptimisticUpdate = false;
  DateTime? _lastOptimisticUpdateTime;
  
  @override
  void initState() {
    super.initState();
    _initializeBalance();

    // Notify parent about the controller
    if (widget.onControllerCreated != null) {
      // Schedule for next frame to ensure widget is fully initialized
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onControllerCreated!(RealTimeCoinBalanceController(this));
        }
      });
    }
  }

  /// Optimistically deduct coins (called by controller)
  void _optimisticallyDeduct(int amount) {
    if (mounted) {
      setState(() {
        _coinBalance = (_coinBalance - amount).clamp(0, 999999999);
        _hasOptimisticUpdate = true;
        _lastOptimisticUpdateTime = DateTime.now();
      });
      AppLogger().debug('🪙 Optimistically deducted $amount coins. New balance: $_coinBalance');

      // Clear the optimistic flag after 5 seconds to allow real-time sync
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _hasOptimisticUpdate = false;
          });
          // Reload balance from server after optimistic period expires
          _loadBalance();
        }
      });
    }
  }

  /// Optimistically add coins (called by controller)
  void _optimisticallyAdd(int amount) {
    if (mounted) {
      setState(() {
        _coinBalance += amount;
        _hasOptimisticUpdate = true;
        _lastOptimisticUpdateTime = DateTime.now();
      });
      AppLogger().debug('🪙 Optimistically added $amount coins. New balance: $_coinBalance');

      // Clear the optimistic flag after 5 seconds to allow real-time sync
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _hasOptimisticUpdate = false;
          });
          // Reload balance from server after optimistic period expires
          _loadBalance();
        }
      });
    }
  }
  
  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
  
  Future<void> _initializeBalance() async {
    try {
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      
      _userId = user.$id;
      
      // Load initial balance
      await _loadBalance();
      
      // Subscribe to real-time updates for the user document
      _subscribeToBalanceUpdates();
      
    } catch (e) {
      AppLogger().error('Failed to initialize coin balance: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadBalance() async {
    if (_userId == null) return;
    
    try {
      final coins = await _coinService.getUserCoins(_userId!);
      if (mounted) {
        setState(() {
          _coinBalance = coins;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('Failed to load coin balance: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _subscribeToBalanceUpdates() {
    if (_userId == null) return;
    
    try {
      // Subscribe to updates on the user's document
      _subscription = _appwriteService.realtime.subscribe([
        'databases.arena_db.collections.users.documents.$_userId'
      ]);
      
      _subscription!.stream.listen((event) {
        // Check if this is an update event for the user document
        final isUpdate = event.events.any((e) =>
          e.contains('update') ||
          e.contains('databases.arena_db.collections.users.documents.$_userId')
        );

        if (isUpdate) {
          // Skip real-time updates during optimistic update period
          if (_hasOptimisticUpdate) {
            final timeSinceOptimistic = DateTime.now().difference(_lastOptimisticUpdateTime ?? DateTime.now());
            if (timeSinceOptimistic.inSeconds < 3) {
              AppLogger().debug('🪙 Skipping real-time update during optimistic period');
              return;
            }
          }

          // Balance was updated, reload it
          _loadBalance();
          AppLogger().debug('🪙 Coin balance updated via real-time subscription');
        }
      });
      
      AppLogger().debug('🔔 Subscribed to real-time coin balance updates');
    } catch (e) {
      AppLogger().error('Failed to subscribe to balance updates: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }
    
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.amber,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showCoinIcon) ...[
            Icon(
              Icons.monetization_on,
              size: widget.iconSize,
              color: widget.textStyle?.color ?? Colors.black,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '$_coinBalance',
            style: widget.textStyle ?? const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}