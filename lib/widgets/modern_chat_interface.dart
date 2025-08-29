import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:file_selector/file_selector.dart'; // Will be used for document picking
import '../models/user_profile.dart';
import '../models/instant_message.dart';
import '../core/logging/app_logger.dart';

/// Modern chat interface that looks like iPhone Messages
class ModernChatInterface extends StatefulWidget {
  final UserProfile currentUser;
  final UserProfile otherUser;
  final String? conversationId;
  final VoidCallback? onClose;

  const ModernChatInterface({
    super.key,
    required this.currentUser,
    required this.otherUser,
    this.conversationId,
    this.onClose,
  });

  @override
  State<ModernChatInterface> createState() => _ModernChatInterfaceState();
}

class _ModernChatInterfaceState extends State<ModernChatInterface>
    with TickerProviderStateMixin {
  // Placeholder messaging service (LiveKit chat integration pending)
  final _messagingService = _DisabledMessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  // final ImagePicker _imagePicker = ImagePicker(); // Will be used for image picking
  
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  
  List<InstantMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _conversationId;
  
  // New message notifications from other users
  String? _newMessageFromOtherUser;
  String? _newMessageFromOtherUserId;
  String? _newMessageContent;
  bool _isOpeningOtherChat = false;
  Timer? _notificationTimer;
  StreamSubscription? _conversationsSubscription;
  
  // Track previous unread counts to detect actual new messages
  final Map<String, int> _previousUnreadCounts = {};
  
  // Track last message timestamps to detect new messages
  final Map<String, DateTime> _lastMessageTimes = {};
  
  // Listen to message streams for other conversations
  final Map<String, StreamSubscription> _messageStreamSubscriptions = {};
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      // Faster animation for Android performance
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      // Simpler curve for better Android performance
      curve: Curves.easeOut,
    ));
    
    _slideAnimationController.forward();
  }

  void _initializeChat() async {
    try {
      // Generate conversation ID immediately (minimal logging for Android performance)
      _conversationId = widget.conversationId ?? 
          _generateConversationId(widget.currentUser.id, widget.otherUser.id);
      
      // Auto-focus on message input for new conversations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _messages.isEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _messageFocusNode.requestFocus();
            }
          });
        }
      });
      
      // Shorter timeout for Android performance
      Timer(const Duration(milliseconds: 1200), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
            _messages = [];
          });
        }
      });
      
      // Load conversation history with minimal logging
      final messagesStream = _messagingService.getMessagesStream(_conversationId!);
      messagesStream.listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          // Defer scrolling to not block initial render
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      });
      
      // Mark messages as read asynchronously to not block UI
      Future.microtask(() async {
        if (mounted) {
          await _messagingService.markMessagesAsRead(_conversationId!);
        }
      });
      
      // Initialize other features asynchronously for better Android performance
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _initializePreviousUnreadCounts();
          _listenForOtherUserMessages();
        }
      });
      
    } catch (e) {
      AppLogger().error('❌ Failed to initialize chat: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'conv_${sortedIds[0]}_${sortedIds[1]}';
  }
  
  void _initializePreviousUnreadCounts() {
    // Get current unread counts to establish baseline
    _messagingService.getConversationsStream().take(1).listen((conversations) {
      for (final conversation in conversations) {
        _previousUnreadCounts[conversation.id] = conversation.unreadCount;
        _lastMessageTimes[conversation.id] = conversation.lastMessageTime;
        
        // Set up message stream listeners for other conversations
        if (conversation.id != _conversationId) {
          _setupMessageListener(conversation.id);
        }
      }
      AppLogger().info('📊 Initialized previous unread counts for ${conversations.length} conversations');
    });
  }
  
  void _setupMessageListener(String conversationId) {
    // Clean up existing subscription if any
    _messageStreamSubscriptions[conversationId]?.cancel();
    
    // Listen to messages for this specific conversation
    _messageStreamSubscriptions[conversationId] = _messagingService
        .getMessagesStream(conversationId)
        .listen((messages) {
      if (!mounted || messages.isEmpty) return;
      
      // Get the latest message
      final latestMessage = messages.last;
      
      // Check if this is a new message from another user (not current user)
      if (latestMessage.senderId != widget.currentUser.id) {
        final previousTime = _lastMessageTimes[conversationId];
        
        // If this message is newer than what we've seen before, it's a new incoming message
        if (previousTime == null || latestMessage.timestamp.isAfter(previousTime)) {
          _lastMessageTimes[conversationId] = latestMessage.timestamp;
          
          // Show notification with the actual message content
          _showNewMessageNotification(
            latestMessage.senderId,
            latestMessage.senderUsername ?? 'Unknown User',
            latestMessage.content,
          );
          
          AppLogger().info('🔔 NEW message detected via stream: ${latestMessage.content}');
        }
      }
    });
  }
  
  void _showNewMessageNotification(String senderId, String senderName, String messageContent) {
    if (!mounted) return;
    
    AppLogger().info('🔔 New message notification data:');
    AppLogger().info('🔔   Sender ID: $senderId');
    AppLogger().info('🔔   Sender Name: $senderName');
    AppLogger().info('🔔   Message: $messageContent');
    AppLogger().info('🔔   Current User ID: ${widget.currentUser.id}');
    
    // Only show if it's different from currently displayed notification
    if (_newMessageFromOtherUserId != senderId) {
      setState(() {
        _newMessageFromOtherUser = senderName;
        _newMessageFromOtherUserId = senderId;
        _newMessageContent = messageContent;
      });
      
      AppLogger().info('🔔 Showing notification banner: $senderName - $messageContent');
    } else {
      AppLogger().info('🔔 Skipping notification - same user as currently displayed');
    }
  }
  
  void _listenForOtherUserMessages() {
    // Listen to conversations to set up message stream listeners and detect when conversations are read
    _conversationsSubscription = _messagingService.getConversationsStream().listen((conversations) {
      if (!mounted) return;
      
      // Set up message listeners for new conversations
      for (final conversation in conversations) {
        if (conversation.id != _conversationId && !_messageStreamSubscriptions.containsKey(conversation.id)) {
          _setupMessageListener(conversation.id);
        }
      }
      
      // Hide notification if there are no more unread messages from other users
      final unreadConversations = conversations.where((conversation) {
        return conversation.id != _conversationId && conversation.unreadCount > 0;
      }).toList();
      
      if (unreadConversations.isEmpty && _newMessageFromOtherUser != null) {
        setState(() {
          _newMessageFromOtherUser = null;
          _newMessageFromOtherUserId = null;
          _newMessageContent = null;
        });
        AppLogger().info('🔕 Hiding notification banner - no unread messages');
      }
      
      // Update tracking data
      for (final conversation in conversations) {
        _previousUnreadCounts[conversation.id] = conversation.unreadCount;
        _lastMessageTimes[conversation.id] = conversation.lastMessageTime;
      }
    });
  }
  
  void _dismissNotification() {
    _notificationTimer?.cancel();
    setState(() {
      _newMessageFromOtherUser = null;
      _newMessageFromOtherUserId = null;
      _newMessageContent = null;
    });
  }
  
  void _openOtherUserChat() {
    if (_newMessageFromOtherUserId == null) {
      AppLogger().error('❌ Cannot open chat - no user ID stored');
      return;
    }
    
    if (_isOpeningOtherChat) {
      AppLogger().info('⏳ Already opening chat, ignoring duplicate tap');
      return;
    }
    
    setState(() {
      _isOpeningOtherChat = true;
    });
    
    // Add timeout to prevent infinite loading
    Timer(const Duration(seconds: 10), () {
      if (mounted && _isOpeningOtherChat) {
        AppLogger().error('⏰ Timeout opening chat - resetting loading state');
        setState(() {
          _isOpeningOtherChat = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timeout opening conversation. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    
    AppLogger().info('🔄 Opening chat with user ID: $_newMessageFromOtherUserId');
    AppLogger().info('🔄 Current user: ${widget.currentUser.name} (${widget.currentUser.id})');
    
    // Create a simple UserProfile directly from the stored notification data
    if (_newMessageFromOtherUser != null && _newMessageFromOtherUserId != null) {
      AppLogger().info('🔧 Creating UserProfile directly from notification data');
      
      final otherUser = UserProfile(
        id: _newMessageFromOtherUserId!,
        name: _newMessageFromOtherUser!,
        email: '${_newMessageFromOtherUserId!}@arena.app',
        avatar: null, // We don't have avatar info from notification
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      AppLogger().info('✅ Created UserProfile: ${otherUser.name} (${otherUser.id})');
      _openChatWithUser(otherUser);
    } else {
      AppLogger().error('❌ Missing notification data - cannot create user profile');
      setState(() {
        _isOpeningOtherChat = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing user information. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _openChatWithUser(UserProfile otherUser) {
    AppLogger().info('🚀 Opening chat with user: ${otherUser.name}');
    
    // Dismiss the notification first
    _dismissNotification();
    
    if (mounted) {
      Navigator.of(context).pop();
      
      // Small delay to ensure smooth transition
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isOpeningOtherChat = false;
          });
          AppLogger().info('🎯 Showing chat interface with ${otherUser.name}');
          showModernChatInterface(
            context,
            currentUser: widget.currentUser,
            otherUser: otherUser,
          );
        }
      });
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

  void _scrollToBottomOnKeyboard() {
    // Scroll to bottom when keyboard appears
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Scroll to bottom when keyboard appears
    if (keyboardHeight > 0) {
      _scrollToBottomOnKeyboard();
    }
    
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      resizeToAvoidBottomInset: false, // Handle keyboard manually
      body: GestureDetector(
        onTap: () => _closeChat(),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping modal content
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.1,
                  bottom: keyboardHeight, // Adjust for keyboard
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5), // Light background like iPhone messages
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    // New message notification from other user
                    if (_newMessageFromOtherUser != null)
                      _buildNewMessageNotification(),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
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
      ),
    );
  }

  Widget _buildNewMessageNotification() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.message,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New message from $_newMessageFromOtherUser',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_newMessageContent != null && _newMessageContent!.isNotEmpty)
                  const SizedBox(height: 4),
                if (_newMessageContent != null && _newMessageContent!.isNotEmpty)
                  Text(
                    _newMessageContent!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isOpeningOtherChat ? null : _openOtherUserChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isOpeningOtherChat 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isOpeningOtherChat
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _dismissNotification,
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
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
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF007AFF)),
            onPressed: _closeChat,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF007AFF),
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
        onTap: () {
          // Dismiss keyboard when tapping empty area
          FocusScope.of(context).unfocus();
        },
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
      onTap: () {
        // Dismiss keyboard when tapping on messages
        FocusScope.of(context).unfocus();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          // Dismiss keyboard when user starts scrolling
          if (scrollNotification is ScrollStartNotification) {
            FocusScope.of(context).unfocus();
          }
          return false;
        },
        child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      // Add caching for better performance
      cacheExtent: 1000, // Cache 1000 pixels worth of items
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == widget.currentUser.id;
        final showAvatar = !isMe && (index == _messages.length - 1 || 
            _messages[index + 1].senderId != message.senderId);
        
        // Use a key for better widget recycling
        return MessageBubbleWidget(
          key: ValueKey(message.id),
          message: message,
          isMe: isMe,
          showAvatar: showAvatar,
          currentUser: widget.currentUser,
          otherUser: widget.otherUser,
        );
      },
      ),
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF8E8E93)),
            onPressed: _showAttachmentOptions,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
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
                  // Scroll to bottom when user taps on input and ensure keyboard appears
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollToBottom();
                  });
                  
                  // Ensure focus is properly set
                  if (!_messageFocusNode.hasFocus) {
                    _messageFocusNode.requestFocus();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Start typing...',
                  hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: MediaQuery.of(context).viewInsets.bottom > 0
                      ? IconButton(
                          icon: const Icon(Icons.keyboard_hide),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                          },
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
            onTap: _sendMessage,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  onTap: _pickDocument,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF007AFF),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF007AFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    // TODO: Implement image picking
  }

  Future<void> _pickDocument() async {
    Navigator.pop(context);
    // TODO: Implement document picking
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    AppLogger().info('📤 Sending message: "$content"');

    setState(() {
      _isSending = true;
    });

    try {
      await _messagingService.sendMessage(
        receiverId: widget.otherUser.id,
        content: content,
        sender: widget.currentUser,
      );

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
        setState(() {
          _isSending = false;
        });
      }
    }
  }


  void _closeChat() {
    _slideAnimationController.reverse().then((_) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _notificationTimer?.cancel();
    _conversationsSubscription?.cancel();
    
    // Cancel all message stream subscriptions
    for (final subscription in _messageStreamSubscriptions.values) {
      subscription.cancel();
    }
    _messageStreamSubscriptions.clear();
    
    super.dispose();
  }
}

/// Optimized message avatar widget
class _MessageAvatar extends StatelessWidget {
  final UserProfile user;
  final double radius;
  
  const _MessageAvatar({
    required this.user,
    required this.radius,
  });
  
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF007AFF),
      backgroundImage: user.avatar != null
          ? NetworkImage(user.avatar!)
          : null,
      child: user.avatar == null
          ? Text(
              user.name[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.85,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

/// Optimized message bubble content
class _MessageBubbleContent extends StatelessWidget {
  final InstantMessage message;
  final bool isMe;
  
  const _MessageBubbleContent({
    required this.message,
    required this.isMe,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF8B5CF6) : const Color(0xFFE9E9EB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// Optimized message timestamp widget
class _MessageTimestamp extends StatelessWidget {
  final DateTime timestamp;
  final bool isMe;
  
  const _MessageTimestamp({
    required this.timestamp,
    required this.isMe,
  });
  
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
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatMessageTime(timestamp),
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.done_all,
            size: 14,
            color: Color(0xFF8B5CF6),
          ),
        ],
      ],
    );
  }
}

/// Optimized message bubble widget for better performance
class MessageBubbleWidget extends StatelessWidget {
  final InstantMessage message;
  final bool isMe;
  final bool showAvatar;
  final UserProfile currentUser;
  final UserProfile otherUser;
  
  const MessageBubbleWidget({
    required super.key,
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.currentUser,
    required this.otherUser,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            _MessageAvatar(
              user: otherUser,
              radius: 14,
            ),
          if (!isMe && !showAvatar)
            const SizedBox(width: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _MessageBubbleContent(
                  message: message,
                  isMe: isMe,
                ),
                const SizedBox(height: 4),
                _MessageTimestamp(
                  timestamp: message.timestamp,
                  isMe: isMe,
                ),
              ],
            ),
          ),
          if (isMe) ...[ 
            const SizedBox(width: 8),
            _MessageAvatar(
              user: currentUser,
              radius: 14,
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper function to show the modern chat interface (optimized for Android)
Future<void> showModernChatInterface(
  BuildContext context, {
  required UserProfile currentUser,
  required UserProfile otherUser,
  String? conversationId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Optimizations for Android performance
    enableDrag: true,
    useSafeArea: true,
    // Use a more efficient transition
    transitionAnimationController: null,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => RepaintBoundary(
        child: ModernChatInterface(
          currentUser: currentUser,
          otherUser: otherUser,
          conversationId: conversationId,
        ),
      ),
    ),
  );
}

// Placeholder class to prevent compilation errors (Agora functionality disabled)
class _DisabledMessagingService {
  Stream<List<InstantMessage>> getMessagesStream(String conversationId) {
    return Stream.value(<InstantMessage>[]);
  }
  
  Future<void> markMessagesAsRead(String conversationId) async {
    // Disabled
  }
  
  Future<void> sendMessage({
    required String receiverId,
    required String content,
    required UserProfile sender,
  }) async {
    // Disabled
  }
  
  Future<String> createOrGetConversation({
    required String userId1,
    required String userId2,
  }) async {
    return 'disabled';
  }
  
  Stream<List<dynamic>> getConversationsStream() {
    return Stream.value([]);
  }
}