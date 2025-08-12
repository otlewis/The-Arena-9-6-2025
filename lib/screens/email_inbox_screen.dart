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
  final List<ArenaEmail> _drafts = [];
  
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
    _loadCurrentUser();
    _subscribeToEmails();
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
      
      // Check for new emails and play sound
      final hasNewEmails = newInboxEmails.length > _inboxEmails.length;
      if (hasNewEmails && _inboxEmails.isNotEmpty) {
        debugPrint('New email received! Playing sound...');
        _soundService.playEmailSound();
      }
      
      for (var email in newInboxEmails) {
        debugPrint('Inbox email: sender=${email.senderId}, recipient=${email.recipientId}, subject=${email.subject}');
      }
      
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
  
  void _subscribeToEmails() {
    try {
      final realtime = _appwrite.realtime;
      _subscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.arenaEmailsCollection}.documents'
      ]);
      
      _subscription!.stream.listen((response) {
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
  
  void _composeEmail({UserProfile? recipient}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailComposeScreen(
          currentUserId: _currentUserId!,
          currentUsername: _currentUsername!,
          recipient: recipient,
        ),
      ),
    );
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
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement reply
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
                        // TODO: Implement forward
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
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm').format(date);
    } else {
      return DateFormat('MMM d, y').format(date);
    }
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
                _drafts.isEmpty
                    ? const Center(
                        child: Text(
                          'No drafts',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : _buildEmailList(_drafts, isDraft: true),
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
}