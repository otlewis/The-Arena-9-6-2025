import 'package:flutter/material.dart';
import '../models/message.dart';
// import '../services/chat_service.dart'; // Old chat service removed
import '../widgets/user_avatar.dart';
import 'dart:async';

// Colors
const Color scarletRed = Color(0xFFDC143C);
const Color accentPurple = Color(0xFF9966CC);
const Color deepPurple = Color(0xFF4A0E4E);
const Color lightScarlet = Color(0xFFFFE4E1);

class ModernChatWidget extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> currentUser;
  final Map<String, dynamic> userProfiles; // Map of userId -> UserProfile
  final bool isVisible;
  final VoidCallback? onClose;

  const ModernChatWidget({
    super.key,
    required this.roomId,
    required this.currentUser,
    required this.userProfiles,
    required this.isVisible,
    this.onClose,
  });

  @override
  State<ModernChatWidget> createState() => _ModernChatWidgetState();
}

class _ModernChatWidgetState extends State<ModernChatWidget> {
  // final ChatService _chatService = ChatService(); // Old chat service removed
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  List<Message> _messages = [];
  StreamSubscription? _messagesSubscription;
  

  
  // bool _isUserScrolling = false; // Removed with old chat system

  @override
  void initState() {
    super.initState();
    _setupChat();
  }

  void _setupChat() {
    // Old chat service removed - using new chat system
    // _chatService.subscribeToRoomMessages(widget.roomId);
    // Old chat service removed - using new chat system
    setState(() {
      _messages = []; // Empty messages since old chat is disabled
    });
  }


  void _toggleChat() {
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    
    final content = _messageController.text.trim();
    _messageController.clear();

    // Old chat service removed - using new chat system
    {
      // Show error and restore text
      _messageController.text = content;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() => _isSending = false);
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    // _chatService.unsubscribe(); // Old chat service removed
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    
    return _buildChatInterface();
  }

  Widget _buildChatInterface() {
    return Positioned(
      bottom: 80,
      right: 16,
      left: 16,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: scarletRed.withValues(alpha: 0.05),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildChatHeader(),
            Expanded(child: _buildMessagesList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [scarletRed, accentPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Room Chat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${_messages.length}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleChat,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to say something!',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Scroll tracking removed with old chat system
        // if (notification is ScrollStartNotification) {
        //   _isUserScrolling = true;
        // } else if (notification is ScrollEndNotification) {
        //   Future.delayed(const Duration(seconds: 2), () {
        //     _isUserScrolling = false;
        //   });
        // }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        reverse: true, // Show newest at bottom
        itemBuilder: (context, index) {
          final message = _messages[_messages.length - 1 - index];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isCurrentUser = message.senderId == widget.currentUser['id'];
    final isSystemMessage = message.isSystemMessage;
    final isGiftMessage = message.metadata['messageType'] == 'gift';
    
    if (isSystemMessage) {
      return _buildSystemMessage(message, isGiftMessage);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isCurrentUser 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            UserAvatar(
              avatarUrl: message.senderAvatar,
              initials: message.senderName.isNotEmpty 
                ? message.senderName[0] 
                : 'U',
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 8),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        color: deepPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentUser 
                      ? scarletRed 
                      : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomLeft: isCurrentUser 
                        ? const Radius.circular(18) 
                        : const Radius.circular(4),
                      bottomRight: isCurrentUser 
                        ? const Radius.circular(4) 
                        : const Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : deepPurple,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            UserAvatar(
              avatarUrl: message.senderAvatar,
              initials: 'YOU',
              radius: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemMessage(Message message, bool isGiftMessage) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isGiftMessage 
              ? Colors.pink.shade50 
              : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGiftMessage 
                ? Colors.pink.shade200 
                : Colors.blue.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGiftMessage) ...[
                const Icon(
                  Icons.card_giftcard,
                  color: Colors.pink,
                  size: 16,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isGiftMessage 
                      ? Colors.pink.shade700 
                      : Colors.blue.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [scarletRed, accentPurple],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _isSending ? null : _sendMessage,
                child: Center(
                  child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
} 