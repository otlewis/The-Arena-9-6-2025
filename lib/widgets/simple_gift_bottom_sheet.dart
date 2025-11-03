import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../models/money_tip.dart';
import '../services/gift_service.dart';
import '../services/firebase_coin_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'real_time_coin_balance.dart';
import 'money_tip_bottom_sheet.dart';

/// Simple gift bottom sheet that definitely works
class SimpleGiftBottomSheet extends StatefulWidget {
  final UserProfile recipient;
  final String? roomId;
  final Function(String emoji, String giftName, int giftValue, String senderName)? onGiftSent;

  const SimpleGiftBottomSheet({
    super.key,
    required this.recipient,
    this.roomId,
    this.onGiftSent,
  });

  @override
  State<SimpleGiftBottomSheet> createState() => _SimpleGiftBottomSheetState();
}

class _SimpleGiftBottomSheetState extends State<SimpleGiftBottomSheet> {
  final GiftService _giftService = GiftService();
  final FirebaseCoinService _firebaseCoinService = FirebaseCoinService();
  final AppwriteService _appwriteService = AppwriteService();

  Gift? _selectedGift;
  final TextEditingController _messageController = TextEditingController();
  RealTimeCoinBalanceController? _coinBalanceController;


  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Determine room type from context
  RoomType? _getRoomType() {
    // You can determine this based on the room type passed from parent
    // For now, return null and let the money tip sheet handle it
    // You can pass roomType as a parameter to SimpleGiftBottomSheet if needed
    return null;
  }

  Future<void> _sendGift() async {
    AppLogger().info('🎁 🎁 🎁 SEND GIFT BUTTON TAPPED! 🎁 🎁 🎁');

    if (_selectedGift == null) {
      AppLogger().warning('⚠️ No gift selected!');
      return;
    }

    AppLogger().info('🎁 Selected gift: ${_selectedGift!.name} (${_selectedGift!.cost} coins)');

    try {
      // Get current user
      AppLogger().debug('🎁 Getting current user...');
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        AppLogger().error('❌ User not logged in!');
        _showError('You must be logged in to send gifts');
        return;
      }
      AppLogger().debug('🎁 Current user: ${user.$id}');

      // Check coin balance from Firebase
      final balance = await _firebaseCoinService.getUserCoins(user.$id);
      if (balance < _selectedGift!.cost) {
        _showError('Insufficient coins! You need ${_selectedGift!.cost} coins but only have $balance.');
        return;
      }

      // STEP 1: OPTIMISTICALLY deduct coins from UI FIRST (before anything else)
      if (_coinBalanceController != null) {
        _coinBalanceController!.optimisticallyDeduct(_selectedGift!.cost);
        AppLogger().debug('💰 Step 1: Optimistically deducted ${_selectedGift!.cost} coins from UI');
      }

      // STEP 2: Deduct coins from Firebase IMMEDIATELY (atomic transaction)
      bool coinDeductionSuccess = false;
      try {
        AppLogger().debug('💰 Step 2: Attempting to deduct ${_selectedGift!.cost} coins from user ${user.$id} via Firebase transaction...');
        coinDeductionSuccess = await _firebaseCoinService.deductCoins(user.$id, _selectedGift!.cost);
        if (coinDeductionSuccess) {
          AppLogger().info('✅ Step 2: Successfully deducted ${_selectedGift!.cost} coins via Firebase!');
        } else {
          AppLogger().error('❌ Step 2: Firebase coin deduction failed - insufficient balance');
          _showError('Failed to deduct coins. Please try again.');
          return; // Don't send gift if coins couldn't be deducted
        }
      } catch (e) {
        AppLogger().error('❌ Step 2: Coin deduction error: $e');
        _showError('Failed to deduct coins: $e');
        return; // Don't send gift if coins couldn't be deducted
      }

      // STEP 3: Now send the gift (only after coins are successfully deducted)
      if (widget.onGiftSent != null && widget.roomId != null) {
        try {
          AppLogger().debug('🎁 Step 3: Getting current user profile for gift visual...');
          final currentUserProfile = await _appwriteService.getUserProfile(user.$id);
          AppLogger().debug('🎁 Step 3: Calling onGiftSent callback to broadcast gift...');
          widget.onGiftSent!(
            _selectedGift!.emoji,
            _selectedGift!.name,
            _selectedGift!.cost,
            currentUserProfile?.displayName ?? 'Someone',
          );
          AppLogger().info('✅ Step 3: Gift broadcast sent via callback!');
        } catch (e) {
          AppLogger().error('❌ Step 3: Failed to broadcast gift visual: $e');
        }
      } else {
        // No callback - this is a profile gift (not in-room), use Firebase
        try {
          AppLogger().info('📬 Step 3: Sending gift via Firebase (profile gift)...');
          await _giftService.sendGift(
            giftId: _selectedGift!.id,
            receiverId: widget.recipient.id,
            receiverName: widget.recipient.displayName,
            message: _messageController.text.trim(),
          );
          AppLogger().info('✅ Step 3: Firebase gift sent!');
        } catch (e) {
          AppLogger().error('❌ Step 3: Firebase gift send failed: $e');
          _showError('Failed to send gift: $e');
          return;
        }
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${_selectedGift!.emoji} ${_selectedGift!.name} sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      AppLogger().error('Failed to send gift: $e');
      _showError('Failed to send gift: $e');
    } finally {
      // Gift sending completed
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Send Gift',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              RealTimeCoinBalance(
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                backgroundColor: Colors.transparent,
                showCoinIcon: true,
                onControllerCreated: (controller) {
                  _coinBalanceController = controller;
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'To: ${widget.recipient.displayName}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),

          // Tip the Speaker Button - styled like coin icon
          GestureDetector(
            onTap: () {
              // Close current bottom sheet
              Navigator.pop(context);
              // Open money tip bottom sheet
              showMoneyTipBottomSheet(
                context,
                recipient: widget.recipient,
                roomId: widget.roomId,
                roomType: _getRoomType(),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Scarlet outline circle with purple dollar sign
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color(0xFFDC143C), // Scarlet outline
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFDC143C).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '\$',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6), // Purple color
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Tip the Speaker',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Selected gift display
          if (_selectedGift != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedGift!.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedGift!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _selectedGift!.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on, size: 16),
                        Text(
                          '${_selectedGift!.cost}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Gift categories
          Text(
            'Choose a Gift:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Build sections for each category
                  ...GiftCategory.values.map((category) => _buildGiftCategorySection(category)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGiftCategorySection(GiftCategory category) {
    // Skip money category - it has its own button now
    if (category == GiftCategory.money) {
      return const SizedBox.shrink();
    }

    final categoryGifts = GiftConstants.getGiftsByCategory(category);
    if (categoryGifts.isEmpty) return const SizedBox.shrink();

    // Category title
    String categoryTitle = category.name.split('').map((char) =>
      char == category.name[0] ? char.toUpperCase() : char
    ).join('').replaceAll('_', ' ');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            categoryTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: categoryGifts.length,
          itemBuilder: (context, index) {
            final gift = categoryGifts[index];
            final isSelected = _selectedGift?.id == gift.id;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGift = gift;
                });
              },
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        Text(
                          gift.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          gift.name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monetization_on, size: 10, color: Colors.black),
                              Text(
                                '${gift.cost}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                  // Selection highlight border
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  // TikTok-style send button that appears when selected
                  if (isSelected)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _sendGift(),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              'Send',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

}

/// Show the simple gift bottom sheet
void showSimpleGiftBottomSheet(
  BuildContext context, {
  required UserProfile recipient,
  String? roomId,
  Function(String emoji, String giftName, int giftValue, String senderName)? onGiftSent,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SimpleGiftBottomSheet(
      recipient: recipient,
      roomId: roomId,
      onGiftSent: onGiftSent,
    ),
  );
}