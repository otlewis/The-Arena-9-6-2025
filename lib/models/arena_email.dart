/// Email Draft model for saving unsent emails
class EmailDraft {
  final String id;
  final String userId;
  final String? recipientId;
  final String? recipientUsername;
  final String subject;
  final String body;
  final DateTime lastModified;
  final String? recipientEmail;

  EmailDraft({
    required this.id,
    required this.userId,
    this.recipientId,
    this.recipientUsername,
    required this.subject,
    required this.body,
    required this.lastModified,
    this.recipientEmail,
  });

  factory EmailDraft.fromJson(Map<String, dynamic> json) {
    return EmailDraft(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      recipientId: json['recipientId'],
      recipientUsername: json['recipientUsername'],
      subject: json['subject'] ?? '',
      body: json['body'] ?? '',
      lastModified: json['lastModified'] != null 
        ? DateTime.parse(json['lastModified'])
        : DateTime.now(),
      recipientEmail: json['recipientEmail'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'recipientId': recipientId,
      'recipientUsername': recipientUsername,
      'subject': subject,
      'body': body,
      'lastModified': lastModified.toIso8601String(),
      'recipientEmail': recipientEmail,
    };
  }
}

/// Arena Email model for internal email system
class ArenaEmail {
  final String id;
  final String senderId;
  final String recipientId;
  final String senderUsername;
  final String recipientUsername;
  final String subject;
  final String body;
  final bool isRead;
  final String emailType; // personal, challenge, results, feedback
  final DateTime createdAt;
  final String? threadId;
  final bool isStarred;
  final bool isArchived;
  final List<String>? attachments;

  ArenaEmail({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.senderUsername,
    required this.recipientUsername,
    required this.subject,
    required this.body,
    this.isRead = false,
    this.emailType = 'personal',
    required this.createdAt,
    this.threadId,
    this.isStarred = false,
    this.isArchived = false,
    this.attachments,
  });

  // Get formatted Arena email address
  String get senderEmail => '${senderUsername.toLowerCase()}@arena.dtd';
  String get recipientEmail => '${recipientUsername.toLowerCase()}@arena.dtd';

  factory ArenaEmail.fromJson(Map<String, dynamic> json) {
    return ArenaEmail(
      id: json['\$id'] ?? json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      recipientId: json['recipientId'] ?? '',
      senderUsername: json['senderUsername'] ?? '',
      recipientUsername: json['recipientUsername'] ?? '',
      subject: json['subject'] ?? '',
      body: json['body'] ?? '',
      isRead: json['isRead'] ?? false,
      emailType: json['emailType'] ?? 'personal',
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
      threadId: json['threadId'],
      isStarred: json['isStarred'] ?? false,
      isArchived: json['isArchived'] ?? false,
      attachments: json['attachments'] != null 
        ? List<String>.from(json['attachments'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'recipientId': recipientId,
      'senderUsername': senderUsername,
      'recipientUsername': recipientUsername,
      'subject': subject,
      'body': body,
      'isRead': isRead,
      'emailType': emailType,
      'createdAt': createdAt.toIso8601String(),
      'threadId': threadId,
      'isStarred': isStarred,
      'isArchived': isArchived,
    };
  }
}

/// Email template for debate-specific emails
class EmailTemplate {
  final String id;
  final String templateType; // challenge, results, rematch, feedback
  final String subject;
  final String bodyTemplate;
  final List<String> variables; // Dynamic content placeholders

  EmailTemplate({
    required this.id,
    required this.templateType,
    required this.subject,
    required this.bodyTemplate,
    required this.variables,
  });

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    return EmailTemplate(
      id: json['\$id'] ?? json['id'] ?? '',
      templateType: json['templateType'] ?? '',
      subject: json['subject'] ?? '',
      bodyTemplate: json['bodyTemplate'] ?? '',
      variables: json['variables'] != null 
        ? List<String>.from(json['variables'])
        : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templateType': templateType,
      'subject': subject,
      'bodyTemplate': bodyTemplate,
      'variables': variables,
    };
  }

  // Generate email from template
  ArenaEmail generateEmail({
    required String senderId,
    required String recipientId,
    required String senderUsername,
    required String recipientUsername,
    Map<String, String>? replacements,
  }) {
    String processedBody = bodyTemplate;
    
    // Replace variables in template
    if (replacements != null) {
      replacements.forEach((key, value) {
        processedBody = processedBody.replaceAll('{{$key}}', value);
      });
    }

    return ArenaEmail(
      id: '', // Will be generated by Appwrite
      senderId: senderId,
      recipientId: recipientId,
      senderUsername: senderUsername,
      recipientUsername: recipientUsername,
      subject: subject,
      body: processedBody,
      emailType: templateType,
      createdAt: DateTime.now(),
    );
  }
}

/// Predefined email templates
class EmailTemplates {
  static final challenge = EmailTemplate(
    id: 'challenge',
    templateType: 'challenge',
    subject: 'Debate Challenge from {{senderName}}',
    bodyTemplate: '''
Hello {{recipientName}},

I challenge you to a debate on the topic: "{{topic}}"

Proposed format: {{format}}
Proposed time: {{time}}

Do you accept this challenge?

Best regards,
{{senderName}}
''',
    variables: ['senderName', 'recipientName', 'topic', 'format', 'time'],
  );

  static final results = EmailTemplate(
    id: 'results',
    templateType: 'results',
    subject: 'Debate Results: {{topic}}',
    bodyTemplate: '''
Congratulations on completing your debate!

Topic: {{topic}}
Date: {{date}}
Winner: {{winner}}

Scores:
{{scores}}

Judge Feedback:
{{feedback}}

Thank you for participating in The Arena!
''',
    variables: ['topic', 'date', 'winner', 'scores', 'feedback'],
  );

  static final rematch = EmailTemplate(
    id: 'rematch',
    templateType: 'rematch',
    subject: 'Rematch Request from {{senderName}}',
    bodyTemplate: '''
Hello {{recipientName}},

Great debate on "{{topic}}"! 

I'd like to challenge you to a rematch. Are you interested?

{{message}}

Best regards,
{{senderName}}
''',
    variables: ['senderName', 'recipientName', 'topic', 'message'],
  );

  static final feedback = EmailTemplate(
    id: 'feedback',
    templateType: 'feedback',
    subject: 'Judge Feedback on Your Debate',
    bodyTemplate: '''
Dear {{recipientName}},

Here's the detailed feedback from the judges on your recent debate:

Topic: {{topic}}

{{feedbackContent}}

Keep up the great work!

The Arena Team
''',
    variables: ['recipientName', 'topic', 'feedbackContent'],
  );
}