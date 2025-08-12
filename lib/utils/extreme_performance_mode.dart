import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// Extreme performance mode that bypasses complex widgets entirely
class ExtremePerformanceMode {
  static ExtremePerformanceMode? _instance;
  static ExtremePerformanceMode get instance => _instance ??= ExtremePerformanceMode._();
  
  ExtremePerformanceMode._();
  
  bool _isEnabled = false;
  
  void enable() {
    if (_isEnabled) return;
    _isEnabled = true;
    AppLogger().info('🚀🚀 EXTREME performance mode enabled');
  }
  
  void disable() {
    _isEnabled = false;
  }
  
  /// Create the most minimal participant widget possible
  Widget createMinimalParticipant({
    required String userId,
    required String name,
    required String avatarUrl,
    VoidCallback? onTap,
  }) {
    if (!_isEnabled) {
      return _StandardParticipant(
        userId: userId,
        name: name,
        avatarUrl: avatarUrl,
        onTap: onTap,
      );
    }
    
    return _ExtremelyFastParticipant(
      key: ValueKey(userId),
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
      onTap: onTap,
    );
  }
  
  /// Create the most minimal grid possible
  Widget createMinimalGrid({
    required List<Map<String, dynamic>> participants,
    Function(String userId)? onParticipantTap,
    required BuildContext context,
  }) {
    if (!_isEnabled || participants.isEmpty) {
      return _StandardGrid(participants: participants, onParticipantTap: onParticipantTap);
    }
    
    return _ExtremelyFastGrid(
      participants: participants,
      onParticipantTap: onParticipantTap,
    );
  }
}

class _ExtremelyFastParticipant extends StatelessWidget {
  final String userId;
  final String name;
  final String avatarUrl;
  final VoidCallback? onTap;
  
  const _ExtremelyFastParticipant({
    super.key,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    // Single container with minimal styling
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        color: const Color(0xFFFFFFFF), // Direct color, no calculations
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minimal avatar - just a colored circle
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF9E9E9E),
                shape: BoxShape.circle,
              ),
              child: avatarUrl.isNotEmpty 
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.none, // Fastest possible
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                  )
                : const Icon(Icons.person, size: 16, color: Colors.white),
            ),
            // Minimal text - no formatting, no overflow handling
            Text(
              name.length > 8 ? name.substring(0, 8) : name,
              style: const TextStyle(fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtremelyFastGrid extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final Function(String userId)? onParticipantTap;
  
  const _ExtremelyFastGrid({
    required this.participants,
    this.onParticipantTap,
  });
  
  @override
  Widget build(BuildContext context) {
    // Use the simplest possible layout - wrap
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: participants.map((participant) {
          final userId = participant['userId'] ?? '';
          return SizedBox(
            width: 70, // Fixed width for consistency
            height: 60, // Fixed height
            child: _ExtremelyFastParticipant(
              key: ValueKey(userId),
              userId: userId,
              name: participant['name'] ?? 'User',
              avatarUrl: participant['avatarUrl'] ?? '',
              onTap: onParticipantTap != null ? () => onParticipantTap!(userId) : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Fallback standard implementations
class _StandardParticipant extends StatelessWidget {
  final String userId;
  final String name;
  final String avatarUrl;
  final VoidCallback? onTap;
  
  const _StandardParticipant({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            const SizedBox(height: 4),
            Text(
              name.length > 12 ? '${name.substring(0, 12)}...' : name,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StandardGrid extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final Function(String userId)? onParticipantTap;
  
  const _StandardGrid({
    required this.participants,
    this.onParticipantTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final userId = participant['userId'] ?? '';
        return _StandardParticipant(
          userId: userId,
          name: participant['name'] ?? 'User',
          avatarUrl: participant['avatarUrl'] ?? '',
          onTap: onParticipantTap != null ? () => onParticipantTap!(userId) : null,
        );
      },
    );
  }
}