// Languages: the app follows the system language unless the user picks one
// (Settings, login / account creation). Strings live in lib/l10n/app_<lang>.arb,
// generated from tool/i18n/strings/*.txt (see tool/i18n/build_arb.py).
//
// To add a language: add a column to the strings files + LANGS in build_arb.py,
// then add it to [appLanguages] below and to CFBundleLocalizations (iOS Info.plist)
// and to the dispatch Edge Function templates.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart' show AppLocalizations;

/// Supported languages: code → native name (shown in pickers).
const appLanguages = {'fr': 'Français', 'en': 'English'};
const fallbackLanguage = 'fr';

AppLocalizations _current = lookupAppLocalizations(const Locale(fallbackLanguage));

/// Strings of the active language, usable outside widgets (toasts, helpers…).
AppLocalizations get tr => _current;

/// Active language code ("fr", "en").
String get currentLanguage => _current.localeName.split('_').first;

/// Applies a language to [tr] and intl's default locale (date formats).
void applyLanguage(String code) {
  final lang = appLanguages.containsKey(code) ? code : fallbackLanguage;
  _current = lookupAppLocalizations(Locale(lang));
  Intl.defaultLocale = lang;
}

/// Best supported language for the device settings.
String systemLanguage() {
  for (final l in WidgetsBinding.instance.platformDispatcher.locales) {
    if (appLanguages.containsKey(l.languageCode)) return l.languageCode;
  }
  return fallbackLanguage;
}

const _prefKey = 'language';

/// User choice: null = follow the system.
final languageChoiceProvider = NotifierProvider<LanguageChoice, String?>(LanguageChoice.new);

class LanguageChoice extends Notifier<String?> {
  /// Loaded in main() before runApp so the first frame is in the right language.
  static String? initial;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_prefKey);
      initial = appLanguages.containsKey(v) ? v : null;
    } catch (_) {
      initial = null;
    }
  }

  @override
  String? build() => initial;

  Future<void> set(String? code) async {
    state = code;
    initial = code;
    try {
      final p = await SharedPreferences.getInstance();
      if (code == null) {
        await p.remove(_prefKey);
      } else {
        await p.setString(_prefKey, code);
      }
    } catch (_) {}
  }
}

/// Effective language (choice, else system).
final languageProvider = Provider<String>((ref) => ref.watch(languageChoiceProvider) ?? systemLanguage());
