import 'package:flutter/material.dart';

/// Semantic color families used across the app (see description §7).
enum Tone { red, orange, amber, green, pink, violet, brand, gray }

/// Colors of one tone: soft background (pill), text on that background,
/// a strong "solid" color (dot, filled button) and a text color on the page.
class ToneColors {
  const ToneColors({required this.bg, required this.fg, required this.solid, required this.text});
  final Color bg;
  final Color fg;
  final Color solid;
  final Color text;
}

/// Tailwind-like palette, kept identical to the original web app.
abstract final class Palette {
  static const brand50 = Color(0xFFEEF2FF);
  static const brand100 = Color(0xFFE0E7FF);
  static const brand200 = Color(0xFFC7D2FE);
  static const brand300 = Color(0xFFA5B4FC);
  static const brand400 = Color(0xFF818CF8);
  static const brand500 = Color(0xFF6366F1);
  static const brand600 = Color(0xFF4F46E5);
  static const brand700 = Color(0xFF4338CA);
  static const brand800 = Color(0xFF3730A3);
  static const brand900 = Color(0xFF312E81);

  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);
  static const night = Color(0xFF0B0B0F);
}

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.background,
    required this.card,
    required this.border,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.brand,
    required this.brandText,
    required this.brandSoft,
    required this.secondaryFill,
    required this.inputFill,
    required this.inputBorder,
  });

  final Brightness brightness;
  final Color background;
  final Color card;
  final Color border;
  final Color divider;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color brand;

  /// Brand color used for text/links/icons (lighter in dark mode).
  final Color brandText;

  /// Very light brand background for info boxes (#EEF2FF in light mode).
  final Color brandSoft;
  final Color secondaryFill;
  final Color inputFill;
  final Color inputBorder;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppColors(
    brightness: Brightness.light,
    background: Palette.gray50,
    card: Colors.white,
    border: Color(0xB3E5E7EB),
    divider: Palette.gray100,
    text: Palette.gray900,
    textMuted: Palette.gray500,
    textSubtle: Palette.gray400,
    brand: Palette.brand600,
    brandText: Palette.brand600,
    brandSoft: Palette.brand50,
    secondaryFill: Palette.gray100,
    inputFill: Colors.white,
    inputBorder: Palette.gray300,
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    background: Palette.night,
    card: Palette.gray900,
    border: Palette.gray800,
    divider: Palette.gray800,
    text: Color(0xFFF3F4F6),
    textMuted: Palette.gray400,
    textSubtle: Palette.gray500,
    brand: Palette.brand600,
    brandText: Palette.brand300,
    brandSoft: Color(0x66312E81),
    secondaryFill: Palette.gray800,
    inputFill: Palette.gray900,
    inputBorder: Palette.gray700,
  );

  ToneColors tone(Tone t) => isDark ? _darkTones[t]! : _lightTones[t]!;

  static const _lightTones = {
    Tone.red: ToneColors(bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B), solid: Color(0xFFDC2626), text: Color(0xFFDC2626)),
    Tone.orange: ToneColors(bg: Color(0xFFFFEDD5), fg: Color(0xFF9A3412), solid: Color(0xFFF97316), text: Color(0xFFEA580C)),
    Tone.amber: ToneColors(bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E), solid: Color(0xFFF59E0B), text: Color(0xFFD97706)),
    Tone.green: ToneColors(bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46), solid: Color(0xFF059669), text: Color(0xFF059669)),
    Tone.pink: ToneColors(bg: Color(0xFFFCE7F3), fg: Color(0xFF9D174D), solid: Color(0xFFDB2777), text: Color(0xFFDB2777)),
    Tone.violet: ToneColors(bg: Color(0xFFEDE9FE), fg: Color(0xFF5B21B6), solid: Color(0xFF7C3AED), text: Color(0xFF7C3AED)),
    Tone.brand: ToneColors(bg: Palette.brand100, fg: Palette.brand800, solid: Palette.brand600, text: Palette.brand600),
    Tone.gray: ToneColors(bg: Palette.gray200, fg: Palette.gray700, solid: Palette.gray500, text: Palette.gray500),
  };

  static const _darkTones = {
    Tone.red: ToneColors(bg: Color(0x667F1D1D), fg: Color(0xFFFECACA), solid: Color(0xFFEF4444), text: Color(0xFFF87171)),
    Tone.orange: ToneColors(bg: Color(0x667C2D12), fg: Color(0xFFFED7AA), solid: Color(0xFFF97316), text: Color(0xFFFB923C)),
    Tone.amber: ToneColors(bg: Color(0x6678350F), fg: Color(0xFFFDE68A), solid: Color(0xFFF59E0B), text: Color(0xFFFBBF24)),
    Tone.green: ToneColors(bg: Color(0x66064E3B), fg: Color(0xFFA7F3D0), solid: Color(0xFF3F9469), text: Color(0xFF34D399)),
    Tone.pink: ToneColors(bg: Color(0x66831843), fg: Color(0xFFFBCFE8), solid: Color(0xFFDB2777), text: Color(0xFFF9A8D4)),
    Tone.violet: ToneColors(bg: Color(0x664C1D95), fg: Color(0xFFDDD6FE), solid: Color(0xFF8B5CF6), text: Color(0xFFC4B5FD)),
    Tone.brand: ToneColors(bg: Color(0x66312E81), fg: Palette.brand200, solid: Palette.brand600, text: Palette.brand300),
    Tone.gray: ToneColors(bg: Palette.gray800, fg: Palette.gray300, solid: Palette.gray500, text: Palette.gray400),
  };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Radii & spacing shared by widgets.
abstract final class Radii {
  static const card = 20.0;
  static const button = 14.0;
  static const input = 14.0;
  static const sheet = 24.0;
}

ThemeData buildTheme(AppColors c) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.brand600,
      brightness: c.brightness,
      primary: Palette.brand600,
      surface: c.card,
      error: c.tone(Tone.red).solid,
    ),
  );
  final textTheme = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.input),
    borderSide: BorderSide(color: c.inputBorder),
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    extensions: [c],
    textTheme: textTheme,
    dividerColor: c.divider,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.inputFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: TextStyle(color: c.textSubtle),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: Palette.brand500, width: 1.6)),
      errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.tone(Tone.red).solid)),
      focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.tone(Tone.red).solid, width: 1.6)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.isDark ? Palette.gray700 : Palette.gray300,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.tone(Tone.green).solid : (c.isDark ? Palette.gray700 : Palette.gray300),
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.brand600),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    datePickerTheme: DatePickerThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
    timePickerTheme: TimePickerThemeData(backgroundColor: c.card),
  );
}
