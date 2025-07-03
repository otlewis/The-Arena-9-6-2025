import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../widgets/user_avatar.dart';

class ArenaChatPanel extends ConsumerStatefulWidget {
  const ArenaChatPanel({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ArenaChatPanel> createState() => _ArenaChatPanelState();
}

class _ArenaChatPanelState extends ConsumerState<ArenaChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arenaState = ref.watch(arenaProvider(widget.roomId));

    if (arenaState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (arenaState.error != null) {
      return _buildErrorState(context, arenaState.error!);
    }
    
    return _buildChatPanel(context, ref, arenaState);
  }

  Widget _buildChatPanel(BuildContext context, WidgetRef ref, ArenaState state) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChatHeader(state),
          const Divider(height: 1),
          Expanded(
            child: _buildMessagesList(state),
          ),
          const Divider(height: 1),
          _buildMessageInput(ref, state),
        ],
      ),
    );
  }

  Widget _buildChatHeader(ArenaState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline),
          const SizedBox(width: 8),
          const Text(
            'Arena Chat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${state.participants.length} participants',
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

  Widget _buildMessagesList(ArenaState state) {
    // In a real implementation, you'd have a messages provider
    // For now, we'll show a placeholder structure
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 10, // Placeholder
      itemBuilder: (context, index) => _buildMessageItem(
        message: ChatMessage(
          id: 'msg_$index',
          userId: 'user_$index',
          userName: 'User $index',
          content: 'This is a sample message $index',
          timestamp: DateTime.now().subtract(Duration(minutes: index)),
          type: index % 3 == 0 ? MessageType.system : MessageType.user,
        ),
        state: state,
      ),
    );
  }

  Widget _buildMessageItem({
    required ChatMessage message,
    required ArenaState state,
  }) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwnMessage = message.userId == currentUserId;
    final participant = state.participants[message.userId];

    if (message.type == MessageType.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
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
                color: isOwnMessage ? Colors.blue.shade600 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isOwnMessage ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isOwnMessage ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOwnMessage)
                    Text(
                      message.userName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(participant?.role),
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
              radius: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(WidgetRef ref, ArenaState state) {
    final canSendMessage = _canUserSendMessage(ref, state);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: canSendMessage,
              decoration: InputDecoration(
                hintText: canSendMessage 
                    ? 'Type a message...' 
                    : 'Chat disabled during this phase',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: canSendMessage ? (_) => _sendMessage(ref) : null,
              onChanged: (value) {
                setState(() {
                  _isTyping = value.isNotEmpty;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: canSendMessage && _isTyping ? () => _sendMessage(ref) : null,
            backgroundColor: canSendMessage && _isTyping 
                ? Colors.blue.shade600 
                : Colors.grey.shade300,
            child: Icon(
              Icons.send,
              color: canSendMessage && _isTyping ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Chat Unavailable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load chat: ${error.toString()}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _canUserSendMessage(WidgetRef ref, ArenaState state) {
    final currentUserId = ref.read(currentUserIdProvider);
    
    // Allow messaging during preparation and judging phases
    if (state.currentPhase == DebatePhase.preDebate ||
        state.currentPhase == DebatePhase.judging) {
      return true;
    }
    
    // During debate phases, only allow judges and moderators to send messages
    final participant = state.participants[currentUserId];
    return participant?.role == ArenaRole.judge1 || 
           participant?.role == ArenaRole.judge2 ||
           participant?.role == ArenaRole.judge3 ||
           participant?.role == ArenaRole.moderator;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    
    return name[0].toUpperCase();
  }

  Color _getRoleColor(ArenaRole? role) {
    switch (role) {
      case ArenaRole.affirmative:
        return Colors.blue;
      case ArenaRole.negative:
        return Colors.red;
      case ArenaRole.moderator:
        return Colors.purple;
      case ArenaRole.judge1:
      case ArenaRole.judge2:
      case ArenaRole.judge3:
        return Colors.orange;
      case ArenaRole.audience:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  void _sendMessage(WidgetRef ref) {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final validation = validateMessage(content);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation)),
      );
      return;
    }

    // Send message through provider
    ref.read(arenaProvider(widget.roomId).notifier).sendMessage(content);
    
    _messageController.clear();
    setState(() {
      _isTyping = false;
    });

    // Scroll to bottom
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
}

// Chat message model
class ChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime timestamp;
  final MessageType type;

  ChatMessage({
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