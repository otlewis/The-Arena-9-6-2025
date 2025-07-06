import 'package:flutter/material.dart';
// import 'dart:math';
import '../core/logging/app_logger.dart';
import '../services/appwrite_service.dart';

class CreateDAndDScreen extends StatefulWidget {
  const CreateDAndDScreen({super.key});

  @override
  State<CreateDAndDScreen> createState() => _CreateDAndDScreenState();
}

class _CreateDAndDScreenState extends State<CreateDAndDScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  bool _isCreating = false;
  // Controllers for text inputs
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  
  // Room settings state
  String _selectedCategory = 'Religion';
  String _selectedRoomType = 'Debate';
  // String _customCategory = '';
  bool _isPrivate = false;
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now();
  
  // Available categories
  final List<String> _categories = [
    'Religion',
    'Sports',
    'Science',
    'Technology',
    'Music',
    'Business',
    'Art',
    'Education',
    'Social',
    'Gaming',
    'Other'
  ];
  
  // Room types
  final List<String> _roomTypes = [
    'Debate',
    'Take',
    'Discussion'
  ];
  
  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF333333);
  static const Color mediumGray = Color(0xFF666666);
  static const Color lightBorder = Color(0xFFDDDDDD);
  
  @override
  void dispose() {
    _roomNameController.dispose();
    _descriptionController.dispose();
    _userNameController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }
  
  // Generate a random user ID
  // String _generateUserID() {
  //   return 'user_${Random().nextInt(100000)}';
  // }
  
  // Check if form is valid
  bool get _isFormValid {
    return _roomNameController.text.trim().isNotEmpty && 
           _userNameController.text.trim().isNotEmpty;
  }
  
  // Create room function
  Future<void> _createRoom() async {
    // Validation
    if (!_isFormValid) {
      _showSnackBar('Please enter both a room name and your name');
      return;
    }
    
    if (_isCreating) return; // Prevent double creation
    
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
      final finalCategory = _selectedCategory == 'Other' 
          ? _customCategoryController.text.trim().isNotEmpty 
              ? _customCategoryController.text.trim()
              : 'Other'
          : _selectedCategory;
      
      // Prepare tags (category and room type)
      final tags = [_selectedRoomType, finalCategory];
      
      AppLogger().info('Creating room in Appwrite...');
      
      // Create room in Appwrite
      final roomId = await _appwriteService.createRoom(
        title: _roomNameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: currentUser.$id,
        tags: tags,
        maxParticipants: 50, // Default max participants
      );
      
      AppLogger().info('Room created successfully with ID: $roomId');
      
      // Show success message
      _showSnackBar('Room created successfully!');
      
      // Navigate back to room list
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate room was created
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Show date picker
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
      backgroundColor: lightGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildRoomInformationSection(),
                    const SizedBox(height: 25),
                    _buildRoomTypeSection(),
                    const SizedBox(height: 25),
                    _buildCategorySection(),
                    const SizedBox(height: 25),
                    _buildRoomSettingsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                color: scarletRed,
              ),
            ),
          ),
          const Text(
            'Create Room',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkGray,
            ),
          ),
          ElevatedButton(
            onPressed: (_isFormValid && !_isCreating) ? _createRoom : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: (_isFormValid && !_isCreating) ? accentPurple : Colors.grey[300],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isCreating 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoomInformationSection() {
    return _buildFormSection(
      title: 'Room Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel('Your Name*'),
          _buildTextInput(
            controller: _userNameController,
            placeholder: 'Enter your name',
            maxLength: 30,
          ),
          const SizedBox(height: 15),
          
          _buildInputLabel('Room Name*'),
          _buildTextInput(
            controller: _roomNameController,
            placeholder: 'Give your room a name',
            maxLength: 50,
            showCharCount: true,
          ),
          const SizedBox(height: 15),
          
          _buildInputLabel('Description'),
          _buildTextInput(
            controller: _descriptionController,
            placeholder: 'What\'s this room about?',
            maxLength: 200,
            maxLines: 4,
            showCharCount: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoomTypeSection() {
    return _buildFormSection(
      title: 'Room Type',
      child: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _roomTypes.length,
              itemBuilder: (context, index) {
                final roomType = _roomTypes[index];
                final isSelected = _selectedRoomType == roomType;
                
                return Padding(
                  padding: EdgeInsets.only(right: index < _roomTypes.length - 1 ? 10 : 0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRoomType = roomType;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? scarletRed : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? scarletRed : lightBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          roomType,
                          style: TextStyle(
                            color: isSelected ? Colors.white : mediumGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return _buildFormSection(
      title: 'Category',
      child: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                
                return Padding(
                  padding: EdgeInsets.only(right: index < _categories.length - 1 ? 10 : 0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? accentPurple : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? accentPurple : lightBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : mediumGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedCategory == 'Other') ...[
            const SizedBox(height: 15),
            _buildTextInput(
              controller: _customCategoryController,
              placeholder: 'Enter custom category',
              maxLength: 20,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildRoomSettingsSection() {
    return _buildFormSection(
      title: 'Room Settings',
      child: Column(
        children: [
          _buildSwitchRow(
            title: 'Private Room',
            description: 'Only people with the link can join',
            value: _isPrivate,
            onChanged: (value) {
              setState(() {
                _isPrivate = value;
              });
            },
          ),
          const SizedBox(height: 20),
          
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
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputLabel('Select Date and Time'),
                GestureDetector(
                  onTap: _selectDateTime,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: lightGray,
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
                const SizedBox(height: 5),
                const Text(
                  'Tap to change date and time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFormSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 1),
            blurRadius: 2,
            spreadRadius: 0,
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
          const SizedBox(height: 15),
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
          fontSize: 16,
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
    bool showCharCount = false,
  }) {
    return Column(
      children: [
        TextField(
          controller: controller,
          maxLength: showCharCount ? maxLength : null,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: lightGray,
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
              borderSide: const BorderSide(color: accentPurple),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            counterText: showCharCount ? null : '',
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (_) => setState(() {}), // Rebuild to update create button state
        ),
        if (showCharCount && !showCharCount) // This condition will never be true, keeping for structure consistency
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '${controller.text.length}/$maxLength',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
      ],
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
                  fontWeight: FontWeight.w500,
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
          activeColor: accentPurple,
          activeTrackColor: accentPurple.withValues(alpha: 0.5),
          inactiveThumbColor: const Color(0xFFF4F3F4),
          inactiveTrackColor: const Color(0xFF767577),
        ),
      ],
    );
  }
}