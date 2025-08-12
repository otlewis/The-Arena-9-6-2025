import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../models/user_profile.dart';
import '../services/appwrite_service.dart';
import '../services/sound_service.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';

/// Simple, reliable chat interface using same pattern as room chat
class SimpleChatInterface extends StatefulWidget {
  final UserProfile currentUser;
  final UserProfile otherUser;
  final String? conversationId;
  final VoidCallback? onClose;

  const SimpleChatInterface({
    super.key,
    required this.currentUser,
    required this.otherUser,
    this.conversationId,
    this.onClose,
  });

  @override
  State<SimpleChatInterface> createState() => _SimpleChatInterfaceState();
}

class _SimpleChatInterfaceState extends State<SimpleChatInterface> {
  final AppwriteService _appwrite = AppwriteService();
  final SoundService _soundService = SoundService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _conversationId;
  RealtimeSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() async {
    try {
      // Generate conversation ID
      _conversationId = widget.conversationId ?? 
          _generateConversationId(widget.currentUser.id, widget.otherUser.id);
      
      AppLogger().info('💬 Initializing chat between ${widget.currentUser.name} and ${widget.otherUser.name}');
      AppLogger().info('💬 Conversation ID: $_conversationId');
      
      // Load existing messages
      await _loadMessages();
      
      // Setup realtime updates
      _setupRealtimeUpdates();
      
      // Auto-focus on message input
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messageFocusNode.requestFocus();
        }
      });
      
    } catch (e) {
      AppLogger().error('❌ Failed to initialize chat: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _generateConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'conv_${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<void> _loadMessages() async {
    try {
      AppLogger().info('📥 Loading messages for conversation: $_conversationId');
      
      // Query instant_messages collection for messages between these users  
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.or([
            Query.and([
              Query.equal('senderId', widget.currentUser.id),
              Query.equal('receiverId', widget.otherUser.id),
            ]),
            Query.and([
              Query.equal('senderId', widget.otherUser.id), 
              Query.equal('receiverId', widget.currentUser.id),
            ]),
          ]),
          Query.orderAsc('createdAt'),
          Query.limit(100),
        ],
      );

      final messages = response.documents
          .where((doc) => !(doc.data['content'] ?? '').startsWith('typing_')) // Filter out typing indicators
          .map((doc) => ChatMessage(
            id: doc.$id,
            senderId: doc.data['senderId'] ?? '',
            senderName: doc.data['senderUsername'] ?? 'Unknown', // Use the actual field from database
            content: doc.data['content'] ?? '',
            timestamp: DateTime.tryParse(doc.data['timestamp'] ?? doc.data['\$createdAt'] ?? '') ?? DateTime.now(),
            isMe: doc.data['senderId'] == widget.currentUser.id,
          )).toList();

      AppLogger().info('📥 Loaded ${messages.length} messages');

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      AppLogger().error('❌ Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeUpdates() {
    try {
      AppLogger().info('📡 Setting up realtime updates for chat');
      
      _messageSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents'
      ]);

      _messageSubscription?.stream.listen((response) {
        AppLogger().info('📡 Realtime update: ${response.events}');
        
        if (response.events.contains('databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents.*.create')) {
          final doc = response.payload;
          
          // Check if this message is for this conversation
          final isForThisConversation = 
              (doc['senderId'] == widget.currentUser.id && doc['receiverId'] == widget.otherUser.id) ||
              (doc['senderId'] == widget.otherUser.id && doc['receiverId'] == widget.currentUser.id);
          
          if (isForThisConversation) {
            final content = doc['content'] ?? '';
            
            // Skip typing indicators in chat display
            if (content.startsWith('typing_')) {
              return;
            }
            
            final newMessage = ChatMessage(
              id: doc['\$id'],
              senderId: doc['senderId'] ?? '',
              senderName: doc['senderUsername'] ?? 'Unknown', // Use the actual field from database
              content: content,
              timestamp: DateTime.tryParse(doc['timestamp'] ?? doc['\$createdAt'] ?? '') ?? DateTime.now(),
              isMe: doc['senderId'] == widget.currentUser.id,
            );

            AppLogger().info('📨 New message received: ${newMessage.content}');
            
            // Play notification sound for received messages (not sent by current user)
            if (!newMessage.isMe) {
              _soundService.playInstantMessageSound();
            }

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
      AppLogger().error('❌ Error setting up realtime updates: $e');
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    AppLogger().info('📤 Sending message: "$content"');
    AppLogger().info('📤 Database: ${AppwriteConstants.databaseId}, Collection: instant_messages');
    AppLogger().info('📤 From: ${widget.currentUser.id} to: ${widget.otherUser.id}');

    setState(() => _isSending = true);

    try {
      // Test if the collection exists by trying to create a document
      AppLogger().info('📤 Attempting to create document in instant_messages collection...');
      
      final document = await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        documentId: 'unique()',
        data: {
          'senderId': widget.currentUser.id,
          'receiverId': widget.otherUser.id,
          'content': content,
          'conversationId': _conversationId,
          'isRead': false, // Mark as unread initially
          'timestamp': DateTime.now().toIso8601String(),
          'senderUsername': widget.currentUser.name, // Required field
          'senderAvatar': widget.currentUser.avatar ?? '', // Required field
        },
      );
      
      AppLogger().info('📤 ✅ Document created successfully: ${document.$id}');
      AppLogger().info('✅ Message sent successfully');
      _messageController.clear();
      _scrollToBottom();

    } catch (e) {
      AppLogger().error('❌ Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping modal content
            child: Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.1,
                bottom: keyboardHeight,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B46C1)), // Royal purple
                            ),
                          )
                        : _buildMessagesList(),
                  ),
                  _buildMessageInput(),
                ],
              ),
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
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF6B46C1)), // Royal purple
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF6B46C1), // Royal purple
            backgroundImage: widget.otherUser.avatar != null
                ? NetworkImage(widget.otherUser.avatar!)
                : null,
            child: widget.otherUser.avatar == null
                ? Text(
                    widget.otherUser.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'online',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: const Center(
          child: Text(
            'No messages yet',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6B46C1), // Royal purple
              backgroundImage: widget.otherUser.avatar != null
                  ? NetworkImage(widget.otherUser.avatar!)
                  : null,
              child: widget.otherUser.avatar == null
                  ? Text(
                      widget.otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.isMe ? const Color(0xFF6B46C1) : const Color(0xFFE9E9EB), // Royal purple for sent messages
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                      ),
                    ),
                    if (message.isMe) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all,
                        size: 14,
                        color: Color(0xFF6B46C1), // Royal purple
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6B46C1), // Royal purple
              backgroundImage: widget.currentUser.avatar != null
                  ? NetworkImage(widget.currentUser.avatar!)
                  : null,
              child: widget.currentUser.avatar == null
                  ? Text(
                      widget.currentUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      final hour = time.hour;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $period';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(
          top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: const TextStyle(fontSize: 16),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onTap: () {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _scrollToBottom();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Start typing...',
                  hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: MediaQuery.of(context).viewInsets.bottom > 0
                      ? IconButton(
                          icon: const Icon(Icons.keyboard_hide),
                          onPressed: () => FocusScope.of(context).unfocus(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 20,
                          color: const Color(0xFF8E8E93),
                        )
                      : null,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : const Color(0xFF6B46C1), // Royal purple
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messageSubscription?.close();
    super.dispose();
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });
}