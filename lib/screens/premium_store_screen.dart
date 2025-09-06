import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenue_cat_service.dart';
import '../services/coin_service.dart';
import '../services/feature_flag_service.dart';
import '../core/logging/app_logger.dart';
import '../widgets/premium_badge.dart';
import '../services/appwrite_service.dart';
import '../widgets/real_time_coin_balance.dart';
import 'paywall_screen.dart';

/// Premium store screen powered by RevenueCat
class PremiumStoreScreen extends StatefulWidget {
  const PremiumStoreScreen({super.key});

  @override
  State<PremiumStoreScreen> createState() => _PremiumStoreScreenState();
}

class _PremiumStoreScreenState extends State<PremiumStoreScreen> {
  final RevenueCatService _revenueCatService = GetIt.instance<RevenueCatService>();
  final FeatureFlagService _featureFlagService = FeatureFlagService();
  AppwriteService? _appwriteService;
  final CoinService _coinService = CoinService();
  
  List<StoreProduct> _products = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupRevenueCatCallbacks();
  }

  void _initializeServices() async {
    try {
      // Wait for AppwriteService to be ready (it's registered as async singleton)
      await GetIt.instance.isReady<AppwriteService>();
      _appwriteService = GetIt.instance<AppwriteService>();
      AppLogger().debug('✅ AppwriteService ready for Premium Store');
    } catch (e) {
      AppLogger().error('AppwriteService initialization failed: $e');
    }
    _initializeStore();
  }

  void _setupRevenueCatCallbacks() {
    _revenueCatService.onPurchaseSuccess = (productId, customerInfo) {
      AppLogger().info('✅ Purchase successful: $productId');
      _loadCustomerInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Purchase successful! Welcome to Premium!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };
    
    _revenueCatService.onPurchaseError = (error, userCancelled) {
      AppLogger().warning('❌ Purchase failed: $error');
      
      if (mounted && !userCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Purchase failed: ${error}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };
    
    _revenueCatService.onProcessingStateChanged = (processing) {
      if (mounted) {
        setState(() {
          _isProcessing = processing;
        });
      }
    };
  }

  Future<void> _initializeStore() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Ensure RevenueCat is initialized
      if (!_revenueCatService.isInitialized) {
        final initialized = await _revenueCatService.initialize();
        if (!initialized) {
          throw Exception('RevenueCat failed to initialize');
        }
      }

      // Set user ID if authenticated (with error handling)
      try {
        if (_appwriteService != null) {
          final user = await _appwriteService!.getCurrentUser();
          if (user != null) {
            await _revenueCatService.setUserId(user.$id);
          }
        }
      } catch (e) {
        AppLogger().warning('Could not get current user for RevenueCat: $e');
        // Continue without user ID - RevenueCat can still work
      }

      // Load products and customer info
      await Future.wait([
        _loadProducts(),
        _loadCustomerInfo(),
      ]);

    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      AppLogger().error('Failed to initialize store: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    final products = await _revenueCatService.getProducts();
    setState(() {
      _products = products;
    });
  }

  Future<void> _loadCustomerInfo() async {
    final customerInfo = await _revenueCatService.getCustomerInfo();
    setState(() {
      _customerInfo = customerInfo;
    });
  }

  Future<void> _purchaseProduct(StoreProduct product) async {
    try {
      // Check if user is authenticated
      if (_appwriteService == null) {
        // Wait for AppwriteService to be ready
        try {
          await GetIt.instance.isReady<AppwriteService>();
          _appwriteService = GetIt.instance<AppwriteService>();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to connect to services. Please check your internet connection.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      final user = await _appwriteService!.getCurrentUser();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to make purchases'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      bool success = false;
      
      if (product.identifier.contains('coins')) {
        success = await _revenueCatService.purchaseCoins(product.identifier);
      } else {
        success = await _revenueCatService.purchaseSubscription(product.identifier);
      }

      if (success) {
        await _loadCustomerInfo();
      }

    } catch (e) {
      AppLogger().error('Purchase error: $e');
    }
  }

  Future<void> _restorePurchases() async {
    final success = await _revenueCatService.restorePurchases();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? '✅ Purchases restored successfully' 
            : '❌ Failed to restore purchases'
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      
      if (success) {
        await _loadCustomerInfo();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Premium Store'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            SizedBox(height: 16),
            Text('Loading store...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              'Store not available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPremiumStatus(),
          const SizedBox(height: 24),
          _buildSubscriptionSection(),
          const SizedBox(height: 24),
          _buildCoinsSection(),
          const SizedBox(height: 24),
          _buildFeaturesList(),
        ],
      ),
    );
  }

  Widget _buildPremiumStatus() {
    final hasPremium = _customerInfo?.entitlements.active.containsKey(RevenueCatService.premiumEntitlement) ?? false;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasPremium
            ? [Colors.amber.shade200, Colors.amber.shade400]
            : [Color(0xFF8B5CF6).withValues(alpha: 0.1), Color(0xFF6B46C1).withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPremium ? Colors.amber : const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            hasPremium ? Icons.shield : Icons.workspace_premium,
            size: 48,
            color: hasPremium ? Colors.black : const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          Text(
            hasPremium ? 'Premium Active' : 'Get Premium',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: hasPremium ? Colors.black : const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPremium 
              ? 'You have access to all premium features!'
              : 'Unlock exclusive features and support Arena',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: hasPremium ? Colors.black87 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Check if user has any premium subscription
  bool get _hasPremium {
    return _customerInfo?.entitlements.active.containsKey(RevenueCatService.premiumEntitlement) ?? false;
  }

  /// Check if user has a specific subscription type
  bool _hasSubscription(String productId) {
    if (_customerInfo == null) return false;
    
    final entitlements = _customerInfo!.entitlements.active;
    final premiumEntitlement = entitlements[RevenueCatService.premiumEntitlement];
    
    if (premiumEntitlement == null) return false;
    
    return premiumEntitlement.productIdentifier == productId;
  }

  Widget _buildSubscriptionSection() {
    final subscriptionProducts = _products.where((p) => 
      p.identifier.contains('monthly') || p.identifier.contains('yearly')
    ).toList();

    // Show mock products for testing when no real products are available
    if (subscriptionProducts.isEmpty) {
      return _buildMockSubscriptionSection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Subscriptions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...subscriptionProducts.map((product) => _buildSubscriptionCard(product)),
      ],
    );
  }

  Widget _buildSubscriptionCard(StoreProduct product) {
    final isYearly = product.identifier.contains('yearly');
    final badgeColor = isYearly ? Colors.amber : Colors.grey[400]!;
    final badgeText = isYearly ? 'GOLD' : 'SILVER';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isYearly ? Colors.amber.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
          width: isYearly ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with badge and title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, color: Colors.black, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isYearly)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Save 17%',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              isYearly ? 'Arena Pro Yearly' : 'Arena Pro Monthly',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              'Premium debates with unlimited features',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Price and button row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.priceString,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    Text(
                      isYearly ? 'per year' : 'per month',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 48,
                  width: 140,
                  child: ElevatedButton(
                    onPressed: _isProcessing || _hasSubscription(product.identifier) 
                      ? null 
                      : () => _purchaseProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasSubscription(product.identifier)
                        ? Colors.grey[400]
                        : const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: _hasSubscription(product.identifier) ? 0 : 4,
                      shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isProcessing 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _hasSubscription(product.identifier) ? 'Active' : 'Subscribe',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinsSection() {
    final coinProducts = _products.where((p) => 
      p.identifier.contains('coins')
    ).toList();

    // Show mock products for testing when no real products are available
    if (coinProducts.isEmpty) {
      return _buildMockCoinsSection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Arena Coins',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const RealTimeCoinBalance(
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Send gifts and support creators in debates',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: coinProducts.length,
          itemBuilder: (context, index) => _buildCoinCard(coinProducts[index]),
        ),
      ],
    );
  }

  Widget _buildCoinCard(StoreProduct product) {
    // Extract coin amount from product identifier
    int coinAmount = 1000;
    int baseAmount = 1000;
    if (product.identifier.contains('5000')) {
      coinAmount = 5000;
      baseAmount = 5000;
    } else if (product.identifier.contains('10000')) {
      coinAmount = 10000; // 10% bonus
      baseAmount = 10000;
    } else if (product.identifier.contains('25000')) {
      coinAmount = 25000; // 20% bonus
      baseAmount = 25000;
    }

    final hasBonus = product.identifier.contains('10000') || product.identifier.contains('25000');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monetization_on,
            color: Colors.amber,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            '$coinAmount',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.amber[700],
            ),
          ),
          Text(
            'coins',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (hasBonus) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'BONUS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            product.priceString,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _purchaseProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: _isProcessing 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text('Buy', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.shield, 'Premium Badge', 'Stand out with gold/silver badges'),
          _buildFeatureItem(Icons.monetization_on, 'Welcome Bonus', '1,000 free coins on subscription'),
          _buildFeatureItem(Icons.priority_high, 'Priority Support', 'Get help faster when needed'),
          _buildFeatureItem(Icons.upcoming, 'Early Access', 'Try new features before everyone'),
          _buildFeatureItem(Icons.favorite, 'Support Arena', 'Help us build the best debate platform'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF8B5CF6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mock subscription section for testing when RevenueCat products aren't available
  Widget _buildMockSubscriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Subscriptions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildMockSubscriptionCard('arena_pro_monthly', 'Arena Pro Monthly', '\$9.99', 'per month', false),
        _buildMockSubscriptionCard('arena_pro_yearly', 'Arena Pro Yearly', '\$99.99', 'per year', true),
      ],
    );
  }

  Widget _buildMockSubscriptionCard(String identifier, String title, String price, String period, bool isPopular) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? Colors.amber.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with badge and save indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPopular ? Colors.amber : Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, color: Colors.black, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isPopular ? 'GOLD' : 'SILVER',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Save 17%',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              identifier.contains('monthly') ? 'Arena Pro Monthly' : 'Arena Pro Yearly',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              'Premium debates with unlimited features',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Price and button row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    Text(
                      period,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 48,
                  width: 140,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _purchaseMockProduct(identifier),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isProcessing 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Subscribe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Mock coins section for testing when RevenueCat products aren't available
  Widget _buildMockCoinsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Arena Coins',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const RealTimeCoinBalance(
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Send gifts and support creators in debates',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMockCoinCard('arena_coins_1000', '1,000', '\$0.99', 'coins'),
            _buildMockCoinCard('arena_coins_5000', '5,000', '\$4.99', 'coins'),
            _buildMockCoinCard('arena_coins_10000', '10,000', '\$8.99', 'coins + 10% bonus'),
            _buildMockCoinCard('arena_coins_25000', '25,000', '\$19.99', 'coins + 20% bonus'),
          ],
        ),
      ],
    );
  }

  Widget _buildMockCoinCard(String identifier, String coins, String price, String description) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isProcessing ? null : () => _purchaseMockProduct(identifier),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monetization_on,
                  color: Colors.amber.shade600,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  coins,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle mock product purchase for testing
  Future<void> _purchaseMockProduct(String productId) async {
    try {
      // Check if user is authenticated
      if (_appwriteService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service initializing, please try again in a moment'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final user = await _appwriteService!.getCurrentUser();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to make purchases'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Add coins based on product type
      int coinsToAdd = 0;
      String purchaseType = '';
      
      if (productId.contains('coins')) {
        switch (productId) {
          case 'arena_coins_1000':
            coinsToAdd = 1000;
            purchaseType = 'coin package';
            break;
          case 'arena_coins_5000':
            coinsToAdd = 5000;
            purchaseType = 'coin package';
            break;
          case 'arena_coins_10000':
            coinsToAdd = 10000;
            purchaseType = 'coin package';
            break;
          case 'arena_coins_25000':
            coinsToAdd = 25000;
            purchaseType = 'coin package';
            break;
        }
        
        if (coinsToAdd > 0) {
          // Add coins using the coin service
          await _coinService.addCoins(user.$id, coinsToAdd);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Mock purchase successful!\nAdded $coinsToAdd coins to your balance'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Handle subscription mock purchases
        purchaseType = 'subscription';
        
        // Add welcome bonus coins for subscription
        await _coinService.addCoins(user.$id, 1000);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Mock subscription activated!\nAdded 1,000 welcome bonus coins\n\nNote: Real purchases require iOS/Android device with App Store/Google Play setup.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing mock purchase: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}