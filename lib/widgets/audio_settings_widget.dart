import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/enhanced_audio_service.dart';

class AudioSettingsWidget extends StatefulWidget {
  const AudioSettingsWidget({Key? key}) : super(key: key);

  @override
  State<AudioSettingsWidget> createState() => _AudioSettingsWidgetState();
}

class _AudioSettingsWidgetState extends State<AudioSettingsWidget> {
  final EnhancedAudioService _audioService = EnhancedAudioService();

  double _masterVolume = 1.0;
  double _effectsVolume = 1.0;
  double _voiceVolume = 1.0;
  double _notificationVolume = 0.8;
  bool _isMuted = false;
  bool _hapticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final stats = _audioService.getStatistics();
    setState(() {
      _masterVolume = stats['masterVolume'] ?? 1.0;
      _effectsVolume = stats['effectsVolume'] ?? 1.0;
      _voiceVolume = stats['voiceVolume'] ?? 1.0;
      _notificationVolume = stats['notificationVolume'] ?? 0.8;
      _isMuted = stats['isMuted'] ?? false;
      _hapticsEnabled = stats['hapticsEnabled'] ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Audio Settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Mute toggle
          SwitchListTile(
            title: const Text('Mute All Audio'),
            subtitle: const Text('Disable all sounds and notifications'),
            value: _isMuted,
            onChanged: (value) async {
              setState(() => _isMuted = value);
              await _audioService.setMuted(value);
            },
            secondary: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: _isMuted ? Colors.red : null,
            ),
          ),

          const Divider(height: 32),

          // Master Volume
          _buildVolumeSlider(
            label: 'Master Volume',
            icon: Icons.volume_up,
            value: _masterVolume,
            enabled: !_isMuted,
            onChanged: (value) async {
              setState(() => _masterVolume = value);
              await _audioService.setMasterVolume(value);
            },
            onTest: () => _audioService.playNotification(),
          ),

          const SizedBox(height: 16),

          // Effects Volume
          _buildVolumeSlider(
            label: 'Sound Effects',
            icon: Icons.music_note,
            value: _effectsVolume,
            enabled: !_isMuted,
            onChanged: (value) async {
              setState(() => _effectsVolume = value);
              await _audioService.setEffectsVolume(value);
            },
            onTest: () => _audioService.playNotification(),
          ),

          const SizedBox(height: 16),

          // Voice Volume
          _buildVolumeSlider(
            label: 'Voice Chat',
            icon: Icons.mic,
            value: _voiceVolume,
            enabled: !_isMuted,
            onChanged: (value) async {
              setState(() => _voiceVolume = value);
              await _audioService.setVoiceVolume(value);
            },
            onTest: null, // No test sound for voice
          ),

          const SizedBox(height: 16),

          // Notification Volume
          _buildVolumeSlider(
            label: 'Notifications',
            icon: Icons.notifications,
            value: _notificationVolume,
            enabled: !_isMuted,
            onChanged: (value) async {
              setState(() => _notificationVolume = value);
              await _audioService.setNotificationVolume(value);
            },
            onTest: () => _audioService.playMessageReceived(),
          ),

          const Divider(height: 32),

          // Haptics toggle
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibration for interactions and notifications'),
            value: _hapticsEnabled,
            onChanged: (value) async {
              setState(() => _hapticsEnabled = value);
              await _audioService.setHapticsEnabled(value);
              if (value) {
                // Test haptic
                _audioService.playNotification();
              }
            },
            secondary: const Icon(Icons.vibration),
          ),

          const SizedBox(height: 16),

          // Statistics
          _buildStatisticsSection(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider({
    required String label,
    required IconData icon,
    required double value,
    required bool enabled,
    required Function(double) onChanged,
    VoidCallback? onTest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: enabled ? null : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: enabled ? null : Colors.grey,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: enabled ? null : Colors.grey,
              ),
            ),
            if (onTest != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.play_circle_outline, size: 20),
                onPressed: enabled ? onTest : null,
                tooltip: 'Test sound',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: enabled ? Theme.of(context).primaryColor : Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
            thumbColor: enabled ? Theme.of(context).primaryColor : Colors.grey,
          ),
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
            min: 0.0,
            max: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    final stats = _audioService.getStatistics();
    final permissions = stats['permissions'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio System Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildStatusRow('Active Players', '${stats['activePlayers'] ?? 0}'),
          _buildStatusRow('Cached Sounds', '${stats['cachedSounds'] ?? 0}'),
          _buildStatusRow('Cache Size', stats['cacheSize'] ?? '0 MB'),
          _buildStatusRow(
            'Audio Permission',
            permissions['audio'] == true ? 'Granted' : 'Denied',
            color: permissions['audio'] == true ? Colors.green : Colors.orange,
          ),
          _buildStatusRow(
            'Vibration Support',
            permissions['vibration'] == true ? 'Available' : 'Unavailable',
            color: permissions['vibration'] == true ? Colors.green : Colors.grey,
          ),
          if (Theme.of(context).platform == TargetPlatform.android)
            _buildStatusRow(
              'Audio Focus',
              stats['hasAudioFocus'] == true ? 'Granted' : 'Not Granted',
              color: stats['hasAudioFocus'] == true ? Colors.green : Colors.orange,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Show audio settings bottom sheet
void showAudioSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AudioSettingsWidget(),
  );
}