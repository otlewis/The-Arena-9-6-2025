import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/role_authority_service.dart';
import '../services/client_role_manager.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Admin dashboard for monitoring and debugging the role authority system
/// Shows real-time state, events, and system health
class RoleAuthorityAdminDashboard extends ConsumerStatefulWidget {
  const RoleAuthorityAdminDashboard({super.key});

  @override
  ConsumerState<RoleAuthorityAdminDashboard> createState() => _RoleAuthorityAdminDashboardState();
}

class _RoleAuthorityAdminDashboardState extends ConsumerState<RoleAuthorityAdminDashboard> {
  final AppLogger _logger = AppLogger();
  final RoleAuthorityService _authorityService = RoleAuthorityService();
  final AppwriteService _appwriteService = AppwriteService();

  // Dashboard state
  List<RoomInfo> _activeRooms = [];
  List<RoleChangeEvent> _recentEvents = [];
  Map<String, SystemMetrics> _systemMetrics = {};
  Timer? _refreshTimer;
  bool _isLoading = true;
  String? _selectedRoomId;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _loadActiveRooms();
      await _loadRecentEvents();
      await _loadSystemMetrics();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.error('Failed to initialize admin dashboard: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    try {
      await _loadActiveRooms();
      await _loadRecentEvents();
      await _loadSystemMetrics();
    } catch (e) {
      _logger.debug('Refresh failed: $e');
    }
  }

  Future<void> _loadActiveRooms() async {
    try {
      // Load all active rooms from debates_discussions and arena_rooms
      final debateRooms = await _appwriteService.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: 'debate_discussion_rooms',
        queries: [
          // Query.equal('status', 'active'),
        ],
      );

      final arenaRooms = await _appwriteService.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: 'arena_rooms',
        queries: [
          // Query.equal('status', 'active'),
        ],
      );

      final rooms = <RoomInfo>[];

      // Process debate rooms
      for (final room in debateRooms.documents) {
        final participants = await _loadRoomParticipants(room.$id, 'debate_discussion_participants');
        rooms.add(RoomInfo(
          id: room.$id,
          title: room.data['title'] ?? 'Untitled Room',
          type: 'Debate & Discussion',
          status: room.data['status'] ?? 'unknown',
          participantCount: participants.length,
          participants: participants,
          createdAt: DateTime.parse(room.$createdAt),
        ));
      }

      // Process arena rooms
      for (final room in arenaRooms.documents) {
        final participants = await _loadRoomParticipants(room.$id, 'arena_participants');
        rooms.add(RoomInfo(
          id: room.$id,
          title: room.data['title'] ?? 'Untitled Arena',
          type: 'Arena',
          status: room.data['status'] ?? 'unknown',
          participantCount: participants.length,
          participants: participants,
          createdAt: DateTime.parse(room.$createdAt),
        ));
      }

      if (mounted) {
        setState(() {
          _activeRooms = rooms;
        });
      }
    } catch (e) {
      _logger.error('Failed to load active rooms: $e');
    }
  }

  Future<List<ParticipantInfo>> _loadRoomParticipants(String roomId, String collectionId) async {
    try {
      final participants = await _appwriteService.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: collectionId,
        queries: [
          // Query.equal('roomId', roomId),
          // Query.equal('status', 'active'),
        ],
      );

      return participants.documents.map((doc) => ParticipantInfo(
        userId: doc.data['userId'] ?? '',
        role: doc.data['role'] ?? 'audience',
        isConnected: doc.data['isConnected'] ?? false,
        lastHeartbeat: doc.data['lastHeartbeat'] != null
            ? DateTime.parse(doc.data['lastHeartbeat'])
            : DateTime.now(),
        joinedAt: DateTime.parse(doc.$createdAt),
      )).toList();
    } catch (e) {
      _logger.error('Failed to load participants for room $roomId: $e');
      return [];
    }
  }

  Future<void> _loadRecentEvents() async {
    try {
      final events = await _appwriteService.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: 'role_change_events',
        queries: [
          // Query.orderDesc('timestamp'),
          // Query.limit(50),
        ],
      );

      final recentEvents = events.documents.map((doc) => RoleChangeEvent(
        roomId: doc.data['roomId'] ?? '',
        userId: doc.data['userId'] ?? '',
        oldRole: _parseRole(doc.data['oldRole'] ?? 'audience'),
        newRole: _parseRole(doc.data['newRole'] ?? 'audience'),
        eventId: doc.data['eventId'] ?? '',
        timestamp: DateTime.parse(doc.data['timestamp'] ?? DateTime.now().toIso8601String()),
      )).toList();

      if (mounted) {
        setState(() {
          _recentEvents = recentEvents;
        });
      }
    } catch (e) {
      _logger.error('Failed to load recent events: $e');
    }
  }

  Future<void> _loadSystemMetrics() async {
    try {
      final metrics = <String, SystemMetrics>{};

      for (final room in _activeRooms) {
        final roomMetrics = await _calculateRoomMetrics(room);
        metrics[room.id] = roomMetrics;
      }

      if (mounted) {
        setState(() {
          _systemMetrics = metrics;
        });
      }
    } catch (e) {
      _logger.error('Failed to load system metrics: $e');
    }
  }

  Future<SystemMetrics> _calculateRoomMetrics(RoomInfo room) async {
    final now = DateTime.now();
    final staleThreshold = Duration(minutes: 2);

    int connectedParticipants = 0;
    int staleParticipants = 0;
    Map<String, int> roleDistribution = {
      'moderator': 0,
      'speaker': 0,
      'pending': 0,
      'audience': 0,
    };

    for (final participant in room.participants) {
      if (participant.isConnected) {
        connectedParticipants++;
      }

      if (now.difference(participant.lastHeartbeat) > staleThreshold) {
        staleParticipants++;
      }

      roleDistribution[participant.role] = (roleDistribution[participant.role] ?? 0) + 1;
    }

    return SystemMetrics(
      totalParticipants: room.participants.length,
      connectedParticipants: connectedParticipants,
      staleParticipants: staleParticipants,
      roleDistribution: roleDistribution,
      lastUpdated: now,
    );
  }

  ParticipantRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'moderator':
        return ParticipantRole.moderator;
      case 'speaker':
        return ParticipantRole.speaker;
      case 'pending':
        return ParticipantRole.pending;
      case 'audience':
      default:
        return ParticipantRole.audience;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Authority Admin Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          Switch(
            value: _refreshTimer?.isActive ?? false,
            onChanged: (value) {
              if (value) {
                _startPeriodicRefresh();
              } else {
                _refreshTimer?.cancel();
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left sidebar - Room list
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: _buildRoomList(),
                ),
                // Main content area
                Expanded(
                  child: _selectedRoomId != null
                      ? _buildRoomDetails()
                      : _buildOverview(),
                ),
              ],
            ),
    );
  }

  Widget _buildRoomList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.meeting_room),
              const SizedBox(width: 8),
              Text(
                'Active Rooms (${_activeRooms.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _activeRooms.length,
            itemBuilder: (context, index) {
              final room = _activeRooms[index];
              final isSelected = room.id == _selectedRoomId;
              final metrics = _systemMetrics[room.id];

              return ListTile(
                title: Text(
                  room.title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${room.type} • ${room.participantCount} participants'),
                    if (metrics != null)
                      Text(
                        '${metrics.connectedParticipants} connected • ${metrics.staleParticipants} stale',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                trailing: _buildRoomStatusIndicator(room, metrics),
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedRoomId = room.id;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoomStatusIndicator(RoomInfo room, SystemMetrics? metrics) {
    if (metrics == null) {
      return const CircularProgressIndicator(strokeWidth: 2);
    }

    Color statusColor = Colors.green;
    if (metrics.staleParticipants > 0) {
      statusColor = Colors.orange;
    }
    if (metrics.connectedParticipants == 0) {
      statusColor = Colors.red;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSystemOverview(),
          const SizedBox(height: 20),
          _buildRecentEventsTable(),
        ],
      ),
    );
  }

  Widget _buildSystemOverview() {
    final totalParticipants = _activeRooms.fold(0, (sum, room) => sum + room.participantCount);
    final totalConnected = _systemMetrics.values.fold(0, (sum, metrics) => sum + metrics.connectedParticipants);
    final totalStale = _systemMetrics.values.fold(0, (sum, metrics) => sum + metrics.staleParticipants);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard('Active Rooms', _activeRooms.length.toString(), Colors.blue),
                _buildMetricCard('Total Participants', totalParticipants.toString(), Colors.green),
                _buildMetricCard('Connected', totalConnected.toString(), Colors.teal),
                _buildMetricCard('Stale Connections', totalStale.toString(), Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEventsTable() {
    return Card(
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
              const Text('No recent events')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Room')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('From')),
                    DataColumn(label: Text('To')),
                    DataColumn(label: Text('Event ID')),
                  ],
                  rows: _recentEvents.take(20).map((event) {
                    final room = _activeRooms.firstWhere(
                      (r) => r.id == event.roomId,
                      orElse: () => RoomInfo(
                        id: event.roomId,
                        title: 'Unknown Room',
                        type: 'Unknown',
                        status: 'unknown',
                        participantCount: 0,
                        participants: [],
                        createdAt: DateTime.now(),
                      ),
                    );

                    return DataRow(cells: [
                      DataCell(Text('${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}')),
                      DataCell(Text(room.title)),
                      DataCell(Text(event.userId)),
                      DataCell(_buildRoleChip(event.oldRole)),
                      DataCell(_buildRoleChip(event.newRole)),
                      DataCell(Text(event.eventId.split('_').last)),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomDetails() {
    final room = _activeRooms.firstWhere((r) => r.id == _selectedRoomId);
    final metrics = _systemMetrics[room.id];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoomHeader(room, metrics),
          const SizedBox(height: 20),
          _buildParticipantsTable(room),
          const SizedBox(height: 20),
          _buildRoomEvents(room),
        ],
      ),
    );
  }

  Widget _buildRoomHeader(RoomInfo room, SystemMetrics? metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  room.type == 'Arena' ? Icons.sports_kabaddi : Icons.forum,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${room.type} • Status: ${room.status}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (metrics != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildMetricCard('Total', metrics.totalParticipants.toString(), Colors.blue),
                  _buildMetricCard('Connected', metrics.connectedParticipants.toString(), Colors.green),
                  _buildMetricCard('Stale', metrics.staleParticipants.toString(), Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Role Distribution:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: metrics.roleDistribution.entries.map((entry) =>
                  Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    backgroundColor: _getRoleColor(entry.key).withValues(alpha: 0.2),
                  ),
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsTable(RoomInfo room) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('User ID')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Last Heartbeat')),
                  DataColumn(label: Text('Joined')),
                ],
                rows: room.participants.map((participant) {
                  final isStale = DateTime.now().difference(participant.lastHeartbeat) > Duration(minutes: 2);

                  return DataRow(
                    color: isStale ? WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)) : null,
                    cells: [
                      DataCell(Text(participant.userId)),
                      DataCell(_buildRoleChip(_parseRole(participant.role))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            participant.isConnected ? Icons.circle : Icons.circle_outlined,
                            color: participant.isConnected ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(participant.isConnected ? 'Connected' : 'Disconnected'),
                        ],
                      )),
                      DataCell(Text(_formatDuration(DateTime.now().difference(participant.lastHeartbeat)))),
                      DataCell(Text(_formatDuration(DateTime.now().difference(participant.joinedAt)))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomEvents(RoomInfo room) {
    final roomEvents = _recentEvents.where((e) => e.roomId == room.id).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Events in This Room',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (roomEvents.isEmpty)
              const Text('No recent events in this room')
            else
              Column(
                children: roomEvents.take(10).map((event) =>
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRoleColor(event.newRole.toString().split('.').last),
                      child: Text(
                        event.userId.substring(0, 2).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('${event.userId} role changed'),
                    subtitle: Row(
                      children: [
                        _buildRoleChip(event.oldRole),
                        const Icon(Icons.arrow_forward, size: 16),
                        _buildRoleChip(event.newRole),
                      ],
                    ),
                    trailing: Text(
                      _formatDuration(DateTime.now().difference(event.timestamp)),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(ParticipantRole role) {
    final roleString = role.toString().split('.').last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getRoleColor(roleString),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        roleString,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'moderator':
        return Colors.red;
      case 'speaker':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'audience':
      default:
        return Colors.blue;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return '${duration.inSeconds}s ago';
    }
  }
}

// Data models for the dashboard

class RoomInfo {
  final String id;
  final String title;
  final String type;
  final String status;
  final int participantCount;
  final List<ParticipantInfo> participants;
  final DateTime createdAt;

  RoomInfo({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.participantCount,
    required this.participants,
    required this.createdAt,
  });
}

class ParticipantInfo {
  final String userId;
  final String role;
  final bool isConnected;
  final DateTime lastHeartbeat;
  final DateTime joinedAt;

  ParticipantInfo({
    required this.userId,
    required this.role,
    required this.isConnected,
    required this.lastHeartbeat,
    required this.joinedAt,
  });
}

class SystemMetrics {
  final int totalParticipants;
  final int connectedParticipants;
  final int staleParticipants;
  final Map<String, int> roleDistribution;
  final DateTime lastUpdated;

  SystemMetrics({
    required this.totalParticipants,
    required this.connectedParticipants,
    required this.staleParticipants,
    required this.roleDistribution,
    required this.lastUpdated,
  });
}