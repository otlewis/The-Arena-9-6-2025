import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/instant_message.dart';
import '../models/user_profile.dart';
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
  final bool _showNotificationPulse = false; // Pulse animation for new messages
  
  // Position variables for draggable functionality
  double _buttonX = 20;
  double _buttonY = 150;
  
  // Streams
  StreamSubscription<List<Conversation>>? _conversationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  
  // Data
  final List<Conversation> _conversations = [];
  final int _unreadCount = 0;
  
  
  
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
      
      // IM service disabled (Agora removed)
      AppLogger().debug('📱 Floating IM widget disabled (Agora removed)');
    } catch (e) {
      AppLogger().error('Failed to initialize floating IM: $e');
    }
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
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
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
                    child: Center(
                      child: _unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _unreadCount > 9 ? '9+' : '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.message,
                            color: Colors.blue.shade600,
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                    boxShadow: const [
                      // Light shadow for depth
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-8, -8),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                      // Dark shadow for depth
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(8, 8),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _rotateAnimation,
                        child: _isExpanded 
                          ? Icon(
                              Icons.close,
                              color: Colors.grey.shade700,
                              size: 24,
                            )
                          : Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.blue.shade600,
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
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.red,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  spreadRadius: 0,
                                ),
                              ],
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
            top: -5,
            right: -5,
            child: GestureDetector(
              onTap: () {
                setState(() => _isVisible = false);
              },
              child: Container(
                width: 22,
                height: 22,
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
          ),
      ],
    );
  }

  Widget _buildConversationsBottomSheet() {
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
                // Ensure keyboard appears after the widget rebuilds
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
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
                  Text(
                    'Search for users...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
      child: Container(
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
      child: Container(
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

    // Message read marking disabled (Agora removed)
    AppLogger().debug('📱 Message read marking disabled (Agora removed)');
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
        color: Colors.red.shade600,
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