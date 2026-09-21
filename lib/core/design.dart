import 'package:flutter/material.dart';

/// Hệ thiết kế app di động nextplease.
///
/// ─── Vì sao bản này khác bốn bản trước ────────────────────────────────────
///
/// Bốn lần trước đều bị chê chưa đẹp, và nhìn lại thì cả bốn có CHUNG một bộ
/// khung — chỉ khác lớp sơn. Sai lầm nằm ở chỗ đó: cái quyết định một app
/// trông cao cấp hay rẻ tiền hiếm khi là bảng màu.
///
/// Hai thứ thật sự quyết định, và cả bốn bản trước đều thiếu:
///
///   1. CHỮ. Cả bốn bản dùng font mặc định của hệ thống, nên trông y như một
///      app Flutter mẫu bất kể sơn màu gì. Bản này nhúng font thật và dựng
///      một thang chữ có ĐỘ TƯƠNG PHẢN LỚN — tiêu đề 40px cạnh nhãn 11px.
///      Tương phản cỡ chữ là thứ tạo ra nhịp, và nhịp là thứ mắt đọc ra là
///      "có chủ ý".
///
///   2. MỘT màu nhấn, phẳng, bão hoà cao. Bỏ hẳn gradient tím→hồng: đó là
///      gradient bị dùng nhiều nhất thập kỷ qua, nên nó đọc ra là "mẫu có
///      sẵn" chứ không phải một quyết định. Một màu duy nhất, dùng đúng chỗ,
///      luôn tự tin hơn hai màu chuyển sắc.
abstract final class Np {
  // ── Nền và bề mặt ──────────────────────────────────────────────────────
  // Xám trung tính, KHÔNG ngả xanh. Nền ngả xanh là mặc định của mọi bộ giao
  // diện tối, và nó làm màu nhấn ấm bị xỉn.
  static const bg = Color(0xFF0B0B0D);
  static const surface = Color(0xFF151518);
  static const surfaceHi = Color(0xFF1E1E23);

  // ── Chữ ────────────────────────────────────────────────────────────────
  static const ink = Color(0xFFFAFAFA);
  static const muted = Color(0xFF86868E);
  static const faint = Color(0xFF5A5A62);

  /// Ranh giới là đường SÁNG mờ, bắt chước mép bắt sáng của vật thể.
  static const line = Color(0x14FFFFFF);

  // ── Một màu nhấn duy nhất ──────────────────────────────────────────────
  /// Lime điện. Nối được với emerald của thương hiệu web nhưng trẻ hơn hẳn,
  /// và trên nền gần-đen thì nó tự phát sáng mà không cần hiệu ứng nào.
  static const acid = Color(0xFFC8FF4D);

  /// Chữ đặt TRÊN nền acid. Không bao giờ dùng trắng — lime quá sáng, chữ
  /// trắng trên đó gần như không đọc được.
  static const onAcid = Color(0xFF0B0B0D);

  /// Màu cảnh báo. Không tính là màu nhấn thứ hai vì nó chỉ xuất hiện khi có
  /// lỗi, và không bao giờ đứng cạnh acid.
  static const danger = Color(0xFFFF6B6B);

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

  /// Quầng sáng dưới nút nhấn — ánh sáng màu hắt xuống, không phải bóng đen.
  static List<BoxShadow> get acidGlow => [
        BoxShadow(
          color: acid.withValues(alpha: 0.22),
          blurRadius: 26,
          offset: const Offset(0, 8),
        ),
      ];

  static BoxDecoration card({double radius = rLg, bool hi = false}) =>
      BoxDecoration(
        color: hi ? surfaceHi : surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
      );
}

/// ─── Thang chữ ──────────────────────────────────────────────────────────
///
/// Archivo chỉ dùng cho tiêu đề lớn; mọi chữ còn lại là Be Vietnam Pro.
/// Trộn hai font là có chủ ý: tiêu đề cần tính cách, chữ đọc cần dễ đọc, và
/// một font hiếm khi giỏi cả hai.
abstract final class NpType {
  /// Archivo là font BIẾN THIÊN với trục chiều rộng (wdth). Nén về 88 cho
  /// tiêu đề khổng lồ vẫn vừa một dòng mà không phải giảm cỡ chữ — giảm cỡ
  /// là cách làm mất luôn độ tương phản vừa dựng lên.
  static const _archivoCompressed = [
    FontVariation('wght', 800),
    FontVariation('wdth', 88),
  ];

  /// Tiêu đề khổng lồ. line-height 0.98 — với chữ hoa tiếng Việt thì 0.95 là
  /// SÀN tuyệt đối, dưới mức đó dấu Ẫ/Ộ/Ế bị cắt ngọn.
  static const display = TextStyle(
    fontFamily: 'Archivo',
    fontVariations: _archivoCompressed,
    fontSize: 40,
    height: 1.0,
    letterSpacing: -1.4,
    color: Np.ink,
  );

  static const h1 = TextStyle(
    fontFamily: 'Archivo',
    fontVariations: _archivoCompressed,
    fontSize: 28,
    height: 1.08,
    letterSpacing: -0.9,
    color: Np.ink,
  );

  static const title = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16.5,
    fontWeight: FontWeight.w600,
    height: 1.32,
    letterSpacing: -0.3,
    color: Np.ink,
  );

  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.1,
    color: Np.ink,
  );

  static const meta = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.05,
    color: Np.muted,
  );

  /// Nhãn nhỏ viết hoa. Giãn chữ dương vì chữ hoa ở cỡ nhỏ dính vào nhau.
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.9,
    color: Np.muted,
  );

  static const button = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.2,
  );
}
