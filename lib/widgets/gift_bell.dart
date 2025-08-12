import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/gift_service.dart';
import '../models/received_gift.dart';
import '../core/logging/app_logger.dart';

/// Global gift bell widget that shows new gifts anywhere in the app
class GiftBell extends StatefulWidget {
  final Color iconColor;
  final double iconSize;
  
  const GiftBell({
    super.key,
    this.iconColor = const Color(0xFF8B5CF6),
    this.iconSize = 20,
  });

  @override
  State<GiftBell> createState() => _GiftBellState();
}

class _GiftBellState extends State<GiftBell> with TickerProviderStateMixin {
  final GiftService _giftService = GiftService();
  StreamSubscription? _newGiftSubscription;
  int _unreadGiftCount = 0;
  
  // Animation controller for bell shake
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  // Animation controller for gift particles
  late AnimationController _particleController;
  late Animation<double> _particleAnimation;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize shake animation
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.15,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));
    
    // Initialize particle animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    ));
    
    _subscribeToNewGifts();
    _loadUnreadCount();
  }

  void _subscribeToNewGifts() {
    // Subscribe to new gifts stream
    _newGiftSubscription = _giftService.newGiftStream.listen((newGift) {
      if (mounted) {
        _loadUnreadCount();
        
        // Animate bell when new gift arrives
        _animateNewGift(newGift);
        
        // Show snackbar notification
        _showNewGiftNotification(newGift);
        
        AppLogger().info('🎁 New gift received: ${newGift.giftId} from ${newGift.senderName}');
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _giftService.getUnreadGiftCount();
      if (mounted) {
        setState(() {
          _unreadGiftCount = count;
        });
      }
    } catch (e) {
      AppLogger().error('Error loading unread gift count: $e');
    }
  }

  void _animateNewGift(ReceivedGift gift) {
    // Start shake animation
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
    
    // Start particle animation
    setState(() => _showParticles = true);
    _particleController.forward().then((_) {
      _particleController.reset();
      if (mounted) {
        setState(() => _showParticles = false);
      }
    });
  }

  void _showNewGiftNotification(ReceivedGift gift) {
    final giftDetails = gift.giftDetails;
    if (giftDetails == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              giftDetails.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Gift from ${gift.senderName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${giftDetails.name} ${gift.contextText}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => _showGiftDetails(gift),
        ),
      ),
    );
  }

  void _handleBellTap() async {
    AppLogger().info('🎁 Gift bell tapped - unread gifts: $_unreadGiftCount');
    
    if (_unreadGiftCount > 0) {
      // Show gifts modal
      _showGiftsModal();
    } else {
      // Show message if no new gifts
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No new gifts'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showGiftsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent Gifts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B46C1),
                    ),
                  ),
                  const Spacer(),
                  if (_unreadGiftCount > 0)
                    TextButton(
                      onPressed: () async {
                        await _giftService.markAllGiftsAsRead();
                        _loadUnreadCount();
                      },
                      child: const Text('Mark All Read'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Gift list
              Expanded(
                child: StreamBuilder<List<ReceivedGift>>(
                  stream: _giftService.receivedGiftsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8B5CF6),
                        ),
                      );
                    }
                    
                    final gifts = snapshot.data ?? [];
                    
                    if (gifts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.card_giftcard_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No gifts received yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: gifts.length,
                      itemBuilder: (context, index) => _buildGiftTile(gifts[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftTile(ReceivedGift gift) {
    final giftDetails = gift.giftDetails;
    if (giftDetails == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gift.isRead ? Colors.grey.withValues(alpha: 0.05) : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gift.isRead ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Gift emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                giftDetails.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Gift details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      giftDetails.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${giftDetails.cost} coins)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'From ${gift.senderName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (gift.message != null && gift.message!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '"${gift.message}"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${gift.timeAgoText} ${gift.contextText}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          
          // Unread indicator
          if (!gift.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF8B5CF6),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  void _showGiftDetails(ReceivedGift gift) {
    // Implementation for showing detailed gift modal
    // This could be expanded to show more details, sender profile, etc.
  }

  @override
  void dispose() {
    _newGiftSubscription?.cancel();
    _shakeController.dispose();
    _particleController.dispose();
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
                  Icons.card_giftcard,
                  color: widget.iconColor,
                  size: widget.iconSize,
                ),
                
                // Gift particles animation
                if (_showParticles)
                  AnimatedBuilder(
                    animation: _particleAnimation,
                    builder: (context, child) => Positioned.fill(
                      child: CustomPaint(
                        painter: GiftParticlesPainter(_particleAnimation.value),
                      ),
                    ),
                  ),
                
                // Unread gift count badge
                if (_unreadGiftCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
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
                        _unreadGiftCount > 99 ? '99+' : _unreadGiftCount.toString(),
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

/// Custom painter for gift particle effects
class GiftParticlesPainter extends CustomPainter {
  final double progress;
  
  GiftParticlesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.fill;

    // Draw small sparkle particles
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.6 * progress;
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      canvas.drawCircle(
        Offset(x, y),
        2.0 * (1.0 - progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}