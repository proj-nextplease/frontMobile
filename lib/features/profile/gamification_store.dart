import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// Tiến trình của người dùng: cấp, EXP, chuỗi ngày, và nhiệm vụ ngày/tuần.
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
  int longestStreak = 0;

  /// Đã ghi nhận hoạt động hôm nay chưa. Dùng để KHÔNG gọi ping lặp lại trong
  /// cùng một ngày.
  bool activeToday = false;

  List<DailyQuest> daily = const [];
  List<DailyQuest> weekly = const [];
  bool loaded = false;

  /// Nhiệm vụ đã xong mà CHƯA nhận thưởng — thứ đáng nhắc người dùng nhất.
  List<DailyQuest> get claimable =>
      [...daily, ...weekly].where((q) => q.completed && !q.claimed).toList();

  /// 0..1. Trả 0 khi chưa có dữ liệu hoặc mốc lên cấp bằng 0 — chia cho 0 ở
  /// đây sẽ ra NaN và Flutter vẽ ra một vạch rộng vô hạn.
  double get progress {
    if (expForNextLevel <= 0) return 0;
    return (expIntoLevel / expForNextLevel).clamp(0.0, 1.0);
  }

  Future<void> hydrate() async {
    try {
      _apply(await _api.get('/me/gamification'));
    } on ApiException {
      // Chưa đăng nhập hoặc endpoint hỏng: vạch EXP đơn giản là không hiện.
      // Không phải sự cố cần báo cho người dùng.
    }
  }

  /// Đánh dấu hoạt động hôm nay: đẩy chuỗi ngày lên và hoàn thành nhiệm vụ
  /// "Ghé thăm mỗi ngày".
  ///
  /// ─── Vì sao hàm này quan trọng ───────────────────────────────────────
  /// App TRƯỚC ĐÂY không bao giờ gọi nó. Web gọi mỗi lần mở dashboard, còn
  /// mobile chỉ ĐỌC chuỗi ngày rồi hiện ra. Hệ quả: người chỉ dùng mobile có
  /// chuỗi ngày đứng yên vĩnh viễn — app hiện một con số mà chính nó không
  /// bao giờ làm tăng được.
  ///
  /// Gọi lại trong cùng một ngày là vô hại (backend idempotent theo
  /// last_active_date), nhưng vẫn chặn ở đây để khỏi tốn một lượt gọi mạng
  /// mỗi lần người dùng chuyển app ra vào.
  Future<void> ping({bool force = false}) async {
    if (activeToday && !force) return;
    try {
      _apply(await _api.post('/me/gamification/ping'));
    } on ApiException {
      // Không nói gì: chuỗi ngày không tăng được là chuyện của hệ thống, và
      // người dùng không làm gì sai để phải nhận một thông báo lỗi.
    }
  }

  /// Ghi nhận một hành động đếm vào nhiệm vụ.
  ///
  /// Danh sách sự kiện lấy từ CATALOG của backend: VIEW_OPPORTUNITY, APPLY,
  /// SUBMIT_PROOF. Gửi tên khác thì backend lặng lẽ bỏ qua, nên đừng tự nghĩ
  /// thêm tên mới ở đây.
  Future<void> record(GameEvent event, {int amount = 1}) async {
    try {
      _apply(await _api.post('/me/gamification/events',
          body: {'event': event.wire, 'amount': amount}));
    } on ApiException {
      // Mất một lượt đếm nhiệm vụ không đáng để chặn luồng chính.
    }
  }

  /// Nhận thưởng EXP của một nhiệm vụ đã hoàn thành.
  ///
  /// Trả lỗi (chuỗi) để nơi gọi hiện ra — khác với ping và record, đây là
  /// hành động người dùng CHỦ ĐỘNG bấm, nên im lặng khi hỏng là sai.
  Future<String?> claim(DailyQuest quest) async {
    try {
      _apply(await _api.post(
          '/me/gamification/quests/${quest.scope}/${quest.key}/claim'));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void _apply(Object? data) {
    if (data is! Map) return;
    level = _int(data['level']);
    expIntoLevel = _int(data['expIntoLevel']);
    expForNextLevel = _int(data['expForNextLevel']);
    streak = _int(data['currentStreak'] ?? data['streak']);
    longestStreak = _int(data['longestStreak']);
    activeToday = data['activeToday'] == true;
    daily = _quests(data['dailyQuests']);
    weekly = _quests(data['weeklyQuests']);
    loaded = true;
    notifyListeners();
  }

  List<DailyQuest> _quests(Object? v) => (v is List)
      ? v.whereType<Map<String, dynamic>>().map(DailyQuest.fromJson).toList()
      : const [];

  void clear() {
    level = expIntoLevel = expForNextLevel = 0;
    streak = longestStreak = 0;
    activeToday = false;
    daily = weekly = const [];
    loaded = false;
    notifyListeners();
  }

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}

/// Sự kiện đếm vào nhiệm vụ.
///
/// `wire` phải TRÙNG chính xác với QuestDef.event() ở backend — gửi tên khác
/// thì backend lặng lẽ bỏ qua và nhiệm vụ không bao giờ nhích. Tách ra khỏi
/// tên hằng để tên Dart theo lowerCamelCase mà chuỗi gửi đi vẫn đúng.
enum GameEvent {
  viewOpportunity('VIEW_OPPORTUNITY'),
  apply('APPLY'),
  submitProof('SUBMIT_PROOF');

  const GameEvent(this.wire);
  final String wire;
}

class DailyQuest {
  const DailyQuest({
    required this.key,
    required this.scope,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.exp,
    required this.completed,
    required this.claimed,
  });

  final String key;

  /// "DAILY" hoặc "WEEKLY". Giữ nguyên chữ hoa vì nó đi thẳng vào URL nhận
  /// thưởng, và backend so khớp không phân biệt hoa thường nhưng đường dẫn
  /// thì nên khớp đúng những gì nó trả về.
  final String scope;

  final String title;
  final String description;
  final int progress;
  final int target;
  final int exp;
  final bool completed;
  final bool claimed;

  /// 0..1. Target bằng 0 là dữ liệu hỏng, trả 0 thay vì để chia cho 0.
  double get ratio => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  factory DailyQuest.fromJson(Map<String, dynamic> m) => DailyQuest(
        key: '${m['key'] ?? ''}',
        scope: '${m['scope'] ?? 'DAILY'}',
        title: '${m['title'] ?? ''}',
        description: '${m['desc'] ?? ''}',
        progress: (m['progress'] as num?)?.toInt() ?? 0,
        target: (m['target'] as num?)?.toInt() ?? 0,
        exp: (m['exp'] as num?)?.toInt() ?? 0,
        completed: m['completed'] == true,
        claimed: m['claimed'] == true,
      );
}
