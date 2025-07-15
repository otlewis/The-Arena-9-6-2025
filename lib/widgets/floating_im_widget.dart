import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/instant_message.dart';
import '../models/user_profile.dart';
import '../services/instant_messaging_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Floating instant messaging widget that appears globally
class FloatingIMWidget extends StatefulWidget {
  final Widget child;
  
  const FloatingIMWidget({
    super.key,
    required this.child,
  });

  @override
  State<FloatingIMWidget> createState() => _FloatingIMWidgetState();
}

class _FloatingIMWidgetState extends State<FloatingIMWidget>
    with SingleTickerProviderStateMixin {
  final InstantMessagingService _imService = InstantMessagingService();
  final AppwriteService _appwriteService = AppwriteService();
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  
  // State variables
  bool _isExpanded = false;
  bool _showConversations = true;
  String? _activeConversationId;
  UserProfile? _currentUser;
  UserProfile? _activeRecipient;
  
  // Streams
  StreamSubscription<List<Conversation>>? _conversationsSubscription;
  StreamSubscription<List<InstantMessage>>? _messagesSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  
  // Data
  List<Conversation> _conversations = [];
  List<InstantMessage> _messages = [];
  int _unreadCount = 0;
  
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeIM();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeIM() async {
    try {
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        final userProfile = await _appwriteService.getUserProfile(user.$id);
        setState(() => _currentUser = userProfile);
      }
      
      // Initialize IM service
      await _imService.initialize();
      
      // Subscribe to conversations
      _conversationsSubscription = _imService
          .getConversationsStream()
          .listen((conversations) {
        setState(() => _conversations = conversations);
      });
      
      // Subscribe to unread count
      _unreadCountSubscription = _imService
          .getUnreadCountStream()
          .listen((count) {
        setState(() => _unreadCount = count);
      });
    } catch (e) {
      AppLogger().error('Failed to initialize floating IM: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          right: 20,
          child: _buildFloatingButton(),
        ),
        if (_isExpanded) _buildExpandedView(),
      ],
    );
  }

  Widget _buildFloatingButton() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _rotateAnimation,
              child: Icon(
                _isExpanded ? Icons.close : Icons.chat_bubble,
                color: Colors.white,
                size: 28,
              ),
            ),
            if (_unreadCount > 0 && !_isExpanded)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
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
      ),
    );
  }

  Widget _buildExpandedView() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 150,
      right: 20,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.bottomRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            constraints: const BoxConstraints(
              maxWidth: 350,
              maxHeight: 500,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _showConversations
                      ? _buildConversationsList()
                      : _buildChatView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          if (!_showConversations)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _backToConversations,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _showConversations
                  ? 'Messages'
                  : _activeRecipient?.name ?? 'Chat',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_showConversations)
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              onPressed: () => setState(() => _isSearching = true),
              tooltip: 'Start new conversation',
            ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_isSearching) {
      return _buildUserSearch();
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isSearching = true),
              icon: const Icon(Icons.person_add),
              label: const Text('Start a conversation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final otherUser = conversation.participants.values.first;
        
        return _buildConversationTile(conversation, otherUser);
      },
    );
  }

  Widget _buildConversationTile(Conversation conversation, UserInfo otherUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openConversation(conversation, otherUser),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8B5CF6),
                    image: otherUser.avatar != null
                        ? DecorationImage(
                            image: NetworkImage(otherUser.avatar!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: otherUser.avatar == null
                      ? Center(
                          child: Text(
                            otherUser.username[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherUser.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatLastMessageTime(conversation.lastMessageTime),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.lastMessage ?? '',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Unread badge
                if (conversation.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSearch() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchResults.clear();
                  });
                },
              ),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _performUserSearch,
          ),
        ),
        // Search results
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              return _buildUserSearchTile(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserSearchTile(UserProfile user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _startNewConversation(user),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8B5CF6),
                    image: user.avatar != null
                        ? DecorationImage(
                            image: NetworkImage(user.avatar!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.avatar == null
                      ? Center(
                          child: Text(
                            user.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Username
                Expanded(
                  child: Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Start a conversation!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  controller: _messagesScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderId == _currentUser?.id;
                    return _buildMessageBubble(message, isMe);
                  },
                ),
        ),
        // Message input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(InstantMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF8B5CF6) : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: Color(0xFF8B5CF6)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    HapticFeedback.lightImpact();
  }

  void _openConversation(Conversation conversation, UserInfo otherUser) async {
    setState(() {
      _showConversations = false;
      _activeConversationId = conversation.id;
      _activeRecipient = UserProfile(
        id: otherUser.id,
        name: otherUser.username,
        email: '',
        avatar: otherUser.avatar,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    // Subscribe to messages
    _messagesSubscription?.cancel();
    _messagesSubscription = _imService
        .getMessagesStream(conversation.id)
        .listen((messages) {
      setState(() => _messages = messages);
      _scrollToBottom();
    });

    // Mark messages as read
    await _imService.markMessagesAsRead(conversation.id);
  }

  void _backToConversations() {
    setState(() {
      _showConversations = true;
      _activeConversationId = null;
      _activeRecipient = null;
      _messages.clear();
    });
    
    _messagesSubscription?.cancel();
  }

  void _performUserSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    final results = await _imService.searchUsers(query);
    setState(() => _searchResults = results);
  }

  void _startNewConversation(UserProfile user) {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults.clear();
      _showConversations = false;
      _activeRecipient = user;
      _activeConversationId = InstantMessageAppwrite.generateConversationId(
        _currentUser!.id,
        user.id,
      );
    });

    // Subscribe to messages
    _messagesSubscription?.cancel();
    _messagesSubscription = _imService
        .getMessagesStream(_activeConversationId!)
        .listen((messages) {
      setState(() => _messages = messages);
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUser == null || _activeRecipient == null) {
      return;
    }

    _messageController.clear();

    try {
      await _imService.sendMessage(
        receiverId: _activeRecipient!.id,
        content: content,
        sender: _currentUser!,
      );
      
      HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger().error('Failed to send message: $e');
      
      // Show error
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _formatMessageTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    
    return '$displayHour:$minute $period';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _messagesScrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }
}