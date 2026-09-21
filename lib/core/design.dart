import 'package:flutter/material.dart';

/// Bảng màu, có hai biến thể sáng/tối.
///
/// Dựng bằng ThemeExtension thay vì hằng số tĩnh: hằng số tĩnh không đổi được
/// theo chế độ máy, mà app này cần thích ứng. Widget lấy màu qua `Np.of(context)`.
///
/// Một ràng buộc thật của bảng màu này: **lime trên nền sáng gần như không đọc
/// được**. Nên có hai token riêng —
///   `acid`     : dùng làm NỀN (nút, chip đang chọn). Sáng hay tối đều dùng
///                được vì chữ đặt lên nó luôn là màu mực.
///   `acidText` : dùng làm MÀU CHỮ. Ở chế độ tối thì vẫn là lime; ở chế độ
///                sáng phải đậm hẳn xuống, nếu không chữ chìm vào nền trắng.
/// Lẫn hai cái này là lỗi hay gặp nhất khi chuyển một bảng màu tối sang sáng.
@immutable
class NpColors extends ThemeExtension<NpColors> {
  const NpColors({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.acid,
    required this.acidText,
    required this.onAcid,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHi;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color line;

  /// Nền của nút/chip nhấn.
  final Color acid;

  /// Màu CHỮ nhấn. Khác `acid` ở chế độ sáng.
  final Color acidText;

  /// Chữ đặt trên nền `acid`. Luôn là màu mực đậm — không bao giờ trắng, vì
  /// lime quá sáng.
  final Color onAcid;

  final Color danger;

  /// Chế độ tối. Xám TRUNG TÍNH, không ngả xanh — nền ngả xanh là mặc định của
  /// mọi bộ giao diện tối và nó làm màu nhấn ấm bị xỉn.
  static const dark = NpColors(
    bg: Color(0xFF0B0B0D),
    surface: Color(0xFF151518),
    surfaceHi: Color(0xFF1E1E23),
    ink: Color(0xFFFAFAFA),
    muted: Color(0xFF86868E),
    faint: Color(0xFF5A5A62),
    line: Color(0x14FFFFFF),
    acid: Color(0xFFC8FF4D),
    acidText: Color(0xFFC8FF4D),
    onAcid: Color(0xFF0B0B0D),
    danger: Color(0xFFFF6B6B),
  );

  /// Chế độ sáng. Nền trắng ngà rất nhẹ chứ không trắng tinh: trắng tinh cạnh
  /// thẻ trắng thì không phân biệt được lớp nào với lớp nào.
  static const light = NpColors(
    bg: Color(0xFFFBFBFA),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFF4F4F2),
    ink: Color(0xFF14141A),
    muted: Color(0xFF6E6E7A),
    faint: Color(0xFF9B9BA6),
    line: Color(0x14000000),
    acid: Color(0xFFC8FF4D),
    // Lime nguyên bản trên nền trắng có độ tương phản khoảng 1.3:1 — dưới xa
    // ngưỡng đọc được. Phiên bản đậm này đạt ~4.6:1.
    acidText: Color(0xFF4E7A00),
    onAcid: Color(0xFF14141A),
    danger: Color(0xFFD92D20),
  );

  static NpColors of(BuildContext context) =>
      Theme.of(context).extension<NpColors>()!;

  @override
  NpColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHi,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? line,
    Color? acid,
    Color? acidText,
    Color? onAcid,
    Color? danger,
  }) =>
      NpColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceHi: surfaceHi ?? this.surfaceHi,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        faint: faint ?? this.faint,
        line: line ?? this.line,
        acid: acid ?? this.acid,
        acidText: acidText ?? this.acidText,
        onAcid: onAcid ?? this.onAcid,
        danger: danger ?? this.danger,
      );

  @override
  NpColors lerp(covariant NpColors? other, double t) {
    if (other == null) return this;
    return NpColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHi: Color.lerp(surfaceHi, other.surfaceHi, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      line: Color.lerp(line, other.line, t)!,
      acid: Color.lerp(acid, other.acid, t)!,
      acidText: Color.lerp(acidText, other.acidText, t)!,
      onAcid: Color.lerp(onAcid, other.onAcid, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Hình học và nhịp khoảng cách. Không phụ thuộc chế độ sáng/tối nên vẫn tĩnh.
abstract final class Np {
  static NpColors of(BuildContext context) => NpColors.of(context);

  // ── Bo góc ─────────────────────────────────────────────────────────────
  static const rSm = 10.0;
  static const rMd = 16.0;
  static const rLg = 22.0;
  static const rPill = 999.0;

  // ── Nhịp khoảng cách ───────────────────────────────────────────────────
  // Bội số của 4. Dùng thang cố định thay vì con số tuỳ hứng là cách rẻ nhất
  // để cả app trông có kỷ luật.
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;

  static const gutter = s5;

  /// Chỗ phải chừa dưới đáy mọi danh sách cuộn.
  ///
  /// Thanh điều hướng NỔI và đè lên nội dung (extendBody), nên nếu không chừa
  /// thì mục cuối cùng của mọi danh sách bị nó che. 66 là chiều cao thanh,
  /// cộng lề và một khoảng thở.
  static const navInset = 72.0 + s2 + s5;

  /// Quầng sáng dưới nút nhấn — ánh sáng màu hắt xuống, không phải bóng đen.
  /// Ở chế độ sáng thì nhạt hơn, vì trên nền trắng quầng đậm trông như vết bẩn.
  static List<BoxShadow> glow(NpColors c, {required bool isDark}) => [
        BoxShadow(
          color: c.acid.withValues(alpha: isDark ? 0.22 : 0.40),
          blurRadius: isDark ? 26 : 18,
          offset: const Offset(0, 8),
        ),
      ];

  static BoxDecoration card(NpColors c,
          {double radius = rLg, bool hi = false}) =>
      BoxDecoration(
        color: hi ? c.surfaceHi : c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line),
      );
}

/// ─── Thang chữ ──────────────────────────────────────────────────────────
///
/// KHÔNG mang màu. Màu do nơi dùng gán, vì cùng một kiểu chữ phải chạy được ở
/// cả hai chế độ sáng/tối.
///
/// Archivo chỉ cho tiêu đề lớn; mọi chữ còn lại là Be Vietnam Pro. Trộn hai
/// font là có chủ ý: tiêu đề cần tính cách, chữ đọc cần dễ đọc, và một font
/// hiếm khi giỏi cả hai.
abstract final class NpType {
  /// Archivo là font BIẾN THIÊN với trục chiều rộng (wdth). Nén về 88 cho
  /// tiêu đề khổng lồ vẫn vừa một dòng mà không phải giảm cỡ chữ — giảm cỡ là
  /// cách làm mất luôn độ tương phản vừa dựng lên.
  static const _archivo = [
    FontVariation('wght', 800),
    FontVariation('wdth', 88),
  ];

  /// line-height 1.0 — với chữ hoa tiếng Việt thì 0.95 là SÀN tuyệt đối, dưới
  /// mức đó dấu Ẫ/Ộ/Ế bị cắt ngọn.
  static const display = TextStyle(
    fontFamily: 'Archivo',
    fontVariations: _archivo,
    fontSize: 40,
    height: 1.0,
    letterSpacing: -1.4,
  );

  static const h1 = TextStyle(
    fontFamily: 'Archivo',
    fontVariations: _archivo,
    fontSize: 28,
    height: 1.08,
    letterSpacing: -0.9,
  );

  static const title = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16.5,
    fontWeight: FontWeight.w600,
    height: 1.32,
    letterSpacing: -0.3,
  );

  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.1,
  );

  static const meta = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.05,
  );

  /// Nhãn nhỏ viết hoa. Giãn chữ dương vì chữ hoa ở cỡ nhỏ dính vào nhau.
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.9,
  );

  static const button = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.2,
  );
}
