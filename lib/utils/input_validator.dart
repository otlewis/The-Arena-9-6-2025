/// Input validation and sanitization utilities for user-generated content
///
/// Use these methods to validate and sanitize all user input before:
/// - Storing in database
/// - Displaying in UI
/// - Using in queries
/// - Sending to external services
library;

class InputValidator {
  // Private constructor to prevent instantiation
  InputValidator._();

  /// Sanitize text input by removing potentially dangerous characters
  ///
  /// Removes:
  /// - HTML/XML tags
  /// - Control characters
  /// - Zero-width characters
  /// - Excessive whitespace
  ///
  /// Limits:
  /// - Maximum length (default 500 characters)
  /// - Trims leading/trailing whitespace
  static String sanitizeText(String input, {int maxLength = 500}) {
    if (input.isEmpty) return '';

    var sanitized = input;

    // Remove HTML/XML tags
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove script tags and content
    sanitized = sanitized.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');

    // Remove control characters (except newline and tab)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Remove zero-width characters
    sanitized = sanitized.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    // Limit length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    // Normalize whitespace (replace multiple spaces with single space)
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    return sanitized.trim();
  }

  /// Validate room name
  ///
  /// Rules:
  /// - 3-50 characters
  /// - Alphanumeric, spaces, hyphens, underscores only
  /// - Cannot start or end with space/hyphen/underscore
  static bool isValidRoomName(String name) {
    if (name.isEmpty || name.length < 3 || name.length > 50) {
      return false;
    }

    // Must start with alphanumeric
    if (!RegExp(r'^[a-zA-Z0-9]').hasMatch(name)) {
      return false;
    }

    // Must end with alphanumeric
    if (!RegExp(r'[a-zA-Z0-9]$').hasMatch(name)) {
      return false;
    }

    // Only allowed characters in between
    return RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(name);
  }

  /// Sanitize room name
  ///
  /// - Removes invalid characters
  /// - Limits length
  /// - Returns empty string if invalid
  static String sanitizeRoomName(String input) {
    if (input.isEmpty) return '';

    // Remove invalid characters
    var sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_]'), '');

    // Limit length
    if (sanitized.length > 50) {
      sanitized = sanitized.substring(0, 50);
    }

    // Trim and normalize whitespace
    sanitized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Validate result
    return isValidRoomName(sanitized) ? sanitized : '';
  }

  /// Validate username
  ///
  /// Rules:
  /// - 3-30 characters
  /// - Alphanumeric, hyphens, underscores only
  /// - Must start with alphanumeric
  /// - Cannot end with hyphen or underscore
  static bool isValidUsername(String username) {
    if (username.isEmpty || username.length < 3 || username.length > 30) {
      return false;
    }

    // Must start with alphanumeric
    if (!RegExp(r'^[a-zA-Z0-9]').hasMatch(username)) {
      return false;
    }

    // Only alphanumeric, hyphens, underscores
    if (!RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(username)) {
      return false;
    }

    // Cannot end with hyphen or underscore
    if (RegExp(r'[\-_]$').hasMatch(username)) {
      return false;
    }

    return true;
  }

  /// Validate email address
  ///
  /// Uses standard email regex pattern
  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > 254) {
      return false;
    }

    // RFC 5322 compliant email regex (simplified)
    final emailRegex = RegExp(
      r'''^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$''',
    );

    return emailRegex.hasMatch(email);
  }

  /// Validate URL
  ///
  /// Checks for valid HTTP/HTTPS URLs
  static bool isValidUrl(String url) {
    if (url.isEmpty || url.length > 2048) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Sanitize bio/description
  ///
  /// - Allows more characters than room names
  /// - Preserves newlines (up to 2 consecutive)
  /// - Limits length to 500 characters
  static String sanitizeBio(String input) {
    if (input.isEmpty) return '';

    var sanitized = sanitizeText(input, maxLength: 500);

    // Limit consecutive newlines to 2
    sanitized = sanitized.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return sanitized.trim();
  }

  /// Validate password strength
  ///
  /// Requirements:
  /// - Minimum 12 characters
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one digit
  /// - At least one special character
  static bool isStrongPassword(String password) {
    if (password.length < 12) {
      return false;
    }

    // Check for uppercase
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return false;
    }

    // Check for lowercase
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return false;
    }

    // Check for digit
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return false;
    }

    // Check for special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return false;
    }

    return true;
  }

  /// Get password strength score (0-5)
  ///
  /// 0 = Very Weak
  /// 1 = Weak
  /// 2 = Fair
  /// 3 = Good
  /// 4 = Strong
  /// 5 = Very Strong
  static int getPasswordStrength(String password) {
    var score = 0;

    if (password.isEmpty) return 0;

    // Length score
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Character variety
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    // Cap at 5
    return score > 5 ? 5 : score;
  }

  /// Sanitize search query
  ///
  /// Removes special characters that could be used for injection
  static String sanitizeSearchQuery(String query) {
    if (query.isEmpty) return '';

    // Remove quotes and special query characters
    var sanitized = query.replaceAll(RegExp(r'''["'`]'''), '');

    // Remove SQL/NoSQL operators
    sanitized = sanitized.replaceAll(RegExp(r'(\$|;|--|\||&)'), '');

    // Limit length
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }

    return sanitized.trim();
  }

  /// Validate and sanitize user ID
  ///
  /// User IDs should be alphanumeric strings
  static String? sanitizeUserId(String? userId) {
    if (userId == null || userId.isEmpty) return null;

    // Remove any non-alphanumeric characters
    final sanitized = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    // Validate length (typical Appwrite IDs are 20 characters)
    if (sanitized.length < 10 || sanitized.length > 50) {
      return null;
    }

    return sanitized;
  }

  /// Validate file name for uploads
  ///
  /// - No path traversal (../)
  /// - Alphanumeric, hyphens, underscores, dots only
  /// - Must have file extension
  static bool isValidFileName(String fileName) {
    if (fileName.isEmpty || fileName.length > 255) {
      return false;
    }

    // No path traversal
    if (fileName.contains('..') || fileName.contains('/') || fileName.contains('\\')) {
      return false;
    }

    // Must have extension
    if (!fileName.contains('.') || fileName.endsWith('.')) {
      return false;
    }

    // Only safe characters
    if (!RegExp(r'^[a-zA-Z0-9\-_.]+$').hasMatch(fileName)) {
      return false;
    }

    return true;
  }

  /// Sanitize file name
  ///
  /// Removes path traversal and dangerous characters
  static String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return '';

    // Remove path separators and parent directory references
    var sanitized = fileName.replaceAll(RegExp(r'[/\\]'), '');
    sanitized = sanitized.replaceAll('..', '');

    // Only allow safe characters
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_');

    // Limit length
    if (sanitized.length > 255) {
      final parts = sanitized.split('.');
      if (parts.length > 1) {
        final extension = parts.last;
        final name = parts.sublist(0, parts.length - 1).join('.');
        final maxNameLength = 255 - extension.length - 1;
        sanitized = '${name.substring(0, maxNameLength)}.$extension';
      } else {
        sanitized = sanitized.substring(0, 255);
      }
    }

    return sanitized;
  }
}
