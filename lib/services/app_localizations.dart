import 'package:flutter/widgets.dart';

import 'visual_settings.dart';

class AppLocalizations {
  final String localeCode;

  const AppLocalizations(this.localeCode);

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('bn'),
    Locale('te'),
    Locale('mr'),
    Locale('ta'),
    Locale('ur'),
    Locale('gu'),
    Locale('kn'),
    Locale('ml'),
    Locale('pa'),
    Locale('or'),
  ];

  static const languageLabels = <String, String>{
    'en': 'English',
    'hi': 'हिन्दी',
    'bn': 'বাংলা',
    'te': 'తెలుగు',
    'mr': 'मराठी',
    'ta': 'தமிழ்',
    'ur': 'اردو',
    'gu': 'ગુજરાતી',
    'kn': 'ಕನ್ನಡ',
    'ml': 'മലയാളം',
    'pa': 'ਪੰਜਾਬੀ',
    'or': 'ଓଡ଼ିଆ',
  };

  static const localizedStrings = <String, Map<String, String>>{
    'en': {},
    'hi': {
      'Records': 'रिकॉर्ड्स',
      'Analysis': 'विश्लेषण',
      'Budgets': 'बजट',
      'Accounts': 'अकाउंट्स',
      'Categories': 'कैटेगरी',
      'SMSs': 'SMS',
      'Expense': 'खर्च',
      'Income': 'आय',
      'Save': 'सेव करें',
      'Cancel': 'रद्द करें',
      'Search': 'खोज',
      'Comments': 'टिप्पणी',
      'Amount': 'राशि',
      'Type': 'प्रकार',
      'Account': 'अकाउंट',
      'Category': 'कैटेगरी',
      'Date': 'तारीख',
      'Add Transaction': 'ट्रांज़ैक्शन जोड़ें',
      'Edit Transaction': 'ट्रांज़ैक्शन संपादित करें',
    },
  };

  String t(String input) {
    final map = localizedStrings[localeCode] ?? const <String, String>{};
    return map[input] ?? input;
  }
}

class AppLocalizationsScope extends InheritedWidget {
  final AppLocalizations localizations;

  const AppLocalizationsScope({
    super.key,
    required this.localizations,
    required super.child,
  });

  static AppLocalizations of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocalizationsScope>();
    assert(scope != null, 'App localizations scope is not available.');
    return scope!.localizations;
  }

  @override
  bool updateShouldNotify(AppLocalizationsScope oldWidget) {
    return localizations.localeCode != oldWidget.localizations.localeCode;
  }
}

extension AppLocalizationX on BuildContext {
  String tr(String input) => AppLocalizationsScope.of(this).t(input);

  Locale get currentLocale {
    final settings = VisualSettingsScope.of(this).value;
    return Locale(settings.localeCode);
  }
}
