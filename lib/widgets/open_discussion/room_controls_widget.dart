import 'package:flutter/material.dart';
import '../../core/logging/app_logger.dart';

/// Focused widget for room controls and actions
/// Handles microphone, hand raise, and room management controls
class RoomControlsWidget extends StatelessWidget {
  final String userRole;
  final bool isMuted;
  final bool isHandRaised;
  final bool isConnected;
  final int handRaiseCount;
  final Function()? onToggleMicrophone;
  final Function()? onToggleHandRaise;
  final Function()? onShowHandRaiseList;
  final Function()? onShowParticipantList;
  final Function()? onShowRoomChat;
  final Function()? onEndRoom;

  const RoomControlsWidget({
    super.key,
    required this.userRole,
    required this.isMuted,
    required this.isHandRaised,
    required this.isConnected,
    required this.handRaiseCount,
    this.onToggleMicrophone,
    this.onToggleHandRaise,
    this.onShowHandRaiseList,
    this.onShowParticipantList,
    this.onShowRoomChat,
    this.onEndRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone control (speakers/moderators only)
          if (userRole == 'speaker' || userRole == 'moderator')
            _buildMicrophoneButton(),
            
          // Hand raise control (audience only)
          if (userRole == 'audience')
            _buildHandRaiseButton(),
            
          // Hand raise notifications (moderators only)
          if (userRole == 'moderator' && handRaiseCount > 0)
            _buildHandRaiseNotificationButton(),
            
          // Participants list
          _buildParticipantsButton(),
          
          // Chat button
          _buildChatButton(),
          
          // Room end button (moderators only)
          if (userRole == 'moderator')
            _buildEndRoomButton(),
        ],
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return _buildControlButton(
      icon: isMuted ? Icons.mic_off : Icons.mic,
      label: isMuted ? 'Unmute' : 'Mute',
      color: isMuted ? Colors.red : Colors.green,
      onTap: () {
        try {
          onToggleMicrophone?.call();
          AppLogger().debug('🎤 Microphone ${isMuted ? 'unmuted' : 'muted'}');
        } catch (e) {
          AppLogger().error('❌ Error toggling microphone: $e');
        }
      },
      enabled: isConnected,
    );
  }

  Widget _buildHandRaiseButton() {
    return _buildControlButton(
      icon: isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
      label: isHandRaised ? 'Lower Hand' : 'Raise Hand',
      color: isHandRaised ? Colors.orange : Colors.grey,
      onTap: () {
        try {
          onToggleHandRaise?.call();
          AppLogger().debug('✋ Hand ${isHandRaised ? 'lowered' : 'raised'}');
        } catch (e) {
          AppLogger().error('❌ Error toggling hand raise: $e');
        }
      },
      enabled: isConnected,
    );
  }

  Widget _buildHandRaiseNotificationButton() {
    return Stack(
      children: [
        _buildControlButton(
          icon: Icons.pan_tool,
          label: 'Requests',
          color: Colors.orange,
          onTap: () {
            try {
              onShowHandRaiseList?.call();
              AppLogger().debug('📋 Showing hand raise list');
            } catch (e) {
              AppLogger().error('❌ Error showing hand raise list: $e');
            }
          },
          enabled: isConnected,
        ),
        
        // Notification badge
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              handRaiseCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsButton() {
    return _buildControlButton(
      icon: Icons.people,
      label: 'Participants',
      color: Colors.blue,
      onTap: () {
        try {
          onShowParticipantList?.call();
          AppLogger().debug('👥 Showing participants list');
        } catch (e) {
          AppLogger().error('❌ Error showing participants list: $e');
        }
      },
      enabled: true,
    );
  }

  Widget _buildChatButton() {
    return _buildControlButton(
      icon: Icons.chat_bubble_outline,
      label: 'Chat',
      color: Colors.purple,
      onTap: () {
        try {
          onShowRoomChat?.call();
          AppLogger().debug('💬 Opening room chat');
        } catch (e) {
          AppLogger().error('❌ Error opening chat: $e');
        }
      },
      enabled: true,
    );
  }

  Widget _buildEndRoomButton() {
    return _buildControlButton(
      icon: Icons.exit_to_app,
      label: 'End Room',
      color: Colors.red,
      onTap: () {
        try {
          _showEndRoomConfirmation();
          AppLogger().debug('🚪 End room requested');
        } catch (e) {
          AppLogger().error('❌ Error ending room: $e');
        }
      },
      enabled: true,
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: enabled ? color : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEndRoomConfirmation() {
    // This would show a confirmation dialog
    // For now, we'll just call the end room function
    onEndRoom?.call();
  }
}

/// Connection status indicator widget
class ConnectionStatusWidget extends StatelessWidget {
  final bool isConnected;
  final String connectionQuality;

  const ConnectionStatusWidget({
    super.key,
    required this.isConnected,
    required this.connectionQuality,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green[900] : Colors.red[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Connected • $connectionQuality' : 'Disconnected',
            style: TextStyle(
              color: isConnected ? Colors.green[200] : Colors.red[200],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}