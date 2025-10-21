// ignore_for_file: avoid_print, unused_local_variable
import 'dart:io';

void main() {
  print('''
╔══════════════════════════════════════════════════════════════╗
║            🎬 LiveKit Egress Configuration Setup              ║
╚══════════════════════════════════════════════════════════════╝

This script will help you configure LiveKit Cloud for recording Arena debates.

📋 Prerequisites:
1. LiveKit Cloud account (https://cloud.livekit.io)
2. Create a new project or use existing one
3. Get your API Key and Secret from the Settings page

''');

  // Check current environment
  final currentApiKey = Platform.environment['LIVEKIT_API_KEY'] ?? '';
  final currentApiSecret = Platform.environment['LIVEKIT_API_SECRET'] ?? '';
  final currentUrl = Platform.environment['LIVEKIT_URL'] ?? 'wss://arena-debates-zbkzwdqv.livekit.cloud';

  if (currentApiKey.isNotEmpty) {
    print('✅ Current LiveKit configuration detected:');
    print('   API Key: ${currentApiKey.substring(0, 10)}...');
    print('   URL: $currentUrl');
    print('');
  }

  print('''
🔧 Setup Instructions:
═══════════════════════════════════════════════════════════════

1️⃣ Get your LiveKit credentials:
   • Go to: https://cloud.livekit.io
   • Select your project
   • Go to Settings → Keys
   • Copy your API Key and Secret

2️⃣ Set environment variables:

   For macOS/Linux (add to ~/.bashrc or ~/.zshrc):
   ────────────────────────────────────────────────
   export LIVEKIT_API_KEY="your_api_key_here"
   export LIVEKIT_API_SECRET="your_api_secret_here"
   export LIVEKIT_URL="wss://your-project.livekit.cloud"
   ────────────────────────────────────────────────

   For Windows (Command Prompt):
   ────────────────────────────────────────────────
   setx LIVEKIT_API_KEY "your_api_key_here"
   setx LIVEKIT_API_SECRET "your_api_secret_here"
   setx LIVEKIT_URL "wss://your-project.livekit.cloud"
   ────────────────────────────────────────────────

3️⃣ Or add directly to the code (lib/services/recording_service.dart):
   ────────────────────────────────────────────────
   static const String _liveKitApiKey = 'your_api_key_here';
   static const String _liveKitApiSecret = 'your_api_secret_here';
   static const String _liveKitUrl = 'wss://your-project.livekit.cloud';
   ────────────────────────────────────────────────

4️⃣ Restart your Flutter app after setting credentials

📝 LiveKit Egress Features Enabled:
• Audio-only recording (MP3 format)
• Automatic file upload to storage
• Playback system integration
• Timeline and event capture

💰 LiveKit Pricing:
• Free tier: 50 participant minutes/month
• Egress: \$0.004 per minute for audio recording
• Storage: Use your own (IONOS configured)

🧪 Testing:
1. Create an arena with "Enable Playback" checked
2. Start the debate (recording begins automatically)
3. End the debate (recording stops and processes)
4. Check logs for recording status

Need help? Visit: https://docs.livekit.io/cloud/
''');

  // Offer to create .env file
  print('Would you like to create a .env file with placeholders? (y/n): ');
  final answer = stdin.readLineSync()?.toLowerCase();

  if (answer == 'y' || answer == 'yes') {
    final envFile = File('.env');
    if (envFile.existsSync()) {
      print('⚠️  .env file already exists. Overwrite? (y/n): ');
      final overwrite = stdin.readLineSync()?.toLowerCase();
      if (overwrite != 'y' && overwrite != 'yes') {
        print('✅ Keeping existing .env file');
        return;
      }
    }

    envFile.writeAsStringSync('''
# LiveKit Configuration
LIVEKIT_API_KEY=your_api_key_here
LIVEKIT_API_SECRET=your_api_secret_here
LIVEKIT_URL=wss://your-project.livekit.cloud

# IONOS Storage Configuration (Optional)
IONOS_SERVER_HOST=50.21.187.76
IONOS_SERVER_USER=root
IONOS_SERVER_PATH=/var/www/arena-recordings
IONOS_BASE_URL=https://arena-recordings.your-domain.com
''');

    print('✅ Created .env file with placeholders');
    print('📝 Edit .env and add your actual credentials');
  }
}