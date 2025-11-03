import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../models/money_tip.dart';
import '../services/stripe_payment_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Bottom sheet for sending real money tips via Stripe
class MoneyTipBottomSheet extends StatefulWidget {
  final UserProfile recipient;
  final String? roomId;
  final RoomType? roomType;

  const MoneyTipBottomSheet({
    super.key,
    required this.recipient,
    this.roomId,
    this.roomType,
  });

  @override
  State<MoneyTipBottomSheet> createState() => _MoneyTipBottomSheetState();
}

class _MoneyTipBottomSheetState extends State<MoneyTipBottomSheet> {
  final StripePaymentService _stripeService = StripePaymentService();
  final AppwriteService _appwriteService = AppwriteService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  double? _selectedAmount;
  bool _isProcessing = false;

  // Quick tip amounts
  final List<double> _quickAmounts = [1, 5, 10, 20, 50, 100];

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendTip() async {
    if (_isProcessing) return;

    final amount = _selectedAmount ?? double.tryParse(_amountController.text);

    if (amount == null || amount < 1) {
      _showError('Please enter an amount of at least \$1');
      return;
    }

    if (amount > 10000) {
      _showError('Maximum tip amount is \$10,000');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      AppLogger().info('💵 Sending \$$amount tip to ${widget.recipient.displayName}');

      final success = await _stripeService.sendMoneyTip(
        recipient: widget.recipient,
        amount: amount,
        message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
        roomId: widget.roomId,
        roomType: widget.roomType,
      );

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ \$$amount tip sent to ${widget.recipient.displayName}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger().error('Failed to send tip: $e');
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
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
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
              const Text(
                '💵 Send Money',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
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
          const SizedBox(height: 24),

          // Quick amount buttons
          const Text(
            'Quick Amount:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts.map((amount) {
              final isSelected = _selectedAmount == amount;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAmount = amount;
                    _amountController.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.grey[700]!,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '\$${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[300],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Custom amount input
          const Text(
            'Or Enter Custom Amount:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.attach_money, color: Colors.white),
              hintText: 'Enter amount',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _selectedAmount = null; // Clear quick selection when typing
              });
            },
          ),

          const SizedBox(height: 16),

          // Optional message
          TextField(
            controller: _messageController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a message (optional)',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const Spacer(),

          // Info text
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Powered by Stripe • Secure payment processing',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _sendTip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Send \$${(_selectedAmount ?? double.tryParse(_amountController.text) ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the money tip bottom sheet
void showMoneyTipBottomSheet(
  BuildContext context, {
  required UserProfile recipient,
  String? roomId,
  RoomType? roomType,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MoneyTipBottomSheet(
      recipient: recipient,
      roomId: roomId,
      roomType: roomType,
    ),
  );
}
