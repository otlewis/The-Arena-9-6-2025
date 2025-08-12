import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import '../constants/appwrite.dart';
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
  RealtimeSubscription? _unreadCountSubscription;
  StreamSubscription? _conversationsSubscription;
  int _unreadCount = 0;
  
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
        // Load initial unread count
        await _loadUnreadCount(user.$id);
        
        // Subscribe to new messages for real-time count updates
        _subscribeToMessages(user.$id);
      }

      AppLogger().info('📱 🔔 InstantMessageBell initialized successfully for user: ${user?.$id}');
      AppLogger().info('📱 🔔 Initial unread count: $_unreadCount');
    } catch (e) {
      AppLogger().error('Failed to initialize instant messaging bell: $e');
    }
  }
  
  Future<void> _loadUnreadCount(String userId) async {
    try {
      // Count unread messages where user is receiver and isRead = false
      final response = await _appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('receiverId', userId),
          Query.equal('isRead', false),
          Query.limit(100), // Just for counting, we don't need all
        ],
      );
      
      if (mounted) {
        setState(() {
          _unreadCount = response.documents.length;
        });
        
        AppLogger().debug('📱 Loaded unread count: $_unreadCount');
        
        // Animate if there are unread messages
        if (_unreadCount > 0) {
          _animationController.forward();
        }
      }
    } catch (e) {
      AppLogger().error('Failed to load unread count: $e');
    }
  }
  
  void _subscribeToMessages(String userId) {
    try {
      // Test basic realtime connection first
      AppLogger().info('📱 Testing Appwrite realtime connection...');
      AppLogger().info('📱 Database ID: ${AppwriteConstants.databaseId}');
      
      // First test with a simpler subscription to see if realtime works at all
      _unreadCountSubscription = _appwriteService.realtimeInstance.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents'
      ]);
      
      _unreadCountSubscription?.stream.listen(
        (response) {
          AppLogger().info('📱 📡 REALTIME EVENT RECEIVED: ${response.events}');
          AppLogger().debug('📱 Payload: ${response.payload}');
          
          // Check for any instant message create events
          final hasCreateEvent = response.events.any((event) => 
            event.contains('instant_messages.documents') && event.contains('create'));
            
          if (hasCreateEvent) {
            final doc = response.payload;
            AppLogger().info('📱 🔄 Processing new message for user $userId');
            AppLogger().debug('📱 Message receiverId: ${doc['receiverId']}, isRead: ${doc['isRead']}');
            
            // Only count if it's for current user and unread
            if (doc['receiverId'] == userId && doc['isRead'] == false) {
              if (mounted) {
                setState(() {
                  _unreadCount++;
                });
                
                AppLogger().info('📱 🚨 NEW UNREAD MESSAGE DETECTED! Count: $_unreadCount');
                
                // Animate the bell
                _animationController.forward().then((_) {
                  _animationController.reverse();
                });
              }
            } else {
              AppLogger().debug('📱 ❌ Message not for current user or already read');
            }
          } else {
            AppLogger().debug('📱 ❌ No create event found in: ${response.events}');
          }
        },
        onError: (error) {
          AppLogger().error('📱 💥 Realtime subscription error: $error');
        },
        onDone: () {
          AppLogger().warning('📱 ⚠️ Realtime subscription closed');
        },
      );
      
      AppLogger().info('📱 ✅ Successfully subscribed to instant messages for real-time updates');
      AppLogger().info('📱 Subscription channels: databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents');
    } catch (e) {
      AppLogger().error('Failed to subscribe to messages: $e');
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
    _unreadCountSubscription?.close();
    _conversationsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}