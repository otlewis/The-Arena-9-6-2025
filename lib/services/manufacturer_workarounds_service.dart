import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import '../core/logging/app_logger.dart';
import 'package:flutter/services.dart';
import 'device_capabilities_service.dart';

/// Service to handle manufacturer-specific audio and battery workarounds
class ManufacturerWorkaroundsService {
  static final ManufacturerWorkaroundsService _instance = ManufacturerWorkaroundsService._internal();
  factory ManufacturerWorkaroundsService() => _instance;
  ManufacturerWorkaroundsService._internal();

  final _logger = AppLogger();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Platform channel for native Android calls
  static const _platform = MethodChannel('com.thearenadtd.app/manufacturer_workarounds');
  
  String? _manufacturer;
  String? _model;
  int? _sdkInt;
  
  /// Known problematic manufacturers requiring special handling
  static const _problematicManufacturers = {
    'samsung': SamsungWorkarounds(),
    'xiaomi': XiaomiWorkarounds(),
    'huawei': HuaweiWorkarounds(),
    'oppo': OppoWorkarounds(),
    'vivo': VivoWorkarounds(),
    'realme': RealmeWorkarounds(),
    'oneplus': OnePlusWorkarounds(),
    'asus': AsusWorkarounds(),
    'nokia': NokiaWorkarounds(),
    'sony': SonyWorkarounds(),
    'tecno': TecnoWorkarounds(),
    'infinix': InfinixWorkarounds(),
    'honor': HonorWorkarounds(),
    'motorola': MotorolaWorkarounds(),
    'lenovo': LenovoWorkarounds(),
  };

  /// Initialize and detect manufacturer
  Future<void> initialize() async {
    // Only run on Android - skip web, iOS, macOS, etc.
    if (kIsWeb) return;
    
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      _manufacturer = androidInfo.manufacturer.toLowerCase();
      _model = androidInfo.model.toLowerCase();
      _sdkInt = androidInfo.version.sdkInt;
      
      _logger.info('📱 Device detected: $_manufacturer $_model (SDK $_sdkInt)');
      
      // Apply initial workarounds
      await applyWorkarounds();
      
      // Apply additional edge case workarounds
      await _applyEdgeCaseWorkarounds();
      
    } catch (e) {
      _logger.error('Failed to initialize manufacturer workarounds: $e');
    }
  }

  /// Apply all necessary workarounds for this device
  Future<void> applyWorkarounds() async {
    if (_manufacturer == null) return;
    
    final workaround = _problematicManufacturers[_manufacturer];
    if (workaround != null) {
      _logger.info('🔧 Applying $_manufacturer specific workarounds');
      await workaround.apply(this);
    }
    
    // Apply general Android workarounds
    await _applyGeneralAndroidWorkarounds();
  }

  /// General Android workarounds for all devices
  Future<void> _applyGeneralAndroidWorkarounds() async {
    try {
      // Disable battery optimizations
      await requestBatteryOptimizationExemption();
      
      // Request auto-start permission if available
      await requestAutoStartPermission();
      
      // Disable data saver for our app
      await requestDataSaverExemption();
      
    } catch (e) {
      _logger.debug('Error applying general workarounds: $e');
    }
  }

  /// Request battery optimization exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final result = await _platform.invokeMethod('requestBatteryOptimizationExemption');
      _logger.info('🔋 Battery optimization exemption: ${result ? "granted" : "denied"}');
      return result == true;
    } catch (e) {
      _logger.debug('Battery optimization exemption not available: $e');
      return false;
    }
  }

  /// Request auto-start permission (for Chinese OEMs)
  Future<bool> requestAutoStartPermission() async {
    try {
      // Only for specific manufacturers
      if (!['xiaomi', 'oppo', 'vivo', 'huawei', 'realme', 'oneplus'].contains(_manufacturer)) {
        return true;
      }
      
      final result = await _platform.invokeMethod('requestAutoStartPermission', {
        'manufacturer': _manufacturer,
      });
      _logger.info('🚀 Auto-start permission: ${result ? "granted" : "denied"}');
      return result == true;
    } catch (e) {
      _logger.debug('Auto-start permission not available: $e');
      return false;
    }
  }

  /// Request data saver exemption
  Future<bool> requestDataSaverExemption() async {
    try {
      if (_sdkInt != null && _sdkInt! >= 24) {
        final result = await _platform.invokeMethod('requestDataSaverExemption');
        _logger.info('📊 Data saver exemption: ${result ? "granted" : "denied"}');
        return result == true;
      }
      return true;
    } catch (e) {
      _logger.debug('Data saver exemption not available: $e');
      return false;
    }
  }

  /// Disable manufacturer audio effects
  Future<void> disableManufacturerAudioEffects() async {
    try {
      await _platform.invokeMethod('disableAudioEffects', {
        'manufacturer': _manufacturer,
      });
      _logger.info('🔇 Manufacturer audio effects disabled');
    } catch (e) {
      _logger.debug('Could not disable audio effects: $e');
    }
  }

  /// Get recommended audio configuration for this manufacturer
  Map<String, dynamic> getManufacturerAudioConfig() {
    final workaround = _problematicManufacturers[_manufacturer ?? ''];
    return workaround?.getAudioConfig() ?? {};
  }

  /// Check if device needs aggressive battery optimization
  bool needsAggressiveBatteryOptimization() {
    return ['xiaomi', 'huawei', 'oppo', 'vivo', 'realme'].contains(_manufacturer);
  }

  /// Get battery optimization instructions for user
  String getBatteryOptimizationInstructions() {
    final workaround = _problematicManufacturers[_manufacturer ?? ''];
    return workaround?.getBatteryInstructions() ?? _getGenericBatteryInstructions();
  }

  String _getGenericBatteryInstructions() {
    return '''
To ensure uninterrupted audio during calls:

1. Go to Settings > Apps > Arena
2. Tap "Battery" or "Power Management"
3. Select "Don't optimize" or "Unrestricted"
4. Enable "Allow background activity"
''';
  }

  /// Show battery optimization instructions to user
  Future<void> showBatteryOptimizationInstructions() async {
    final instructions = getBatteryOptimizationInstructions();
    _logger.info('🔋 Battery optimization instructions: $instructions');
    // TODO: Show actual dialog to user with manufacturer-specific instructions
  }

  /// Apply advanced optimizations for audio configurations
  Future<AudioConfiguration> applyAudioOptimizations(AudioConfiguration config) async {
    final manufacturerConfig = getManufacturerAudioConfig();
    
    // Apply manufacturer-specific audio settings
    if (manufacturerConfig.isNotEmpty) {
      _logger.info('🎵 Applying $_manufacturer audio optimizations: $manufacturerConfig');
      
      // Create optimized config based on manufacturer requirements
      return AudioConfiguration(
        bitrate: config.bitrate,
        sampleRate: config.sampleRate,
        channels: config.channels,
        dtx: manufacturerConfig['dtx'] ?? config.dtx,
        red: manufacturerConfig['red'] ?? config.red,
        noiseSuppression: manufacturerConfig['disableEffects'] == true ? false : config.noiseSuppression,
        echoCancellation: manufacturerConfig['disableEffects'] == true ? false : config.echoCancellation,
        autoGainControl: config.autoGainControl,
        preferredCodec: config.preferredCodec,
        jitterBufferSize: manufacturerConfig['useSimpleBuffering'] == true ? 200 : config.jitterBufferSize,
        audioFrameDuration: config.audioFrameDuration,
      );
    }
    
    return config;
  }

  /// Apply edge case workarounds for unknown or problematic devices
  Future<void> _applyEdgeCaseWorkarounds() async {
    // Check for very old Android versions that need special handling
    if (_sdkInt != null && _sdkInt! < 21) {
      _logger.warning('📱 Very old Android version detected (API $_sdkInt) - applying legacy workarounds');
      await _applyLegacyAndroidWorkarounds();
    }
    
    // Check for specific problematic models that might not be caught by manufacturer
    if (_model != null) {
      await _applyModelSpecificWorkarounds(_model!);
    }
    
    // Check for devices with known severe memory constraints
    if (_isLowMemoryDevice()) {
      _logger.warning('📱 Low memory device detected - applying memory conservation measures');
      await _applyMemoryConstrainedWorkarounds();
    }
  }

  /// Apply workarounds for very old Android versions
  Future<void> _applyLegacyAndroidWorkarounds() async {
    try {
      await _platform.invokeMethod('legacy_disableAudioEffects');
      await _platform.invokeMethod('legacy_useBasicAudioSession');
      _logger.info('📱 Legacy Android workarounds applied');
    } catch (e) {
      _logger.debug('Legacy workarounds error: $e');
    }
  }

  /// Apply model-specific workarounds for devices with known issues
  Future<void> _applyModelSpecificWorkarounds(String model) async {
    final problematicModels = [
      'redmi note 4',
      'redmi 5a',
      'galaxy j2',
      'galaxy j3',
      'moto e4',
      'moto g4',
    ];
    
    if (problematicModels.any((m) => model.toLowerCase().contains(m))) {
      _logger.warning('📱 Known problematic model detected: $model');
      try {
        await _platform.invokeMethod('problematic_useMinimalAudio');
        await _platform.invokeMethod('problematic_disableAdvancedFeatures');
      } catch (e) {
        _logger.debug('Model-specific workarounds error: $e');
      }
    }
  }

  /// Apply workarounds for devices with severe memory constraints
  Future<void> _applyMemoryConstrainedWorkarounds() async {
    try {
      await _platform.invokeMethod('memory_useMinimalBuffers');
      await _platform.invokeMethod('memory_disableAudioProcessing');
      _logger.info('📱 Memory-constrained workarounds applied');
    } catch (e) {
      _logger.debug('Memory workarounds error: $e');
    }
  }

  /// Check if device has severe memory constraints
  bool _isLowMemoryDevice() {
    // Check for signs of low memory devices
    return _sdkInt != null && _sdkInt! < 23 && // Android 6.0 or below
           (_model?.contains('go') == true || // Android Go devices
            _model?.contains('lite') == true || // Lite variants
            _model?.contains('mini') == true); // Mini variants
  }
}

/// Base class for manufacturer-specific workarounds
abstract class ManufacturerWorkaround {
  const ManufacturerWorkaround();
  
  Future<void> apply(ManufacturerWorkaroundsService service);
  Map<String, dynamic> getAudioConfig();
  String getBatteryInstructions();
}

/// Samsung-specific workarounds
class SamsungWorkarounds extends ManufacturerWorkaround {
  const SamsungWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    // Disable Samsung SoundAlive and other audio enhancements
    await service.disableManufacturerAudioEffects();
    
    // Request special Samsung permissions
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('samsung_disableSoundAlive');
      await ManufacturerWorkaroundsService._platform.invokeMethod('samsung_disableAdaptSound');
      service._logger.info('🎵 Samsung audio enhancements disabled');
    } catch (e) {
      service._logger.debug('Samsung workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableEffects': false, // Keep echo cancellation enabled for Samsung devices
    'useSimpleAudioTrack': true,
    'avoidAudioFocus': false,
    'preferredBufferSize': 256,
  };
  
  @override
  String getBatteryInstructions() => '''
Samsung Battery Optimization:

1. Settings > Device Care > Battery
2. Tap "App Power Management"
3. Turn OFF "Put unused apps to sleep"
4. Turn OFF "Auto disable unused apps"
5. Add Arena to "Apps that won't be put to sleep"

For One UI 3.0+:
1. Settings > Apps > Arena
2. Battery > "Unrestricted"
3. Turn ON "Allow background activity"
''';
}

/// Xiaomi-specific workarounds
class XiaomiWorkarounds extends ManufacturerWorkaround {
  const XiaomiWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    // MIUI specific optimizations
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('xiaomi_requestAutoStart');
      await ManufacturerWorkaroundsService._platform.invokeMethod('xiaomi_disableMiSound');
      await ManufacturerWorkaroundsService._platform.invokeMethod('xiaomi_lockInRecents');
      service._logger.info('📱 Xiaomi MIUI optimizations applied');
    } catch (e) {
      service._logger.debug('Xiaomi workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableEffects': false, // Keep echo cancellation enabled for Xiaomi devices
    'forceStereoToMono': true,
    'useAudioAttributesBuilder': true,
    'avoidHighSampleRates': true,
    'maxSampleRate': 16000,
  };
  
  @override
  String getBatteryInstructions() => '''
Xiaomi MIUI Optimization:

1. Settings > Apps > Manage Apps > Arena
2. Turn ON "Autostart"
3. Battery Saver > "No restrictions"
4. Other permissions > "Display pop-up windows while running in background"

Lock app in recents:
1. Open recent apps
2. Long press Arena
3. Tap lock icon

Security app settings:
1. Security > Permissions > Autostart > Arena ON
2. Security > Battery > App battery saver > Arena > No restrictions
3. Security > Boost speed > Lock apps > Arena ON
''';
}

/// Huawei-specific workarounds  
class HuaweiWorkarounds extends ManufacturerWorkaround {
  const HuaweiWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('huawei_requestProtectedApps');
      await ManufacturerWorkaroundsService._platform.invokeMethod('huawei_disableHisten');
      service._logger.info('📱 Huawei EMUI optimizations applied');
    } catch (e) {
      service._logger.debug('Huawei workarounds error: $e');
    }
  }

  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableEffects': false, // Keep echo cancellation enabled for Huawei devices
    'useCompatibilityMode': true,
    'forceLowLatency': false,
    'preferredLatency': 100,
  };
  
  @override
  String getBatteryInstructions() => '''
Huawei EMUI Optimization:

1. Settings > Apps > Arena
2. Battery > "Don't allow system to manage automatically"
3. App launch > Manual management (all 3 switches ON)

Protected apps:
1. Settings > Battery > Protected apps
2. Enable Arena

Power-intensive prompt:
1. Settings > Battery > More battery settings
2. Turn OFF "Power-intensive prompt"
''';
}

/// Oppo-specific workarounds
class OppoWorkarounds extends ManufacturerWorkaround {
  const OppoWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('oppo_requestAutoStart');
      await ManufacturerWorkaroundsService._platform.invokeMethod('oppo_requestFloatingWindow');
      service._logger.info('📱 Oppo ColorOS optimizations applied');
    } catch (e) {
      service._logger.debug('Oppo workarounds error: $e');
    }
  }

  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableEffects': false, // Keep echo cancellation enabled for Oppo devices
    'useSimpleBuffering': true,
    'avoidAudioFocusChanges': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Oppo ColorOS Optimization:

1. Settings > Battery > Energy Saver
2. Turn OFF energy saver for Arena
3. Settings > App Management > App List > Arena
4. Allow auto startup
5. Allow background running

Lock in recents:
1. Open recent apps
2. Pull down Arena card
3. Tap lock icon
''';
}

/// Vivo-specific workarounds
class VivoWorkarounds extends ManufacturerWorkaround {
  const VivoWorkarounds();

  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('vivo_requestWhiteList');
      service._logger.info('📱 Vivo FuntouchOS optimizations applied');
    } catch (e) {
      service._logger.debug('Vivo workarounds error: $e');
    }
  }

  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableEffects': false, // Keep echo cancellation enabled for Vivo devices
    'useBasicAudioTrack': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Vivo FuntouchOS Optimization:

1. Settings > Battery > Background power consumption
2. Enable Arena
3. Settings > Apps & permissions > Autostart manager
4. Enable Arena

i Manager app:
1. App Manager > Permissions > Autostart
2. Enable Arena
3. App Manager > White List
4. Add Arena
''';
}

/// Realme-specific workarounds
class RealmeWorkarounds extends ManufacturerWorkaround {
  const RealmeWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    // Similar to Oppo (same parent company)
    await OppoWorkarounds().apply(service);
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => OppoWorkarounds().getAudioConfig();
  
  @override
  String getBatteryInstructions() => '''
Realme UI Optimization:

1. Settings > App Management > App List > Arena
2. Turn ON "Allow auto startup"
3. Turn ON "Allow background running"
4. Settings > Battery > App Battery Management
5. Turn OFF battery optimization for Arena
''';
}

/// OnePlus-specific workarounds
class OnePlusWorkarounds extends ManufacturerWorkaround {
  const OnePlusWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('oneplus_disableOptimization');
      service._logger.info('📱 OnePlus OxygenOS optimizations applied');
    } catch (e) {
      service._logger.debug('OnePlus workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'preferLowLatency': true,
    'usePerformanceMode': true,
  };
  
  @override
  String getBatteryInstructions() => '''
OnePlus OxygenOS Optimization:

1. Settings > Battery > Battery Optimization
2. Select Arena > "Don't optimize"
3. Settings > Apps > Arena > Battery
4. Background restriction > "Allow background activity"

For newer versions:
1. Settings > Apps & notifications > Arena
2. Advanced > Battery optimization > Don't optimize
3. Lock app in recents menu
''';
}

/// Asus-specific workarounds
class AsusWorkarounds extends ManufacturerWorkaround {
  const AsusWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('asus_requestAutoStart');
      service._logger.info('📱 Asus ZenUI optimizations applied');
    } catch (e) {
      service._logger.debug('Asus workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'useStandardConfig': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Asus ZenUI Optimization:

1. Settings > Power management > Auto-start manager
2. Enable Arena
3. Settings > Mobile Manager > PowerMaster
4. Settings > Battery optimization > Turn OFF for Arena
''';
}

/// Nokia-specific workarounds
class NokiaWorkarounds extends ManufacturerWorkaround {
  const NokiaWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    // Nokia uses aggressive Evenwell power management
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('nokia_disableEvenwell');
      service._logger.info('📱 Nokia Android optimizations applied');
    } catch (e) {
      service._logger.debug('Nokia workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'useConservativeSettings': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Nokia Android Optimization:

1. Settings > Apps > See all apps > Arena
2. Advanced > Battery > Background restriction > Remove
3. Battery optimization > All apps > Arena > Don't optimize

Disable DuraSpeed:
1. Open phone dialer
2. Dial *#*#3988638#*#*
3. Disable DuraSpeed if present
''';
}

/// Sony-specific workarounds
class SonyWorkarounds extends ManufacturerWorkaround {
  const SonyWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('sony_disableStamina');
      service._logger.info('📱 Sony Xperia optimizations applied');
    } catch (e) {
      service._logger.debug('Sony workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'useSonyAudioOptimizations': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Sony Xperia Optimization:

1. Settings > Battery > Menu > Battery optimization
2. Apps > Arena > Don't optimize

STAMINA mode:
1. Settings > Battery > STAMINA mode
2. Apps active in standby > Add > Arena

Ultra STAMINA:
Note: Arena won't work in Ultra STAMINA mode
''';
}

/// Tecno-specific workarounds
class TecnoWorkarounds extends ManufacturerWorkaround {
  const TecnoWorkarounds();

  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    // Tecno HiOS optimizations
    service._logger.info('📱 Tecno HiOS optimizations applied');
  }

  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableEffects': false, // Keep echo cancellation enabled for Tecno devices
    'useBasicAudioTrack': true,
    'avoidAudioFocusChanges': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Tecno HiOS Optimization:

1. Settings > Battery & performance > Auto-start manager
2. Enable Arena
3. Settings > Battery & performance > Background cleaner
4. Add Arena to protected apps

Phone Master app:
1. AutoStart management > Allow Arena
2. Background apps limit > Unlimited for Arena
''';
}

/// Infinix-specific workarounds
class InfinixWorkarounds extends ManufacturerWorkaround {
  const InfinixWorkarounds();

  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    // Infinix XOS optimizations
    service._logger.info('📱 Infinix XOS optimizations applied');
  }

  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableEffects': false, // Keep echo cancellation enabled for Infinix devices
    'useBasicAudioTrack': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Infinix XOS Optimization:

1. Settings > Battery > Power Marathon
2. Background app freeze > Exclude Arena
3. Settings > Security > Auto-start management
4. Enable Arena

XManager:
1. Auto-start > Enable Arena
2. Background cleaner > Exclude Arena
''';
}

/// Honor-specific workarounds (similar to Huawei)
class HonorWorkarounds extends ManufacturerWorkaround {
  const HonorWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('honor_requestProtectedApps');
      service._logger.info('📱 Honor Magic UI optimizations applied');
    } catch (e) {
      service._logger.debug('Honor workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableHonorEffects': true,
    'useCompatibleBuffering': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Honor Magic UI Optimization:

1. Settings > Apps > Arena
2. Battery > "Don't allow system to manage automatically"
3. App launch > Manual management (all switches ON)

Honor specific:
1. Settings > Battery > Protected apps
2. Enable Arena
3. Optimizer > Protected apps > Enable Arena
''';
}

/// Motorola-specific workarounds
class MotorolaWorkarounds extends ManufacturerWorkaround {
  const MotorolaWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    try {
      await ManufacturerWorkaroundsService._platform.invokeMethod('motorola_disableBatteryOptimization');
      service._logger.info('📱 Motorola optimizations applied');
    } catch (e) {
      service._logger.debug('Motorola workarounds error: $e');
    }
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'useMotoAudioAPI': true,
    'disableMotoDolby': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Motorola Optimization:

1. Settings > Battery > Battery optimization
2. All apps > Arena > Don't optimize

Moto Actions (if present):
1. Settings > Moto > Moto Actions
2. Disable audio-related gestures during calls
''';
}

/// Lenovo-specific workarounds
class LenovoWorkarounds extends ManufacturerWorkaround {
  const LenovoWorkarounds();
  
  @override
  Future<void> apply(ManufacturerWorkaroundsService service) async {
    service._logger.info('📱 Lenovo optimizations applied');
  }
  
  @override
  Map<String, dynamic> getAudioConfig() => {
    'disableViberatorEffects': true,
    'useBasicAudioSession': true,
  };
  
  @override
  String getBatteryInstructions() => '''
Lenovo Optimization:

1. Settings > Battery > Battery optimization
2. Arena > Don't optimize
3. Settings > Apps > Manage apps > Arena
4. Permissions > All permissions enabled

Power Manager (if present):
1. Background app management > Exclude Arena
2. Auto-start management > Enable Arena
''';
}