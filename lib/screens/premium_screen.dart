import '../core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/in_app_purchase_service.dart';
import '../services/coin_service.dart';
import '../services/appwrite_service.dart';
import '../widgets/challenge_bell.dart';
// Removed unused import: package:in_app_purchase/in_app_purchase.dart

/// Premium store screen for subscriptions, coins, and other premium features
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final ThemeService _themeService = ThemeService();
  final InAppPurchaseService _purchaseService = InAppPurchaseService();
  final CoinService _coinService = CoinService();
  final AppwriteService _appwriteService = AppwriteService();
  
  bool _isLoading = false;
  // Removed unused _products field
  String? _currentUserId;
  
  // Colors matching app theme
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  
  @override
  void initState() {
    super.initState();
    _initializePurchaseService();
    _getCurrentUser();
  }
  
  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }
  
  Future<void> _initializePurchaseService() async {
    setState(() => _isLoading = true);
    
    _purchaseService.onProductsLoaded = (products) {
      if (mounted) {
        setState(() {
          // Products loaded but not stored (unused)
          _isLoading = false;
        });
      }
    };
    
    _purchaseService.onPurchaseSuccess = (productId) {
      if (mounted) {
        _handlePurchaseSuccess(productId);
      }
    };
    
    _purchaseService.onPurchaseError = (error) {
      if (mounted) {
        _showErrorDialog('Purchase Error', error);
        setState(() => _isLoading = false);
      }
    };
    
    await _purchaseService.initialize();
  }
  
  Future<void> _getCurrentUser() async {
    final user = await _appwriteService.getCurrentUser();
    if (user != null) {
      setState(() => _currentUserId = user.$id);
    }
  }
  
  void _handlePurchaseSuccess(String productId) {
    setState(() => _isLoading = false);
    
    // Handle different product types
    if (productId.contains('coins')) {
      _handleCoinPurchase(productId);
    } else if (productId.contains('monthly') || productId.contains('yearly')) {
      _handleSubscriptionPurchase(productId);
    }
    
    _showSuccessDialog('Purchase Successful!', 'Your purchase has been completed successfully.');
  }
  
  Future<void> _handleCoinPurchase(String productId) async {
    if (_currentUserId == null) return;
    
    // Award coins based on product
    int coinsToAward = 0;
    switch (productId) {
      case 'arena_coins_1000':
        coinsToAward = 1000;
        break;
      case 'arena_coins_5000':
        coinsToAward = 5500; // 5000 + 500 bonus
        break;
      case 'arena_coins_10000':
        coinsToAward = 11500; // 10000 + 1500 bonus
        break;
      case 'arena_coins_25000':
        coinsToAward = 30000; // 25000 + 5000 bonus
        break;
    }
    
    if (coinsToAward > 0) {
      await _coinService.addCoins(_currentUserId!, coinsToAward);
    }
  }
  
  Future<void> _handleSubscriptionPurchase(String productId) async {
    if (_currentUserId == null) return;
    
    // Update user's premium status in Appwrite
    // This would typically be done on your backend after receipt verification
    try {
      // Calculate expiry date but not used in current implementation
      final _ = DateTime.now().add(
        productId.contains('yearly') ? const Duration(days: 365) : const Duration(days: 30),
      );
      
      // For now, we'll just award some coins as a premium bonus
      await _coinService.addCoins(_currentUserId!, 1000); // Premium welcome bonus
      
      // TODO: Update user profile with premium status and expiry date
      // await _appwriteService.updateUserProfile(
      //   userId: _currentUserId!,
      //   premiumStatus: true,
      //   premiumExpiry: expiryDate,
      // );
      
    } catch (e) {
      AppLogger().debug('Error updating premium status: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
      appBar: AppBar(
        title: Text(
          'Premium Store',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        backgroundColor: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        elevation: 0,
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? Colors.white70 : scarletRed,
        ),
        actions: [
          // Challenge Bell
          ChallengeBell(
            iconColor: _themeService.isDarkMode ? Colors.white70 : deepPurple,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          _buildNeumorphicIcon(
            icon: Icons.info_outline,
            onTap: () => _showComingSoonDialog(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                SizedBox(height: 16),
                Text('Processing...', style: TextStyle(fontSize: 16)),
              ],
            ),
          )
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Beta Testing Notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.1),
                    Colors.cyan.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.science,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🧪 Beta Testing Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _themeService.isDarkMode ? Colors.blue[300] : Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coin purchases are simulated for testing. No real money will be charged.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Premium Subscription Section
            _buildSection(
              title: 'Premium Subscriptions',
              icon: Icons.diamond,
              color: Colors.orange,
              children: [
                _buildSubscriptionCard(
                  title: 'Arena Pro Monthly',
                  price: '\$9.99/month',
                  features: [
                    '🎤 High-quality audio debates',
                    'Unlimited debate challenges',
                    'Priority arena access',
                    'Advanced analytics & insights',
                    'Custom debate topics',
                    'No advertisements',
                    'Priority customer support',
                    'Exclusive debate tournaments',
                  ],
                  color: Colors.purple,
                  isPopular: true,
                ),
                const SizedBox(height: 12),
                _buildSubscriptionCard(
                  title: 'Arena Pro Yearly',
                  price: '\$99.99/year',
                  features: [
                    '🎤 High-quality audio debates',
                    'All monthly features included',
                    'Get 2 months free (save \$20)',
                    'Exclusive annual tournaments',
                    'VIP priority support',
                    'Early access to new features',
                    'Special yearly subscriber badge',
                    'Beta feature testing access',
                  ],
                  color: Colors.blue,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Coins Section
            _buildSection(
              title: 'Arena Coins',
              icon: Icons.monetization_on,
              color: Colors.amber,
              children: [
                _buildCoinsGrid(),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Gifts Section
            _buildSection(
              title: 'Gifts & Rewards',
              icon: Icons.card_giftcard,
              color: Colors.pink,
              children: [
                _buildGiftsGrid(),
              ],
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-8, -8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.5)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
            offset: const Offset(8, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode 
                      ? const Color(0xFF2D2D2D)
                      : const Color(0xFFE8E8E8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _themeService.isDarkMode 
                          ? Colors.black.withValues(alpha: 0.6)
                          : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                      offset: const Offset(3, 3),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: _themeService.isDarkMode 
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.white.withValues(alpha: 0.8),
                      offset: const Offset(-3, -3),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required String title,
    required String price,
    required List<String> features,
    required Color color,
    bool isPopular = false,
  }) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? const Color(0xFF2D2D2D)
                : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPopular ? color.withValues(alpha: 0.6) : scarletRed.withValues(alpha: 0.2),
              width: isPopular ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.8),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _themeService.isDarkMode ? Colors.white : color,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _themeService.isDarkMode 
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFF0F0F3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1),
                      ),
                      child: Icon(Icons.check, color: color, size: 12),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 14,
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              _buildNeumorphicButton(
                text: 'Subscribe',
                color: color,
                onPressed: () => _purchaseSubscription(title, price),
              ),
            ],
          ),
        ),
        if (isPopular)
          Positioned(
            top: -2,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoinsGrid() {
    final coinPackages = [
      {'coins': '1,000', 'price': '\$0.99', 'bonus': '', 'productId': 'arena_coins_1000'},
      {'coins': '5,000', 'price': '\$4.99', 'bonus': '+500 Bonus', 'productId': 'arena_coins_5000'},
      {'coins': '10,000', 'price': '\$9.99', 'bonus': '+1.5K Bonus', 'productId': 'arena_coins_10000'},
      {'coins': '25,000', 'price': '\$19.99', 'bonus': '+5K Bonus', 'productId': 'arena_coins_25000'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: coinPackages.length,
      itemBuilder: (context, index) {
        final package = coinPackages[index];
        return GestureDetector(
          onTap: () => _purchaseCoinPackage(index),
          child: Container(
            decoration: BoxDecoration(
              color: _themeService.isDarkMode 
                  ? const Color(0xFF2D2D2D)
                  : const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scarletRed.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.8),
                  offset: const Offset(-6, -6),
                  blurRadius: 12,
                ),
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                  offset: const Offset(6, 6),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _themeService.isDarkMode 
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFF0F0F3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _themeService.isDarkMode 
                              ? Colors.black.withValues(alpha: 0.6)
                              : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                          spreadRadius: -1,
                        ),
                        BoxShadow(
                          color: _themeService.isDarkMode 
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white.withValues(alpha: 0.8),
                          offset: const Offset(-2, -2),
                          blurRadius: 4,
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    package['coins']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (package['bonus']!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      package['bonus']!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    package['price']!,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGiftsGrid() {
    final gifts = [
      {'name': 'Roses', 'cost': '10 coins', 'icon': Icons.local_florist},
      {'name': 'Trophy', 'cost': '50 coins', 'icon': Icons.emoji_events},
      {'name': 'Crown', 'cost': '100 coins', 'icon': Icons.workspaces},
      {'name': 'Diamond', 'cost': '500 coins', 'icon': Icons.diamond},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return GestureDetector(
          onTap: () => _showGiftInfo(gift['name'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: _themeService.isDarkMode 
                  ? const Color(0xFF2D2D2D)
                  : const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scarletRed.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.8),
                  offset: const Offset(-6, -6),
                  blurRadius: 12,
                ),
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                  offset: const Offset(6, 6),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _themeService.isDarkMode 
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFF0F0F3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _themeService.isDarkMode 
                              ? Colors.black.withValues(alpha: 0.6)
                              : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                          offset: const Offset(3, 3),
                          blurRadius: 6,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: _themeService.isDarkMode 
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white.withValues(alpha: 0.8),
                          offset: const Offset(-3, -3),
                          blurRadius: 6,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Icon(
                      gift['icon'] as IconData,
                      color: Colors.pink,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gift['name'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gift['cost'] as String,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _purchaseSubscription(String title, String price) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Determine product ID based on title
      String productId;
      if (title.contains('Monthly')) {
        productId = InAppPurchaseService.monthlySubscriptionId;
      } else if (title.contains('Yearly')) {
        productId = InAppPurchaseService.yearlySubscriptionId;
      } else {
        throw Exception('Unknown subscription type');
      }
      
      final product = _purchaseService.getProduct(productId);
      if (product != null) {
        await _purchaseService.purchaseProduct(product);
      } else {
        _showErrorDialog('Product Not Found', 'This subscription is not available.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showErrorDialog('Purchase Error', 'Failed to start purchase: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _purchaseCoinPackage(int packageIndex) async {
    if (_isLoading) return;
    
    final coinPackages = [
      {'coins': '1,000', 'price': '\$0.99', 'productId': 'arena_coins_1000'},
      {'coins': '5,000', 'price': '\$4.99', 'productId': 'arena_coins_5000'},
      {'coins': '10,000', 'price': '\$9.99', 'productId': 'arena_coins_10000'},
      {'coins': '25,000', 'price': '\$19.99', 'productId': 'arena_coins_25000'},
    ];
    
    if (packageIndex >= coinPackages.length) return;
    
    final package = coinPackages[packageIndex];
    final productId = package['productId']!;
    
    // For beta testing, we'll simulate the purchase by directly adding coins
    await _simulateCoinPurchase(productId, package['coins']!, package['price']!);
  }
  
  Future<void> _simulateCoinPurchase(String productId, String coins, String price) async {
    if (_currentUserId == null) {
      _showErrorDialog('Error', 'Please log in to make purchases.');
      return;
    }
    
    // Show confirmation dialog
    final shouldPurchase = await _showConfirmationDialog(
      'Purchase $coins Arena Coins', 
      'Would you like to purchase $coins for $price?\n\n⚠️ Beta Testing: This will add coins to your account for testing purposes.',
    );
    
    if (!shouldPurchase) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Simulate purchase delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Add coins based on package
      await _handleCoinPurchase(productId);
      
      setState(() => _isLoading = false);
      _showSuccessDialog('Purchase Successful!', 'Your coins have been added to your account.');
      
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Purchase Error', 'Failed to complete purchase: $e');
    }
  }
  
  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Purchase'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showGiftInfo(String giftName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? const Color(0xFF2D2D2D)
                : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scarletRed.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.8),
                offset: const Offset(-8, -8),
                blurRadius: 16,
              ),
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                offset: const Offset(8, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                giftName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Send $giftName to other users during debates to show appreciation!',
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildNeumorphicButton(
                text: 'Got it',
                color: accentPurple,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? const Color(0xFF2D2D2D)
                : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scarletRed.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.8),
                offset: const Offset(-8, -8),
                blurRadius: 16,
              ),
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                offset: const Offset(8, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode 
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFF0F0F3),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _themeService.isDarkMode 
                          ? Colors.black.withValues(alpha: 0.6)
                          : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                      offset: const Offset(3, 3),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: _themeService.isDarkMode 
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.white.withValues(alpha: 0.8),
                      offset: const Offset(-3, -3),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(Icons.schedule, color: Colors.orange, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Coming Soon!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Payment integration is coming soon. Stay tuned!',
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildNeumorphicButton(
                text: 'OK',
                color: accentPurple,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF0F0F3),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.7),
              offset: const Offset(-3, -3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: _themeService.isDarkMode ? Colors.white70 : accentPurple,
        ),
      ),
    );
  }

  Widget _buildNeumorphicButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF0F0F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.7),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}