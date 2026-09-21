import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/jobs/jobs_page.dart';
import 'features/onboarding/splash_page.dart';

/// Luồng mở app: splash → (đăng nhập | danh sách cơ hội).
///
/// Vì sao splash tự quyết định đi đâu thay vì luôn về màn hình đăng nhập:
/// phiên được lưu trong Keychain/Keystore nên người đã đăng nhập sẽ vẫn còn
/// phiên sau khi tắt app. Bắt họ đăng nhập lại mỗi lần mở là vô nghĩa.
enum _Stage { splash, login, home }

class NextPleaseApp extends StatefulWidget {
  const NextPleaseApp({super.key});
  @override
  State<NextPleaseApp> createState() => _NextPleaseAppState();
}

class _NextPleaseAppState extends State<NextPleaseApp> {
  final _auth = AuthService();
  _Stage _stage = _Stage.splash;

  @override
  void initState() {
    super.initState();

    /* Đăng nhập mạng xã hội KHÔNG trả kết quả về chỗ bấm nút: trình duyệt mở
       ra, người dùng thao tác ở đó, rồi hệ điều hành đánh thức app qua deep
       link. Nên phải lắng nghe luồng sự kiện, nếu không app sẽ nằm mãi ở màn
       hình đăng nhập dù đã đăng nhập xong. */
    if (Env.hasSupabase) {
      _auth.changes.listen((state) {
        if (!mounted) return;
        if (state.event == AuthChangeEvent.signedIn) {
          setState(() => _stage = _Stage.home);
        } else if (state.event == AuthChangeEvent.signedOut) {
          setState(() => _stage = _Stage.login);
        }
      });
    }
  }

  void _afterSplash() {
    setState(() => _stage = _auth.signedIn ? _Stage.home : _Stage.login);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nextplease',
      debugShowCheckedModeBanner: false,
      theme: buildNpTheme(),
      home: switch (_stage) {
        _Stage.splash => SplashPage(onDone: _afterSplash),
        _Stage.login => LoginPage(
            onEmailLogin: _auth.signInWithPassword,
            onSocialLogin: _auth.signInWithProvider,
            onSkip: () => setState(() => _stage = _Stage.home),
          ),
        _Stage.home => const JobsPage(),
      },
    );
  }
}
