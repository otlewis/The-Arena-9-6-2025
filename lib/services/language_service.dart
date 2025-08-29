import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging/app_logger.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  Locale _locale = const Locale('en');
  final AppLogger _logger = AppLogger();

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('es', ''), // Spanish
    Locale('fr', ''), // French
  ];

  // Language display names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
  };

  Locale get locale => _locale;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('language_code');
      
      if (savedLanguage != null) {
        final savedLocale = Locale(savedLanguage);
        if (supportedLocales.contains(savedLocale)) {
          _locale = savedLocale;
          _logger.debug('Loaded saved language: $savedLanguage');
        }
      } else {
        // Use system locale if supported, otherwise default to English
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (supportedLocales.any((locale) => locale.languageCode == systemLocale.languageCode)) {
          _locale = Locale(systemLocale.languageCode);
          _logger.debug('Using system language: ${systemLocale.languageCode}');
        }
      }
      
      notifyListeners();
    } catch (e) {
      _logger.error('Error initializing language service: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    try {
      if (supportedLocales.contains(locale) && _locale != locale) {
        _locale = locale;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', locale.languageCode);
        
        _logger.info('Language changed to: ${locale.languageCode}');
        notifyListeners();
      }
    } catch (e) {
      _logger.error('Error setting locale: $e');
    }
  }

  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode.toUpperCase();
  }

  bool isSupported(Locale locale) {
    return supportedLocales.any((supportedLocale) => 
        supportedLocale.languageCode == locale.languageCode);
  }

  /// Get RTL (Right-to-Left) language support
  bool isRTL(String languageCode) {
    // Add RTL languages as needed (Arabic, Hebrew, etc.)
    const rtlLanguages = ['ar', 'he', 'fa', 'ur'];
    return rtlLanguages.contains(languageCode);
  }

  /// Get locale-specific number formatting
  String formatNumber(int number) {
    // This could be expanded to use proper locale-specific formatting
    return number.toString();
  }

  /// Get locale-specific date formatting preference
  bool use24HourFormat() {
    // Most countries use 24-hour format, US typically uses 12-hour
    return _locale.languageCode != 'en' || _locale.countryCode != 'US';
  }
}