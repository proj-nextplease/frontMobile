import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'notifications_page.dart';
import 'notifications_store.dart';

/// Banner nhắc trong app.
///
/// ─── Vì sao KHÔNG dùng SnackBar ──────────────────────────────────────────
/// SnackBar trượt lên từ ĐÁY, đúng chỗ thanh điều hướng nổi đang nằm, nên nó
/// vừa che mất thanh vừa đọc ra như một thông báo kết quả của thao tác người
/// dùng vừa làm. Thông báo từ máy chủ không phải kết quả của thao tác nào cả
/// — nó đến từ ngoài, nên nó xuất hiện từ trên xuống, giống chỗ mà thông báo
/// hệ điều hành sẽ rơi xuống nếu sau này bật push thật.
///
/// Đây là NHẮC TRONG APP, không phải push: app đóng lại thì không có gì.
class NotificationBannerHost extends StatefulWidget {
  const NotificationBannerHost({super.key, required this.child});
  final Widget child;

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  StreamSubscription<NotificationItem>? _sub;
  Timer? _hide;

  NotificationItem? _current;

  @override
  void initState() {
    super.initState();
    _sub = NotificationsStore.instance.incoming.listen(_show);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  void _show(NotificationItem n) {
    if (!mounted) return;
    // Cái mới ĐÈ cái đang hiện thay vì xếp hàng. Xếp hàng thì thông báo thứ ba
    // hiện ra sau gần mười giây, lúc đó nó đã không còn là tin mới nữa.
    _hide?.cancel();
    setState(() => _current = n);
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _current = null);
    });
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted) setState(() => _current = null);
  }

  void _open() {
    final n = _current;
    _dismiss();
    if (n == null) return;
    NotificationsStore.instance.markRead(n.id);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _current;

    return Stack(
      children: [
        widget.child,
        // IgnorePointer khi không có banner: Stack phủ toàn màn hình, không
        // có nó thì một lớp trong suốt nuốt hết cú chạm của cả app.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(begin: const Offset(0, -1), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: n == null
                ? const SizedBox.shrink(key: ValueKey('none'))
                : _Banner(
                    key: ValueKey(n.id),
                    item: n,
                    onTap: _open,
                    onDismiss: _dismiss,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Np.s3, top + Np.s2, Np.s3, 0),
        child: Dismissible(
          key: ValueKey('dismiss-${item.id}'),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismiss(),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s3 + 2),
              decoration: BoxDecoration(
                // Nền TỐI để tách hẳn khỏi nội dung nền sáng bên dưới. Dùng
                // nền sáng thì banner lẫn vào trang và người dùng không nhận
                // ra có gì vừa xuất hiện.
                color: c.band,
                borderRadius: BorderRadius.circular(Np.rMd),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: c.acid, shape: BoxShape.circle),
                    child: NpIco(NpIcon.bell, size: 15, color: c.onAcid),
                  ),
                  const SizedBox(width: Np.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.isEmpty ? 'Thông báo mới' : item.title,
                          style: NpType.body.copyWith(
                            fontSize: 14,
                            color: c.onBand,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.body,
                            style: NpType.meta.copyWith(
                              fontSize: 12.5,
                              color: c.onBand.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Np.s2),
                  NpIco(NpIcon.arrow,
                      size: 15, color: c.onBand.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
