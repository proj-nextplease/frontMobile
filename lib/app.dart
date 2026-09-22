import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/shell/main_shell.dart';
import 'features/credentials/credentials_store.dart';
import 'features/jobs/applied_store.dart';
import 'features/jobs/saved_store.dart';
import 'features/profile/gamification_store.dart';
import 'features/legal/consent_gate.dart';
import 'features/profile/me_store.dart';
import 'features/profile/notification_banner.dart';
import 'features/profile/notifications_store.dart';
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

class _NextPleaseAppState extends State<NextPleaseApp>
    with WidgetsBindingObserver {
  final _auth = AuthService();
  _Stage _stage = _Stage.splash;

  /// Cần để đóng màn hình đăng nhập được ĐẨY LÊN từ chỗ khác trong app.
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
          // ping thay cho hydrate: nó vừa đánh dấu hoạt động hôm nay (đẩy
          // chuỗi ngày, hoàn thành nhiệm vụ "Ghé thăm mỗi ngày") vừa TRẢ VỀ
          // đúng trạng thái mà hydrate sẽ lấy. Gọi cả hai là gọi thừa.
          GamificationStore.instance.ping(force: true);
          // Hai kho này quyết định nút Ứng tuyển hiện ra thế nào (xem
          // eligibility.dart). Không nạp ở đây thì thẻ và màn chi tiết mời
          // người dùng nộp một cơ hội mà máy chủ sẽ từ chối.
          MeStore.instance.hydrate();
          AppliedStore.instance.hydrate();
          NotificationsStore.instance.hydrate();
          NotificationsStore.instance.startPolling();
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
          CredentialsStore.instance.clear();
          NotificationsStore.instance.clear();
          _navKey.currentState?.popUntil((r) => r.isFirst);
          setState(() => _stage = _Stage.login);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationsStore.instance.stopPolling();
    super.dispose();
  }

  /// App xuống nền thì NGỪNG hỏi máy chủ. Không có chỗ này thì app vẫn gọi
  /// mạng đều đặn suốt lúc nằm trong túi, và người dùng chỉ thấy pin tụt.
  ///
  /// Quay lại thì hỏi NGAY một lần rồi mới chạy lại vòng, vì trong lúc ở nền
  /// có thể đã có phản hồi mới, và bắt họ chờ hết một nhịp nữa là vô lý.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_auth.signedIn) return;
    if (state == AppLifecycleState.resumed) {
      NotificationsStore.instance.hydrate();
      NotificationsStore.instance.startPolling();
      // Người dùng mở app qua nửa đêm thì ngày đã đổi mà app vẫn đang chạy —
      // không ping ở đây thì chuỗi ngày hôm đó mất trắng. ping() tự bỏ qua
      // nếu đã ghi nhận hôm nay rồi.
      GamificationStore.instance.ping();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      NotificationsStore.instance.stopPolling();
    }
  }

  void _afterSplash() {
    // Phiên khôi phục từ Keychain lúc mở app KHÔNG bắn sự kiện signedIn —
    // nó đã đăng nhập sẵn từ trước. Nên phải nạp tay ở đây, nếu không người
    // dùng cũ mở app sẽ thấy mọi tin đều chưa lưu.
    if (_auth.signedIn) {
      SavedStore.instance.hydrate();
      GamificationStore.instance.ping(force: true);
      MeStore.instance.hydrate();
      AppliedStore.instance.hydrate();
      NotificationsStore.instance.hydrate();
      NotificationsStore.instance.startPolling();
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

      // App chỉ có tiếng Việt, nên ĐẶT CỨNG locale thay vì theo máy: người
      // dùng để máy tiếng Anh vẫn phải thấy hộp chọn ngày bằng tiếng Việt,
      // không thì một nửa giao diện nói một thứ tiếng.
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      // Thiếu ba delegate này thì showDatePicker ném
      // "No MaterialLocalizations found" ngay khi mở, và menu cắt/dán khi giữ
      // lâu trên ô nhập nói tiếng Anh.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      // Banner bọc NGOÀI Navigator để nó phủ lên cả những màn được đẩy lên.
      // Đặt trong `home:` thì mọi route mới sẽ che mất nó.
      builder: (context, child) => NotificationBannerHost(
        navigatorKey: _navKey,
        enabled: _stage == _Stage.home,
        // Cổng đồng ý nằm TRONG banner host nhưng NGOÀI Navigator: nó phải
        // phủ lên mọi màn được đẩy lên, còn banner thông báo thì không nên
        // chạy đè lên một cổng đang chặn.
        child: ConsentGate(
          enabled: _stage == _Stage.home && _auth.signedIn,
          onDecline: _auth.signOut,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
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
