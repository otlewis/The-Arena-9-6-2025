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
  
  const RealTimeCoinBalance({
    super.key,
    this.textStyle,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.showCoinIcon = true,
    this.iconSize = 20,
  });

  @override
  State<RealTimeCoinBalance> createState() => _RealTimeCoinBalanceState();
}

class _RealTimeCoinBalanceState extends State<RealTimeCoinBalance> {
  final AppwriteService _appwriteService = AppwriteService();
  final CoinService _coinService = CoinService();
  
  int _coinBalance = 0;
  bool _isLoading = true;
  String? _userId;
  RealtimeSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _initializeBalance();
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
        if (event.events.contains('databases.arena_db.collections.users.documents.$_userId.update')) {
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