import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisualSettings {
  static const String _fontKey = 'visual_font_family';
  static const String _fontScaleKey = 'visual_text_scale';
  static const String _themeModeKey = 'visual_theme_mode';
  static const String _localeCodeKey = 'visual_locale_code';

  static const List<VisualFontOption> fontOptions = [
    VisualFontOption(key: 'default', label: 'Default', fontFamily: null),
    VisualFontOption(key: 'sans', label: 'Sans', fontFamily: 'sans-serif'),
    VisualFontOption(key: 'serif', label: 'Serif', fontFamily: 'serif'),
    VisualFontOption(key: 'mono', label: 'Monospace', fontFamily: 'monospace'),
  ];

  final String fontKey;
  final double textScale;
  final ThemeMode themeMode;
  final String localeCode;

  const VisualSettings({
    required this.fontKey,
    required this.textScale,
    required this.themeMode,
    required this.localeCode,
  });

  static const VisualSettings defaults = VisualSettings(
    fontKey: 'default',
    textScale: 1.0,
    themeMode: ThemeMode.light,
    localeCode: 'en',
  );

  String? get fontFamily =>
      fontOptions.firstWhere((option) => option.key == fontKey, orElse: () => fontOptions.first).fontFamily;

  String get fontLabel =>
      fontOptions.firstWhere((option) => option.key == fontKey, orElse: () => fontOptions.first).label;

  VisualSettings copyWith({
    String? fontKey,
    double? textScale,
    ThemeMode? themeMode,
    String? localeCode,
  }) {
    return VisualSettings(
      fontKey: fontKey ?? this.fontKey,
      textScale: textScale ?? this.textScale,
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
    );
  }

  static Future<VisualSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFont = prefs.getString(_fontKey) ?? defaults.fontKey;
    final storedScale = prefs.getDouble(_fontScaleKey) ?? defaults.textScale;
    final storedThemeMode = prefs.getString(_themeModeKey) ?? ThemeMode.light.name;
    final storedLocaleCode = prefs.getString(_localeCodeKey) ?? defaults.localeCode;

    final validFont = fontOptions.any((option) => option.key == storedFont)
        ? storedFont
        : defaults.fontKey;

    final validThemeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == storedThemeMode,
      orElse: () => ThemeMode.light,
    );

    return VisualSettings(
      fontKey: validFont,
      textScale: storedScale.clamp(0.85, 1.35),
      themeMode: validThemeMode,
      localeCode: storedLocaleCode,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, fontKey);
    await prefs.setDouble(_fontScaleKey, textScale);
    await prefs.setString(_themeModeKey, themeMode.name);
    await prefs.setString(_localeCodeKey, localeCode);
  }
}

class VisualFontOption {
  final String key;
  final String label;
  final String? fontFamily;

  const VisualFontOption({
    required this.key,
    required this.label,
    required this.fontFamily,
  });
}

class VisualSettingsController extends ValueNotifier<VisualSettings> {
  VisualSettingsController(super.value);

  Future<void> updateSettings(VisualSettings settings) async {
    value = settings;
    await settings.save();
  }

  Future<void> reset() async {
    await updateSettings(VisualSettings.defaults);
  }
}

class FinTrackTheme {
  static ThemeData build(VisualSettings settings, {Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      brightness: brightness,
      primarySwatch: Colors.green,
      scaffoldBackgroundColor: isDark ? const Color(0xFF101418) : const Color(0xFFF3F5F9),
    );

    final scaledTextTheme = base.textTheme.apply(
      fontFamily: settings.fontFamily,
      bodyColor: isDark ? const Color(0xFFE6E8EB) : const Color(0xFF1F2933),
      displayColor: isDark ? const Color(0xFFE6E8EB) : const Color(0xFF1F2933),
    );

    return base.copyWith(
      textTheme: scaledTextTheme,
      primaryTextTheme: scaledTextTheme,
      visualDensity: VisualDensity.compact,
      listTileTheme: const ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity.compact,
        minVerticalPadding: 2,
      ),
      popupMenuTheme: const PopupMenuThemeData(),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0B0D10) : Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: scaledTextTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: scaledTextTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}


class VisualSettingsScope extends InheritedWidget {
  final VisualSettingsController controller;

  const VisualSettingsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static VisualSettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VisualSettingsScope>();
    assert(scope != null, 'Visual settings controller is not available.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(VisualSettingsScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
