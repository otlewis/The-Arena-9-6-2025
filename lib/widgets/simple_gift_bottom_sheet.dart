import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../services/gift_service.dart';
import '../services/coin_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'real_time_coin_balance.dart';

/// Simple gift bottom sheet that definitely works
class SimpleGiftBottomSheet extends StatefulWidget {
  final UserProfile recipient;

  const SimpleGiftBottomSheet({
    super.key,
    required this.recipient,
  });

  @override
  State<SimpleGiftBottomSheet> createState() => _SimpleGiftBottomSheetState();
}

class _SimpleGiftBottomSheetState extends State<SimpleGiftBottomSheet> {
  final GiftService _giftService = GiftService();
  final CoinService _coinService = CoinService();
  final AppwriteService _appwriteService = AppwriteService();

  Gift? _selectedGift;
  bool _isSending = false;
  final TextEditingController _messageController = TextEditingController();

  // Use all available gifts from GiftConstants
  List<Gift> get _gifts => GiftConstants.allGifts;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        _showError('You must be logged in to send gifts');
        return;
      }

      // Check coin balance
      final balance = await _coinService.getUserCoins(user.$id);
      if (balance < _selectedGift!.cost) {
        _showError('Insufficient coins! You need ${_selectedGift!.cost} coins but only have $balance.');
        return;
      }

      // Send the gift
      await _giftService.sendGift(
        giftId: _selectedGift!.id,
        receiverId: widget.recipient.id,
        receiverName: widget.recipient.displayName,
        message: _messageController.text.trim(),
      );

      // Deduct coins from sender's balance
      await _coinService.deductCoins(user.$id, _selectedGift!.cost);

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
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
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
              const RealTimeCoinBalance(
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                backgroundColor: Colors.transparent,
                showCoinIcon: true,
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
    final categoryGifts = GiftConstants.getGiftsByCategory(category);
    if (categoryGifts.isEmpty) return const SizedBox.shrink();

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

  Color _getTierColor(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return Colors.green;
      case GiftTier.standard:
        return Colors.blue;
      case GiftTier.premium:
        return Colors.purple;
      case GiftTier.legendary:
        return Colors.orange;
    }
  }
}

/// Show the simple gift bottom sheet
void showSimpleGiftBottomSheet(
  BuildContext context, {
  required UserProfile recipient,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SimpleGiftBottomSheet(
      recipient: recipient,
    ),
  );
}