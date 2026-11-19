import 'package:flutter/services.dart';

/// Ngày bắt đầu / kết thúc của kinh nghiệm: người dùng nhập dd/mm/yyyy —
/// cùng quy tắc với web (`FE/src/lib/experienceDates.js`).
///
/// Bản ghi cũ chỉ có tháng/năm; backend trả về dạng mm/yyyy và vẫn nhận lại y
/// nguyên. Nên giá trị cũ CHƯA bị sửa vẫn hợp lệ, ô đã gõ lại thì phải đủ ngày.
class ExperienceDates {
  ExperienceDates._();

  static const placeholder = 'dd/mm/yyyy';

  static final _full = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
  static final _legacy = RegExp(r'^(0[1-9]|1[0-2])/(\d{2}|\d{4})$');

  /// "15/09/2024" → DateTime, hoặc null nếu sai / không có thật (31/02).
  static DateTime? parseFull(String value) {
    final m = _full.firstMatch(value.trim());
    if (m == null) return null;
    final d = int.parse(m[1]!), mo = int.parse(m[2]!), y = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) return null;
    return date;
  }

  static bool isLegacyMonth(String value) => _legacy.hasMatch(value.trim());

  /// DateTime → "15/09/2024".
  static String format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year.toString().padLeft(4, '0')}';

  /// Khoá so sánh: đủ ngày → yyyymmdd; chỉ tháng → yyyymm00.
  static ({int key, bool hasDay})? _keyOf(String value) {
    final full = parseFull(value);
    if (full != null) {
      return (
        key: full.year * 10000 + full.month * 100 + full.day,
        hasDay: true,
      );
    }
    final m = _legacy.firstMatch(value.trim());
    if (m == null) return null;
    final y = m[2]!.length == 2 ? 2000 + int.parse(m[2]!) : int.parse(m[2]!);
    return (key: y * 10000 + int.parse(m[1]!) * 100, hasDay: false);
  }

  /// Lỗi của cặp ngày, hoặc null nếu ổn. Ô trống được phép (kết thúc trống =
  /// đang làm).
  static String? validate({
    required String start,
    required String end,
    bool allowLegacyStart = false,
    bool allowLegacyEnd = false,
  }) {
    final now = DateTime.now();
    final today = now.year * 10000 + now.month * 100 + now.day;

    String? check(String v, bool allowLegacy, String label) {
      if (v.trim().isEmpty) return null;
      final k = _keyOf(v);
      if (k == null || (!k.hasDay && !allowLegacy)) {
        return '$label chưa đúng dạng dd/mm/yyyy';
      }
      final future = k.hasDay ? k.key > today : k.key ~/ 100 > today ~/ 100;
      if (future) return '$label không được sau hôm nay';
      return null;
    }

    final s = check(start, allowLegacyStart, 'Ngày bắt đầu');
    if (s != null) return s;
    final e = check(end, allowLegacyEnd, 'Ngày kết thúc');
    if (e != null) return e;
    if (start.trim().isNotEmpty && end.trim().isNotEmpty) {
      final a = _keyOf(start)!, b = _keyOf(end)!;
      final before = a.hasDay && b.hasDay
          ? b.key < a.key
          : b.key ~/ 100 < a.key ~/ 100;
      if (before) return 'Ngày kết thúc đang trước ngày bắt đầu';
    }
    return null;
  }
}

/// Tự chèn "/" khi gõ: 15092024 → 15/09/2024.
class DateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(digits[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
