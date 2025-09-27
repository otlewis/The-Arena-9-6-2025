import 'package:flutter/material.dart';
import '../services/client_role_manager.dart';
import '../services/role_authority_service.dart';
import '../core/logging/app_logger.dart';

/// Demo widget showcasing the new role authority system
/// This widget demonstrates how the system prevents state sync issues
class RoleAuthorityDemoWidget extends StatefulWidget {
  final String roomId;
  final String currentUserId;

  const RoleAuthorityDemoWidget({
    super.key,
    required this.roomId,
    required this.currentUserId,
  });

  @override
  State<RoleAuthorityDemoWidget> createState() => _RoleAuthorityDemoWidgetState();
}

class _RoleAuthorityDemoWidgetState extends State<RoleAuthorityDemoWidget> {
  final ClientRoleManager _roleManager = ClientRoleManager();
  final AppLogger _logger = AppLogger();

  Map<String, ParticipantRole> _roster = {};
  List<RoleChangeEvent> _recentEvents = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeRoleManager();
  }

  Future<void> _initializeRoleManager() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Initialize the role manager
      await _roleManager.initialize(widget.currentUserId);
      await _roleManager.joinRoom(widget.roomId);

      // Listen to roster updates
      _roleManager.rosterStream.listen((roster) {
        if (mounted) {
          setState(() {
            _roster = roster;
          });
        }
      });

      // Listen to role change events
      _roleManager.roleChangeStream.listen((event) {
        if (mounted) {
          setState(() {
            _recentEvents.insert(0, event);
            // Keep only last 10 events
            if (_recentEvents.length > 10) {
              _recentEvents.removeLast();
            }
          });
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _logger.error('Failed to initialize role manager: $e');
    }
  }

  @override
  void dispose() {
    _roleManager.leaveRoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Authority System Demo'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildMainView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error: $_errorMessage',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeRoleManager,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentUserCard(),
          const SizedBox(height: 20),
          _buildRosterSection(),
          const SizedBox(height: 20),
          _buildActionsSection(),
          const SizedBox(height: 20),
          _buildRecentEventsSection(),
          const SizedBox(height: 20),
          _buildSystemStatusSection(),
        ],
      ),
    );
  }

  Widget _buildCurrentUserCard() {
    final myRole = _roleManager.getCurrentUserRole();
    final roleColor = Color(int.parse(_roleManager.getRoleColor(myRole).substring(1), radix: 16) + 0xFF000000);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Current Role',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: roleColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _roleManager.getRoleDisplayName(myRole),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'User ID: ${widget.currentUserId}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Room Roster (Backend Authority)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_roster.length} participants',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_roster.isEmpty)
              const Text('No participants found')
            else
              _buildRoleGroups(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleGroups() {
    final moderators = _roleManager.getParticipantsByRole(ParticipantRole.moderator);
    final speakers = _roleManager.getParticipantsByRole(ParticipantRole.speaker);
    final pending = _roleManager.getParticipantsByRole(ParticipantRole.pending);
    final audience = _roleManager.getParticipantsByRole(ParticipantRole.audience);

    return Column(
      children: [
        if (moderators.isNotEmpty) _buildRoleGroup('Moderators', moderators, ParticipantRole.moderator),
        if (speakers.isNotEmpty) _buildRoleGroup('Speakers', speakers, ParticipantRole.speaker),
        if (pending.isNotEmpty) _buildRoleGroup('Pending Speakers', pending, ParticipantRole.pending),
        if (audience.isNotEmpty) _buildRoleGroup('Audience', audience, ParticipantRole.audience),
      ],
    );
  }

  Widget _buildRoleGroup(String title, List<String> participants, ParticipantRole role) {
    final roleColor = Color(int.parse(_roleManager.getRoleColor(role).substring(1), radix: 16) + 0xFF000000);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${participants.length})',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: roleColor,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: participants.map((userId) => _buildParticipantChip(userId, role)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(String userId, ParticipantRole role) {
    final roleColor = Color(int.parse(_roleManager.getRoleColor(role).substring(1), radix: 16) + 0xFF000000);
    final isCurrentUser = userId == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Chip(
        label: Text(
          userId == widget.currentUserId ? '$userId (You)' : userId,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: roleColor,
        side: isCurrentUser ? const BorderSide(color: Colors.white, width: 2) : null,
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildUserActions(),
            if (_roleManager.canModerate) ...[
              const SizedBox(height: 16),
              _buildModeratorActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Actions:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (_roleManager.isAudience)
              ElevatedButton.icon(
                onPressed: _requestToSpeak,
                icon: const Icon(Icons.pan_tool),
                label: const Text('Raise Hand'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            if (_roleManager.hasPendingSpeakerRequest)
              ElevatedButton.icon(
                onPressed: _cancelSpeakerRequest,
                icon: const Icon(Icons.cancel),
                label: const Text('Lower Hand'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeratorActions() {
    final pendingUsers = _roleManager.getParticipantsByRole(ParticipantRole.pending);
    final speakers = _roleManager.getParticipantsByRole(ParticipantRole.speaker);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Moderator Actions:',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
        ),
        const SizedBox(height: 8),
        if (pendingUsers.isNotEmpty) ...[
          const Text('Approve Speakers:', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 4,
            children: pendingUsers.map((userId) =>
              ElevatedButton(
                onPressed: () => _promoteToSpeaker(userId),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Approve $userId'),
              ),
            ).toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (speakers.isNotEmpty) ...[
          const Text('Demote Speakers:', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 4,
            children: speakers.map((userId) =>
              ElevatedButton(
                onPressed: () => _demoteToAudience(userId),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Demote $userId'),
              ),
            ).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentEventsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Role Changes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_recentEvents.isEmpty)
              const Text('No recent role changes')
            else
              Column(
                children: _recentEvents.map(_buildEventTile).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(RoleChangeEvent event) {
    final oldColor = Color(int.parse(_roleManager.getRoleColor(event.oldRole).substring(1), radix: 16) + 0xFF000000);
    final newColor = Color(int.parse(_roleManager.getRoleColor(event.newRole).substring(1), radix: 16) + 0xFF000000);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.userId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: oldColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _roleManager.getRoleDisplayName(event.oldRole),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: newColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _roleManager.getRoleDisplayName(event.newRole),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Backend Authority', 'Active', Colors.green),
            _buildStatusRow('Real-time Events', 'Connected', Colors.green),
            _buildStatusRow('Heartbeat', 'Sending', Colors.green),
            _buildStatusRow('Event Idempotency', 'Enabled', Colors.green),
            const SizedBox(height: 12),
            const Text(
              '✅ This system prevents role state inconsistencies across clients',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Action handlers

  Future<void> _requestToSpeak() async {
    try {
      await _roleManager.requestToSpeak();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speaker request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request speaker role: $e')),
        );
      }
    }
  }

  Future<void> _cancelSpeakerRequest() async {
    try {
      await _roleManager.cancelSpeakerRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speaker request cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e')),
        );
      }
    }
  }

  Future<void> _promoteToSpeaker(String userId) async {
    try {
      await _roleManager.promoteToSpeaker(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$userId promoted to speaker')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to promote $userId: $e')),
        );
      }
    }
  }

  Future<void> _demoteToAudience(String userId) async {
    try {
      await _roleManager.demoteToAudience(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$userId demoted to audience')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to demote $userId: $e')),
        );
      }
    }
  }
}