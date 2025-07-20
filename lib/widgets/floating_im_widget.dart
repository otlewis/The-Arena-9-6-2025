import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/instant_message.dart';
import '../models/user_profile.dart';
import '../services/agora_instant_messaging_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'modern_chat_interface.dart';

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
    with TickerProviderStateMixin {
  final AgoraInstantMessagingService _imService = AgoraInstantMessagingService();
  final AppwriteService _appwriteService = AppwriteService();
  
  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _pulseAnimation;
  
  // State variables
  bool _isExpanded = false;
  UserProfile? _currentUser;
  bool _isVisible = true; // Allow users to hide the widget
  bool _showNotificationPulse = false; // Pulse animation for new messages
  
  // Position variables for draggable functionality
  double _buttonX = 20;
  double _buttonY = 150;
  
  // Streams
  StreamSubscription<List<Conversation>>? _conversationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  
  // Data
  List<Conversation> _conversations = [];
  int _unreadCount = 0;
  
  // Notification cooldown
  DateTime? _lastNotificationTime;
  
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;
  
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
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeIM() async {
    try {
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user != null && mounted) {
        final userProfile = await _appwriteService.getUserProfile(user.$id);
        if (mounted) {
          setState(() => _currentUser = userProfile);
        }
      }
      
      // Initialize IM service
      await _imService.initialize();
      
      // Subscribe to conversations
      _conversationsSubscription = _imService
          .getConversationsStream()
          .listen((conversations) {
        if (mounted) {
          setState(() => _conversations = conversations);
        }
      });
      
      // Subscribe to unread count
      _unreadCountSubscription = _imService
          .getUnreadCountStream()
          .listen((count) {
        if (mounted) {
          final previousCount = _unreadCount;
          setState(() => _unreadCount = count);
          
          AppLogger().info('📱 FloatingIM: Unread count updated from $previousCount to $count');
          
          // If we have new unread messages, trigger pulse animation
          if (count > previousCount && count > 0) {
            final now = DateTime.now();
            // Only trigger notification if it's been more than 2 seconds since last notification
            if (_lastNotificationTime == null || 
                now.difference(_lastNotificationTime!).inSeconds >= 2) {
              AppLogger().info('📱 FloatingIM: Triggering new message notification');
              _lastNotificationTime = now;
              _triggerNewMessageNotification();
            } else {
              AppLogger().info('📱 FloatingIM: Skipping notification due to cooldown');
            }
          }
        }
      });
    } catch (e) {
      AppLogger().error('Failed to initialize floating IM: $e');
    }
  }

  void _triggerNewMessageNotification() {
    if (!mounted) return;
    
    setState(() => _showNotificationPulse = true);
    
    // Start pulse animation
    _pulseController.repeat(reverse: true);
    
    // NO AUTO-OPENING - Let users decide if they want to view the message
    // This gives users control over their conversation flow
    
    // Stop pulse after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _pulseController.stop();
        setState(() => _showNotificationPulse = false);
      }
    });
    
    AppLogger().info('💬 New message notification triggered - showing banner only (no auto-open)');
  }


  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          widget.child,
          if (_isVisible) ...[
            Positioned(
              bottom: _buttonY,
              right: _buttonX,
              child: RepaintBoundary(
                child: Draggable(
                  feedback: _buildFloatingButton(),
                  childWhenDragging: Container(), // Hide original during drag
                  onDragEnd: (details) {
                    setState(() {
                      // Calculate new position relative to screen edges
                      final screenWidth = MediaQuery.of(context).size.width;
                      final screenHeight = MediaQuery.of(context).size.height;
                      
                      // Convert global position to bottom-right coordinates
                      _buttonX = screenWidth - details.offset.dx - 120; // 120 is button width
                      _buttonY = screenHeight - details.offset.dy - 120; // 120 is button height
                      
                      // Ensure button stays within screen bounds
                      _buttonX = _buttonX.clamp(20.0, screenWidth - 140);
                      _buttonY = _buttonY.clamp(100.0, screenHeight - 200);
                    });
                  },
                  child: _buildFloatingButton(),
                ),
              ),
            ),
          ],
          // Show restore button when hidden
          if (!_isVisible)
            Positioned(
              bottom: 20,
              right: 20,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () => setState(() => _isVisible = true),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _unreadCount > 0 
                        ? const Color(0xFF8B5CF6) 
                        : Colors.grey[700],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _unreadCount > 0 
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _unreadCount > 0
                        ? Text(
                            _unreadCount > 9 ? '9+' : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Icon(
                            Icons.message,
                            color: Colors.white,
                            size: 20,
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _toggleExpanded,
          behavior: HitTestBehavior.deferToChild,
          child: AnimatedBuilder(
            animation: _showNotificationPulse ? _pulseAnimation : _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _showNotificationPulse ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: _isExpanded ? BoxDecoration(
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
                  ) : const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _rotateAnimation,
                        child: _isExpanded 
                          ? const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 23,
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                // Scarlet background
                                Icon(
                                  Icons.chat_bubble_rounded,
                                  color: Color(0xFFFF2400), // Scarlet red background
                                  size: 48,
                                ),
                                // Purple lines inside
                                Icon(
                                  Icons.chat_bubble_outline_rounded, // Outline version for purple lines
                                  color: Color(0xFF8B5CF6), // Purple lines inside
                                  size: 48,
                                ),
                              ],
                            ),
                      ),
                      if (_unreadCount > 0 && !_isExpanded)
                        Positioned(
                          top: 20,
                          right: 20,
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
            },
          ),
        ),
        // Hide button (only show when not expanded)
        if (!_isExpanded)
          Positioned(
            top: 15,
            right: 15,
            child: GestureDetector(
              onTap: () {
                setState(() => _isVisible = false);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConversationsBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(),
          Expanded(
            child: _buildConversationsList(),
          ),
        ],
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
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Messages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              setState(() => _isSearching = true);
              // Ensure keyboard appears after the widget rebuilds
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _searchFocusNode.requestFocus();
              });
            },
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

    return Column(
      children: [
        // Search bar always visible
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              setState(() => _isSearching = true);
              // Ensure keyboard appears after the widget rebuilds
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _searchFocusNode.requestFocus();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[500], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Search for users...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
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
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search for users above to start chatting',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final otherUser = conversation.participants.values.first;
                  
                  return _buildConversationTile(conversation, otherUser);
                },
              ),
        ),
      ],
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
                // Optimized Avatar
                _ConversationAvatar(
                  user: otherUser,
                  size: 48,
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: _ConversationContent(
                    conversation: conversation,
                    otherUser: otherUser,
                  ),
                ),
                // Unread badge
                if (conversation.unreadCount > 0)
                  _UnreadBadge(count: conversation.unreadCount),
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
            focusNode: _searchFocusNode,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _isSearchLoading 
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
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
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
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
                    Icon(Icons.person_search, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Search for users to start messaging',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type a username above',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              )
            : _searchResults.isEmpty && !_isSearchLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
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
                // Optimized Avatar for search
                _SearchUserAvatar(
                  user: user,
                  size: 40,
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


  void _toggleExpanded() {
    if (_isExpanded) {
      // If currently expanded (bottom sheet is showing), close it
      Navigator.of(context).pop();
      setState(() => _isExpanded = false);
    } else {
      // Show bottom sheet with conversations
      showConversationsBottomSheet();
    }
    
    HapticFeedback.lightImpact();
  }
  
  void showConversationsBottomSheet() {
    setState(() => _isExpanded = true);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildConversationsBottomSheet(),
    ).then((_) {
      // Reset state when bottom sheet is dismissed
      if (mounted) {
        setState(() => _isExpanded = false);
      }
    });
  }

  void _openConversation(Conversation conversation, UserInfo otherUser) async {
    // Close the current bottom sheet first
    Navigator.of(context).pop();
    setState(() => _isExpanded = false);
    
    // Convert UserInfo to UserProfile for the bottom sheet
    final otherUserProfile = UserProfile(
      id: otherUser.id,
      name: otherUser.username,
      email: '',
      avatar: otherUser.avatar,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Show the new modern chat interface
    if (_currentUser != null && mounted) {
      showModernChatInterface(
        context,
        currentUser: _currentUser!,
        otherUser: otherUserProfile,
      );
    }

    // Mark messages as read
    await _imService.markMessagesAsRead(conversation.id);
  }


  Timer? _searchDebouncer;
  
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
        AppLogger().info('🔍 Searching for users: $query');
        final results = await _imService.searchUsers(query);
        
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
    // Close the current bottom sheet first
    Navigator.of(context).pop();
    setState(() {
      _isExpanded = false;
      _isSearching = false;
      _searchController.clear();
      _searchResults.clear();
    });

    // Show the new modern chat interface
    if (_currentUser != null && mounted) {
      showModernChatInterface(
        context,
        currentUser: _currentUser!,
        otherUser: user,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _conversationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }
}

/// Optimized conversation avatar widget
class _ConversationAvatar extends StatelessWidget {
  final UserInfo user;
  final double size;
  
  const _ConversationAvatar({
    required this.user,
    required this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
                user.username[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}

/// Optimized conversation content widget
class _ConversationContent extends StatelessWidget {
  final Conversation conversation;
  final UserInfo otherUser;
  
  const _ConversationContent({
    required this.conversation,
    required this.otherUser,
  });
  
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
  
  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

/// Optimized unread badge widget
class _UnreadBadge extends StatelessWidget {
  final int count;
  
  const _UnreadBadge({required this.count});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Optimized search user avatar widget
class _SearchUserAvatar extends StatelessWidget {
  final UserProfile user;
  final double size;
  
  const _SearchUserAvatar({
    required this.user,
    required this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}