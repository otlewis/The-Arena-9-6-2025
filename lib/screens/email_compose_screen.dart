import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import '../models/arena_email.dart';
import '../models/user_profile.dart';

class EmailComposeScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;
  final UserProfile? recipient;
  final ArenaEmail? replyTo;
  final ArenaEmail? forwardEmail;
  final EmailTemplate? template;
  final EmailDraft? draft;
  
  const EmailComposeScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    this.recipient,
    this.replyTo,
    this.forwardEmail,
    this.template,
    this.draft,
  });

  @override
  State<EmailComposeScreen> createState() => _EmailComposeScreenState();
}

class _EmailComposeScreenState extends State<EmailComposeScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final _formKey = GlobalKey<FormState>();
  
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  
  bool _isSending = false;
  List<EmailTemplate> _templates = [];
  UserProfile? _selectedRecipient;
  String? _draftId;
  Timer? _autoSaveTimer;
  bool _hasChanges = false;
  
  // Colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color borderColor = Color(0xFF2D2D2D);
  
  @override
  void initState() {
    super.initState();
    _initializeCompose();
    _loadTemplates();
    _setupAutoSave();
    _setupTextListeners();
  }
  
  void _setupTextListeners() {
    _toController.addListener(_onTextChanged);
    _subjectController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    _hasChanges = true;
  }
  
  void _setupAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_hasChanges) {
        _saveDraft();
      }
    });
  }
  
  void _initializeCompose() {
    // Load from draft if available
    if (widget.draft != null) {
      _draftId = widget.draft!.id;
      _toController.text = widget.draft!.recipientEmail ?? '';
      _subjectController.text = widget.draft!.subject;
      _bodyController.text = widget.draft!.body;
      // TODO: Load recipient profile if recipientId is available
    }
    
    if (widget.recipient != null) {
      _selectedRecipient = widget.recipient;
      _toController.text = '${widget.recipient!.name.toLowerCase()}@arena.dtd';
    }
    
    if (widget.replyTo != null) {
      // Set recipient from the reply
      _selectedRecipient = widget.recipient;
      _toController.text = widget.replyTo!.senderEmail;
      
      // Format subject with Re: prefix if not already present
      String subject = widget.replyTo!.subject;
      if (!subject.startsWith('Re: ')) {
        subject = 'Re: $subject';
      }
      _subjectController.text = subject;
      
      // Format reply body with original message quoted
      final formattedDate = _formatDateTime(widget.replyTo!.createdAt);
      _bodyController.text = '\n\n---\nOn $formattedDate, ${widget.replyTo!.senderEmail} wrote:\n${widget.replyTo!.body}';
    }
    
    if (widget.forwardEmail != null) {
      // For forward, leave recipient empty to be selected
      _toController.text = '';
      
      // Format subject with Fwd: prefix if not already present
      String subject = widget.forwardEmail!.subject;
      if (!subject.startsWith('Fwd: ')) {
        subject = 'Fwd: $subject';
      }
      _subjectController.text = subject;
      
      // Format forward body with original message
      final formattedDate = _formatDateTime(widget.forwardEmail!.createdAt);
      _bodyController.text = '''

---------- Forwarded message ----------
From: ${widget.forwardEmail!.senderEmail}
Date: $formattedDate
Subject: ${widget.forwardEmail!.subject}
To: ${widget.forwardEmail!.recipientEmail}

${widget.forwardEmail!.body}''';
    }
    
    if (widget.template != null) {
      _applyTemplate(widget.template!);
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    // Format: MM/dd/yy h:mm a (e.g., "8/16/25 1:00 PM")
    return DateFormat('M/d/yy h:mm a').format(dateTime);
  }
  
  Future<void> _loadTemplates() async {
    // Load email templates
    _templates = [
      EmailTemplates.challenge,
      EmailTemplates.rematch,
    ];
  }
  
  void _applyTemplate(EmailTemplate template) {
    setState(() {
      _subjectController.text = template.subject
          .replaceAll('{{senderName}}', widget.currentUsername);
      
      String body = template.bodyTemplate
          .replaceAll('{{senderName}}', widget.currentUsername);
      
      if (_selectedRecipient != null) {
        body = body.replaceAll('{{recipientName}}', _selectedRecipient!.name);
      }
      
      _bodyController.text = body;
    });
  }
  
  Future<void> _selectRecipient() async {
    final selectedUser = await showDialog<UserProfile>(
      context: context,
      builder: (context) => UserSearchDialog(
        currentUserId: widget.currentUserId,
        appwriteService: _appwrite,
      ),
    );
    
    if (selectedUser != null) {
      setState(() {
        _selectedRecipient = selectedUser;
        _toController.text = '${selectedUser.name.toLowerCase()}@arena.dtd';
      });
      
      // Update template if one is being used
      if (_bodyController.text.contains('{{recipientName}}')) {
        String updatedBody = _bodyController.text
            .replaceAll('{{recipientName}}', selectedUser.name);
        _bodyController.text = updatedBody;
      }
    }
  }
  
  Future<void> _saveDraft() async {
    if (_subjectController.text.isEmpty && _bodyController.text.isEmpty) {
      return; // Don't save empty drafts
    }
    
    try {
      final draft = EmailDraft(
        id: _draftId ?? '',
        userId: widget.currentUserId,
        recipientId: _selectedRecipient?.id,
        recipientUsername: _selectedRecipient?.name,
        recipientEmail: _toController.text,
        subject: _subjectController.text,
        body: _bodyController.text,
        lastModified: DateTime.now(),
      );
      
      if (_draftId != null) {
        // Update existing draft
        await _appwrite.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.emailDraftsCollection,
          documentId: _draftId!,
          data: draft.toJson(),
        );
      } else {
        // Create new draft
        final doc = await _appwrite.databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.emailDraftsCollection,
          documentId: ID.unique(),
          data: draft.toJson(),
        );
        _draftId = doc.$id;
      }
      
      _hasChanges = false;
      debugPrint('Draft saved successfully');
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }
  
  Future<void> _deleteDraft() async {
    if (_draftId == null) return;
    
    try {
      await _appwrite.databases.deleteDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.emailDraftsCollection,
        documentId: _draftId!,
      );
      debugPrint('Draft deleted successfully');
    } catch (e) {
      debugPrint('Error deleting draft: $e');
    }
  }
  
  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRecipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a recipient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isSending = true);
    
    try {
      debugPrint('Sending email from ${widget.currentUserId} to ${_selectedRecipient!.id}');
      
      // Determine thread ID for email threading
      String? threadId;
      if (widget.replyTo != null) {
        // Use the original thread ID if it exists, otherwise use the replied email's ID
        threadId = widget.replyTo!.threadId ?? widget.replyTo!.id;
      }
      
      final email = ArenaEmail(
        id: '', // Will be generated by Appwrite
        senderId: widget.currentUserId,
        recipientId: _selectedRecipient!.id,
        senderUsername: widget.currentUsername,
        recipientUsername: _selectedRecipient!.name,
        subject: _subjectController.text,
        body: _bodyController.text,
        createdAt: DateTime.now(),
        threadId: threadId,
      );
      
      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.arenaEmailsCollection,
        documentId: ID.unique(),
        data: email.toJson(),
      );
      
      // Delete draft after sending
      await _deleteDraft();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, 'sent'); // Return 'sent' to indicate success
      }
    } catch (e) {
      debugPrint('Error sending email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        elevation: 0,
        title: Text(
          widget.replyTo != null 
              ? 'Reply' 
              : widget.forwardEmail != null 
                  ? 'Forward Email' 
                  : 'Compose Email',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSending ? null : _sendEmail,
            icon: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
            label: Text(
              _isSending ? 'Sending...' : 'Send',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email header fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: cardBackground,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // To field
                  GestureDetector(
                    onTap: _selectRecipient,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _toController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'To',
                          labelStyle: TextStyle(color: Colors.white54),
                          hintText: 'Tap to search users...',
                          hintStyle: TextStyle(color: Colors.white38),
                          suffixIcon: Icon(Icons.person_add, color: accentPurple),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: accentPurple),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a recipient';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Subject field
                  TextFormField(
                    controller: _subjectController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accentPurple),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            
            // Template selector
            if (_templates.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: cardBackground,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Center(
                        child: Text(
                          'Templates:',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ),
                    ..._templates.map((template) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: ActionChip(
                          label: Text(
                            template.templateType,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _applyTemplate(template),
                          backgroundColor: accentPurple.withValues(alpha: 0.2),
                          labelStyle: const TextStyle(color: accentPurple),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            
            // Email body
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _bodyController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Write your message...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_hasChanges) {
      _saveDraft(); // Save draft one last time
    }
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}

class UserSearchDialog extends StatefulWidget {
  final String currentUserId;
  final AppwriteService appwriteService;
  
  const UserSearchDialog({
    super.key,
    required this.currentUserId,
    required this.appwriteService,
  });
  
  @override
  State<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<UserSearchDialog> {
  final _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  List<UserProfile> _allUsers = [];
  bool _isLoading = false;
  
  // Colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color borderColor = Color(0xFF2D2D2D);
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }
  
  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await widget.appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usersCollection,
        queries: [
          Query.limit(100),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      final users = response.documents
          .map((doc) => UserProfile.fromMap(doc.data))
          .where((user) => user.id != widget.currentUserId) // Exclude current user
          .toList()
          .cast<UserProfile>();
      
      setState(() {
        _allUsers = users;
        _searchResults = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    
    if (query.isEmpty) {
      setState(() => _searchResults = _allUsers);
    } else {
      final filtered = _allUsers.where((user) {
        return user.name.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query) ||
               '${user.name.toLowerCase()}@arena.dtd'.contains(query);
      }).toList();
      
      setState(() => _searchResults = filtered);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: darkBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Select Recipient',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Search field
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentPurple),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: accentPurple),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_search,
                                size: 64,
                                color: Colors.white54,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'No users found'
                                    : 'No users match your search',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return _buildUserTile(user);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserTile(UserProfile user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        onTap: () => Navigator.pop(context, user),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accentPurple,
          backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
          child: user.avatar == null
              ? Text(
                  user.initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          user.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.name.toLowerCase()}@arena.dtd',
              style: const TextStyle(color: accentPurple, fontSize: 12),
            ),
            if (user.totalDebates > 0)
              Text(
                '${user.totalDebates} debates • ${user.totalWins} wins',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white54,
          size: 16,
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}