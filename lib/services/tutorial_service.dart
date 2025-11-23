import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/feature_highlights_screen.dart';

/// Service to manage contextual tutorials across different screens
class TutorialService {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  // Tutorial completion keys for SharedPreferences
  static const String _homeScreenTutorial = 'tutorial_home_screen';
  static const String _arenaScreenTutorial = 'tutorial_arena_screen';
  static const String _createRoomTutorial = 'tutorial_create_room';
  static const String _debatesScreenTutorial = 'tutorial_debates_screen';
  static const String _findUsersTutorial = 'tutorial_find_users';
  static const String _inRoomTutorial = 'tutorial_in_room';

  // Global dismiss flag
  static const String _globalDismiss = 'tutorial_global_dismiss';

  /// Check if user has globally dismissed all tutorials
  Future<bool> hasGloballyDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_globalDismiss) ?? false;
  }

  /// Set global dismiss flag
  Future<void> setGlobalDismiss(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalDismiss, value);
  }

  /// Check if a specific tutorial has been seen
  Future<bool> hasSeen(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(tutorialKey) ?? false;
  }

  /// Mark a specific tutorial as seen
  Future<void> markAsSeen(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tutorialKey, true);
  }

  /// Reset all tutorials (useful for testing or if user wants to see them again)
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeScreenTutorial, false);
    await prefs.setBool(_arenaScreenTutorial, false);
    await prefs.setBool(_createRoomTutorial, false);
    await prefs.setBool(_debatesScreenTutorial, false);
    await prefs.setBool(_findUsersTutorial, false);
    await prefs.setBool(_inRoomTutorial, false);
    await prefs.setBool(_globalDismiss, false);
  }

  /// Show tutorial if not seen and not globally dismissed
  Future<void> maybeShowTutorial({
    required BuildContext context,
    required String tutorialKey,
    required List<FeatureHighlight> highlights,
    bool force = false,
  }) async {
    // Check global dismiss first
    if (!force && await hasGloballyDismissed()) {
      return;
    }

    // Check if this specific tutorial has been seen
    if (!force && await hasSeen(tutorialKey)) {
      return;
    }

    // Wait for UI to settle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        _showTutorialOverlay(
          context: context,
          tutorialKey: tutorialKey,
          highlights: highlights,
        );
      }
    });
  }

  void _showTutorialOverlay({
    required BuildContext context,
    required String tutorialKey,
    required List<FeatureHighlight> highlights,
  }) {
    // Insert the tutorial directly as an overlay entry to avoid blocking navigation
    final overlayState = Overlay.of(context);
    OverlayEntry? tutorialOverlay;

    tutorialOverlay = OverlayEntry(
      builder: (context) => FeatureHighlightsScreen(
        highlights: highlights,
        onComplete: () async {
          await markAsSeen(tutorialKey);
          tutorialOverlay?.remove();
        },
        onDismissAll: () async {
          await setGlobalDismiss(true);
          tutorialOverlay?.remove();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All tutorials dismissed. You can re-enable them in settings.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
      ),
    );

    overlayState.insert(tutorialOverlay);
  }

  // Tutorial key getters for easy access
  String get homeScreenKey => _homeScreenTutorial;
  String get arenaScreenKey => _arenaScreenTutorial;
  String get createRoomKey => _createRoomTutorial;
  String get debatesScreenKey => _debatesScreenTutorial;
  String get findUsersKey => _findUsersTutorial;
  String get inRoomKey => _inRoomTutorial;
}
