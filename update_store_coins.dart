import 'package:appwrite/appwrite.dart';

void main() async {
  // Initialize Appwrite client
  final client = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('683a37a8003719978879');

  final databases = Databases(client);

  // Updated coin packages with optimized amounts (10x lower)
  final coinPackages = [
    {
      '\$id': 'coins_100',
      'coin_package_id': 'coins_100',
      'amount': 100,  // Changed from 1000
      'price_display': '\$0.99',
      'badge': null,  // Removed badge for starter
      'rc_product_id': 'arena_coins_100',
      'sort_order': 1,
      'is_active': true,
    },
    {
      '\$id': 'coins_600',
      'coin_package_id': 'coins_600',
      'amount': 600,  // Changed from 5000
      'price_display': '\$4.99',
      'badge': 'Most Popular',
      'rc_product_id': 'arena_coins_600',
      'sort_order': 2,
      'is_active': true,
    },
    {
      '\$id': 'coins_2000',
      'coin_package_id': 'coins_2000',
      'amount': 2000,  // Changed from 10000
      'price_display': '\$14.99',
      'badge': 'Best Value',
      'rc_product_id': 'arena_coins_2000',
      'sort_order': 3,
      'is_active': true,
    },
    {
      '\$id': 'coins_5000',
      'coin_package_id': 'coins_5000',
      'amount': 5000,  // Changed from 25000
      'price_display': '\$34.99',
      'badge': 'Premium',
      'rc_product_id': 'arena_coins_5000',
      'sort_order': 4,
      'is_active': true,
    },
  ];

  print('🔄 Updating Store Coins with optimized amounts...\n');

  for (final package in coinPackages) {
    try {
      final id = package['\$id'] as String;
      package.remove('\$id');  // Remove $id from update data

      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'store_coins',
        documentId: id,
        data: package,
      );

      print('✅ Updated ${package['coin_package_id']}: ${package['amount']} coins for ${package['price_display']}');
      if (package['badge'] != null) {
        print('   Badge: ${package['badge']}');
      }
    } catch (e) {
      print('❌ Error updating ${package['coin_package_id']}: $e');

      // If update fails, try creating the document
      try {
        await databases.createDocument(
          databaseId: 'arena_db',
          collectionId: 'store_coins',
          documentId: package['coin_package_id'] as String,
          data: package,
        );
        print('✅ Created ${package['coin_package_id']}: ${package['amount']} coins for ${package['price_display']}');
      } catch (createError) {
        print('❌ Could not create ${package['coin_package_id']}: $createError');
      }
    }
  }

  print('\n📊 New Coin Economy Summary:');
  print('├── Starter: 100 coins for \$0.99 (1¢ per coin)');
  print('├── Popular: 600 coins for \$4.99 (0.83¢ per coin)');
  print('├── Value: 2,000 coins for \$14.99 (0.75¢ per coin)');
  print('└── Premium: 5,000 coins for \$34.99 (0.7¢ per coin)');

  print('\n💡 Benefits:');
  print('├── Faster depletion = More frequent purchases');
  print('├── Gifts feel more meaningful (higher % of balance)');
  print('├── 5-10x higher purchase frequency expected');
  print('└── Better monetization for staff payouts');
}