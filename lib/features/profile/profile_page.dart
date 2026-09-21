import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/saved_store.dart';

/// Tab Hồ sơ.
///
/// Với khách: một lời mời đăng nhập, không phải màn hình trống có chữ "chưa
/// đăng nhập". Đây là nơi người dùng tìm tới khi họ ĐÃ muốn có tài khoản, nên
/// nó phải trả lời được câu "đăng nhập rồi thì được gì".
///
/// Với người đã đăng nhập: thông tin tài khoản, số tin đã lưu, và đăng xuất.
/// Phần chỉnh sửa hồ sơ năng lực chưa dựng — nó là một trình soạn thảo nhiều
/// bước, hiện chỉ có trên website.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.isGuest,
    required this.onSignIn,
    required this.onSignOut,
  });

  final bool isGuest;
  final VoidCallback onSignIn;
  final Future<void> Function() onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = ApiClient();
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    if (!widget.isGuest) _loadMe();
  }

  @override
  void didUpdateWidget(ProfilePage old) {
    super.didUpdateWidget(old);
    // Người dùng đăng nhập trong lúc tab này đã dựng sẵn (IndexedStack dựng cả
    // bốn tab từ đầu), nên phải nạp lại khi cờ đổi — initState không chạy lại.
    if (old.isGuest && !widget.isGuest) _loadMe();
    if (!old.isGuest && widget.isGuest) setState(() => _me = null);
  }

  Future<void> _loadMe() async {
    try {
      final data = await _api.get('/me');
      if (mounted && data is Map<String, dynamic>) {
        setState(() => _me = data);
      }
    } on ApiException {
      // Không hiện lỗi: email lấy từ phiên vẫn dùng được, và một thông báo đỏ
      // ở đây chỉ làm người dùng lo mà không giúp được gì.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(Np.gutter, Np.s6, Np.gutter, Np.navInset),
        children: [
          const SectionLabel('Tài khoản'),
          const SizedBox(height: Np.s4),
          Text('Hồ sơ',
              style: NpType.h1.copyWith(fontSize: 30, color: c.ink)),
          const SizedBox(height: Np.s6),

          if (widget.isGuest)
            _GuestCard(onSignIn: widget.onSignIn)
          else ...[
            _AccountCard(me: _me),
            const SizedBox(height: Np.s5),
            const _SavedCount(),
            const SizedBox(height: Np.s5),
            const _NotYetCard(),
            const SizedBox(height: Np.s6),
            _SignOutRow(onSignOut: widget.onSignOut),
          ],
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onSignIn});
  final VoidCallback onSignIn;

  static const _perks = [
    (Icons.favorite_rounded, 'Lưu tin để xem lại sau'),
    (Icons.send_rounded, 'Nộp đơn ngay trong app'),
    (Icons.verified_rounded, 'Minh chứng được xác thực cho mỗi việc hoàn thành'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đăng nhập để bắt đầu',
              style: NpType.title.copyWith(fontSize: 19, color: c.ink)),
          const SizedBox(height: Np.s4),
          for (final (icon, text) in _perks) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 17, color: c.acidText),
                const SizedBox(width: Np.s3),
                Expanded(
                  child: Text(text,
                      style: NpType.meta.copyWith(color: c.muted)),
                ),
              ],
            ),
            const SizedBox(height: Np.s3),
          ],
          const SizedBox(height: Np.s2),
          AcidButton(
            label: 'Đăng nhập',
            icon: Icons.arrow_forward_rounded,
            onTap: onSignIn,
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.me});
  final Map<String, dynamic>? me;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final email = '${me?['email'] ?? '—'}';
    // roles có thể rỗng (tài khoản vừa tạo, chưa gán vai trò) — lúc đó join()
    // trả chuỗi rỗng và dòng biến mất, để lại một khoảng hụt trông như lỗi.
    final roleList = (me?['roles'] as List?)?.map((e) => '$e').toList() ?? [];
    final roles = roleList.isEmpty ? 'Ứng viên' : roleList.join(', ');
    final initial = email.isEmpty || email == '—'
        ? 'N'
        : email.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.acid,
              borderRadius: BorderRadius.circular(Np.rMd),
            ),
            child: Text(initial,
                style: NpType.h1.copyWith(fontSize: 22, color: c.onAcid)),
          ),
          const SizedBox(width: Np.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email,
                    style: NpType.title.copyWith(color: c.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(roles, style: NpType.meta.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCount extends StatelessWidget {
  const _SavedCount();

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return ListenableBuilder(
      listenable: SavedStore.instance,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(Np.s5),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          children: [
            Icon(Icons.favorite_rounded, size: 19, color: c.acidText),
            const SizedBox(width: Np.s3),
            Expanded(
              child: Text('Tin đã lưu',
                  style: NpType.body.copyWith(color: c.ink)),
            ),
            Text('${SavedStore.instance.count}',
                style: NpType.title.copyWith(color: c.ink)),
          ],
        ),
      ),
    );
  }
}

class _NotYetCard extends StatelessWidget {
  const _NotYetCard();

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c, radius: Np.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hồ sơ năng lực',
              style: NpType.body.copyWith(
                  color: c.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: Np.s2),
          Text(
            'Phần chỉnh sửa portfolio chưa có trong app. '
            'Tạm thời làm trên website nhé.',
            style: NpType.meta.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onSignOut});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _confirm(context),
        child: Padding(
          padding: const EdgeInsets.all(Np.s3),
          child: Text('Đăng xuất',
              style: NpType.body.copyWith(
                  color: c.danger, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  /// Hỏi lại trước khi đăng xuất. Nút này nằm ngay dưới các mục khác nên rất
  /// dễ bấm nhầm, mà hậu quả là mất phiên và phải nhập lại mật khẩu.
  Future<void> _confirm(BuildContext context) async {
    final c = Np.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Np.rLg)),
        title: Text('Đăng xuất?',
            style: NpType.title.copyWith(fontSize: 18, color: c.ink)),
        content: Text('Bạn sẽ cần đăng nhập lại để lưu tin và nộp đơn.',
            style: NpType.meta.copyWith(color: c.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Ở lại', style: TextStyle(color: c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Đăng xuất',
                style: TextStyle(
                    color: c.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) await onSignOut();
  }
}
