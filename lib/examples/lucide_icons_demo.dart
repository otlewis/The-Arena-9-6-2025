import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Demo showing Lucide Icons with Arena app's scarlet and purple theme
class LucideIconsDemo extends StatelessWidget {
  const LucideIconsDemo({super.key});

  // Your app's theme colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucide Icons Demo'),
        backgroundColor: Colors.white,
        foregroundColor: deepPurple,
        actions: const [
          // Notification bell
          Icon(LucideIcons.bell, color: scarletRed, size: 24),
          SizedBox(width: 16),
          // Settings
          Icon(LucideIcons.settings, color: accentPurple, size: 24),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Navigation Icons', _navigationIcons()),
            _buildSection('Communication Icons', _communicationIcons()),
            _buildSection('Media Icons', _mediaIcons()),
            _buildSection('Action Icons', _actionIcons()),
            _buildSection('Status Icons', _statusIcons()),
            _buildSection('Styled Button Examples', _styledButtons()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        content,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _navigationIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _iconCard(LucideIcons.home, 'Home', scarletRed),
        _iconCard(LucideIcons.search, 'Search', accentPurple),
        _iconCard(LucideIcons.arrowLeft, 'Back', deepPurple),
        _iconCard(LucideIcons.menu, 'Menu', scarletRed),
        _iconCard(LucideIcons.moreVertical, 'More', accentPurple),
      ],
    );
  }

  Widget _communicationIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _iconCard(LucideIcons.messageCircle, 'Chat', scarletRed),
        _iconCard(LucideIcons.send, 'Send', accentPurple),
        _iconCard(LucideIcons.phone, 'Call', deepPurple),
        _iconCard(LucideIcons.mail, 'Email', scarletRed),
        _iconCard(LucideIcons.bell, 'Notifications', accentPurple),
      ],
    );
  }

  Widget _mediaIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _iconCard(LucideIcons.mic, 'Microphone', scarletRed),
        _iconCard(LucideIcons.micOff, 'Mic Off', Colors.grey),
        _iconCard(LucideIcons.video, 'Video', accentPurple),
        _iconCard(LucideIcons.videoOff, 'Video Off', Colors.grey),
        _iconCard(LucideIcons.volume2, 'Volume', deepPurple),
      ],
    );
  }

  Widget _actionIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _iconCard(LucideIcons.plus, 'Add', scarletRed),
        _iconCard(LucideIcons.edit, 'Edit', accentPurple),
        _iconCard(LucideIcons.trash2, 'Delete', Colors.red),
        _iconCard(LucideIcons.share, 'Share', deepPurple),
        _iconCard(LucideIcons.download, 'Download', scarletRed),
      ],
    );
  }

  Widget _statusIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _iconCard(LucideIcons.check, 'Success', Colors.green),
        _iconCard(LucideIcons.x, 'Close', Colors.red),
        _iconCard(LucideIcons.alertTriangle, 'Warning', Colors.orange),
        _iconCard(LucideIcons.info, 'Info', accentPurple),
        _iconCard(LucideIcons.star, 'Favorite', scarletRed),
      ],
    );
  }

  Widget _iconCard(IconData icon, String label, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: deepPurple,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _styledButtons() {
    return Column(
      children: [
        // Primary buttons with Lucide icons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.messageCircle, size: 20),
                label: const Text('Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scarletRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.mic, size: 20),
                label: const Text('Speak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Outlined buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.userPlus, size: 20),
                label: const Text('Follow'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scarletRed,
                  side: const BorderSide(color: scarletRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.share, size: 20),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentPurple,
                  side: const BorderSide(color: accentPurple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Floating action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: "lucide_demo_1",
              onPressed: () {},
              backgroundColor: scarletRed,
              child: const Icon(LucideIcons.plus, color: Colors.white),
            ),
            FloatingActionButton(
              heroTag: "lucide_demo_2",
              onPressed: () {},
              backgroundColor: accentPurple,
              child: const Icon(LucideIcons.bell, color: Colors.white),
            ),
            FloatingActionButton(
              heroTag: "lucide_demo_3",
              onPressed: () {},
              backgroundColor: deepPurple,
              child: const Icon(LucideIcons.settings, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
} 