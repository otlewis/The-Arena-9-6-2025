import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? initials;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.initials,
    this.radius = 20,
    this.backgroundColor = const Color(0xFFFFF1F0),
    this.textColor = const Color(0xFFFF2400),
    this.onTap,
    this.showBorder = false,
    this.borderColor = const Color(0xFFFF2400),
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildInitialsAvatar(),
            errorWidget: (context, url, error) => _buildInitialsAvatar(),
          ),
        ),
      );
    } else {
      avatar = _buildInitialsAvatar();
    }

    if (showBorder) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: avatar,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildInitialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        _getInitials(),
        style: TextStyle(
          color: textColor,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials() {
    if (initials != null && initials!.isNotEmpty) {
      return initials!.toUpperCase();
    }
    return 'U';
  }
}

class UserAvatarStatus extends StatelessWidget {
  final String? avatarUrl;
  final String? initials;
  final double radius;
  final bool isOnline;
  final bool isSpeaking;
  final VoidCallback? onTap;

  const UserAvatarStatus({
    super.key,
    this.avatarUrl,
    this.initials,
    this.radius = 24,
    this.isOnline = false,
    this.isSpeaking = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UserAvatar(
          avatarUrl: avatarUrl,
          initials: initials,
          radius: radius,
          onTap: onTap,
          showBorder: isSpeaking,
          borderColor: const Color(0xFF4CAF50), // Green for speaking
          borderWidth: 3,
        ),
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.4,
              height: radius * 0.4,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50), // Green for online
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
} 