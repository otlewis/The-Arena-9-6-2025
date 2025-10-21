import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

class DebateTutorScreen extends StatefulWidget {
  const DebateTutorScreen({super.key});

  @override
  State<DebateTutorScreen> createState() => _DebateTutorScreenState();
}

class _DebateTutorScreenState extends State<DebateTutorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AppwriteService _appwriteService = AppwriteService();

  final List<Map<String, String>> _conversation = [];
  bool _isLoading = false;
  String? _userId;
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // Tutor settings
  String _selectedMode = 'practice';
  String _position = 'affirmative';
  String _skillLevel = 'intermediate';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _topicController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (mounted && user != null) {
        setState(() {
          _userId = user.$id;
        });
      }
    } catch (e) {
      AppLogger().error('Error loading user: $e');
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _conversation.add({
        'sender': 'tutor',
        'message': 'Welcome to your AI Debate Tutor! 🎓\n\nI can help you:\n• Practice debates\n• Critique your arguments\n• Research topics\n• Learn strategy\n• Get debate tips\n• Identify logical fallacies\n\nSelect a mode above and let\'s get started!'
      });
    });
  }

  Future<void> _sendToTutor(String message) async {
    if (message.trim().isEmpty) return;
    if (_userId == null) {
      _showError('Please log in to use the AI Tutor');
      return;
    }

    setState(() {
      _conversation.add({'sender': 'user', 'message': message});
      _isLoading = true;
    });

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.4.94:5555/webhook/debate-tutor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'sessionId': _sessionId,
          'tutorMode': _selectedMode,
          'topic': _topicController.text.trim(),
          'position': _position,
          'skillLevel': _skillLevel,
          'userMessage': message,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _conversation.add({
              'sender': 'tutor',
              'message': data['tutorResponse'] ?? 'I apologize, but I couldn\'t generate a response.'
            });
            _isLoading = false;
          });

          // Scroll to bottom after response
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      AppLogger().error('Tutor error: $e');
      if (mounted) {
        setState(() {
          _conversation.add({
            'sender': 'tutor',
            'message': 'Sorry, I\'m having trouble connecting right now. Please try again. (Error: $e)'
          });
          _isLoading = false;
        });
      }
    }

    _messageController.clear();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _getHintText() {
    switch (_selectedMode) {
      case 'practice':
        return 'Make your argument...';
      case 'critique':
        return 'Paste your argument for feedback...';
      case 'research':
        return 'What do you want to research?';
      case 'strategy':
        return 'Ask about strategy...';
      case 'fallacies':
        return 'Paste text to check for fallacies...';
      default:
        return 'Ask your question...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('AI Debate Tutor', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Mode selector
          PopupMenuButton<String>(
            initialValue: _selectedMode,
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (mode) {
              setState(() {
                _selectedMode = mode;
                _conversation.add({
                  'sender': 'system',
                  'message': 'Switched to ${_getModeLabel(mode)} mode'
                });
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'practice', child: Text('🥊 Practice')),
              const PopupMenuItem(value: 'critique', child: Text('📝 Critique')),
              const PopupMenuItem(value: 'research', child: Text('🔍 Research')),
              const PopupMenuItem(value: 'strategy', child: Text('🎯 Strategy')),
              const PopupMenuItem(value: 'tips', child: Text('💡 Tips')),
              const PopupMenuItem(value: 'fallacies', child: Text('⚠️ Fallacies')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Settings panel
          Container(
            color: const Color(0xFF2D2D2D),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Mode indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getModeIcon(_selectedMode),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_getModeLabel(_selectedMode)} Mode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Topic row
                TextField(
                  controller: _topicController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Topic',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
                    hintText: 'e.g., Should AI replace teachers?',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 10),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Position and level row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _position,
                        dropdownColor: const Color(0xFF2D2D2D),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Position',
                          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'affirmative', child: Text('For')),
                          DropdownMenuItem(value: 'negative', child: Text('Against')),
                        ],
                        onChanged: (value) => setState(() => _position = value!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _skillLevel,
                        dropdownColor: const Color(0xFF2D2D2D),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Level',
                          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'beginner', child: Text('Begin')),
                          DropdownMenuItem(value: 'intermediate', child: Text('Inter')),
                          DropdownMenuItem(value: 'advanced', child: Text('Adv')),
                        ],
                        onChanged: (value) => setState(() => _skillLevel = value!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Conversation history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _conversation.length,
              itemBuilder: (context, index) {
                final msg = _conversation[index];
                final sender = msg['sender']!;
                final message = msg['message']!;

                if (sender == 'system') {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                  );
                }

                final isUser = sender == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.purple[700] : const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(12),
                      border: isUser ? null : Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isUser ? 'You' : 'AI Tutor 🎓',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isUser ? Colors.white70 : Colors.purple[300],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Tutor is thinking...',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            color: const Color(0xFF2D2D2D),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _getHintText(),
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendToTutor(_messageController.text),
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : () => _sendToTutor(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getModeLabel(String mode) {
    switch (mode) {
      case 'practice':
        return 'Practice';
      case 'critique':
        return 'Critique';
      case 'research':
        return 'Research';
      case 'strategy':
        return 'Strategy';
      case 'tips':
        return 'Tips';
      case 'fallacies':
        return 'Fallacies';
      default:
        return 'Practice';
    }
  }

  String _getModeIcon(String mode) {
    switch (mode) {
      case 'practice':
        return '🥊';
      case 'critique':
        return '📝';
      case 'research':
        return '🔍';
      case 'strategy':
        return '🎯';
      case 'tips':
        return '💡';
      case 'fallacies':
        return '⚠️';
      default:
        return '🎓';
    }
  }
}
