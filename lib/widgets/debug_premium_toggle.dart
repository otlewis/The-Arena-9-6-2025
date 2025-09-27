import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';
import '../services/revenue_cat_service.dart';
import '../core/logging/app_logger.dart';

/// Debug widget to manually toggle premium status for testing
class DebugPremiumToggle extends StatefulWidget {
  final String userId;
  final String userName;
  
  const DebugPremiumToggle({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<DebugPremiumToggle> createState() => _DebugPremiumToggleState();
}

class _DebugPremiumToggleState extends State<DebugPremiumToggle> {
  bool _isUpdating = false;
  String _status = '';
  final RevenueCatService _revenueCatService = RevenueCatService();

  Future<void> _togglePremium(bool isPremium, String type) async {
    setState(() {
      _isUpdating = true;
      _status = 'Updating premium status...';
    });

    try {
      final appwrite = AppwriteService();
      
      final updateData = {
        'isPremium': isPremium,
        'premiumType': isPremium ? type : null,
        'premiumExpiry': isPremium ? DateTime.now().add(
          type == 'yearly' ? const Duration(days: 365) : const Duration(days: 30)
        ).toIso8601String() : null,
        'isTestSubscription': isPremium,
      };

      AppLogger().debug('🧪 Updating user ${widget.userId} premium status: $updateData');
      
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: widget.userId,
        data: updateData,
      );

      setState(() {
        _status = isPremium 
          ? '✅ ${widget.userName} is now ${type.toUpperCase()} premium!' 
          : '✅ ${widget.userName} premium status removed';
        _isUpdating = false;
      });

      AppLogger().info('🎉 Premium status updated successfully for ${widget.userName}');

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_status),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Refresh the page after 2 seconds to show the changes
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        // Force a page refresh by triggering a rebuild
        setState(() {
          _status = '🔄 Refreshing to show changes...';
        });
      }

    } catch (e) {
      setState(() {
        _status = '❌ Error: ${e.toString()}';
        _isUpdating = false;
      });
      AppLogger().error('Failed to update premium status: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating premium status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _syncRevenueCatStatus() async {
    setState(() {
      _isUpdating = true;
      _status = 'Syncing RevenueCat with Appwrite...';
    });

    try {
      await _revenueCatService.forceSyncPremiumStatus();
      
      setState(() {
        _status = '✅ RevenueCat sync completed!';
        _isUpdating = false;
      });

      AppLogger().info('🔄 RevenueCat sync completed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ RevenueCat premium status synced with Appwrite'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Refresh after sync
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _status = '🔄 Refreshing to show changes...';
        });
      }

    } catch (e) {
      setState(() {
        _status = '❌ Sync Error: ${e.toString()}';
        _isUpdating = false;
      });
      AppLogger().error('Failed to sync RevenueCat status: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _checkRevenueCatStatus() async {
    setState(() {
      _isUpdating = true;
      _status = 'Checking RevenueCat status...';
    });

    try {
      final status = await _revenueCatService.getRevenueCatStatus();
      
      String statusText = '📊 RevenueCat Status:\n';
      statusText += '• Initialized: ${status['isInitialized']}\n';
      statusText += '• Has Customer Info: ${status['hasCustomerInfo']}\n';
      statusText += '• Customer User ID: ${status['customerUserId'] ?? 'None'}\n';
      statusText += '• Has Premium: ${status['hasPremium']}\n';
      statusText += '• Active Entitlements: ${status['activeEntitlements']}\n';
      statusText += '• All Entitlements: ${status['allEntitlements']}';
      
      if (status['error'] != null) {
        statusText += '\n❌ Error: ${status['error']}';
      }
      
      setState(() {
        _status = statusText;
        _isUpdating = false;
      });

      AppLogger().info('RevenueCat Status Check: $status');

    } catch (e) {
      setState(() {
        _status = '❌ Status Check Error: ${e.toString()}';
        _isUpdating = false;
      });
      AppLogger().error('Failed to check RevenueCat status: $e');
    }
  }

  Future<void> _mockSandboxPurchase(String productId) async {
    setState(() {
      _isUpdating = true;
      _status = 'Creating mock sandbox purchase...';
    });

    try {
      final success = await _revenueCatService.mockSandboxPurchase(productId);
      
      if (success) {
        setState(() {
          _status = '✅ Mock sandbox purchase successful!';
          _isUpdating = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Mock ${productId.contains('yearly') ? 'yearly' : 'monthly'} purchase successful!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _status = '❌ Mock purchase failed';
          _isUpdating = false;
        });
      }

      // Refresh after a delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _status = '🔄 Refreshing to show changes...';
        });
      }

    } catch (e) {
      setState(() {
        _status = '❌ Mock Purchase Error: ${e.toString()}';
        _isUpdating = false;
      });
      AppLogger().error('Mock sandbox purchase failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Mock purchase failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        border: Border.all(color: Colors.purple),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🧪 DEBUG: Premium Status Toggle',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manually set premium status for ${widget.userName}',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_status.isNotEmpty) ...[
            Text(
              _status,
              style: TextStyle(
                fontSize: 12,
                color: _status.startsWith('✅') 
                  ? Colors.green 
                  : (_status.startsWith('❌') ? Colors.red : Colors.blue),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _isUpdating ? null : () => _togglePremium(true, 'yearly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Set YEARLY Premium'),
              ),
              ElevatedButton(
                onPressed: _isUpdating ? null : () => _togglePremium(true, 'monthly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Set MONTHLY Premium'),
              ),
              ElevatedButton(
                onPressed: _isUpdating ? null : () => _togglePremium(false, ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove Premium'),
              ),
              ElevatedButton(
                onPressed: _isUpdating ? null : _syncRevenueCatStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('🔄 Sync RevenueCat'),
              ),
              ElevatedButton(
                onPressed: _isUpdating ? null : _checkRevenueCatStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('📊 Check RC Status'),
              ),
              const SizedBox(width: 8, height: 8), // Separator
              const Text('🧪 Sandbox Purchases:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isUpdating ? null : () => _mockSandboxPurchase('arena_pro_yearly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('🧪 Mock Yearly'),
              ),
              ElevatedButton(
                onPressed: _isUpdating ? null : () => _mockSandboxPurchase('arena_pro_monthly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('🧪 Mock Monthly'),
              ),
            ],
          ),
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}