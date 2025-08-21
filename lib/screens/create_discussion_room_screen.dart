import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';
import '../widgets/challenge_bell.dart';
import '../core/logging/app_logger.dart';
import 'debates_discussions_screen.dart';

class CreateDiscussionRoomScreen extends StatefulWidget {
  const CreateDiscussionRoomScreen({super.key});

  @override
  State<CreateDiscussionRoomScreen> createState() => _CreateDiscussionRoomScreenState();
}

class _CreateDiscussionRoomScreenState extends State<CreateDiscussionRoomScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  
  // Form controllers
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // State variables
  String _selectedCategory = 'Religion';
  String _selectedDebateStyle = 'Discussion';
  bool _showCustomCategory = false;
  bool _isCreating = false;
  bool _isPrivate = false;
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  
  // Purple theme colors
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color lightPurple = Color(0xFFF3F4F6);
  static const Color darkGray = Color(0xFF333333);
  static const Color mediumGray = Color(0xFF666666);
  static const Color lightBorder = Color(0xFFDDDDDD);
  
  // Categories with priority order
  final List<String> _categories = [
    'Religion',
    'Sports', 
    'Science',
    'Politics',
    'Technology',
    'Music',
    'Business',
    'Art',
    'Education',
    'Social',
    'Gaming',
    'Custom'
  ];
  
  // Debate styles
  final List<Map<String, String>> _debateStyles = [
    {
      'id': 'Discussion',
      'name': 'Discussion',
      'description': 'Open conversation and exchange of ideas'
    },
    {
      'id': 'Debate',
      'name': 'Debate',
      'description': 'Structured argument with opposing viewpoints'
    },
    {
      'id': 'Take',
      'name': 'Take',
      'description': 'Share your perspective on a topic'
    },
  ];

  @override
  void dispose() {
    _roomNameController.dispose();
    _descriptionController.dispose();
    _customCategoryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Check if form is valid
  bool get _isFormValid {
    final basicValid = _roomNameController.text.trim().isNotEmpty;
    
    // If private room, password is required
    if (_isPrivate) {
      return basicValid && _passwordController.text.trim().isNotEmpty;
    }
    
    return basicValid;
  }

  // Create room function
  Future<void> _createRoom() async {
    if (!_isFormValid || _isCreating) return;
    
    // Prevent multiple concurrent operations
    if (!mounted) return;
    
    setState(() {
      _isCreating = true;
    });
    
    try {
      // Get current user
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) {
        _showSnackBar('Please log in to create a room');
        return;
      }
      
      // Get final category
      final finalCategory = _selectedCategory == 'Custom' 
          ? _customCategoryController.text.trim().isNotEmpty 
              ? _customCategoryController.text.trim()
              : 'Custom'
          : _selectedCategory;
      
      AppLogger().info('Creating debate discussion room...');
      
      // Debug the scheduled date being sent
      if (_isScheduled) {
        AppLogger().info('Creating scheduled room with date: $_scheduledDate');
        AppLogger().info('Current time: ${DateTime.now()}');
        AppLogger().info('Time difference: ${_scheduledDate.difference(DateTime.now()).inMinutes} minutes');
        AppLogger().info('Is scheduled date in future: ${_scheduledDate.isAfter(DateTime.now())}');
        AppLogger().info('Scheduled date UTC: ${_scheduledDate.toUtc()}');
        AppLogger().info('Scheduled date ISO8601: ${_scheduledDate.toIso8601String()}');
      }
      
      // Create room using the correct method for Debates & Discussions
      final roomId = await _appwriteService.createDebateDiscussionRoom(
        name: _roomNameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: finalCategory,
        debateStyle: _selectedDebateStyle,
        createdBy: currentUser.$id,
        isPrivate: _isPrivate,
        password: _isPrivate ? _passwordController.text.trim() : null,
        isScheduled: _isScheduled,
        scheduledDate: _isScheduled ? _scheduledDate : null,
      );
      
      AppLogger().info('Room created successfully with ID: $roomId');
      
      // Show success message
      _showSnackBar('Room created successfully!');
      
      // Wait for room setup to complete before navigation
      AppLogger().info('Waiting for room setup to stabilize before navigation...');
      await Future.delayed(const Duration(seconds: 1));
      
      // Verify room exists and is properly set up before navigating
      final roomData = await _appwriteService.getDebateDiscussionRoom(roomId);
      if (roomData == null) {
        throw Exception('Room was not properly created or was deleted');
      }
      
      AppLogger().info('Room verified, proceeding with navigation to: $roomId');
      
      // Navigate directly to the created room (using Arena pattern)
      if (mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DebatesDiscussionsScreen(
              roomId: roomId,
              roomName: _roomNameController.text.trim(),
              moderatorName: currentUser.name.isNotEmpty ? currentUser.name : 'Moderator',
            ),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Error creating room: $e');
      _showSnackBar('Error creating room: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  // Show snack bar
  void _showSnackBar(String message) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  // Show date picker for scheduling
  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDate),
      );
      
      if (time != null) {
        setState(() {
          _scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightPurple,
      appBar: AppBar(
        title: const Text('Create Discussion Room'),
        backgroundColor: Colors.white,
        foregroundColor: darkGray,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          const ChallengeBell(iconColor: Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          TextButton(
            onPressed: (_isFormValid && !_isCreating) ? _createRoom : null,
            child: _isCreating 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Create',
                    style: TextStyle(
                      color: (_isFormValid && !_isCreating) ? primaryPurple : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormSection(
              title: 'Room Information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Room Name*'),
                  _buildTextInput(
                    controller: _roomNameController,
                    placeholder: 'Give your room a name',
                    maxLength: 50,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInputLabel('Description'),
                  _buildTextInput(
                    controller: _descriptionController,
                    placeholder: 'What\'s this room about?',
                    maxLength: 200,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            _buildFormSection(
              title: 'Debate Style',
              child: Column(
                children: _debateStyles.map((style) {
                  final isSelected = _selectedDebateStyle == style['id'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDebateStyle = style['id']!;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryPurple.withValues(alpha: 0.1) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? primaryPurple : lightBorder,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? primaryPurple : Colors.grey,
                                  width: 2,
                                ),
                                color: isSelected ? primaryPurple : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    style['name']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? primaryPurple : darkGray,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    style['description']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildFormSection(
              title: 'Category',
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                            _showCustomCategory = category == 'Custom';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryPurple : Colors.white,
                            border: Border.all(
                              color: isSelected ? primaryPurple : lightBorder,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : mediumGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_showCustomCategory) ...[
                    const SizedBox(height: 16),
                    _buildTextInput(
                      controller: _customCategoryController,
                      placeholder: 'Enter custom category',
                      maxLength: 20,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            _buildFormSection(
              title: 'Room Settings',
              child: Column(
                children: [
                  _buildSwitchRow(
                    title: 'Private Room',
                    description: 'Require password to join',
                    value: _isPrivate,
                    onChanged: (value) {
                      setState(() {
                        _isPrivate = value;
                      });
                    },
                  ),
                  
                  if (_isPrivate) ...[
                    const SizedBox(height: 16),
                    _buildInputLabel('Room Password*'),
                    _buildTextInput(
                      controller: _passwordController,
                      placeholder: 'Enter room password',
                      maxLength: 20,
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  _buildSwitchRow(
                    title: 'Schedule for Later',
                    description: 'Create a scheduled room',
                    value: _isScheduled,
                    onChanged: (value) {
                      setState(() {
                        _isScheduled = value;
                      });
                    },
                  ),
                  
                  if (_isScheduled) ...[
                    const SizedBox(height: 16),
                    _buildInputLabel('Select Date and Time'),
                    GestureDetector(
                      onTap: _selectDateTime,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: lightPurple,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: lightBorder),
                        ),
                        child: Text(
                          '${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year} at ${_scheduledDate.hour.toString().padLeft(2, '0')}:${_scheduledDate.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: darkGray,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change date and time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkGray,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: mediumGray,
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String placeholder,
    int maxLength = 100,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: placeholder,
        filled: true,
        fillColor: lightPurple,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryPurple),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        counterText: '',
      ),
      style: const TextStyle(fontSize: 16),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: mediumGray,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: primaryPurple,
          activeTrackColor: primaryPurple.withValues(alpha: 0.5),
          inactiveThumbColor: const Color(0xFFF4F3F4),
          inactiveTrackColor: const Color(0xFF767577),
        ),
      ],
    );
  }
}