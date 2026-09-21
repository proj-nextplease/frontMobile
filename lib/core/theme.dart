import 'package:flutter/material.dart';

/// Design token của nextplease, chép từ DESIGN.md ở gốc dự án.
///
/// Giữ đúng tên token như bên web để khi đối chiếu hai bên không phải dịch
/// qua lại. Quy tắc quan trọng nhất trong DESIGN.md: MỘT trang chỉ có MỘT màu
/// nhấn — emerald. Không thêm vàng/cam/tím làm accent phụ.
abstract final class NpColors {
  static const ink = Color(0xFF0B0F0E);        // nền tối chủ đạo
  static const inkSoft = Color(0xFF121817);    // thẻ nổi trên ink
  static const emerald = Color(0xFF10B981);    // màu nhấn DUY NHẤT
  static const emeraldHover = Color(0xFF34D399);
  static const onDark = Color(0xFFFFFFFF);
  static const mutedDark = Color(0x9EE9F7F2);  // rgba(233,247,242,0.62)
  static const lineDark = Color(0x1FFFFFFF);   // rgba(255,255,255,0.12)
}

abstract final class NpRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;   // thẻ việc làm
  static const pill = 9999.0;
}

abstract final class NpSpace {
  static const cardPad = 22.0;
  static const gridGap = 24.0;
  static const gutter = 20.0;  // lề ngang của nội dung
}

/// DESIGN.md quy định Be Vietnam Pro cho toàn bộ chữ thân bài và Archivo cho
/// display. Bản này chưa nhúng font — dùng font hệ thống trước để chạy được,
/// phần nhúng làm ở bước sau khi đã có màn hình thật để nhìn.
ThemeData buildNpTheme() {
  const base = TextStyle(color: NpColors.onDark, height: 1.4, letterSpacing: -0.015);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: NpColors.ink,
    colorScheme: const ColorScheme.dark(
      primary: NpColors.emerald,
      onPrimary: NpColors.ink,     // chữ trên nền emerald là ink, không phải trắng
      surface: NpColors.inkSoft,
      onSurface: NpColors.onDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NpColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      titleMedium: base.copyWith(fontSize: 16.3, fontWeight: FontWeight.w700, height: 1.35),
      bodyMedium: base.copyWith(fontSize: 16),
      bodySmall: base.copyWith(fontSize: 13.6, color: NpColors.mutedDark, height: 1.5),
      labelLarge: base.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1),
    ),
    dividerTheme: const DividerThemeData(color: NpColors.lineDark, thickness: 1, space: 1),
  );
}
