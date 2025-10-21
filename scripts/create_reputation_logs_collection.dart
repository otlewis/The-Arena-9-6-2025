// ⚠️ DEPRECATED SCRIPT - DO NOT USE ⚠️
// This script uses old Appwrite SDK methods that are no longer available in v18.0.0
// The methods setKey, createCollection, createStringAttribute, etc. have been removed
// For working collection creation, use create_reputation_collection.dart which uses REST API
// Or wait for TablesDB support to be added to the Flutter SDK

/*
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

// Simple console logger for scripts
void logInfo(String message) {
  if (kDebugMode || !kIsWeb) {
    debugPrint('INFO: $message');
  }
}

void logError(String message) {
  if (kDebugMode || !kIsWeb) {
    debugPrint('ERROR: $message');
  }
}

void logSuccess(String message) {
  if (kDebugMode || !kIsWeb) {
    debugPrint('SUCCESS: $message');
  }
}

void main() async {
  // Initialize Appwrite client
  final client = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('683a37a8003719978879')
    .setKey('standard_a2bb604b91b6e0ad49c4b8b3c0c59c83c9a7ee4ce4b2a784c9f05d9ad84c0fb5f3e8b05e8c4e8f79b3f5e8b05e8c4e8f79b3f5e8b05e8c4e8f79b3f5e8b05e8c4e8');

  final databases = Databases(client);
  
  try {
    logInfo('Creating reputation_logs collection...');
    
    // Note: Appwrite SDK methods are deprecated but TablesDB is not yet available
    // This script will need updating when TablesDB support is added to Flutter SDK
    final collection = await databases.createCollection(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      name: 'Reputation Logs',
      permissions: [
        Permission.read(Role.any()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
      documentSecurity: true,
    );
    
    logSuccess('Collection created: ${collection.name}');
    
    // Create attributes
    logInfo('Creating attributes...');
    
    // userId attribute
    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'userId',
      size: 255,
      required: true,
    );
    logSuccess('Created userId attribute');
    
    // Wait a moment for attribute to be ready
    await Future.delayed(Duration(seconds: 2));
    
    // pointsChange attribute
    await databases.createIntegerAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'pointsChange',
      required: true,
    );
    logSuccess('Created pointsChange attribute');
    
    await Future.delayed(Duration(seconds: 2));
    
    // newTotal attribute
    await databases.createIntegerAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'newTotal',
      required: true,
    );
    logSuccess('Created newTotal attribute');
    
    await Future.delayed(Duration(seconds: 2));
    
    // reason attribute
    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'reason',
      size: 500,
      required: true,
    );
    logSuccess('Created reason attribute');
    
    await Future.delayed(Duration(seconds: 2));
    
    // timestamp attribute
    await databases.createDatetimeAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'timestamp',
      required: true,
    );
    logSuccess('Created timestamp attribute');
    
    // Wait for all attributes to be ready before creating indexes
    logInfo('Waiting for attributes to be ready...');
    await Future.delayed(Duration(seconds: 10));
    
    // Create indexes
    logInfo('Creating indexes...');
    
    // Index for userId
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'userId_index',
      type: 'key',
      attributes: ['userId'],
    );
    logSuccess('Created userId index');
    
    await Future.delayed(Duration(seconds: 2));
    
    // Index for timestamp
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'timestamp_index',
      type: 'key',
      attributes: ['timestamp'],
    );
    logSuccess('Created timestamp index');
    
    await Future.delayed(Duration(seconds: 2));
    
    // Compound index for userId + timestamp
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'userId_timestamp_index',
      type: 'key',
      attributes: ['userId', 'timestamp'],
    );
    logSuccess('Created userId_timestamp compound index');
    
    logSuccess('\nreputation_logs collection created successfully!');
    logInfo('Collection ID: reputation_logs');
    logInfo('Attributes: userId, pointsChange, newTotal, reason, timestamp');
    logInfo('Indexes: userId, timestamp, userId+timestamp');
    
  } catch (e) {
    logError('Error creating collection: $e');
  }
}
*/

import 'dart:developer' as developer;

void main() {
  developer.log('⚠️ This deprecated script is disabled to prevent compilation errors.');
  developer.log('Use the REST API or wait for TablesDB support in the Flutter SDK.');
}