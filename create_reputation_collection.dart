import 'dart:io';
import 'dart:convert';

void main() async {
  print('Creating reputation_logs collection via Appwrite REST API...');
  
  const endpoint = 'https://cloud.appwrite.io/v1';
  const projectId = '683a37a8003719978879';
  const apiKey = 'standard_a2bb604b91b6e0ad49c4b8b3c0c59c83c9a7ee4ce4b2a784c9f05d9ad84c0fb5f3e8b05e8c4e8f79b3f5e8b05e8c4e8f79b3f5e8b05e8c4e8f79b3f5e8b05e8c4e8';
  const databaseId = 'arena_db';
  
  final httpClient = HttpClient();
  
  try {
    // Create collection
    print('Creating collection...');
    var request = await httpClient.postUrl(Uri.parse('$endpoint/databases/$databaseId/collections'));
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);
    request.headers.set('Content-Type', 'application/json');
    
    var collectionBody = jsonEncode({
      'collectionId': 'reputation_logs',
      'name': 'Reputation Logs',
      'permissions': [
        'read("any")',
        'create("users")',
        'update("users")',
        'delete("users")'
      ],
      'documentSecurity': true
    });
    
    request.write(collectionBody);
    var response = await request.close();
    var responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 201) {
      print('✅ Collection created successfully');
    } else {
      print('❌ Failed to create collection: $responseBody');
      return;
    }
    
    // Wait for collection to be ready
    await Future.delayed(Duration(seconds: 3));
    
    // Create attributes
    final attributes = [
      {'key': 'userId', 'type': 'string', 'size': 255, 'required': true},
      {'key': 'pointsChange', 'type': 'integer', 'required': true},
      {'key': 'newTotal', 'type': 'integer', 'required': true},
      {'key': 'reason', 'type': 'string', 'size': 500, 'required': true},
      {'key': 'timestamp', 'type': 'datetime', 'required': true},
    ];
    
    for (var attr in attributes) {
      print('Creating ${attr['key']} attribute...');
      
      var attrRequest = await httpClient.postUrl(
        Uri.parse('$endpoint/databases/$databaseId/collections/reputation_logs/attributes/${attr['type']}'
      ));
      attrRequest.headers.set('X-Appwrite-Project', projectId);
      attrRequest.headers.set('X-Appwrite-Key', apiKey);
      attrRequest.headers.set('Content-Type', 'application/json');
      
      var attrBody = jsonEncode(attr);
      attrRequest.write(attrBody);
      
      var attrResponse = await attrRequest.close();
      var attrResponseBody = await attrResponse.transform(utf8.decoder).join();
      
      if (attrResponse.statusCode == 202) {
        print('✅ Created ${attr['key']} attribute');
      } else {
        print('❌ Failed to create ${attr['key']} attribute: $attrResponseBody');
      }
      
      await Future.delayed(Duration(seconds: 2));
    }
    
    // Wait for attributes to be ready
    print('Waiting for attributes to be ready...');
    await Future.delayed(Duration(seconds: 10));
    
    // Create indexes
    final indexes = [
      {'key': 'userId_index', 'type': 'key', 'attributes': ['userId']},
      {'key': 'timestamp_index', 'type': 'key', 'attributes': ['timestamp']},
      {'key': 'userId_timestamp_index', 'type': 'key', 'attributes': ['userId', 'timestamp']},
    ];
    
    for (var index in indexes) {
      print('Creating ${index['key']} index...');
      
      var indexRequest = await httpClient.postUrl(
        Uri.parse('$endpoint/databases/$databaseId/collections/reputation_logs/indexes')
      );
      indexRequest.headers.set('X-Appwrite-Project', projectId);
      indexRequest.headers.set('X-Appwrite-Key', apiKey);
      indexRequest.headers.set('Content-Type', 'application/json');
      
      var indexBody = jsonEncode(index);
      indexRequest.write(indexBody);
      
      var indexResponse = await indexRequest.close();
      var indexResponseBody = await indexResponse.transform(utf8.decoder).join();
      
      if (indexResponse.statusCode == 202) {
        print('✅ Created ${index['key']} index');
      } else {
        print('❌ Failed to create ${index['key']} index: $indexResponseBody');
      }
      
      await Future.delayed(Duration(seconds: 2));
    }
    
    print('\n🎉 reputation_logs collection created successfully!');
    print('Collection ID: reputation_logs');
    print('Attributes: userId, pointsChange, newTotal, reason, timestamp');
    print('Indexes: userId, timestamp, userId+timestamp');
    
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    httpClient.close();
  }
}