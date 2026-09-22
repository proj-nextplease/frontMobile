import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/app_banner.dart';
import '../../core/np_icons.dart';

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

  /// Thông báo VỪA xuất hiện, để chỗ nào đó trong app hiện banner.
  ///
  /// Dùng stream broadcast chứ không phải notifyListeners: một thông báo mới
  /// là một SỰ KIỆN xảy ra một lần, còn listener thì chạy lại mỗi lần bất kỳ
  /// thứ gì trong kho đổi — kể cả lúc người dùng bấm "đã đọc". Trộn hai thứ
  /// đó lại là cách chắc chắn để banner hiện lại lúc không ai mong.
  final _incoming = StreamController<AppBanner>.broadcast();
  Stream<AppBanner> get incoming => _incoming.stream;

  /// Cần cho nơi dựng banner: nó chỉ nhận được AppBanner, nhưng khi người
  /// dùng bấm thì phải tìm lại bản gốc để biết mở đi đâu.
  NotificationItem? byId(String id) {
    for (final n in items) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Id đã từng thấy. Chỉ dùng để phân biệt "mới đến" với "đã có từ trước".
  final Set<String> _seenIds = {};

  Timer? _poll;

  /// Khoảng cách giữa hai lần hỏi máy chủ.
  ///
  /// 15 giây. Không có push hệ điều hành thì hỏi vòng là cách duy nhất, nên
  /// con số này là một đánh đổi chứ không phải hằng số tuỳ ý: mỗi giờ app mở
  /// là khoảng 240 lượt gọi `/me/notifications`, gấp ba so với 45 giây.
  ///
  /// Chấp nhận được vì vòng lặp CHỈ chạy khi app ở tiền cảnh và đã đăng nhập
  /// (xem stopPolling và didChangeAppLifecycleState trong app.dart) — app nằm
  /// trong túi thì không gọi lần nào. Nếu sau này số người dùng lớn lên và
  /// endpoint này thành điểm nóng, đây là chỗ đầu tiên cần nhìn lại.
  static const _interval = Duration(seconds: 15);

  /// Bắt đầu hỏi máy chủ định kỳ. Gọi khi có phiên và app đang ở tiền cảnh.
  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_interval, (_) => hydrate());
  }

  /// Dừng khi app xuống nền hoặc đăng xuất. Thiếu chỗ này thì app vẫn gọi
  /// mạng đều đặn trong lúc nằm trong túi.
  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> hydrate() async {
    try {
      final data = await _api.get('/me/notifications');
      if (data is! Map) return;
      final next = (data['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(NotificationItem.fromJson)
              .toList() ??
          const <NotificationItem>[];

      // Lần nạp ĐẦU TIÊN chỉ ghi nhận, không bắn sự kiện: không thì vừa đăng
      // nhập là ba mươi banner đổ xuống cùng lúc.
      final first = !loaded;
      final fresh = <NotificationItem>[];
      for (final n in next) {
        if (_seenIds.add(n.id) && !first && !n.isRead) fresh.add(n);
      }

      items = next;
      unread = (data['unreadCount'] as num?)?.toInt() ?? 0;
      loaded = true;
      notifyListeners();

      // Cũ trước mới sau, và chỉ lấy ba cái gần nhất. Nhiều hơn thì banner
      // xếp hàng chờ nhau và cái cuối hiện ra khi đã hết liên quan.
      for (final n in fresh.reversed.take(3).toList().reversed) {
        _incoming.add(AppBanner(
          id: n.id,
          title: n.title.isEmpty ? 'Thông báo mới' : n.title,
          body: n.body,
          icon: NpIcon.bell,
        ));
      }
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

  /// Chỉ dành cho kiểm thử: bắn một thông báo vào luồng mà không cần mạng.
  ///
  /// Có mặt ở đây thay vì để test tự dựng một kho giả, vì thứ đáng kiểm là
  /// ĐÚNG luồng mà app dùng thật, không phải một bản sao của nó.
  @visibleForTesting
  void debugEmit(NotificationItem item) => _incoming.add(AppBanner(
        id: item.id,
        title: item.title.isEmpty ? 'Thông báo mới' : item.title,
        body: item.body,
        icon: NpIcon.bell,
      ));

  void clear() {
    stopPolling();
    items = const [];
    unread = 0;
    loaded = false;
    // Xoá cả id đã thấy: người tiếp theo đăng nhập trên cùng thiết bị phải
    // được coi như chưa thấy gì, không thì thông báo của họ bị nuốt vì trùng
    // id với phiên trước.
    _seenIds.clear();
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
    this.link,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String? type;

  /// Đường dẫn của WEBSITE ("/discussions/…", "/jobs/…"). KHÔNG mở thẳng —
  /// NotificationRouter dịch nó sang màn hình trong app.
  final String? link;

  final DateTime? createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> m) => NotificationItem(
        id: '${m['id']}',
        title: '${m['title'] ?? ''}'.trim(),
        body: '${m['body'] ?? ''}'.trim(),
        isRead: m['isRead'] == true,
        type: (m['type'] as String?)?.trim(),
        link: (m['link'] as String?)?.trim(),
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
        link: link,
        createdAt: createdAt,
      );
}
