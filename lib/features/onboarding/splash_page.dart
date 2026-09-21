import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Màn hình mở app — hệ giấy/sticker.
///
/// Hai lớp splash chứ không phải một:
///   1. Splash NATIVE (Info.plist, styles.xml) — hiện ngay khoảnh khắc chạm
///      icon, trước cả khi Flutter khởi động. Không lập trình được gì ở đó.
///   2. Màn hình này — chạy SAU khi Flutter sẵn sàng, nên mới có hoạt hoạ.
///
/// Hai lớp phải CÙNG MÀU NỀN, nếu không sẽ thấy một cú chớp đổi màu ở chỗ nối.
/// Đổi Paper.bg ở đây thì phải đổi cả LaunchScreen.storyboard và colors.xml.
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
  late final _card = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
  );
  late final _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
  );
  late final _stickers = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.5, 0.9, curve: Curves.easeOutBack),
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
        statusBarBrightness: Brightness.light,    // iOS mô tả NỀN
        statusBarIconBrightness: Brightness.dark, // Android mô tả ICON
      ),
      child: Scaffold(
        backgroundColor: Paper.bg,
        body: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                // Ba sticker nhỏ bay quanh, hiện sau cùng.
                _Sticker(
                  t: _stickers.value,
                  offset: const Offset(-118, -86),
                  angle: -0.22,
                  fill: Paper.coral,
                  glyph: '★',
                ),
                _Sticker(
                  t: _stickers.value,
                  offset: const Offset(126, -54),
                  angle: 0.26,
                  fill: Paper.violet,
                  glyph: '✦',
                ),
                _Sticker(
                  t: _stickers.value,
                  offset: const Offset(-96, 92),
                  angle: 0.16,
                  fill: Paper.lime,
                  glyph: '✓',
                  glyphColor: Paper.ink,
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _card.value,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 13, 20, 15),
                        decoration: Paper.card(
                          fill: Paper.lime, radius: 18, dx: 5, dy: 5,
                        ),
                        child: const Text(
                          'nextplease:',
                          style: TextStyle(
                            color: Paper.ink,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.3,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: _tagline.value,
                      child: const Text(
                        'hồ sơ dựa trên bằng chứng',
                        style: TextStyle(
                          color: Paper.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker({
    required this.t,
    required this.offset,
    required this.angle,
    required this.fill,
    required this.glyph,
    this.glyphColor = Paper.bg,
  });

  final double t;
  final Offset offset;
  final double angle;
  final Color fill;
  final String glyph;
  final Color glyphColor;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: t,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: Paper.card(fill: fill, radius: 12, dx: 3, dy: 3),
              child: Text(
                glyph,
                style: TextStyle(
                  color: glyphColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
}
