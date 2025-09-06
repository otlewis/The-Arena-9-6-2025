import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mock_payment_service.dart';
import '../services/theme_service.dart';
import '../core/logging/app_logger.dart';

/// Mock payment dialog for beta testing
class MockPaymentDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final String price;
  final Function(PaymentResult) onPaymentComplete;
  
  const MockPaymentDialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.price,
    required this.onPaymentComplete,
  });
  
  @override
  State<MockPaymentDialog> createState() => _MockPaymentDialogState();
}

class _MockPaymentDialogState extends State<MockPaymentDialog> {
  final ThemeService _themeService = ThemeService();
  final MockPaymentService _paymentService = MockPaymentService();
  
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _zipController = TextEditingController();
  
  bool _isProcessing = false;
  CardType _cardType = CardType.unknown;
  
  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  
  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_updateCardType);
  }
  
  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _zipController.dispose();
    super.dispose();
  }
  
  void _updateCardType() {
    setState(() {
      _cardType = _paymentService.getCardType(_cardNumberController.text);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 24,
      ),
      child: Container(
        width: screenWidth * (isSmallScreen ? 0.95 : 0.9),
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? 360 : 500,
        ),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF2D2D2D)
              : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scarletRed.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Beta Test Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.science, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'BETA TEST MODE - No real charges will occur',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  
                  // Title
                  Text(
                    'Complete Purchase',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: _themeService.isDarkMode ? Colors.white : deepPurple,
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  
                  // Product details
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    decoration: BoxDecoration(
                      color: _themeService.isDarkMode 
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFF0F0F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            widget.productName,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.price,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: accentPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  
                  // Test cards info
                  ExpansionTile(
                    title: const Text(
                      'View Test Card Numbers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTestCard('4242 4242 4242 4242', 'Success'),
                            _buildTestCard('4000 0000 0000 0002', 'Declined'),
                            _buildTestCard('4000 0000 0000 9995', 'Insufficient Funds'),
                            _buildTestCard('5555 5555 5555 4444', 'Success (Mastercard)'),
                            const SizedBox(height: 8),
                            Text(
                              'Use any future expiry, any 3-digit CVC',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  
                  // Card number field
                  _buildTextField(
                    controller: _cardNumberController,
                    label: 'Card Number',
                    hint: '4242 4242 4242 4242',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CardNumberFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card number';
                      }
                      if (value.replaceAll(' ', '').length < 13) {
                        return 'Invalid card number';
                      }
                      return null;
                    },
                    suffixIcon: _getCardIcon(),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Expiry and CVC row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _expiryController,
                          label: 'Expiry Date',
                          hint: 'MM/YY',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _ExpiryDateFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (!value.contains('/') || value.length < 5) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _cvcController,
                          label: 'CVC',
                          hint: '123',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (value.length < 3) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Cardholder name
                  _buildTextField(
                    controller: _nameController,
                    label: 'Cardholder Name',
                    hint: 'John Doe',
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter cardholder name';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Email (optional)
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email (optional)',
                    hint: 'john@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildButton(
                          text: 'Cancel',
                          color: Colors.grey,
                          onPressed: _isProcessing ? null : () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 16),
                      Expanded(
                        child: _buildButton(
                          text: _isProcessing 
                              ? 'Processing...' 
                              : (isSmallScreen ? 'Pay' : 'Pay ${widget.price}'),
                          color: accentPurple,
                          onPressed: _isProcessing ? null : _processPayment,
                          isLoading: _isProcessing,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Security badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Secure Beta Test Payment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTestCard(String number, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: description.contains('Success') ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: textCapitalization,
      style: TextStyle(
        color: _themeService.isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
        ),
        hintStyle: TextStyle(
          color: _themeService.isDarkMode ? Colors.white38 : Colors.black38,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _themeService.isDarkMode 
                ? Colors.white24 
                : Colors.black26,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: accentPurple,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
      ),
    );
  }
  
  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 12 : 16,
          horizontal: isSmallScreen ? 8 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: isLoading 
          ? SizedBox(
              height: isSmallScreen ? 16 : 20,
              width: isSmallScreen ? 16 : 20,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              text,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
  
  Widget? _getCardIcon() {
    IconData iconData;
    Color color;
    
    switch (_cardType) {
      case CardType.visa:
        iconData = Icons.credit_card;
        color = Colors.blue;
        break;
      case CardType.mastercard:
        iconData = Icons.credit_card;
        color = Colors.orange;
        break;
      case CardType.amex:
        iconData = Icons.credit_card;
        color = Colors.green;
        break;
      case CardType.discover:
        iconData = Icons.credit_card;
        color = Colors.purple;
        break;
      default:
        iconData = Icons.credit_card;
        color = Colors.grey;
    }
    
    return Icon(iconData, color: color);
  }
  
  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      // Parse expiry date
      final expiry = _expiryController.text.split('/');
      final expiryMonth = expiry[0];
      final expiryYear = expiry.length > 1 ? expiry[1] : '';
      
      // Process mock payment
      final result = await _paymentService.processMockPayment(
        productId: widget.productId,
        cardNumber: _cardNumberController.text,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvc: _cvcController.text,
        cardholderName: _nameController.text,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        zipCode: _zipController.text.isNotEmpty ? _zipController.text : null,
      );
      
      // Close dialog and return result
      if (mounted) {
        Navigator.of(context).pop();
        widget.onPaymentComplete(result);
      }
      
    } catch (e) {
      AppLogger().warning('Payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

/// Card number formatter
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
      if (i >= 18) break; // Max 19 digits
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Expiry date formatter
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length && i < 4; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}