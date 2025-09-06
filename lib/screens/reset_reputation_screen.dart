import 'package:flutter/material.dart';
import '../setup/reset_reputation.dart';
import '../core/logging/app_logger.dart';

class ResetReputationScreen extends StatefulWidget {
  const ResetReputationScreen({super.key});

  @override
  State<ResetReputationScreen> createState() => _ResetReputationScreenState();
}

class _ResetReputationScreenState extends State<ResetReputationScreen> {
  bool _isLoading = false;
  String _status = '';
  bool _isComplete = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Reputation'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.refresh,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Reset All Reputation Values',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will reset ALL users\' reputation to 0 points.\nCoin balances will remain unchanged.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Warning',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This action will:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• Set all users\' reputation to 0'),
                  Text('• Keep coin balances unchanged'),
                  Text('• Enable the new reputation system'),
                  Text('• Cannot be undone'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isComplete ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isComplete ? Colors.green : Colors.blue,
                  ),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14,
                    color: _isComplete ? Colors.green[700] : Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton(
              onPressed: _isLoading || _isComplete ? null : _resetReputation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Resetting Reputation...'),
                    ],
                  )
                : Text(_isComplete ? 'Reset Complete!' : 'Reset All Reputation to 0'),
            ),
            if (_isComplete) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resetReputation() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting reputation reset for all users...';
    });

    try {
      await ReputationReset.resetAllReputation();
      
      setState(() {
        _isLoading = false;
        _isComplete = true;
        _status = '🎉 Success! All user reputation values have been reset to 0. The reputation system is now ready to track real reputation points!';
      });
      
      AppLogger().info('✅ Reputation reset completed successfully');
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error: ${e.toString()}\n\nSome users may not have been updated. Check the logs for details.';
      });
      
      AppLogger().error('❌ Reputation reset failed: $e');
    }
  }
}