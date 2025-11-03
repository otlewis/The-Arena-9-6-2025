import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../core/logging/app_logger.dart';

// Conditional import for Platform - stub for web
import 'dart:io' if (dart.library.html) '../utils/platform_stub.dart';

/// Service for detecting device capabilities and determining optimal audio configuration
class DeviceCapabilitiesService {
  static final DeviceCapabilitiesService _instance = DeviceCapabilitiesService._internal();
  factory DeviceCapabilitiesService() => _instance;
  DeviceCapabilitiesService._internal();

  final _logger = AppLogger();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Device capability thresholds
  static const int lowRamThresholdMb = 2048; // 2GB
  static const int veryLowRamThresholdMb = 1024; // 1GB
  static const int lowCpuCoreThreshold = 2;
  static const int minAndroidApiForOpus = 21; // Android 5.0
  static const int minIosVersionForOpus = 11;
  
  // Cached device info
  DeviceProfile? _cachedProfile;
  
  /// Get comprehensive device profile
  Future<DeviceProfile> getDeviceProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;
    
    try {
      if (kIsWeb) {
        _cachedProfile = DeviceProfile.webDefault();
      } else if (Platform.isAndroid) {
        _cachedProfile = await _getAndroidProfile();
      } else if (Platform.isIOS) {
        _cachedProfile = await _getIOSProfile();
      } else {
        _cachedProfile = DeviceProfile.unknown();
      }
      
      _logger.info('📱 Device Profile: ${_cachedProfile!.toJson()}');
      return _cachedProfile!;
    } catch (e) {
      _logger.error('Failed to get device profile: $e');
      return DeviceProfile.unknown();
    }
  }
  
  /// Get Android device profile
  Future<DeviceProfile> _getAndroidProfile() async {
    final androidInfo = await _deviceInfo.androidInfo;
    
    // Estimate RAM from physical memory (not always accurate)
    final totalRamMB = _estimateAndroidRAM(androidInfo);
    
    // Get CPU cores (approximate)
    final cpuCores = _getCPUCores();
    
    // Determine device tier
    final tier = _determineDeviceTier(totalRamMB, cpuCores, androidInfo.version.sdkInt);
    
    return DeviceProfile(
      platform: 'android',
      osVersion: androidInfo.version.release,
      apiLevel: androidInfo.version.sdkInt,
      manufacturer: androidInfo.manufacturer,
      model: androidInfo.model,
      totalRamMB: totalRamMB,
      cpuCores: cpuCores,
      deviceTier: tier,
      supportedCodecs: _getAndroidSupportedCodecs(androidInfo.version.sdkInt),
      isLowEndDevice: tier == DeviceTier.low || tier == DeviceTier.veryLow,
      requiresOptimization: tier != DeviceTier.high,
    );
  }
  
  /// Get iOS device profile
  Future<DeviceProfile> _getIOSProfile() async {
    final iosInfo = await _deviceInfo.iosInfo;
    
    // Parse iOS version
    final osVersion = iosInfo.systemVersion;
    final majorVersion = int.tryParse(osVersion.split('.').first) ?? 11;
    
    // Estimate device tier based on model
    final tier = _determineIOSDeviceTier(iosInfo.utsname.machine);
    
    // Estimate specs based on device model
    final deviceSpecs = _getIOSDeviceSpecs(iosInfo.utsname.machine);
    
    return DeviceProfile(
      platform: 'ios',
      osVersion: osVersion,
      apiLevel: majorVersion,
      manufacturer: 'Apple',
      model: iosInfo.model,
      deviceIdentifier: iosInfo.utsname.machine,
      totalRamMB: deviceSpecs.ramMB,
      cpuCores: deviceSpecs.cpuCores,
      deviceTier: tier,
      supportedCodecs: _getIOSSupportedCodecs(majorVersion),
      isLowEndDevice: tier == DeviceTier.low || tier == DeviceTier.veryLow,
      requiresOptimization: tier != DeviceTier.high,
    );
  }
  
  /// Estimate Android RAM (fallback method)
  int _estimateAndroidRAM(AndroidDeviceInfo info) {
    // Skip Process calls on web
    if (!kIsWeb) {
      // Try to get actual memory info
      try {
        final memInfo = Process.runSync('cat', ['/proc/meminfo']);
        if (memInfo.exitCode == 0) {
          final output = memInfo.stdout.toString();
          final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(output);
          if (match != null) {
            final kb = int.parse(match.group(1)!);
            return kb ~/ 1024; // Convert to MB
          }
        }
      } catch (e) {
        _logger.debug('Could not read memory info: $e');
      }
    }
    
    // Fallback: estimate based on Android version and device age
    final sdkInt = info.version.sdkInt;
    if (sdkInt <= 23) return 1024; // Android 6.0 and below: assume 1GB
    if (sdkInt <= 26) return 2048; // Android 7-8: assume 2GB  
    if (sdkInt <= 28) return 3072; // Android 9: assume 3GB
    return 4096; // Android 10+: assume 4GB
  }
  
  /// Get CPU core count
  int _getCPUCores() {
    if (kIsWeb) {
      // Web: Use navigator.hardwareConcurrency if available
      return 4; // Default for web
    }

    try {
      if (Platform.numberOfProcessors > 0) {
        return Platform.numberOfProcessors;
      }
    } catch (e) {
      _logger.debug('Could not get CPU cores: $e');
    }
    return 4; // Default fallback
  }
  
  /// Determine device tier based on specs
  DeviceTier _determineDeviceTier(int ramMB, int cpuCores, int apiLevel) {
    // Very low-end device
    if (ramMB <= veryLowRamThresholdMb || cpuCores <= 2 || apiLevel < 21) {
      return DeviceTier.veryLow;
    }
    
    // Low-end device
    if (ramMB <= lowRamThresholdMb || cpuCores <= lowCpuCoreThreshold || apiLevel < 24) {
      return DeviceTier.low;
    }
    
    // Medium device
    if (ramMB <= 3072 || cpuCores <= 4 || apiLevel < 28) {
      return DeviceTier.medium;
    }
    
    // High-end device
    return DeviceTier.high;
  }
  
  /// Determine iOS device tier based on model
  DeviceTier _determineIOSDeviceTier(String machine) {
    // iPhone 6/6S/SE (1st gen) and older
    if (machine.contains('iPhone7') || machine.contains('iPhone8,1') || 
        machine.contains('iPhone8,4')) {
      return DeviceTier.veryLow;
    }
    
    // iPhone 7/8
    if (machine.contains('iPhone9') || machine.contains('iPhone10,1') || 
        machine.contains('iPhone10,4')) {
      return DeviceTier.low;
    }
    
    // iPhone X/XR/11
    if (machine.contains('iPhone10') || machine.contains('iPhone11')) {
      return DeviceTier.medium;
    }
    
    // iPhone 12 and newer
    return DeviceTier.high;
  }
  
  /// Get iOS device specs based on model
  ({int ramMB, int cpuCores}) _getIOSDeviceSpecs(String machine) {
    // iPhone 6/6S
    if (machine.contains('iPhone7') || machine.contains('iPhone8,1')) {
      return (ramMB: 1024, cpuCores: 2);
    }
    
    // iPhone 7/8
    if (machine.contains('iPhone9') || machine.contains('iPhone10,1')) {
      return (ramMB: 2048, cpuCores: 2);
    }
    
    // iPhone X/XR
    if (machine.contains('iPhone10') || machine.contains('iPhone11')) {
      return (ramMB: 3072, cpuCores: 6);
    }
    
    // iPhone 12 and newer
    return (ramMB: 4096, cpuCores: 6);
  }
  
  /// Get supported codecs for Android
  List<AudioCodecSupport> _getAndroidSupportedCodecs(int apiLevel) {
    final codecs = <AudioCodecSupport>[];
    
    // Opus (Android 5.0+)
    if (apiLevel >= 21) {
      codecs.add(AudioCodecSupport.opus);
    }
    
    // AMR-NB and AMR-WB (all Android versions)
    codecs.add(AudioCodecSupport.amrNB);
    if (apiLevel >= 16) {
      codecs.add(AudioCodecSupport.amrWB);
    }
    
    // G.711 (all Android versions)
    codecs.add(AudioCodecSupport.g711);
    
    return codecs;
  }
  
  /// Get supported codecs for iOS
  List<AudioCodecSupport> _getIOSSupportedCodecs(int majorVersion) {
    final codecs = <AudioCodecSupport>[];
    
    // Opus (iOS 11+)
    if (majorVersion >= 11) {
      codecs.add(AudioCodecSupport.opus);
    }
    
    // AAC (all iOS versions)
    codecs.add(AudioCodecSupport.aac);
    
    // G.711 (all iOS versions)
    codecs.add(AudioCodecSupport.g711);
    
    return codecs;
  }
  
  /// Get optimal audio configuration for device
  AudioConfiguration getOptimalAudioConfig(DeviceProfile profile, NetworkType networkType) {
    // Determine base configuration from device tier
    AudioConfiguration config;
    
    switch (profile.deviceTier) {
      case DeviceTier.veryLow:
        config = AudioConfiguration.veryLowEnd();
        break;
      case DeviceTier.low:
        config = AudioConfiguration.lowEnd();
        break;
      case DeviceTier.medium:
        config = AudioConfiguration.medium();
        break;
      case DeviceTier.high:
        config = AudioConfiguration.highEnd();
        break;
    }
    
    // Adjust for network conditions with ultra-low bitrates for 2G/3G
    switch (networkType) {
      case NetworkType.cellular2G:
        // Ultra-low bitrate for 2G networks (EDGE/GPRS) - 16kbps limit (boosted from 8kbps)
        config = AudioConfiguration(
          bitrate: 16000, // Increased from 8000 for better quality
          sampleRate: 16000, // Increased from 8000 for better quality
          channels: 1,
          dtx: true,
          red: true,
          noiseSuppression: false,
          echoCancellation: true, // Enabled for better quality
          autoGainControl: true, // Enabled to normalize audio levels and boost quality
          preferredCodec: 'opus', // Opus is better than g711 even on 2G
          jitterBufferSize: 300,
          audioFrameDuration: 60,
        );
        break;
      case NetworkType.cellular3G:
        // Moderate bitrate for 3G networks - 32kbps limit (boosted from 16kbps)
        config = AudioConfiguration(
          bitrate: 32000, // Increased from 16000 for better quality
          sampleRate: 24000, // Increased from 16000 for better quality
          channels: 1,
          dtx: true,
          red: false, // Disabled for better quality
          noiseSuppression: true, // Enabled for better clarity
          echoCancellation: true,
          autoGainControl: true, // Enabled to normalize audio levels and boost quality
          preferredCodec: 'opus', // Always use Opus for best quality
          jitterBufferSize: 200,
          audioFrameDuration: 40,
        );
        break;
      case NetworkType.cellular4G:
        // Standard cellular optimization for 4G LTE
        if (profile.deviceTier == DeviceTier.veryLow) {
          config = config.copyWith(bitrate: 32000);
        }
        break;
      case NetworkType.cellular5G:
        // High-quality config for 5G networks
        if (profile.deviceTier != DeviceTier.veryLow) {
          config = config.copyWith(
            bitrate: config.bitrate > 64000 ? config.bitrate : 64000,
            sampleRate: config.sampleRate > 24000 ? config.sampleRate : 24000,
          );
        }
        break;
      case NetworkType.wifi:
      case NetworkType.ethernet:
        // Keep optimal config for wired/WiFi
        break;
      case NetworkType.unknown:
        // Conservative approach for unknown connections
        if (profile.deviceTier == DeviceTier.veryLow) {
          config = config.copyWith(bitrate: 24000);
        }
        break;
    }
    
    // Select best available codec
    if (profile.supportedCodecs.contains(AudioCodecSupport.opus)) {
      config = config.copyWith(preferredCodec: 'opus');
    } else if (profile.supportedCodecs.contains(AudioCodecSupport.amrWB)) {
      config = config.copyWith(preferredCodec: 'amr-wb');
    } else {
      config = config.copyWith(preferredCodec: 'g711');
    }
    
    _logger.info('🎵 Audio Config: ${config.toJson()}');
    return config;
  }
}

/// Device profile information
class DeviceProfile {
  final String platform;
  final String osVersion;
  final int apiLevel;
  final String manufacturer;
  final String model;
  final String? deviceIdentifier;
  final int totalRamMB;
  final int cpuCores;
  final DeviceTier deviceTier;
  final List<AudioCodecSupport> supportedCodecs;
  final bool isLowEndDevice;
  final bool requiresOptimization;
  
  DeviceProfile({
    required this.platform,
    required this.osVersion,
    required this.apiLevel,
    required this.manufacturer,
    required this.model,
    this.deviceIdentifier,
    required this.totalRamMB,
    required this.cpuCores,
    required this.deviceTier,
    required this.supportedCodecs,
    required this.isLowEndDevice,
    required this.requiresOptimization,
  });
  
  factory DeviceProfile.webDefault() => DeviceProfile(
    platform: 'web',
    osVersion: 'unknown',
    apiLevel: 0,
    manufacturer: 'unknown',
    model: 'web',
    totalRamMB: 4096,
    cpuCores: 4,
    deviceTier: DeviceTier.high,
    supportedCodecs: [AudioCodecSupport.opus],
    isLowEndDevice: false,
    requiresOptimization: false,
  );
  
  factory DeviceProfile.unknown() => DeviceProfile(
    platform: 'unknown',
    osVersion: 'unknown',
    apiLevel: 0,
    manufacturer: 'unknown',
    model: 'unknown',
    totalRamMB: 2048,
    cpuCores: 2,
    deviceTier: DeviceTier.medium,
    supportedCodecs: [AudioCodecSupport.g711],
    isLowEndDevice: false,
    requiresOptimization: true,
  );
  
  Map<String, dynamic> toJson() => {
    'platform': platform,
    'osVersion': osVersion,
    'apiLevel': apiLevel,
    'manufacturer': manufacturer,
    'model': model,
    'deviceIdentifier': deviceIdentifier,
    'totalRamMB': totalRamMB,
    'cpuCores': cpuCores,
    'deviceTier': deviceTier.name,
    'supportedCodecs': supportedCodecs.map((c) => c.name).toList(),
    'isLowEndDevice': isLowEndDevice,
    'requiresOptimization': requiresOptimization,
  };
}

/// Device performance tier
enum DeviceTier {
  veryLow,  // < 1GB RAM, 2 cores, old OS
  low,      // 1-2GB RAM, 2-4 cores
  medium,   // 2-3GB RAM, 4-6 cores
  high,     // 4GB+ RAM, 6+ cores
}

/// Supported audio codecs
enum AudioCodecSupport {
  opus,
  amrNB,
  amrWB,
  g711,
  aac,
}

/// Network type classification
enum NetworkType {
  cellular2G,
  cellular3G,
  cellular4G,
  cellular5G,
  wifi,
  ethernet,
  unknown,
}

/// Audio configuration settings
class AudioConfiguration {
  final int bitrate;
  final int sampleRate;
  final int channels;
  final bool dtx;
  final bool red;
  final bool noiseSuppression;
  final bool echoCancellation;
  final bool autoGainControl;
  final String preferredCodec;
  final int jitterBufferSize;
  final int audioFrameDuration;
  
  AudioConfiguration({
    required this.bitrate,
    required this.sampleRate,
    this.channels = 1,
    this.dtx = false,
    this.red = false,
    this.noiseSuppression = true,
    this.echoCancellation = true,
    this.autoGainControl = true, // Enabled to normalize audio levels and boost Android quality
    this.preferredCodec = 'opus',
    this.jitterBufferSize = 50,
    this.audioFrameDuration = 20,
  });
  
  factory AudioConfiguration.veryLowEnd() => AudioConfiguration(
    bitrate: 16000, // Increased from 8000 for better quality
    sampleRate: 16000, // Increased from 8000 for better quality
    channels: 1,
    dtx: true,
    red: true,
    noiseSuppression: false,
    echoCancellation: false,
    autoGainControl: true, // Enabled to normalize audio levels and boost quality
    jitterBufferSize: 200,
    audioFrameDuration: 40,
  );

  factory AudioConfiguration.lowEnd() => AudioConfiguration(
    bitrate: 32000, // Increased from 16000 for better quality
    sampleRate: 24000, // Increased from 16000 for better quality
    channels: 1,
    dtx: true,
    red: false, // Disabled for better quality (less packet loss protection needed)
    noiseSuppression: true, // Re-enabled for better clarity
    echoCancellation: true,
    autoGainControl: true, // Enabled to normalize audio levels and boost quality
    jitterBufferSize: 100,
    audioFrameDuration: 20,
  );

  factory AudioConfiguration.medium() => AudioConfiguration(
    bitrate: 48000, // Increased from 32000 for better quality
    sampleRate: 32000, // Increased from 24000 for better quality
    channels: 1,
    dtx: false, // Disabled for better quality (continuous transmission)
    red: false,
    noiseSuppression: true,
    echoCancellation: true,
    autoGainControl: true, // Enabled to normalize audio levels and boost quality
    jitterBufferSize: 50,
    audioFrameDuration: 20,
  );

  factory AudioConfiguration.highEnd() => AudioConfiguration(
    bitrate: 96000, // Increased from 64000 for crystal clear quality
    sampleRate: 48000,
    channels: 2, // Stereo for high-end devices
    dtx: false,
    red: false,
    noiseSuppression: true,
    echoCancellation: true,
    autoGainControl: true, // Enabled to normalize audio levels and boost quality
    jitterBufferSize: 20,
    audioFrameDuration: 10,
  );
  
  AudioConfiguration copyWith({
    int? bitrate,
    int? sampleRate,
    int? channels,
    bool? dtx,
    bool? red,
    bool? noiseSuppression,
    bool? echoCancellation,
    bool? autoGainControl,
    String? preferredCodec,
    int? jitterBufferSize,
    int? audioFrameDuration,
  }) {
    return AudioConfiguration(
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      dtx: dtx ?? this.dtx,
      red: red ?? this.red,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      echoCancellation: echoCancellation ?? this.echoCancellation,
      autoGainControl: autoGainControl ?? this.autoGainControl,
      preferredCodec: preferredCodec ?? this.preferredCodec,
      jitterBufferSize: jitterBufferSize ?? this.jitterBufferSize,
      audioFrameDuration: audioFrameDuration ?? this.audioFrameDuration,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'bitrate': bitrate,
    'sampleRate': sampleRate,
    'channels': channels,
    'dtx': dtx,
    'red': red,
    'noiseSuppression': noiseSuppression,
    'echoCancellation': echoCancellation,
    'autoGainControl': autoGainControl,
    'preferredCodec': preferredCodec,
    'jitterBufferSize': jitterBufferSize,
    'audioFrameDuration': audioFrameDuration,
  };
}