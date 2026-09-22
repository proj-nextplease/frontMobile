/// Khoá cấu hình, nạp lúc biên dịch.
///
/// Truyền qua --dart-define-from-file=env.json. File env.json nằm trong
/// .gitignore; env.example.json là bản mẫu để người mới biết cần điền gì.
///
///     flutter run --dart-define-from-file=env.json
///
/// Vì sao không nhét thẳng vào mã nguồn: anon key tuy được thiết kế để lộ ra
/// phía client (web cũng gửi kèm trong bundle), nhưng nằm trong lịch sử git
/// thì không xoá đi được nữa nếu sau này dự án đổi khoá hoặc đổi chế độ repo.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep link Supabase gọi về sau khi đăng nhập OAuth xong. Phải trùng với
  /// mục Redirect URLs trong Supabase Dashboard, và trùng với URL scheme khai
  /// báo ở Info.plist (iOS) và AndroidManifest.xml (Android). Lệch một chỗ là
  /// trình duyệt mở xong không quay về app được.
  static const oauthCallback = 'vn.nextplease.mobile://login-callback';

  /// Nơi email đặt lại mật khẩu trỏ về.
  ///
  /// Trỏ sang TRANG WEB chứ không deep link về app. Deep link đẹp hơn nhưng
  /// đòi thêm một mục trong Redirect URLs của Supabase và một màn đặt mật khẩu
  /// mới trong app; trang web thì đã có sẵn và đã chạy. Người dùng bấm link
  /// trong mail, đổi mật khẩu trên web, rồi quay lại app đăng nhập.
  ///
  /// Đổi được lúc build: --dart-define=RESET_PASSWORD_URL=...
  static const resetPasswordUrl = String.fromEnvironment(
    'RESET_PASSWORD_URL',
    defaultValue: 'https://nextplease.vercel.app/reset-password?role=candidate',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
