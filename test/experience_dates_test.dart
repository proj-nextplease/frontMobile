import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/core/experience_dates.dart';

void main() {
  String fmt(DateTime d) => ExperienceDates.format(d);

  test('đọc đủ ngày, loại ngày không có thật', () {
    expect(ExperienceDates.parseFull('15/09/2024'), DateTime(2024, 9, 15));
    expect(ExperienceDates.parseFull('31/02/2024'), isNull);
    expect(ExperienceDates.parseFull('09/2024'), isNull);
  });

  test('giá trị cũ mm/yyyy chỉ hợp lệ khi chưa bị sửa', () {
    expect(ExperienceDates.validate(start: '06/2026', end: '08/2026'),
        isNotNull);
    expect(
        ExperienceDates.validate(
            start: '06/2026',
            end: '08/2026',
            allowLegacyStart: true,
            allowLegacyEnd: true),
        isNull);
  });

  test('chặn tương lai và kết thúc trước bắt đầu', () {
    final now = DateTime.now();
    expect(ExperienceDates.validate(start: fmt(now), end: ''), isNull);
    expect(
        ExperienceDates.validate(
            start: fmt(now.add(const Duration(days: 1))), end: ''),
        contains('sau hôm nay'));
    expect(ExperienceDates.validate(start: '20/08/2026', end: '15/06/2026'),
        contains('trước ngày bắt đầu'));
    // Một bên chỉ có tháng: so theo tháng.
    expect(
        ExperienceDates.validate(
            start: '06/2026', end: '10/06/2026', allowLegacyStart: true),
        isNull);
  });

  test('ô ngày tự chèn dấu /', () {
    final f = DateMaskFormatter();
    TextEditingValue run(String s) =>
        f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s));
    expect(run('15092024').text, '15/09/2024');
    expect(run('1509').text, '15/09');
    expect(run('150920241').text, '15/09/2024');
  });
}
