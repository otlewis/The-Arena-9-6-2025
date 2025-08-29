import '../core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../widgets/user_avatar.dart';
import '../services/appwrite_service.dart';
import '../core/providers/app_providers.dart';

class RoomChatPanel extends ConsumerStatefulWidget {
  const RoomChatPanel({
    super.key, 
    required this.roomId,
    required this.roomType,
    this.participantCount = 0,
  });

  final String roomId;
  final String roomType; // 'open_discussion' or 'debate_discussion'
  final int participantCount;

  @override
  ConsumerState<RoomChatPanel> createState() => _RoomChatPanelState();
}

class _RoomChatPanelState extends ConsumerState<RoomChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AppwriteService _appwrite = AppwriteService();
  bool _isTyping = false;
  List<RoomChatMessage> _messages = [];
  bool _isLoadingMessages = true;
  RealtimeSubscription? _messageSubscription;
  final Map<String, String?> _userAvatars = {}; // Cache for user avatars

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.close();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'messages',
        queries: [
          Query.equal('roomId', widget.roomId),
          Query.orderAsc('timestamp'),
          Query.limit(100),
        ],
      );

      final messages = response.documents.map((doc) => RoomChatMessage(
        id: doc.$id,
        userId: doc.data['senderId'] ?? '',
        userName: doc.data['senderName'] ?? 'Unknown',
        content: doc.data['content'] ?? '',
        timestamp: DateTime.tryParse(doc.data['timestamp'] ?? '') ?? DateTime.now(),
        type: doc.data['type'] == 'system' ? MessageType.system : MessageType.user,
      )).toList();

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      AppLogger().debug('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  void _setupRealtimeUpdates() {
    try {
      _messageSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.messages.documents'
      ]);

      _messageSubscription?.stream.listen((response) {
        if (response.events.contains('databases.arena_db.collections.messages.documents.*.create')) {
          final doc = response.payload;
          if (doc['roomId'] == widget.roomId) {
            final newMessage = RoomChatMessage(
              id: doc['\$id'],
              userId: doc['senderId'] ?? '',
              userName: doc['senderName'] ?? 'Unknown',
              content: doc['content'] ?? '',
              timestamp: DateTime.tryParse(doc['timestamp'] ?? '') ?? DateTime.now(),
              type: doc['type'] == 'system' ? MessageType.system : MessageType.user,
            );

            if (mounted) {
              setState(() {
                _messages.add(newMessage);
              });
              _scrollToBottom();
            }
          }
        }
      });
    } catch (e) {
      AppLogger().debug('Error setting up realtime updates: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String?> _getUserAvatar(String userId) async {
    // Return cached avatar if available
    if (_userAvatars.containsKey(userId)) {
      return _userAvatars[userId];
    }

    try {
      final userProfile = await _appwrite.getUserProfile(userId);
      final avatarUrl = userProfile?.avatar;
      _userAvatars[userId] = avatarUrl; // Cache the result
      
      // Trigger rebuild to show the avatar
      if (mounted) {
        setState(() {});
      }
      
      return avatarUrl;
    } catch (e) {
      AppLogger().debug('Error fetching avatar for user $userId: $e');
      _userAvatars[userId] = null; // Cache null result to avoid repeated calls
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildChatPanel(context, ref);
  }

  Widget _buildChatPanel(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside input field
        FocusScope.of(context).unfocus();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-8, -8),
                blurRadius: 16,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.grey,
                offset: Offset(8, 8),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildChatHeader(),
              const Divider(height: 1),
              Expanded(
                child: _buildMessagesList(),
              ),
              const Divider(height: 1),
              _buildMessageInput(ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline),
          const SizedBox(width: 8),
          Text(
            widget.roomType == 'open_discussion' ? 'Open Chat' : 'Room Chat',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-2, -2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.grey,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              '${widget.participantCount} participant${widget.participantCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoadingMessages) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Be the first to send a message!',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        // Dismiss keyboard when user starts scrolling
        if (scrollNotification is ScrollStartNotification) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _messages.length,
        itemBuilder: (context, index) => _buildMessageItem(
          message: _messages[index],
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required RoomChatMessage message,
  }) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwnMessage = message.userId == currentUserId;
    
    // Get avatar URL from cached user data
    String? avatarUrl = _userAvatars[message.userId];
    
    // If no avatar cached, fetch it asynchronously
    if (!_userAvatars.containsKey(message.userId)) {
      _getUserAvatar(message.userId);
    }

    if (message.type == MessageType.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.lightBlue,
              offset: Offset(2, 2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOwnMessage) ...[
            UserAvatar(
              initials: _getInitials(message.userName),
              avatarUrl: avatarUrl,
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOwnMessage ? Colors.blue.shade600 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isOwnMessage ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isOwnMessage ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: isOwnMessage ? [
                  BoxShadow(
                    color: Colors.blue.shade800,
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.blue.shade400,
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ] : [
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  const BoxShadow(
                    color: Colors.grey,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOwnMessage)
                    Text(
                      message.userName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  if (!isOwnMessage) const SizedBox(height: 2),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isOwnMessage ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isOwnMessage ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 8),
            UserAvatar(
              initials: _getInitials(message.userName),
              avatarUrl: avatarUrl,
              radius: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    offset: Offset(4, 4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: MediaQuery.of(context).viewInsets.bottom > 0
                    ? IconButton(
                        icon: const Icon(Icons.keyboard_hide),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                        },
                        tooltip: 'Hide keyboard',
                      )
                    : null,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(ref),
              onChanged: (value) {
                setState(() {
                  _isTyping = value.isNotEmpty;
                });
              },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTyping ? Colors.blue.shade600 : Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: _isTyping ? Colors.blue.shade800 : Colors.grey.shade400,
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: _isTyping ? Colors.blue.shade400 : Colors.white,
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isTyping ? () => _sendMessage(ref) : null,
              icon: Icon(
                Icons.send,
                color: _isTyping ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    
    return name[0].toUpperCase();
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      // Convert to 12-hour format
      int hour = timestamp.hour;
      String period = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  void _sendMessage(WidgetRef ref) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final validation = validateMessage(content);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation)),
      );
      return;
    }

    try {
      final currentUser = await _appwrite.account.get();
      
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'messages',
        documentId: 'unique()',
        data: {
          'roomId': widget.roomId,
          'senderId': currentUser.$id,
          'senderName': currentUser.name,
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'user',
        },
      );
      
      _messageController.clear();
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Room chat message model
class RoomChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime timestamp;
  final MessageType type;

  RoomChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    required this.type,
  });
}

enum MessageType {
  user,
  system,
}

// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).currentUser?.$id;
});

// Message validation
String? validateMessage(String message) {
  if (message.isEmpty) return 'Message cannot be empty';
  if (message.length > 500) return 'Message too long (max 500 characters)';
  if (message.contains(RegExp(r'[<>]'))) return 'Invalid characters detected';
  return null;
}