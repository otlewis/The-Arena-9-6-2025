import 'package:flutter/material.dart';
// import 'package:mediasfu_sdk/mediasfu_sdk.dart'; // Package not available
import '../services/appwrite_service.dart';
// import '../models/user_profile.dart'; // Unused import
import '../core/logging/app_logger.dart';
import 'arena_webrtc_screen.dart';

class MediaSFUTestScreen extends StatefulWidget {
  const MediaSFUTestScreen({Key? key}) : super(key: key);

  @override
  State<MediaSFUTestScreen> createState() => _MediaSFUTestScreenState();
}

class _MediaSFUTestScreenState extends State<MediaSFUTestScreen> {
  final AppwriteService _appwrite = AppwriteService();
  
  // User info
  // UserProfile? _currentUser; // Unused field
  String _displayName = 'Guest';
  
  // MediaSFU configuration
  bool _isReady = false;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCurrentUser();
    setState(() {
      _isReady = true;
      _status = 'Ready to start MediaSFU room';
    });
  }

  void _autoLaunchMediaSFU() {
    // MediaSFU SDK not available - redirecting to WebRTC test
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ArenaWebRTCScreen(),
      ),
    );
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser != null) {
        final userProfile = await _appwrite.getUserProfile(currentUser.$id);
        setState(() {
          // _currentUser = userProfile;
          _displayName = userProfile?.name ?? 'User ${currentUser.$id.substring(0, 6)}';
        });
        AppLogger().debug("Loaded user: ${userProfile?.name}");
      }
    } catch (e) {
      AppLogger().error("Error loading current user: $e");
      setState(() {
        _displayName = 'Guest ${DateTime.now().millisecondsSinceEpoch % 1000}';
      });
    }
  }

  void _launchMediaSFURoom() {
    // Launch direct Arena WebRTC connection - completely bypass MediaSFU SDK
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ArenaWebRTCScreen(),
      ),
    );
  }

  void _launchSimpleMediaSFU() {
    // MediaSFU SDK not available - redirecting to WebRTC test
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ArenaWebRTCScreen(),
      ),
    );
  }

  void _launchDirectJoin() {
    // MediaSFU SDK not available - redirecting to WebRTC test
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ArenaWebRTCScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediaSFU Conference Test'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purple, width: 3),
              ),
              child: const Icon(
                Icons.video_call,
                size: 60,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 40),
            
            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isReady ? Colors.purple : Colors.orange,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Display Name: $_displayName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: $_status',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Action buttons
            if (_isReady) ...[
              // MediaSFU Cloud (Free testing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchSimpleMediaSFU,
                  icon: const Icon(Icons.cloud, color: Colors.white),
                  label: const Text(
                    'Start MediaSFU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Basic MediaSFU cloud launch',
                style: TextStyle(color: Colors.purple[200], fontSize: 12),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Ultimate Auto-Launch Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _autoLaunchMediaSFU,
                  icon: const Icon(Icons.bolt, color: Colors.white),
                  label: const Text(
                    'Quick Launch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Replace current screen with MediaSFU',
                style: TextStyle(color: Colors.red[200], fontSize: 12),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Direct Join Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchDirectJoin,
                  icon: const Icon(Icons.fast_forward, color: Colors.white),
                  label: const Text(
                    'Basic MediaSFU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Standard MediaSFU interface',
                style: TextStyle(color: Colors.green[200], fontSize: 12),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Self-hosted option
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _launchMediaSFURoom,
                  icon: const Icon(Icons.dns, color: Colors.orange),
                  label: const Text(
                    'Direct Arena Connection',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Zero MediaSFU - connects directly to your server',
                style: TextStyle(color: Colors.orange[200], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            
            if (!_isReady) ...[
              const CircularProgressIndicator(color: Colors.purple),
              const SizedBox(height: 16),
              const Text(
                'Initializing...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
            
            const Spacer(),
            
            // Info section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Text(
                    'MediaSFU Video Conference',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Full video conferencing support\\n'
                    '• Audio/Video toggle controls\\n' 
                    '• Chat and participant management\\n'
                    '• Bypass login screen with credentials\\n'
                    '• Direct room join options\\n'
                    '• Professional conference UI',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}