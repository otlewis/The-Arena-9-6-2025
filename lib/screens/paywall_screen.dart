import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenue_cat_service.dart';
import '../services/feature_flag_service.dart';
import '../core/logging/app_logger.dart';
import '../widgets/user_avatar.dart';
import '../services/appwrite_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatefulWidget {
  final String? userId;
  final VoidCallback? onPurchaseSuccess;
  final VoidCallback? onDismiss;

  const PaywallScreen({
    super.key,
    this.userId,
    this.onPurchaseSuccess,
    this.onDismiss,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final RevenueCatService _revenueCatService = RevenueCatService();
  final FeatureFlagService _featureFlagService = FeatureFlagService();
  final AppwriteService _appwriteService = AppwriteService();
  
  List<StoreProduct> _products = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _errorMessage = '';
  bool _paymentsEnabled = false;

  // App colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color backgroundWhite = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _initializePaywall();
  }

  Future<void> _initializePaywall() async {
    try {
      setState(() => _isLoading = true);

      // Check if payments are enabled via feature flag
      _paymentsEnabled = await _featureFlagService.isPaymentsEnabled();
      
      if (!_paymentsEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Payments are temporarily unavailable. Please try again later.';
        });
        return;
      }

      // Initialize RevenueCat if not already done
      await _revenueCatService.initialize();

      // Set user ID if available
      if (widget.userId != null) {
        await _revenueCatService.setUserId(widget.userId!);
      }

      // Load products
      final products = await _revenueCatService.getProducts();
      
      setState(() {
        _products = products;
        _isLoading = false;
      });

      // Set up purchase callbacks
      _revenueCatService.onPurchaseSuccess = (productId, customerInfo) {
        AppLogger().info('🎉 Purchase successful in paywall: $productId');
        if (mounted) {
          _showSuccessMessage();
          widget.onPurchaseSuccess?.call();
        }
      };

      _revenueCatService.onPurchaseError = (error, userCancelled) {
        if (mounted && !userCancelled) {
          setState(() {
            _errorMessage = 'Purchase failed: $error';
            _isProcessing = false;
          });
        }
      };

      _revenueCatService.onProcessingStateChanged = (processing) {
        if (mounted) {
          setState(() => _isProcessing = processing);
        }
      };

    } catch (e) {
      AppLogger().error('Failed to initialize paywall: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load payment options. Please try again.';
        });
      }
    }
  }

  void _showSuccessMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Welcome to Arena Pro!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎉 Your subscription is now active!'),
            SizedBox(height: 8),
            Text('You now have access to:'),
            SizedBox(height: 8),
            Text('• Unlimited challenges'),
            Text('• Premium badge'),
            Text('• Priority support'),
            Text('• 1,000 bonus coins'),
            SizedBox(height: 8),
            Text('Enjoy your premium experience!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close paywall
            },
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseProduct(StoreProduct product) async {
    if (!_paymentsEnabled) {
      _showErrorSnackBar('Payments are currently disabled.');
      return;
    }

    try {
      setState(() {
        _errorMessage = '';
        _isProcessing = true;
      });

      final success = await _revenueCatService.purchaseSubscription(product.identifier);
      
      if (!success) {
        setState(() => _isProcessing = false);
      }
      
    } catch (e) {
      AppLogger().error('Purchase failed: $e');
      setState(() {
        _errorMessage = 'Purchase failed. Please try again.';
        _isProcessing = false;
      });
    }
  }

  Future<void> _restorePurchases() async {
    try {
      setState(() {
        _errorMessage = '';
        _isProcessing = true;
      });

      final success = await _revenueCatService.restorePurchases();
      
      if (success) {
        _showSuccessSnackBar('Purchases restored successfully!');
        widget.onPurchaseSuccess?.call();
      } else {
        _showErrorSnackBar('No purchases found to restore.');
      }
      
    } catch (e) {
      AppLogger().error('Restore failed: $e');
      _showErrorSnackBar('Failed to restore purchases. Please try again.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackBar('Could not open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        title: const Text('Arena Pro'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        titleTextStyle: const TextStyle(
          color: deepPurple,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          if (widget.onDismiss != null)
            TextButton(
              onPressed: widget.onDismiss,
              child: const Text('Maybe Later'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentPurple))
          : !_paymentsEnabled
              ? _buildPaymentsDisabledView()
              : _products.isEmpty
                  ? _buildNoProductsView()
                  : _buildPaywallContent(),
    );
  }

  Widget _buildPaymentsDisabledView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Payments Temporarily Unavailable',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We\'re working on improvements to our payment system. Please check back soon!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProductsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              _errorMessage.isEmpty ? 'No products available' : _errorMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePaywall,
              style: ElevatedButton.styleFrom(backgroundColor: accentPurple),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaywallContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildFeaturesList(),
          const SizedBox(height: 32),
          _buildPricingCards(),
          const SizedBox(height: 24),
          _buildRestoreButton(),
          const SizedBox(height: 24),
          _buildLegalFooter(),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.workspace_premium, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Upgrade to Arena Pro',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: deepPurple,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock the full power of The Arena',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.flash_on, 'title': 'Unlimited Challenges', 'desc': 'Challenge any premium user'},
      {'icon': Icons.workspace_premium, 'title': 'Premium Badge', 'desc': 'Show your exclusive status'},
      {'icon': Icons.priority_high, 'title': 'Priority Support', 'desc': 'Get help when you need it'},
      {'icon': Icons.monetization_on, 'title': 'Bonus Coins', 'desc': '1,000 coins to get started'},
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentPurple.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: features.map((feature) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(feature['icon'] as IconData, color: accentPurple),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: deepPurple,
                        ),
                      ),
                      Text(
                        feature['desc'] as String,
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
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildPricingCards() {
    // Sort products: yearly first, then monthly
    final sortedProducts = List<StoreProduct>.from(_products)
      ..sort((a, b) {
        if (a.identifier.contains('yearly')) return -1;
        if (b.identifier.contains('yearly')) return 1;
        return 0;
      });

    return Column(
      children: sortedProducts.map((product) => _buildPricingCard(product)).toList(),
    );
  }

  Widget _buildPricingCard(StoreProduct product) {
    final isYearly = product.identifier.contains('yearly');
    final isPopular = isYearly;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Card(
            elevation: isPopular ? 8 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isPopular ? Colors.amber : accentPurple.withOpacity(0.2),
                width: isPopular ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    isYearly ? 'Annual Plan' : 'Monthly Plan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isPopular ? Colors.amber[700] : deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.priceString,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: deepPurple,
                    ),
                  ),
                  if (isYearly) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Save 2 months!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _purchaseProduct(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPopular ? Colors.amber : accentPurple,
                        foregroundColor: isPopular ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Start ${isYearly ? 'Annual' : 'Monthly'} Plan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isPopular)
            Positioned(
              top: 0,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: _isProcessing ? null : _restorePurchases,
      child: const Text(
        'Restore Purchases',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: deepPurple,
        ),
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Column(
      children: [
        const Text(
          'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: () => _launchUrl('https://arena-app.com/terms'),
              child: const Text(
                'Terms of Service',
                style: TextStyle(fontSize: 12, color: deepPurple),
              ),
            ),
            TextButton(
              onPressed: () => _launchUrl('https://arena-app.com/privacy'),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 12, color: deepPurple),
              ),
            ),
          ],
        ),
      ],
    );
  }
}