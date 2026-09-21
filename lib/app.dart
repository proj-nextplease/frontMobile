import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/shell/main_shell.dart';
import 'features/jobs/applied_store.dart';
import 'features/jobs/saved_store.dart';
import 'features/profile/gamification_store.dart';
import 'features/profile/me_store.dart';
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

  /// Cần để đóng màn hình đăng nhập được ĐẨY LÊN từ chỗ khác trong app.
  final _navKey = GlobalKey<NavigatorState>();

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
          // Nạp danh sách đã lưu ngay khi có phiên, để tim hiện đúng ở lần
          // cuộn đầu tiên chứ không phải sau khi người dùng bấm thử.
          SavedStore.instance.hydrate();
          GamificationStore.instance.hydrate();
          // Hai kho này quyết định nút Ứng tuyển hiện ra thế nào (xem
          // eligibility.dart). Không nạp ở đây thì thẻ và màn chi tiết mời
          // người dùng nộp một cơ hội mà máy chủ sẽ từ chối.
          MeStore.instance.hydrate();
          AppliedStore.instance.hydrate();
          // Đóng màn hình đăng nhập nếu nó đang được đẩy lên trên danh sách.
          // Không có gì để đóng thì popUntil trả về ngay.
          _navKey.currentState?.popUntil((r) => r.isFirst);
          setState(() => _stage = _Stage.home);
        } else if (state.event == AuthChangeEvent.signedOut) {
          // Không xoá thì người tiếp theo đăng nhập trên cùng thiết bị sẽ thấy
          // tim của người trước.
          SavedStore.instance.clear();
          GamificationStore.instance.clear();
          MeStore.instance.clear();
          AppliedStore.instance.clear();
          _navKey.currentState?.popUntil((r) => r.isFirst);
          setState(() => _stage = _Stage.login);
        }
      });
    }
  }

  void _afterSplash() {
    // Phiên khôi phục từ Keychain lúc mở app KHÔNG bắn sự kiện signedIn —
    // nó đã đăng nhập sẵn từ trước. Nên phải nạp tay ở đây, nếu không người
    // dùng cũ mở app sẽ thấy mọi tin đều chưa lưu.
    if (_auth.signedIn) {
      SavedStore.instance.hydrate();
      GamificationStore.instance.hydrate();
      MeStore.instance.hydrate();
      AppliedStore.instance.hydrate();
    }
    setState(() => _stage = _auth.signedIn ? _Stage.home : _Stage.login);
  }

  /// Mở màn hình đăng nhập TỪ danh sách cơ hội.
  ///
  /// Đẩy lên thành một route riêng thay vì đổi _stage. Khác biệt quan trọng:
  /// đổi _stage sẽ huỷ JobsPage, kéo theo mất vị trí cuộn, mất tab đang chọn
  /// và phải gọi lại API. Đẩy route thì JobsPage vẫn nằm nguyên bên dưới, nên
  /// đóng lại là trở về đúng chỗ đang đọc dở.
  ///
  /// Đây cũng là lý do màn hình đăng nhập ở đây có nút đóng còn ở lần mở app
  /// thì không: một bên là bước bắt buộc, một bên là việc người dùng có thể
  /// đổi ý.
  void _openLoginSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LoginPage(
          onEmailLogin: _auth.signInWithPassword,
          onSocialLogin: _auth.signInWithProvider,
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nextplease',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      // Hai bộ theme, MaterialApp tự chọn theo cài đặt sáng/tối của máy.
      // themeMode mặc định là ThemeMode.system nên không cần khai báo.
      theme: buildNpTheme(Brightness.light),
      darkTheme: buildNpTheme(Brightness.dark),
      home: switch (_stage) {
        _Stage.splash => SplashPage(onDone: _afterSplash),
        _Stage.login => LoginPage(
            onEmailLogin: _auth.signInWithPassword,
            onSocialLogin: _auth.signInWithProvider,
            onSkip: () => setState(() => _stage = _Stage.home),
          ),
        // Khách vào qua nút "Xem cơ hội trước đã" — truyền cờ để các tab hiện
        // đường quay lại đăng nhập.
        _Stage.home => Builder(
            builder: (context) => MainShell(
              isGuest: !_auth.signedIn,
              onSignIn: () => _openLoginSheet(context),
              onSignOut: _auth.signOut,
            ),
          ),
      },
    );
  }
}
