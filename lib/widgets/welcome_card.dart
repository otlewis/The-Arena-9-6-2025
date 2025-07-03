import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import 'gavel_logo.dart';
// Import your providers
import '../providers/user_profile_notifier.dart';
import '../providers/theme_notifier.dart';

class WelcomeCard extends ConsumerWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileNotifierProvider);
    final isDarkMode = ref.watch(themeNotifierProvider);

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Custom Logo
              AnimatedScaleIn(
                delay: const Duration(milliseconds: 400),
                child: Center(
                  child: GavelLogo(
                    color: isDarkMode ? Colors.white : const Color(0xFF6B46C1),
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 600),
                child: Text(
                  'Welcome to The Arena',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF6B46C1),
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 800),
                child: Text(
                  'Where Debate is Royalty',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? const Color(0xFF8B5CF6) : const Color(0xFFDC2626),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 18),
              userProfileAsync.when(
                data: (profile) => AnimatedSlideIn(
                  delay: const Duration(milliseconds: 1000),
                  child: _buildStatsRow(context, profile, isDarkMode),
                ),
                loading: () => _buildSkeletonStats(context, isDarkMode),
                error: (_, __) => _buildStatsRow(context, null, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonStats(BuildContext context, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSkeletonStatBox(context, isDarkMode),
        _buildSkeletonStatBox(context, isDarkMode),
        _buildSkeletonStatBox(context, isDarkMode),
      ],
    );
  }

  Widget _buildSkeletonStatBox(BuildContext context, bool isDarkMode) {
    return Column(
      children: [
        SkeletonText(width: 40, height: 20),
        const SizedBox(height: 4),
        SkeletonText(width: 60, height: 14),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context, UserProfile? profile, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox(context, 'Wins', profile?.totalWins ?? 0, isDarkMode),
        _buildStatBox(context, 'Debates', profile?.totalDebates ?? 0, isDarkMode),
        _buildStatBox(context, 'Rank', (profile?.reputation != null ? (profile!.reputation / 100).toStringAsFixed(1) : '0.0'), isDarkMode),
      ],
    );
  }

  Widget _buildStatBox(BuildContext context, String label, dynamic value, bool isDarkMode) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF6B46C1),
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 