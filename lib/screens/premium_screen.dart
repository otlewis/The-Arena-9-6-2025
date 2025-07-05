import 'package:flutter/material.dart';
import '../examples/notification_system_demo.dart';

/// Premium store screen for subscriptions, coins, and other premium features
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Store'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
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
                _buildSubscriptionCard(
                  title: 'Arena Pro Monthly',
                  price: '\$9.99/month',
                  features: [
                    'Unlimited debate challenges',
                    'Priority arena access',
                    'Advanced analytics',
                    'Custom debate topics',
                    'No ads',
                  ],
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildSubscriptionCard(
                  title: 'Arena Pro Yearly',
                  price: '\$99.99/year',
                  features: [
                    'All monthly features',
                    '2 months free',
                    'Exclusive tournaments',
                    'VIP support',
                    'Early access to new features',
                  ],
                  color: Colors.purple,
                  isPopular: true,
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
            
            const SizedBox(height: 32),
            
            // Temporary: Notification Demo Access
            _buildSection(
              title: 'Developer Features',
              icon: Icons.bug_report,
              color: Colors.green,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.blue),
                    title: const Text('Notification System Demo'),
                    subtitle: const Text('Test the new notification features'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationSystemDemo(),
                        ),
                      );
                    },
                  ),
                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
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
          decoration: BoxDecoration(
            border: Border.all(
              color: isPopular ? color : Colors.grey.shade300,
              width: isPopular ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isPopular ? color.withValues(alpha: 0.05) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _showPurchaseDialog(title, price);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Subscribe'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isPopular)
          Positioned(
            top: -1,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () => _showPurchaseDialog(
              '${package['coins']} Arena Coins',
              package['price']!,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    package['coins']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () => _showGiftInfo(gift['name'] as String),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    gift['icon'] as IconData,
                    color: Colors.pink,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gift['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
      builder: (context) => AlertDialog(
        title: Text('Purchase $item'),
        content: Text('Would you like to purchase $item for $price?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showComingSoonDialog();
            },
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }

  void _showGiftInfo(String giftName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(giftName),
        content: Text('Send $giftName to other users during debates to show appreciation!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon!'),
        content: const Text('Payment integration is coming soon. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}