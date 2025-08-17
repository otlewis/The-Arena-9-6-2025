import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../models/moderator_judge.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';

class JudgeRegistrationScreen extends StatefulWidget {
  final String currentUserId;
  final JudgeProfile? existingProfile;

  const JudgeRegistrationScreen({
    super.key,
    required this.currentUserId,
    this.existingProfile,
  });

  @override
  State<JudgeRegistrationScreen> createState() => _JudgeRegistrationScreenState();
}

class _JudgeRegistrationScreenState extends State<JudgeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appwrite = AppwriteService();
  
  // Form controllers
  final _displayNameController = TextEditingController();
  
  // Form state
  Set<DebateCategory> _selectedCategories = {};
  bool _isAvailable = true;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.existingProfile != null) {
      _populateForm();
    }
  }
  
  void _populateForm() {
    final profile = widget.existingProfile!;
    _displayNameController.text = profile.displayName;
    _selectedCategories = profile.categories.toSet();
    _isAvailable = profile.isAvailable;
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      _showError('Please select at least one category');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final profileData = {
        'userId': widget.currentUserId,
        'username': user.name,
        'displayName': _displayNameController.text.trim(),
        'categories': _selectedCategories.map((e) => e.name).toList(),
        'isAvailable': _isAvailable,
        'totalJudged': widget.existingProfile?.totalJudged ?? 0,
        'rating': widget.existingProfile?.rating ?? 5.0,
        'ratingCount': widget.existingProfile?.ratingCount ?? 0,
        'bio': null,
        'createdAt': widget.existingProfile?.createdAt.toIso8601String() ?? DateTime.now().toIso8601String(),
        'lastActive': DateTime.now().toIso8601String(),
        'specializations': [],
        'experienceYears': 0,
        'certifications': [],
      };
      
      if (widget.existingProfile != null) {
        // Update existing profile
        await _appwrite.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.judgesCollection,
          documentId: widget.existingProfile!.id,
          data: profileData,
        );
        _showSuccess('Profile updated successfully!');
      } else {
        // Create new profile
        await _appwrite.databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.judgesCollection,
          documentId: ID.unique(),
          data: profileData,
        );
        _showSuccess('Judge profile created successfully!');
      }
      
      // Return to previous screen
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
      
    } catch (e) {
      debugPrint('Error saving judge profile: $e');
      _showError('Failed to save profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.existingProfile != null ? 'Edit Judge Profile' : 'Become a Judge'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.balance,
                    size: 48,
                    color: Color(0xFFFFC107),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.existingProfile != null ? 'Update Your Judge Profile' : 'Join as a Judge',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF57C00),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Evaluate arguments and help determine winners in Arena debates',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Basic Information
            _buildSection(
              'Basic Information',
              [
                _buildTextField(
                  controller: _displayNameController,
                  label: 'Display Name',
                  hint: 'How you want to appear to debaters',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Display name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Categories
            _buildSection(
              'Debate Categories',
              [
                Text(
                  'Select the categories you\'re comfortable judging:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                _buildCategoryGrid(),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Availability
            _buildSection(
              'Availability',
              [
                SwitchListTile(
                  title: const Text('Available for judging'),
                  subtitle: Text(
                    _isAvailable 
                        ? 'You will receive ping requests from debaters'
                        : 'You will not receive new ping requests',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  value: _isAvailable,
                  onChanged: (value) {
                    setState(() => _isAvailable = value);
                  },
                  activeThumbColor: const Color(0xFFFFC107),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.existingProfile != null ? 'Update Profile' : 'Create Profile',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF57C00),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DebateCategory.values.map((category) {
        final isSelected = _selectedCategories.contains(category);
        return FilterChip(
          label: Text(category.displayName),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCategories.add(category);
              } else {
                _selectedCategories.remove(category);
              }
            });
          },
          selectedColor: const Color(0xFFFFC107).withValues(alpha: 0.2),
          checkmarkColor: const Color(0xFFFFC107),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFFFFC107) : Colors.grey[700],
            fontSize: 12,
          ),
          backgroundColor: Colors.grey[100],
          side: BorderSide(
            color: isSelected ? const Color(0xFFFFC107) : Colors.grey[300]!,
          ),
        );
      }).toList(),
    );
  }
}