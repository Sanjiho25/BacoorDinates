import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  Locale _currentLocale;

  LanguageProvider() : _currentLocale = const Locale('en') {
    _loadSavedLanguage();
  }

  Locale get currentLocale => _currentLocale;

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      if (savedLanguage != null) {
        final parts = savedLanguage.split('_');
        _currentLocale = parts.length > 1 
            ? Locale(parts[0], parts[1])
            : Locale(parts[0]);
        notifyListeners();
      }
    } catch (e) {
      // If there's an error loading the saved language, keep using English
      debugPrint('Error loading saved language: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    notifyListeners(); // Update UI immediately, don't wait for I/O

    try {
      final prefs = await SharedPreferences.getInstance();
      final localeString = locale.countryCode != null
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;
      await prefs.setString(_languageKey, localeString);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }
}