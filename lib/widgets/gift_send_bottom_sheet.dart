import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../models/user_profile.dart';
import '../services/gift_service.dart';
import '../services/coin_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'real_time_coin_balance.dart';

/// Bottom sheet for sending gifts to other users
class GiftSendBottomSheet extends StatefulWidget {
  final UserProfile recipient;
  final String? roomId;
  final String? roomType;
  final String? roomName;

  const GiftSendBottomSheet({
    super.key,
    required this.recipient,
    this.roomId,
    this.roomType,
    this.roomName,
  });

  @override
  State<GiftSendBottomSheet> createState() => _GiftSendBottomSheetState();
}

class _GiftSendBottomSheetState extends State<GiftSendBottomSheet> with TickerProviderStateMixin {
  final GiftService _giftService = GiftService();
  final CoinService _coinService = CoinService();
  final AppwriteService _appwriteService = AppwriteService();
  
  int _userCoinBalance = 0;
  bool _sending = false;
  Gift? _selectedGift;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserCoinBalance();
    
    // Initialize pulse animation for selected gift
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadUserCoinBalance() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        final coins = await _coinService.getUserCoins(user.$id);
        if (mounted) {
          setState(() {
            _userCoinBalance = coins;
          });
        }
        
        // Subscribe to balance updates
        _subscribeToBalanceUpdates(user.$id);
      }
    } catch (e) {
      AppLogger().error('Error loading coin balance: $e');
    }
  }
  
  void _subscribeToBalanceUpdates(String userId) {
    try {
      // Subscribe to updates on the user's document
      final subscription = _appwriteService.realtime.subscribe([
        'databases.arena_db.collections.users.documents.$userId'
      ]);
      
      subscription.stream.listen((event) {
        if (event.events.contains('databases.arena_db.collections.users.documents.$userId.update')) {
          // Balance was updated, reload it
          _reloadBalance(userId);
        }
      });
    } catch (e) {
      AppLogger().error('Failed to subscribe to balance updates: $e');
    }
  }
  
  Future<void> _reloadBalance(String userId) async {
    try {
      final coins = await _coinService.getUserCoins(userId);
      if (mounted) {
        setState(() {
          _userCoinBalance = coins;
        });
      }
    } catch (e) {
      AppLogger().error('Error reloading coin balance: $e');
    }
  }

  void _selectGift(Gift gift) {
    setState(() {
      _selectedGift = gift;
    });
    
    // Start pulse animation
    _pulseController.repeat(reverse: true);
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;
    
    setState(() {
      _sending = true;
    });

    try {
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get latest coin balance before sending
      final currentBalance = await _coinService.getUserCoins(user.$id);
      
      // Check if user has enough coins
      if (currentBalance < _selectedGift!.cost) {
        _showInsufficientCoinsDialog(currentBalance);
        return;
      }

      final success = await _giftService.sendGift(
        giftId: _selectedGift!.id,
        receiverId: widget.recipient.id,
        receiverName: widget.recipient.name,
        message: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
        roomId: widget.roomId,
        roomType: widget.roomType,
        roomName: widget.roomName,
      );

      if (success) {
        // Real-time widget will automatically update the balance
        
        // Show success message and close
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(_selectedGift!.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gift sent to ${widget.recipient.name}!',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF8B5CF6),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showErrorDialog('Failed to send gift. Please try again.');
      }
    } catch (e) {
      AppLogger().error('Error sending gift: $e');
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _showInsufficientCoinsDialog(int currentBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Coins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'You need ${_selectedGift!.cost} coins to send this gift, but you only have $currentBalance coins.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Purchase more coins or earn them by participating in debates!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBalanceHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            const Color(0xFF6B46C1).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monetization_on,
            color: Colors.amber,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text(
            'Your Balance:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const RealTimeCoinBalance(
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.transparent,
            showCoinIcon: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge(UserProfile user) {
    // Check if user is premium and determine badge type
    if (!user.isPremium) return const SizedBox.shrink();

    final isYearly = user.premiumType == 'yearly';
    final badgeColor = isYearly ? Colors.amber : Colors.grey[400]!;
    final badgeText = isYearly ? 'GOLD' : 'SILVER';
    final icon = Icons.shield;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.black,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: widget.recipient.avatar?.isNotEmpty == true
              ? NetworkImage(widget.recipient.avatar!)
              : null,
          backgroundColor: const Color(0xFF8B5CF6),
          child: widget.recipient.avatar?.isNotEmpty != true
              ? Text(
                  widget.recipient.name.isNotEmpty ? widget.recipient.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.recipient.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPremiumBadge(widget.recipient),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Send a gift to show appreciation',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGiftGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Gift',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: GiftConstants.allGifts.length,
          itemBuilder: (context, index) {
            final gift = GiftConstants.allGifts[index];
            final isSelected = _selectedGift?.id == gift.id;
            final canAfford = _userCoinBalance >= gift.cost;

            return AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = isSelected ? _pulseAnimation.value : 1.0;
                
                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: canAfford ? () => _selectGift(gift) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                            : canAfford
                                ? Colors.grey.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8B5CF6)
                              : canAfford
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : Colors.red.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            gift.emoji,
                            style: TextStyle(
                              fontSize: 24,
                              color: canAfford ? null : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${gift.cost}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: canAfford ? const Color(0xFF8B5CF6) : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add a Message (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLength: 100,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Write a nice message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedGiftInfo() {
    if (_selectedGift == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            _selectedGift!.emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedGift!.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _selectedGift!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedGift!.cost} coins',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Coin balance
          _buildCoinBalanceHeader(),
          const SizedBox(height: 16),

          // Recipient info
          _buildRecipientHeader(),
          const SizedBox(height: 20),

          // Selected gift info
          _buildSelectedGiftInfo(),
          if (_selectedGift != null) const SizedBox(height: 16),

          // Gift grid
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildGiftGrid(),
                  const SizedBox(height: 20),
                  _buildMessageInput(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedGift != null && !_sending ? _sendGift : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _selectedGift != null
                          ? 'Send ${_selectedGift!.name}'
                          : 'Choose a Gift',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Show gift sending bottom sheet
void showGiftSendBottomSheet(
  BuildContext context, {
  required UserProfile recipient,
  String? roomId,
  String? roomType,
  String? roomName,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => GiftSendBottomSheet(
        recipient: recipient,
        roomId: roomId,
        roomType: roomType,
        roomName: roomName,
      ),
    ),
  );
}