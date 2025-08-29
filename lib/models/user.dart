import 'package:appwrite/models.dart' as appwrite_models;

/// User model wrapper extending Appwrite's User model
/// Provides additional convenience methods and properties
class User {
  final dynamic _appwriteUser; // Can be appwrite_models.User or _MockAppwriteUser

  User(this._appwriteUser);

  // Delegate to Appwrite User properties
  String get $id => _appwriteUser.$id;
  String get $createdAt => _appwriteUser.$createdAt;
  String get $updatedAt => _appwriteUser.$updatedAt;
  String get name => _appwriteUser.name;
  String get email => _appwriteUser.email;
  bool get emailVerification => _appwriteUser.emailVerification;
  String get phone => _appwriteUser.phone;
  bool get phoneVerification => _appwriteUser.phoneVerification;
  dynamic get preferences => _appwriteUser.prefs;
  bool get status => _appwriteUser.status;
  String get registration => _appwriteUser.registration;
  String get passwordUpdate => _appwriteUser.passwordUpdate;

  // Get the underlying Appwrite User
  dynamic get appwriteUser => _appwriteUser;

  // Convenience getters for debate app
  String get displayName => name.isNotEmpty ? name : email.split('@').first;
  
  String? get profilePicture => _getPreferenceValue('profilePicture') as String?;
  
  String? get bio => _getPreferenceValue('bio') as String?;
  
  int get debateScore => _safeParseInt(_getPreferenceValue('debateScore')) ?? 0;
  
  int get totalDebates => _safeParseInt(_getPreferenceValue('totalDebates')) ?? 0;
  
  int get totalWins => _safeParseInt(_getPreferenceValue('totalWins')) ?? 0;
  
  List<String> get interests => 
      (_getPreferenceValue('interests') as List<dynamic>?)?.cast<String>() ?? [];
  
  bool get isVerified => _getPreferenceValue('isVerified') as bool? ?? false;
  
  String get userType => _getPreferenceValue('userType') as String? ?? 'member'; // member, moderator, admin

  // Helper method to get preference values from either mock or real preferences
  dynamic _getPreferenceValue(String key) {
    if (preferences is appwrite_models.Preferences) {
      return (preferences as appwrite_models.Preferences).data[key];
    } else if (preferences is _MockPreferences) {
      return (preferences as _MockPreferences).data[key];
    }
    return null;
  }

  // Safe integer parsing method
  static int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Factory constructor from Appwrite User
  factory User.fromAppwrite(appwrite_models.User appwriteUser) {
    return User(appwriteUser);
  }

  // Convert to Map for Appwrite operations
  Map<String, dynamic> toMap() {
    Map<String, dynamic> prefsData = {};
    if (preferences is appwrite_models.Preferences) {
      prefsData = (preferences as appwrite_models.Preferences).data;
    } else if (preferences is _MockPreferences) {
      prefsData = (preferences as _MockPreferences).data;
    }
    
    return {
      '\$id': $id,
      'name': name,
      'email': email,
      'prefs': prefsData,
      // Include other necessary fields
    };
  }

  // Create User from Map
  factory User.fromMap(Map<String, dynamic> map) {
    // Create a mock Appwrite User for testing purposes
    // In production, this would be replaced with actual Appwrite User data
    final mockAppwriteUser = _MockAppwriteUser(
      $id: map['id'] ?? map['\$id'] ?? '',
      $createdAt: map['\$createdAt'] ?? DateTime.now().toIso8601String(),
      $updatedAt: map['\$updatedAt'] ?? DateTime.now().toIso8601String(),
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      emailVerification: map['emailVerification'] ?? false,
      phone: map['phone'] ?? '',
      phoneVerification: map['phoneVerification'] ?? false,
      prefs: _MockPreferences(map['prefs'] ?? {}),
      status: map['status'] ?? false,
      registration: map['registration'] ?? DateTime.now().toIso8601String(),
      passwordUpdate: map['passwordUpdate'] ?? DateTime.now().toIso8601String(),
    );
    
    return User(mockAppwriteUser);
  }

  @override
  String toString() {
    return 'User(id: ${$id}, name: $name, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.$id == $id;
  }

  @override
  int get hashCode => $id.hashCode;
}

// Mock classes for testing purposes
class _MockAppwriteUser {
  final String $id;
  final String $createdAt;
  final String $updatedAt;
  final String name;
  final String email;
  final bool emailVerification;
  final String phone;
  final bool phoneVerification;
  final _MockPreferences prefs;
  final bool status;
  final String registration;
  final String passwordUpdate;

  _MockAppwriteUser({
    required this.$id,
    required this.$createdAt,
    required this.$updatedAt,
    required this.name,
    required this.email,
    required this.emailVerification,
    required this.phone,
    required this.phoneVerification,
    required this.prefs,
    required this.status,
    required this.registration,
    required this.passwordUpdate,
  });
}

class _MockPreferences {
  final Map<String, dynamic> data;

  _MockPreferences(this.data);
} 