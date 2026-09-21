import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'opportunity.dart';

/// Ghi nhớ mốc thời gian người dùng xem danh sách cơ hội lần cuối.
///
/// Dùng để biết có tin nào đăng SAU lần đó không — tức là "tin mới với riêng
/// người này", khác hẳn "tin mới nhất trong hệ thống".
///
/// Lưu bằng SharedPreferences chứ không phải secure storage: đây là một mốc
/// thời gian, không phải bí mật. Nhét vào Keychain thì vừa thừa vừa làm lẫn
/// lộn ranh giới giữa dữ liệu nhạy cảm và dữ liệu thường.
class SeenStore extends ChangeNotifier {
  SeenStore._();
  static final instance = SeenStore._();

  static const _key = 'nextplease.opportunities.seenAt';

  DateTime? _seenAt;
  int _newCount = 0;

  int get newCount => _newCount;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _seenAt = raw == null ? null : DateTime.tryParse(raw);
  }

  /// Đếm lại số tin mới. Gọi mỗi khi danh sách được nạp.
  void recount(List<Opportunity> items) {
    final since = _seenAt;
    // Lần đầu mở app thì KHÔNG báo gì. Coi toàn bộ danh sách là mới sẽ hiện
    // một chấm đỏ vô nghĩa — người dùng chưa bỏ lỡ điều gì cả.
    final n = since == null
        ? 0
        : items.where((o) {
            final t = o.createdAt;
            return t != null && t.isAfter(since);
          }).length;
    if (n == _newCount) return;
    _newCount = n;
    notifyListeners();
  }

  /// Đánh dấu đã xem. Gọi khi người dùng mở tab Cơ hội.
  Future<void> markSeen() async {
    _seenAt = DateTime.now();
    _newCount = 0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _seenAt!.toIso8601String());
  }
}
