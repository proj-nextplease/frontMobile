import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Cấu hình môi trường.
class AppConfig {
  /// Địa chỉ gốc của API.
  ///
  /// Có một cái bẫy ở đây mà ai làm mobile lần đầu cũng vấp: `localhost` trên
  /// máy ảo KHÔNG trỏ về máy tính của bạn.
  ///
  ///   - Simulator iOS dùng chung ngăn xếp mạng với macOS, nên `localhost` đúng.
  ///   - Emulator Android là một máy ảo riêng. `localhost` ở đó là chính nó,
  ///     và backend trên máy tính phải gọi qua địa chỉ đặc biệt `10.0.2.2`.
  ///   - Máy THẬT thì cả hai đều sai, phải dùng IP LAN của máy tính
  ///     (vd http://192.168.1.12:8080). Lúc đó truyền qua --dart-define.
  ///
  /// Ghi đè khi chạy:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.12:8080
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  static String get apiUrl => '$baseUrl/api/v1';

  /// Địa chỉ trang web, KHÔNG phải địa chỉ API.
  ///
  /// Hai thứ khác nhau và không suy ra được từ nhau: lúc dev thì API chạy ở
  /// localhost còn trang web công khai vẫn là bản đã deploy. Dùng cho link hồ
  /// sơ công khai (`/p/<slug>`) và hai văn bản pháp lý (/terms, /privacy) —
  /// những trang app không tự dựng lại mà mở thẳng ra trình duyệt.
  ///
  /// Ghi đè: --dart-define=WEB_BASE_URL=https://nextplease.vn
  static String get webBaseUrl {
    const override = String.fromEnvironment('WEB_BASE_URL');
    return override.isNotEmpty ? override : 'https://nextplease.vercel.app';
  }

  /// Backend đang chạy trên máy dev là HTTP thuần. Cả iOS lẫn Android đều CHẶN
  /// HTTP không mã hoá theo mặc định, nên phần khai báo ngoại lệ nằm ở
  /// ios/Runner/Info.plist và android/.../network_security_config.xml.
  /// Khi lên production phải là HTTPS và gỡ hai ngoại lệ đó đi.
  static const bool isDev = true;
}
