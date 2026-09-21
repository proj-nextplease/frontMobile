import 'package:flutter/material.dart';

import 'paper_theme.dart';

export 'paper_theme.dart';

/// Theme của app — hệ GIẤY/STICKER cho toàn bộ màn hình.
///
/// Trước đây app dùng hệ tối `nextplease-dark` như web. Đổi hết sang hệ giấy
/// theo yêu cầu: app di động hướng tới sinh viên, và hệ giấy đã là ngôn ngữ
/// nextplease dùng cho các bề mặt hướng tới họ (trang portfolio công khai).
///
/// Giữ hai hệ trong cùng một app sẽ tệ hơn chọn hẳn một: người dùng đi từ
/// màn hình sáng sang màn hình tối trong cùng một luồng sẽ tưởng mình đã
/// rời khỏi app.
ThemeData buildNpTheme() {
  const base = TextStyle(color: Paper.ink, height: 1.4, letterSpacing: -0.1);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Paper.bg,
    colorScheme: const ColorScheme.light(
      primary: Paper.ink,
      onPrimary: Paper.bg,
      secondary: Paper.violet,
      surface: Paper.bg,
      onSurface: Paper.ink,
      error: Paper.coral,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Paper.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Paper.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      titleMedium: base.copyWith(fontSize: 17, fontWeight: FontWeight.w800, height: 1.25),
      bodyMedium: base.copyWith(fontSize: 15.5),
      bodySmall: base.copyWith(
        fontSize: 13.5,
        height: 1.4,
        color: Paper.ink.withValues(alpha: 0.62),
      ),
      labelLarge: base.copyWith(fontSize: 15, fontWeight: FontWeight.w800, height: 1),
    ),
    dividerTheme: const DividerThemeData(
      color: Paper.ink, thickness: 1.5, space: 1.5,
    ),
  );
}
