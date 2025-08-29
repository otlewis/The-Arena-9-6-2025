import '../core/logging/app_logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Performance optimization utilities for Arena app
class PerformanceOptimizations {
  static const Duration _debounceDelay = Duration(milliseconds: 100);
  static const Duration _throttleDelay = Duration(milliseconds: 16); // ~60fps
  
  /// Debounce timer for setState calls
  static Timer? _debounceTimer;
  
  /// Throttle timer for high-frequency updates
  static Timer? _throttleTimer;
  static bool _throttleActive = false;

  /// Debounced setState - prevents excessive rebuilds
  static void debouncedSetState(VoidCallback setState) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (!kDebugMode) {
        // In release mode, prioritize performance
        WidgetsBinding.instance.addPostFrameCallback((_) => setState());
      } else {
        setState();
      }
    });
  }

  /// Throttled setState - limits updates to ~60fps
  static void throttledSetState(VoidCallback setState) {
    if (_throttleActive) return;
    
    _throttleActive = true;
    _throttleTimer?.cancel();
    _throttleTimer = Timer(_throttleDelay, () {
      _throttleActive = false;
      if (!kDebugMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) => setState());
      } else {
        setState();
      }
    });
  }

  /// Batch multiple setState calls into one
  static void batchedSetState(List<VoidCallback> operations, VoidCallback setState) {
    // Execute all operations without triggering rebuilds
    for (final operation in operations) {
      operation();
    }
    // Single rebuild at the end
    WidgetsBinding.instance.addPostFrameCallback((_) => setState());
  }

  /// Cleanup timers
  static void dispose() {
    _debounceTimer?.cancel();
    _throttleTimer?.cancel();
    _debounceTimer = null;
    _throttleTimer = null;
    _throttleActive = false;
  }

  /// Memory-efficient list update that minimizes widget rebuilds
  static bool shouldUpdateList<T>(List<T> oldList, List<T> newList) {
    if (oldList.length != newList.length) return true;
    
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i] != newList[i]) return true;
    }
    return false;
  }

  /// Create performance-optimized GridView for audience
  static Widget buildOptimizedAudienceGrid({
    required List<dynamic> audience,
    required Widget Function(int index, dynamic item) itemBuilder,
    int crossAxisCount = 4,
    double childAspectRatio = 1.0,
    double spacing = 8.0,
  }) {
    if (audience.isEmpty) {
      return const Center(
        child: Text(
          'No audience members yet',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    // Use RepaintBoundary to isolate repaints
    return RepaintBoundary(
      child: CustomScrollView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Each grid item is isolated with RepaintBoundary
                return RepaintBoundary(
                  child: itemBuilder(index, audience[index]),
                );
              },
              childCount: audience.length,
              // Add semantic indexes for better accessibility
              semanticIndexCallback: (widget, localIndex) => localIndex,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
          ),
        ],
      ),
    );
  }

  /// Optimize image caching for user avatars
  static void preloadAvatarImages(List<String?> avatarUrls, BuildContext context) {
    for (final url in avatarUrls) {
      if (url != null && url.isNotEmpty) {
        // Preload images to improve grid scroll performance
        precacheImage(NetworkImage(url), context);
      }
    }
  }

  /// Efficient participant comparison to avoid unnecessary rebuilds
  static bool participantsChanged(List<dynamic> oldParticipants, List<dynamic> newParticipants) {
    if (oldParticipants.length != newParticipants.length) return true;
    
    for (int i = 0; i < oldParticipants.length; i++) {
      final old = oldParticipants[i];
      final newP = newParticipants[i];
      
      // Compare key fields that affect UI
      if (old['userId'] != newP['userId'] ||
          old['role'] != newP['role'] ||
          old['status'] != newP['status']) {
        return true;
      }
    }
    return false;
  }

  /// Frame rate monitoring (debug only)
  static void monitorFrameRate() {
    if (!kDebugMode) return;
    
    WidgetsBinding.instance.addPersistentFrameCallback((timeStamp) {
      final fps = 1000000 / timeStamp.inMicroseconds;
      if (fps < 55) {
        AppLogger().debug('⚠️ Low FPS detected: ${fps.toStringAsFixed(1)}');
      }
    });
  }
}

/// Optimized widget that prevents unnecessary rebuilds
class OptimizedBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final bool Function()? shouldRebuild;
  
  const OptimizedBuilder({
    super.key,
    required this.builder,
    this.shouldRebuild,
  });

  @override
  State<OptimizedBuilder> createState() => _OptimizedBuilderState();
}

class _OptimizedBuilderState extends State<OptimizedBuilder> {
  Widget? _cachedWidget;
  
  @override
  Widget build(BuildContext context) {
    final shouldRebuild = widget.shouldRebuild?.call() ?? true;
    
    if (shouldRebuild || _cachedWidget == null) {
      _cachedWidget = RepaintBoundary(child: widget.builder(context));
    }
    
    return _cachedWidget!;
  }
}

/// Optimized participant list item with automatic shouldRebuild
class OptimizedParticipantItem extends StatelessWidget {
  final dynamic participant;
  final Widget Function(dynamic participant) builder;
  
  const OptimizedParticipantItem({
    super.key,
    required this.participant,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: builder(participant),
    );
  }
}