import 'package:flutter/material.dart';

/// Hệ thiết kế của app di động nextplease — "gradient sống động".
///
/// Hai lỗi của bản giấy/sticker trước phải tránh bằng mọi giá:
///
///   1. QUÁ NHIỀU MÀU CÙNG LÚC. Lime, violet, coral xuất hiện chung một màn
///      hình khiến mắt không biết nhìn đâu. Ở đây chỉ có MỘT họ gradient làm
///      điểm nhấn; mọi thứ còn lại là trung tính. Màu thứ hai (mint) được giữ
///      cho đúng một nghĩa — phần thưởng EXP — và không dùng vào việc gì khác.
///
///   2. VIỀN ĐEN DÀY. Thay hoàn toàn bằng bóng màu mềm: bóng nhuộm sắc tím
///      nhạt thay vì bóng đen, nên nó tạo chiều sâu mà không vẽ đường kẻ.
///      Chỗ nào thật sự cần ranh giới thì dùng đường 1px màu #EDEDF2 — đủ để
///      mắt thấy, không đủ để thành nét vẽ.
abstract final class Np {
  // ── Nền và chữ ─────────────────────────────────────────────────────────
  static const bg = Color(0xFFF7F7FB);      // nền hơi ngả lạnh, không trắng tinh
  static const surface = Color(0xFFFFFFFF); // thẻ
  static const ink = Color(0xFF14141C);     // chữ chính
  static const muted = Color(0xFF6E6E80);   // chữ phụ
  static const line = Color(0xFFEDEDF2);    // đường chia, chỉ khi buộc phải có

  // ── Một họ gradient duy nhất ───────────────────────────────────────────
  static const violet = Color(0xFF7A5CFF);
  static const pink = Color(0xFFD65DB1);

  /// Gradient thương hiệu. Dùng cho nút chính, nhãn đang chọn, và các mảng
  /// lớn — KHÔNG rải lên từng chi tiết nhỏ, vì rải ra là quay lại lỗi cũ.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, pink],
  );

  /// Màu thứ hai, dành riêng cho phần thưởng EXP/quest. Không dùng vào việc
  /// khác — một màu mà mang hai nghĩa thì nó không còn nghĩa nào.
  static const mint = Color(0xFF00B894);

  // ── Bo góc ─────────────────────────────────────────────────────────────
  static const rSm = 12.0;
  static const rMd = 18.0;
  static const rLg = 26.0;   // thẻ, nút lớn
  static const rPill = 999.0;

  // ── Khoảng cách ────────────────────────────────────────────────────────
  static const gutter = 20.0;
  static const cardPad = 18.0;

  /// Bóng của thẻ. Mềm, lệch xuống, và NHUỘM SẮC TÍM thay vì đen — bóng đen
  /// trên nền sáng luôn trông bẩn, còn bóng nhuộm theo màu thương hiệu thì
  /// hoà vào nền.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: violet.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: ink.withValues(alpha: 0.03),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  /// Bóng của nút gradient: đậm hơn và cùng tông với chính nút, tạo cảm giác
  /// nút đang phát sáng xuống nền.
  static List<BoxShadow> get brandShadow => [
        BoxShadow(
          color: violet.withValues(alpha: 0.32),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

  static BoxDecoration card({double radius = rLg}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: cardShadow,
      );

  /// Nền nhạt cùng tông cho chip. Độ đục thấp nên nhiều chip cạnh nhau vẫn
  /// đọc ra là một nhóm, không phải một dãy nút đủ màu.
  static BoxDecoration softChip(Color tone) => BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(rPill),
      );
}

/// Chữ hoa tiếng Việt cần line-height ≥ 0.95, nếu không dấu Ẫ/Ộ/Ế bị cắt ngọn.
/// Con số này là SÀN, không phải lựa chọn thẩm mỹ.
const double kViUppercaseLineHeight = 0.95;
