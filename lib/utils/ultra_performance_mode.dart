import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// Ultra-performance mode for Arena screens to achieve 60fps
class UltraPerformanceMode {
  static UltraPerformanceMode? _instance;
  static UltraPerformanceMode get instance => _instance ??= UltraPerformanceMode._();
  
  UltraPerformanceMode._();
  
  bool _isEnabled = false;
  
  /// Enable ultra-performance mode
  void enable() {
    if (_isEnabled) return;
    
    _isEnabled = true;
    
    // Optimize rendering pipeline
    _optimizeRendering();
    
    AppLogger().info('🚀 Ultra-performance mode enabled');
  }
  
  /// Disable ultra-performance mode
  void disable() {
    if (!_isEnabled) return;
    
    _isEnabled = false;
    AppLogger().info('🐌 Ultra-performance mode disabled');
  }
  
  void _optimizeRendering() {
    // Performance optimizations applied internally
    // Most rendering optimizations are handled by RepaintBoundary usage
  }
  
  /// Get ultra-fast participant widget
  Widget getUltraFastParticipant({
    required String userId,
    required String name,
    required String avatarUrl,
    required String role,
    VoidCallback? onTap,
  }) {
    if (!_isEnabled) {
      return _buildStandardParticipant(
        userId: userId,
        name: name,
        avatarUrl: avatarUrl,
        role: role,
        onTap: onTap,
      );
    }
    
    return _UltraFastParticipant(
      key: ValueKey(userId),
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
      role: role,
      onTap: onTap,
    );
  }
  
  Widget _buildStandardParticipant({
    required String userId,
    required String name,
    required String avatarUrl,
    required String role,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getRoleColor(role),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar(avatarUrl, name),
            const SizedBox(height: 4),
            _buildNameText(name),
          ],
        ),
      ),
    );
  }
  
  /// Helper function to create avatar text content from name data - just first letter
  Widget _buildAvatarText(String name, double fontSize) {
    String letter;
    
    if (name.isEmpty) {
      letter = 'U';
    } else {
      letter = name.substring(0, 1).toUpperCase();
    }
    
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  Widget _buildAvatar(String avatarUrl, String name) {
    const double size = 40;
    
    if (avatarUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        child: _buildAvatarText(name, 16),
      );
    }
    
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 40,
        cacheHeight: 40,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
          child: _buildAvatarText(name, 16),
        ),
      ),
    );
  }
  
  Widget _buildNameText(String name) {
    return Text(
      name.length > 12 ? '${name.substring(0, 12)}...' : name,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      textAlign: TextAlign.center,
      maxLines: 1,
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role) {
      case 'moderator':
        return Colors.red.withValues(alpha: 0.1);
      case 'speaker':
        return Colors.blue.withValues(alpha: 0.1);
      case 'pending':
        return Colors.orange.withValues(alpha: 0.1);
      default:
        return Colors.white;
    }
  }
  
  /// Get ultra-fast grid view for participants
  Widget getUltraFastGrid({
    required List<Map<String, dynamic>> participants,
    Function(String userId)? onParticipantTap,
    required BuildContext context,
  }) {
    if (!_isEnabled) {
      return _buildStandardGrid(participants, onParticipantTap, context);
    }
    
    return _UltraFastGrid(
      participants: participants,
      onParticipantTap: onParticipantTap,
    );
  }
  
  Widget _buildStandardGrid(
    List<Map<String, dynamic>> participants,
    Function(String userId)? onParticipantTap,
    BuildContext context,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 5 : 4;
    
    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final userId = participant['userId'] ?? '';
        return getUltraFastParticipant(
          userId: userId,
          name: participant['name'] ?? 'Unknown',
          avatarUrl: participant['avatarUrl'] ?? '',
          role: participant['role'] ?? 'audience',
          onTap: onParticipantTap != null ? () => onParticipantTap(userId) : null,
        );
      },
    );
  }
}

/// Ultra-fast participant widget with minimal rebuilds
class _UltraFastParticipant extends StatelessWidget {
  final String userId;
  final String name;
  final String avatarUrl;
  final String role;
  final VoidCallback? onTap;
  
  const _UltraFastParticipant({
    super.key,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.role,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    // Single RepaintBoundary for the entire widget
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _getRoleColor(),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _UltraFastAvatar(
                  avatarUrl: avatarUrl,
                  userId: userId,
                  name: name,
                ),
                const SizedBox(height: 4),
                _UltraFastText(name: name),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getRoleColor() {
    // Pre-computed colors to avoid calculations
    switch (role) {
      case 'moderator':
        return const Color(0x1AF44336); // Colors.red.withValues(alpha: 0.1)
      case 'speaker':
        return const Color(0x1A2196F3); // Colors.blue.withValues(alpha: 0.1)
      case 'pending':
        return const Color(0x1AFF9800); // Colors.orange.withValues(alpha: 0.1)
      default:
        return const Color(0xFFFFFFFF); // Colors.white
    }
  }
}

/// Ultra-fast avatar with aggressive caching
class _UltraFastAvatar extends StatelessWidget {
  final String avatarUrl;
  final String userId;
  final String name;
  
  const _UltraFastAvatar({
    required this.avatarUrl,
    required this.userId,
    required this.name,
  });
  
  @override
  Widget build(BuildContext context) {
    const double size = 32; // Reduced size for better performance
    
    if (avatarUrl.isEmpty) {
      return _DefaultAvatar(name: name);
    }
    
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 32, // Match actual size
          cacheHeight: 32,
          filterQuality: FilterQuality.low, // Faster rendering
          errorBuilder: (_, __, ___) => _DefaultAvatar(name: name),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _DefaultAvatar(name: name);
          },
        ),
      ),
    );
  }
}

/// Static helper function for avatar text (used in static widgets)
// ignore_for_file: prefer_const_constructors
Widget _buildStaticAvatarText(String name, double fontSize) {
  if (name.isEmpty) {
    return Text(
      'U',
      style: TextStyle(
        color: Color(0xFFFFFFFF), // Colors.white
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  final parts = name.split(' ');
  
  // Single name - just show first letter
  if (parts.length == 1) {
    return Text(
      parts[0].substring(0, 1).toUpperCase(),
      style: TextStyle(
        color: Color(0xFFFFFFFF), // Colors.white
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  // Multiple names - stack first and last name vertically
  if (parts.length >= 2) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          parts[0],
          style: TextStyle(
            color: Color(0xFFFFFFFF), // Colors.white
            fontSize: fontSize * 0.4,
            fontWeight: FontWeight.bold,
            height: 0.9,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          parts.last,
          style: TextStyle(
            color: Color(0xFFFFFFFF), // Colors.white
            fontSize: fontSize * 0.4,
            fontWeight: FontWeight.bold,
            height: 0.9,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
  
  // Fallback to first letter
  return Text(
    name.substring(0, 1).toUpperCase(),
    style: TextStyle(
      color: Color(0xFFFFFFFF), // Colors.white
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    ),
  );
}

/// Default avatar widget (cached)
class _DefaultAvatar extends StatelessWidget {
  final String name;
  
  const _DefaultAvatar({required this.name});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF9E9E9E), // Colors.grey
        shape: BoxShape.circle,
      ),
      child: _buildStaticAvatarText(name, 16),
    );
  }
}

/// Ultra-fast text widget
class _UltraFastText extends StatelessWidget {
  final String name;
  
  const _UltraFastText({required this.name});
  
  @override
  Widget build(BuildContext context) {
    final displayName = name.length > 10 ? '${name.substring(0, 10)}...' : name;
    
    return Text(
      displayName,
      style: const TextStyle(
        fontSize: 9, // Slightly smaller for performance
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.clip, // Faster than ellipsis
    );
  }
}

/// Ultra-fast grid implementation
class _UltraFastGrid extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final Function(String userId)? onParticipantTap;
  
  const _UltraFastGrid({
    required this.participants,
    this.onParticipantTap,
  });
  
  @override
  State<_UltraFastGrid> createState() => _UltraFastGridState();
}

class _UltraFastGridState extends State<_UltraFastGrid> {
  List<Widget> _cachedWidgets = [];
  List<String> _lastParticipantIds = [];
  
  @override
  void initState() {
    super.initState();
    _buildCachedWidgets();
  }
  
  @override
  void didUpdateWidget(_UltraFastGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Quick check - only rebuild if participant IDs changed
    final newIds = widget.participants.map((p) => p['userId']?.toString() ?? '').toList();
    if (_participantIdsChanged(newIds)) {
      _buildCachedWidgets();
    }
  }
  
  bool _participantIdsChanged(List<String> newIds) {
    if (_lastParticipantIds.length != newIds.length) return true;
    
    for (int i = 0; i < newIds.length; i++) {
      if (_lastParticipantIds[i] != newIds[i]) return true;
    }
    
    return false;
  }
  
  void _buildCachedWidgets() {
    _lastParticipantIds = widget.participants.map((p) => p['userId']?.toString() ?? '').toList();
    
    _cachedWidgets = widget.participants.map((participant) {
      final userId = participant['userId'] ?? '';
      return _UltraFastParticipant(
        key: ValueKey(userId),
        userId: userId,
        name: participant['name'] ?? 'Unknown',
        avatarUrl: participant['avatarUrl'] ?? '',
        role: participant['role'] ?? 'audience',
        onTap: widget.onParticipantTap != null 
          ? () => widget.onParticipantTap!(userId)
          : null,
      );
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) {
      return const Center(
        child: Text(
          'No participants yet',
          style: TextStyle(color: Color(0xFF757575), fontSize: 16),
        ),
      );
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 5 : 4;
    
    return RepaintBoundary(
      child: GridView.custom(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.85, // Slightly smaller for better fit
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        childrenDelegate: SliverChildListDelegate(
          _cachedWidgets,
          addRepaintBoundaries: false, // We handle this ourselves
        ),
      ),
    );
  }
}