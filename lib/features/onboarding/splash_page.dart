import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Màn hình mở app.
///
/// Hai lớp splash chứ không phải một:
///   1. Splash NATIVE (Info.plist, styles.xml) — hiện ngay khoảnh khắc chạm
///      icon, trước cả khi Flutter khởi động. Không lập trình được gì ở đó.
///   2. Màn hình này — chạy SAU khi Flutter sẵn sàng, nên mới có hoạt hoạ.
///
/// Hai lớp phải CÙNG MÀU NỀN. Đổi Np.bg thì phải đổi cả LaunchScreen.storyboard
/// và colors.xml, nếu không sẽ thấy một cú chớp đổi màu ở chỗ nối.
///
/// ─── Về hoạt hoạ ─────────────────────────────────────────────────────────
/// Bản trước quá thưa: một vạch kéo ngang rồi chữ hiện lên, hết. Bản này thêm
/// ba lớp chồng nhau, mỗi lớp vào ở một nhịp khác nhau:
///
///   nền     — lưới chấm mờ, nở ra từ giữa
///   nội dung— chữ hiện theo KIỂU MẶT NẠ (trượt lên từ dưới một khung cắt),
///             không phải mờ dần; mặt nạ cho cảm giác chữ được "in" ra
///   viền    — ba thẻ nhỏ nói app này làm gì, bay vào rồi trôi nhẹ
///
/// Ba thẻ không phải để trang trí: chúng nói "thực tập / quest / minh chứng"
/// — tức là người dùng biết app này làm gì ngay trong 2 giây chờ, thay vì chỉ
/// nhìn một cái tên.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  /// Mạch chính, chạy một lần rồi gọi onDone.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  /// Mạch riêng cho chuyển động trôi của thẻ. Tách khỏi mạch chính vì nó lặp
  /// vô hạn — gộp chung thì onDone sẽ không bao giờ được gọi.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final _grid = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
  );
  late final _bar = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.08, 0.5, curve: Curves.easeInOutCubic),
  );
  late final _word = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.22, 0.6, curve: Curves.easeOutCubic),
  );
  late final _tag = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.42, 0.7, curve: Curves.easeOut),
  );
  late final _progress = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.1, 1.0, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _float.dispose();
    super.dispose();
  }

  /// Ba thẻ: nhãn, vị trí theo tỉ lệ màn hình, góc nghiêng, nhịp vào.
  /// x nằm trong khoảng an toàn ±0.66: Alignment tính từ TÂM thẻ, nên thẻ càng
  /// rộng thì càng dễ thò ra ngoài mép. '+500 EXP' ở 0.74 bị cắt mất đuôi.
  static const _cards = [
    (label: 'Thực tập', x: -0.66, y: -0.42, angle: -0.10, delay: 0.46),
    (label: '+500 EXP', x: 0.60, y: -0.22, angle: 0.12, delay: 0.56),
    (label: 'Đã xác thực', x: -0.48, y: 0.30, angle: 0.07, delay: 0.66),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,      // iOS mô tả NỀN
        statusBarIconBrightness: Brightness.light, // Android mô tả ICON
      ),
      child: Scaffold(
        backgroundColor: Np.bg,
        body: AnimatedBuilder(
          animation: Listenable.merge([_c, _float]),
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotGrid(progress: _grid.value),
                ),
              ),

              for (final card in _cards)
                _FloatingCard(
                  label: card.label,
                  align: Alignment(card.x, card.y),
                  angle: card.angle,
                  // Ép về 0..1 rồi bình thường hoá: mỗi thẻ có nhịp vào riêng
                  // nhưng dùng chung một mạch.
                  t: ((_c.value - card.delay) / 0.22).clamp(0.0, 1.0),
                  drift: _float.value,
                ),

              Center(
                child: Padding(
                  // Lề này là thứ bản trước thiếu: Center bọc một Column rộng
                  // bằng đúng chữ "nextplease", mà chữ đó gần bằng bề ngang
                  // màn hình, nên nó tràn ra cả hai mép.
                  padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Sweep(t: _bar.value),
                      const SizedBox(height: Np.s5),
                      _MaskedRise(
                        t: _word.value,
                        child: Text(
                          'nextplease',
                          style: NpType.display.copyWith(fontSize: 40),
                        ),
                      ),
                      const SizedBox(height: Np.s2),
                      _MaskedRise(
                        t: _tag.value,
                        child: Text(
                          'hồ sơ dựa trên bằng chứng',
                          style: NpType.meta.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Vạch tiến trình mảnh sát đáy. Nói cho người dùng biết màn hình
              // này có điểm kết, thay vì để họ đoán.
              Positioned(
                left: Np.gutter,
                right: Np.gutter,
                bottom: Np.s10,
                child: _ProgressLine(t: _progress.value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vạch acid kéo ngang, có chấm sáng chạy ở đầu mũi.
class _Sweep extends StatelessWidget {
  const _Sweep({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        height: 8,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: 190 * t,
              height: 3,
              decoration: BoxDecoration(
                color: Np.acid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (t > 0.02 && t < 0.99)
              Positioned(
                left: (190 * t) - 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Np.acid,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Np.acid.withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Chữ trượt lên từ dưới một khung cắt.
///
/// Dùng mặt nạ thay vì mờ dần: mờ dần trông như "đang tải", còn trượt lên sau
/// một khung cắt trông như chữ được IN ra — dứt khoát hơn hẳn.
class _MaskedRise extends StatelessWidget {
  const _MaskedRise({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: Align(
          alignment: Alignment.topLeft,
          heightFactor: 1,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - t)),
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
        ),
      );
}

/// Thẻ nhỏ bay vào rồi trôi nhẹ mãi.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.label,
    required this.align,
    required this.angle,
    required this.t,
    required this.drift,
  });

  final String label;
  final Alignment align;
  final double angle;
  final double t;

  /// 0..1 lặp vô hạn, dùng làm pha của chuyển động trôi.
  final double drift;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();

    // Mỗi thẻ lệch pha theo vị trí của nó, nếu không cả ba sẽ trôi đồng bộ
    // và trông như một khối duy nhất.
    final phase = drift * 2 * math.pi + align.x * 2;
    final dy = math.sin(phase) * 5;

    return Align(
      alignment: align,
      child: Transform.translate(
        offset: Offset(0, dy + 22 * (1 - t)),
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: 0.85 + 0.15 * t,
            child: Opacity(
              opacity: t,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s3, vertical: Np.s2 - 1),
                decoration: BoxDecoration(
                  color: Np.surfaceHi,
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: Np.line),
                ),
                child: Text(
                  label,
                  style: NpType.meta.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Np.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 2,
          child: Stack(
            children: [
              Container(color: Np.line),
              FractionallySizedBox(
                widthFactor: t.clamp(0.0, 1.0),
                child: Container(color: Np.acid),
              ),
            ],
          ),
        ),
      );
}

/// Lưới chấm mờ, nở ra từ giữa màn hình.
///
/// Vẽ bằng CustomPainter thay vì xếp hàng trăm Widget: ~200 chấm mà mỗi chấm
/// là một Container thì cây widget phình lên vô ích, còn ở đây chỉ là một lượt
/// drawCircle.
class _DotGrid extends CustomPainter {
  _DotGrid({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    const gap = 34.0;
    final center = Offset(size.width / 2, size.height / 2);
    final maxDist = center.distance;
    final paint = Paint()..color = Np.ink;

    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        final p = Offset(x, y);
        final d = (p - center).distance / maxDist;

        // Chấm chỉ hiện khi sóng nở đã chạy qua nó.
        final local = ((progress - d * 0.7) / 0.3).clamp(0.0, 1.0);
        if (local <= 0) continue;

        // Mờ dần về rìa, để lưới không tranh chấp với chữ ở giữa.
        final alpha = 0.055 * local * (1 - d * 0.55);
        canvas.drawCircle(p, 1.3, paint..color = Np.ink.withValues(alpha: alpha));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGrid old) => old.progress != progress;
}
