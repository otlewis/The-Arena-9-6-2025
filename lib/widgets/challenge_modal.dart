import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../widgets/user_avatar.dart';
import '../services/challenge_messaging_service.dart';
import '../features/arena/screens/arena_screen_modular.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

class ChallengeModal extends StatefulWidget {
  final Map<String, dynamic> challenge;
  final VoidCallback onDismiss;

  const ChallengeModal({
    super.key,
    required this.challenge,
    required this.onDismiss,
  });

  @override
  State<ChallengeModal> createState() => _ChallengeModalState();
}

class _ChallengeModalState extends State<ChallengeModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isResponding = false;

  // Colors matching app theme
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.8, // Limit to 80% of screen height
                maxWidth: 400, // Reasonable max width
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _buildContent(),
                    ),
                  ),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [scarletRed, accentPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.flash_on,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Challenge Received!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: _dismiss,
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContent() {
    final challengerName = widget.challenge['challengerName'] ?? 'Unknown User';
    final challengerAvatar = widget.challenge['challengerAvatar'];
    final topic = widget.challenge['topic'] ?? 'No topic provided';
    final description = widget.challenge['description'] ?? '';
    final challengerPosition = widget.challenge['position'] ?? 'affirmative';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Challenger info
          Row(
            children: [
              UserAvatar(
                avatarUrl: challengerAvatar,
                initials: challengerName.isNotEmpty ? challengerName[0] : '?',
                radius: 25,
                backgroundColor: lightScarlet,
                textColor: scarletRed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challengerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: deepPurple,
                      ),
                    ),
                    Text(
                      'wants to debate with you',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Challenge topic
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightScarlet,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scarletRed.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debate Topic:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  topic,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scarletRed,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Additional Details:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: deepPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Position Information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: challengerPosition == 'affirmative' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: challengerPosition == 'affirmative' ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  challengerPosition == 'affirmative' ? Icons.thumb_up : Icons.thumb_down,
                  color: challengerPosition == 'affirmative' ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$challengerName will argue ${challengerPosition == 'affirmative' ? 'FOR' : 'AGAINST'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: challengerPosition == 'affirmative' ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'You will argue ${challengerPosition == 'affirmative' ? 'AGAINST' : 'FOR'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isResponding ? null : () => _respondToChallenge('declined'),
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isResponding ? null : () => _respondToChallenge('accepted'),
                  icon: _isResponding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.flash_on),
                  label: Text(_isResponding ? 'Accepting...' : 'Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scarletRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _decideLater,
            child: Text(
              'I\'ll decide later',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToChallenge(String response) async {
    setState(() => _isResponding = true);

    try {
      await ChallengeMessagingService().respondToChallenge(
        widget.challenge['id'],
        response,
      );

      if (mounted) {
        if (response == 'accepted') {
          final topic = widget.challenge['topic'] ?? 'Debate Topic';
          final description = widget.challenge['description'];
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Challenge accepted! Getting Arena room...'),
              backgroundColor: Colors.green,
            ),
          );

          // Get the room ID from the updated challenge (messaging service creates the room)
          final challengeId = widget.challenge['id'];
          
          // Wait a moment for the messaging service to update the challenge with room ID
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Fetch the updated challenge to get the arena room ID
          final appwrite = AppwriteService();
          String? roomId = widget.challenge['arenaRoomId'];
          
          if (roomId == null) {
            // Try to find the room by challenge ID
            final rooms = await appwrite.databases.listDocuments(
              databaseId: 'arena_db',
              collectionId: 'arena_rooms',
              queries: [
                Query.equal('challengeId', challengeId),
                Query.equal('status', 'waiting'),
              ],
            );
            
            if (rooms.documents.isNotEmpty) {
              roomId = rooms.documents.first.$id;
              AppLogger().info('Found arena room: $roomId');
            } else {
              throw Exception('Arena room not found after challenge acceptance');
            }
          }

          // ✅ NOTE: Judge/moderator invitations are now handled automatically 
          // by ChallengeMessagingService when the arena room is created

          // Navigate to Arena
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ArenaScreenModular(
                roomId: roomId!,
                challengeId: widget.challenge['id'],
                topic: topic,
                description: description,
                challengerId: widget.challenge['challengerId'],
                challengedId: widget.challenge['challengedId'],
              ),
            ),
          );
          
          _dismiss();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Challenge declined'),
              backgroundColor: Colors.orange,
            ),
          );
          _dismiss();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
      }
    }
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _decideLater() async {
    try {
      // Mark challenge as dismissed but keep in messages list
      await ChallengeMessagingService().dismissChallenge(widget.challenge['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💭 Challenge saved to Messages for later'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      AppLogger().debug('Error dismissing challenge: $e');
    }
    
    _dismiss();
  }
} 