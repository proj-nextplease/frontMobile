import 'package:flutter/material.dart';

/// Hệ thiết kế app di động nextplease — TỐI, gradient phát sáng.
///
/// Lịch sử ba bản trước, ghi lại để không quay vòng:
///   1. Tối emerald  — đúng chuẩn web nhưng khô khan.
///   2. Giấy/sticker — bị chê quá nhiều màu và viền đen thô.
///   3. Gradient nền sáng — vẫn chưa đẹp. Giả thuyết: gradient đúng hướng,
///      nhưng đặt trên nền gần-trắng thì nó trông rẻ, vì nền sáng làm màu bị
///      "dẹt" — không có gì để nó phát sáng lên.
///
/// Bản này giữ nguyên dải gradient nhưng đổi sang nền tối. Trên nền tối, cùng
/// một màu sẽ đọc ra là PHÁT SÁNG thay vì chỉ là một mảng màu, và bóng đổ
/// nhuộm màu trở nên có nghĩa thật sự.
///
/// Kỷ luật màu giữ nguyên từ bản trước, vì đó không phải chỗ sai:
///   - MỘT họ gradient làm điểm nhấn, còn lại trung tính.
///   - Màu thứ hai (mint) dành riêng cho phần thưởng EXP.
///   - Không viền đen. Ranh giới là đường sáng mờ 1px, kiểu mép kính.
abstract final class Np {
  // ── Nền, bề mặt, chữ ───────────────────────────────────────────────────
  static const bg = Color(0xFF0A0A0F);        // gần đen, ngả xanh rất nhẹ
  static const surface = Color(0xFF15151E);   // thẻ
  static const surfaceHi = Color(0xFF1C1C28); // thẻ nổi hơn một bậc
  static const ink = Color(0xFFF2F2F7);       // chữ chính
  static const muted = Color(0xFF8E8EA3);     // chữ phụ

  /// Ranh giới trên nền tối phải là đường SÁNG mờ, không phải đường tối — nó
  /// bắt chước mép bắt sáng của một tấm kính, nên đọc ra là vật thể chứ không
  /// phải nét vẽ.
  static const line = Color(0x14FFFFFF);      // trắng 8%

  // ── Một họ gradient duy nhất ───────────────────────────────────────────
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);

  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, pink],
  );

  /// Màu thứ hai, CHỈ cho phần thưởng EXP/quest.
  static const mint = Color(0xFF2DD4A7);

  // ── Bo góc ─────────────────────────────────────────────────────────────
  static const rSm = 12.0;
  static const rMd = 18.0;
  static const rLg = 24.0;
  static const rPill = 999.0;

  // ── Khoảng cách ────────────────────────────────────────────────────────
  static const gutter = 20.0;
  static const cardPad = 18.0;

  /// Thẻ trên nền tối KHÔNG cần bóng — bóng đen trên nền đen là vô hình.
  /// Cái tạo ra chiều sâu ở đây là bề mặt sáng hơn nền, cộng một đường viền
  /// sáng mờ. Đó là lý do bản này bỏ hẳn boxShadow cho thẻ.
  static BoxDecoration card({double radius = rLg, bool elevated = false}) =>
      BoxDecoration(
        color: elevated ? surfaceHi : surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
      );

  /// Bóng cho nút gradient: đây mới là chỗ bóng có tác dụng trên nền tối, vì
  /// nó là ÁNH SÁNG màu hắt xuống chứ không phải bóng đen.
  static List<BoxShadow> get glow => [
        BoxShadow(
          color: violet.withValues(alpha: 0.45),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];

  /// Nền nhạt cùng tông cho chip.
  static BoxDecoration softChip(Color tone) => BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(rPill),
      );
}

/// Chữ hoa tiếng Việt cần line-height ≥ 0.95, nếu không dấu Ẫ/Ộ/Ế bị cắt ngọn.
/// Con số này là SÀN, không phải lựa chọn thẩm mỹ.
const double kViUppercaseLineHeight = 0.95;
