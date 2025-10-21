// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = 'APIwzQr7qFmXHcy';
  const apiSecret = '2gVhXTdGbSJ4bPSpomxfaHjCA8PBdmJ4N7h89dZAJT9';
  const liveKitUrl = 'http://34.171.185.205:7879';

  print('🧪 Testing LiveKit Egress Authentication...');
  print('📡 Server: $liveKitUrl');
  print('🔑 API Key: ${apiKey.substring(0, 8)}...');

  try {
    // Generate JWT token
    final jwt = JWT({
      'iss': apiKey,
      'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      'nbf': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'video': {
        'roomRecord': true,
        'room': 'test-room',
      },
      'roomAdmin': true,
      'roomCreate': true,
    });

    final token = jwt.sign(SecretKey(apiSecret), algorithm: JWTAlgorithm.HS256);
    print('🎫 JWT Token: ${token.substring(0, 20)}...');

    // Test 1: List existing egress sessions
    print('\n1️⃣ Testing ListEgress endpoint...');
    final listUrl = Uri.parse('$liveKitUrl/twirp/livekit.Egress/ListEgress');

    final listResponse = await http.post(
      listUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );

    print('📊 ListEgress Status: ${listResponse.statusCode}');
    print('📄 ListEgress Response: ${listResponse.body}');

    if (listResponse.statusCode == 200) {
      print('✅ Authentication working! Egress service is accessible.');

      // Test 2: Try to start a test recording
      print('\n2️⃣ Testing StartRoomCompositeEgress...');
      final startUrl = Uri.parse('$liveKitUrl/twirp/livekit.Egress/StartRoomCompositeEgress');

      final startPayload = {
        'room_name': 'test-arena-room',
        'layout': 'speaker',
        'audio_only': true,
        'file_outputs': [
          {
            'file_type': 'MP3',
            'filepath': 'test_recording.mp3',
          }
        ],
        'options': {
          'preset': 'MEDIUM',
        }
      };

      final startResponse = await http.post(
        startUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(startPayload),
      );

      print('🎬 StartRecording Status: ${startResponse.statusCode}');
      print('📄 StartRecording Response: ${startResponse.body}');

      if (startResponse.statusCode == 200) {
        print('🎉 SUCCESS! Recording can be started.');

        final responseData = jsonDecode(startResponse.body);
        final egressId = responseData['egress_id'];
        print('🆔 Egress ID: $egressId');

        // Stop the test recording
        if (egressId != null) {
          print('\n3️⃣ Stopping test recording...');
          final stopUrl = Uri.parse('$liveKitUrl/twirp/livekit.Egress/StopEgress');

          final stopResponse = await http.post(
            stopUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'egress_id': egressId}),
          );

          print('⏹️ StopRecording Status: ${stopResponse.statusCode}');
          print('📄 StopRecording Response: ${stopResponse.body}');
        }

      } else {
        print('❌ Failed to start recording: ${startResponse.body}');
      }

    } else {
      print('❌ Authentication failed: ${listResponse.body}');
    }

  } catch (e) {
    print('💥 Test failed: $e');
  }

  print('\n🏁 Test completed.');
}