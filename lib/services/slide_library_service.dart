import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:appwrite/appwrite.dart';
import '../models/debate_source.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'package:get_it/get_it.dart';

class SlideLibraryService {
  Future<AppwriteService> get _appwrite async {
    try {
      // Since AppwriteService is registered as async, we need to wait for it
      return await GetIt.instance.getAsync<AppwriteService>();
    } catch (e) {
      _logger.warning('⚠️ GetIt AppwriteService not available, using singleton: $e');
      return AppwriteService();
    }
  }
  static final _logger = AppLogger();

  /// Get all slide libraries for the current user
  Future<List<UserSlideLibrary>> getUserSlides() async {
    try {
      final appwrite = await _appwrite;
      final currentUser = await appwrite.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final documents = await appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.userSlideLibraryCollection,
        queries: [
          Query.equal('userId', currentUser.$id),
          Query.orderDesc('\$createdAt'),
        ],
      );

      final slides = <UserSlideLibrary>[];
      for (final doc in documents.documents) {
        slides.add(UserSlideLibrary.fromJson({
          'id': doc.$id,
          'userId': doc.data['userId'],
          'title': doc.data['title'],
          'fileName': doc.data['fileName'],
          'fileId': doc.data['fileId'],
          'totalSlides': doc.data['totalSlides'],
          'thumbnailUrl': doc.data['thumbnailUrl'],
          'description': doc.data['description'],
          'fileType': doc.data['fileType'] ?? 'pdf',
          'uploadedAt': doc.data['uploadedAt'],
          'lastUsedAt': doc.data['lastUsedAt'],
        }));
      }

      _logger.info('📋 Loaded ${slides.length} slide libraries for user');
      return slides;
    } catch (e) {
      if (e.toString().contains('collection_not_found')) {
        _logger.warning('⚠️ Slide library collection not found - returning empty list');
        return <UserSlideLibrary>[]; // Return empty list when collection doesn't exist
      } else if (e.toString().contains('user_unauthorized')) {
        _logger.warning('⚠️ User not authorized - may need to log in or collection permissions need adjustment');
        throw Exception('Please log in to access your slide library');
      }
      _logger.error('❌ Error getting user slides: $e');
      rethrow;
    }
  }

  /// Pick and upload slides using file picker
  Future<UserSlideLibrary?> pickAndUploadSlides() async {
    try {
      // Use file picker to select PDF files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result?.files.single.path == null) {
        _logger.info('📋 User cancelled file picking');
        return null;
      }

      final file = result!.files.single;
      final filePath = file.path!;
      final fileName = file.name;

      _logger.info('📋 Selected file: $fileName');

      // Validate file size (max 50MB)
      final fileSize = await File(filePath).length();
      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('File size must be less than 50MB');
      }

      return await _processAndUploadFile(File(filePath), fileName);
    } catch (e) {
      _logger.error('❌ Error picking and uploading slides: $e');
      rethrow;
    }
  }

  /// Handle files shared via AirDrop or file sharing
  Future<UserSlideLibrary?> handleSharedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Shared file not found');
      }

      final fileName = file.path.split('/').last;
      _logger.info('📋 Processing shared file: $fileName');

      // Validate file type
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        throw Exception('Only PDF files are supported');
      }

      return await _processAndUploadFile(file, fileName);
    } catch (e) {
      _logger.error('❌ Error handling shared file: $e');
      rethrow;
    }
  }

  /// Process and upload a file to Appwrite
  Future<UserSlideLibrary> _processAndUploadFile(File file, String fileName) async {
    try {
      final appwrite = await _appwrite;
      final currentUser = await appwrite.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      _logger.info('📋 Starting file upload process for: $fileName');

      // Read file as bytes
      final fileBytes = await file.readAsBytes();

      // Upload to Appwrite storage
      final uploadedFile = await appwrite.storage.createFile(
        bucketId: AppwriteConstants.debateSlidesBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: fileBytes,
          filename: fileName,
        ),
      );

      _logger.info('📋 File uploaded to storage with ID: ${uploadedFile.$id}');

      // Get PDF page count (simplified - in real implementation you'd use a PDF library)
      final totalSlides = await _estimatePdfPageCount(fileBytes);

      // Create slide library entry in database
      final title = _generateTitleFromFilename(fileName);
      
      late final dynamic slideLibraryDoc;
      try {
        slideLibraryDoc = await appwrite.databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.userSlideLibraryCollection,
          documentId: ID.unique(),
          data: {
            'userId': currentUser.$id,
            'title': title,
            'fileName': fileName,
            'fileId': uploadedFile.$id,
            'totalSlides': totalSlides,
            'fileType': 'pdf',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        if (e.toString().contains('collection_not_found')) {
          throw Exception(
            'Slide library collection not set up. Please ask an administrator to run the collection setup script or create the "user_slide_library" collection manually in Appwrite console.'
          );
        }
        rethrow;
      }

      final slideLibrary = UserSlideLibrary.fromJson({
        'id': slideLibraryDoc.$id,
        'userId': currentUser.$id,
        'title': title,
        'fileName': fileName,
        'fileId': uploadedFile.$id,
        'totalSlides': totalSlides,
        'fileType': 'pdf',
        'uploadedAt': DateTime.now().toIso8601String(),
      });

      _logger.info('📋 Successfully created slide library: $title');
      return slideLibrary;
    } catch (e) {
      _logger.error('❌ Error processing and uploading file: $e');
      rethrow;
    }
  }

  /// Update slide details
  Future<void> updateSlideDetails(String slideId, String title, String? description) async {
    try {
      final appwrite = await _appwrite;
      await appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.userSlideLibraryCollection,
        documentId: slideId,
        data: {
          'title': title,
          'description': description?.isNotEmpty == true ? description : null,
        },
      );
      _logger.info('📋 Updated slide details for: $slideId');
    } catch (e) {
      _logger.error('❌ Error updating slide details: $e');
      rethrow;
    }
  }

  /// Delete a slide library
  Future<void> deleteSlideLibrary(String slideId) async {
    try {
      final appwrite = await _appwrite;
      // Get the slide library document first to get file ID
      final doc = await appwrite.databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.userSlideLibraryCollection,
        documentId: slideId,
      );

      final fileId = doc.data['fileId'] as String;

      // Delete from storage
      try {
        await appwrite.storage.deleteFile(
          bucketId: AppwriteConstants.debateSlidesBucket,
          fileId: fileId,
        );
        _logger.info('📋 Deleted file from storage: $fileId');
      } catch (storageError) {
        _logger.warning('⚠️ Could not delete file from storage: $storageError');
        // Continue with database deletion even if storage deletion fails
      }

      // Delete from database
      await appwrite.databases.deleteDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.userSlideLibraryCollection,
        documentId: slideId,
      );

      _logger.info('📋 Successfully deleted slide library: $slideId');
    } catch (e) {
      _logger.error('❌ Error deleting slide library: $e');
      rethrow;
    }
  }

  /// Share slide library in a debate room
  Future<void> shareSlideInRoom(String slideId, String roomId) async {
    try {
      final appwrite = await _appwrite;
      final currentUser = await appwrite.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify the slide library exists
      await appwrite.databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.userSlideLibraryCollection,
        documentId: slideId,
      );

      // Update last used timestamp
      await appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.userSlideLibraryCollection,
        documentId: slideId,
        data: {
          'lastUsedAt': DateTime.now().toIso8601String(),
        },
      );

      // TODO: Integrate with existing presentation sharing system
      // This would connect to the LiveKitMaterialSyncService to share the slides
      
      _logger.info('📋 Shared slide library $slideId in room $roomId');
    } catch (e) {
      _logger.error('❌ Error sharing slide in room: $e');
      rethrow;
    }
  }

  /// Generate a user-friendly title from filename
  String _generateTitleFromFilename(String fileName) {
    // Remove extension
    final nameWithoutExtension = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
    
    // Replace underscores and hyphens with spaces
    String title = nameWithoutExtension.replaceAll(RegExp(r'[_-]'), ' ');
    
    // Capitalize first letter of each word
    title = title.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    // Limit length
    if (title.length > 50) {
      title = '${title.substring(0, 50).trim()}...';
    }
    
    return title.isNotEmpty ? title : 'Untitled Presentation';
  }

  /// Estimate PDF page count (simplified implementation)
  /// In a real implementation, you'd use a proper PDF library
  Future<int> _estimatePdfPageCount(Uint8List fileBytes) async {
    try {
      // Very basic estimation - count occurrences of "/Type /Page"
      final fileString = String.fromCharCodes(fileBytes);
      final pageMatches = RegExp(r'/Type\s*/Page[^s]').allMatches(fileString);
      final pageCount = pageMatches.length;
      
      // Return at least 1 page, max 1000 for safety
      return pageCount > 0 ? pageCount.clamp(1, 1000) : 1;
    } catch (e) {
      _logger.warning('⚠️ Could not estimate PDF page count: $e');
      return 1; // Default to 1 page if estimation fails
    }
  }
}