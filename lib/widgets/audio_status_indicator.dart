import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/persistent_audio_service.dart';
import '../core/logging/app_logger.dart';

/// Global audio status indicator widget
/// Shows current audio connection status with visual feedback
class AudioStatusIndicator extends StatefulWidget {
  final bool showLabel;
  final double size;
  
  const AudioStatusIndicator({
    super.key,
    this.showLabel = false,
    this.size = 16.0,
  });

  @override
  State<AudioStatusIndicator> createState() => _AudioStatusIndicatorState();
}

class _AudioStatusIndicatorState extends State<AudioStatusIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  PersistentAudioService? _audioService;
  bool _isConnected = false;
  bool _isHealthy = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation for connecting state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _initializeAudioService();
  }

  void _initializeAudioService() {
    try {
      if (GetIt.instance.isRegistered<PersistentAudioService>()) {
        _audioService = GetIt.instance<PersistentAudioService>();
        _audioService!.addListener(_updateAudioStatus);
        _updateAudioStatus();
      }
    } catch (e) {
      AppLogger().warning('Failed to initialize audio status indicator: $e');
    }
  }

  void _updateAudioStatus() {
    if (!mounted || _audioService == null) return;
    
    setState(() {
      _isConnected = _audioService!.isConnected;
      _isHealthy = _audioService!.isConnectionHealthy;
    });
    
    // Control pulse animation based on connection state
    if (_isConnected && _isHealthy) {
      _pulseController.stop();
    } else if (_isConnected && !_isHealthy) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _audioService?.removeListener(_updateAudioStatus);
    _pulseController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    if (!_isConnected) {
      return Colors.red; // Disconnected
    } else if (!_isHealthy) {
      return Colors.orange; // Connected but degraded
    } else {
      return Colors.green; // Connected and healthy
    }
  }

  String get _statusText {
    if (!_isConnected) {
      return 'Audio Disconnected';
    } else if (!_isHealthy) {
      return 'Audio Degraded';
    } else {
      return 'Audio Ready';
    }
  }

  IconData get _statusIcon {
    if (!_isConnected) {
      return Icons.mic_off;
    } else if (!_isHealthy) {
      return Icons.mic_external_on;
    } else {
      return Icons.mic;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.showLabel ? _showAudioStatusDialog : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor.withValues(
                    alpha: _isConnected && _isHealthy 
                        ? 1.0 
                        : _pulseAnimation.value,
                  ),
                  boxShadow: [
                    if (!_isConnected || !_isHealthy)
                      BoxShadow(
                        color: _statusColor.withValues(alpha: 0.3),
                        blurRadius: 4 * _pulseAnimation.value,
                        spreadRadius: 2 * _pulseAnimation.value,
                      ),
                  ],
                ),
                child: Icon(
                  _statusIcon,
                  size: widget.size * 0.6,
                  color: Colors.white,
                ),
              );
            },
          ),
          if (widget.showLabel) ...[
            const SizedBox(width: 8),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _statusColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAudioStatusDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_statusIcon, color: _statusColor),
            const SizedBox(width: 8),
            Text(_statusText),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Connection', _isConnected ? 'Connected' : 'Disconnected'),
            _buildStatusRow('Health', _isHealthy ? 'Healthy' : 'Degraded'),
            if (_audioService != null) ...[
              _buildStatusRow('Current Room', _audioService!.currentRoomId ?? 'None'),
              _buildStatusRow('User Role', _audioService!.currentUserRole ?? 'None'),
              _buildStatusRow('Muted', _audioService!.isMuted ? 'Yes' : 'No'),
            ],
          ],
        ),
        actions: [
          if (!_isConnected || !_isHealthy)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _retryConnection();
              },
              child: const Text('Retry Connection'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDetailedDiagnostics();
            },
            child: const Text('Diagnostics'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  void _retryConnection() async {
    if (_audioService == null) return;
    
    try {
      AppLogger().info('🔄 Manual audio connection retry requested');
      
      // Try to restart the audio service
      if (_audioService!.currentUserId != null) {
        await _audioService!.restart(userId: _audioService!.currentUserId!);
      }
    } catch (e) {
      AppLogger().warning('Manual audio retry failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reconnect audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDetailedDiagnostics() async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Connection Diagnostics'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Common Issues & Solutions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDiagnosticItem(
                '🔥 Firewall/Network Blocking',
                'Try switching from WiFi to mobile data or vice versa',
              ),
              _buildDiagnosticItem(
                '🏢 Corporate Network',
                'Corporate networks often block WebRTC. Use personal hotspot.',
              ),
              _buildDiagnosticItem(
                '📡 Router Issues',
                'Restart your router or try a different network',
              ),
              _buildDiagnosticItem(
                '🌐 Server Issues',
                'The LiveKit server might be down or misconfigured',
              ),
              const SizedBox(height: 16),
              const Text(
                'Troubleshooting Steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Switch networks (WiFi ↔ Mobile Data)'),
              const Text('2. Restart the app'),
              const Text('3. Check with other users'),
              const Text('4. Contact support if persistent'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _testNetworkConnection();
            },
            child: const Text('Test Network'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _testNetworkConnection() async {
    if (!mounted) return;
    
    // Show testing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Testing Network...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing connection to LiveKit server...'),
          ],
        ),
      ),
    );
    
    try {
      // Test basic connectivity
      final response = await HttpClient()
          .getUrl(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      final httpResponse = await response.close().timeout(const Duration(seconds: 5));
      
      if (mounted) {
        Navigator.of(context).pop(); // Close testing dialog
        
        String message;
        if (httpResponse.statusCode == 200) {
          message = '✅ Internet connection is working.\n\n'
                   'The issue appears to be with WebRTC/LiveKit connectivity.\n'
                   'Try switching networks or contact support.';
        } else {
          message = '⚠️ Internet connection has issues.\n\n'
                   'Status code: ${httpResponse.statusCode}\n'
                   'Try switching to a different network.';
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Network Test Results'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close testing dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Network Test Failed'),
            content: Text(
              '❌ Network connectivity test failed.\n\n'
              'Error: $e\n\n'
              'Please check your internet connection and try again.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}