import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/sound_service.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'simple_instant_messaging.dart';

/// Simple message bell that shows unread count and opens messaging
class SimpleMessageBell extends StatefulWidget {
  final Color iconColor;
  final double iconSize;

  const SimpleMessageBell({
    super.key,
    this.iconColor = const Color(0xFF6B46C1), // Royal purple default
    this.iconSize = 24,
  });

  @override
  State<SimpleMessageBell> createState() => _SimpleMessageBellState();
}

class _SimpleMessageBellState extends State<SimpleMessageBell> {
  final AppwriteService _appwrite = AppwriteService();
  final SoundService _soundService = SoundService();
  String? _currentUserId;
  int _unreadCount = 0;
  int _previousUnreadCount = 0;
  Timer? _refreshTimer;
  RealtimeSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        setState(() => _currentUserId = user.$id);
        await _loadUnreadCount();
        
        // Subscribe to real-time message updates
        _subscribeToMessages();
        
        // Refresh unread count every 10 seconds as backup
        _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _loadUnreadCount();
        });
      }
    } catch (e) {
      AppLogger().error('Failed to initialize message bell: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    if (_currentUserId == null) return;
    
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('receiverId', _currentUserId!),
          Query.equal('isRead', false),
          Query.limit(100),
        ],
      );
      
      if (mounted) {
        // Filter out typing indicators from unread count
        final newUnreadCount = response.documents
            .where((doc) => !(doc.data['content'] ?? '').startsWith('typing_'))
            .length;
        
        // Play sound if unread count increased (new message received)
        if (newUnreadCount > _previousUnreadCount && _previousUnreadCount >= 0) {
          _soundService.playInstantMessageSound();
        }
        
        setState(() {
          _previousUnreadCount = _unreadCount;
          _unreadCount = newUnreadCount;
        });
      }
      
    } catch (e) {
      AppLogger().error('Failed to load unread count: $e');
    }
  }

  void _openMessaging() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SimpleInstantMessaging(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMessaging,
      child: SizedBox(
        width: widget.iconSize + 16,
        height: widget.iconSize + 16,
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 8,
              child: Icon(
                Icons.message,
                color: widget.iconColor,
                size: widget.iconSize,
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6B46C1), // Royal purple for notification badge
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _subscribeToMessages() {
    if (_currentUserId == null) return;
    
    try {
      _messageSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents'
      ]);
      
      _messageSubscription?.stream.listen((response) {
        final isCreate = response.events.any((e) => e.contains('create'));
        if (isCreate) {
          final doc = response.payload;
          
          // Check if this is a normal message for current user (not typing indicator)
          final content = doc['content'] ?? '';
          if (doc['receiverId'] == _currentUserId && !content.startsWith('typing_')) {
            // New message received - play sound and update count
            _soundService.playInstantMessageSound();
            _loadUnreadCount();
            
            AppLogger().info('🔔 New instant message notification played');
          }
        }
      });
      
      AppLogger().info('🔔 Subscribed to instant message notifications');
      
    } catch (e) {
      AppLogger().error('Failed to subscribe to message notifications: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageSubscription?.close();
    super.dispose();
  }
}