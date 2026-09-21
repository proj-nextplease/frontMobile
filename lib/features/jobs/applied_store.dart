import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../profile/application_item.dart';
import 'opportunity.dart';

/// Những cơ hội người dùng ĐÃ nộp đơn.
///
/// Backend chặn nộp trùng bằng lỗi ALREADY_APPLIED, nhưng chặn ở đó là chặn
/// SAU KHI người dùng đã mở ô lời nhắn, gõ xong và bấm gửi. Biết trước thì
/// nút ứng tuyển đổi thành "Đã nộp" ngay từ đầu.
///
/// Chỉ giữ ID chứ không giữ cả đơn: nơi cần chi tiết là trang Đơn đã nộp, và
/// nó tự gọi API riêng.
class AppliedStore extends ChangeNotifier {
  AppliedStore._();
  static final instance = AppliedStore._();

  final _api = ApiClient();

  final Set<String> _jobIds = {};
  final Set<String> _questIds = {};

  /// Số đơn chưa có kết luận. Để ở đây chứ không ở màn Hồ sơ vì cùng một lệnh
  /// gọi mạng đã lấy được — tính ở chỗ khác là gọi API lần hai cho cùng dữ liệu.
  int openCount = 0;
  bool loaded = false;

  bool hasApplied(Opportunity o) =>
      (o.isQuest ? _questIds : _jobIds).contains(o.id);

  /// Đánh dấu ngay sau khi nộp thành công, không đợi nạp lại từ máy chủ.
  void markApplied(Opportunity o) {
    (o.isQuest ? _questIds : _jobIds).add(o.id);
    notifyListeners();
  }

  Future<void> hydrate() async {
    final res = await Future.wait([
      _try('/me/applications'),
      _try('/me/quest-applications'),
    ]);
    if (res[0] == null && res[1] == null) return;

    _jobIds
      ..clear()
      // Khoá ngoại nằm ở `job_id` (snake) với đơn tin tuyển dụng và `questId`
      // (camel) với đơn quest — hai endpoint đặt tên khác nhau, xem
      // ApplicationService và QuestService.
      ..addAll(_ids(res[0], 'job_id'));
    _questIds
      ..clear()
      ..addAll(_ids(res[1], 'questId'));

    openCount = [...?res[0], ...?res[1]]
        .whereType<Map<String, dynamic>>()
        .where((m) =>
            kOpenStatuses.contains('${m['status'] ?? ''}'.toUpperCase()))
        .length;
    loaded = true;
    notifyListeners();
  }

  /// Đơn đã RÚT thì không tính là đã nộp — người dùng được nộp lại.
  Iterable<String> _ids(List<dynamic>? raw, String key) =>
      (raw ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((m) => '${m['status'] ?? ''}'.toUpperCase() != 'WITHDRAWN')
          .map((m) => '${m[key] ?? ''}')
          .where((s) => s.isNotEmpty);

  void clear() {
    _jobIds.clear();
    _questIds.clear();
    openCount = 0;
    loaded = false;
    notifyListeners();
  }

  Future<List<dynamic>?> _try(String path) async {
    try {
      final d = await _api.get(path);
      return d is List ? d : const [];
    } on ApiException {
      return null;
    }
  }
}
