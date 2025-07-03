import '../error/app_error.dart';

/// Input validation utilities
class Validators {
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxTopicLength = 200;
  static const int maxDescriptionLength = 1000;
  static const int maxNameLength = 50;

  /// Email validation
  static ValidationError? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return const ValidationError(message: 'Email is required');
    }
    
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return const ValidationError(message: 'Please enter a valid email address');
    }
    
    if (email.length > 254) {
      return const ValidationError(message: 'Email address is too long');
    }
    
    return null;
  }

  /// Password validation
  static ValidationError? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return const ValidationError(message: 'Password is required');
    }
    
    if (password.length < minPasswordLength) {
      return const ValidationError(message: 'Password must be at least $minPasswordLength characters');
    }
    
    if (password.length > maxPasswordLength) {
      return const ValidationError(message: 'Password must be less than $maxPasswordLength characters');
    }
    
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      return const ValidationError(
        message: 'Password must contain at least one uppercase letter, one lowercase letter, and one number'
      );
    }
    
    return null;
  }

  /// Name validation
  static ValidationError? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return const ValidationError(message: 'Name is required');
    }
    
    if (name.trim().length < 2) {
      return const ValidationError(message: 'Name must be at least 2 characters');
    }
    
    if (name.length > maxNameLength) {
      return const ValidationError(message: 'Name must be less than $maxNameLength characters');
    }
    
    if (!RegExp(r"^[a-zA-Z\s\-'\.]+$").hasMatch(name)) {
      return const ValidationError(message: 'Name can only contain letters, spaces, hyphens, apostrophes, and periods');
    }
    
    return null;
  }

  /// Topic validation for debates
  static ValidationError? validateTopic(String? topic) {
    if (topic == null || topic.isEmpty) {
      return const ValidationError(message: 'Topic is required');
    }
    
    if (topic.trim().length < 10) {
      return const ValidationError(message: 'Topic must be at least 10 characters');
    }
    
    if (topic.length > maxTopicLength) {
      return const ValidationError(message: 'Topic must be less than $maxTopicLength characters');
    }
    
    // Check for inappropriate content (basic filter)
    if (_containsInappropriateContent(topic)) {
      return const ValidationError(message: 'Topic contains inappropriate content');
    }
    
    return null;
  }

  /// Description validation
  static ValidationError? validateDescription(String? description) {
    if (description == null || description.isEmpty) {
      return null; // Description is optional
    }
    
    if (description.length > maxDescriptionLength) {
      return const ValidationError(message: 'Description must be less than $maxDescriptionLength characters');
    }
    
    if (_containsInappropriateContent(description)) {
      return const ValidationError(message: 'Description contains inappropriate content');
    }
    
    return null;
  }

  /// Room name validation
  static ValidationError? validateRoomName(String? roomName) {
    if (roomName == null || roomName.isEmpty) {
      return const ValidationError(message: 'Room name is required');
    }
    
    if (roomName.trim().length < 3) {
      return const ValidationError(message: 'Room name must be at least 3 characters');
    }
    
    if (roomName.length > 100) {
      return const ValidationError(message: 'Room name must be less than 100 characters');
    }
    
    if (!RegExp(r'^[a-zA-Z0-9\s\-_\.]+$').hasMatch(roomName)) {
      return const ValidationError(
        message: 'Room name can only contain letters, numbers, spaces, hyphens, underscores, and periods'
      );
    }
    
    return null;
  }

  /// URL validation
  static ValidationError? validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null; // URL is optional
    }
    
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return const ValidationError(message: 'Please enter a valid URL starting with http:// or https://');
      }
    } catch (e) {
      return const ValidationError(message: 'Please enter a valid URL');
    }
    
    return null;
  }

  /// Phone number validation (basic)
  static ValidationError? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }
    
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]+'), '');
    
    if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(cleaned)) {
      return const ValidationError(message: 'Please enter a valid phone number');
    }
    
    return null;
  }

  /// Age validation
  static ValidationError? validateAge(int? age) {
    if (age == null) {
      return const ValidationError(message: 'Age is required');
    }
    
    if (age < 13) {
      return const ValidationError(message: 'You must be at least 13 years old to use this app');
    }
    
    if (age > 120) {
      return const ValidationError(message: 'Please enter a valid age');
    }
    
    return null;
  }

  /// Basic inappropriate content filter
  static bool _containsInappropriateContent(String text) {
    final inappropriateWords = [
      // Add inappropriate words that should be filtered
      // This is a basic implementation - in production you'd use a more sophisticated filter
      'spam', 'scam', 'fraud', 'hate', 'violence'
    ];
    
    final lowerText = text.toLowerCase();
    return inappropriateWords.any((word) => lowerText.contains(word));
  }

  /// Batch validation
  static List<ValidationError> validateUserRegistration({
    required String? email,
    required String? password,
    required String? name,
    String? confirmPassword,
  }) {
    final errors = <ValidationError>[];
    
    final emailError = validateEmail(email);
    if (emailError != null) errors.add(emailError);
    
    final passwordError = validatePassword(password);
    if (passwordError != null) errors.add(passwordError);
    
    final nameError = validateName(name);
    if (nameError != null) errors.add(nameError);
    
    if (confirmPassword != null && confirmPassword != password) {
      errors.add(const ValidationError(message: 'Passwords do not match'));
    }
    
    return errors;
  }

  /// Validate challenge creation
  static List<ValidationError> validateChallengeCreation({
    required String? topic,
    String? description,
  }) {
    final errors = <ValidationError>[];
    
    final topicError = validateTopic(topic);
    if (topicError != null) errors.add(topicError);
    
    final descriptionError = validateDescription(description);
    if (descriptionError != null) errors.add(descriptionError);
    
    return errors;
  }
}