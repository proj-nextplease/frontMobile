import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Màn hình mở app.
///
/// Hai lớp splash chứ không phải một, và chúng khác nhau về bản chất:
///
///   1. Splash NATIVE (do hệ điều hành vẽ, cấu hình ở Info.plist và
///      styles.xml). Hiện ngay khoảnh khắc chạm icon, trước cả khi Flutter
///      kịp khởi động. Không lập trình được gì ở đó.
///   2. Màn hình này — chạy SAU khi Flutter đã sẵn sàng, nên mới có hoạt hoạ.
///
/// Nếu chỉ làm lớp 2 thì người dùng thấy một khoảng trắng chớp lên trước khi
/// hoạt hoạ bắt đầu, đúng cái hở mà splash native sinh ra để che.
///
/// Thời lượng cố ý ngắn. Màn hình mở app là thuế thu trên MỌI lần mở, nên
/// hoạt hoạ dài chỉ vui ở lần đầu rồi thành phiền ở lần thứ mười.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onDone});

  /// Gọi khi hoạt hoạ xong. Nơi gọi quyết định đi tiếp đâu — đăng nhập hay
  /// thẳng vào app nếu còn phiên.
  final VoidCallback onDone;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // Chấm tròn nảy lên trước, chữ trượt vào sau — lệch pha để mắt có thứ tự để
  // bám theo, thay vì mọi thứ cùng hiện một lúc.
  late final _dot = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
  );
  late final _word = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic),
  );
  late final _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
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
    return Scaffold(
      backgroundColor: NpColors.ink,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Opacity(
                    opacity: _word.value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - _word.value)),
                      child: const Text(
                        'nextplease',
                        style: TextStyle(
                          color: NpColors.onDark,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  // Dấu hai chấm emerald — chi tiết nhận diện lấy từ wordmark
                  // ở footer của web.
                  Transform.scale(
                    scale: _dot.value,
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 3, left: 2),
                      child: Text(
                        ':',
                        style: TextStyle(
                          color: NpColors.emerald,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: _tagline.value,
                child: const Text(
                  'Hồ sơ dựa trên bằng chứng',
                  style: TextStyle(
                    color: NpColors.mutedDark,
                    fontSize: 15,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
