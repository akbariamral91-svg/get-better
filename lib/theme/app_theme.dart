import 'package:flutter/material.dart';

/// پالت رنگ برنامه. دو نمونهٔ ثابت دارد (تیره و روشن) و از طریق `context.colors` بر اساس تم فعلی انتخاب می‌شود.
/// حالت تیره ظاهر اصلی برنامه است.
class C {
  final Color bg, card, card2, text, muted, gold, green, red, onAccent;
  const C({
    required this.bg,
    required this.card,
    required this.card2,
    required this.text,
    required this.muted,
    required this.gold,
    required this.green,
    required this.red,
    required this.onAccent,
  });

  /// سرمه‌ای بسیار تیره، کارت‌های کمی روشن‌تر، تأکید طلایی
  static const dark = C(
    bg: Color(0xFF0A1128),
    card: Color(0xFF131D3B),
    card2: Color(0xFF1B2850),
    text: Color(0xFFE8ECF8),
    muted: Color(0xFF8E9AC0),
    gold: Color(0xFFE8B84A),
    green: Color(0xFF4CC38A),
    red: Color(0xFFE5737A),
    onAccent: Color(0xFF0A1128),
  );

  /// پس‌زمینهٔ روشن، متن تیره؛ رنگ‌های تأکید کمی تیره‌تر تا روی زمینهٔ روشن خوانا بمانند
  static const light = C(
    bg: Color(0xFFF4F6FB),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFE6EBF6),
    text: Color(0xFF16203D),
    muted: Color(0xFF5B6585),
    gold: Color(0xFFA8760A),
    green: Color(0xFF1F8A5B),
    red: Color(0xFFC4424B),
    onAccent: Color(0xFFFFFFFF),
  );

  static C of(Brightness b) => b == Brightness.dark ? dark : light;
}

extension AppColorsContext on BuildContext {
  /// پالت رنگ هماهنگ با تم فعلی
  C get colors => C.of(Theme.of(this).brightness);
}

/// نام خانوادهٔ فونت برنامه (فایل‌ها با tool/get_font.sh دریافت و در pubspec ثبت می‌شوند).
const String appFontFamily = 'Vazirmatn';

ThemeData buildTheme(Brightness brightness) {
  final p = C.of(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.gold,
    brightness: brightness,
    primary: p.gold,
    onPrimary: p.onAccent,
    secondary: p.green,
    onSecondary: p.onAccent,
    error: p.red,
    surface: p.card,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    outline: p.muted,
    outlineVariant: p.card2,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.card,
    surfaceContainer: p.card,
    surfaceContainerHigh: p.card,
    surfaceContainerHighest: p.card2,
    secondaryContainer: Color.alphaBlend(p.gold.withOpacity(0.22), p.card),
    onSecondaryContainer: p.text,
  );
  final base = ThemeData(brightness: brightness, useMaterial3: true, colorScheme: scheme);
  final textTheme = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    fontFamily: appFontFamily, // اگر فایل فونت در پروژه نباشد، فونت سیستم جایگزین می‌شود
    scaffoldBackgroundColor: p.bg,
    dividerColor: p.card2,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: p.text,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.gold.withOpacity(0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(fontFamily: appFontFamily, fontSize: 11, color: states.contains(WidgetState.selected) ? p.text : p.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? p.gold : p.muted),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card2,
      hintStyle: TextStyle(fontFamily: appFontFamily, color: p.muted),
      labelStyle: TextStyle(fontFamily: appFontFamily, color: p.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.gold,
        foregroundColor: p.onAccent,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(fontFamily: appFontFamily, fontSize: 14, color: p.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: appFontFamily, fontSize: 13))),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: appFontFamily))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontFamily: appFontFamily))),
    chipTheme: ChipThemeData(labelStyle: TextStyle(fontFamily: appFontFamily, fontSize: 13, color: p.text)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: p.gold, foregroundColor: p.onAccent),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.card2,
      contentTextStyle: TextStyle(fontFamily: appFontFamily, color: p.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
