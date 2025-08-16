import 'package:flutter/material.dart';
import 'judge_registration_screen.dart';

class JudgeAgreementScreen extends StatefulWidget {
  final String currentUserId;

  const JudgeAgreementScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<JudgeAgreementScreen> createState() => _JudgeAgreementScreenState();
}

class _JudgeAgreementScreenState extends State<JudgeAgreementScreen> {
  bool _hasAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Judge Role'),
        backgroundColor: const Color(0xFFFFC107),
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
                    Icons.balance,
                    size: 48,
                    color: Color(0xFFFFC107),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Become a Judge',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF57C00),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Evaluate arguments and determine winners in Arena debates',
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
                    'Judge Responsibilities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF57C00),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildResponsibility(
                    '⚖️ Evaluate Arguments',
                    'Assess the strength, logic, and evidence presented by each debater objectively.',
                  ),
                  _buildResponsibility(
                    '🎯 Score Fairly',
                    'Provide unbiased scoring based on argument quality, not personal beliefs or preferences.',
                  ),
                  _buildResponsibility(
                    '📝 Give Feedback',
                    'Offer constructive feedback to help debaters improve their skills and arguments.',
                  ),
                  _buildResponsibility(
                    '🧠 Stay Objective',
                    'Set aside personal opinions and judge solely on the merits of the arguments presented.',
                  ),
                  _buildResponsibility(
                    '📊 Apply Criteria',
                    'Use consistent judging criteria including logic, evidence, delivery, and rebuttal effectiveness.',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Judging Criteria
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
                    'Judging Criteria',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF57C00),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCriteria('Argument Strength', 'Quality and persuasiveness of main points'),
                  _buildCriteria('Evidence & Facts', 'Use of credible sources and supporting data'),
                  _buildCriteria('Logic & Reasoning', 'Coherence and logical flow of arguments'),
                  _buildCriteria('Rebuttals', 'Effectiveness in addressing opposing points'),
                  _buildCriteria('Communication', 'Clarity, organization, and presentation'),
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
                    'Judge Commitment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF57C00),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'As an Arena Judge, I commit to:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCommitment('✓ Judge all debates objectively and without bias'),
                  _buildCommitment('✓ Base decisions solely on argument merit, not personal beliefs'),
                  _buildCommitment('✓ Provide fair and constructive feedback'),
                  _buildCommitment('✓ Maintain confidentiality of deliberation processes'),
                  _buildCommitment('✓ Uphold the highest standards of integrity'),
                  _buildCommitment('✓ Disclose any conflicts of interest'),
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
                  color: const Color(0xFFFFC107).withValues(alpha: 0.3),
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
                    activeColor: const Color(0xFFFFC107),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I have read and understand the judge responsibilities and criteria. I agree to evaluate all debates objectively and fairly, putting aside personal biases to ensure the integrity of The Arena.',
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
                  backgroundColor: const Color(0xFFFFC107),
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

  Widget _buildCriteria(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8, right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFC107),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
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
        builder: (context) => JudgeRegistrationScreen(
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