import 'package:flutter/material.dart';
import 'moderator_registration_screen.dart';

class ModeratorAgreementScreen extends StatefulWidget {
  final String currentUserId;

  const ModeratorAgreementScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<ModeratorAgreementScreen> createState() => _ModeratorAgreementScreenState();
}

class _ModeratorAgreementScreenState extends State<ModeratorAgreementScreen> {
  bool _hasAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Moderator Role'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.gavel,
                    size: 48,
                    color: Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Become a Moderator',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help maintain fair and engaging debates in The Arena',
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
            
            // Role Description
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Moderator Responsibilities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildResponsibility(
                    '🛡️ Enforce Rules',
                    'Ensure all participants follow Arena debate guidelines and maintain respectful discourse.',
                  ),
                  _buildResponsibility(
                    '⏰ Manage Time',
                    'Control debate timing, ensure fair speaking opportunities, and maintain debate structure.',
                  ),
                  _buildResponsibility(
                    '🎯 Stay Neutral',
                    'Remain completely impartial and avoid expressing personal opinions on debate topics.',
                  ),
                  _buildResponsibility(
                    '🔨 Handle Violations',
                    'Address rule violations promptly and fairly, including warnings and participant removal when necessary.',
                  ),
                  _buildResponsibility(
                    '📋 Facilitate Discussion',
                    'Guide the debate flow, ensure all voices are heard, and maintain productive dialogue.',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Commitment Section
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Moderator Commitment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'As an Arena Moderator, I commit to:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCommitment('✓ Moderate all debates fairly and without bias'),
                  _buildCommitment('✓ Respect all participants regardless of their viewpoints'),
                  _buildCommitment('✓ Apply rules consistently and transparently'),
                  _buildCommitment('✓ Maintain professionalism at all times'),
                  _buildCommitment('✓ Protect the integrity of The Arena community'),
                  _buildCommitment('✓ Report any conflicts of interest or concerns'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Agreement Checkbox
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _hasAgreed,
                    onChanged: (value) {
                      setState(() {
                        _hasAgreed = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF8B5CF6),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I have read and understand the moderator responsibilities. I agree to fulfill these duties fairly and impartially, maintaining the highest standards of conduct in The Arena.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _hasAgreed ? _proceedToRegistration : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue to Registration',
                  style: TextStyle(
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

  Widget _buildResponsibility(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.split(' ')[0], // Get emoji
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.substring(title.indexOf(' ') + 1), // Get title without emoji
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitment(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
          height: 1.3,
        ),
      ),
    );
  }

  void _proceedToRegistration() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModeratorRegistrationScreen(
          currentUserId: widget.currentUserId,
        ),
      ),
    );
    
    // If registration was successful, pop back to home with success result
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }
}