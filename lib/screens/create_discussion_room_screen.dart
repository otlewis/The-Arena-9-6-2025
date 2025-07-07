import 'package:flutter/material.dart';

class CreateDiscussionRoomScreen extends StatefulWidget {
  const CreateDiscussionRoomScreen({super.key});

  @override
  State<CreateDiscussionRoomScreen> createState() => _CreateDiscussionRoomScreenState();
}

class _CreateDiscussionRoomScreenState extends State<CreateDiscussionRoomScreen> {
  // Form controllers
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  
  // State variables
  String _selectedCategory = 'Religion';
  String _selectedDebateStyle = 'Discussion';
  bool _isPrivate = false;
  bool _isScheduled = false;
  bool _showCustomCategory = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  
  // Purple theme colors
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color lightPurple = Color(0xFFF3F4F6);
  
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
      'description': 'Structured argument with opposing sides'
    },
    {
      'id': 'Take',
      'name': 'Take',
      'description': 'Hot takes and quick opinions (First Take style)'
    }
  ];
  
  @override
  void dispose() {
    _roomNameController.dispose();
    _descriptionController.dispose();
    _userNameController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }
  
  String _generateRoomId() {
    return 'room_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch % 100000}';
  }
  
  void _createRoom() {
    // Validation
    if (_roomNameController.text.trim().isEmpty || _userNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both a room name and your name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Get final category
    String finalCategory = _selectedCategory;
    if (_selectedCategory == 'Custom' && _customCategoryController.text.trim().isNotEmpty) {
      finalCategory = _customCategoryController.text.trim();
    }
    
    // Create room data
    final roomData = {
      'id': _generateRoomId(),
      'name': _roomNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': finalCategory,
      'debateStyle': _selectedDebateStyle,
      'isPrivate': _isPrivate,
      'isScheduled': _isScheduled,
      'scheduledDate': _isScheduled ? _scheduledDate : null,
      'moderator': _userNameController.text.trim(),
      'moderatorId': _generateUserId(),
      'createdAt': DateTime.now(),
    };
    
    debugPrint('Creating room: $roomData');
    
    if (_isScheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Room scheduled successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      // Navigate to room (you would implement this navigation)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚀 ${roomData['debateStyle']} room "${roomData['name']}" created!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(roomData);
    }
  }
  
  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDate),
      );
      
      if (time != null && mounted) {
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
    final isFormValid = _roomNameController.text.trim().isNotEmpty && 
                       _userNameController.text.trim().isNotEmpty;
    
    return Scaffold(
      backgroundColor: lightPurple,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: primaryPurple, fontSize: 16),
          ),
        ),
        title: const Text(
          'Create Room',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: isFormValid ? _createRoom : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFormValid ? primaryPurple : Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildRoomInformationSection(),
            const SizedBox(height: 20),
            _buildDebateStyleSection(),
            const SizedBox(height: 20),
            _buildCategorySection(),
            const SizedBox(height: 20),
            _buildRoomSettingsSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoomInformationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          const Text(
            'Your Name*',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _userNameController,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              filled: true,
              fillColor: lightPurple,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryPurple),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          
          const Text(
            'Room Name*',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roomNameController,
            maxLength: 50,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Give your room a name',
              filled: true,
              fillColor: lightPurple,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryPurple),
              ),
            ),
          ),
          Text(
            '${_roomNameController.text.length}/50',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 20),
          
          const Text(
            'Description',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLength: 200,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'What\'s this room about?',
              filled: true,
              fillColor: lightPurple,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryPurple),
              ),
            ),
          ),
          Text(
            '${_descriptionController.text.length}/200',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDebateStyleSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debate Style',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          
          Column(
            children: _debateStyles.map((style) {
              final isSelected = _selectedDebateStyle == style['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDebateStyle = style['id']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryPurple.withValues(alpha: 0.1) : lightPurple,
                      border: Border.all(
                        color: isSelected ? primaryPurple : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? primaryPurple : Colors.grey,
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
                                  color: isSelected ? primaryPurple : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                style['description']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
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
        ],
      ),
    );
  }
  
  Widget _buildCategorySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _showCustomCategory = category == 'Custom';
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryPurple : lightPurple,
                        border: Border.all(
                          color: isSelected ? primaryPurple : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_showCustomCategory) ...[
            const SizedBox(height: 15),
            const Text(
              'Custom Category',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customCategoryController,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: 'Enter custom category',
                filled: true,
                fillColor: lightPurple,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryPurple),
                ),
                counterText: '',
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildRoomSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private Room',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Only people with the link can join',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPrivate,
                onChanged: (value) {
                  setState(() {
                    _isPrivate = value;
                  });
                },
                activeColor: primaryPurple,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule for Later',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create a scheduled room',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isScheduled,
                onChanged: (value) {
                  setState(() {
                    _isScheduled = value;
                  });
                },
                activeColor: primaryPurple,
              ),
            ],
          ),
          
          if (_isScheduled) ...[
            const SizedBox(height: 20),
            const Text(
              'Select Date and Time',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateTime,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightPurple,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: primaryPurple),
                    const SizedBox(width: 12),
                    Text(
                      '${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year} at ${_scheduledDate.hour.toString().padLeft(2, '0')}:${_scheduledDate.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}