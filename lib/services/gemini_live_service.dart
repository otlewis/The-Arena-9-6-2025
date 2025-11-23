import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/logging/app_logger.dart';

/// Gemini Live API Service for real-time AI voice conversations
/// with Google Search grounding for fact-checking
class GeminiLiveService {
  static final GeminiLiveService _instance = GeminiLiveService._internal();
  factory GeminiLiveService() => _instance;
  GeminiLiveService._internal();

  final _logger = AppLogger();

  // API Configuration
  static const String _baseUrl = 'generativelanguage.googleapis.com';
  static const String _model = 'gemini-2.0-flash-exp';

  // Get API key from environment (set via --dart-define)
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // WebSocket connection for Live API
  WebSocketChannel? _wsChannel;
  bool _isConnected = false;
  bool _isListening = false;

  // Audio buffers
  final List<Uint8List> _audioBuffer = [];

  // Callbacks
  Function(String)? onTranscript;
  Function(Uint8List)? onAudioResponse;
  Function(String)? onError;
  Function(List<Map<String, dynamic>>)? onSearchResults;

  // Stream controllers
  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  /// Check if API key is configured
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Check if currently connected
  bool get isConnected => _isConnected;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Initialize the Gemini Live connection for a debate room
  Future<bool> initialize({
    required String roomId,
    required String debateTopic,
  }) async {
    if (!isConfigured) {
      _logger.error('Gemini API key not configured. Set GEMINI_API_KEY environment variable.');
      onError?.call('AI service not configured');
      return false;
    }

    try {
      _logger.info('Initializing Gemini Live for room: $roomId');
      _logger.info('Debate topic: $debateTopic');

      // Build WebSocket URL for Gemini Live API
      final wsUrl = Uri(
        scheme: 'wss',
        host: _baseUrl,
        path: '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
        queryParameters: {'key': _apiKey},
      );

      _wsChannel = WebSocketChannel.connect(wsUrl);

      // Listen for responses
      _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          _logger.error('WebSocket error: $error');
          onError?.call('Connection error: $error');
          _isConnected = false;
        },
        onDone: () {
          _logger.info('WebSocket connection closed');
          _isConnected = false;
        },
      );

      // Send initial setup message with system instructions
      final setupMessage = {
        'setup': {
          'model': 'models/$_model',
          'generation_config': {
            'response_modalities': ['AUDIO', 'TEXT'],
            'speech_config': {
              'voice_config': {
                'prebuilt_voice_config': {
                  'voice_name': 'Aoede', // Professional sounding voice
                }
              }
            }
          },
          'system_instruction': {
            'parts': [{
              'text': '''You are an AI fact-checker and research assistant for a live debate on the topic: "$debateTopic".

Your role:
- Listen to the debate discussion
- When asked, fact-check claims using real-time Google Search
- Provide accurate, sourced information
- Be concise and clear (responses should be 30 seconds or less when spoken)
- Always cite your sources
- Remain neutral and objective
- If you're unsure, say so

When fact-checking:
- Search for recent, authoritative sources
- Distinguish between facts, opinions, and disputed claims
- Provide context when needed

Keep responses brief and suitable for audio - aim for 2-3 sentences unless more detail is requested.'''
            }]
          },
          'tools': [
            {
              'google_search': {}  // Enable Search Grounding
            }
          ]
        }
      };

      _wsChannel!.sink.add(jsonEncode(setupMessage));
      _isConnected = true;
      _logger.info('Gemini Live connection established');

      return true;
    } catch (e) {
      _logger.error('Failed to initialize Gemini Live: $e');
      onError?.call('Failed to connect to AI service');
      return false;
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // Handle different response types
      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'] as Map<String, dynamic>;

        // Check for model turn (response)
        if (serverContent.containsKey('modelTurn')) {
          final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>;
          final parts = modelTurn['parts'] as List<dynamic>?;

          if (parts != null) {
            for (final part in parts) {
              // Text response
              if (part['text'] != null) {
                final text = part['text'] as String;
                _logger.info('Gemini text response: $text');
                _responseController.add(text);
                onTranscript?.call(text);
              }

              // Audio response
              if (part['inlineData'] != null) {
                final inlineData = part['inlineData'] as Map<String, dynamic>;
                if (inlineData['mimeType']?.toString().startsWith('audio/') == true) {
                  final audioData = base64Decode(inlineData['data'] as String);
                  _logger.info('Received audio response: ${audioData.length} bytes');
                  onAudioResponse?.call(audioData);
                }
              }
            }
          }
        }

        // Check for grounding metadata (search results)
        if (serverContent.containsKey('groundingMetadata')) {
          final metadata = serverContent['groundingMetadata'] as Map<String, dynamic>;
          final chunks = metadata['groundingChunks'] as List<dynamic>?;

          if (chunks != null) {
            final searchResults = chunks.map((chunk) {
              final web = chunk['web'] as Map<String, dynamic>?;
              return {
                'title': web?['title'] ?? '',
                'uri': web?['uri'] ?? '',
              };
            }).toList();

            _logger.info('Search results: ${searchResults.length} sources');
            onSearchResults?.call(searchResults.cast<Map<String, dynamic>>());
          }
        }

        // Check if turn is complete
        if (serverContent['turnComplete'] == true) {
          _logger.info('AI response complete');
        }
      }

      // Handle setup complete
      if (data.containsKey('setupComplete')) {
        _logger.info('Gemini Live setup complete');
      }

    } catch (e) {
      _logger.error('Error parsing WebSocket message: $e');
    }
  }

  /// Send audio data to Gemini for processing
  void sendAudio(Uint8List audioData) {
    if (!_isConnected || _wsChannel == null) {
      _logger.warning('Cannot send audio - not connected');
      return;
    }

    final message = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'mimeType': 'audio/pcm;rate=16000',
            'data': base64Encode(audioData),
          }
        ]
      }
    };

    _wsChannel!.sink.add(jsonEncode(message));
  }

  /// Send a text query to Gemini (for fact-check requests)
  Future<void> sendQuery(String query) async {
    if (!_isConnected || _wsChannel == null) {
      _logger.warning('Cannot send query - not connected');
      onError?.call('AI not connected');
      return;
    }

    _logger.info('Sending query to Gemini: $query');

    final message = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': query}
            ]
          }
        ],
        'turnComplete': true
      }
    };

    _wsChannel!.sink.add(jsonEncode(message));
  }

  /// Request a fact-check on a specific claim
  Future<void> factCheck(String claim) async {
    final query = 'Please fact-check this claim: "$claim". Search for current information and provide sources.';
    await sendQuery(query);
  }

  /// Ask for information on a topic
  Future<void> askAboutTopic(String topic) async {
    final query = 'Provide brief, factual information about: $topic. Include recent data and cite sources.';
    await sendQuery(query);
  }

  /// Start listening to room audio
  void startListening() {
    _isListening = true;
    _logger.info('Gemini Live started listening');
  }

  /// Stop listening to room audio
  void stopListening() {
    _isListening = false;
    _logger.info('Gemini Live stopped listening');
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    _logger.info('Disconnecting Gemini Live');

    _isConnected = false;
    _isListening = false;

    await _wsChannel?.sink.close();
    _wsChannel = null;

    _audioBuffer.clear();
  }

  /// Dispose of resources
  void dispose() {
    disconnect();
    _responseController.close();
  }
}

/// Alternative REST API approach for simpler integration
/// Use this if WebSocket approach has issues
class GeminiRestService {
  static final GeminiRestService _instance = GeminiRestService._internal();
  factory GeminiRestService() => _instance;
  GeminiRestService._internal();

  final _logger = AppLogger();

  static const String _envApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // Fallback API key for testing (remove in production)
  static const String _fallbackKey = 'AIzaSyBFBIyOvh2YRNa5AuvbycOqL-croYQJJAs';

  static String get _apiKey => _envApiKey.isNotEmpty ? _envApiKey : _fallbackKey;

  /// Generate content using official Google Generative AI SDK
  Future<Map<String, dynamic>?> generateWithSearch({
    required String prompt,
    String? debateTopic,
  }) async {
    // Debug: Log API key status
    _logger.info('🔑 Gemini API key length: ${_apiKey.length}');
    _logger.info('🔑 API key first 10 chars: ${_apiKey.substring(0, _apiKey.length > 10 ? 10 : _apiKey.length)}...');
    _logger.info('🔑 API key configured: ${_apiKey.isNotEmpty}');

    if (_apiKey.isEmpty) {
      _logger.error('❌ Gemini API key not configured');
      return null;
    }

    _logger.info('🤖 Calling Gemini API with prompt: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');

    try {
      // Use official SDK with gemini-1.5-flash
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 500,
        ),
      );

      _logger.info('📤 Sending request to Gemini...');

      // Include system context in the prompt itself
      final systemContext = debateTopic != null
          ? 'You are a fact-checker for a debate on "$debateTopic". Be concise and cite sources.\n\n'
          : 'You are a helpful fact-checker. Be concise and cite sources.\n\n';

      final response = await model.generateContent([
        Content.text(systemContext + prompt),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out after 30 seconds');
        },
      );

      _logger.info('📥 Response received from Gemini');

      final text = response.text;

      if (text != null && text.isNotEmpty) {
        _logger.info('✅ Gemini API success!');
        _logger.info('📝 Response text length: ${text.length}');

        return {
          'text': text,
          'sources': <Map<String, dynamic>>[],
        };
      } else {
        _logger.error('❌ Empty response from Gemini');
        _logger.error('❌ Response candidates: ${response.candidates?.length ?? 0}');
        return {
          'error': true,
          'message': 'Empty response from AI',
        };
      }
    } on GenerativeAIException catch (e) {
      _logger.error('❌ Gemini API Exception: ${e.message}');
      return {
        'error': true,
        'message': e.message,
      };
    } catch (e) {
      _logger.error('❌ Error calling Gemini API: $e');
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
}
