import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Light theme colors
  static const Color lightPrimary = Color(0xFFFF2400);
  static const Color lightPrimaryVariant = Color(0xFFFF4500);
  static const Color lightSecondary = Color(0xFF8B5CF6);
  static const Color lightSecondaryVariant = Color(0xFF6B46C1);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightAccent = Color(0xFFF1F0FF);

  // Dark theme colors
  static const Color darkPrimary = Color(0xFFFF4500);
  static const Color darkPrimaryVariant = Color(0xFFFF6B35);
  static const Color darkSecondary = Color(0xFF9D6CFF);
  static const Color darkSecondaryVariant = Color(0xFF7C4DFF);
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color darkSurface = Color(0xFF2D2D2D);
  static const Color darkAccent = Color(0xFF3A3A3A);

  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    primaryColorDark: lightPrimaryVariant,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      primaryContainer: lightPrimaryVariant,
      secondary: lightSecondary,
      secondaryContainer: lightSecondaryVariant,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF1A1A1A),
    ),
    scaffoldBackgroundColor: lightBackground,
    cardColor: lightSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      iconTheme: IconThemeData(color: lightPrimary),
    ),
    iconTheme: const IconThemeData(color: lightPrimary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: lightSecondaryVariant, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: lightSecondaryVariant, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: lightSecondaryVariant, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
      bodyMedium: TextStyle(color: Color(0xFF1A1A1A)),
      bodySmall: TextStyle(color: Color(0xFF666666)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: lightPrimary.withValues(alpha: 0.1)),
      ),
    ),
  );

  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    primaryColorDark: darkPrimaryVariant,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      primaryContainer: darkPrimaryVariant,
      secondary: darkSecondary,
      secondaryContainer: darkSecondaryVariant,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: darkBackground,
    cardColor: darkSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: Color(0xFFE0E0E0),
      elevation: 0,
      iconTheme: IconThemeData(color: darkPrimary),
    ),
    iconTheme: const IconThemeData(color: darkPrimary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
      bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
      bodySmall: TextStyle(color: Color(0xFFB0B0B0)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: darkPrimary.withValues(alpha: 0.1)),
      ),
    ),
  );

  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode == isDark) return;
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  // Helper methods for getting theme-specific colors
  Color get primaryColor => _isDarkMode ? darkPrimary : lightPrimary;
  Color get backgroundColor => _isDarkMode ? darkBackground : lightBackground;
  Color get surfaceColor => _isDarkMode ? darkSurface : lightSurface;
  Color get textColor => _isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);
  Color get secondaryTextColor => _isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF666666);
  Color get accentColor => _isDarkMode ? darkAccent : lightAccent;
  Color get secondaryColor => _isDarkMode ? darkSecondary : lightSecondary;
} 