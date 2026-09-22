import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Lỗi đến từ API, đã bóc sẵn thông điệp tiếng Việt do backend trả về.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Lớp gọi HTTP mỏng, đúng theo hình dạng phản hồi của backend nextplease.
///
/// Mọi endpoint đều bọc dữ liệu trong ApiResponse:
///     { "success": true, "data": ..., "message": null, "errorCode": null }
/// nên chỗ nào cũng phải bóc `data` ra. Gom vào một nơi để không lặp lại ở
/// từng màn hình, và để khi backend đổi hình dạng thì chỉ sửa một chỗ.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Nguồn token, cắm một lần lúc khởi động app.
  ///
  /// Đặt ở đây thay vì để mỗi nơi tự truyền token vào: token đổi mỗi lần đăng
  /// nhập, đăng xuất hoặc làm mới phiên, mà các repository thì được tạo rải
  /// rác. Bản trước có trường `accessToken` nhưng KHÔNG AI GÁN, nên mọi lệnh
  /// gọi cần đăng nhập đều đi ra không kèm token và nhận 401 — lỗi này im
  /// lặng vì các endpoint công khai vẫn chạy bình thường.
  ///
  /// Là hàm chứ không phải giá trị: phải đọc lại ở TỪNG lệnh gọi, vì Supabase
  /// tự làm mới token nền và giá trị chụp sẵn sẽ hết hạn.
  static String? Function()? tokenProvider;

  Map<String, String> get _headers {
    final token = tokenProvider?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
    return _send(() => _client.get(uri, headers: _headers));
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    return _send(() => _client.delete(uri, headers: _headers));
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    return _send(
      () => _client.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    return _send(
      () => _client.put(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  /// PATCH. Backend dùng động từ này cho các thao tác đổi MỘT phần trạng thái
  /// (rút đơn, đánh dấu đã đọc), nên không thay bằng post được — Spring định
  /// tuyến theo động từ và POST vào cùng đường dẫn sẽ trả 405.
  Future<dynamic> patch(String path, {Object? body}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    return _send(
      () => _client.patch(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    late http.Response res;
    try {
      res = await run().timeout(const Duration(seconds: 20));
    } on SocketException {
      // Lỗi hay gặp nhất lúc phát triển, và thông báo mặc định của Dart thì
      // vô dụng với người đọc. Nói thẳng nghi phạm số một.
      throw ApiException(
        'Không kết nối được máy chủ (${AppConfig.baseUrl}).\n'
        'Kiểm tra backend đã chạy chưa, và nếu đang dùng máy thật thì phải '
        'truyền IP LAN qua --dart-define=API_BASE_URL.',
      );
    } on HttpException {
      throw ApiException('Máy chủ trả về phản hồi không hợp lệ.');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Phản hồi không phải JSON (HTTP ${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    // Backend trả HTTP 200 kèm success=false ở một số nhánh, nên xét cả hai
    // chứ không chỉ mã trạng thái.
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (!ok || json['success'] != true) {
      throw ApiException(
        (json['message'] as String?) ?? 'Yêu cầu thất bại (HTTP ${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    return json['data'];
  }
}
