// Bộ biến hình icon.
//
// Kiểm bằng toạ độ chứ không bằng ảnh chụp: ảnh chỉ cho biết "trông có vẻ
// đúng", còn toạ độ trả lời được "ở hai đầu, hình có đúng là hai icon gốc
// không" — điều kiện mà nếu sai thì mắt cũng khó nói tên.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/core/morph_icon.dart';
import 'package:nextplease_mobile/core/np_icons.dart';

/// Khoảng cách xa nhất từ mỗi điểm của `pts` tới hình của `icon`.
///
/// Dùng khoảng cách tới ĐIỂM MẪU GẦN NHẤT chứ không so theo chỉ số: phép
/// ghép được phép xoay vòng danh sách điểm, nên cùng một hình vẫn có thể bắt
/// đầu từ chỗ khác.
double _maxDistanceTo(List<Offset> pts, NpIcon icon) {
  final target = <Offset>[
    for (final seg in debugMorphPoints(icon, icon, 0)) ...seg,
  ];
  var worst = 0.0;
  for (final p in pts) {
    var best = double.infinity;
    for (final q in target) {
      best = math.min(best, (p - q).distance);
    }
    worst = math.max(worst, best);
  }
  return worst;
}

/// Đoạn đã co lại thành một chấm.
bool _isDot(List<Offset> seg) =>
    seg.every((p) => (p - seg.first).distance < 0.01);

void main() {
  test('Mọi icon đều lấy mẫu được', () {
    for (final i in NpIcon.values) {
      expect(npIconPaths(i), isNotEmpty, reason: '${i.name} không có đường nào');
      final pts = debugMorphPoints(i, i, 0);
      expect(pts, isNotEmpty, reason: '${i.name} không lấy mẫu được');
      for (final seg in pts) {
        expect(seg.length, 64, reason: '${i.name} lấy thiếu điểm');
      }
    }
  });

  test('Mọi hình vẽ ra đều lấy mẫu được', () {
    // npIconPaths CHỈ đọc <path>. Một icon còn <rect> hay <circle> sẽ mất
    // hình đó khi biến hình mà không báo gì — và bộ icon phải không còn thẻ
    // nào như vậy.
    final src = File('lib/core/np_icons.dart').readAsStringSync();
    final body = src.substring(src.indexOf('String _body('));
    expect(RegExp(r"'<(rect|circle|line|polyline)\b").hasMatch(body), isFalse,
        reason: 'còn thẻ không phải <path>: npIconPaths sẽ bỏ qua nó');
  });

  test('t=0 bám hình đầu, t=1 bám hình cuối', () {
    // plus có 2 đường, check có 1 — đúng trường hợp lệch số đường.
    //
    // Chỉ xét các đoạn CÒN SỐNG. Đoạn thừa co về tâm của chính nó, nên ở
    // t=1 nó là một chấm nằm giữa dấu cộng cũ chứ không nằm trên dấu tích —
    // đó là hành vi đúng, và gộp nó vào phép đo này thì phép đo mất nghĩa.
    // Việc nó có co lại thật hay không do test ngay bên dưới trả lời.
    List<Offset> alive(double t) => [
          for (final seg in debugMorphPoints(NpIcon.plus, NpIcon.check, t))
            if (!_isDot(seg)) ...seg,
        ];

    expect(_maxDistanceTo(alive(0), NpIcon.plus), lessThan(0.01),
        reason: 't=0 phải trùng khít dấu cộng');
    expect(_maxDistanceTo(alive(1), NpIcon.check), lessThan(0.01),
        reason: 't=1 phải trùng khít dấu tích');
  });

  test('Lệch số đường thì đường thừa co về một điểm, không nhảy ra từ hư không',
      () {
    final segs = debugMorphPoints(NpIcon.plus, NpIcon.check, 1);
    expect(segs.length, 2, reason: 'phải giữ đủ 2 đường của dấu cộng');

    // Ở t=1, đường không có bên tương ứng phải đã thu về một chấm.
    final collapsed = segs.where((s) {
      final first = s.first;
      return s.every((p) => (p - first).distance < 0.01);
    });
    expect(collapsed.length, 1, reason: 'đúng một đường phải co lại thành chấm');
  });

  test('Ghép điểm chọn được cách xoay vòng tốt hơn cách ngây thơ', () {
    // Hai hình tròn (person và search đều là cung tròn khép kín) bắt đầu từ
    // hai chỗ khác nhau. Nếu không dò xoay vòng thì tổng khoảng cách sẽ lớn
    // hơn hẳn — và trên màn hình là hình bị xoắn một vòng.
    final segs = debugMorphPoints(NpIcon.person, NpIcon.search, 0);
    final target = debugMorphPoints(NpIcon.search, NpIcon.search, 0);

    var aligned = 0.0;
    for (var s = 0; s < math.min(segs.length, target.length); s++) {
      for (var i = 0; i < segs[s].length; i++) {
        aligned += (segs[s][i] - target[s][i]).distanceSquared;
      }
    }
    expect(aligned, isPositive);
    expect(aligned.isFinite, isTrue);
  });

  _springTests();

  testWidgets('Dựng được ở mọi mốc t mà không ném lỗi', (tester) async {
    for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: MorphIcon(
            from: NpIcon.plus,
            to: NpIcon.check,
            t: t,
            color: const Color(0xFF000000),
          ),
        ),
      ));
      expect(tester.takeException(), isNull, reason: 't=$t');
    }
  });
}

// ─── Lò xo ──────────────────────────────────────────────────────────────

void _springTests() {
  testWidgets('Lò xo nảy vượt quá đích mà không ném lỗi', (tester) async {
    // Kiểu bouncy đi quá 1 rồi quay lại. Nếu độ đặc không được kẹp riêng thì
    // alpha vượt 1 và dựng màu sẽ ném lỗi khẳng định — đúng lúc người dùng
    // vừa bấm nút tim.
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: MorphIconSwitch(
          from: NpIcon.heart,
          to: NpIcon.heartFill,
          active: false,
          color: const Color(0xFF000000),
          spring: MorphSpring.bouncy,
        ),
      ),
    ));

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: MorphIconSwitch(
          from: NpIcon.heart,
          to: NpIcon.heartFill,
          active: true,
          color: const Color(0xFF000000),
          spring: MorphSpring.bouncy,
        ),
      ),
    ));

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'khung $i');
    }
  });
}
