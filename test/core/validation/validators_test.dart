import 'package:flutter_test/flutter_test.dart';
import 'package:arena/core/validation/validators.dart';
import 'package:arena/core/error/app_error.dart';

void main() {
  group('Email Validation', () {
    test('should return null for valid email', () {
      expect(Validators.validateEmail('test@example.com'), null);
      expect(Validators.validateEmail('user.name+tag@domain.co.uk'), null);
    });

    test('should return error for invalid email format', () {
      final result = Validators.validateEmail('invalid-email');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('valid email address'));
    });

    test('should return error for empty email', () {
      final result = Validators.validateEmail('');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('required'));
    });

    test('should return error for email too long', () {
      final longEmail = '${'a' * 250}@example.com';
      final result = Validators.validateEmail(longEmail);
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('too long'));
    });
  });

  group('Password Validation', () {
    test('should return null for valid password', () {
      expect(Validators.validatePassword('ValidPass123'), null);
      expect(Validators.validatePassword('AnotherGood1'), null);
    });

    test('should return error for password too short', () {
      final result = Validators.validatePassword('short');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('at least'));
    });

    test('should return error for password without uppercase', () {
      final result = Validators.validatePassword('lowercase123');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('uppercase'));
    });

    test('should return error for password without lowercase', () {
      final result = Validators.validatePassword('UPPERCASE123');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('lowercase'));
    });

    test('should return error for password without number', () {
      final result = Validators.validatePassword('NoNumbers');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('number'));
    });

    test('should return error for empty password', () {
      final result = Validators.validatePassword('');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('required'));
    });
  });

  group('Topic Validation', () {
    test('should return null for valid topic', () {
      expect(Validators.validateTopic('Should AI replace human workers?'), null);
    });

    test('should return error for topic too short', () {
      final result = Validators.validateTopic('Short');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('at least 10 characters'));
    });

    test('should return error for topic too long', () {
      final longTopic = 'A' * 250;
      final result = Validators.validateTopic(longTopic);
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('less than'));
    });

    test('should return error for inappropriate content', () {
      final result = Validators.validateTopic('This is spam content that should be filtered');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('inappropriate content'));
    });
  });

  group('Name Validation', () {
    test('should return null for valid name', () {
      expect(Validators.validateName('John Doe'), null);
      expect(Validators.validateName('Mary-Jane O\'Connor'), null);
    });

    test('should return error for name too short', () {
      final result = Validators.validateName('A');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('at least 2 characters'));
    });

    test('should return error for invalid characters', () {
      final result = Validators.validateName('John123');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('letters, spaces, hyphens'));
    });
  });

  group('Batch Validation', () {
    test('should validate user registration with multiple fields', () {
      final errors = Validators.validateUserRegistration(
        email: 'test@example.com',
        password: 'ValidPass123',
        name: 'John Doe',
        confirmPassword: 'ValidPass123',
      );

      expect(errors, isEmpty);
    });

    test('should return multiple errors for invalid registration', () {
      final errors = Validators.validateUserRegistration(
        email: 'invalid-email',
        password: 'weak',
        name: 'J',
        confirmPassword: 'different',
      );

      expect(errors, hasLength(4)); // Email, password, name, and confirm password errors
      expect(errors.any((e) => e.message.contains('email')), true);
      expect(errors.any((e) => e.message.contains('Password')), true);
      expect(errors.any((e) => e.message.contains('Name')), true);
      expect(errors.any((e) => e.message.contains('not match')), true);
    });

    test('should validate challenge creation', () {
      final errors = Validators.validateChallengeCreation(
        topic: 'Should we implement universal basic income?',
        description: 'A debate about economic policy',
      );

      expect(errors, isEmpty);
    });
  });

  group('URL Validation', () {
    test('should return null for valid URLs', () {
      expect(Validators.validateUrl('https://example.com'), null);
      expect(Validators.validateUrl('http://subdomain.example.com/path'), null);
    });

    test('should return null for empty URL (optional)', () {
      expect(Validators.validateUrl(''), null);
      expect(Validators.validateUrl(null), null);
    });

    test('should return error for invalid URL', () {
      final result = Validators.validateUrl('not-a-url');
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('valid URL'));
    });
  });

  group('Age Validation', () {
    test('should return null for valid ages', () {
      expect(Validators.validateAge(18), null);
      expect(Validators.validateAge(65), null);
    });

    test('should return error for age too young', () {
      final result = Validators.validateAge(12);
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('at least 13 years old'));
    });

    test('should return error for unrealistic age', () {
      final result = Validators.validateAge(150);
      expect(result, isA<ValidationError>());
      expect(result!.message, contains('valid age'));
    });
  });
}