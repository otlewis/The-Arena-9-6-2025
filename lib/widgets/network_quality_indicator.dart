import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/network_resilience_service.dart';

/// Widget that displays current network quality status with visual indicators
class NetworkQualityIndicator extends StatefulWidget {
  final bool showText;
  final bool showIcon;
  final double? iconSize;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const NetworkQualityIndicator({
    super.key,
    this.showText = true,
    this.showIcon = true,
    this.iconSize,
    this.textStyle,
    this.padding,
  });

  @override
  State<NetworkQualityIndicator> createState() => _NetworkQualityIndicatorState();
}

class _NetworkQualityIndicatorState extends State<NetworkQualityIndicator> {
  final NetworkResilienceService _networkService = GetIt.instance<NetworkResilienceService>();
  bool _isOnline = true;
  NetworkQuality _networkQuality = NetworkQuality.good;

  @override
  void initState() {
    super.initState();
    _isOnline = _networkService.isOnline;
    _networkQuality = _networkService.networkQuality;

    // Listen to network changes
    _networkService.connectionStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });

    _networkService.networkQualityStream.listen((quality) {
      if (mounted) {
        setState(() {
          _networkQuality = quality;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showIcon && !widget.showText) {
      return const SizedBox.shrink();
    }

    final config = _getNetworkConfig();
    
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon) ...[
            Icon(
              config.icon,
              color: config.color,
              size: widget.iconSize ?? 16,
            ),
            if (widget.showText) const SizedBox(width: 4),
          ],
          if (widget.showText)
            Text(
              config.text,
              style: widget.textStyle?.copyWith(color: config.color) ??
                  TextStyle(
                    color: config.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
            ),
        ],
      ),
    );
  }

  NetworkConfig _getNetworkConfig() {
    if (!_isOnline) {
      return NetworkConfig(
        icon: Icons.wifi_off,
        text: 'Offline',
        color: Colors.red[600]!,
      );
    }

    switch (_networkQuality) {
      case NetworkQuality.good:
        return NetworkConfig(
          icon: Icons.wifi,
          text: 'Good',
          color: Colors.green[600]!,
        );
      case NetworkQuality.moderate:
        return NetworkConfig(
          icon: Icons.wifi_2_bar,
          text: 'Fair',
          color: Colors.orange[600]!,
        );
      case NetworkQuality.poor:
        return NetworkConfig(
          icon: Icons.wifi_1_bar,
          text: 'Poor',
          color: Colors.red[600]!,
        );
      case NetworkQuality.offline:
        return NetworkConfig(
          icon: Icons.wifi_off,
          text: 'Offline',
          color: Colors.red[600]!,
        );
    }
  }
}

/// Compact network quality indicator for status bars
class CompactNetworkIndicator extends StatelessWidget {
  const CompactNetworkIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const NetworkQualityIndicator(
      showText: false,
      iconSize: 14,
      padding: EdgeInsets.all(4),
    );
  }
}

/// Full network quality indicator with text
class FullNetworkIndicator extends StatelessWidget {
  const FullNetworkIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const NetworkQualityIndicator(
      showText: true,
      showIcon: true,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}

/// Network quality banner for poor connections
class NetworkQualityBanner extends StatefulWidget {
  const NetworkQualityBanner({super.key});

  @override
  State<NetworkQualityBanner> createState() => _NetworkQualityBannerState();
}

class _NetworkQualityBannerState extends State<NetworkQualityBanner> with TickerProviderStateMixin {
  final NetworkResilienceService _networkService = GetIt.instance<NetworkResilienceService>();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  bool _showBanner = false;
  bool _isOnline = true;
  NetworkQuality _networkQuality = NetworkQuality.good;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _isOnline = _networkService.isOnline;
    _networkQuality = _networkService.networkQuality;
    _updateBannerVisibility();

    // Listen to network changes
    _networkService.connectionStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _updateBannerVisibility();
        });
      }
    });

    _networkService.networkQualityStream.listen((quality) {
      if (mounted) {
        setState(() {
          _networkQuality = quality;
          _updateBannerVisibility();
        });
      }
    });
  }

  void _updateBannerVisibility() {
    final shouldShow = !_isOnline || _networkQuality == NetworkQuality.poor;
    
    if (shouldShow != _showBanner) {
      setState(() {
        _showBanner = shouldShow;
      });
      
      if (_showBanner) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) {
      return const SizedBox.shrink();
    }

    final config = _getNetworkConfig();
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 50),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  config.icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        config.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (config.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          config.subtitle!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  NetworkBannerConfig _getNetworkConfig() {
    if (!_isOnline) {
      return NetworkBannerConfig(
        icon: Icons.wifi_off,
        title: 'No Internet Connection',
        subtitle: 'Check your connection and try again',
        color: Colors.red[700]!,
      );
    }

    switch (_networkQuality) {
      case NetworkQuality.poor:
        return NetworkBannerConfig(
          icon: Icons.wifi_1_bar,
          title: 'Poor Connection',
          subtitle: 'Some features may be slower than usual',
          color: Colors.orange[700]!,
        );
      default:
        return NetworkBannerConfig(
          icon: Icons.wifi,
          title: 'Connection Restored',
          color: Colors.green[700]!,
        );
    }
  }
}

class NetworkConfig {
  final IconData icon;
  final String text;
  final Color color;

  NetworkConfig({
    required this.icon,
    required this.text,
    required this.color,
  });
}

class NetworkBannerConfig {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  NetworkBannerConfig({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
  });
}