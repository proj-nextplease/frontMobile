import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// Tiến trình của người dùng: cấp, EXP, chuỗi ngày.
///
/// Tách thành kho riêng vì thanh điều hướng cần nó ở MỌI màn hình, không chỉ
/// tab Hồ sơ. Đây là lý do vạch EXP đáng đưa lên thanh: nó là bề mặt duy nhất
/// luôn hiện, mà lời hứa của sản phẩm — mỗi việc hoàn thành là một minh chứng
/// — lại đang bị giấu trong một tab người dùng hiếm khi mở.
class GamificationStore extends ChangeNotifier {
  GamificationStore._();
  static final instance = GamificationStore._();

  final _api = ApiClient();

  int level = 0;
  int expIntoLevel = 0;
  int expForNextLevel = 0;
  int streak = 0;
  bool loaded = false;

  /// 0..1. Trả 0 khi chưa có dữ liệu hoặc mốc lên cấp bằng 0 — chia cho 0 ở
  /// đây sẽ ra NaN và Flutter vẽ ra một vạch rộng vô hạn.
  double get progress {
    if (expForNextLevel <= 0) return 0;
    return (expIntoLevel / expForNextLevel).clamp(0.0, 1.0);
  }

  Future<void> hydrate() async {
    try {
      final data = await _api.get('/me/gamification');
      if (data is! Map) return;
      level = _int(data['level']);
      expIntoLevel = _int(data['expIntoLevel']);
      expForNextLevel = _int(data['expForNextLevel']);
      streak = _int(data['currentStreak'] ?? data['streak']);
      loaded = true;
      notifyListeners();
    } on ApiException {
      // Chưa đăng nhập hoặc endpoint hỏng: vạch EXP đơn giản là không hiện.
      // Không phải sự cố cần báo cho người dùng.
    }
  }

  void clear() {
    level = 0;
    expIntoLevel = 0;
    expForNextLevel = 0;
    streak = 0;
    loaded = false;
    notifyListeners();
  }

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}
