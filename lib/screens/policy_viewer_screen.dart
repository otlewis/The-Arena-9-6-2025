import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PolicyViewerScreen extends StatefulWidget {
  final String policyType;

  const PolicyViewerScreen({
    super.key,
    required this.policyType,
  });

  @override
  State<PolicyViewerScreen> createState() => _PolicyViewerScreenState();
}

class _PolicyViewerScreenState extends State<PolicyViewerScreen> {
  String _policyContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      String content;
      if (widget.policyType == 'Terms of Service') {
        content = await rootBundle.loadString('TERMS_OF_SERVICE.md');
      } else {
        content = await rootBundle.loadString('PRIVACY_POLICY.md');
      }
      
      setState(() {
        _policyContent = content;
        _isLoading = false;
      });
    } catch (e) {
      // Simple fallback content
      setState(() {
        if (widget.policyType == 'Terms of Service') {
          _policyContent = '''# Terms of Service
**The Arena DTD**

*Last Updated: September 2025*

## 1. Acceptance of Terms
By using The Arena DTD, you agree to these terms.

## 2. Age Requirement
You must be 18 years or older to use this app.

## 3. User Conduct
- Be respectful in debates
- No harassment or hate speech
- Follow moderator instructions

For full terms, visit: http://50.21.187.76/terms.html

Contact: thearenadtd@gmail.com''';
        } else {
          _policyContent = '''# Privacy Policy
**The Arena DTD**

*Last Updated: September 2025*

## 1. Information We Collect
- Account information (email, name)
- Debate participation data
- Voice/video during debates (not stored)

## 2. How We Use Information
- Provide app services
- Enable debates and discussions
- Improve the app

## 3. Your Rights (GDPR/CCPA)
- Access your data
- Delete your account
- Export your data

For full policy, visit: http://50.21.187.76/privacy.html

Contact: thearenadtd@gmail.com''';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          widget.policyType,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B46C1),
              ),
            )
          : Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Markdown(
                data: _policyContent,
                styleSheet: MarkdownStyleSheet(
                  h1: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  h2: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  h3: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5568),
                  ),
                  p: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                  listBullet: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  strong: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  em: const TextStyle(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B46C1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Close',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}