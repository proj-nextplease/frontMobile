import 'package:flutter/widgets.dart';

import 'np_icons.dart';

/// Một mẩu tin trượt xuống từ đỉnh màn hình.
///
/// Tách khỏi NotificationItem vì banner giờ có HAI nguồn: thông báo từ máy
/// chủ, và nhiệm vụ vừa hoàn thành ngay trong máy. Buộc nguồn thứ hai phải
/// giả vờ thành một NotificationItem sẽ kéo theo cả id giả — mà id đó lại đi
/// thẳng vào lệnh "đánh dấu đã đọc" gửi lên máy chủ.
@immutable
class AppBanner {
  const AppBanner({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    this.onTap,
  });

  /// Chỉ dùng để phân biệt banner này với banner kia (khoá của AnimatedSwitcher
  /// và Dismissible). KHÔNG bao giờ gửi lên máy chủ.
  final String id;

  final String title;
  final String body;
  final NpIcon icon;

  /// Null thì banner chỉ để đọc, bấm vào chỉ đóng lại.
  final VoidCallback? onTap;
}
