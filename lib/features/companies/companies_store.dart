import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import 'company.dart';

/// Danh bạ đối tác và danh sách đang theo dõi.
///
/// /me/followed-companies chỉ trả về MẢNG UUID, không kèm tên hay logo. Nên
/// màn "đang theo dõi" phải ghép id đó với danh bạ /companies lấy ở đây —
/// không có danh bạ thì màn đó chỉ là một danh sách UUID.
class CompaniesStore extends ChangeNotifier {
  CompaniesStore._();
  static final instance = CompaniesStore._();

  final _api = ApiClient();

  List<Company> all = const [];
  Set<String> followedIds = {};

  bool loaded = false;

  /// Các id đang chờ máy chủ trả lời. Dùng để khoá riêng từng nút thay vì
  /// khoá cả màn.
  final Set<String> pending = {};

  List<Company> get followed =>
      all.where((c) => followedIds.contains(c.id)).toList();

  bool isFollowing(String id) => followedIds.contains(id);

  Future<void> hydrate() async {
    await Future.wait([_loadDirectory(), _loadFollowed()]);
    loaded = true;
    notifyListeners();
  }

  Future<void> _loadDirectory() async {
    try {
      final data = await _api.get('/companies');
      if (data is List) {
        all = data
            .whereType<Map<String, dynamic>>()
            .map(Company.fromJson)
            .toList();
      }
    } on ApiException {
      // Giữ nguyên danh bạ cũ: xoá trắng khi mạng chập là cách biến một lỗi
      // tạm thời thành màn hình trống.
    }
  }

  Future<void> _loadFollowed() async {
    try {
      final data = await _api.get('/me/followed-companies');
      if (data is List) {
        followedIds = data.map((e) => '$e').toSet();
      }
    } on ApiException {
      // Khách chưa đăng nhập: không theo dõi ai, không phải lỗi.
    }
  }

  /// Bật/tắt theo dõi. Trả null khi xong, chuỗi lỗi khi hỏng.
  Future<String?> toggle(String companyId) async {
    if (pending.contains(companyId)) return null;

    final wasFollowing = followedIds.contains(companyId);

    // Đổi trước, hoàn lại nếu hỏng. Nút theo dõi phải phản hồi tức thì; chờ
    // một vòng mạng rồi mới đổi màu thì cảm giác như bấm hụt.
    pending.add(companyId);
    wasFollowing ? followedIds.remove(companyId) : followedIds.add(companyId);
    notifyListeners();

    String? err;
    try {
      if (wasFollowing) {
        await _api.delete('/companies/$companyId/follow');
      } else {
        await _api.post('/companies/$companyId/follow');
      }
    } on ApiException catch (e) {
      err = e.message;
      wasFollowing ? followedIds.add(companyId) : followedIds.remove(companyId);
    }

    pending.remove(companyId);
    notifyListeners();
    return err;
  }

  /// Chi tiết một đối tác, kèm followerCount mà danh sách không có.
  Future<Company?> detail(String id) async {
    try {
      final data = await _api.get('/companies/$id');
      if (data is Map<String, dynamic>) return Company.fromJson(data);
    } on ApiException {
      // Rơi về bản rút gọn trong danh bạ nếu có.
    }
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  void clear() {
    followedIds = {};
    pending.clear();
    notifyListeners();
  }
}
