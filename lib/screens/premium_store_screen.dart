import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenue_cat_service.dart';
import '../core/logging/app_logger.dart';
import '../services/appwrite_service.dart';
import '../services/store_config_service.dart';
import '../models/store_config.dart';
import '../widgets/real_time_coin_balance.dart';
import '../services/super_moderator_service.dart';

/// Premium store screen powered by RevenueCat
class PremiumStoreScreen extends StatefulWidget {
  const PremiumStoreScreen({super.key});

  @override
  State<PremiumStoreScreen> createState() => _PremiumStoreScreenState();
}

class _PremiumStoreScreenState extends State<PremiumStoreScreen> {
  final RevenueCatService _revenueCatService = GetIt.instance<RevenueCatService>();
  final StoreConfigService _storeConfigService = StoreConfigService();
  AppwriteService? _appwriteService;

  List<StoreProduct> _products = [];
  StoreData? _storeConfig;
  int? _userAge;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  CustomerInfo? _customerInfo;
  String? _currentUserId;
  bool _isSuperMod = false;

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

      // Get current user and check super moderator status
      final currentUser = await _appwriteService?.getCurrentUser();
      if (currentUser != null) {
        _currentUserId = currentUser.$id;
        final superModService = SuperModeratorService();
        _isSuperMod = superModService.isSuperModerator(_currentUserId!);
      }

      if (mounted) {
        setState(() {});
      }
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
            content: Text('❌ Purchase failed: $error'),
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

      // Load products, customer info, and store configuration
      await Future.wait([
        _loadProducts(),
        _loadCustomerInfo(),
        _loadStoreConfiguration(),
        _loadUserAge(),
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

  Future<void> _loadStoreConfiguration() async {
    try {
      await _storeConfigService.initialize();
      final storeConfig = await _storeConfigService.refreshStoreConfig();
      setState(() {
        _storeConfig = storeConfig;
      });
      AppLogger().debug('Store configuration loaded successfully');
    } catch (e) {
      AppLogger().error('Failed to load store configuration: $e');
      // Set fallback empty config
      setState(() {
        _storeConfig = StoreData.empty();
      });
    }
  }

  Future<void> _loadUserAge() async {
    try {
      if (_appwriteService != null) {
        final user = await _appwriteService!.getCurrentUser();
        if (user != null) {
          final userData = await _appwriteService!.databases.getDocument(
            databaseId: 'arena_db',
            collectionId: 'users',
            documentId: user.$id,
          );

          final dob = userData.data['dateOfBirth'];
          if (dob != null) {
            final birthDate = DateTime.parse(dob);
            final age = DateTime.now().difference(birthDate).inDays ~/ 365;
            setState(() {
              _userAge = age;
            });
            AppLogger().debug('User age loaded: $age');
          }
        }
      }
    } catch (e) {
      AppLogger().warning('Could not load user age: $e');
      // Age will remain null, showing all subscriptions
    }
  }

  Future<void> _purchaseProduct(StoreProduct product) async {
    try {
      // Age-based purchase validation
      if (product.identifier.contains('teen') && _userAge != null && _userAge! >= 18) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teen plans are only available for users 13-17 years old'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Prevent teens from purchasing adult plans
      if ((product.identifier.contains('pro') || product.identifier.contains('adult'))
          && _userAge != null && _userAge! < 18) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adult plans are only available for users 18+ years old'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if user is authenticated
      if (_appwriteService == null) {
        // Wait for AppwriteService to be ready
        try {
          await GetIt.instance.isReady<AppwriteService>();
          _appwriteService = GetIt.instance<AppwriteService>();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to connect to services. Please check your internet connection.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      final user = await _appwriteService!.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to make purchases'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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


  @override
  Widget build(BuildContext context) {
    // Check if user is a Super Moderator
    if (!_isSuperMod) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Premium Store'),
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The Premium Store is currently only accessible to Super Moderators.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Store'),
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
          if (_storeConfig != null && _storeConfig!.activeSubscriptions.isNotEmpty)
            ...[
              _buildSubscriptionSection(),
              const SizedBox(height: 24),
            ],
          if (_storeConfig != null && _storeConfig!.activeCoins.isNotEmpty)
            ...[
              _buildCoinsSection(),
              const SizedBox(height: 24),
            ],
          if (_storeConfig != null && _storeConfig!.activeEvents.isNotEmpty)
            ...[
              _buildEventsSection(),
              const SizedBox(height: 24),
            ],
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
            : [Color(0xFF8B5CF6).withOpacity(0.1), Color(0xFF6B46C1).withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPremium ? Colors.amber : const Color(0xFF8B5CF6).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            hasPremium ? Icons.shield : Icons.workspace_premium,
            size: 48,
            color: hasPremium ? Colors.black : const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 6),
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


  /// Check if user has a specific subscription type
  bool _hasSubscription(String productId) {
    if (_customerInfo == null) return false;
    
    final entitlements = _customerInfo!.entitlements.active;
    final premiumEntitlement = entitlements[RevenueCatService.premiumEntitlement];
    
    if (premiumEntitlement == null) return false;
    
    return premiumEntitlement.productIdentifier == productId;
  }

  Widget _buildSubscriptionSection() {
    if (_storeConfig == null) return const SizedBox.shrink();

    // Get subscriptions eligible for user's age
    final eligibleSubscriptions = _userAge != null
        ? _storeConfig!.getEligibleSubscriptions(_userAge!)
        : _storeConfig!.activeSubscriptions;

    if (eligibleSubscriptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Subscriptions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...eligibleSubscriptions.map((subscription) => _buildDynamicSubscriptionCard(subscription)),
      ],
    );
  }

  Widget _buildDynamicSubscriptionCard(StoreSubscription subscription) {
    // Find matching RevenueCat product
    final product = _products.firstWhere(
      (p) => p.identifier == subscription.rcProductId,
      orElse: () => StoreProduct(
        subscription.rcProductId,
        subscription.title,
        subscription.title,
        9.99, // Fallback price
        subscription.priceDisplay,
        'USD',
      ),
    );

    final isTeenPlan = subscription.eligibility == 'age_13_17';
    final isPopular = subscription.badge?.toLowerCase().contains('popular') ?? false;
    final badgeColor = isPopular ? Colors.amber : isTeenPlan ? Colors.blue[400]! : Colors.grey[400]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? Colors.amber.withOpacity(0.4) :
                 isTeenPlan ? Colors.blue.withOpacity(0.4) :
                 Colors.grey.withOpacity(0.3),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
            // Header row with badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (subscription.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTeenPlan ? Icons.school : Icons.shield,
                          color: Colors.black,
                          size: 16
                        ),
                        const SizedBox(width: 6),
                        Text(
                          subscription.badge!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (subscription.badge != null) const SizedBox(height: 16),

            // Title
            Text(
              subscription.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            // Description from features
            if (subscription.features.isNotEmpty)
              Text(
                subscription.features.take(2).join(' • '),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

            const SizedBox(height: 16),

            // Features list
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subscription.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
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
                      subscription.priceDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    if (isTeenPlan)
                      Text(
                        'Parent approval required',
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                SizedBox(
                  height: 48,
                  width: 140,
                  child: ElevatedButton(
                    onPressed: _isProcessing || _hasSubscription(subscription.rcProductId)
                      ? null
                      : () => _purchaseProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasSubscription(subscription.rcProductId)
                        ? Colors.grey[400]
                        : const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: _hasSubscription(subscription.rcProductId) ? 0 : 4,
                      shadowColor: const Color(0xFF8B5CF6).withOpacity(0.3),
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
                          _hasSubscription(subscription.rcProductId) ? 'Active' : 'Subscribe',
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
    if (_storeConfig == null || !_storeConfig!.coinPurchasesEnabled) {
      return const SizedBox.shrink();
    }

    final activeCoins = _storeConfig!.activeCoins;
    if (activeCoins.isEmpty) {
      return const SizedBox.shrink();
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
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.95,
          ),
          itemCount: activeCoins.length,
          itemBuilder: (context, index) => _buildDynamicCoinCard(activeCoins[index]),
        ),
      ],
    );
  }

  Widget _buildDynamicCoinCard(StoreCoin coinConfig) {
    // Find matching RevenueCat product
    final product = _products.firstWhere(
      (p) => p.identifier == coinConfig.rcProductId,
      orElse: () => StoreProduct(
        coinConfig.rcProductId,
        '${coinConfig.amount} Arena Coins',
        '${coinConfig.amount} Coins',
        4.99, // Fallback price
        coinConfig.priceDisplay,
        'USD',
      ),
    );


    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge for popular/best value
          if (coinConfig.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: coinConfig.badge!.toLowerCase().contains('popular')
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: coinConfig.badge!.toLowerCase().contains('popular')
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                ),
              ),
              child: Text(
                coinConfig.badge!,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: coinConfig.badge!.toLowerCase().contains('popular')
                      ? Colors.orange[700]
                      : Colors.green[700],
                ),
              ),
            ),

          // Coin icon and amount
          Icon(
            Icons.monetization_on,
            color: Colors.amber[600],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            '${coinConfig.amount}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            'coins',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),

          // Price
          Text(
            coinConfig.priceDisplay,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 6),

          // Buy button
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _purchaseProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Buy',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEventsSection() {
    if (_storeConfig == null || !_storeConfig!.eventsEnabled) {
      return const SizedBox.shrink();
    }

    final activeEvents = _storeConfig!.activeEvents;
    if (activeEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Events',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Join tournaments and special debate events',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...activeEvents.map((event) => _buildEventCard(event)),
      ],
    );
  }

  Widget _buildEventCard(StoreEvent event) {
    final isActive = event.startDate != null && event.endDate != null
        ? DateTime.now().isAfter(event.startDate!) && DateTime.now().isBefore(event.endDate!)
        : true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Event icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.event,
              color: Colors.purple[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                if (event.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      event.priceDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    if (!isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Ended',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action button
          ElevatedButton(
            onPressed: isActive ? () => _handleEventAction(event) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? const Color(0xFF8B5CF6) : Colors.grey[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              isActive ? event.ctaText : 'Ended',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEventAction(StoreEvent event) {
    // Handle event-specific actions
    AppLogger().info('Event action triggered: ${event.title}');

    // For now, show a dialog indicating the event action
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Text('Event feature coming soon!\n\n${event.description ?? 'Join this special event.'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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





}