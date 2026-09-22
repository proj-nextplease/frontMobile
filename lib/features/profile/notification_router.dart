import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../discussions/discussions_repository.dart';
import '../discussions/post_detail_page.dart';
import '../jobs/opportunities_repository.dart';
import '../jobs/opportunity_detail_page.dart';
import 'notifications_store.dart';
import 'portfolio_page.dart';

/// Mở đúng nội dung mà một thông báo nói tới.
///
/// ─── Vì sao cần một lớp dịch ─────────────────────────────────────────────
/// `link` trong bảng notifications là đường dẫn của WEBSITE — "/discussions/…",
/// "/jobs/…", "/portfolio". Mở thẳng nó sẽ ném người dùng ra trình duyệt giữa
/// chừng. App phải tự dịch sang màn hình của mình.
///
/// Trước đây app KHÔNG đọc `link` chút nào: bấm vào thông báo chỉ đánh dấu đã
/// đọc rồi đứng im. Người dùng biết "có ai đó bình luận" nhưng không có cách
/// nào tới được bình luận đó.
///
/// ─── Nguyên tắc khi không mở được ────────────────────────────────────────
/// Không bao giờ để cú chạm rơi vào hư không. Link lạ, bài đã xoá, mạng hỏng —
/// đều nói ra bằng một dòng, vì im lặng thì người dùng bấm lại vài lần rồi
/// kết luận app hỏng.
class NotificationRouter {
  NotificationRouter._();

  /// Trả về true nếu đã điều hướng đi đâu đó.
  static Future<bool> open(BuildContext context, NotificationItem item) async {
    // Đánh dấu đã đọc trước, không chờ điều hướng: người dùng đã NHÌN thấy nó
    // rồi, và nếu mở nội dung hỏng thì cũng không nên để nó mãi chưa đọc.
    NotificationsStore.instance.markRead(item.id);

    final link = item.link?.trim() ?? '';
    if (link.isEmpty) return false;

    // Cắt phần truy vấn và tiền tố tên miền: NotificationService ghép
    // APP_PUBLIC_URL vào trước khi gửi email, nên link có thể là tuyệt đối.
    final path = Uri.tryParse(link)?.path ?? link;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return false;

    try {
      switch (parts.first) {
        case 'discussions' when parts.length >= 2:
          return await _openPost(context, parts[1]);
        case 'jobs' when parts.length >= 2:
          return await _openOpportunity(context, parts[1], isQuest: false);
        case 'quests' when parts.length >= 2:
          return await _openOpportunity(context, parts[1], isQuest: true);
        case 'portfolio':
          if (!context.mounted) return false;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PortfolioPage()),
          );
          return true;
        default:
          return false;
      }
    } on ApiException catch (e) {
      if (context.mounted) _say(context, e.message);
      return false;
    }
  }

  static Future<bool> _openPost(BuildContext context, String id) async {
    final post = await DiscussionsRepository(ApiClient()).fetchPost(id);
    if (!context.mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          post: post,
          // Tới được đây nghĩa là đã đăng nhập — thông báo chỉ tồn tại cho
          // người có tài khoản.
          isGuest: false,
          onSignIn: () {},
        ),
      ),
    );
    return true;
  }

  static Future<bool> _openOpportunity(BuildContext context, String id,
      {required bool isQuest}) async {
    final repo = OpportunitiesRepository(ApiClient());
    final item = await repo.findById(id, isQuest: isQuest);
    if (!context.mounted) return false;
    if (item == null) {
      _say(context, 'Cơ hội này không còn nữa.');
      return false;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OpportunityDetailPage(
          summary: item,
          isGuest: false,
          onSignIn: () {},
        ),
      ),
    );
    return true;
  }

  static void _say(BuildContext context, String message) {
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: c.surfaceHi,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Np.rSm),
        side: BorderSide(color: c.line),
      ),
      content:
          Text(message, style: NpType.body.copyWith(fontSize: 14, color: c.ink)),
    ));
  }
}

/// Dùng lại cho nơi cần biết thông báo có mở được gì không (để quyết định có
/// hiện mũi tên hay không).
extension NotificationTarget on NotificationItem {
  bool get hasTarget {
    final l = link?.trim() ?? '';
    if (l.isEmpty) return false;
    final path = Uri.tryParse(l)?.path ?? l;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return false;
    return switch (parts.first) {
      'discussions' || 'jobs' || 'quests' => parts.length >= 2,
      'portfolio' => true,
      _ => false,
    };
  }
}
