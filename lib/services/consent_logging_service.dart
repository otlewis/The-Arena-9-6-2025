import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:arena/services/appwrite_service.dart';
import 'package:arena/services/email_templates.dart';
import 'dart:convert';

class ConsentLoggingService {
  static const String collectionId = 'consent_logs';
  
  static Future<void> logConsentEvent({
    required String userId,
    required String action, // 'given', 'revoked', 'suspended', 'reactivated'
    String? parentEmail,
    String? reason,
    String? tosVersion,
    String? privacyVersion,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final appwriteService = AppwriteService();
      
      // Create bulletproof schema structure
      final metadata = {
        'tosVersion': tosVersion ?? '1.1',
        'privacyVersion': privacyVersion ?? '1.1',
        if (reason != null) 'reason': reason,
        if (additionalMetadata != null) ...additionalMetadata,
      };
      
      await appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: collectionId,
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'parentEmail': parentEmail,
          'action': action,
          'timestamp': DateTime.now().toIso8601String(),
          'metadata': jsonEncode(metadata),
        },
      );
      
      print('Consent event logged: $action for user $userId');
    } catch (e) {
      print('Failed to log consent event: $e');
      // Don't throw - logging failures shouldn't break app flow
    }
  }
  
  static Future<List<Document>> getConsentHistory(String userId) async {
    try {
      final appwriteService = AppwriteService();
      
      final response = await appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: collectionId,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      return response.documents;
    } catch (e) {
      print('Failed to get consent history: $e');
      return [];
    }
  }
  
  static Future<void> suspendTeenAccount({
    required String userId,
    required String reason,
    String? parentEmail,
  }) async {
    try {
      final appwriteService = AppwriteService();
      
      // Update user's account status in metadata
      final currentUser = await appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
      );
      
      final metadata = Map<String, dynamic>.from(currentUser.data);
      metadata['accountSuspended'] = true;
      metadata['suspensionReason'] = reason;
      metadata['suspensionDate'] = DateTime.now().toIso8601String();
      metadata['parentalConsentRevoked'] = true;
      
      await appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {'metadata': metadata},
      );
      
      // Log the suspension event
      await logConsentEvent(
        userId: userId,
        action: 'suspended',
        parentEmail: parentEmail,
        reason: reason,
        tosVersion: metadata['tosVersion'] ?? '1.1',
        privacyVersion: metadata['privacyVersion'] ?? '1.1',
        additionalMetadata: {
          'suspensionType': 'parental_consent_revoked',
          'previousConsentDate': metadata['parentalConsentDate'],
        },
      );
      
      print('Teen account suspended for user: $userId');
    } catch (e) {
      print('Failed to suspend teen account: $e');
      throw e; // Account suspension failures should be thrown
    }
  }
  
  static Future<void> reactivateTeenAccount({
    required String userId,
    String? parentEmail,
  }) async {
    try {
      final appwriteService = AppwriteService();
      
      // Update user's account status in metadata
      final currentUser = await appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
      );
      
      final metadata = Map<String, dynamic>.from(currentUser.data);
      metadata['accountSuspended'] = false;
      metadata['suspensionReason'] = null;
      metadata['suspensionDate'] = null;
      metadata['parentalConsentRevoked'] = false;
      metadata['parentalConsentGiven'] = true;
      metadata['parentalConsentDate'] = DateTime.now().toIso8601String();
      
      await appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {'metadata': metadata},
      );
      
      // Log the reactivation event
      await logConsentEvent(
        userId: userId,
        action: 'reactivated',
        parentEmail: parentEmail,
        reason: 'Account reactivated with renewed parental consent',
        tosVersion: metadata['tosVersion'] ?? '1.1',
        privacyVersion: metadata['privacyVersion'] ?? '1.1',
        additionalMetadata: {
          'reactivationType': 'parental_consent_renewed',
          'previousSuspensionDate': metadata['suspensionDate'],
        },
      );
      
      print('Teen account reactivated for user: $userId');
    } catch (e) {
      print('Failed to reactivate teen account: $e');
      throw e;
    }
  }

  /// Automated re-consent handling for policy updates
  static Future<void> flagTeenAccountsForReconsent({
    required String newTosVersion,
    required String newPrivacyVersion,
    String reason = 'Policy update requires renewed parental consent',
  }) async {
    try {
      final appwriteService = AppwriteService();

      // Get all teen users with current consent
      final response = await appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('isTeenUser', true),
          Query.equal('parentalConsentGiven', true),
          Query.equal('accountSuspended', [false, null]),
        ],
      );

      for (final user in response.documents) {
        final metadata = Map<String, dynamic>.from(user.data);
        final currentTos = metadata['tosVersion'] ?? '1.0';
        final currentPrivacy = metadata['privacyVersion'] ?? '1.0';

        // Check if user needs to re-consent
        bool needsReconsent = false;
        if (currentTos != newTosVersion || currentPrivacy != newPrivacyVersion) {
          needsReconsent = true;
        }

        if (needsReconsent) {
          // Flag account for re-consent
          metadata['parentalConsentGiven'] = false;
          metadata['requiresReconsent'] = true;
          metadata['reconsentReason'] = reason;
          metadata['reconsentRequiredDate'] = DateTime.now().toIso8601String();
          metadata['previousTosVersion'] = currentTos;
          metadata['previousPrivacyVersion'] = currentPrivacy;

          await appwriteService.databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: 'users',
            documentId: user.$id,
            data: {'metadata': metadata},
          );

          // Log the re-consent requirement
          await logConsentEvent(
            userId: user.$id,
            action: 'revoked',
            parentEmail: metadata['parentEmail'],
            reason: 'Automatic re-consent required due to policy update',
            tosVersion: newTosVersion,
            privacyVersion: newPrivacyVersion,
            additionalMetadata: {
              'reconsentType': 'policy_update',
              'previousTosVersion': currentTos,
              'previousPrivacyVersion': currentPrivacy,
            },
          );

          print('Flagged teen account ${user.$id} for re-consent');
        }
      }

      print('Policy update re-consent flagging completed');
    } catch (e) {
      print('Failed to flag accounts for re-consent: $e');
      throw e;
    }
  }

  /// Check if a teen user needs to re-consent
  static Future<bool> needsReconsent(String userId) async {
    try {
      final appwriteService = AppwriteService();
      
      final user = await appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
      );

      final metadata = Map<String, dynamic>.from(user.data);
      return metadata['requiresReconsent'] == true;
    } catch (e) {
      print('Failed to check re-consent status: $e');
      return false;
    }
  }

  /// Production-ready parental notification system
  static Future<void> sendParentalNotification({
    required String parentEmail,
    required String notificationType, // 'account_created', 'policy_update', 'account_suspended'
    required String teenName,
    String parentName = '',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      String subject = '';
      String htmlContent = '';
      String textContent = '';
      
      // Generate appropriate email content based on notification type
      switch (notificationType) {
        case 'account_created':
          subject = 'Your teen has joined The Arena DTD - Action Required';
          final signupDate = additionalData?['signupDate'] ?? DateTime.now().toIso8601String();
          final userAge = additionalData?['userAge'] ?? 16;
          
          htmlContent = EmailTemplates.teenAccountCreated(
            teenName: teenName,
            parentName: parentName,
            teenAge: userAge,
            signupDate: _formatDate(signupDate),
            appStoreUrl: additionalData?['appStoreUrl'],
          );
          
          textContent = EmailTemplates.teenAccountCreatedPlainText(
            teenName: teenName,
            parentName: parentName,
            teenAge: userAge,
            signupDate: _formatDate(signupDate),
          );
          break;
          
        case 'policy_update':
          subject = 'The Arena DTD Policy Update - Your Action Required';
          final newVersion = additionalData?['newVersion'] ?? '1.2';
          final updateDate = additionalData?['updateDate'] ?? DateTime.now().toIso8601String();
          
          htmlContent = EmailTemplates.policyUpdateNotification(
            teenName: teenName,
            parentName: parentName,
            newVersion: newVersion,
            updateDate: _formatDate(updateDate),
          );
          break;
          
        case 'account_suspended':
          subject = 'URGENT: Your teen\'s Arena DTD account has been suspended';
          final reason = additionalData?['reason'] ?? 'Violation of Terms of Service';
          final suspensionDate = additionalData?['suspensionDate'] ?? DateTime.now().toIso8601String();
          
          htmlContent = EmailTemplates.accountSuspendedNotification(
            teenName: teenName,
            parentName: parentName,
            reason: reason,
            suspensionDate: _formatDate(suspensionDate),
          );
          break;
          
        default:
          print('Unknown notification type: $notificationType');
          return;
      }
      
      // Send the email using production email service
      final emailSent = await EmailService.sendParentalNotificationEmail(
        to: parentEmail,
        subject: subject,
        htmlContent: htmlContent,
        textContent: textContent,
      );
      
      if (emailSent) {
        print('✅ Parental notification sent: $notificationType to $parentEmail');
        
        // Log the notification in our audit trail
        final notificationData = {
          'parentEmail': parentEmail,
          'notificationType': notificationType,
          'teenName': teenName,
          'timestamp': DateTime.now().toIso8601String(),
          'emailSent': true,
          'subject': subject,
          'additionalData': additionalData,
        };
        
        // Could store in notifications audit collection
        print('📊 Notification logged: $notificationData');
      } else {
        print('❌ Failed to send parental notification to $parentEmail');
      }
      
    } catch (e) {
      print('Failed to send parental notification: $e');
      // Don't throw - notification failures shouldn't break app flow
      
      // Could implement retry logic here:
      // - Queue failed emails for retry
      // - Use exponential backoff
      // - Alert administrators of persistent failures
    }
  }
  
  /// Helper method to format dates for email display
  static String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }
}