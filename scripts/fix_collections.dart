import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Fix script to add missing attributes and insert feature flags
class FixCollections {
  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = '683a37a8003719978879';
  static const String apiKey = 'standard_2bf7169aa1f5d5778308c19c6c015c91363ed48add53ff76421e970c2b926e76cf9236f767bd82979f959082469e4d35533bffc98651115257a5031907fc22af00af0c5c2bfc1dfc19dbe8455eda5455ff751c8e2fe80f9a5c5da681d18ca832e05bc190b51d20ffd29dd5457e613a07dee74402b50bc216daaa4403af202b5c';
  static const String databaseId = 'arena_db';

  final Map<String, String> headers;

  FixCollections()
      : headers = {
          'X-Appwrite-Project': projectId,
          'X-Appwrite-Key': apiKey,
          'Content-Type': 'application/json',
        };

  Future<void> run() async {
    print('🔧 Fixing Arena collections...\n');

    // Fix missing attributes
    await fixFeatureFlagsAttributes();
    await fixWebhookEventsAttributes();
    await fixSubscriptionRecordsAttributes();
    
    // Wait for attributes to be ready
    print('\n⏳ Waiting for attributes to be ready...');
    await Future.delayed(Duration(seconds: 5));
    
    // Insert feature flags
    await insertFeatureFlags();
    
    print('\n✅ Collections fixed!');
  }

  Future<void> fixFeatureFlagsAttributes() async {
    print('📌 Fixing feature_flags collection...');
    
    // Add enabled attribute without default for required
    await createAttribute('feature_flags', 'boolean', 'enabled', required: false, defaultValue: false);
  }

  Future<void> fixWebhookEventsAttributes() async {
    print('📌 Fixing webhook_events collection...');
    
    // Add source attribute without default for required
    await createAttribute('webhook_events', 'string', 'source', size: 50, required: false, defaultValue: 'revenuecat');
  }

  Future<void> fixSubscriptionRecordsAttributes() async {
    print('📌 Fixing subscription_records collection...');
    
    // Add isTestSubscription attribute without default for required
    await createAttribute('subscription_records', 'boolean', 'isTestSubscription', required: false, defaultValue: false);
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

      // Only add default value if not required
      if (!required && defaultValue != null) {
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
        print('  ✓ Added $key attribute');
      } else if (response.statusCode == 409) {
        print('  ⚠️  $key attribute already exists');
      } else {
        final error = jsonDecode(response.body);
        print('  ❌ Failed to add $key: ${error['message']}');
      }
    } catch (e) {
      print('  ❌ Error adding attribute $key: $e');
    }
  }

  Future<void> insertFeatureFlags() async {
    print('\n📌 Inserting feature flags...');
    
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
      try {
        final response = await http.post(
          Uri.parse('$endpoint/databases/$databaseId/collections/feature_flags/documents'),
          headers: headers,
          body: jsonEncode({
            'documentId': 'unique()',
            'data': flag,
          }),
        );

        if (response.statusCode == 201) {
          print('  ✓ Created flag: ${flag['name']} = ${flag['enabled']}');
        } else {
          final error = jsonDecode(response.body);
          print('  ❌ Failed to create ${flag['name']}: ${error['message']}');
        }
      } catch (e) {
        print('  ❌ Error creating flag ${flag['name']}: $e');
      }
    }
  }
}

void main() async {
  final fix = FixCollections();
  await fix.run();
}