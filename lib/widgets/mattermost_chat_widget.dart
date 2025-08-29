import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  void _scrollToBottomImmediate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    AppLogger().debug('📤 Sending message: "$content"');
    AppLogger().debug('📤 Room ID: ${widget.roomId}');

    try {
      if (widget.roomId != null) {
        AppLogger().debug('📤 Sending room message...');
        await _chatService.sendRoomMessage(
          content: content,
          replyToId: _replyToMessageId,
          mentions: _extractMentions(content),
        );
        AppLogger().debug('✅ Room message sent successfully');
      } else {
        AppLogger().debug('⚠️ Cannot send message - no room available');
        _showError('No room available for messaging');
        return;
      }
      
      _messageController.clear();
      _clearReply();
      // Ensure scroll to bottom after sending message, even with keyboard open
      _scrollToBottomImmediate();
    } catch (e) {
      AppLogger().error('Error sending message: $e');
      AppLogger().debug('❌ Error sending message: $e');
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
          height: MediaQuery.of(context).viewInsets.bottom > 0 
            ? _calculateKeyboardOpenHeight(context)  // Dynamic height when keyboard is open
            : MediaQuery.of(context).size.height * 0.7, // Normal height when keyboard is closed
          constraints: BoxConstraints(
            minHeight: 320, // Minimum height to show at least 4 messages
            maxHeight: MediaQuery.of(context).viewInsets.bottom > 0
              ? _calculateKeyboardOpenHeight(context)  // Max height when keyboard is open
              : MediaQuery.of(context).size.height * 0.9, // Max height when keyboard is closed
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF8F7FF),
                Colors.white,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, -4),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6B46C1), // Royal Purple
            Color(0xFFDC2626), // Scarlet
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
        labelColor: const Color(0xFF6B46C1),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF6B46C1),
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
                      color: Color(0xFF6B46C1),
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
                          _formatMessageTime(message.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onLongPress: () => _showMessageOptions(message, isOwn),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isOwn 
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF6B46C1), // Royal Purple
                              Color(0xFFDC2626), // Scarlet
                            ],
                          )
                        : null,
                      color: isOwn ? null : Colors.grey[50],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isOwn ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      border: isOwn ? null : Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isOwn 
                            ? const Color(0xFF6B46C1).withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6B46C1).withValues(alpha: 0.1),
            const Color(0xFFDC2626).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6B46C1), // Royal Purple
                  Color(0xFFDC2626), // Scarlet
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.reply_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderName}',
                  style: const TextStyle(
                    color: Color(0xFF6B46C1),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _replyToMessage!.content.length > 50
                      ? '${_replyToMessage!.content.substring(0, 50)}...'
                      : _replyToMessage!.content,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6B46C1).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: _clearReply,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF6B7280),
                size: 16,
              ),
            ),
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
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF6B46C1).withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6B46C1), // Royal Purple
                  Color(0xFFDC2626), // Scarlet
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF6B46C1).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6B46C1).withValues(alpha: 0.1),
                  const Color(0xFFDC2626).withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: const Color(0xFF6B46C1).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
        top: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 80,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF6B46C1).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message to the room...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: Color(0xFF6B46C1),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6B46C1), // Royal Purple
                  Color(0xFFDC2626), // Scarlet
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B46C1).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send_rounded,
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

  double _calculateKeyboardOpenHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;
    
    // Calculate height that ensures at least 4 messages are visible
    // Header (~80px) + Tab bar (~48px) + Message input (~64px) + 4 messages (~240px) = ~432px minimum
    const minRequiredHeight = 400.0;
    
    // Use 60% of available height but ensure minimum for 4 messages
    final calculatedHeight = availableHeight * 0.6;
    
    return calculatedHeight > minRequiredHeight ? calculatedHeight : minRequiredHeight;
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      // Show time for today's messages
      return DateFormat('h:mm a').format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Show "Yesterday" + time for yesterday's messages
      return 'Yesterday ${DateFormat('h:mm a').format(timestamp)}';
    } else if (now.difference(messageDate).inDays < 7) {
      // Show day name + time for this week
      return DateFormat('EEEE h:mm a').format(timestamp);
    } else {
      // Show date + time for older messages
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}