import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../models/user_profile.dart';
import '../models/instant_message.dart';
// import '../services/agora_instant_messaging_service.dart'; // Agora removed
import '../core/logging/app_logger.dart';

/// Modern chat bottom sheet with file sharing capabilities
/// Leverages Agora Chat SDK for enhanced messaging experience
class AgoraChatBottomSheet extends StatefulWidget {
  final UserProfile currentUser;
  final UserProfile otherUser;
  final String? conversationId;
  final VoidCallback? onClose;

  const AgoraChatBottomSheet({
    super.key,
    required this.currentUser,
    required this.otherUser,
    this.conversationId,
    this.onClose,
  });

  @override
  State<AgoraChatBottomSheet> createState() => _AgoraChatBottomSheetState();
}

class _AgoraChatBottomSheetState extends State<AgoraChatBottomSheet>
    with TickerProviderStateMixin {
  // final AgoraInstantMessagingService _messagingService = AgoraInstantMessagingService(); // Agora removed
  
  // Placeholder methods to prevent compilation errors
  Stream<List<InstantMessage>> _getMessagesStream(String conversationId) {
    return Stream.value(<InstantMessage>[]);
  }
  
  Future<void> _markMessagesAsRead(String conversationId) async {
    // Disabled (Agora removed)
  }
  
  Future<void> _sendMessageToService({required String receiverId, required String content, required dynamic sender}) async {
    // Disabled (Agora removed)
  }
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  List<InstantMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showAttachmentOptions = false;
  String? _conversationId;
  
  // Chat colors
  static const Color _primaryColor = Color(0xFF8B5CF6);
  static const Color _backgroundColor = Color(0xFF1A1A1A);
  static const Color _surfaceColor = Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimationController.forward();
    _fadeAnimationController.forward();
  }

  void _initializeChat() async {
    try {
      AppLogger().info('🔄 Initializing chat bottom sheet...');
      
      // Generate conversation ID if not provided
      _conversationId = widget.conversationId ?? 
          _generateConversationId(widget.currentUser.id, widget.otherUser.id);
      
      AppLogger().info('💬 Chat conversation ID: $_conversationId');
      AppLogger().info('👤 Current user: ${widget.currentUser.name} (${widget.currentUser.id})');
      AppLogger().info('👥 Other user: ${widget.otherUser.name} (${widget.otherUser.id})');
      
      // Set a timeout to prevent infinite loading
      Timer(const Duration(seconds: 3), () {
        if (mounted && _isLoading) {
          AppLogger().info('⏰ Chat loading timeout - showing empty chat');
          setState(() {
            _isLoading = false;
            _messages = [];
          });
        }
      });
      
      // Load conversation history
      final messagesStream = _getMessagesStream(_conversationId!);
      messagesStream.listen((messages) {
        AppLogger().info('📨 Received ${messages.length} messages from stream');
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          _scrollToBottom();
        }
      });
      
      // Mark messages as read
      await _markMessagesAsRead(_conversationId!);
      
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

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty || _isSending) return;
    
    AppLogger().info('📤 Sending message: "${content.trim()}"');
    
    setState(() {
      _isSending = true;
    });
    
    try {
      await _sendMessageToService(
        receiverId: widget.otherUser.id,
        content: content.trim(),
        sender: widget.currentUser,
      );
      
      AppLogger().info('✅ Message sent successfully');
      _messageController.clear();
      
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

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image != null) {
        await _sendMessage('[Image: ${image.name}]');
        // TODO: Implement actual image upload with Agora Chat SDK
      }
    } catch (e) {
      AppLogger().error('❌ Failed to pick image: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Documents',
            extensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
          ),
          const XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
          ),
          const XTypeGroup(
            label: 'Videos',
            extensions: ['mp4', 'mov', 'avi', 'mkv'],
          ),
        ],
      );
      
      if (file != null) {
        await _sendMessage('[File: ${file.name}]');
        // TODO: Implement actual file upload with Agora Chat SDK
      }
    } catch (e) {
      AppLogger().error('❌ Failed to pick file: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image != null) {
        await _sendMessage('[Photo: ${image.name}]');
        // TODO: Implement actual image upload with Agora Chat SDK
      }
    } catch (e) {
      AppLogger().error('❌ Failed to take photo: $e');
    }
  }

  void _closeBottomSheet() {
    _slideAnimationController.reverse().then((_) {
      if (mounted) {
        widget.onClose?.call();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _closeBottomSheet(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping modal content
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: DraggableScrollableSheet(
                initialChildSize: 0.8,
                minChildSize: 0.4,
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: _buildMessagesList(),
                        ),
                        if (_showAttachmentOptions) _buildAttachmentOptions(),
                        _buildMessageInput(),
                      ],
                    ),
                  );
                },
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
        color: _surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          
          // User avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: _primaryColor,
            backgroundImage: widget.otherUser.avatar != null && widget.otherUser.avatar!.isNotEmpty
                ? NetworkImage(widget.otherUser.avatar!)
                : null,
            child: widget.otherUser.avatar == null || widget.otherUser.avatar!.isEmpty
                ? Text(
                    widget.otherUser.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Online', // TODO: Get actual online status
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Close button
          IconButton(
            onPressed: _closeBottomSheet,
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[800],
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation with ${widget.otherUser.name}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == widget.currentUser.id;
        final showAvatar = index == 0 || 
            _messages[index - 1].senderId != message.senderId;
        
        return _buildMessageBubble(message, isMe, showAvatar);
      },
    );
  }

  Widget _buildMessageBubble(InstantMessage message, bool isMe, bool showAvatar) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _primaryColor,
              backgroundImage: message.senderAvatar != null && message.senderAvatar!.isNotEmpty
                  ? NetworkImage(message.senderAvatar!)
                  : null,
              child: message.senderAvatar == null || message.senderAvatar!.isEmpty
                  ? Text(
                      message.senderUsername?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ] else if (!isMe) ...[
            const SizedBox(width: 40),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? _primaryColor : _surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar) ...[
                    Text(
                      message.senderUsername ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[500],
                      fontSize: 10,
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Widget _buildAttachmentOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAttachmentOption(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: _takePhoto,
          ),
          _buildAttachmentOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: _pickAndSendImage,
          ),
          _buildAttachmentOption(
            icon: Icons.attach_file,
            label: 'File',
            onTap: _pickAndSendFile,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAttachmentOptions = false;
        });
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: _primaryColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
        color: _surfaceColor,
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            onPressed: () {
              setState(() {
                _showAttachmentOptions = !_showAttachmentOptions;
              });
            },
            icon: Icon(
              _showAttachmentOptions ? Icons.close : Icons.attach_file,
              color: _primaryColor,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _primaryColor.withValues(alpha: 0.1),
              shape: const CircleBorder(),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Message input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                maxLines: null,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) {
                  _sendMessage(value);
                  _messageFocusNode.requestFocus();
                },
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: _primaryColor,
                disabledBackgroundColor: Colors.grey[600],
                shape: const CircleBorder(),
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
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }
}

/// Helper function to show the Agora Chat bottom sheet
Future<void> showAgoraChatBottomSheet(
  BuildContext context, {
  required UserProfile currentUser,
  required UserProfile otherUser,
  String? conversationId,
}) {
  AppLogger().info('🚀 showAgoraChatBottomSheet called!');
  AppLogger().info('👤 Current user: ${currentUser.name} (${currentUser.id})');
  AppLogger().info('👥 Other user: ${otherUser.name} (${otherUser.id})');
  
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      AppLogger().info('📱 Building AgoraChatBottomSheet widget...');
      return AgoraChatBottomSheet(
        currentUser: currentUser,
        otherUser: otherUser,
        conversationId: conversationId,
      );
    },
  );
}