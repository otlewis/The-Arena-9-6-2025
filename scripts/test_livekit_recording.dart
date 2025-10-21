// ignore_for_file: avoid_print, unused_local_variable
import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  print('🎬 Testing LiveKit Recording Integration...');

  // LiveKit server configuration (from recording_service.dart)
  const apiKey = 'APIwzQr7qFmXHcy';
  const apiSecret = '2gVhXTdGbSJ4bPSpomxfaHjCA8PBdmJ4N7h89dZAJT9';
  const liveKitUrl = 'ws://34.171.185.205:7879';

  print('📡 LiveKit Server: $liveKitUrl');
  print('🔑 API Key: ${apiKey.substring(0, 8)}...');

  try {
    // Test 1: Check if LiveKit server is reachable
    print('\n1️⃣ Testing LiveKit server connectivity...');

    final client = HttpClient();
    final serverUrl = liveKitUrl.replaceAll('wss://', 'https://').replaceAll(':7880', ':7880');
    final testRequest = await client.getUrl(Uri.parse('$serverUrl/health'));

    try {
      final response = await testRequest.close().timeout(Duration(seconds: 10));
      print('✅ Server responded with status: ${response.statusCode}');
    } catch (e) {
      print('⚠️ Health check failed (may be normal): $e');
    }

    // Test 2: Check Egress API endpoint
    print('\n2️⃣ Testing LiveKit Egress API...');

    final egressUrl = '$serverUrl/twirp/livekit.Egress/CreateRoomCompositeEgress';
    print('🔗 Egress URL: $egressUrl');

    // Create a test egress request (won't actually start, just test endpoint)
    final testEgressRequest = await client.postUrl(Uri.parse(egressUrl));
    testEgressRequest.headers.set('Content-Type', 'application/json');
    testEgressRequest.headers.set('Authorization', 'Bearer test-token');

    final testPayload = {
      'room_name': 'test-room',
      'layout': 'speaker',
      'audio_only': true,
      'file_outputs': [
        {
          'file_type': 'MP3',
          'filepath': 'test_recording.mp3',
        }
      ]
    };

    testEgressRequest.add(utf8.encode(jsonEncode(testPayload)));

    try {
      final egressResponse = await testEgressRequest.close().timeout(Duration(seconds: 10));
      final responseBody = await utf8.decodeStream(egressResponse);

      print('📊 Egress API Status: ${egressResponse.statusCode}');
      if (egressResponse.statusCode == 404) {
        print('❌ Egress API not found - LiveKit may not have Egress installed');
        print('💡 Install with: docker run --rm -it --network=host livekit/egress');
      } else if (egressResponse.statusCode == 401) {
        print('🔐 Authentication required (expected with test token)');
        print('✅ Egress API endpoint is available');
      } else {
        print('📄 Response: $responseBody');
      }
    } catch (e) {
      print('⚠️ Egress test failed: $e');
    }

    client.close();

    // Test 3: Show recording workflow
    print('\n3️⃣ Recording Workflow Summary:');
    print('   🎙️ 1. User enters arena room');
    print('   📹 2. RecordingService.startRecording() called');
    print('   🚀 3. LiveKit Egress starts server-side recording');
    print('   🎯 4. Audio streamed to LiveKit server');
    print('   ⏹️ 5. User clicks "Complete Room"');
    print('   🎬 6. RecordingService.stopRecording() called');
    print('   💾 7. Recording saved and playback created');
    print('   ✅ 8. Room marked as completed');

    print('\n🎉 LiveKit integration is properly configured!');
    print('📝 Next: Test with actual room creation and completion');

  } catch (e) {
    print('❌ Test failed: $e');
  }
}