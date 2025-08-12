import 'package:flutter/material.dart';
import 'dart:async';
import '../services/challenge_messaging_service.dart';
import '../widgets/challenge_modal.dart';
import '../core/logging/app_logger.dart';

/// Global challenge bell widget that shows pending challenges anywhere in the app
class ChallengeBell extends StatefulWidget {
  final Color iconColor;
  final double iconSize;
  
  const ChallengeBell({
    super.key,
    this.iconColor = const Color(0xFFFF2400),
    this.iconSize = 20,
  });

  @override
  State<ChallengeBell> createState() => _ChallengeBellState();
}

class _ChallengeBellState extends State<ChallengeBell> with SingleTickerProviderStateMixin {
  final ChallengeMessagingService _challengeService = ChallengeMessagingService();
  StreamSubscription? _challengeSubscription;
  List<ChallengeMessage> _pendingChallenges = [];
  
  // Animation controller for bell shake
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _subscribeToChallenges();
    _loadPendingChallenges();
  }

  void _subscribeToChallenges() {
    // Subscribe to pending challenges stream
    _challengeSubscription = _challengeService.pendingChallenges.listen((challenges) {
      if (mounted) {
        final previousCount = _pendingChallenges.length;
        setState(() {
          _pendingChallenges = challenges.where((c) => c.isPending && !c.isDismissed).toList();
        });
        
        // Animate bell when new challenge arrives
        if (_pendingChallenges.length > previousCount) {
          _animationController.forward().then((_) {
            _animationController.reverse();
          });
        }
        
        AppLogger().info('🔔 Pending challenges updated: ${_pendingChallenges.length}');
      }
    });
  }

  void _loadPendingChallenges() {
    // Get current pending challenges from service
    if (mounted) {
      setState(() {
        _pendingChallenges = _challengeService.currentPendingChallenges.where((c) => c.isPending && !c.isDismissed).toList();
      });
    }
  }

  void _handleBellTap() async {
    AppLogger().info('🔔 Challenge bell tapped - pending challenges: ${_pendingChallenges.length}');
    
    if (_pendingChallenges.isNotEmpty) {
      // Show the most recent challenge
      final latestChallenge = _pendingChallenges.first;
      if (mounted) {
        _showChallengeModal(latestChallenge);
      }
    } else {
      // Show a message if no pending challenges
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pending challenges'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showChallengeModal(ChallengeMessage challenge) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChallengeModal(
        challenge: challenge.toModalFormat(),
        onDismiss: () {
          Navigator.of(context).pop();
          _removeChallengeFromList(challenge.id);
        },
      ),
    );
  }

  void _removeChallengeFromList(String challengeId) {
    if (mounted) {
      setState(() {
        _pendingChallenges.removeWhere((c) => c.id == challengeId);
      });
    }
  }

  @override
  void dispose() {
    _challengeSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _shakeAnimation.value,
          child: GestureDetector(
            onTap: _handleBellTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.bolt, // Bolt icon for challenges
                  color: widget.iconColor,
                  size: widget.iconSize,
                ),
                
                // Challenge count badge
                if (_pendingChallenges.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2400),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _pendingChallenges.length > 99 ? '99+' : _pendingChallenges.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}