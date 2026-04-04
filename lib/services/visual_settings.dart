import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisualSettings {
  static const String _fontKey = 'visual_font_family';
  static const String _fontScaleKey = 'visual_text_scale';
  static const String _themeModeKey = 'visual_theme_mode';
  static const String _localeCodeKey = 'visual_locale_code';
  static const String _comparisonModeKey = 'visual_comparison_mode';

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
  final ComparisonMode comparisonMode;

  const VisualSettings({
    required this.fontKey,
    required this.textScale,
    required this.themeMode,
    required this.localeCode,
    required this.comparisonMode,
  });

  static const VisualSettings defaults = VisualSettings(
    fontKey: 'default',
    textScale: 1.0,
    themeMode: ThemeMode.light,
    localeCode: 'en',
    comparisonMode: ComparisonMode.budgetVsExpense,
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
    ComparisonMode? comparisonMode,
  }) {
    return VisualSettings(
      fontKey: fontKey ?? this.fontKey,
      textScale: textScale ?? this.textScale,
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
      comparisonMode: comparisonMode ?? this.comparisonMode,
    );
  }

  static Future<VisualSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFont = prefs.getString(_fontKey) ?? defaults.fontKey;
    final storedScale = prefs.getDouble(_fontScaleKey) ?? defaults.textScale;
    final storedThemeMode = prefs.getString(_themeModeKey) ?? ThemeMode.light.name;
    final storedLocaleCode = prefs.getString(_localeCodeKey) ?? defaults.localeCode;
    final storedComparisonMode = prefs.getString(_comparisonModeKey) ?? defaults.comparisonMode.name;

    final validFont = fontOptions.any((option) => option.key == storedFont)
        ? storedFont
        : defaults.fontKey;

    var validThemeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == storedThemeMode,
      orElse: () => ThemeMode.light,
    );
    // System theme removed from UI; migrate saved preference.
    if (validThemeMode == ThemeMode.system) {
      validThemeMode = ThemeMode.light;
    }
    final validComparisonMode = ComparisonMode.values.firstWhere(
      (mode) => mode.name == storedComparisonMode,
      orElse: () => ComparisonMode.budgetVsExpense,
    );

    final settings = VisualSettings(
      fontKey: validFont,
      textScale: storedScale.clamp(0.85, 1.35),
      themeMode: validThemeMode,
      localeCode: storedLocaleCode,
      comparisonMode: validComparisonMode,
    );
    if (storedThemeMode == ThemeMode.system.name) {
      await settings.save();
    }
    return settings;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, fontKey);
    await prefs.setDouble(_fontScaleKey, textScale);
    await prefs.setString(_themeModeKey, themeMode.name);
    await prefs.setString(_localeCodeKey, localeCode);
    await prefs.setString(_comparisonModeKey, comparisonMode.name);
  }
}

enum ComparisonMode {
  budgetVsExpense,
  incomeVsExpense,
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
    const primary = Color(0xFFE88363);
    const primaryDark = Color(0xFFD86F4E);
    const accent = Color(0xFFF2A287);
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: primaryDark,
            onPrimary: Colors.white,
            secondary: accent,
            onSecondary: Colors.white,
            surface: const Color(0xFF1E1410),
            onSurface: const Color(0xFFFFF4EF),
            onSurfaceVariant: const Color(0xFFD8B4A6),
            surfaceContainerHighest: const Color(0xFF281D18),
            outline: const Color(0xFF775649),
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: Colors.white,
            secondary: accent,
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF2A1A14),
            onSurfaceVariant: const Color(0xFF7A5A4D),
            surfaceContainerHighest: const Color(0xFFFFF2EC),
            outline: const Color(0xFFE9D2C8),
          );

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      primarySwatch: Colors.deepOrange,
      scaffoldBackgroundColor: isDark ? const Color(0xFF160E0B) : Colors.white,
      dividerColor: isDark ? const Color(0xFF6D4A3F) : const Color(0xFFE9D2C8),
      splashColor: colorScheme.primary.withValues(alpha: 0.10),
      highlightColor: colorScheme.primary.withValues(alpha: 0.05),
      hoverColor: colorScheme.primary.withValues(alpha: 0.04),
    );

    final scaledTextTheme = base.textTheme.apply(
      fontFamily: settings.fontFamily,
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return base.copyWith(
      textTheme: scaledTextTheme,
      primaryTextTheme: scaledTextTheme,
      visualDensity: VisualDensity.compact,
      listTileTheme: ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity.compact,
        minVerticalPadding: 2,
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF160E0B) : (Color.lerp(primary, Colors.white, 0.34) ?? primary),
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
