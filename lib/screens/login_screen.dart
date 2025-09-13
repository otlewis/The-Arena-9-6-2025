import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';
import 'forgot_password_screen.dart';
import 'policy_viewer_screen.dart';
import 'parental_consent_screen.dart';
import '../services/consent_logging_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  
  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSignUp = false; // false = Sign In, true = Sign Up
  bool _obscurePassword = true;
  DateTime? _selectedBirthDate;
  bool _acceptedTos = false;
  bool _acceptedPrivacy = false;

  // Colors matching app theme (keeping scarletRed for potential future use)
  static const Color scarletRed = Color(0xFFFF2400);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check age and TOS/Privacy acceptance for sign up
    if (_isSignUp) {
      if (_selectedBirthDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your date of birth'),
            backgroundColor: Color(0xFFFF2400),
          ),
        );
        return;
      }
      
      // Check age and handle teen users (13-17)
      final age = DateTime.now().difference(_selectedBirthDate!).inDays ~/ 365;
      if (age < 13) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be at least 13 years old to use The Arena DTD'),
            backgroundColor: Color(0xFFFF2400),
          ),
        );
        return;
      }
      
      // If user is 13-17, show parental consent screen
      if (age >= 13 && age < 18) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParentalConsentScreen(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              name: _nameController.text.trim(),
              birthDate: _selectedBirthDate!,
              onConsentGiven: (String? parentEmail) {
                Navigator.pop(context);
                _proceedWithSignup(isTeenUser: true, parentEmail: parentEmail);
              },
              onConsentDeclined: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
        return;
      }
      
      if (!_acceptedTos || !_acceptedPrivacy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the Terms of Service and Privacy Policy'),
            backgroundColor: Color(0xFFFF2400),
          ),
        );
        return;
      }
    }

    // For 18+ users, proceed directly with signup
    _proceedWithSignup();
  }
  
  Future<void> _proceedWithSignup({bool isTeenUser = false, String? parentEmail}) async {
    setState(() => _isLoading = true);
    
    // Capture ScaffoldMessenger reference before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (_isSignUp) {
        // Create new account
        await _appwrite.createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );
        
        // Automatically sign in after successful signup
        await _appwrite.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Create user profile in database
        final user = await _appwrite.getCurrentUser();
        if (user != null) {
          final age = DateTime.now().difference(_selectedBirthDate!).inDays ~/ 365;
          await _appwrite.createUserProfile(
            userId: user.$id,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            metadata: {
              'birthDate': _selectedBirthDate!.toIso8601String(),
              'age': age,
              'isTeenUser': isTeenUser,
              'parentalConsentGiven': isTeenUser,
              'parentalConsentDate': isTeenUser ? DateTime.now().toIso8601String() : null,
              'parentEmail': parentEmail,
              'tosAccepted': true,
              'tosAcceptedAt': DateTime.now().toIso8601String(),
              'tosVersion': '1.1',
              'privacyAccepted': true,
              'privacyAcceptedAt': DateTime.now().toIso8601String(),
              'privacyVersion': '1.1',
            },
          );

          // Log consent event for teen users
          if (isTeenUser) {
            await ConsentLoggingService.logConsentEvent(
              userId: user.$id,
              action: 'given',
              parentEmail: parentEmail,
              reason: 'Initial parental consent during signup',
              tosVersion: '1.1',
              privacyVersion: '1.1',
              additionalMetadata: {
                'signupFlow': 'mobile_app',
                'userAge': age,
              },
            );

            // Send parental notification if email provided
            if (parentEmail != null) {
              await ConsentLoggingService.sendParentalNotification(
                parentEmail: parentEmail,
                notificationType: 'account_created',
                teenName: _nameController.text.trim(),
                additionalData: {
                  'userAge': age,
                  'signupDate': DateTime.now().toIso8601String(),
                },
              );
            }
          }
        }
        
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Account created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Notify parent and go back
          widget.onLoginSuccess?.call();
        }
      } else {
        // Sign in existing user
        await _appwrite.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Welcome back!'),
              backgroundColor: Colors.green,
            ),
          );
          // Notify parent and go back
          widget.onLoginSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: scarletRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);
    
    // Capture ScaffoldMessenger reference before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _appwrite.signInWithGoogle();
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Successfully signed in with Google!'),
            backgroundColor: Colors.green,
          ),
        );
        // Notify parent and go back
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${_getErrorMessage(e.toString())}'),
            backgroundColor: const Color(0xFFFF2400),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('user_already_exists')) {
      return 'This email is already registered. Try signing in instead.';
    } else if (error.contains('user_invalid_credentials')) {
      return 'Invalid email or password. Please try again.';
    } else if (error.contains('user_not_found')) {
      return 'No account found with this email. Try signing up instead.';
    } else if (error.contains('password')) {
      return 'Password must be at least 8 characters long.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
    });
  }

  // Helper method for neumorphic input decoration
  InputDecoration _buildModernInputDecoration({
    required String labelText,
    required IconData icon,
    bool isPassword = false,
    VoidCallback? onSuffixTap,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF6B46C1),
              Color(0xFF8B5CF6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
      suffixIcon: isPassword
          ? GestureDetector(
              onTap: onSuffixTap,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Neumorphism background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Modern Logo and Title Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Logo with gradient background
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6B46C1), // Purple
                              Color(0xFF8B5CF6), // Lighter purple
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Container(
                              width: 100,
                              height: 100,
                              color: Colors.white,
                              child: Image.asset(
                                'assets/images/2logo.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.gavel,
                                    size: 60,
                                    color: Color(0xFF8B5CF6),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // App title with gradient text effect
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFDC2626), // Red
                            Color(0xFFEF4444), // Lighter red
                          ],
                        ).createShader(bounds),
                        child: Text(
                          _isSignUp ? 'Join The Arena DTD' : 'The Arena DTD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _isSignUp ? 26 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // This will be overridden by the shader
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isSignUp 
                          ? 'Create your account to start debating'
                          : 'Sign in to enter the arena',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                  
                  const SizedBox(height: 40),
                  
                  // Form Fields
                  if (_isSignUp) ...[
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _buildModernInputDecoration(
                          labelText: 'Display Name',
                          icon: Icons.person,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Date of Birth Picker
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 4745)), // 13 years ago
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF6B46C1),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && picked != _selectedBirthDate) {
                            setState(() {
                              _selectedBirthDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6B46C1),
                                      Color(0xFF8B5CF6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.cake,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              Text(
                                _selectedBirthDate == null
                                    ? 'Date of Birth (Must be 13+)'
                                    : '${_selectedBirthDate!.month}/${_selectedBirthDate!.day}/${_selectedBirthDate!.year}',
                                style: TextStyle(
                                  color: _selectedBirthDate == null
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade800,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: Colors.grey.shade800),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Email',
                        icon: Icons.email,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: Colors.grey.shade800),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Password',
                        icon: Icons.lock,
                        isPassword: true,
                        onSuffixTap: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (_isSignUp && value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  // Terms of Service and Privacy Policy Checkboxes (Sign Up only)
                  if (_isSignUp) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _acceptedTos,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _acceptedTos = value ?? false;
                                  });
                                },
                                activeColor: const Color(0xFF6B46C1),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showPolicyDialog('Terms of Service'),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 14,
                                      ),
                                      children: const [
                                        TextSpan(text: 'I accept the '),
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: TextStyle(
                                            color: Color(0xFF6B46C1),
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _acceptedPrivacy,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _acceptedPrivacy = value ?? false;
                                  });
                                },
                                activeColor: const Color(0xFF6B46C1),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showPolicyDialog('Privacy Policy'),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 14,
                                      ),
                                      children: const [
                                        TextSpan(text: 'I accept the '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(
                                            color: Color(0xFF6B46C1),
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You must be 13 years or older to use The Arena DTD. Teens 13-17 require parental consent.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Neumorphic Auth Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isLoading ? [] : const [
                        BoxShadow(
                          color: Colors.grey,
                          offset: Offset(4, 4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-4, -4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _isLoading ? null : _handleEmailAuth,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade700),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Create Account' : 'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Google Sign-In Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isLoading ? [] : const [
                        BoxShadow(
                          color: Colors.grey,
                          offset: Offset(4, 4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-4, -4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _isLoading ? null : _handleGoogleAuth,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google2.png',
                                height: 34,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text('G', 
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isSignUp ? 'Sign up with Google' : 'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Forgot Password Link (only show on sign in)
                  if (!_isSignUp)
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Toggle Sign Up / Sign In
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUp 
                          ? 'Already have an account? '
                          : 'Don\'t have an account? ',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      GestureDetector(
                        onTap: _toggleMode,
                        child: Text(
                          _isSignUp ? 'Sign In' : 'Sign Up',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
  }

  void _showPolicyDialog(String policyType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PolicyViewerScreen(
          policyType: policyType,
        ),
      ),
    );
  }
} 