import 'package:flutter/material.dart';

import 'design.dart';

export 'design.dart';
export 'widgets.dart';

ThemeData buildNpTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Np.bg,
      fontFamily: 'BeVietnamPro',
      colorScheme: const ColorScheme.dark(
        primary: Np.acid,
        onPrimary: Np.onAcid,
        surface: Np.surface,
        onSurface: Np.ink,
        error: Np.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Np.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Np.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        displayLarge: NpType.display,
        headlineMedium: NpType.h1,
        titleMedium: NpType.title,
        bodyMedium: NpType.body,
        bodySmall: NpType.meta,
        labelSmall: NpType.label,
        labelLarge: NpType.button,
      ),
      dividerTheme: const DividerThemeData(
        color: Np.line, thickness: 1, space: 1,
      ),
      splashFactory: NoSplash.splashFactory,
    );
