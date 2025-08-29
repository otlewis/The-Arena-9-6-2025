import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:get_it/get_it.dart';
import '../services/super_moderator_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

class AdminSetupDialog extends StatefulWidget {
  const AdminSetupDialog({super.key});
  
  @override
  State<AdminSetupDialog> createState() => _AdminSetupDialogState();
}

class _AdminSetupDialogState extends State<AdminSetupDialog> {
  final SuperModeratorService _superModService = GetIt.instance<SuperModeratorService>();
  final AppwriteService _appwriteService = GetIt.instance<AppwriteService>();
  final AppLogger _logger = AppLogger();
  
  bool _isLoading = false;
  String _status = '';
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings, color: Color(0xFFFFD700)),
          SizedBox(width: 8),
          Text('Admin Setup'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will set up the Super Moderator system and grant Kritik admin privileges.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _setupSuperModerator,
          icon: const Icon(Icons.shield),
          label: const Text('Setup Kritik as Super Mod'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Future<void> _setupSuperModerator() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing Super Moderator service...';
    });
    
    try {
      // Initialize the service
      await _superModService.initialize();
      _updateStatus('✅ Service initialized');
      
      // Find Kritik's user profile
      _updateStatus('🔍 Looking for user "Kritik"...');
      
      final users = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('name', 'Kritik'),
        ],
      );
      
      if (users.documents.isEmpty) {
        _updateStatus('❌ User "Kritik" not found in database');
        return;
      }
      
      final kritikUser = users.documents.first;
      final userId = kritikUser.$id;
      final username = kritikUser.data['name'] as String;
      final profileImageUrl = kritikUser.data['profileImageUrl'] as String?;
      
      _updateStatus('✅ Found user: $username (ID: ${userId.substring(0, 8)}...)');
      
      // Check if already a Super Moderator
      if (_superModService.isSuperModerator(userId)) {
        _updateStatus('✅ Kritik is already a Super Moderator!');
        return;
      }
      
      _updateStatus('🎖️ Granting Super Moderator status...');
      
      // Grant Super Moderator status
      final superMod = await _superModService.grantSuperModeratorStatus(
        userId: userId,
        username: username,
        grantedBy: 'system',
        profileImageUrl: profileImageUrl,
      );
      
      if (superMod != null) {
        _updateStatus('🎉 SUCCESS! Kritik is now a Super Moderator');
        _updateStatus('Permissions: ${superMod.permissions.length} granted');
        
        // Show completion dialog after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.shield, color: Color(0xFFFFD700)),
                  SizedBox(width: 8),
                  Text('Setup Complete!'),
                ],
              ),
              content: const Text(
                'Kritik now has Super Moderator privileges:\n\n'
                '• Golden SM badge on profile\n'
                '• Cannot be kicked from rooms\n'
                '• Instant speaker panel access\n'
                '• Can lock mics, kick/ban users\n'
                '• Can promote other Super Mods\n'
                '• Access to Super Mod dashboard',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close success dialog
                    Navigator.pop(context); // Close setup dialog
                  },
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          );
        }
      } else {
        _updateStatus('❌ Failed to grant Super Moderator status');
      }
      
    } catch (e, stackTrace) {
      _updateStatus('❌ Error: $e');
      _logger.error('Setup failed: $e\n$stackTrace');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _status += '$message\n';
      });
    }
    _logger.info(message);
  }
}

// Helper function to show the setup dialog
void showAdminSetupDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AdminSetupDialog(),
  );
}