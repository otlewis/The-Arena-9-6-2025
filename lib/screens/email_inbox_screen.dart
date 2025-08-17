import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/sound_service.dart';
import '../constants/appwrite.dart';
import '../models/arena_email.dart';
import '../models/user_profile.dart';
import 'email_compose_screen.dart';
import 'package:intl/intl.dart';

class EmailInboxScreen extends StatefulWidget {
  const EmailInboxScreen({super.key});

  @override
  State<EmailInboxScreen> createState() => _EmailInboxScreenState();
}

class _EmailInboxScreenState extends State<EmailInboxScreen> with TickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  final SoundService _soundService = SoundService();
  late TabController _tabController;
  
  List<ArenaEmail> _inboxEmails = [];
  List<ArenaEmail> _sentEmails = [];
  List<EmailDraft> _drafts = [];
  
  String? _currentUserId;
  String? _currentUsername;
  bool _isLoading = true;
  RealtimeSubscription? _subscription;
  
  // Colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color borderColor = Color(0xFF2D2D2D);
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeSoundService();
    _loadCurrentUser();
    _subscribeToEmails();
  }
  
  Future<void> _initializeSoundService() async {
    await _soundService.initialize();
    debugPrint('SoundService initialized for email inbox');
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _subscription?.close();
    super.dispose();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _appwrite.account.get();
      final profile = await _appwrite.getUserProfile(user.$id);
      
      setState(() {
        _currentUserId = user.$id;
        _currentUsername = profile?.name ?? user.name;
      });
      
      await _loadEmails();
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }
  
  Future<void> _loadEmails() async {
    if (_currentUserId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      debugPrint('Loading emails for user: $_currentUserId');
      
      // Simple approach: Load ALL emails and filter in app
      final allEmailsResponse = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.arenaEmailsCollection,
        queries: [
          Query.orderDesc('createdAt'),
          Query.limit(100), // Limit to recent 100 emails
        ],
      );
      
      debugPrint('Total emails in database: ${allEmailsResponse.documents.length}');
      
      // Filter emails in the app
      final allEmails = allEmailsResponse.documents
          .map((doc) => ArenaEmail.fromJson(doc.data))
          .toList();
      
      final newInboxEmails = allEmails
          .where((email) => email.recipientId == _currentUserId! && !email.isArchived)
          .toList();
      
      final newSentEmails = allEmails
          .where((email) => email.senderId == _currentUserId!)
          .toList();
      
      debugPrint('Filtered inbox emails: ${newInboxEmails.length} for user $_currentUserId');
      debugPrint('Filtered sent emails: ${newSentEmails.length} for user $_currentUserId');
      
      // Debug sent emails
      for (var email in newSentEmails) {
        debugPrint('Sent email: to=${email.recipientUsername}, subject=${email.subject}, date=${email.createdAt}');
      }
      
      // Note: Sound is now played in the real-time subscription when a new email arrives
      
      for (var email in newInboxEmails) {
        debugPrint('Inbox email: sender=${email.senderId}, recipient=${email.recipientId}, subject=${email.subject}');
      }
      
      // Load drafts
      await _loadDrafts();
      
      setState(() {
        _inboxEmails = newInboxEmails;
        _sentEmails = newSentEmails;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading emails: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadDrafts() async {
    try {
      final draftsResponse = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.emailDraftsCollection,
        queries: [
          Query.equal('userId', _currentUserId!),
          Query.orderDesc('lastModified'),
          Query.limit(50),
        ],
      );
      
      final drafts = draftsResponse.documents
          .map((doc) => EmailDraft.fromJson(doc.data))
          .toList();
      
      setState(() {
        _drafts = drafts;
      });
      
      debugPrint('Loaded ${drafts.length} drafts');
    } catch (e) {
      debugPrint('Error loading drafts: $e');
      // Collection might not exist yet
      setState(() {
        _drafts = [];
      });
    }
  }
  
  void _subscribeToEmails() {
    try {
      final realtime = _appwrite.realtime;
      _subscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.arenaEmailsCollection}.documents'
      ]);
      
      _subscription!.stream.listen((response) {
        debugPrint('Email subscription event received: ${response.events}');
        
        // Check if this is a new email for the current user
        if (response.events.contains('databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.arenaEmailsCollection}.documents.*.create')) {
          // New email created, check if it's for current user
          final payload = response.payload;
          if (payload['recipientId'] == _currentUserId) {
            debugPrint('New email received for current user! Playing sound...');
            _soundService.playEmailSound();
          }
        }
        
        _loadEmails(); // Reload emails on any change
      });
    } catch (e) {
      debugPrint('Error subscribing to emails: $e');
    }
  }
  
  Future<void> _markAsRead(ArenaEmail email) async {
    if (email.isRead) return;
    
    try {
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.arenaEmailsCollection,
        documentId: email.id,
        data: {'isRead': true},
      );
    } catch (e) {
      debugPrint('Error marking email as read: $e');
    }
  }
  
  void _composeEmail({UserProfile? recipient}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailComposeScreen(
          currentUserId: _currentUserId!,
          currentUsername: _currentUsername!,
          recipient: recipient,
        ),
      ),
    );
    
    // If email was sent, switch to sent tab
    if (result == 'sent' && mounted) {
      _tabController.animateTo(1); // Switch to Sent tab
    }
  }
  
  void _openEmail(ArenaEmail email) {
    _markAsRead(email);
    _showEmailModal(email);
  }
  
  void _showEmailModal(ArenaEmail email) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Email header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From: ${email.senderEmail}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'To: ${email.recipientEmail}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          
                          // Show confirmation dialog
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: cardBackground,
                                title: const Text(
                                  'Delete Email',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'Are you sure you want to delete this email?',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (shouldDelete == true && mounted) {
                            
                            try {
                              await _appwrite.databases.deleteDocument(
                                databaseId: AppwriteConstants.databaseId,
                                collectionId: AppwriteConstants.arenaEmailsCollection,
                                documentId: email.id,
                              );
                              
                              if (mounted) {
                                setState(() {
                                  _inboxEmails.removeWhere((e) => e.id == email.id);
                                  _sentEmails.removeWhere((e) => e.id == email.id);
                                });
                                
                                nav.pop(); // Close the modal
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Email deleted'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error deleting email: $e');
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete email: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        tooltip: 'Delete email',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    email.subject,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(email.createdAt),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            // Email body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  email.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            
            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: darkBackground,
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        nav.pop();
                        // Get sender's profile for reply
                        final senderProfile = await _appwrite.getUserProfile(email.senderId);
                        if (mounted) {
                          nav.push(
                            MaterialPageRoute(
                              builder: (context) => EmailComposeScreen(
                                currentUserId: _currentUserId!,
                                currentUsername: _currentUsername!,
                                replyTo: email,
                                recipient: senderProfile,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.reply),
                      label: const Text('Reply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmailComposeScreen(
                              currentUserId: _currentUserId!,
                              currentUsername: _currentUsername!,
                              forwardEmail: email,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.forward),
                      label: const Text('Forward'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentPurple,
                        side: const BorderSide(color: accentPurple),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    // Format: MM/dd/yy h:mm a (e.g., "8/16/25 1:00 PM")
    return DateFormat('M/d/yy h:mm a').format(date);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Arena Mail',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_currentUsername != null)
              Text(
                '${_currentUsername!.toLowerCase()}@arena.dtd',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          // Debug button to test email sound
          IconButton(
            icon: const Icon(Icons.volume_up, color: Colors.white54),
            onPressed: () {
              debugPrint('Testing email sound...');
              _soundService.playEmailSound();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email sound played'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Test email sound',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentPurple,
          labelColor: accentPurple,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              text: 'Inbox',
              icon: _inboxEmails.where((e) => !e.isRead).isNotEmpty
                  ? Badge(
                      label: Text(
                        _inboxEmails.where((e) => !e.isRead).length.toString(),
                      ),
                      child: const Icon(Icons.inbox),
                    )
                  : const Icon(Icons.inbox),
            ),
            const Tab(
              text: 'Sent',
              icon: Icon(Icons.send),
            ),
            const Tab(
              text: 'Drafts',
              icon: Icon(Icons.drafts),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: accentPurple,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Inbox tab
                _buildEmailList(_inboxEmails, isInbox: true),
                
                // Sent tab
                _buildEmailList(_sentEmails, isInbox: false),
                
                // Drafts tab
                _buildDraftsList(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _composeEmail(),
        backgroundColor: accentPurple,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
  
  Widget _buildEmailList(List<ArenaEmail> emails, {bool isInbox = false, bool isDraft = false}) {
    if (emails.isEmpty) {
      return Center(
        child: Text(
          isInbox ? 'No emails yet' : isDraft ? 'No drafts' : 'No sent emails',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: emails.length,
      itemBuilder: (context, index) {
        final email = emails[index];
        return _buildEmailCard(email, isInbox: isInbox);
      },
    );
  }
  
  Widget _buildEmailCard(ArenaEmail email, {bool isInbox = false}) {
    final isUnread = isInbox && !email.isRead;
    
    return Card(
      color: cardBackground,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Dismissible(
        key: Key(email.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          // Show confirmation dialog
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: cardBackground,
                title: const Text(
                  'Delete Email',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Are you sure you want to delete this email?',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            },
          );
        },
        onDismissed: (direction) async {
          // Delete email from database
          try {
            await _appwrite.databases.deleteDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.arenaEmailsCollection,
              documentId: email.id,
            );
            
            setState(() {
              if (isInbox) {
                _inboxEmails.removeWhere((e) => e.id == email.id);
              } else {
                _sentEmails.removeWhere((e) => e.id == email.id);
              }
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${isInbox ? 'Inbox' : 'Sent'} email deleted'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error deleting email: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete email: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: ListTile(
          onTap: () => _openEmail(email),
          leading: CircleAvatar(
            backgroundColor: accentPurple.withValues(alpha: 0.2),
            child: Text(
              (isInbox ? email.senderUsername : email.recipientUsername)[0].toUpperCase(),
              style: TextStyle(
                color: accentPurple,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          title: Text(
            isInbox ? email.senderUsername : 'To: ${email.recipientUsername}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email.subject,
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                email.body,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(email.createdAt),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              if (email.emailType != 'personal')
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTypeColor(email.emailType).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    email.emailType,
                    style: TextStyle(
                      color: _getTypeColor(email.emailType),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getTypeColor(String type) {
    switch (type) {
      case 'challenge':
        return Colors.orange;
      case 'results':
        return Colors.green;
      case 'feedback':
        return Colors.blue;
      case 'rematch':
        return Colors.purple;
      default:
        return accentPurple;
    }
  }
  
  Widget _buildDraftsList() {
    if (_drafts.isEmpty) {
      return const Center(
        child: Text(
          'No drafts',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        return _buildDraftCard(draft);
      },
    );
  }
  
  Widget _buildDraftCard(EmailDraft draft) {
    return Card(
      color: cardBackground,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Dismissible(
        key: Key(draft.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) async {
          // Delete draft
          try {
            await _appwrite.databases.deleteDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.emailDraftsCollection,
              documentId: draft.id,
            );
            setState(() {
              _drafts.removeWhere((d) => d.id == draft.id);
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draft deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error deleting draft: $e');
          }
        },
        child: ListTile(
          onTap: () async {
            // Open draft in compose screen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailComposeScreen(
                  currentUserId: _currentUserId!,
                  currentUsername: _currentUsername!,
                  draft: draft,
                ),
              ),
            );
            
            // Reload drafts after returning
            _loadDrafts();
            
            // If email was sent, switch to sent tab
            if (result == 'sent' && mounted) {
              _tabController.animateTo(1);
            }
          },
          leading: CircleAvatar(
            backgroundColor: Colors.orange.withValues(alpha: 0.2),
            child: const Icon(
              Icons.drafts,
              color: Colors.orange,
            ),
          ),
          title: Text(
            draft.recipientEmail?.isNotEmpty == true 
                ? 'To: ${draft.recipientEmail}'
                : 'New Draft',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.subject.isNotEmpty ? draft.subject : '(No subject)',
                style: const TextStyle(
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                draft.body.isNotEmpty ? draft.body : '(No content)',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: Text(
            _formatDate(draft.lastModified),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}