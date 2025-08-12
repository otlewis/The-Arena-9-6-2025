import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/discussion_chat_message.dart';
import '../models/user_profile.dart';
import '../services/unified_chat_service.dart';
import '../core/logging/app_logger.dart';

/// Mattermost-inspired chat widget for Open Discussion rooms
/// Supports both room chat and direct messages with seamless switching
class MattermostChatWidget extends StatefulWidget {
  final String currentUserId;
  final UserProfile currentUser;
  final String? roomId;
  final List<ChatParticipant> participants;
  final VoidCallback? onClose;
  final bool startWithDM;
  final String? dmTargetUserId;

  const MattermostChatWidget({
    super.key,
    required this.currentUserId,
    required this.currentUser,
    this.roomId,
    this.participants = const [],
    this.onClose,
    this.startWithDM = false,
    this.dmTargetUserId,
  });

  @override
  State<MattermostChatWidget> createState() => _MattermostChatWidgetState();
}

class _MattermostChatWidgetState extends State<MattermostChatWidget>
    with TickerProviderStateMixin {
  final UnifiedChatService _chatService = UnifiedChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  late TabController _tabController;
  List<DiscussionChatMessage> _roomMessages = [];
  List<ChatParticipant> _participants = [];
  bool _isLoading = false;
  String? _replyToMessageId;
  DiscussionChatMessage? _replyToMessage;

  @override
  void initState() {
    super.initState();
    
    // Initialize tab controller - only room chat now
    _tabController = TabController(
      length: 1,
      vsync: this,
      initialIndex: 0,
    );
    
    _tabController.addListener(_onTabChanged);
    _participants = List.from(widget.participants);
    
    // Debug logging
    AppLogger().debug('💬 CHAT WIDGET: Initialized with ${_participants.length} participants');
    for (final participant in _participants) {
      AppLogger().debug('💬 CHAT WIDGET: ${participant.username} (${participant.role})');
    }
    
    _initializeChat();
    _setupStreamListeners();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _chatService.stopSession();
    super.dispose();
  }

  void _onTabChanged() {
    // Only room chat now, so always active
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
    });
    
    if (widget.roomId != null) {
      _startRoomChat();
    }
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    try {
      await _chatService.initialize(widget.currentUserId);
      
      if (widget.roomId != null) {
        await _startRoomChat();
      }
    } catch (e) {
      AppLogger().error('Error initializing chat: $e');
      _showError('Failed to initialize chat');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startRoomChat() async {
    if (widget.roomId == null) return;
    
    try {
      await _chatService.startRoomChat(widget.roomId!);
    } catch (e) {
      AppLogger().error('Error starting room chat: $e');
      _showError('Failed to start room chat');
    }
  }


  void _setupStreamListeners() {
    // Room messages
    _chatService.roomMessages.listen((messages) {
      setState(() => _roomMessages = messages);
      _scrollToBottom();
    });
    
    // Participants
    _chatService.participants.listen((participants) {
      setState(() => _participants = participants);
    });
    
    // New messages (for auto-scroll)
    _chatService.newRoomMessage.listen((_) => _scrollToBottom());
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
    if (content.isEmpty) return;

    debugPrint('📤 Sending message: "$content"');
    debugPrint('📤 Room ID: ${widget.roomId}');

    try {
      if (widget.roomId != null) {
        debugPrint('📤 Sending room message...');
        await _chatService.sendRoomMessage(
          content: content,
          replyToId: _replyToMessageId,
          mentions: _extractMentions(content),
        );
        debugPrint('✅ Room message sent successfully');
      } else {
        debugPrint('⚠️ Cannot send message - no room available');
        _showError('No room available for messaging');
        return;
      }
      
      _messageController.clear();
      _clearReply();
    } catch (e) {
      AppLogger().error('Error sending message: $e');
      debugPrint('❌ Error sending message: $e');
      _showError('Failed to send message: ${e.toString()}');
    }
  }

  List<String> _extractMentions(String content) {
    final mentions = <String>[];
    final mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(content);
    
    for (final match in matches) {
      final username = match.group(1);
      final participant = _participants.firstWhere(
        (p) => p.username.toLowerCase() == username?.toLowerCase(),
        orElse: () => const ChatParticipant(userId: '', username: '', role: ''),
      );
      if (participant.userId.isNotEmpty) {
        mentions.add(participant.userId);
      }
    }
    
    return mentions;
  }

  void _replyToRoomMessage(DiscussionChatMessage message) {
    setState(() {
      _replyToMessageId = message.id;
      _replyToMessage = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                          onTap: () {
                            // Dismiss keyboard when tapping in chat area
                            FocusScope.of(context).unfocus();
                          },
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRoomChatView(),
                            ],
                          ),
                        ),
                ),
                _buildMessageInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF8B5CF6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping header
                FocusScope.of(context).unfocus();
              },
              child: const Text(
                'Room Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Keyboard dismiss button
          if (MediaQuery.of(context).viewInsets.bottom > 0)
            IconButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.keyboard_hide, color: Colors.white),
              tooltip: 'Hide keyboard',
            ),
          IconButton(
            onPressed: widget.onClose ?? () {},
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close chat',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF8B5CF6),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF8B5CF6),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group, size: 16),
                const SizedBox(width: 8),
                const Text('Room Chat'),
                if (_roomMessages.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_roomMessages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomChatView() {
    return Column(
      children: [
        if (_replyToMessage != null) _buildReplyPreview(),
        Expanded(
          child: _roomMessages.isEmpty
              ? _buildEmptyState('No messages yet. Start the conversation!')
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _roomMessages.length,
                  itemBuilder: (context, index) {
                    final message = _roomMessages[index];
                    final isOwn = message.senderId == widget.currentUserId;
                    final showDate = index == 0 || 
                        !_isSameDay(_roomMessages[index - 1].timestamp, message.timestamp);
                    
                    return Column(
                      children: [
                        if (showDate) _buildDateSeparator(message.timestamp),
                        _buildRoomMessage(message, isOwn),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }



  Widget _buildRoomMessage(DiscussionChatMessage message, bool isOwn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOwn) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderAvatar != null
                  ? NetworkImage(message.senderAvatar!)
                  : null,
              child: message.senderAvatar == null
                  ? Text(message.senderName.substring(0, 1).toUpperCase())
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isOwn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          message.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(message.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onLongPress: () => _showMessageOptions(message, isOwn),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOwn ? const Color(0xFF8B5CF6) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyToId != null) _buildReplyReference(message),
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isOwn ? Colors.white : Colors.black,
                          ),
                        ),
                        if (message.isEdited)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '(edited)',
                              style: TextStyle(
                                color: isOwn ? Colors.white70 : Colors.grey[600],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isOwn)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      timeago.format(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.currentUser.avatar != null
                  ? NetworkImage(widget.currentUser.avatar!)
                  : null,
              child: widget.currentUser.avatar == null
                  ? Text(widget.currentUser.name.substring(0, 1).toUpperCase())
                  : null,
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.blue[600], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderName}',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _replyToMessage!.content.length > 50
                      ? '${_replyToMessage!.content.substring(0, 50)}...'
                      : _replyToMessage!.content,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearReply,
            icon: Icon(Icons.close, color: Colors.grey[600], size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyReference(DiscussionChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${message.replyToSender}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            message.replyToContent ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final canSendMessage = widget.roomId != null;
    
    if (!canSendMessage) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 100,
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message to the room...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            width: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF8B5CF6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(DiscussionChatMessage message, bool isOwn) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _replyToRoomMessage(message);
              },
            ),
            if (isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement edit
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message.id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId);
    } catch (e) {
      _showError('Failed to delete message');
    }
  }


  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}