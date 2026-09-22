import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'notifications_page.dart';
import 'notifications_store.dart';

/// Chuông thông báo, dùng chung cho MỌI tab.
///
/// Trước đây mỗi tab tự dựng một cái: trang chủ một bản, tab Hồ sơ một bản
/// gần giống. Hai bản chép tay là hai chỗ để lệch nhau khi sửa, và hai tab
/// còn lại thì không có chuông nào — người dùng đang ở tab Cơ hội hay Thảo
/// luận thì không có cách nào biết có tin mới ngoài cái chấm nhỏ trên thanh
/// điều hướng.
///
/// Tự nghe kho nên nơi đặt nó không cần biết gì về thông báo.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.size = 21, this.color});

  final double size;

  /// Màu biểu tượng. Null thì dùng màu chữ chính của nền hiện tại.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return ListenableBuilder(
      listenable: NotificationsStore.instance,
      builder: (context, _) {
        final unread = NotificationsStore.instance.unread;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: size + 19,
            height: size + 19,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                NpIco(NpIcon.bell, size: size, color: color ?? c.ink),
                if (unread > 0)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.danger,
                        borderRadius: BorderRadius.circular(Np.rPill),
                        // Viền cùng màu nền để con số tách khỏi biểu tượng bên
                        // dưới; thiếu nó thì hai thứ dính thành một khối.
                        border: Border.all(color: c.bg, width: 1.5),
                      ),
                      child: Text(unread > 9 ? '9+' : '$unread',
                          style: NpType.meta.copyWith(
                            fontSize: 10,
                            height: 1.1,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
