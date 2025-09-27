import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Appwrite configuration
  final endpoint = 'https://cloud.appwrite.io/v1';
  final projectId = '683a37a8003719978879';
  final databaseId = 'arena_db';
  final collectionId = 'store_coins';

  // You'll need to set this API key - get it from Appwrite Console > Settings > API Keys
  // Create a new API key with Database write permissions
  final apiKey = Platform.environment['APPWRITE_API_KEY'] ?? '';

  if (apiKey.isEmpty) {
    print('❌ Please set APPWRITE_API_KEY environment variable');
    print('   Get it from: Appwrite Console > Settings > API Keys');
    print('   Run: export APPWRITE_API_KEY="your-api-key-here"');
    exit(1);
  }

  // Updated coin packages with optimized amounts
  final updates = [
    {
      'documentId': 'coins_100',
      'data': {
        'coin_package_id': 'coins_100',
        'amount': 100,  // Changed from 1000
        'price_display': '\$0.99',
        'rc_product_id': 'arena_coins_100',
        'sort_order': 1,
        'is_active': true,
      }
    },
    {
      'documentId': 'coins_600',
      'data': {
        'coin_package_id': 'coins_600',
        'amount': 600,  // Changed from 5000
        'price_display': '\$4.99',
        'badge': 'Most Popular',
        'rc_product_id': 'arena_coins_600',
        'sort_order': 2,
        'is_active': true,
      }
    },
    {
      'documentId': 'coins_2000',
      'data': {
        'coin_package_id': 'coins_2000',
        'amount': 2000,  // Changed from 10000
        'price_display': '\$14.99',
        'badge': 'Best Value',
        'rc_product_id': 'arena_coins_2000',
        'sort_order': 3,
        'is_active': true,
      }
    },
    {
      'documentId': 'coins_5000',
      'data': {
        'coin_package_id': 'coins_5000',
        'amount': 5000,  // Changed from 25000
        'price_display': '\$34.99',
        'badge': 'Premium',
        'rc_product_id': 'arena_coins_5000',
        'sort_order': 4,
        'is_active': true,
      }
    },
  ];

  print('🔄 Updating Store Coins with optimized amounts...\n');

  for (final update in updates) {
    final documentId = update['documentId'] as String;
    final data = update['data'] as Map<String, dynamic>;

    try {
      final url = Uri.parse('$endpoint/databases/$databaseId/collections/$collectionId/documents/$documentId');

      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Appwrite-Project': projectId,
          'X-Appwrite-Key': apiKey,
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final amount = data['amount'];
        final price = data['price_display'];
        final badge = data['badge'] ?? '';
        print('✅ Updated $documentId: $amount coins for $price ${badge.isNotEmpty ? "($badge)" : ""}');
      } else {
        print('❌ Failed to update $documentId: ${response.body}');
      }
    } catch (e) {
      print('❌ Error updating $documentId: $e');
    }
  }

  print('\n📊 New Coin Economy Summary:');
  print('├── Starter: 100 coins for \$0.99 (1¢ per coin)');
  print('├── Popular: 600 coins for \$4.99 (0.83¢ per coin) - Most Popular');
  print('├── Value: 2,000 coins for \$14.99 (0.75¢ per coin) - Best Value');
  print('└── Premium: 5,000 coins for \$34.99 (0.7¢ per coin) - Premium');

  print('\n💡 Benefits:');
  print('├── Faster depletion = More frequent purchases');
  print('├── Gifts feel more meaningful (higher % of balance)');
  print('├── 5-10x higher purchase frequency expected');
  print('└── Better monetization for staff payouts');
}