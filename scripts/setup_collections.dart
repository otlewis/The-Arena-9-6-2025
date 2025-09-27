import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

/// Standalone script to create Appwrite collections for payment system
/// 
/// Usage: dart run scripts/setup_collections.dart
class SetupCollections {
  // IMPORTANT: Update these with your Appwrite details
  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = '683a37a8003719978879'; // Your project ID from the environment
  static const String apiKey = 'standard_2bf7169aa1f5d5778308c19c6c015c91363ed48add53ff76421e970c2b926e76cf9236f767bd82979f959082469e4d35533bffc98651115257a5031907fc22af00af0c5c2bfc1dfc19dbe8455eda5455ff751c8e2fe80f9a5c5da681d18ca832e05bc190b51d20ffd29dd5457e613a07dee74402b50bc216daaa4403af202b5c'; // Your API key
  static const String databaseId = 'arena_db';

  final Map<String, String> headers;

  SetupCollections()
      : headers = {
          'X-Appwrite-Project': projectId,
          'X-Appwrite-Key': apiKey,
          'Content-Type': 'application/json',
        };

  Future<void> run() async {
    developer.log('🚀 Setting up Arena payment collections...\n');
    
    if (apiKey == 'YOUR_API_KEY_HERE') {
      developer.log('❌ ERROR: Please update the API key in this script first!');
      developer.log('  1. Go to Appwrite Console > Settings > API Keys');
      developer.log('  2. Create a key with Database write permissions');
      developer.log('  3. Update the apiKey constant in this file');
      return;
    }

    try {
      // 1. Create feature_flags collection
      await createFeatureFlagsCollection();
      
      // 2. Create webhook_events collection
      await createWebhookEventsCollection();
      
      // 3. Create subscription_records collection
      await createSubscriptionRecordsCollection();
      
      // 4. Create user_aliases collection
      await createUserAliasesCollection();
      
      // 5. Update users collection attributes
      await updateUsersCollection();
      
      // 6. Insert initial feature flags
      await insertInitialFeatureFlags();
      
      developer.log('\n✅ All collections created successfully!');
      developer.log('\n📝 Next steps:');
      developer.log('  1. Configure RevenueCat webhook URL: ${endpoint.replaceAll('/v1', '')}/webhooks/revenuecat');
      developer.log('  2. Update RevenueCat API keys in lib/services/revenue_cat_service.dart');
      developer.log('  3. Test sandbox purchases with TestFlight');
      
    } catch (e) {
      developer.log('❌ Error: $e');
    }
  }

  Future<void> createFeatureFlagsCollection() async {
    try {
      developer.log('📌 Creating feature_flags collection...');
      
      // Create collection
      final createResponse = await http.post(
        Uri.parse('$endpoint/databases/$databaseId/collections'),
        headers: headers,
        body: jsonEncode({
          'collectionId': 'feature_flags',
          'name': 'Feature Flags',
          'permissions': ['read("any")', 'write("team:admin")'],
        }),
      );

      if (createResponse.statusCode == 201 || createResponse.statusCode == 409) {
        if (createResponse.statusCode == 409) {
          developer.log('  ⚠️  Collection already exists, adding attributes...');
        } else {
          developer.log('  ✓ Collection created');
        }

        // Add attributes
        await createAttribute('feature_flags', 'string', 'name', size: 255, required: true);
        await createAttribute('feature_flags', 'boolean', 'enabled', required: true, defaultValue: false);
        await createAttribute('feature_flags', 'string', 'description', size: 500, required: false);
        await createAttribute('feature_flags', 'datetime', 'updatedAt', required: false);
        
        developer.log('  ✓ feature_flags collection ready');
      } else {
        developer.log('  ❌ Failed: ${createResponse.body}');
      }
    } catch (e) {
      developer.log('  ❌ Error: $e');
    }
  }

  Future<void> createWebhookEventsCollection() async {
    try {
      developer.log('📌 Creating webhook_events collection...');
      
      final createResponse = await http.post(
        Uri.parse('$endpoint/databases/$databaseId/collections'),
        headers: headers,
        body: jsonEncode({
          'collectionId': 'webhook_events',
          'name': 'Webhook Events',
          'permissions': ['read("team:admin")', 'write("label:webhook")'],
        }),
      );

      if (createResponse.statusCode == 201 || createResponse.statusCode == 409) {
        if (createResponse.statusCode == 409) {
          developer.log('  ⚠️  Collection already exists, adding attributes...');
        } else {
          developer.log('  ✓ Collection created');
        }

        await createAttribute('webhook_events', 'string', 'eventType', size: 100, required: true);
        await createAttribute('webhook_events', 'string', 'userId', size: 255, required: true);
        await createAttribute('webhook_events', 'string', 'payload', size: 10000, required: true);
        await createAttribute('webhook_events', 'datetime', 'processedAt', required: true);
        await createAttribute('webhook_events', 'string', 'source', size: 50, required: true, defaultValue: 'revenuecat');
        
        developer.log('  ✓ webhook_events collection ready');
      } else {
        developer.log('  ❌ Failed: ${createResponse.body}');
      }
    } catch (e) {
      developer.log('  ❌ Error: $e');
    }
  }

  Future<void> createSubscriptionRecordsCollection() async {
    try {
      developer.log('📌 Creating subscription_records collection...');
      
      final createResponse = await http.post(
        Uri.parse('$endpoint/databases/$databaseId/collections'),
        headers: headers,
        body: jsonEncode({
          'collectionId': 'subscription_records',
          'name': 'Subscription Records',
          'permissions': ['read("users")', 'write("label:webhook")'],
        }),
      );

      if (createResponse.statusCode == 201 || createResponse.statusCode == 409) {
        if (createResponse.statusCode == 409) {
          developer.log('  ⚠️  Collection already exists, adding attributes...');
        } else {
          developer.log('  ✓ Collection created');
        }

        await createAttribute('subscription_records', 'string', 'userId', size: 255, required: true);
        await createAttribute('subscription_records', 'string', 'productId', size: 255, required: false);
        await createAttribute('subscription_records', 'string', 'status', size: 50, required: true);
        await createAttribute('subscription_records', 'datetime', 'eventTime', required: true);
        await createAttribute('subscription_records', 'datetime', 'expiryDate', required: false);
        await createAttribute('subscription_records', 'boolean', 'isTestSubscription', required: true, defaultValue: false);
        await createAttribute('subscription_records', 'datetime', 'createdAt', required: true);
        
        developer.log('  ✓ subscription_records collection ready');
      } else {
        developer.log('  ❌ Failed: ${createResponse.body}');
      }
    } catch (e) {
      developer.log('  ❌ Error: $e');
    }
  }

  Future<void> createUserAliasesCollection() async {
    try {
      developer.log('📌 Creating user_aliases collection...');
      
      final createResponse = await http.post(
        Uri.parse('$endpoint/databases/$databaseId/collections'),
        headers: headers,
        body: jsonEncode({
          'collectionId': 'user_aliases',
          'name': 'User Aliases',
          'permissions': ['read("team:admin")', 'write("label:webhook")'],
        }),
      );

      if (createResponse.statusCode == 201 || createResponse.statusCode == 409) {
        if (createResponse.statusCode == 409) {
          developer.log('  ⚠️  Collection already exists, adding attributes...');
        } else {
          developer.log('  ✓ Collection created');
        }

        await createAttribute('user_aliases', 'string', 'originalUserId', size: 255, required: true);
        await createAttribute('user_aliases', 'string', 'newUserId', size: 255, required: true);
        await createAttribute('user_aliases', 'datetime', 'createdAt', required: true);
        
        developer.log('  ✓ user_aliases collection ready');
      } else {
        developer.log('  ❌ Failed: ${createResponse.body}');
      }
    } catch (e) {
      developer.log('  ❌ Error: $e');
    }
  }

  Future<void> updateUsersCollection() async {
    try {
      developer.log('📌 Updating users collection with premium fields...');
      
      // Add premium-related attributes
      await createAttribute('users', 'boolean', 'isPremium', required: false, defaultValue: false);
      await createAttribute('users', 'string', 'premiumType', size: 50, required: false);
      await createAttribute('users', 'datetime', 'premiumExpiry', required: false);
      await createAttribute('users', 'boolean', 'isTestSubscription', required: false, defaultValue: false);
      await createAttribute('users', 'datetime', 'lastWebhookUpdate', required: false);
      
      developer.log('  ✓ users collection updated');
    } catch (e) {
      developer.log('  ❌ Error updating users: $e');
    }
  }

  Future<void> createAttribute(
    String collectionId,
    String type,
    String key, {
    int? size,
    bool required = false,
    dynamic defaultValue,
  }) async {
    try {
      String attributeEndpoint = '$endpoint/databases/$databaseId/collections/$collectionId/attributes';
      
      Map<String, dynamic> body = {
        'key': key,
        'required': required,
      };

      if (defaultValue != null) {
        body['default'] = defaultValue;
      }

      // Add type-specific fields
      if (type == 'string') {
        attributeEndpoint += '/string';
        body['size'] = size ?? 255;
      } else if (type == 'boolean') {
        attributeEndpoint += '/boolean';
      } else if (type == 'datetime') {
        attributeEndpoint += '/datetime';
      }

      final response = await http.post(
        Uri.parse(attributeEndpoint),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 202) {
        developer.log('    ✓ Added $key attribute');
      } else if (response.statusCode == 409) {
        developer.log('    ⚠️  $key attribute already exists');
      } else {
        final error = jsonDecode(response.body);
        if (!error['message'].contains('already exists')) {
          developer.log('    ❌ Failed to add $key: ${error['message']}');
        }
      }
    } catch (e) {
      developer.log('    ❌ Error adding attribute $key: $e');
    }
  }

  Future<void> insertInitialFeatureFlags() async {
    try {
      developer.log('\n📌 Inserting initial feature flags...');
      
      final flags = [
        {
          'name': 'payments_enabled',
          'enabled': false,
          'description': 'Master kill switch for payment system',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'premium_enabled',
          'enabled': true,
          'description': 'Enable premium features for subscribers',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'gifts_enabled',
          'enabled': true,
          'description': 'Enable gift system',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'challenges_enabled',
          'enabled': true,
          'description': 'Enable challenge system',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'sandbox_enabled',
          'enabled': true,
          'description': 'Allow sandbox/test purchases',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ];

      for (final flag in flags) {
        final response = await http.post(
          Uri.parse('$endpoint/databases/$databaseId/collections/feature_flags/documents'),
          headers: headers,
          body: jsonEncode({
            'documentId': 'unique()',
            'data': flag,
          }),
        );

        if (response.statusCode == 201) {
          developer.log('  ✓ Created flag: ${flag['name']} = ${flag['enabled']}');
        } else if (response.statusCode == 409) {
          developer.log('  ⚠️  Flag ${flag['name']} already exists');
        } else {
          developer.log('  ❌ Failed to create ${flag['name']}: ${response.body}');
        }
      }
    } catch (e) {
      developer.log('  ❌ Error inserting flags: $e');
    }
  }
}

void main() async {
  final setup = SetupCollections();
  await setup.run();
}