import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import 'login_page.dart' show SocialProvider;

/// Nơi cất phiên đăng nhập.
///
/// supabase_flutter mặc định lưu phiên bằng SharedPreferences — trên iOS là
/// một file plist thường, trên Android là XML trong vùng dữ liệu app. Đó là
/// chỗ chứa refresh token, thứ đổi được ra quyền truy cập đầy đủ tài khoản.
/// Đưa vào Keychain / Keystore thì nó được hệ điều hành mã hoá ở cấp phần
/// cứng, và không nằm trong bản sao lưu thông thường.
class _SecureLocalStorage extends LocalStorage {
  static const _key = 'nextplease.session';
  // Android: bản v11 bỏ cờ encryptedSharedPreferences vì mặc định đã là
  // AES-GCM với khoá bọc trong KeyStore, nên không cần khai báo gì thêm.
  // iOS: first_unlock thay vì mặc định — phiên vẫn đọc được khi app chạy nền
  // sau lần mở khoá đầu tiên, nhưng không đọc được khi máy chưa hề mở khoá.
  final _store = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _store.read(key: _key);

  @override
  Future<bool> hasAccessToken() async =>
      (await _store.read(key: _key)) != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(key: _key);
}

class AuthService {
  static Future<void> init() async {
    if (!Env.hasSupabase) return;   // nơi gọi tự báo lỗi cấu hình

    // Cắm nguồn token cho mọi lệnh gọi API. Phải làm TRƯỚC khi bất kỳ màn hình
    // nào gọi endpoint cần đăng nhập.
    // try/catch vì Supabase.instance NÉM LỖI nếu initialize chưa xong. Bình
    // thường không xảy ra, nhưng một lệnh gọi API sớm mà làm sập app thì
    // không đáng.
    ApiClient.tokenProvider = () {
      try {
        return Supabase.instance.client.auth.currentSession?.accessToken;
      } catch (_) {
        return null;
      }
    };

    await Supabase.initialize(
      url: Env.supabaseUrl,
      // Supabase đổi tên "anon key" thành "publishable key"; vẫn là cùng một
      // giá trị. Giữ tên biến môi trường trùng với web (VITE_SUPABASE_ANON_KEY)
      // để hai bên dùng chung một khoá mà không phải nhớ hai tên.
      publishableKey: Env.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: _SecureLocalStorage(),
      ),
    );
  }

  GoTrueClient get _auth => Supabase.instance.client.auth;

  Session? get session => Env.hasSupabase ? _auth.currentSession : null;
  bool get signedIn => session != null;
  Stream<AuthState> get changes => _auth.onAuthStateChange;

  String? get accessToken => session?.accessToken;

  /// Trả null nếu thành công, hoặc thông điệp lỗi tiếng Việt để hiển thị.
  ///
  /// Không ném exception ra ngoài: màn hình đăng nhập luôn phải hiện được lỗi
  /// chứ không để app văng, và mọi lỗi ở đây đều là lỗi người dùng đọc được.
  Future<String?> signInWithPassword(String email, String password) async {
    if (!Env.hasSupabase) return _missingConfig;
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _viMessage(e);
    } catch (_) {
      return 'Không kết nối được máy chủ đăng nhập. Kiểm tra mạng rồi thử lại.';
    }
  }

  /// Đăng nhập mạng xã hội qua trình duyệt hệ thống.
  ///
  /// Không dùng SDK native: GitHub không có SDK nào cả, nên nếu làm native cho
  /// Google và Facebook thì ba nút sẽ hành xử khác nhau, và phải khai báo thêm
  /// client ID riêng cho iOS/Android cùng SHA-1 với key hash. Kiểu trình duyệt
  /// dùng lại đúng cấu hình OAuth mà web đã có.
  ///
  /// Hàm trả về NGAY sau khi mở trình duyệt — chưa đăng nhập xong. Kết quả về
  /// sau qua deep link, và nơi gọi phải lắng nghe [changes] chứ không thể chờ
  /// hàm này.
  Future<String?> signInWithProvider(SocialProvider provider) async {
    if (!Env.hasSupabase) return _missingConfig;
    try {
      await _auth.signInWithOAuth(
        switch (provider) {
          SocialProvider.google => OAuthProvider.google,
          SocialProvider.facebook => OAuthProvider.facebook,
          SocialProvider.github => OAuthProvider.github,
        },
        redirectTo: Env.oauthCallback,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return null;
    } on AuthException catch (e) {
      return _viMessage(e);
    } catch (_) {
      return 'Không mở được trang đăng nhập ${provider.name}.';
    }
  }

  /// Gửi email đặt lại mật khẩu.
  ///
  /// LUÔN báo thành công, kể cả khi email không tồn tại. Nói "email này chưa
  /// đăng ký" là biến màn quên mật khẩu thành công cụ dò xem ai có tài khoản
  /// trên hệ thống. Web đã xử lý đúng như vậy (xem authApi.requestPasswordReset),
  /// nên mobile giữ y nguyên hành vi.
  ///
  /// Chỉ trả lỗi khi chính app cấu hình sai — đó là lỗi của mình, không phải
  /// thông tin về người dùng.
  Future<String?> sendPasswordReset(String email) async {
    if (!Env.hasSupabase) return _missingConfig;
    try {
      await _auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: Env.resetPasswordUrl,
      );
    } on AuthException catch (e) {
      // Nuốt lỗi từ nhà cung cấp để không lộ email nào đã đăng ký. Vẫn ghi ra
      // để người phát triển thấy khi cấu hình sai thật.
      debugPrint('[auth] resetPasswordForEmail: ${e.message}');
    } catch (_) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
    }
    return null;
  }

  Future<void> signOut() async {
    if (Env.hasSupabase) await _auth.signOut();
  }

  static const _missingConfig =
      'Chưa cấu hình Supabase. Chạy lại app với --dart-define-from-file=env.json '
      '(xem env.example.json).';

  /// Supabase trả lỗi bằng tiếng Anh. Dịch những trường hợp hay gặp; còn lại
  /// giữ nguyên văn để không che mất thông tin gỡ lỗi.
  String _viMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    if (m.contains('email not confirmed')) {
      return 'Email chưa được xác thực. Kiểm tra hộp thư để kích hoạt tài khoản.';
    }
    if (m.contains('too many requests') || m.contains('rate limit')) {
      return 'Bạn thử quá nhiều lần. Đợi một lát rồi đăng nhập lại.';
    }
    return e.message;
  }
}
