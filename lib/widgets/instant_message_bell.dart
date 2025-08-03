import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import '../widgets/messaging_modal_system.dart';

class InstantMessageBell extends StatefulWidget {
  final Color iconColor;
  final double iconSize;

  const InstantMessageBell({
    super.key,
    this.iconColor = Colors.red,
    this.iconSize = 24,
  });

  @override
  State<InstantMessageBell> createState() => _InstantMessageBellState();
}

/// Memoized bell icon widget for performance optimization
class _MemoizedBellIcon extends StatelessWidget {
  final Color iconColor;
  final double iconSize;
  final int unreadCount;
  
  const _MemoizedBellIcon({
    required this.iconColor,
    required this.iconSize,
    required this.unreadCount,
  });
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: iconSize + 16,
      height: iconSize + 16,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            child: Icon(
              Icons.message,
              color: iconColor,
              size: iconSize,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
}

class _InstantMessageBellState extends State<InstantMessageBell> with SingleTickerProviderStateMixin {
  final AppwriteService _appwriteService = AppwriteService();
  StreamSubscription? _unreadCountSubscription;
  StreamSubscription? _conversationsSubscription;
  final int _unreadCount = 0;
  
  // Animation controller for bell shake
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeMessaging();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _initializeMessaging() async {
    try {
      // Get current user first
      final user = await _appwriteService.getCurrentUser();
      if (user != null && mounted) {
        await _appwriteService.getUserProfile(user.$id);
      }

      // Instant messaging disabled (Agora removed)
      AppLogger().debug('📱 Instant messaging bell disabled (Agora removed)');
    } catch (e) {
      AppLogger().error('Failed to initialize instant messaging bell: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleBellTap,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final shakeOffset = _shakeAnimation.value * 2.0;
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: _MemoizedBellIcon(
              iconColor: widget.iconColor,
              iconSize: widget.iconSize,
              unreadCount: _unreadCount,
            ),
          );
        },
      ),
    );
  }

  void _handleBellTap() {
    HapticFeedback.lightImpact();
    
    // Always show the messaging interface, regardless of unread count
    _showMessagingInterface();
  }
  
  
  void _showMessagingInterface() {
    // Use the new messaging modal system
    try {
      context.openMessagingModal();
      AppLogger().info('✅ Successfully triggered MessagingModal from message bell');
    } catch (e) {
      AppLogger().error('❌ Failed to trigger MessagingModal: $e');
      _showFallbackMessage();
    }
  }

  void _showFallbackMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Messaging Interface',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _unreadCount > 0 
                  ? 'You have $_unreadCount unread message${_unreadCount == 1 ? '' : 's'}'
                  : 'No new messages',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF8B5CF6),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Got it',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _unreadCountSubscription?.cancel();
    _conversationsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}