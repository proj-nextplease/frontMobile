import 'package:flutter/material.dart';

import 'design.dart';

export 'design.dart';
export 'widgets.dart';

/// Dựng ThemeData cho một chế độ. MaterialApp nhận cả hai rồi tự chọn theo
/// cài đặt sáng/tối của máy.
ThemeData buildNpTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? NpColors.dark : NpColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    fontFamily: 'BeVietnamPro',
    extensions: [c],
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.acid,
      onPrimary: c.onAcid,
      secondary: c.acidText,
      onSecondary: c.onAcid,
      surface: c.surface,
      onSurface: c.ink,
      error: c.danger,
      onError: dark ? const Color(0xFF14141A) : Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      displayLarge: NpType.display.copyWith(color: c.ink),
      headlineMedium: NpType.h1.copyWith(color: c.ink),
      titleMedium: NpType.title.copyWith(color: c.ink),
      bodyMedium: NpType.body.copyWith(color: c.ink),
      bodySmall: NpType.meta.copyWith(color: c.muted),
      labelSmall: NpType.label.copyWith(color: c.muted),
      labelLarge: NpType.button,
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
  );
}
