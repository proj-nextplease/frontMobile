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
/// Hoạt hoạ: một vạch acid kéo ngang rồi chữ hiện lên từ dưới vạch đó — như
/// thể vạch vừa "quét" chữ ra. Ngắn, 1,3 giây, vì đây là thuế thu trên MỌI
/// lần mở app.
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
    duration: const Duration(milliseconds: 1300),
  );

  late final _sweep = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.5, curve: Curves.easeInOutCubic),
  );
  late final _word = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.28, 0.72, curve: Curves.easeOutCubic),
  );
  late final _tag = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
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
        statusBarBrightness: Brightness.dark,     // iOS mô tả NỀN
        statusBarIconBrightness: Brightness.light, // Android mô tả ICON
      ),
      child: Scaffold(
        backgroundColor: Np.bg,
        body: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vạch quét. Kéo từ 0 tới hết bề ngang chữ.
                Container(
                  width: 210 * _sweep.value,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Np.acid,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: Np.s5),

                // Chữ trượt lên và hiện dần từ dưới vạch.
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    heightFactor: 1,
                    child: Transform.translate(
                      offset: Offset(0, 44 * (1 - _word.value)),
                      child: Opacity(
                        opacity: _word.value,
                        child: Text(
                          'nextplease',
                          style: NpType.display.copyWith(fontSize: 42),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: Np.s3),
                Opacity(
                  opacity: _tag.value,
                  child: Text(
                    'hồ sơ dựa trên bằng chứng',
                    style: NpType.meta.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
