import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Premium store screen for subscriptions, coins, and other premium features
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final ThemeService _themeService = ThemeService();
  
  // Colors matching app theme
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  
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
          _buildNeumorphicIcon(
            icon: Icons.info_outline,
            onTap: () => _showComingSoonDialog(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Subscription Section
            _buildSection(
              title: 'Premium Subscriptions',
              icon: Icons.diamond,
              color: Colors.orange,
              children: [
                // Pricing Info Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withValues(alpha: 0.1),
                        Colors.purple.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
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
                  child: Column(
                    children: [
                      const Icon(
                        Icons.celebration,
                        color: Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '🎉 Special Launch Offer!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _themeService.isDarkMode ? Colors.white : Colors.orange,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                              children: const [
                                TextSpan(
                                  text: '🎤 Audio-Only: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: 'Enjoy '),
                                TextSpan(
                                  text: '14 days free',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                TextSpan(text: ', then '),
                                TextSpan(
                                  text: '\$4.99',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                TextSpan(text: ' for 1st month, then '),
                                TextSpan(
                                  text: '\$9.99',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                TextSpan(text: '/month'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                              children: const [
                                TextSpan(
                                  text: '📹 Video: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: 'Enjoy '),
                                TextSpan(
                                  text: '14 days free',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                TextSpan(text: ', then '),
                                TextSpan(
                                  text: '\$9.99',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                TextSpan(text: ' for 1st month, then '),
                                TextSpan(
                                  text: '\$14.99',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                TextSpan(text: '/month'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildSubscriptionCard(
                  title: 'Arena Pro Audio-Only',
                  price: '\$9.99/month',
                  features: [
                    '🎤 Audio-only debates',
                    'Unlimited debate challenges',
                    'Priority arena access',
                    'Advanced analytics',
                    'Custom debate topics',
                    'No ads',
                  ],
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
                _buildSubscriptionCard(
                  title: 'Arena Pro Video',
                  price: '\$14.99/month',
                  features: [
                    '📹 Video + Audio debates',
                    'All audio-only features',
                    'HD video streaming',
                    'Screen sharing capabilities',
                    'Video recording & replay',
                    'Premium video quality',
                  ],
                  color: Colors.red,
                  isPopular: true,
                ),
                const SizedBox(height: 12),
                _buildSubscriptionCard(
                  title: 'Arena Pro Audio Yearly',
                  price: '\$99.99/year',
                  features: [
                    '🎤 Audio-only debates',
                    'All monthly audio features',
                    '2 months free',
                    'Exclusive tournaments',
                    'VIP support',
                    'Early access to new features',
                  ],
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildSubscriptionCard(
                  title: 'Arena Pro Video Yearly',
                  price: '\$149.99/year',
                  features: [
                    '📹 Video + Audio debates',
                    'All monthly video features',
                    '2 months free',
                    'Exclusive video tournaments',
                    'Priority VIP support',
                    'Beta video features access',
                  ],
                  color: Colors.orange,
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
                onPressed: () => _showPurchaseDialog(title, price),
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
      {'coins': '1,000', 'price': '\$0.99', 'bonus': ''},
      {'coins': '5,000', 'price': '\$4.99', 'bonus': '+500 Bonus'},
      {'coins': '10,000', 'price': '\$9.99', 'bonus': '+1.5K Bonus'},
      {'coins': '25,000', 'price': '\$19.99', 'bonus': '+5K Bonus'},
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
          onTap: () => _showPurchaseDialog(
            '${package['coins']} Arena Coins',
            package['price']!,
          ),
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

  void _showPurchaseDialog(String item, String price) {
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
                'Purchase $item',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to purchase $item for $price?',
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildNeumorphicButton(
                      text: 'Cancel',
                      color: Colors.grey[600]!,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNeumorphicButton(
                      text: 'Buy Now',
                      color: scarletRed,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showComingSoonDialog();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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