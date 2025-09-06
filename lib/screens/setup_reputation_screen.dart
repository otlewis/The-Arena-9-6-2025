import 'package:flutter/material.dart';
import '../setup/create_reputation_logs.dart';
import '../core/logging/app_logger.dart';

class SetupReputationScreen extends StatefulWidget {
  const SetupReputationScreen({super.key});

  @override
  State<SetupReputationScreen> createState() => _SetupReputationScreenState();
}

class _SetupReputationScreenState extends State<SetupReputationScreen> {
  bool _isLoading = false;
  String _status = '';
  bool _isComplete = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Reputation System'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.star,
              size: 80,
              color: Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reputation System Setup',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will create the reputation_logs collection in Appwrite database',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
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
              onPressed: _isLoading || _isComplete ? null : _createCollection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
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
                      Text('Creating Collection...'),
                    ],
                  )
                : Text(_isComplete ? 'Setup Complete!' : 'Create reputation_logs Collection'),
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
            const SizedBox(height: 24),
            const Text(
              'What will be created:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem('Collection: reputation_logs'),
            _buildFeatureItem('Attributes: userId, pointsChange, newTotal, reason, timestamp'),
            _buildFeatureItem('Indexes: userId, timestamp, compound index'),
            _buildFeatureItem('Permissions: Read/Write for authenticated users'),
            const SizedBox(height: 24),
            const Text(
              'This enables:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem('🏆 Reputation points for debate wins/losses'),
            _buildFeatureItem('🎁 Reputation for sending/receiving gifts'),
            _buildFeatureItem('📊 Full audit trail of reputation changes'),
            _buildFeatureItem('📈 Leaderboards and rankings'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCollection() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting collection creation...';
    });

    try {
      await ReputationLogsCollectionSetup.createCollection();
      
      setState(() {
        _isLoading = false;
        _isComplete = true;
        _status = '🎉 Success! reputation_logs collection created with all attributes and indexes. The reputation system is now ready!';
      });
      
      AppLogger().info('✅ Reputation system setup completed successfully');
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error: ${e.toString()}\n\nPlease check the logs or create the collection manually in Appwrite Console.';
      });
      
      AppLogger().error('❌ Reputation system setup failed: $e');
    }
  }
}