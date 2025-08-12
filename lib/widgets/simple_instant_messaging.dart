import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/sound_service.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';

/// Simple, clean instant messaging system that actually works
class SimpleInstantMessaging extends StatefulWidget {
  const SimpleInstantMessaging({super.key});

  @override
  State<SimpleInstantMessaging> createState() => _SimpleInstantMessagingState();
}

class _SimpleInstantMessagingState extends State<SimpleInstantMessaging> {
  final AppwriteService _appwrite = AppwriteService();
  final SoundService _soundService = SoundService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // State
  String? _currentUserId;
  String? _currentUserName;
  List<SimpleUser> _users = [];
  List<SimpleMessage> _messages = [];
  List<Conversation> _conversations = [];
  SimpleUser? _selectedUser;
  bool _isLoading = false;
  int _unreadCount = 0;
  
  // Typing indicators
  bool _isTyping = false;
  bool _otherUserIsTyping = false;
  Timer? _typingTimer;
  Timer? _stopTypingTimer;
  
  // Real-time subscription
  RealtimeSubscription? _messagesSubscription;
  // Typing subscription integrated with messages subscription

  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    try {
      // Get current user
      final user = await _appwrite.getCurrentUser();
      if (user == null) return;
      
      final profile = await _appwrite.getUserProfile(user.$id);
      if (profile == null) return;
      
      setState(() {
        _currentUserId = user.$id;
        _currentUserName = profile.name;
      });
      
      // Load conversations and users
      await _loadConversations();
      await _loadUsers();
      await _loadUnreadCount();
      _subscribeToMessages();
      _subscribeToTyping();
      
      AppLogger().info('💬 Simple messaging initialized for ${profile.name}');
      
    } catch (e) {
      AppLogger().error('Failed to initialize messaging: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usersCollection,
        queries: [Query.limit(100)],
      );
      
      final users = response.documents
          .where((doc) => doc.$id != _currentUserId) // Exclude current user
          .map((doc) => SimpleUser(
                id: doc.$id,
                name: doc.data['name']?.toString() ?? 'Unknown',
                email: doc.data['email']?.toString() ?? '',
                avatar: doc.data['avatar']?.toString(),
              ))
          .toList();
      
      setState(() {
        _users = users;
        _isLoading = false;
      });
      
      AppLogger().info('💬 Loaded ${users.length} users');
      
    } catch (e) {
      AppLogger().error('Failed to load users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadCount() async {
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
      
      setState(() => _unreadCount = response.documents.length);
      
    } catch (e) {
      AppLogger().error('Failed to load unread count: $e');
    }
  }

  Future<void> _loadMessages(SimpleUser otherUser) async {
    try {
      setState(() => _isLoading = true);
      
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.or([
            Query.and([
              Query.equal('senderId', _currentUserId!),
              Query.equal('receiverId', otherUser.id),
            ]),
            Query.and([
              Query.equal('senderId', otherUser.id),
              Query.equal('receiverId', _currentUserId!),
            ]),
          ]),
          Query.orderAsc('\$createdAt'),
          Query.limit(100),
        ],
      );
      
      final messages = response.documents
          .where((doc) => !(doc.data['content'] ?? '').startsWith('typing_')) // Filter out typing indicators
          .map((doc) => SimpleMessage(
            id: doc.$id,
            senderId: doc.data['senderId'] ?? '',
            senderName: doc.data['senderUsername'] ?? 'Unknown',
            content: doc.data['content'] ?? '',
            timestamp: DateTime.tryParse(doc.data['\$createdAt'] ?? '') ?? DateTime.now(),
            isMe: doc.data['senderId'] == _currentUserId,
          )).toList();
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
      // Mark messages as read
      _markMessagesAsRead(otherUser);
      
      // Scroll to bottom after messages are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      
      AppLogger().info('💬 Loaded ${messages.length} messages with ${otherUser.name}');
      
    } catch (e) {
      AppLogger().error('Failed to load messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead(SimpleUser otherUser) async {
    try {
      // Get unread messages from this user
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('senderId', otherUser.id),
          Query.equal('receiverId', _currentUserId!),
          Query.equal('isRead', false),
        ],
      );
      
      // Mark each as read
      for (final doc in response.documents) {
        await _appwrite.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'instant_messages',
          documentId: doc.$id,
          data: {'isRead': true},
        );
      }
      
      // Update unread count
      await _loadUnreadCount();
      
    } catch (e) {
      AppLogger().error('Failed to mark messages as read: $e');
    }
  }

  Future<void> _sendMessage(String content) async {
    if (_selectedUser == null || content.trim().isEmpty) return;
    
    try {
      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        documentId: ID.unique(),
        data: {
          'senderId': _currentUserId!,
          'receiverId': _selectedUser!.id,
          'content': content.trim(),
          'conversationId': _generateConversationId(_currentUserId!, _selectedUser!.id),
          'isRead': false,
          'timestamp': DateTime.now().toIso8601String(),
          'senderUsername': _currentUserName!,
          // Remove senderAvatar field - not required
        },
      );
      
      AppLogger().info('💬 Message sent to ${_selectedUser!.name}');
      
      // Reload messages
      await _loadMessages(_selectedUser!);
      
    } catch (e) {
      AppLogger().error('Failed to send message: $e');
    }
  }

  void _subscribeToMessages() {
    try {
      _messagesSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents'
      ]);
      
      _messagesSubscription?.stream.listen((response) {
        AppLogger().info('💬 Real-time event: ${response.events}');
        
        final isCreate = response.events.any((e) => e.contains('create'));
        if (isCreate) {
          final doc = response.payload;
          
          // If it's a message for current user, update unread count
          if (doc['receiverId'] == _currentUserId) {
            
            // Check if this is a typing indicator based on content
            final content = doc['content'] ?? '';
            if (content.startsWith('typing_')) {
              // Handle typing indicator
              if (_selectedUser != null && doc['senderId'] == _selectedUser!.id) {
                final isTyping = content == 'typing_start';
                setState(() => _otherUserIsTyping = isTyping);
                
                if (isTyping) {
                  // Auto-hide typing after 4 seconds
                  _stopTypingTimer?.cancel();
                  _stopTypingTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) {
                      setState(() => _otherUserIsTyping = false);
                    }
                  });
                }
              }
            } else {
              // Normal message
              _loadUnreadCount();
              
              // Reload conversations to update the list
              _loadConversations();
              
              // Play notification sound for new messages
              _soundService.playInstantMessageSound();
              
              // If we're viewing this conversation, reload messages
              if (_selectedUser != null && doc['senderId'] == _selectedUser!.id) {
                _loadMessages(_selectedUser!);
                // Stop showing typing indicator when message received
                setState(() => _otherUserIsTyping = false);
              }
            }
          }
        }
      });
      
      AppLogger().info('💬 Subscribed to real-time messages');
      
    } catch (e) {
      AppLogger().error('Failed to subscribe to messages: $e');
    }
  }
  
  void _subscribeToTyping() {
    try {
      // Use the existing messages subscription to listen for typing events
      // Typing indicators will be sent as special message types
      AppLogger().info('💬 Typing indicators integrated with messages subscription');
      
    } catch (e) {
      AppLogger().error('Failed to subscribe to typing: $e');
    }
  }

  String _generateConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'conv_${sortedIds[0]}_${sortedIds[1]}';
  }
  
  Future<void> _loadConversations() async {
    try {
      setState(() => _isLoading = true);
      
      // Get all messages where current user is sender or receiver
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.or([
            Query.equal('senderId', _currentUserId!),
            Query.equal('receiverId', _currentUserId!),
          ]),
          Query.orderDesc('\$createdAt'),
          Query.limit(200),
        ],
      );
      
      // Group messages by conversation partner
      final Map<String, Conversation> conversationMap = {};
      
      for (final doc in response.documents) {
        final content = doc.data['content'] ?? '';
        // Skip typing indicators
        if (content.startsWith('typing_')) continue;
        
        final senderId = doc.data['senderId'];
        final receiverId = doc.data['receiverId'];
        final senderName = doc.data['senderUsername'] ?? 'Unknown';
        final timestamp = DateTime.tryParse(doc.data['\$createdAt'] ?? '') ?? DateTime.now();
        // Determine the other user in this conversation
        final otherUserId = senderId == _currentUserId ? receiverId : senderId;
        
        if (otherUserId != null && otherUserId.isNotEmpty && otherUserId != _currentUserId) {
          // Create or update conversation
          if (!conversationMap.containsKey(otherUserId)) {
            // Get unread count for this conversation
            final unreadCount = response.documents
                .where((d) => 
                    d.data['senderId'] == otherUserId && 
                    d.data['receiverId'] == _currentUserId &&
                    d.data['isRead'] != true &&
                    !(d.data['content'] ?? '').startsWith('typing_'))
                .length;
                
            conversationMap[otherUserId] = Conversation(
              otherUserId: otherUserId,
              otherUserName: senderId == _currentUserId ? 'Unknown' : senderName,
              lastMessage: content,
              lastMessageTime: timestamp,
              unreadCount: unreadCount,
              isLastMessageFromMe: senderId == _currentUserId,
            );
          } else {
            // Update if this message is more recent
            final existing = conversationMap[otherUserId]!;
            if (timestamp.isAfter(existing.lastMessageTime)) {
              conversationMap[otherUserId] = existing.copyWith(
                lastMessage: content,
                lastMessageTime: timestamp,
                isLastMessageFromMe: senderId == _currentUserId,
              );
            }
          }
        }
      }
      
      // Sort conversations by last message time and unread status
      final conversations = conversationMap.values.toList()
        ..sort((a, b) {
          // Unread conversations first
          if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
          if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
          // Then by most recent
          return b.lastMessageTime.compareTo(a.lastMessageTime);
        });
      
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
      
      AppLogger().info('💬 Loaded ${conversations.length} conversations');
      
    } catch (e) {
      AppLogger().error('Failed to load conversations: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Widget _buildConversationsList() {
    return Column(
      children: [
        // Header with search button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Color(0xFF6B46C1)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B46C1),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add, color: Color(0xFF6B46C1)),
                onPressed: () async {
                  // Show user search to start new conversation
                  final selectedUser = await Navigator.push<SimpleUser>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserSearchScreen(),
                    ),
                  );
                  
                  if (selectedUser != null) {
                    setState(() => _selectedUser = selectedUser);
                    await _loadMessages(selectedUser);
                  }
                },
                tooltip: 'Start new conversation',
              ),
            ],
          ),
        ),
        // Conversations list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to start a new conversation',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return _buildConversationTile(conversation);
                    },
                  ),
        ),
      ],
    );
  }
  
  Widget _buildConversationTile(Conversation conversation) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF6B46C1),
        child: Text(
          conversation.otherUserName[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        conversation.otherUserName,
        style: TextStyle(
          fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        conversation.isLastMessageFromMe 
            ? 'You: ${conversation.lastMessage}'
            : conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: conversation.unreadCount > 0 ? Colors.black87 : Colors.grey[600],
          fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastMessageTime),
            style: TextStyle(
              color: conversation.unreadCount > 0 ? const Color(0xFF6B46C1) : Colors.grey[500],
              fontSize: 12,
              fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (conversation.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF6B46C1),
                shape: BoxShape.circle,
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
        ],
      ),
      onTap: () async {
        // Find or create the user object
        final user = _users.firstWhere(
          (u) => u.id == conversation.otherUserId,
          orElse: () => SimpleUser(
            id: conversation.otherUserId,
            name: conversation.otherUserName,
            email: '',
            avatar: null,
          ),
        );
        
        setState(() => _selectedUser = user);
        await _loadMessages(user);
      },
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (now.difference(messageDate).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're on a mobile device
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_selectedUser != null ? _selectedUser!.name : 'Messages'),
        backgroundColor: const Color(0xFF6B46C1), // Royal purple
        foregroundColor: Colors.white,
        leading: _selectedUser != null && isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedUser = null),
              )
            : null,
        actions: [
          if (_unreadCount > 0 && _selectedUser == null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedUser == null) {
      return _buildConversationsList();
    } else {
      return _buildChatArea();
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Conversation/User list
        Container(
          width: 300,
          color: Colors.white,
          child: _buildConversationsList(),
        ),
        // Chat area
        Expanded(
          child: _selectedUser == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Select a conversation to view messages'),
                    ],
                  ),
                )
              : _buildChatArea(),
        ),
      ],
    );
  }


  Widget _buildChatArea() {
    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF6B46C1),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage: _selectedUser!.avatar != null && _selectedUser!.avatar!.isNotEmpty
                    ? NetworkImage(_selectedUser!.avatar!)
                    : null,
                child: _selectedUser!.avatar == null || _selectedUser!.avatar!.isEmpty
                    ? Text(
                        _selectedUser!.name[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFF6B46C1), fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                _selectedUser!.name,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
        ),
        // Message input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(SimpleMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: message.isMe ? const Color(0xFF6B46C1) : Colors.grey[300], // Royal purple for sent messages
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: message.isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final controller = TextEditingController();
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Typing indicator
          if (_otherUserIsTyping)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF6B46C1),
                    backgroundImage: _selectedUser?.avatar != null && _selectedUser!.avatar!.isNotEmpty
                        ? NetworkImage(_selectedUser!.avatar!)
                        : null,
                    child: _selectedUser?.avatar == null || _selectedUser!.avatar!.isEmpty
                        ? Text(
                            _selectedUser?.name[0].toUpperCase() ?? '?',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedUser?.name ?? 'User'} is typing...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B46C1)),
                    ),
                  ),
                ],
              ),
            ),
          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onChanged: (value) => _onTyping(value),
                  onSubmitted: (value) {
                    _sendMessage(value);
                    controller.clear();
                    _stopTyping();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  _sendMessage(controller.text);
                  controller.clear();
                  _stopTyping();
                },
                icon: const Icon(Icons.send),
                color: const Color(0xFF6B46C1),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _onTyping(String text) {
    if (_selectedUser == null) return;
    
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingIndicator(true);
    }
    
    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _stopTyping();
    });
  }
  
  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _sendTypingIndicator(false);
    }
    _typingTimer?.cancel();
  }
  
  Future<void> _sendTypingIndicator(bool isTyping) async {
    if (_selectedUser == null || _currentUserId == null) return;
    
    try {
      // Send typing indicator as a special content message
      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        documentId: ID.unique(),
        data: {
          'senderId': _currentUserId!,
          'receiverId': _selectedUser!.id,
          'content': isTyping ? 'typing_start' : 'typing_stop',
          'conversationId': _generateConversationId(_currentUserId!, _selectedUser!.id),
          'isRead': true, // Mark as read so it doesn't affect unread count
          'timestamp': DateTime.now().toIso8601String(),
          'senderUsername': _currentUserName!,
        },
      );
    } catch (e) {
      AppLogger().error('Failed to send typing indicator: $e');
      // Typing indicators are not critical, so we don't show error to user
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.close();
    // Typing subscription integrated with messages subscription
    _typingTimer?.cancel();
    _stopTypingTimer?.cancel();
    _stopTyping(); // Stop typing when leaving chat
    super.dispose();
  }
}

// Simple data classes
class SimpleUser {
  final String id;
  final String name;
  final String email;
  final String? avatar;

  SimpleUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
  });
}

class SimpleMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  SimpleMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });
}

class Conversation {
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isLastMessageFromMe;

  Conversation({
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isLastMessageFromMe,
  });
  
  Conversation copyWith({
    String? otherUserId,
    String? otherUserName,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isLastMessageFromMe,
  }) {
    return Conversation(
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isLastMessageFromMe: isLastMessageFromMe ?? this.isLastMessageFromMe,
    );
  }
}

/// Simple user search screen for starting new conversations
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final TextEditingController _searchController = TextEditingController();
  
  String? _currentUserId;
  List<SimpleUser> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebouncer;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
  }

  Future<void> _initializeSearch() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        setState(() => _currentUserId = user.$id);
      }
    } catch (e) {
      AppLogger().error('Failed to initialize search: $e');
    }
  }

  void _performUserSearch(String query) async {
    _searchDebouncer?.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }
    
    setState(() => _isSearching = true);
    
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final response = await _appwrite.databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.usersCollection,
          queries: [Query.limit(50)],
        );
        
        final results = response.documents
            .where((doc) => doc.$id != _currentUserId)
            .map((doc) => SimpleUser(
              id: doc.$id,
              name: doc.data['name']?.toString() ?? 'Unknown',
              email: doc.data['email']?.toString() ?? '',
              avatar: doc.data['avatar']?.toString(),
            ))
            .where((user) => 
                user.name.toLowerCase().contains(query.toLowerCase()) ||
                user.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
        
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        AppLogger().error('Failed to search users: $e');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('New Conversation'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _performUserSearch,
            ),
          ),
          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Search for users to start a conversation'
                                : 'No users found',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF6B46C1),
                            backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                                ? NetworkImage(user.avatar!)
                                : null,
                            child: user.avatar == null || user.avatar!.isEmpty
                                ? Text(
                                    user.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          onTap: () {
                            // Go back to messaging with this user selected
                            Navigator.pop(context, user);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }
}