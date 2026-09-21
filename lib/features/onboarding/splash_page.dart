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
/// Thời lượng cố ý ngắn: đây là thuế thu trên MỌI lần mở app.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  // Lệch pha để mắt có thứ tự bám theo, thay vì mọi thứ cùng bật một lúc.
  late final _orb = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
  );
  late final _word = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.22, 0.65, curve: Curves.easeOutCubic),
  );
  late final _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,    // iOS mô tả NỀN
        statusBarIconBrightness: Brightness.light, // Android mô tả ICON
      ),
      child: Scaffold(
        backgroundColor: Np.bg,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            children: [
              // Hai quầng gradient mờ nở ra từ nền. Đây là nguồn màu duy nhất
              // của màn hình — chữ giữ nguyên màu mực.
              _Orb(
                t: _orb.value,
                alignment: const Alignment(-0.85, -0.6),
                size: 320,
                color: Np.violet,
              ),
              _Orb(
                t: _orb.value,
                alignment: const Alignment(0.9, 0.35),
                size: 280,
                color: Np.pink,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _word.value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - _word.value)),
                        child: GradientText(
                          'nextplease',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _tagline.value,
                      child: const Text(
                        'hồ sơ dựa trên bằng chứng',
                        style: TextStyle(
                          color: Np.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quầng sáng mờ. Dùng gradient radial tắt dần về trong suốt thay vì
/// ImageFiltered(blur): blur thật tốn GPU và ở đây không nhìn ra khác biệt.
class _Orb extends StatelessWidget {
  const _Orb({
    required this.t,
    required this.alignment,
    required this.size,
    required this.color,
  });

  final double t;
  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Container(
          width: size * (0.6 + 0.4 * t),
          height: size * (0.6 + 0.4 * t),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.40 * t),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      );
}
