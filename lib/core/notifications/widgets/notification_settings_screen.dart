import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/material.dart' as material show TimeOfDay;

import '../notification_preferences.dart';
import '../notification_types.dart';

/// Screen for managing notification preferences
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationPreferencesService _preferencesService = NotificationPreferencesService();
  late NotificationPreferences _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (!_preferencesService.isLoaded) {
      await _preferencesService.loadPreferences();
    }
    setState(() {
      _preferences = _preferencesService.preferences;
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    await _preferencesService.savePreferences(_preferences);
  }

  void _updatePreferences(NotificationPreferences updated) {
    setState(() {
      _preferences = updated;
    });
    _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGlobalSettings(),
          const SizedBox(height: 24),
          _buildDoNotDisturbSettings(),
          const SizedBox(height: 24),
          _buildNotificationTypeSettings(),
        ],
      ),
    );
  }

  Widget _buildGlobalSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Master switch for all notifications'),
              value: _preferences.enableNotifications,
              onChanged: (value) {
                _updatePreferences(_preferences.copyWith(enableNotifications: value));
              },
            ),
            SwitchListTile(
              title: const Text('Enable Sounds'),
              subtitle: const Text('Play sounds for notifications'),
              value: _preferences.enableSounds,
              onChanged: _preferences.enableNotifications ? (value) {
                _updatePreferences(_preferences.copyWith(enableSounds: value));
              } : null,
            ),
            SwitchListTile(
              title: const Text('Enable Vibration'),
              subtitle: const Text('Vibrate for important notifications'),
              value: _preferences.enableVibration,
              onChanged: _preferences.enableNotifications ? (value) {
                _updatePreferences(_preferences.copyWith(enableVibration: value));
              } : null,
            ),
            SwitchListTile(
              title: const Text('Enable Banners'),
              subtitle: const Text('Show banner notifications'),
              value: _preferences.enableBanners,
              onChanged: _preferences.enableNotifications ? (value) {
                _updatePreferences(_preferences.copyWith(enableBanners: value));
              } : null,
            ),
            SwitchListTile(
              title: const Text('Enable Push Notifications'),
              subtitle: const Text('Receive notifications when app is closed'),
              value: _preferences.enablePushNotifications,
              onChanged: _preferences.enableNotifications ? (value) {
                _updatePreferences(_preferences.copyWith(enablePushNotifications: value));
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoNotDisturbSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do Not Disturb',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Do Not Disturb'),
              subtitle: const Text('Quiet hours for notifications'),
              value: _preferences.enableDoNotDisturb,
              onChanged: _preferences.enableNotifications ? (value) {
                _updatePreferences(_preferences.copyWith(enableDoNotDisturb: value));
              } : null,
            ),
            if (_preferences.enableDoNotDisturb) ...[
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_preferences.doNotDisturbStart?.toString() ?? 'Not set'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(true),
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(_preferences.doNotDisturbEnd?.toString() ?? 'Not set'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypeSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Types',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...NotificationType.values.map((type) => _buildNotificationTypeCard(type)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypeCard(NotificationType type) {
    final isEnabled = _preferences.typeEnabled[type] ?? false;
    final soundEnabled = _preferences.typeSoundEnabled[type] ?? false;
    final vibrateEnabled = _preferences.typeVibrateEnabled[type] ?? false;
    final minPriority = _preferences.typeMinPriority[type] ?? NotificationPriority.low;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: _getTypeIcon(type),
        title: Text(_getTypeDisplayName(type)),
        subtitle: Text(isEnabled ? 'Enabled' : 'Disabled'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enabled'),
                  value: isEnabled,
                  onChanged: _preferences.enableNotifications ? (value) {
                    final updated = Map<NotificationType, bool>.from(_preferences.typeEnabled);
                    updated[type] = value;
                    _updatePreferences(_preferences.copyWith(typeEnabled: updated));
                  } : null,
                ),
                SwitchListTile(
                  title: const Text('Sound'),
                  value: soundEnabled,
                  onChanged: isEnabled && _preferences.enableSounds ? (value) {
                    final updated = Map<NotificationType, bool>.from(_preferences.typeSoundEnabled);
                    updated[type] = value;
                    _updatePreferences(_preferences.copyWith(typeSoundEnabled: updated));
                  } : null,
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  value: vibrateEnabled,
                  onChanged: isEnabled && _preferences.enableVibration ? (value) {
                    final updated = Map<NotificationType, bool>.from(_preferences.typeVibrateEnabled);
                    updated[type] = value;
                    _updatePreferences(_preferences.copyWith(typeVibrateEnabled: updated));
                  } : null,
                ),
                ListTile(
                  title: const Text('Minimum Priority'),
                  subtitle: Text(_getPriorityDisplayName(minPriority)),
                  trailing: DropdownButton<NotificationPriority>(
                    value: minPriority,
                    onChanged: isEnabled ? (value) {
                      if (value != null) {
                        final updated = Map<NotificationType, NotificationPriority>.from(_preferences.typeMinPriority);
                        updated[type] = value;
                        _updatePreferences(_preferences.copyWith(typeMinPriority: updated));
                      }
                    } : null,
                    items: NotificationPriority.values.map((priority) {
                      return DropdownMenuItem(
                        value: priority,
                        child: Text(_getPriorityDisplayName(priority)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getTypeIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.challenge:
        iconData = Icons.sports_kabaddi;
        color = Colors.orange;
        break;
      case NotificationType.arenaRole:
        iconData = Icons.gavel;
        color = Colors.purple;
        break;
      case NotificationType.arenaStarted:
        iconData = Icons.play_circle;
        color = Colors.green;
        break;
      case NotificationType.arenaEnded:
        iconData = Icons.stop_circle;
        color = Colors.blue;
        break;
      case NotificationType.tournamentInvite:
        iconData = Icons.emoji_events;
        color = Colors.amber;
        break;
      case NotificationType.friendRequest:
        iconData = Icons.person_add;
        color = Colors.teal;
        break;
      case NotificationType.mention:
        iconData = Icons.alternate_email;
        color = Colors.indigo;
        break;
      case NotificationType.achievement:
        iconData = Icons.star;
        color = Colors.yellow;
        break;
      case NotificationType.systemAnnouncement:
        iconData = Icons.campaign;
        color = Colors.red;
        break;
      case NotificationType.roomChat:
        iconData = Icons.chat;
        color = Colors.lightBlue;
        break;
      case NotificationType.voteReminder:
        iconData = Icons.how_to_vote;
        color = Colors.deepOrange;
        break;
      case NotificationType.followUp:
        iconData = Icons.schedule;
        color = Colors.grey;
        break;
      case NotificationType.instantMessage:
        iconData = Icons.message;
        color = const Color(0xFF8B5CF6);
        break;
    }

    return Icon(iconData, color: color);
  }

  String _getTypeDisplayName(NotificationType type) {
    switch (type) {
      case NotificationType.challenge:
        return 'Challenge Invitations';
      case NotificationType.arenaRole:
        return 'Arena Role Invitations';
      case NotificationType.arenaStarted:
        return 'Arena Started';
      case NotificationType.arenaEnded:
        return 'Arena Ended';
      case NotificationType.tournamentInvite:
        return 'Tournament Invitations';
      case NotificationType.friendRequest:
        return 'Friend Requests';
      case NotificationType.mention:
        return 'Mentions';
      case NotificationType.achievement:
        return 'Achievements';
      case NotificationType.systemAnnouncement:
        return 'System Announcements';
      case NotificationType.roomChat:
        return 'Room Chat';
      case NotificationType.voteReminder:
        return 'Vote Reminders';
      case NotificationType.followUp:
        return 'Follow-ups';
      case NotificationType.instantMessage:
        return 'Instant Messages';
    }
  }

  String _getPriorityDisplayName(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.medium:
        return 'Medium';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.urgent:
        return 'Urgent';
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final currentTime = isStartTime 
        ? _preferences.doNotDisturbStart 
        : _preferences.doNotDisturbEnd;
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime != null 
          ? material.TimeOfDay(hour: currentTime.hour, minute: currentTime.minute)
          : material.TimeOfDay.now(),
    );

    if (selectedTime != null) {
      final timeOfDay = TimeOfDay(hour: selectedTime.hour, minute: selectedTime.minute);
      
      final updated = isStartTime 
          ? _preferences.copyWith(doNotDisturbStart: timeOfDay)
          : _preferences.copyWith(doNotDisturbEnd: timeOfDay);
      
      _updatePreferences(updated);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all notification settings to their defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _preferencesService.resetToDefaults();
      setState(() {
        _preferences = _preferencesService.preferences;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings reset to defaults')),
        );
      }
    }
  }
}

