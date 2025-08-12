import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A custom Socket.IO client that ONLY uses HTTP polling
/// This bypasses the flutter socket_io_client WebSocket upgrade bug
class PollingOnlySocketIO {
  final String serverUrl;
  String? sessionId;
  String? socketId;
  Timer? _pollingTimer;
  bool _isConnected = false;
  
  // Event handlers
  final Map<String, List<Function>> _eventHandlers = {};
  final Map<String, Completer> _ackHandlers = {};
  
  // Connection state
  Function()? onConnect;
  Function(dynamic)? onConnectError;
  Function()? onDisconnect;
  
  PollingOnlySocketIO(this.serverUrl);
  
  bool get connected => _isConnected;
  String? get id => socketId;
  
  /// Connect to Socket.IO server using polling only
  Future<void> connect() async {
    try {
      debugPrint('🔌 PollingOnlySocketIO: Connecting to $serverUrl');
      
      // 1. Initial handshake
      final handshakeUrl = '$serverUrl/socket.io/?EIO=4&transport=polling';
      final response = await http.get(Uri.parse(handshakeUrl));
      
      if (response.statusCode == 200) {
        // Parse handshake response
        String body = response.body;
        if (body.startsWith('0')) {
          body = body.substring(1); // Remove the '0' prefix
          final handshake = jsonDecode(body);
          sessionId = handshake['sid'];
          socketId = sessionId; // Socket ID is the session ID
          
          debugPrint('✅ PollingOnlySocketIO: Connected! Session ID: $sessionId');
          _isConnected = true;
          
          // Start polling for messages
          _startPolling();
          
          // CRITICAL: Send Socket.IO connection message to upgrade from Engine.IO
          await _sendRaw('40'); // Connect to default namespace
          debugPrint('🔗 PollingOnlySocketIO: Sent Socket.IO connection message (40)');
          
          // Wait a moment for server to process the connection
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Trigger connect event
          onConnect?.call();
          _emit('connect', null);
          
        } else {
          throw Exception('Invalid handshake response');
        }
      } else {
        throw Exception('Handshake failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ PollingOnlySocketIO: Connection error: $e');
      onConnectError?.call(e);
      _emit('connect_error', e);
      rethrow;
    }
  }
  
  /// Start polling for messages
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!_isConnected || sessionId == null) return;
      
      try {
        final pollUrl = '$serverUrl/socket.io/?EIO=4&transport=polling&sid=$sessionId';
        final response = await http.get(Uri.parse(pollUrl));
        
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          _handlePollResponse(response.body);
        }
      } catch (e) {
        debugPrint('❌ PollingOnlySocketIO: Polling error: $e');
      }
    });
  }
  
  /// Handle poll response
  void _handlePollResponse(String data) {
    if (data.isNotEmpty) {
      debugPrint('📨 PollingOnlySocketIO: Raw poll response: $data');
    }
    
    // Socket.IO protocol: messages can be batched
    final messages = _parseMessages(data);
    
    for (final message in messages) {
      debugPrint('📨 PollingOnlySocketIO: Processing message: $message');
      
      if (message.startsWith('42')) {
        // This is a Socket.IO message event
        final payload = message.substring(2);
        try {
          final decoded = jsonDecode(payload);
          if (decoded is List && decoded.length >= 2) {
            final event = decoded[0] as String;
            final data = decoded.length > 2 ? decoded.sublist(1) : decoded[1];
            debugPrint('📥 PollingOnlySocketIO: Received event: $event with data: $data');
            _emit(event, data);
          } else {
            debugPrint('❌ PollingOnlySocketIO: Invalid event format: $decoded');
          }
        } catch (e) {
          debugPrint('❌ PollingOnlySocketIO: Error parsing message: $e');
          debugPrint('❌ PollingOnlySocketIO: Raw payload: $payload');
        }
      } else if (message == '2') {
        // Ping from server, send pong
        debugPrint('💓 PollingOnlySocketIO: Received ping, sending pong');
        _sendRaw('3');
      } else if (message == '3') {
        // Pong response 
        debugPrint('💓 PollingOnlySocketIO: Received pong');
      } else if (message == '1') {
        // Engine.IO close message - but let's debug what's happening
        debugPrint('⚠️ PollingOnlySocketIO: Received message type 1 - ignoring for now');
        // Don't disconnect yet - let's see what happens
      } else if (message == '6') {
        // NOOP (no operation) - just ignore
        debugPrint('⏸️ PollingOnlySocketIO: Received NOOP message');
      } else if (message == '40') {
        // Connect to namespace (successful connection)
        debugPrint('✅ PollingOnlySocketIO: Connected to namespace');
      } else if (message == '41') {
        // Disconnect from namespace
        debugPrint('🔌 PollingOnlySocketIO: Disconnected from namespace');
      } else {
        debugPrint('❓ PollingOnlySocketIO: Unknown message type: $message');
      }
    }
  }
  
  /// Parse batched messages
  List<String> _parseMessages(String data) {
    final messages = <String>[];
    
    // Handle both batched and single message formats
    if (data.contains(':')) {
      // Batched format with length prefixes
      int i = 0;
      while (i < data.length) {
        // Find message length
        int lengthEnd = data.indexOf(':', i);
        if (lengthEnd == -1) break;
        
        try {
          int length = int.parse(data.substring(i, lengthEnd));
          int messageStart = lengthEnd + 1;
          int messageEnd = messageStart + length;
          
          if (messageEnd <= data.length) {
            messages.add(data.substring(messageStart, messageEnd));
            i = messageEnd;
          } else {
            break;
          }
        } catch (e) {
          debugPrint('❌ PollingOnlySocketIO: Error parsing message length: $e');
          break;
        }
      }
    } else {
      // Single message format
      if (data.isNotEmpty) {
        messages.add(data);
      }
    }
    
    return messages;
  }
  
  /// Emit an event to the server
  Future<void> emit(String event, dynamic data) async {
    if (!_isConnected || sessionId == null) {
      throw Exception('Not connected');
    }
    
    // Create Socket.IO message format
    final message = jsonEncode([event, data]);
    debugPrint('📤 PollingOnlySocketIO: Emitting event: $event with data: $data');
    await _sendRaw('42$message');
  }
  
  /// Send raw data to server
  Future<void> _sendRaw(String data) async {
    if (sessionId == null) return;
    
    final sendUrl = '$serverUrl/socket.io/?EIO=4&transport=polling&sid=$sessionId';
    final body = '${data.length}:$data';
    
    try {
      debugPrint('📮 PollingOnlySocketIO: Sending to $sendUrl with body: $body');
      final response = await http.post(
        Uri.parse(sendUrl),
        headers: {'Content-Type': 'text/plain;charset=UTF-8'},
        body: body,
      );
      debugPrint('📬 PollingOnlySocketIO: Send response: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('❌ PollingOnlySocketIO: Send error: $e');
    }
  }
  
  /// Register event handler
  void on(String event, Function handler) {
    _eventHandlers[event] ??= [];
    _eventHandlers[event]!.add(handler);
  }
  
  /// Register one-time event handler
  void once(String event, Function handler) {
    void wrappedHandler(dynamic data) {
      handler(data);
      off(event, wrappedHandler);
    }
    on(event, wrappedHandler);
  }
  
  /// Remove event handler
  void off(String event, Function handler) {
    _eventHandlers[event]?.remove(handler);
  }
  
  /// Emit event to local handlers
  void _emit(String event, dynamic data) {
    final handlers = _eventHandlers[event];
    if (handlers != null) {
      for (final handler in handlers.toList()) {
        try {
          // Always call with data parameter, even if null
          handler(data);
        } catch (e) {
          debugPrint('❌ PollingOnlySocketIO: Handler error: $e');
        }
      }
    }
  }
  
  /// Disconnect from server
  void disconnect() {
    _isConnected = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    sessionId = null;
    socketId = null;
    
    onDisconnect?.call();
    _emit('disconnect', null);
    
    debugPrint('🔌 PollingOnlySocketIO: Disconnected');
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _eventHandlers.clear();
    _ackHandlers.clear();
  }
}