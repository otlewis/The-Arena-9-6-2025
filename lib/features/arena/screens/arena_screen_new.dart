import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/arena_header.dart';
import '../widgets/arena_timer_with_controls.dart';
import '../widgets/participants_list.dart';
import '../providers/arena_provider.dart';

class ArenaScreenNew extends ConsumerStatefulWidget {
  const ArenaScreenNew({
    super.key,
    required this.roomId,
    required this.challengeId,
    required this.topic,
    this.description,
    this.category,
    this.challengerId,
    this.challengedId,
  });

  final String roomId;
  final String challengeId;
  final String topic;
  final String? description;
  final String? category;
  final String? challengerId;
  final String? challengedId;

  @override
  ConsumerState<ArenaScreenNew> createState() => _ArenaScreenNewState();
}

class _ArenaScreenNewState extends ConsumerState<ArenaScreenNew> {
  @override
  void initState() {
    super.initState();
    // Initialize arena data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The arena provider will automatically initialize when first accessed
    });
  }

  @override
  Widget build(BuildContext context) {
    final arenaState = ref.watch(arenaProvider(widget.roomId));
    
    return Scaffold(
      body: arenaState.isLoading
        ? const _LoadingView()
        : arenaState.error != null
          ? _ErrorView(
              error: arenaState.error!,
              onRetry: () => ref.invalidate(arenaProvider(widget.roomId)),
            )
          : Column(
              children: [
                ArenaHeader(roomId: widget.roomId),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ArenaTimerWithControls(roomId: widget.roomId),
                        const Divider(),
                        ParticipantsList(roomId: widget.roomId),
                        const Divider(),
                        _buildControls(context, arenaState),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildControls(BuildContext context, arenaState) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Arena Controls',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildControlButton(
                context,
                'Ready',
                Icons.check_circle,
                Colors.green,
                () => _handleReady(),
              ),
              _buildControlButton(
                context,
                'Speak',
                Icons.mic,
                Colors.blue,
                () => _handleSpeak(),
              ),
              _buildControlButton(
                context,
                'Mute',
                Icons.mic_off,
                Colors.orange,
                () => _handleMute(),
              ),
              _buildControlButton(
                context,
                'Leave',
                Icons.exit_to_app,
                Colors.red,
                () => _handleLeave(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  void _handleReady() {
    // TODO: Implement ready functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ready status updated')),
    );
  }

  void _handleSpeak() {
    // TODO: Implement speak functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Speaking controls activated')),
    );
  }

  void _handleMute() {
    // TODO: Implement mute functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone toggled')),
    );
  }

  void _handleLeave() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Arena'),
        content: const Text('Are you sure you want to leave this arena?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading Arena...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Arena',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}