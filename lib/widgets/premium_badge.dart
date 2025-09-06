import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

/// Premium subscriber badge widget
/// Shows gold shield for yearly subscribers, silver shield for monthly subscribers
class PremiumBadge extends StatelessWidget {
  final UserProfile user;
  final double size;
  final bool showText;

  const PremiumBadge({
    super.key,
    required this.user,
    this.size = 16.0,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    // Debug logging
    AppLogger().debug('🛡️ PremiumBadge: Checking user ${user.name} - isPremium: ${user.isPremium}, premiumType: ${user.premiumType}');
    
    // Check if user is premium
    if (!user.isPremium) {
      AppLogger().debug('🛡️ PremiumBadge: User ${user.name} is not premium, hiding badge');
      return const SizedBox.shrink();
    }

    final isYearly = user.premiumType == 'yearly';
    final badgeColor = isYearly ? Colors.amber : Colors.grey[400]!;
    final badgeText = isYearly ? 'GOLD' : 'SILVER';
    final textColor = Colors.black;
    
    AppLogger().debug('🛡️ PremiumBadge: Showing ${badgeText} badge for ${user.name}');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showText ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield,
            color: textColor,
            size: size,
          ),
          if (showText) ...[
            const SizedBox(width: 4),
            Text(
              badgeText,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.625, // 10pt for 16pt icon
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact premium badge for small spaces
class CompactPremiumBadge extends StatelessWidget {
  final UserProfile user;
  final double size;

  const CompactPremiumBadge({
    super.key,
    required this.user,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumBadge(
      user: user,
      size: size,
      showText: false,
    );
  }
}

/// Premium badge with glow effect for winners or special occasions
class GlowingPremiumBadge extends StatefulWidget {
  final UserProfile user;
  final double size;
  final bool showText;

  const GlowingPremiumBadge({
    super.key,
    required this.user,
    this.size = 16.0,
    this.showText = true,
  });

  @override
  State<GlowingPremiumBadge> createState() => _GlowingPremiumBadgeState();
}

class _GlowingPremiumBadgeState extends State<GlowingPremiumBadge> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is premium
    if (!widget.user.isPremium) {
      return const SizedBox.shrink();
    }

    final isYearly = widget.user.premiumType == 'yearly';
    final badgeColor = isYearly ? Colors.amber : Colors.grey[400]!;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: badgeColor.withValues(alpha: _glowAnimation.value),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: PremiumBadge(
            user: widget.user,
            size: widget.size,
            showText: widget.showText,
          ),
        );
      },
    );
  }
}