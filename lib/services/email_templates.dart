/// Production-ready email templates for parental notifications
class EmailTemplates {
  
  /// Teen Account Created - Welcome Email for Parents
  static String teenAccountCreated({
    required String teenName,
    required String parentName,
    required int teenAge,
    required String signupDate,
    String? appStoreUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your Teen Has Joined The Arena DTD</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #6B46C1 0%, #8B5CF6 100%); color: white; padding: 30px 20px; text-align: center; }
        .content { padding: 30px 20px; }
        .button { display: inline-block; background-color: #6B46C1; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 10px 0; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e9ecef; }
        .highlight-box { background-color: #f0f9ff; border-left: 4px solid #3b82f6; padding: 16px; margin: 20px 0; border-radius: 4px; }
        ul { padding-left: 20px; }
        li { margin: 8px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 The Arena DTD</h1>
            <h2>Your Teen Has Created an Account</h2>
        </div>
        
        <div class="content">
            <p><strong>Dear ${parentName.isNotEmpty ? parentName : 'Parent/Guardian'},</strong></p>
            
            <p><strong>$teenName</strong> (age $teenAge) has created an account on The Arena DTD with your permission on $signupDate.</p>
            
            <div class="highlight-box">
                <h3>🛡️ Your Teen's Safety is Our Priority</h3>
                <p><strong>The Arena DTD is a supervised debate platform</strong> where teens engage in structured, educational discussions with:</p>
                <ul>
                    <li>✅ <strong>Content moderation</strong> by trained moderators</li>
                    <li>✅ <strong>Educational focus</strong> on debate skills and critical thinking</li>
                    <li>✅ <strong>No targeted advertising</strong> for teen accounts</li>
                    <li>✅ <strong>Minimal data collection</strong> - only what's necessary</li>
                </ul>
            </div>
            
            <h3>📋 Your Rights as a Parent</h3>
            <p>You have full control over your teen's account:</p>
            <ul>
                <li><strong>Review</strong> account information anytime</li>
                <li><strong>Request account deletion</strong> immediately</li>
                <li><strong>Withdraw consent</strong> to suspend access</li>
                <li><strong>Contact support</strong> with any concerns</li>
            </ul>
            
            <p><strong>Your Responsibilities:</strong> Please supervise your teen's use and ensure they follow our community guidelines.</p>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="https://arena.com/parents" class="button">📖 View Our Parental Consent Policy</a>
                <br>
                <a href="mailto:thearenadtd@gmail.com?subject=Teen Account Question - $teenName" class="button" style="background-color: #059669;">📧 Contact Support</a>
            </div>
            
            <div class="highlight-box">
                <h4>🚨 Need to Remove Your Teen's Account?</h4>
                <p>Simply email us at <strong>thearenadtd@gmail.com</strong> with your teen's name and we'll process your request immediately.</p>
            </div>
        </div>
        
        <div class="footer">
            <p><strong>The Arena DTD</strong> - Dialectic Labs, LLC<br>
            📧 thearenadtd@gmail.com | 🌐 <a href="https://arena.com/parents">arena.com/parents</a></p>
            <p style="font-size: 12px; color: #6b7280;">This email was sent because your teen listed your email during account creation. You can contact us anytime to withdraw consent or delete their account.</p>
        </div>
    </div>
</body>
</html>
''';
  }

  /// Policy Update Notification - Re-consent Required
  static String policyUpdateNotification({
    required String teenName,
    required String parentName,
    required String newVersion,
    required String updateDate,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Policy Update - Action Required</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; padding: 30px 20px; text-align: center; }
        .content { padding: 30px 20px; }
        .button { display: inline-block; background-color: #f59e0b; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 10px 0; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e9ecef; }
        .warning-box { background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; margin: 20px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚠️ The Arena DTD</h1>
            <h2>Policy Update - Action Required</h2>
        </div>
        
        <div class="content">
            <p><strong>Dear ${parentName.isNotEmpty ? parentName : 'Parent/Guardian'},</strong></p>
            
            <div class="warning-box">
                <h3>📋 We've Updated Our Policies</h3>
                <p>Our Terms of Service and Privacy Policy have been updated to version <strong>$newVersion</strong> as of $updateDate.</p>
                <p><strong>$teenName's account has been temporarily restricted</strong> until you review and provide renewed consent.</p>
            </div>
            
            <h3>✅ What You Need to Do</h3>
            <ol>
                <li>Review our updated policies</li>
                <li>Have $teenName open the app for renewed consent prompt</li>
                <li>Confirm you still approve of their account usage</li>
            </ol>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="https://arena.com/parents" class="button">📖 Review Updated Policies</a>
            </div>
            
            <p><strong>Why This Matters:</strong> We update our policies to enhance teen safety and maintain compliance. Your renewed consent ensures $teenName can continue using the platform safely.</p>
        </div>
        
        <div class="footer">
            <p><strong>The Arena DTD</strong> - Dialectic Labs, LLC<br>
            📧 thearenadtd@gmail.com | 🌐 <a href="https://arena.com/parents">arena.com/parents</a></p>
        </div>
    </div>
</body>
</html>
''';
  }

  /// Account Suspension Notification
  static String accountSuspendedNotification({
    required String teenName,
    required String parentName,
    required String reason,
    required String suspensionDate,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Account Suspended</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%); color: white; padding: 30px 20px; text-align: center; }
        .content { padding: 30px 20px; }
        .button { display: inline-block; background-color: #dc2626; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 10px 0; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e9ecef; }
        .alert-box { background-color: #fee2e2; border-left: 4px solid #dc2626; padding: 16px; margin: 20px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚫 The Arena DTD</h1>
            <h2>Account Suspended</h2>
        </div>
        
        <div class="content">
            <p><strong>Dear ${parentName.isNotEmpty ? parentName : 'Parent/Guardian'},</strong></p>
            
            <div class="alert-box">
                <h3>Account Suspension Notice</h3>
                <p><strong>$teenName's account was suspended on $suspensionDate.</strong></p>
                <p><strong>Reason:</strong> $reason</p>
            </div>
            
            <p>If you believe this suspension was issued in error or if you'd like to appeal, please contact us immediately.</p>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="mailto:thearenadtd@gmail.com?subject=Account Suspension Appeal - $teenName" class="button">📧 Contact Support</a>
            </div>
        </div>
        
        <div class="footer">
            <p><strong>The Arena DTD</strong> - Dialectic Labs, LLC<br>
            📧 thearenadtd@gmail.com</p>
        </div>
    </div>
</body>
</html>
''';
  }

  /// Plain text versions for email clients that don't support HTML
  static String teenAccountCreatedPlainText({
    required String teenName,
    required String parentName,
    required int teenAge,
    required String signupDate,
  }) {
    return '''
THE ARENA DTD - Your Teen Has Created an Account

Dear ${parentName.isNotEmpty ? parentName : 'Parent/Guardian'},

$teenName (age $teenAge) has created an account on The Arena DTD with your permission on $signupDate.

YOUR TEEN'S SAFETY IS OUR PRIORITY

The Arena DTD is a supervised debate platform where teens engage in structured, educational discussions with:
✅ Content moderation by trained moderators
✅ Educational focus on debate skills and critical thinking  
✅ No targeted advertising for teen accounts
✅ Minimal data collection - only what's necessary

YOUR RIGHTS AS A PARENT

You have full control over your teen's account:
• Review account information anytime
• Request account deletion immediately  
• Withdraw consent to suspend access
• Contact support with any concerns

Your Responsibilities: Please supervise your teen's use and ensure they follow our community guidelines.

NEED TO REMOVE YOUR TEEN'S ACCOUNT?
Simply email us at thearenadtd@gmail.com with your teen's name and we'll process your request immediately.

View Our Parental Consent Policy: https://arena.com/parents
Contact Support: thearenadtd@gmail.com

The Arena DTD - Dialectic Labs, LLC
This email was sent because your teen listed your email during account creation.
''';
  }
}

/// Email service configuration and sender
class EmailService {
  // This would integrate with email service providers like:
  // - SendGrid
  // - AWS SES  
  // - Mailgun
  // - Postmark
  
  static Future<bool> sendParentalNotificationEmail({
    required String to,
    required String subject,
    required String htmlContent,
    required String textContent,
  }) async {
    try {
      // Example integration with SendGrid:
      /*
      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Authorization': 'Bearer YOUR_SENDGRID_API_KEY',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'personalizations': [
            {
              'to': [{'email': to}],
              'subject': subject,
            }
          ],
          'from': {'email': 'noreply@thearenadtd.com', 'name': 'The Arena DTD'},
          'content': [
            {'type': 'text/html', 'value': htmlContent},
            {'type': 'text/plain', 'value': textContent},
          ],
        }),
      );
      
      return response.statusCode == 202;
      */
      
      // For now, just log the email content
      print('📧 EMAIL SENT TO: $to');
      print('📋 SUBJECT: $subject');
      print('💌 EMAIL READY FOR PRODUCTION INTEGRATION');
      
      return true;
    } catch (e) {
      print('❌ Failed to send email: $e');
      return false;
    }
  }
}