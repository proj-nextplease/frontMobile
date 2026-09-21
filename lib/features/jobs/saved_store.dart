import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import 'opportunity.dart';

/// Kho trạng thái "đã lưu", dùng chung cho mọi màn hình.
///
/// Vì sao phải có một kho dùng chung thay vì để mỗi thẻ tự giữ trạng thái:
/// cùng một tin xuất hiện ở danh sách VÀ ở trang chi tiết. Bấm tim ở trang chi
/// tiết mà danh sách phía dưới không đổi theo thì người dùng sẽ tưởng thao tác
/// không ăn. Bên web đã mắc đúng lỗi này (xem FE/src/lib/savedJobs.js).
///
/// API là nguồn sự thật, kho này chỉ là bản sao trong bộ nhớ để giao diện phản
/// hồi tức thì.
class SavedStore extends ChangeNotifier {
  SavedStore._();

  /// Một thực thể duy nhất cho cả app. Không dùng provider/riverpod vì app
  /// hiện chỉ có một mẩu trạng thái chia sẻ; kéo cả một thư viện quản lý trạng
  /// thái về cho đúng một Set là thừa.
  static final instance = SavedStore._();

  final _api = ApiClient();

  final Set<String> _jobIds = {};
  final Set<String> _questIds = {};

  /// Các id đang có lệnh gọi mạng dở dang. Dùng để khoá nút, tránh bấm liên
  /// tục sinh ra hai lệnh ngược nhau chạy song song.
  final Set<String> _busy = {};

  bool isSaved(Opportunity o) =>
      (o.isQuest ? _questIds : _jobIds).contains(o.id);

  bool isBusy(String id) => _busy.contains(id);

  int get count => _jobIds.length + _questIds.length;

  /// Nạp danh sách đã lưu từ máy chủ. Gọi sau khi đăng nhập.
  ///
  /// Dùng endpoint /ids chứ không phải /me/saved-jobs: ở đây chỉ cần biết
  /// tin nào đã lưu, kéo về cả nội dung tin là lãng phí băng thông.
  Future<void> hydrate() async {
    final results = await Future.wait([
      _idsOrEmpty('/me/saved-jobs/ids'),
      _idsOrEmpty('/me/saved-quests/ids'),
    ]);
    _jobIds
      ..clear()
      ..addAll(results[0]);
    _questIds
      ..clear()
      ..addAll(results[1]);
    notifyListeners();
  }

  /// Xoá sạch khi đăng xuất. Không gọi là người tiếp theo đăng nhập trên cùng
  /// thiết bị sẽ thấy tim của người trước.
  void clear() {
    _jobIds.clear();
    _questIds.clear();
    _busy.clear();
    notifyListeners();
  }

  /// Bật/tắt lưu. Trả null nếu thành công, hoặc thông điệp lỗi.
  ///
  /// Cập nhật giao diện TRƯỚC rồi mới gọi mạng, và hoàn tác nếu hỏng. Đợi máy
  /// chủ trả lời mới đổi tim khiến thao tác có cảm giác trễ, trong khi đây là
  /// hành động người dùng làm liên tục khi lướt danh sách.
  Future<String?> toggle(Opportunity o) async {
    if (_busy.contains(o.id)) return null;

    final set = o.isQuest ? _questIds : _jobIds;
    final wasSaved = set.contains(o.id);

    _busy.add(o.id);
    wasSaved ? set.remove(o.id) : set.add(o.id);
    notifyListeners();

    final path = o.isQuest ? '/quests/${o.id}/save' : '/jobs/${o.id}/save';
    try {
      if (wasSaved) {
        await _api.delete(path);
      } else {
        await _api.post(path);
      }
      return null;
    } on ApiException catch (e) {
      // Hoàn tác: giao diện phải nói đúng trạng thái trên máy chủ.
      wasSaved ? set.add(o.id) : set.remove(o.id);
      return e.message;
    } finally {
      _busy.remove(o.id);
      notifyListeners();
    }
  }

  /// Trả về tập rỗng khi hỏng thay vì ném lỗi: chưa đăng nhập thì endpoint này
  /// trả 401, và đó là trạng thái bình thường chứ không phải sự cố.
  Future<Set<String>> _idsOrEmpty(String path) async {
    try {
      final data = await _api.get(path);
      if (data is List) return data.map((e) => '$e').toSet();
    } on ApiException {
      // bỏ qua
    }
    return {};
  }
}
