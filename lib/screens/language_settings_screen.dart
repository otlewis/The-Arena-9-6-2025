import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../services/accessibility_service.dart';
import '../l10n/generated/app_localizations.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final LanguageService _languageService = LanguageService();
  final AccessibilityService _accessibilityService = AccessibilityService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.language),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Language / Seleccionar idioma / Sélectionner la langue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16 * _accessibilityService.textScaleFactor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...LanguageService.supportedLocales.map((locale) {
                    final isSelected = _languageService.locale.languageCode == locale.languageCode;
                    final languageName = _languageService.getLanguageName(locale.languageCode);
                    
                    return ListTile(
                      title: Text(
                        languageName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16 * _accessibilityService.textScaleFactor,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: () async {
                        _accessibilityService.provideHapticFeedback();
                        await _languageService.setLocale(locale);
                        _accessibilityService.announceToScreenReader('Language changed to $languageName');
                        setState(() {});
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accessibility,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16 * _accessibilityService.textScaleFactor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      l10n.largeText,
                      style: TextStyle(fontSize: 16 * _accessibilityService.textScaleFactor),
                    ),
                    subtitle: Text(
                      'Increase text size for better readability',
                      style: TextStyle(fontSize: 14 * _accessibilityService.textScaleFactor),
                    ),
                    value: _accessibilityService.largeTextEnabled,
                    onChanged: (value) async {
                      await _accessibilityService.setLargeTextEnabled(value);
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      l10n.highContrast,
                      style: TextStyle(fontSize: 16 * _accessibilityService.textScaleFactor),
                    ),
                    subtitle: Text(
                      'Use high contrast colors for better visibility',
                      style: TextStyle(fontSize: 14 * _accessibilityService.textScaleFactor),
                    ),
                    value: _accessibilityService.highContrastEnabled,
                    onChanged: (value) async {
                      await _accessibilityService.setHighContrastEnabled(value);
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      l10n.screenReader,
                      style: TextStyle(fontSize: 16 * _accessibilityService.textScaleFactor),
                    ),
                    subtitle: Text(
                      'Optimize interface for screen readers',
                      style: TextStyle(fontSize: 14 * _accessibilityService.textScaleFactor),
                    ),
                    value: _accessibilityService.screenReaderOptimized,
                    onChanged: (value) async {
                      await _accessibilityService.setScreenReaderOptimized(value);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Text Scale: ${(_accessibilityService.textScaleFactor * 100).round()}%',
                    style: TextStyle(fontSize: 16 * _accessibilityService.textScaleFactor),
                  ),
                  Slider(
                    value: _accessibilityService.textScaleFactor,
                    min: 0.8,
                    max: 2.0,
                    divisions: 12,
                    label: '${(_accessibilityService.textScaleFactor * 100).round()}%',
                    onChanged: (value) async {
                      await _accessibilityService.setTextScaleFactor(value);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}