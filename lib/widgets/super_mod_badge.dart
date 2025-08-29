import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/super_moderator_service.dart';

class SuperModBadge extends StatelessWidget {
  final String userId;
  final double size;
  final bool showText;

  const SuperModBadge({
    super.key,
    required this.userId,
    this.size = 20,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final superModService = GetIt.instance<SuperModeratorService>();
    
    if (!superModService.isSuperModerator(userId)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showText ? 6 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700), // Gold
            Color(0xFFFFA500), // Orange Gold
          ],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
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
            size: size,
            color: Colors.white,
          ),
          if (showText) ...[
            const SizedBox(width: 2),
            Text(
              'SM',
              style: TextStyle(
                fontSize: size * 0.7,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0.5, 0.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}