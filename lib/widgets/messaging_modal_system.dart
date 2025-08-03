import 'dart:async';
import 'package:flutter/material.dart';
import '../models/instant_message.dart';
import '../models/user_profile.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'simple_chat_interface.dart';

/// Modal-based messaging system that provides clean messaging UX
/// without persistent floating widgets
class MessagingModalSystem extends StatefulWidget {
  final Widget child;
  
  const MessagingModalSystem({
    super.key,
    required this.child,
  });

  @override
  State<MessagingModalSystem> createState() => _MessagingModalSystemState();
}

class _MessagingModalSystemState extends State<MessagingModalSystem> {
  final AppwriteService _appwriteService = AppwriteService();
  
  UserProfile? _currentUser;
  StreamSubscription<List<Conversation>>? _conversationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  
  final List<Conversation> _conversations = [];
  final int _unreadCount = 0;
  
  // Notification state
  bool _showNotificationBanner = false;
  String? _latestMessageFrom;
  String? _latestMessageContent;
  Timer? _notificationTimer;
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;
  Timer? _searchDebouncer;

  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    try {
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user != null && mounted) {
        final userProfile = await _appwriteService.getUserProfile(user.$id);
        if (mounted) {
          setState(() => _currentUser = userProfile);
        }
      }
      
      // Messaging service disabled (Agora removed)
      AppLogger().debug('📱 Messaging modal system disabled (Agora removed)');
    } catch (e) {
      AppLogger().error('Failed to initialize messaging system: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Notification banner for new messages
        if (_showNotificationBanner)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildNotificationBanner(),
          ),
      ],
    );
  }

  Widget _buildNotificationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.grey,
            offset: Offset(4, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _showNotificationBanner = false);
            _openMessagingModal();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.blue,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.message,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Message from $_latestMessageFrom',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_latestMessageContent != null)
                        Text(
                          _latestMessageContent!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _showNotificationBanner = false);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-2, -2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.grey,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                      size: 14,
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

  void _openMessagingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMessagingModal(),
    );
  }

  void _openDirectMessage(UserProfile otherUser) {
    if (_currentUser != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.9,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SimpleChatInterface(
            currentUser: _currentUser!,
            otherUser: otherUser,
          ),
        ),
      );
    }
  }

  Widget _buildMessagingModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-8, -8),
            blurRadius: 16,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.grey,
            offset: Offset(8, 8),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildModalHeader(),
          Expanded(
            child: _buildConversationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Messages',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _unreadCount > 9 ? '9+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-2, -2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.grey,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.person_add, color: Colors.blue.shade600),
              onPressed: () {
                setState(() => _isSearching = true);
                // Immediate focus request for better keyboard response
                Future.microtask(() {
                  if (mounted) {
                    _searchFocusNode.requestFocus();
                  }
                });
              },
              tooltip: 'Start new conversation',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_isSearching) {
      return _buildUserSearch();
    }

    return Column(
      children: [
        // Search bar always visible - made directly tappable
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: () {
              setState(() => _isSearching = true);
              // Immediate focus request
              Future.microtask(() {
                if (mounted) {
                  _searchFocusNode.requestFocus();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    offset: Offset(4, 4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search for users...',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ),
                  // Add a visual hint that it's tappable
                  Icon(Icons.keyboard, color: Colors.grey.shade400, size: 16),
                ],
              ),
            ),
          ),
        ),
        
        // Conversations list
        Expanded(
          child: _conversations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search for users above to start chatting',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  ],
                ),
              )
            : _buildConversationsListView(),
        ),
      ],
    );
  }

  Widget _buildConversationsListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final otherUser = conversation.participants.values.first;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-4, -4),
                blurRadius: 8,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.grey,
                offset: Offset(4, 4),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openConversation(conversation, otherUser),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // User avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade600,
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
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                _formatLastMessageTime(conversation.lastMessageTime),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            conversation.lastMessage ?? '',
                            style: TextStyle(
                              color: Colors.grey.shade600,
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
                          color: Colors.red.shade600,
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
      },
    );
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

  void _openConversation(Conversation conversation, UserInfo otherUser) async {
    // Close the current modal first
    Navigator.of(context).pop();
    
    // Convert UserInfo to UserProfile for the chat interface
    final otherUserProfile = UserProfile(
      id: otherUser.id,
      name: otherUser.username,
      email: '',
      avatar: otherUser.avatar,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Show the chat interface
    if (_currentUser != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.9,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SimpleChatInterface(
            currentUser: _currentUser!,
            otherUser: otherUserProfile,
          ),
        ),
      );
    }

    // Messaging service disabled (Agora removed)
    AppLogger().debug('📱 Message read marking disabled (Agora removed)');
  }

  Widget _buildUserSearch() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            enableInteractiveSelection: true,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: Colors.grey.shade800),
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              suffixIcon: _isSearchLoading 
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    onPressed: () {
                      _searchFocusNode.unfocus(); // Dismiss keyboard
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        _searchResults.clear();
                        _isSearchLoading = false;
                      });
                    },
                  ),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _performUserSearch,
          ),
        ),
        // Search results or empty state
        Expanded(
          child: _searchController.text.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Search for users to start messaging',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type a username above',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  ],
                ),
              )
            : _searchResults.isEmpty && !_isSearchLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
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
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.grey,
            offset: Offset(4, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startNewConversation(user),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // User avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade600,
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
                    style: TextStyle(
                      color: Colors.grey.shade800,
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

  void _performUserSearch(String query) async {
    // Cancel previous timer
    _searchDebouncer?.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearchLoading = false;
      });
      return;
    }
    
    // Show loading state
    setState(() => _isSearchLoading = true);
    
    // Debounce the search
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () async {
      try {
        AppLogger().info('🔍 User search disabled (Agora removed)');
        final results = <UserProfile>[];
        
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearchLoading = false;
          });
          
          AppLogger().info('🔍 Found ${results.length} users matching "$query"');
        }
      } catch (e) {
        AppLogger().error('Failed to search users: $e');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearchLoading = false;
          });
        }
      }
    });
  }

  void _startNewConversation(UserProfile user) {
    // Close the modal first
    Navigator.of(context).pop();
    
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults.clear();
    });

    // Show the chat interface with auto-focus
    if (_currentUser != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.9,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SimpleChatInterface(
            currentUser: _currentUser!,
            otherUser: user,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _notificationTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }
}

/// Extension to add messaging functionality to any context
extension MessagingModalExtension on BuildContext {
  /// Open the messaging modal from anywhere in the app
  void openMessagingModal() {
    final modalSystem = findAncestorStateOfType<_MessagingModalSystemState>();
    modalSystem?._openMessagingModal();
  }
  
  /// Show messaging modal with specific user
  void openChatWithUser(UserProfile otherUser) {
    final modalSystem = findAncestorStateOfType<_MessagingModalSystemState>();
    modalSystem?._openDirectMessage(otherUser);
  }

  /// Get the current unread message count
  int get unreadMessageCount {
    final modalSystem = findAncestorStateOfType<_MessagingModalSystemState>();
    return modalSystem?._unreadCount ?? 0;
  }
}