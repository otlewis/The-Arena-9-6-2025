import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile? profile;
  
  const EditProfileScreen({super.key, this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _websiteController;
  late TextEditingController _xController;
  late TextEditingController _linkedinController;
  late TextEditingController _youtubeController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  
  List<String> _interests = [];
  bool _isPublicProfile = true;
  bool _isLoading = false;
  Uint8List? _newAvatarBytes;
  String? _currentAvatarUrl;

  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  // Available interests
  final List<String> availableInterests = [
    'Politics', 'Technology', 'Science', 'Environment', 'Education', 
    'Healthcare', 'Economics', 'Philosophy', 'Religion', 'Ethics',
    'Sports', 'Entertainment', 'Business', 'Law', 'History',
    'Psychology', 'Social Issues', 'International Affairs'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _bioController = TextEditingController(text: widget.profile?.bio ?? '');
    _locationController = TextEditingController(text: widget.profile?.location ?? '');
    _websiteController = TextEditingController(text: widget.profile?.website ?? '');
    _xController = TextEditingController(text: widget.profile?.xHandle ?? '');
    _linkedinController = TextEditingController(text: widget.profile?.linkedinHandle ?? '');
    _youtubeController = TextEditingController(text: widget.profile?.youtubeHandle ?? '');
    _facebookController = TextEditingController(text: widget.profile?.facebookHandle ?? '');
    _instagramController = TextEditingController(text: widget.profile?.instagramHandle ?? '');
    
    _interests = List.from(widget.profile?.interests ?? []);
    _isPublicProfile = widget.profile?.isPublicProfile ?? true;
    _currentAvatarUrl = widget.profile?.avatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _xController.dispose();
    _linkedinController.dispose();
    _youtubeController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      // Show options for image source on macOS
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _newAvatarBytes = bytes;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile picture selected successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose how you want to select your profile picture:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, size: 18),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, size: 18),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      String? avatarUrl = _currentAvatarUrl;

      // Upload new avatar if selected
      if (_newAvatarBytes != null) {
        avatarUrl = await _appwrite.uploadAvatar(
          userId: user.$id,
          fileBytes: _newAvatarBytes!,
          fileName: 'avatar_${user.$id}.jpg',
        );
      }

      // Update profile
      await _appwrite.updateUserProfile(
        userId: user.$id,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: avatarUrl,
        location: _locationController.text.trim(),
        website: _websiteController.text.trim(),
        xHandle: _xController.text.trim(),
        linkedinHandle: _linkedinController.text.trim(),
        youtubeHandle: _youtubeController.text.trim(),
        facebookHandle: _facebookController.text.trim(),
        instagramHandle: _instagramController.text.trim(),
        interests: _interests,
        isPublicProfile: _isPublicProfile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        titleTextStyle: const TextStyle(
          color: deepPurple,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isLoading ? Colors.grey : scarletRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAvatarSection(),
                  const SizedBox(height: 32),
                  _buildBasicInfoSection(),
                  const SizedBox(height: 24),
                  _buildSocialLinksSection(),
                  const SizedBox(height: 24),
                  _buildInterestsSection(),
                  const SizedBox(height: 24),
                  _buildPrivacySection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    Widget avatarDisplay;
    
    if (_newAvatarBytes != null) {
      avatarDisplay = CircleAvatar(
        radius: 60,
        backgroundImage: MemoryImage(_newAvatarBytes!),
      );
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      avatarDisplay = CircleAvatar(
        radius: 60,
        backgroundImage: CachedNetworkImageProvider(_currentAvatarUrl!),
        backgroundColor: lightScarlet,
      );
    } else {
      avatarDisplay = CircleAvatar(
        radius: 60,
        backgroundColor: lightScarlet,
        child: Text(
          widget.profile?.initials ?? 'U',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: scarletRed,
          ),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            avatarDisplay,
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: scarletRed,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  onPressed: _pickImage,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap camera to change avatar',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.edit, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
                helperText: 'Tell others about yourself',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Social Links',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: InputDecoration(
                labelText: 'Website',
                prefixIcon: Icon(Icons.language, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty && !Uri.tryParse(value)!.isAbsolute) {
                  return 'Please enter a valid URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _xController,
              decoration: InputDecoration(
                labelText: 'X Handle',
                prefixIcon: Icon(Icons.alternate_email, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
                helperText: 'Without the @ symbol',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkedinController,
              decoration: InputDecoration(
                labelText: 'LinkedIn Handle',
                prefixIcon: Icon(Icons.business, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
                helperText: 'Your LinkedIn username',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _youtubeController,
              decoration: InputDecoration(
                labelText: 'YouTube Handle',
                prefixIcon: Icon(Icons.play_circle, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
                helperText: 'Your YouTube username',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _facebookController,
              decoration: InputDecoration(
                labelText: 'Facebook Handle',
                prefixIcon: Icon(Icons.facebook, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
                helperText: 'Your Facebook username',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instagramController,
              decoration: InputDecoration(
                labelText: 'Instagram Handle',
                prefixIcon: Icon(Icons.camera_alt, color: scarletRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: scarletRed),
                ),
                helperText: 'Your Instagram username',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select topics you\'re interested in debating',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableInterests.map((interest) {
                final isSelected = _interests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _interests.add(interest);
                      } else {
                        _interests.remove(interest);
                      }
                    });
                  },
                  selectedColor: lightScarlet,
                  checkmarkColor: scarletRed,
                  labelStyle: TextStyle(
                    color: isSelected ? scarletRed : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Public Profile'),
              subtitle: const Text('Allow others to view your profile'),
              value: _isPublicProfile,
              onChanged: (value) {
                setState(() {
                  _isPublicProfile = value;
                });
              },
              activeColor: scarletRed,
            ),
          ],
        ),
      ),
    );
  }
} 