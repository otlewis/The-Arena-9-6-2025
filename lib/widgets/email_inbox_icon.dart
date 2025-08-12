import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import '../screens/email_inbox_screen.dart';

/// Email inbox icon with unread count badge
class EmailInboxIcon extends StatefulWidget {
  final Color iconColor;
  final double iconSize;
  
  const EmailInboxIcon({
    super.key,
    this.iconColor = const Color(0xFF8B5CF6),
    this.iconSize = 24,
  });

  @override
  State<EmailInboxIcon> createState() => _EmailInboxIconState();
}

class _EmailInboxIconState extends State<EmailInboxIcon> with SingleTickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  int _unreadCount = 0;
  RealtimeSubscription? _subscription;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _loadUnreadCount();
    _subscribeToEmails();
  }

  @override
  void dispose() {
    _subscription?.close();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final user = await _appwrite.account.get();
      final emails = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.arenaEmailsCollection,
        queries: [
          Query.equal('recipientId', user.$id),
          Query.equal('isRead', false),
          Query.equal('isArchived', false),
        ],
      );
      
      if (mounted) {
        setState(() {
          _unreadCount = emails.total;
        });
        
        if (emails.total > 0) {
          _animationController.forward().then((_) {
            _animationController.reverse();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading unread email count: $e');
    }
  }

  void _subscribeToEmails() {
    try {
      final realtime = _appwrite.realtime;
      _subscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.arenaEmailsCollection}.documents'
      ]);
      
      _subscription!.stream.listen((response) {
        if (response.events.contains(
          'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.arenaEmailsCollection}.documents.*.create'
        )) {
          // New email received
          _loadUnreadCount();
        } else if (response.events.contains(
          'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.arenaEmailsCollection}.documents.*.update'
        )) {
          // Email read status might have changed
          _loadUnreadCount();
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to emails: $e');
    }
  }

  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmailInboxScreen(),
      ),
    ).then((_) {
      // Refresh count when returning from inbox
      _loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openInbox,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  Icons.mail,
                  color: widget.iconColor,
                  size: widget.iconSize,
                ),
              );
            },
          ),
          
          // Unread count badge
          if (_unreadCount > 0)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}