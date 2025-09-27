import 'package:flutter/material.dart';
import '../services/livekit_service.dart';

/// Debug widget to display LiveKit track management statistics
/// Useful for monitoring track leaks and memory usage
class DebugTrackStatsWidget extends StatefulWidget {
  const DebugTrackStatsWidget({super.key});

  @override
  State<DebugTrackStatsWidget> createState() => _DebugTrackStatsWidgetState();
}

class _DebugTrackStatsWidgetState extends State<DebugTrackStatsWidget> {
  final LiveKitService _liveKit = LiveKitService();
  Map<String, dynamic> _roomStats = {};
  Map<String, dynamic> _globalStats = {};
  List<String> _leakedTracks = [];

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _roomStats = _liveKit.getTrackStats();
      _globalStats = _liveKit.getGlobalTrackStats();
      _leakedTracks = _liveKit.detectTrackLeaks();
    });
  }

  Future<void> _cleanupLeaks() async {
    await _liveKit.cleanupLeakedTracks();
    _refreshStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧹 Cleaned up leaked tracks'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎬 LiveKit Track Stats',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshStats,
                      tooltip: 'Refresh stats',
                    ),
                    if (_leakedTracks.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.cleaning_services, color: Colors.orange),
                        onPressed: _cleanupLeaks,
                        tooltip: 'Cleanup leaked tracks',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current room stats
            if (_roomStats.isNotEmpty) ...[
              const Text('Current Room:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildStatsGrid(_roomStats),
              const SizedBox(height: 16),
            ],

            // Global stats
            const Text('Global Stats:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildStatsGrid(_globalStats),

            // Track leaks warning
            if (_leakedTracks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          '${_leakedTracks.length} Potential Track Leaks',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These tracks have been active for over 1 hour. Consider cleaning them up.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    if (stats.isEmpty) {
      return const Text(
        'No data available',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final entry = stats.entries.elementAt(index);
        return _buildStatItem(entry.key, entry.value);
      },
    );
  }

  Widget _buildStatItem(String key, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatStatKey(key),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatStatValue(value),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatStatKey(String key) {
    // Convert camelCase to readable format
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ')
        .trim();
  }

  String _formatStatValue(dynamic value) {
    if (value is double) {
      return value.toStringAsFixed(1);
    } else if (value is int) {
      return value.toString();
    } else if (value is String) {
      return value;
    } else {
      return value.toString();
    }
  }
}