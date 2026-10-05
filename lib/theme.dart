import 'package:flutter/material.dart';

/// Electric-night palette from the design.
abstract final class AG {
  static const bg = Color(0xFF0E0E10);
  static const surface = Color(0xFF1C1C21);
  static const surfaceHi = Color(0xFF2E2E35);
  static const dim = Color(0xFF45454D);
  static const muted = Color(0xFF9A9AA3);
  static const ink = Color(0xFFF5F5F2);
  static const lime = Color(0xFFD4FF3A);
  static const pink = Color(0xFFFF4FD8);
  static const plum = Color(0xFF3A1534);
  static const plumInk = Color(0xFFFFC9F3);

  /// Lime blended into the background, like the design's `color-mix(lime N%, bg)`.
  static Color limeTint(double t) => Color.lerp(bg, lime, t)!;

  static const display = 'Caprasimo';

  static TextStyle d(double size, {Color? color, double? height}) =>
      TextStyle(fontFamily: display, fontSize: size, color: color, height: height);

  static TextStyle t(double size, {Color? color, FontWeight? weight, double? height}) =>
      TextStyle(fontSize: size, color: color, fontWeight: weight, height: height);

  /// Small all-caps section label ("ALSO SCHEDULED", "REPEAT"...).
  static const label = TextStyle(
    fontSize: 11,
    letterSpacing: 1.3,
    color: muted,
    fontWeight: FontWeight.w700,
  );

  static ThemeData theme() {
    final base = ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Figtree',
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: lime,
        secondary: pink,
        surface: bg,
        onPrimary: bg,
        onSurface: ink,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    );
  }
}
