import 'package:flutter/material.dart';
import '../widgets/report_user_dialog.dart';
import '../services/theme_service.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';

class ReportUserIcon extends StatelessWidget {
  final String userId;
  final String? userName;
  
  const ReportUserIcon({
    super.key,
    required this.userId,
    this.userName,
  });

  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color scarletRed = Color(0xFFFF2400);

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = ThemeService();
    
    return IconButton(
      onPressed: () async {
        // Get current user ID for reporting
        final appwrite = AppwriteService();
        final currentUser = await appwrite.getCurrentUser();
        
        if (currentUser == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please sign in to report users'),
                backgroundColor: scarletRed,
              ),
            );
          }
          return;
        }

        // Create a UserProfile object for the reported user
        final reportedUser = UserProfile(
          id: userId,
          name: userName ?? 'User',
          email: '', // Not needed for reporting
          avatar: null, // Not needed for reporting
          totalDebates: 0,
          totalWins: 0,
          reputation: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => ReportUserDialog(
              reportedUser: reportedUser,
              reporterId: currentUser.$id,
              roomId: 'profile_view', // Default room ID for profile reports
            ),
          );
        }
      },
      icon: Icon(
        Icons.report_problem,
        color: themeService.isDarkMode ? Colors.white : scarletRed,
      ),
      tooltip: 'Report User',
    );
  }
}