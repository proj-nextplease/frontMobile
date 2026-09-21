import 'package:flutter/material.dart';

import 'design.dart';

export 'design.dart';
export 'widgets.dart';

ThemeData buildNpTheme() {
  const base = TextStyle(color: Np.ink, height: 1.4, letterSpacing: -0.2);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Np.bg,
    colorScheme: const ColorScheme.dark(
      primary: Np.violet,
      onPrimary: Colors.white,
      secondary: Np.pink,
      surface: Np.surface,
      onSurface: Np.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Np.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Np.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      titleLarge: base.copyWith(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
      titleMedium: base.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700, height: 1.3),
      bodyMedium: base.copyWith(fontSize: 15.5),
      bodySmall: base.copyWith(fontSize: 13.5, color: Np.muted, height: 1.4),
      labelLarge: base.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1),
    ),
    dividerTheme: const DividerThemeData(color: Np.line, thickness: 1, space: 1),
  );
}
