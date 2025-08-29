import 'package:flutter/material.dart';
import '../logging/app_logger.dart';

/// Service for implementing code splitting and lazy loading
class CodeSplittingService {
  static final CodeSplittingService _instance = CodeSplittingService._internal();
  factory CodeSplittingService() => _instance;
  CodeSplittingService._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, Widget> _loadedModules = {};
  final Map<String, Future<Widget>> _loadingModules = {};

  /// Lazy load a module/screen with code splitting
  Future<Widget> loadModule(String moduleName, Future<Widget> Function() loader) async {
    // Return cached module if already loaded
    if (_loadedModules.containsKey(moduleName)) {
      _logger.debug('📦 Module $moduleName loaded from cache');
      return _loadedModules[moduleName]!;
    }

    // Return existing loading future if already loading
    if (_loadingModules.containsKey(moduleName)) {
      _logger.debug('📦 Module $moduleName already loading, waiting...');
      return await _loadingModules[moduleName]!;
    }

    // Start loading the module
    _logger.info('📦 Starting to load module: $moduleName');
    final loadingFuture = _loadModuleInternal(moduleName, loader);
    _loadingModules[moduleName] = loadingFuture;

    try {
      final widget = await loadingFuture;
      _loadedModules[moduleName] = widget;
      _loadingModules.remove(moduleName);
      _logger.info('📦 Successfully loaded module: $moduleName');
      return widget;
    } catch (e) {
      _loadingModules.remove(moduleName);
      _logger.error('📦 Failed to load module $moduleName: $e');
      rethrow;
    }
  }

  /// Internal module loading with performance tracking
  Future<Widget> _loadModuleInternal(String moduleName, Future<Widget> Function() loader) async {
    final startTime = DateTime.now();
    
    try {
      final widget = await loader();
      final loadTime = DateTime.now().difference(startTime);
      _logger.info('📦 Module $moduleName loaded in ${loadTime.inMilliseconds}ms');
      return widget;
    } catch (e) {
      final loadTime = DateTime.now().difference(startTime);
      _logger.error('📦 Module $moduleName failed to load after ${loadTime.inMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Create a lazy loading widget wrapper
  Widget createLazyWidget({
    required String moduleName,
    required Future<Widget> Function() loader,
    Widget? placeholder,
    Widget? errorBuilder,
  }) {
    return LazyLoadWidget(
      moduleName: moduleName,
      loader: loader,
      placeholder: placeholder ?? _buildDefaultPlaceholder(),
      errorBuilder: errorBuilder ?? _buildDefaultErrorWidget(),
    );
  }

  /// Build default loading placeholder
  Widget _buildDefaultPlaceholder() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }

  /// Build default error widget
  Widget _buildDefaultErrorWidget() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load module'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Trigger reload by clearing cache
                _loadedModules.clear();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Clear module cache (useful for development)
  void clearCache() {
    _loadedModules.clear();
    _loadingModules.clear();
    _logger.info('📦 Code splitting cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'loadedModules': _loadedModules.length,
      'loadingModules': _loadingModules.length,
      'moduleNames': _loadedModules.keys.toList(),
    };
  }
}

/// Lazy loading widget that loads modules on demand
class LazyLoadWidget extends StatefulWidget {
  final String moduleName;
  final Future<Widget> Function() loader;
  final Widget placeholder;
  final Widget errorBuilder;

  const LazyLoadWidget({
    super.key,
    required this.moduleName,
    required this.loader,
    required this.placeholder,
    required this.errorBuilder,
  });

  @override
  State<LazyLoadWidget> createState() => _LazyLoadWidgetState();
}

class _LazyLoadWidgetState extends State<LazyLoadWidget> {
  final CodeSplittingService _service = CodeSplittingService();
  late Future<Widget> _loadingFuture;

  @override
  void initState() {
    super.initState();
    _loadingFuture = _service.loadModule(widget.moduleName, widget.loader);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder;
        } else if (snapshot.hasError) {
          return widget.errorBuilder;
        } else if (snapshot.hasData) {
          return snapshot.data!;
        } else {
          return widget.errorBuilder;
        }
      },
    );
  }
}

/// Helper function to create lazy-loaded routes
Route<T> createLazyRoute<T extends Object?>({
  required String moduleName,
  required Future<Widget> Function() loader,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) {
      return CodeSplittingService().createLazyWidget(
        moduleName: moduleName,
        loader: loader,
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}