import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/saved_store.dart';
import 'application_item.dart';
import 'applications_page.dart';
import 'me_store.dart';
import 'portfolio_page.dart';
import 'saved_list_page.dart';

/// Tab Hồ sơ.
///
/// Với khách: một lời mời đăng nhập, không phải màn hình trống có chữ "chưa
/// đăng nhập". Đây là nơi người dùng tìm tới khi họ ĐÃ muốn có tài khoản, nên
/// nó phải trả lời được câu "đăng nhập rồi thì được gì".
///
/// Với người đã đăng nhập: danh tính, rồi ba lối đi — tin đã lưu, đơn đã nộp,
/// hồ sơ năng lực — và đăng xuất.
///
/// Ba lối đi đó là lý do tab này tồn tại. Bản trước chỉ hiện email, một CON SỐ
/// đếm tin đã lưu (không bấm được) và một dòng "chưa có trong app". Mọi lời
/// nhắc ở trang chủ đều trỏ về đây, nên mỗi lời nhắc khi đó là một ngõ cụt.
///
/// Phần SOẠN hồ sơ vẫn chưa dựng — nó là trình soạn nhiều bước, hiện chỉ có
/// trên website. Nhưng xem thì phải xem được.
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
  final _profile = MeStore.instance;
  Map<String, dynamic>? _me;

  /// Số đơn chưa có kết luận. Nạp ở đây để con số nằm ngay trên hàng "Đơn đã
  /// nộp" — người dùng biết có gì đáng mở trước khi bấm vào.
  int _openApps = 0;

  @override
  void initState() {
    super.initState();
    _profile.addListener(_sync);
    SavedStore.instance.addListener(_sync);
    if (!widget.isGuest) _loadMe();
  }

  @override
  void dispose() {
    _profile.removeListener(_sync);
    SavedStore.instance.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ProfilePage old) {
    super.didUpdateWidget(old);
    // Người dùng đăng nhập trong lúc tab này đã dựng sẵn (IndexedStack dựng cả
    // bốn tab từ đầu), nên phải nạp lại khi cờ đổi — initState không chạy lại.
    if (old.isGuest && !widget.isGuest) _loadMe();
    if (!old.isGuest && widget.isGuest) {
      _profile.clear();
      setState(() {
        _me = null;
        _openApps = 0;
      });
    }
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

    await _profile.hydrate();
    await _countOpenApplications();
  }

  /// Đếm đơn chưa có kết luận, gộp cả đơn tin tuyển dụng và đơn quest.
  Future<void> _countOpenApplications() async {
    final res = await Future.wait([
      _try('/me/applications'),
      _try('/me/quest-applications'),
    ]);
    if (!mounted) return;
    final n = res
        .expand((l) => l ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((m) =>
            kOpenStatuses.contains('${m['status'] ?? ''}'.toUpperCase()))
        .length;
    setState(() => _openApps = n);
  }

  Future<List<dynamic>?> _try(String path) async {
    try {
      final d = await _api.get(path);
      return d is List ? d : const [];
    } on ApiException {
      return null;
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

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

            _NavRow(
              icon: NpIcon.heartFill,
              label: 'Tin đã lưu',
              trailing: '${SavedStore.instance.count}',
              onTap: () => _push(const SavedListPage()),
            ),
            const SizedBox(height: Np.s2),
            _NavRow(
              icon: NpIcon.send,
              label: 'Đơn đã nộp',
              // Chỉ hiện số khi CÓ đơn đang chờ. Một số 0 nằm cạnh nhãn chỉ
              // làm hàng này trông như đang báo lỗi.
              trailing: _openApps > 0 ? '$_openApps đang chờ' : null,
              highlight: _openApps > 0,
              onTap: () => _push(const ApplicationsPage()),
            ),
            const SizedBox(height: Np.s2),
            _NavRow(
              icon: NpIcon.person,
              label: 'Hồ sơ năng lực',
              trailing: _profile.loaded
                  ? '${(_profile.completeness * 100).round()}%'
                  : null,
              onTap: () => _push(const PortfolioPage()),
            ),

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

/// Một hàng dẫn sang màn khác.
///
/// Dùng chung một hình dạng cho cả ba lối đi là có chủ ý: chúng ngang hàng
/// nhau về vai trò, nên thứ phân biệt chúng phải là CHỮ, không phải màu hay
/// kích thước. Chỉ hàng nào thật sự có việc cần làm mới được tô.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.highlight = false,
  });

  final NpIcon icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s4 + 2),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          children: [
            NpIco(icon, size: 19, color: highlight ? c.acidText : c.muted),
            const SizedBox(width: Np.s4),
            Expanded(
              child: Text(label,
                  style: NpType.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: NpType.meta.copyWith(
                    color: highlight ? c.acidText : c.muted,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                  )),
              const SizedBox(width: Np.s2),
            ],
            NpIco(NpIcon.arrow, size: 16, color: c.faint),
          ],
        ),
      ),
    );
  }
}
