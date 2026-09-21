import 'package:flutter/material.dart';

/// Hệ GIẤY/STICKER — chép từ mục cùng tên trong DESIGN.md.
///
/// Đây là ngôn ngữ thị giác thứ hai của nextplease, đã dùng cho trang portfolio
/// công khai và trình dựng. Không bịa ra kiểu thứ ba: app mobile mượn đúng hệ
/// này cho các màn hình "mặt tiền" (mở app, đăng nhập), còn màn hình công cụ
/// (danh sách, chi tiết) vẫn giữ hệ tối.
///
/// Ba đặc điểm làm nên nó, thiếu một cái là mất chất:
///   1. Viền đen 2px, đặc, không phải hairline mờ.
///   2. BÓNG ĐỔ CỨNG — offset thuần, blur = 0. Bóng mờ là ngôn ngữ của
///      Material; bóng cứng là ngôn ngữ của sticker dán trên giấy.
///   3. Nền giấy ấm, không phải trắng tinh.
abstract final class Paper {
  static const bg = Color(0xFFFBF7EF);      // giấy ấm
  static const ink = Color(0xFF16150F);     // mực, gần đen nhưng ngả nâu
  static const lime = Color(0xFFC9F24B);
  static const violet = Color(0xFF6C4BF2);
  static const coral = Color(0xFFFF6B4A);
  static const emerald = Color(0xFF10B981); // CHỈ dùng cho dấu đã xác thực

  static const border = 2.0;

  /// Bóng cứng: không blur, không spread. Đây là chi tiết dễ làm sai nhất —
  /// thêm blur vào là thành bóng Material và mất hẳn chất sticker.
  static List<BoxShadow> hardShadow({double dx = 4, double dy = 4}) => [
        BoxShadow(color: ink, offset: Offset(dx, dy), blurRadius: 0, spreadRadius: 0),
      ];

  static BoxDecoration card({
    Color? fill,
    double radius = 20,
    double dx = 4,
    double dy = 4,
  }) =>
      BoxDecoration(
        color: fill ?? bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ink, width: border),
        boxShadow: hardShadow(dx: dx, dy: dy),
      );

  /// Ô nhập: viền mảnh hơn thẻ (1.5 vs 2) và bo nhỏ hơn (12 vs 20+), để nó đọc
  /// ra là "chỗ gõ chữ" chứ không phải "một tấm thẻ nữa". Bóng cứng CHỈ xuất
  /// hiện ở ô đang gõ.
  static BoxDecoration field({required bool focused}) => BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink, width: focused ? 2 : 1.5),
        boxShadow: focused ? hardShadow(dx: 3, dy: 3) : null,
      );
}

/// Chữ hoa tiếng Việt cần line-height ≥ 0.95, nếu không dấu Ẫ/Ộ/Ế bị cắt ngọn.
/// Con số này là SÀN, không phải lựa chọn thẩm mỹ.
const double kViUppercaseLineHeight = 0.95;
