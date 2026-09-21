import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// Thông báo của người dùng.
///
/// Backend đã có sẵn cả hệ thống này (bảng notifications, ba endpoint dưới
/// /me/notifications, và cả gửi email theo tuỳ chọn) nhưng app chưa dùng dòng
/// nào. Hệ quả: sau khi nộp đơn, app hiện câu "Tổ chức sẽ phản hồi qua thông
/// báo" — một lời hứa mà chính nó không giữ được.
class NotificationsStore extends ChangeNotifier {
  NotificationsStore._();
  static final instance = NotificationsStore._();

  final _api = ApiClient();

  List<NotificationItem> items = const [];
  int unread = 0;
  bool loaded = false;

  Future<void> hydrate() async {
    try {
      final data = await _api.get('/me/notifications');
      if (data is! Map) return;
      items = (data['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(NotificationItem.fromJson)
              .toList() ??
          const [];
      unread = (data['unreadCount'] as num?)?.toInt() ?? 0;
      loaded = true;
      notifyListeners();
    } on ApiException {
      // Khách hoặc endpoint hỏng: chuông đơn giản là không có số.
    }
  }

  /// Đánh dấu đã đọc. Đổi trên giao diện TRƯỚC rồi mới gọi mạng, và trả lại
  /// như cũ nếu hỏng — chờ máy chủ xong mới đổi thì cái chấm đỏ còn nằm đó
  /// vài trăm mili giây sau khi người dùng đã mở, trông như thao tác hụt.
  Future<void> markRead(String id) async {
    final i = items.indexWhere((e) => e.id == id);
    if (i < 0 || items[i].isRead) return;

    final before = items;
    final beforeUnread = unread;
    items = [...items]..[i] = items[i].asRead();
    unread = (unread - 1).clamp(0, 1 << 30);
    notifyListeners();

    try {
      await _api.patch('/me/notifications/$id/read');
    } on ApiException {
      items = before;
      unread = beforeUnread;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    final before = items;
    final beforeUnread = unread;
    items = [for (final e in items) e.asRead()];
    unread = 0;
    notifyListeners();

    try {
      await _api.patch('/me/notifications/read-all');
    } on ApiException {
      items = before;
      unread = beforeUnread;
      notifyListeners();
    }
  }

  void clear() {
    items = const [];
    unread = 0;
    loaded = false;
    notifyListeners();
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.type,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String? type;
  final DateTime? createdAt;

  /// `link` cố tình KHÔNG đọc: nó là đường dẫn của WEBSITE (NotificationService
  /// tự ghép tiền tố APP_PUBLIC_URL). Mở nó trong app sẽ đá người dùng ra
  /// trình duyệt giữa chừng. Muốn dùng thì phải ánh xạ sang route của app —
  /// việc đó để sau.
  factory NotificationItem.fromJson(Map<String, dynamic> m) => NotificationItem(
        id: '${m['id']}',
        title: '${m['title'] ?? ''}'.trim(),
        body: '${m['body'] ?? ''}'.trim(),
        isRead: m['isRead'] == true,
        type: (m['type'] as String?)?.trim(),
        createdAt: m['createdAt'] == null
            ? null
            : DateTime.tryParse('${m['createdAt']}')?.toLocal(),
      );

  NotificationItem asRead() => NotificationItem(
        id: id,
        title: title,
        body: body,
        isRead: true,
        type: type,
        createdAt: createdAt,
      );
}
