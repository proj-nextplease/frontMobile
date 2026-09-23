import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

import 'np_icons.dart';

/// Biến hình giữa hai icon: icon này chảy thành icon kia thay vì mờ đi rồi
/// hiện ra.
///
/// ─── Cách làm ───────────────────────────────────────────────────────────
/// 1. Phân tích chuỗi `d` của cả hai icon thành Path của Flutter.
/// 2. Lấy mẫu mỗi đường thành N điểm cách đều THEO CHIỀU DÀI CUNG
///    (PathMetric), chứ không theo tham số — lấy theo tham số thì điểm dồn
///    ở các đoạn cong và hình bị co giật lúc chạy.
/// 3. Ghép các đường của hai icon theo thứ tự; bên nào thừa đường thì đường
///    đó co về tâm của chính nó, tức là thu lại thành một chấm rồi biến mất.
/// 4. Nội suy từng cặp điểm, vẽ lại bằng cùng kiểu nét.
///
/// ─── Chỗ này KHÁC morphicons ────────────────────────────────────────────
/// morphicons giải bài toán Procrustes 2D để tìm phép quay tối ưu giữa hai
/// hình, ở dạng đóng. Ở đây không làm vậy. Thay vào đó, với mỗi cặp đường,
/// thử mọi cách xoay vòng danh sách điểm (và cả chiều ngược lại) rồi chọn
/// cách cho tổng bình phương khoảng cách nhỏ nhất.
///
/// Nó rẻ hơn và đủ cho việc cần làm: thứ gây khó chịu nhất khi biến hình là
/// hình bị XOẮN vì điểm đầu của hai đường nằm ở hai phía khác nhau, và phép
/// chọn này khử đúng cái đó. Nó KHÔNG tìm được phép quay tối ưu cho hai hình
/// chỉ khác nhau bởi một góc xoay — trường hợp đó vẫn biến hình chứ không
/// xoay. Với các cặp trong app (cộng → tích, tim) thì không gặp.
///
/// Kết quả ghép được nhớ lại: với một cặp icon, việc lấy mẫu và dò chỉ chạy
/// một lần cho cả vòng đời app.
class MorphIcon extends StatefulWidget {
  const MorphIcon({
    super.key,
    required this.from,
    required this.to,
    required this.t,
    required this.color,
    this.size = 22,
    this.strokeWidth = 2,
  });

  /// Hai đầu của phép biến hình.
  final NpIcon from;
  final NpIcon to;

  /// 0 là `from`, 1 là `to`.
  final double t;

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  State<MorphIcon> createState() => _MorphIconState();
}

class _MorphIconState extends State<MorphIcon> {
  late _MorphPair _pair = _MorphPair.of(widget.from, widget.to);

  @override
  void didUpdateWidget(MorphIcon old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from || old.to != widget.to) {
      _pair = _MorphPair.of(widget.from, widget.to);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _MorphPainter(
            pair: _pair,
            t: widget.t,
            color: widget.color,
            size: widget.size,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      );
}

class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.pair,
    required this.t,
    required this.color,
    required this.size,
    required this.strokeWidth,
  });

  final _MorphPair pair;

  /// Có thể vượt ra ngoài 0..1: lò xo loại nảy đi quá đích rồi quay lại, và
  /// cắt phần đó đi là cắt mất chính thứ làm nên độ nảy.
  final double t;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Hình học của Lucide nằm trên lưới 24×24; nét cũng phải co theo cùng tỉ
    // lệ, không thì icon nhỏ có nét dày bằng icon lớn.
    final scale = size / 24.0;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Độ đặc chạy từ đầu này sang đầu kia. Với cặp tim rỗng → tim đặc thì
    // đây là TOÀN BỘ phép biến hình: hai bên dùng chung một đường, nên nếu
    // chỉ nội suy toạ độ thì không có gì đổi.
    // Kẹp RIÊNG phần độ đặc. Toạ độ được phép vượt 0..1 để giữ độ nảy,
    // nhưng alpha thì không — quá 1 là lỗi khẳng định khi dựng màu.
    final fillAlpha = ui
        .lerpDouble(pair.fromFilled ? 1.0 : 0.0, pair.toFilled ? 1.0 : 0.0, t)!
        .clamp(0.0, 1.0);

    final fill = fillAlpha <= 0
        ? null
        : (Paint()
          ..color = color.withValues(alpha: color.a * fillAlpha)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true);

    for (final seg in pair.segments) {
      final path = Path();
      for (var i = 0; i < seg.from.length; i++) {
        final p = Offset.lerp(seg.from[i], seg.to[i], t)!;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      if (seg.closed) path.close();
      if (fill != null) canvas.drawPath(path, fill);
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MorphPainter old) =>
      old.t != t ||
      old.color != color ||
      old.size != size ||
      old.strokeWidth != strokeWidth ||
      !identical(old.pair, pair);
}

/// Một cặp đường đã ghép điểm với nhau.
class _MorphSegment {
  const _MorphSegment(this.from, this.to, this.closed);
  final List<Offset> from;
  final List<Offset> to;
  final bool closed;
}

/// Hai icon đã lấy mẫu và ghép xong, nhớ lại theo cặp.
class _MorphPair {
  const _MorphPair(this.segments, this.fromFilled, this.toFilled);
  final List<_MorphSegment> segments;

  /// Hai đầu có tô đặc không. Tim rỗng và tim đặc dùng CHUNG một đường, nên
  /// nếu không có phần này thì phép biến hình giữa chúng không đổi gì cả.
  final bool fromFilled;
  final bool toFilled;

  static final _cache = <String, _MorphPair>{};

  static _MorphPair of(NpIcon from, NpIcon to) =>
      _cache.putIfAbsent('${from.name}>${to.name}', () => _build(from, to));

  /// Số điểm lấy trên mỗi đường.
  ///
  /// 64 đủ để một cung tròn bán kính 8 trên lưới 24 nhìn vẫn tròn — bước
  /// giữa hai điểm dưới 0,8 đơn vị, nhỏ hơn nửa bề dày nét. Tăng nữa chỉ tốn
  /// thời gian mà mắt không thấy khác.
  static const _samples = 64;

  static _MorphPair _build(NpIcon from, NpIcon to) {
    final a = _sampleIcon(from);
    final b = _sampleIcon(to);

    final segments = <_MorphSegment>[];
    final count = math.max(a.length, b.length);

    for (var i = 0; i < count; i++) {
      // Bên nào hết đường thì đường thừa của bên kia co về tâm của chính nó:
      // nó thu lại thành một chấm rồi biến mất, thay vì nhảy từ hư không ra.
      final sa = i < a.length ? a[i] : _collapse(b[i]);
      final sb = i < b.length ? b[i] : _collapse(a[i]);
      final aligned = _align(sa.points, sb.points);
      segments.add(_MorphSegment(aligned, sb.points, sa.closed && sb.closed));
    }
    return _MorphPair(segments, npIconIsFilled(from), npIconIsFilled(to));
  }

  static _Sampled _collapse(_Sampled s) {
    var cx = 0.0, cy = 0.0;
    for (final p in s.points) {
      cx += p.dx;
      cy += p.dy;
    }
    final c = Offset(cx / s.points.length, cy / s.points.length);
    return _Sampled(List.filled(s.points.length, c), s.closed);
  }

  /// Chọn cách xoay vòng (và chiều) của `a` sao cho nó gần `b` nhất.
  ///
  /// Đây là chỗ quyết định phép biến hình nhìn có bị xoắn hay không: hai
  /// đường có thể mô tả cùng một hình nhưng bắt đầu từ hai điểm khác nhau,
  /// và nối điểm 0 với điểm 0 sẽ kéo cả hình quay một vòng.
  static List<Offset> _align(List<Offset> a, List<Offset> b) {
    final n = a.length;
    var best = a;
    var bestCost = double.infinity;

    for (final reversed in [false, true]) {
      final src = reversed ? a.reversed.toList() : a;
      for (var shift = 0; shift < n; shift++) {
        var cost = 0.0;
        for (var i = 0; i < n; i++) {
          final p = src[(i + shift) % n];
          final q = b[i];
          final dx = p.dx - q.dx, dy = p.dy - q.dy;
          cost += dx * dx + dy * dy;
          // Bỏ sớm: phần lớn cách xoay tệ hơn hẳn cách tốt nhất và không cần
          // cộng hết 64 số hạng mới biết.
          if (cost >= bestCost) break;
        }
        if (cost < bestCost) {
          bestCost = cost;
          best = [for (var i = 0; i < n; i++) src[(i + shift) % n]];
        }
      }
    }
    return best;
  }

  static List<_Sampled> _sampleIcon(NpIcon icon) {
    final out = <_Sampled>[];
    for (final d in npIconPaths(icon)) {
      final proxy = _PathBuilder();
      writeSvgPathDataToPath(d, proxy);
      for (final metric in proxy.path.computeMetrics()) {
        if (metric.length <= 0) continue;
        final pts = <Offset>[];
        for (var i = 0; i < _samples; i++) {
          final tan = metric.getTangentForOffset(
              metric.length * (i / (_samples - 1)));
          if (tan != null) pts.add(tan.position);
        }
        if (pts.length == _samples) out.add(_Sampled(pts, metric.isClosed));
      }
    }
    return out;
  }
}

/// Toạ độ đã nội suy tại thời điểm `t`, cho test.
///
/// Bộ biến hình là logic thuần: lấy mẫu, ghép điểm, nội suy. Kiểm bằng ảnh
/// chụp màn hình thì chỉ thấy "trông có vẻ đúng"; kiểm bằng toạ độ thì trả
/// lời được "điểm có bám đúng hình ở hai đầu không".
@visibleForTesting
List<List<Offset>> debugMorphPoints(NpIcon from, NpIcon to, double t) {
  final pair = _MorphPair.of(from, to);
  return [
    for (final seg in pair.segments)
      [
        for (var i = 0; i < seg.from.length; i++)
          Offset.lerp(seg.from[i], seg.to[i], t)!,
      ],
  ];
}

class _Sampled {
  const _Sampled(this.points, this.closed);
  final List<Offset> points;
  final bool closed;
}

/// Cầu nối giữa path_parsing và Path của dart:ui.
class _PathBuilder extends PathProxy {
  final path = ui.Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
          double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

/// Bốn kiểu lò xo, đặt tên theo morphicons.
///
/// Dùng lò xo chứ không dùng đường cong thời lượng cố định vì lò xo NGẮT
/// ĐƯỢC giữa chừng: bấm tim hai lần thật nhanh thì hình chạy tiếp từ chỗ
/// đang dở với vận tốc đang có, thay vì giật về đầu. Với một cái nút bấm
/// nhiều lần thì đó là khác biệt cảm nhận được.
enum MorphSpring {
  smooth(stiffness: 170, damping: 26),
  snappy(stiffness: 300, damping: 30),
  bouncy(stiffness: 260, damping: 14),
  gentle(stiffness: 120, damping: 20);

  const MorphSpring({required this.stiffness, required this.damping});
  final double stiffness;
  final double damping;

  SpringDescription get description =>
      SpringDescription(mass: 1, stiffness: stiffness, damping: damping);
}

/// Icon tự chạy sang hình kia mỗi khi `active` đổi.
///
/// `active` false là `from`, true là `to`.
class MorphIconSwitch extends StatefulWidget {
  const MorphIconSwitch({
    super.key,
    required this.from,
    required this.to,
    required this.active,
    required this.color,
    this.size = 22,
    this.strokeWidth = 2,
    this.spring = MorphSpring.snappy,
  });

  final NpIcon from;
  final NpIcon to;
  final bool active;
  final Color color;
  final double size;
  final double strokeWidth;
  final MorphSpring spring;

  @override
  State<MorphIconSwitch> createState() => _MorphIconSwitchState();
}

class _MorphIconSwitchState extends State<MorphIconSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController.unbounded(
    vsync: this,
    // Bắt đầu ở đúng trạng thái hiện tại, KHÔNG chạy hoạt ảnh lúc dựng: một
    // danh sách vừa cuộn tới sẽ có hàng loạt icon cùng nhảy nếu không.
    value: widget.active ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(MorphIconSwitch old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _run();
  }

  void _run() {
    // Giữ nguyên vận tốc đang có: đó là chỗ lò xo hơn hẳn đường cong cố định.
    _ctrl.animateWith(SpringSimulation(
      widget.spring.description,
      _ctrl.value,
      widget.active ? 1.0 : 0.0,
      _ctrl.velocity,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => MorphIcon(
          from: widget.from,
          to: widget.to,
          // Lò xo loại nảy vượt quá 0..1 rồi quay lại; MorphIcon tự kẹp,
          // nhưng kẹp ở đây thì phần nảy biến mất. Để nguyên và kẹp bên
          // trong là cố ý: hình nảy qua đích một chút rồi ổn định.
          t: _ctrl.value,
          color: widget.color,
          size: widget.size,
          strokeWidth: widget.strokeWidth,
        ),
      );
}
