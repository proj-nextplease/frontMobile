import 'package:flutter/material.dart';

/// Bảng màu, có hai biến thể sáng/tối.
///
/// Dựng bằng ThemeExtension thay vì hằng số tĩnh: hằng số tĩnh không đổi được
/// theo chế độ máy, mà app này cần thích ứng. Widget lấy màu qua `Np.of(context)`.
///
/// Vì sao KHÔNG dùng lime nữa: lime nằm ở vùng hue vàng-xanh, nên hạ độ sáng
/// xuống cho đủ tương phản trên nền trắng thì nó thành màu ô-liu quân đội —
/// nhìn không ra là cùng màu với bản sáng. Xanh lá thật (hue ~150) thì đậm
/// lên vẫn đọc ra là xanh lá.
///
/// Vẫn giữ hai token riêng —
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
    required this.band,
    required this.onBand,
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

  /// Dải màu đậm ở đầu trang chủ. Luôn TỐI HƠN nền ở chế độ sáng và SÁNG HƠN
  /// nền ở chế độ tối — điều quan trọng là nó tách khỏi nền, không phải nó
  /// tối hay sáng.
  final Color band;

  /// Chữ đặt trên dải đó.
  final Color onBand;

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
    acid: Color(0xFF2EE87F),
    acidText: Color(0xFF3CEE8A),
    onAcid: Color(0xFF07160D),
    danger: Color(0xFFFF6B6B),
    band: Color(0xFF1C1C22),
    onBand: Color(0xFFFAFAFA),
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
    acid: Color(0xFF2EE87F),
    // Cùng hue với bản sáng, chỉ hạ độ sáng — nên vẫn đọc ra là một màu. Đạt
    // khoảng 4.8:1 trên nền trắng.
    acidText: Color(0xFF0B7A42),
    onAcid: Color(0xFF07160D),
    danger: Color(0xFFD92D20),
    band: Color(0xFF14141A),
    onBand: Color(0xFFFAFAFA),
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
    Color? band,
    Color? onBand,
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
        band: band ?? this.band,
        onBand: onBand ?? this.onBand,
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
      band: Color.lerp(band, other.band, t)!,
      onBand: Color.lerp(onBand, other.onBand, t)!,
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
  /// wdth 94 chứ không 88. Nén sâu làm chữ trông gắng sức; 94 vẫn gọn hơn
  /// mặc định mà không bóp các dấu tiếng Việt.
  static const _archivo = [
    FontVariation('wght', 800),
    FontVariation('wdth', 94),
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

  /// Tiêu đề cỡ vừa dùng Be Vietnam Pro, KHÔNG phải Archivo nén.
  ///
  /// Archivo ở trục wdth 88 là chữ nén — rất hiệu quả ở cỡ 38px trở lên, nơi
  /// cần dồn nhiều chữ vào một dòng. Nhưng xuống cỡ 23px thì nét dọc sít lại
  /// và các dấu tiếng Việt chen nhau, đọc ra là chật chứ không phải chắc.
  /// Trộn hai font vẫn giữ, nhưng ranh giới rõ hơn: Archivo CHỈ cho chữ
  /// khổng lồ, mọi thứ còn lại là Be Vietnam Pro.
  static const h1 = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
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
