import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../core/logging/app_logger.dart';

/// Live chat widget for real-time messaging in Arena rooms
/// 
/// A reusable component that provides YouTube Live-style chat functionality
/// across Arena, Debates & Discussions, and Open Discussion rooms.
class LiveChatWidget extends StatefulWidget {
  final String chatRoomId;
  final ChatRoomType roomType;
  final UserProfile currentUser;
  final String? userRole;
  final bool isVisible;
  final double? height;
  final double? width;
  final VoidCallback? onToggleVisibility;
  final bool showUserCount;
  final bool allowSystemMessages;

  const LiveChatWidget({
    super.key,
    required this.chatRoomId,
    required this.roomType,
    required this.currentUser,
    this.userRole,
    this.isVisible = true,
    this.height,
    this.width,
    this.onToggleVisibility,
    this.showUserCount = true,
    this.allowSystemMessages = true,
  });

  @override
  State<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends State<LiveChatWidget>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<List<ChatUserPresence>>? _presenceSubscription;
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<ChatMessage> _messages = [];
  List<ChatUserPresence> _activeUsers = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showScrollToBottom = false;
  String? _errorMessage;
  
  // Colors to match Arena theme
  static const Color _chatBackground = Color(0xFF1A1A1A);
  static const Color _messageBackground = Color(0xFF2A2A2A);
  static const Color _inputBackground = Color(0xFF3A3A3A);
  static const Color _primaryAccent = Color(0xFF8B5CF6);
  static const Color _secondaryAccent = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.isVisible) {
      _fadeAnimationController.forward();
      _slideAnimationController.forward();
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final showButton = _scrollController.offset > 200;
      if (showButton != _showScrollToBottom) {
        setState(() => _showScrollToBottom = showButton);
      }
    });
  }

  Future<void> _initializeChat() async {
    try {
      await _chatService.initialize();
      await _chatService.joinChatRoom(
        chatRoomId: widget.chatRoomId,
        user: widget.currentUser,
        userRole: widget.userRole,
      );
      
      // Subscribe to messages
      _messagesSubscription = _chatService
          .getMessagesStream(widget.chatRoomId)
          .listen(_onMessagesUpdated, onError: _onError);
      
      // Subscribe to user presence
      _presenceSubscription = _chatService
          .getPresenceStream(widget.chatRoomId)
          .listen(_onPresenceUpdated, onError: _onError);
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to chat: $e';
      });
      AppLogger().error('💬 Failed to initialize chat: $e');
    }
  }

  void _onMessagesUpdated(List<ChatMessage> messages) {
    if (!mounted) return;
    
    final shouldAutoScroll = _shouldAutoScroll();
    
    setState(() {
      _messages = messages;
      _errorMessage = null;
    });
    
    if (shouldAutoScroll) {
      _scrollToBottom();
    }
  }

  void _onPresenceUpdated(List<ChatUserPresence> presence) {
    if (!mounted) return;
    setState(() => _activeUsers = presence);
  }

  void _onError(dynamic error) {
    if (!mounted) return;
    setState(() => _errorMessage = 'Connection error: $error');
    AppLogger().error('💬 Chat stream error: $error');
  }

  bool _shouldAutoScroll() {
    if (!_scrollController.hasClients) return true;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    const threshold = 100; // Auto-scroll if within 100px of bottom
    
    return (maxScroll - currentScroll) <= threshold;
  }

  Future<void> _scrollToBottom({bool animated = true}) async {
    if (!_scrollController.hasClients) return;
    
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (animated) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      await _chatService.sendMessage(
        content: content,
        chatRoomId: widget.chatRoomId,
        roomType: widget.roomType,
        user: widget.currentUser,
        userRole: widget.userRole,
      );
      
      _messageController.clear();
      _scrollToBottom();
      
      // Haptic feedback for successful send
      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send message: $e');
      AppLogger().error('💬 Failed to send message: $e');
      
      // Error haptic feedback
      HapticFeedback.heavyImpact();
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: widget.isVisible ? _fadeAnimation.value : 0.0,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildChatContainer(),
          ),
        );
      },
    );
  }

  Widget _buildChatContainer() {
    return Container(
      height: widget.height ?? 400,
      width: widget.width ?? 300,
      decoration: BoxDecoration(
        color: _chatBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildChatHeader(),
          Expanded(child: _buildChatBody()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: _primaryAccent,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Live Chat',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (widget.showUserCount) _buildUserCount(),
          if (widget.onToggleVisibility != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onToggleVisibility,
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            '${_activeUsers.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryAccent),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeChat,
              style: ElevatedButton.styleFrom(backgroundColor: _primaryAccent),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          itemCount: _messages.length,
          itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
        ),
        if (_showScrollToBottom) _buildScrollToBottomButton(),
      ],
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isSystemMessage = message.isSystemMessage ?? false;
    final isCurrentUser = message.userId == widget.currentUser.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: isSystemMessage 
          ? _buildSystemMessage(message)
          : _buildUserMessage(message, isCurrentUser),
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _secondaryAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _secondaryAccent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message.content,
              style: const TextStyle(
                color: _secondaryAccent,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage(ChatMessage message, bool isCurrentUser) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserAvatar(message),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMessageHeader(message, isCurrentUser),
              const SizedBox(height: 2),
              _buildMessageContent(message),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(ChatMessage message) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _primaryAccent,
        border: Border.all(
          color: _getRoleColor(message.userRole),
          width: 1.5,
        ),
      ),
      child: message.userAvatar?.isNotEmpty == true
          ? ClipOval(
              child: Image.network(
                message.userAvatar!,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarFallback(message.username),
              ),
            )
          : _buildAvatarFallback(message.username),
    );
  }

  Widget _buildAvatarFallback(String username) {
    return Center(
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageHeader(ChatMessage message, bool isCurrentUser) {
    return Row(
      children: [
        Text(
          message.username,
          style: TextStyle(
            color: _getRoleColor(message.userRole),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (message.userRole != null && message.userRole != 'participant') ...[
          const SizedBox(width: 4),
          _buildRoleBadge(message.userRole!),
        ],
        const Spacer(),
        Text(
          _formatTimestamp(message.timestamp),
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 9,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    final color = _getRoleColor(role);
    final text = _getRoleDisplayText(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _messageBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: _primaryAccent,
        onPressed: () => _scrollToBottom(),
        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: _inputBackground,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: 1,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: _chatBackground,
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : _primaryAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'moderator':
        return const Color(0xFFFF6B6B);
      case 'judge':
        return const Color(0xFFFFD93D);
      case 'speaker':
        return const Color(0xFF6BCF7F);
      case 'system':
        return _secondaryAccent;
      default:
        return Colors.white;
    }
  }

  String _getRoleDisplayText(String role) {
    switch (role.toLowerCase()) {
      case 'moderator':
        return 'MOD';
      case 'judge':
        return 'JUDGE';
      case 'speaker':
        return 'SPEAKER';
      default:
        return role.toUpperCase();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    
    return '$displayHour:$minute $period';
  }


  @override
  void didUpdateWidget(LiveChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeAnimationController.forward();
        _slideAnimationController.forward();
      } else {
        _fadeAnimationController.reverse();
        _slideAnimationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _presenceSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    
    // Leave chat room
    _chatService.leaveChatRoom(
      chatRoomId: widget.chatRoomId,
      userId: widget.currentUser.id,
    );
    
    super.dispose();
  }
}