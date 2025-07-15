import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/user_profile.dart';
import 'live_chat_widget.dart';

/// Floating chat button that toggles the live chat widget
/// 
/// Provides a YouTube Live-style floating chat button that can be positioned
/// anywhere in the UI and expands to show the full chat interface.
class FloatingChatButton extends StatefulWidget {
  final String chatRoomId;
  final ChatRoomType roomType;
  final UserProfile currentUser;
  final String? userRole;
  final bool showUnreadBadge;
  final Color? buttonColor;
  final Color? badgeColor;
  final double size;
  final EdgeInsets? margin;
  final AlignmentGeometry alignment;

  const FloatingChatButton({
    super.key,
    required this.chatRoomId,
    required this.roomType,
    required this.currentUser,
    this.userRole,
    this.showUnreadBadge = true,
    this.buttonColor,
    this.badgeColor,
    this.size = 56.0,
    this.margin,
    this.alignment = Alignment.bottomRight,
  });

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with TickerProviderStateMixin {
  bool _isChatVisible = false;
  int _unreadCount = 0;
  late AnimationController _pulseController;
  late AnimationController _expandController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  static const Color _defaultButtonColor = Color(0xFF8B5CF6);
  static const Color _defaultBadgeColor = Color(0xFFFF4757);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    ));
  }


  void _toggleChat() {
    setState(() {
      _isChatVisible = !_isChatVisible;
      if (_isChatVisible) {
        _unreadCount = 0;
      }
    });
    
    // Button press animation
    _expandController.forward().then((_) {
      _expandController.reverse();
    });
  }

  void _hideChat() {
    setState(() => _isChatVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chat widget overlay
        if (_isChatVisible) _buildChatOverlay(),
        
        // Floating button
        _buildFloatingButton(),
      ],
    );
  }

  Widget _buildChatOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideChat,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Align(
            alignment: _getChatAlignment(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LiveChatWidget(
                chatRoomId: widget.chatRoomId,
                roomType: widget.roomType,
                currentUser: widget.currentUser,
                userRole: widget.userRole,
                isVisible: _isChatVisible,
                height: MediaQuery.of(context).size.height * 0.6,
                width: MediaQuery.of(context).size.width > 600 ? 350 : 300,
                onToggleVisibility: _hideChat,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    return Positioned(
      bottom: widget.margin?.bottom ?? 16,
      right: widget.margin?.right ?? 16,
      left: widget.margin?.left,
      top: widget.margin?.top,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value * 
                   (widget.showUnreadBadge && _unreadCount > 0 
                       ? _pulseAnimation.value 
                       : 1.0),
            child: FloatingActionButton(
              onPressed: _toggleChat,
              backgroundColor: widget.buttonColor ?? _defaultButtonColor,
              heroTag: "chat_button_${widget.chatRoomId}",
              child: Stack(
                children: [
                  const Icon(
                    Icons.chat_bubble,
                    color: Colors.white,
                  ),
                  if (widget.showUnreadBadge && _unreadCount > 0)
                    _buildUnreadBadge(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnreadBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: 16,
        height: 16,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: widget.badgeColor ?? _defaultBadgeColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Center(
          child: Text(
            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  AlignmentGeometry _getChatAlignment() {
    // Position chat relative to button position
    if (widget.alignment == Alignment.bottomRight) {
      return Alignment.bottomRight;
    } else if (widget.alignment == Alignment.bottomLeft) {
      return Alignment.bottomLeft;
    } else if (widget.alignment == Alignment.topRight) {
      return Alignment.topRight;
    } else if (widget.alignment == Alignment.topLeft) {
      return Alignment.topLeft;
    } else {
      return Alignment.center;
    }
  }


  @override
  void dispose() {
    _pulseController.dispose();
    _expandController.dispose();
    super.dispose();
  }
}

/// Integrated chat container for embedding directly in room layouts
/// 
/// An alternative to the floating button that embeds the chat directly
/// into the room's layout structure.
class EmbeddedChatContainer extends StatefulWidget {
  final String chatRoomId;
  final ChatRoomType roomType;
  final UserProfile currentUser;
  final String? userRole;
  final double? height;
  final double? width;
  final bool showHeader;
  final bool autoFocus;

  const EmbeddedChatContainer({
    super.key,
    required this.chatRoomId,
    required this.roomType,
    required this.currentUser,
    this.userRole,
    this.height,
    this.width,
    this.showHeader = true,
    this.autoFocus = false,
  });

  @override
  State<EmbeddedChatContainer> createState() => _EmbeddedChatContainerState();
}

class _EmbeddedChatContainerState extends State<EmbeddedChatContainer> {
  bool _isExpanded = true;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showHeader) _buildToggleHeader(),
        if (_isExpanded)
          SizedBox(
            height: widget.height ?? 300,
            width: widget.width,
            child: LiveChatWidget(
              chatRoomId: widget.chatRoomId,
              roomType: widget.roomType,
              currentUser: widget.currentUser,
              userRole: widget.userRole,
              isVisible: _isExpanded,
            ),
          ),
      ],
    );
  }

  Widget _buildToggleHeader() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Chat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}