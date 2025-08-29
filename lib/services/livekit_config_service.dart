import '../core/logging/app_logger.dart';

/// Centralized LiveKit Configuration Service for Arena
/// This service provides environment-aware LiveKit server configuration
/// and eliminates hardcoded server URLs throughout the application
class LiveKitConfigService {
  static LiveKitConfigService? _instance;
  static LiveKitConfigService get instance => _instance ??= LiveKitConfigService._();
  
  LiveKitConfigService._();

  // Production LiveKit server configuration (Linode server)
  static const String _productionServerUrl = 'ws://172.236.109.9:7880';
  static const String _productionApiKey = 'LKAPI1234567890';
  static const String _productionSecretKey = '7e9fb42854e466daf92dabbc9b88e98f7811486704338e062d30815a592de45d';

  // Development/fallback configuration (same as production for now)
  static const String _developmentServerUrl = 'ws://172.236.109.9:7880'; 
  static const String _developmentApiKey = 'LKAPI1234567890';
  static const String _developmentSecretKey = '7e9fb42854e466daf92dabbc9b88e98f7811486704338e062d30815a592de45d';

  // Current environment detection
  bool get isProduction => const bool.fromEnvironment('dart.vm.product', defaultValue: false);
  
  /// Get the current LiveKit server URL based on environment (for WebSocket connections)
  String get serverUrl {
    final url = isProduction ? _productionServerUrl : _developmentServerUrl;
    
    // SSL/TLS verification
    if (url.startsWith('wss://')) {
      AppLogger().debug('🔒 Using secure WebSocket (wss://) - iOS ATS compatible');
    } else if (url.startsWith('ws://')) {
      AppLogger().debug('📡 Using WebSocket (ws://) connection to Linode server');
      AppLogger().debug('💡 Note: iOS ATS exception configured for 172.236.109.9');
    }
    
    AppLogger().debug('🔧 LiveKit Server URL: $url (${isProduction ? 'PRODUCTION' : 'DEVELOPMENT'})');
    return url;
  }

  /// Get HTTP API URL for server API calls (converts ws:// to http://)
  String get httpApiUrl {
    final wsUrl = isProduction ? _productionServerUrl : _developmentServerUrl;
    
    // Convert WebSocket URLs to HTTP URLs
    String httpUrl;
    if (wsUrl.startsWith('wss://')) {
      httpUrl = wsUrl.replaceFirst('wss://', 'https://');
    } else if (wsUrl.startsWith('ws://')) {
      httpUrl = wsUrl.replaceFirst('ws://', 'http://');
    } else {
      httpUrl = wsUrl; // Already HTTP/HTTPS
    }
    
    AppLogger().debug('🌐 LiveKit HTTP API URL: $httpUrl (${isProduction ? 'PRODUCTION' : 'DEVELOPMENT'})');
    return httpUrl;
  }

  /// Get the current API key based on environment
  String get apiKey {
    final key = isProduction ? _productionApiKey : _developmentApiKey;
    AppLogger().debug('🔑 LiveKit API Key: ${key.substring(0, 8)}... (${isProduction ? 'PRODUCTION' : 'DEVELOPMENT'})');
    return key;
  }

  /// Get the current secret key based on environment
  String get secretKey {
    final secret = isProduction ? _productionSecretKey : _developmentSecretKey;
    AppLogger().debug('🔐 LiveKit Secret: ${secret.substring(0, 8)}... (${isProduction ? 'PRODUCTION' : 'DEVELOPMENT'})');
    return secret;
  }

  /// Get full LiveKit configuration for the current environment
  LiveKitConfig get currentConfig {
    return LiveKitConfig(
      serverUrl: serverUrl,
      apiKey: apiKey,
      secretKey: secretKey,
    );
  }

  /// Test server connectivity (ping-like functionality)
  Future<bool> testServerConnectivity() async {
    try {
      AppLogger().debug('🔄 Testing LiveKit server connectivity...');
      AppLogger().debug('📡 Server: $serverUrl');
      
      // For now, we'll assume the server is reachable if we have valid config
      // In the future, this could implement actual connectivity testing
      final hasValidConfig = serverUrl.isNotEmpty && 
                           apiKey.isNotEmpty && 
                           secretKey.isNotEmpty;
      
      if (hasValidConfig) {
        AppLogger().debug('✅ LiveKit configuration is valid');
        return true;
      } else {
        AppLogger().debug('❌ LiveKit configuration is incomplete');
        return false;
      }
    } catch (error) {
      AppLogger().debug('❌ LiveKit server connectivity test failed: $error');
      return false;
    }
  }

  /// Log current configuration for debugging
  void logCurrentConfiguration() {
    AppLogger().debug('🔧 === LiveKit Configuration ===');
    AppLogger().debug('🌍 Environment: ${isProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
    AppLogger().debug('📡 Server URL: $serverUrl');
    AppLogger().debug('🔑 API Key: ${apiKey.substring(0, 8)}...');
    AppLogger().debug('🔐 Secret: ${secretKey.substring(0, 8)}...');
    AppLogger().debug('🔧 ================================');
  }

  /// Override server URL for testing (development only)
  String? _overrideServerUrl;
  
  void setServerUrlOverride(String? url) {
    if (!isProduction) {
      _overrideServerUrl = url;
      AppLogger().debug('🔧 Server URL override set: $url');
    } else {
      AppLogger().debug('⚠️ Server URL override ignored in production');
    }
  }

  String get effectiveServerUrl => _overrideServerUrl ?? serverUrl;
}

/// LiveKit Configuration Data Class
class LiveKitConfig {
  final String serverUrl;
  final String apiKey;
  final String secretKey;

  const LiveKitConfig({
    required this.serverUrl,
    required this.apiKey,
    required this.secretKey,
  });

  @override
  String toString() {
    return 'LiveKitConfig(serverUrl: $serverUrl, apiKey: ${apiKey.substring(0, 8)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveKitConfig &&
        other.serverUrl == serverUrl &&
        other.apiKey == apiKey &&
        other.secretKey == secretKey;
  }

  @override
  int get hashCode {
    return serverUrl.hashCode ^ apiKey.hashCode ^ secretKey.hashCode;
  }
}