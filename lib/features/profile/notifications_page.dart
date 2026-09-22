import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../jobs/opportunity_labels.dart';
import 'notification_router.dart';
import 'notifications_store.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _store = NotificationsStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_sync);
    _store.hydrate();
  }

  @override
  void dispose() {
    _store.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Thông báo', style: NpType.h1.copyWith(color: c.ink)),
        actions: [
          if (_store.unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: Np.gutter),
              child: GestureDetector(
                onTap: _store.markAllRead,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Text('Đọc hết',
                      style: NpType.meta.copyWith(
                        color: c.acidText,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _store.hydrate,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: _store.items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    Np.s10, Np.s10 * 2, Np.s10, Np.s10),
                children: [
                  Text(
                    _store.loaded
                        ? 'Chưa có thông báo nào.\n'
                            'Nhà tuyển dụng phản hồi đơn của bạn thì tin sẽ '
                            'hiện ở đây.'
                        : 'Đang tải…',
                    style: NpType.meta.copyWith(color: c.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    Np.gutter, Np.s2, Np.gutter, Np.s10),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _store.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Np.s2),
                itemBuilder: (context, i) => _Row(
                  item: _store.items[i],
                  // Router tự đánh dấu đã đọc rồi mới điều hướng.
                  onTap: () =>
                      NotificationRouter.open(context, _store.items[i]),
                ),
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Np.s4),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chấm chưa đọc, không phải nền tô đậm cả thẻ: nền đậm cho từng
            // dòng sẽ làm danh sách trông sọc vằn khi có vài tin chưa đọc xen
            // kẽ tin đã đọc.
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 6, right: Np.s3),
              decoration: BoxDecoration(
                color: item.isRead ? Colors.transparent : c.acid,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title.isEmpty ? 'Thông báo' : item.title,
                      style: NpType.body.copyWith(
                        color: c.ink,
                        fontWeight:
                            item.isRead ? FontWeight.w500 : FontWeight.w700,
                      )),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.body,
                        style: NpType.meta.copyWith(color: c.muted)),
                  ],
                  if (item.createdAt != null) ...[
                    const SizedBox(height: Np.s2),
                    Text(relativeTime(item.createdAt),
                        style: NpType.meta
                            .copyWith(fontSize: 11.5, color: c.faint)),
                  ],
                ],
              ),
            ),
            // Mũi tên CHỈ hiện khi thông báo thật sự mở được nội dung. Hiện
            // đều cho mọi dòng là hứa hẹn một việc mà nửa số dòng không làm
            // được — POST_MODERATION và NEW_APPLICATION không mang link nào.
            if (item.hasTarget) ...[
              const SizedBox(width: Np.s2),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: NpIco(NpIcon.arrow, size: 15, color: c.faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
