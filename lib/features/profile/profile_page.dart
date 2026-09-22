import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../discussions/discussion_widgets.dart';
import '../jobs/applied_store.dart';
import '../jobs/saved_store.dart';
import 'applications_page.dart';
import 'edit_profile_page.dart';
import 'gamification_store.dart';
import 'me_store.dart';
import 'notifications_page.dart';
import 'notifications_store.dart';
import 'portfolio_page.dart';
import 'saved_list_page.dart';

/// Tab Hồ sơ.
///
/// ─── Vì sao bản trước bị bỏ ──────────────────────────────────────────────
/// Nó là một BẢNG CÀI ĐẶT chứ không phải hồ sơ: bốn hàng chữ nhật giống hệt
/// nhau xếp chồng, rồi một nút đăng xuất, rồi nửa màn hình trống.
///
/// Tệ hơn, khối danh tính hiện EMAIL và một ô vuông xanh in chữ cái đầu —
/// trong khi /profiles/me đã trả sẵn ảnh thật, tên thật, giới thiệu, trường,
/// điểm uy tín, cấp độ, tổng EXP và số dư NP. Người dùng mở tab hồ sơ của
/// CHÍNH MÌNH và nhận lại ít thông tin hơn những gì họ đã nhập.
///
/// ─── Bản này ─────────────────────────────────────────────────────────────
///   1. Trên cùng là NGƯỜI, không phải email: ảnh, tên, giới thiệu, trường.
///   2. Một dải số đo thật — uy tín, cấp, chuỗi ngày, NP — thay cho khoảng
///      trống. Đây là những con số app vẫn tính mà chưa bao giờ hiện ra.
///   3. Hồ sơ năng lực thành thẻ lớn có thanh hoàn thiện và vài kỹ năng, vì
///      nó là lời hứa trung tâm của sản phẩm chứ không phải một dòng menu.
///   4. Tin đã lưu và Đơn đã nộp đứng CẠNH nhau: chúng cùng hạng, xếp dọc chỉ
///      làm trang dài ra mà không nói thêm gì.
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
  final _me = MeStore.instance;

  /// Chỉ dùng cho email — /profiles/me không trả email, còn /me thì có.
  Map<String, dynamic>? _account;

  @override
  void initState() {
    super.initState();
    for (final s in _stores) {
      s.addListener(_sync);
    }
    if (!widget.isGuest) _load();
  }

  List<Listenable> get _stores => [
        _me,
        AppliedStore.instance,
        NotificationsStore.instance,
        SavedStore.instance,
        GamificationStore.instance,
      ];

  @override
  void dispose() {
    for (final s in _stores) {
      s.removeListener(_sync);
    }
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ProfilePage old) {
    super.didUpdateWidget(old);
    // IndexedStack dựng cả bốn tab từ đầu nên initState KHÔNG chạy lại khi
    // người dùng đăng nhập.
    if (old.isGuest && !widget.isGuest) _load();
    if (!old.isGuest && widget.isGuest) {
      _me.clear();
      setState(() => _account = null);
    }
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/me');
      if (mounted && data is Map<String, dynamic>) {
        setState(() => _account = data);
      }
    } on ApiException {
      // Email lấy từ phiên vẫn dùng được; một thông báo đỏ ở đây chỉ làm người
      // dùng lo mà không giúp được gì.
    }
    await _me.hydrate();
    await NotificationsStore.instance.hydrate();
    await AppliedStore.instance.hydrate();
    await GamificationStore.instance.hydrate();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    if (widget.isGuest) {
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Np.gutter, Np.s6, Np.gutter, Np.navInset),
          children: [
            const SectionLabel('Tài khoản'),
            const SizedBox(height: Np.s4),
            Text('Hồ sơ', style: NpType.h1.copyWith(fontSize: 30, color: c.ink)),
            const SizedBox(height: Np.s6),
            _GuestCard(onSignIn: widget.onSignIn),
          ],
        ),
      );
    }

    final unread = NotificationsStore.instance.unread;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              Np.gutter, Np.s4, Np.gutter, Np.navInset),
          children: [
            _Identity(
              me: _me,
              email: '${_account?['email'] ?? ''}',
              unread: unread,
              onBell: () => _push(const NotificationsPage()),
              onEdit: () => _push(const EditProfilePage()),
            ),

            const SizedBox(height: Np.s6),
            // KHÔNG dùng `const _Stats()`. Widget const được Flutter chuẩn hoá
            // thành một thực thể duy nhất, và khi cha dựng lại thì nó bị bỏ
            // qua vì "y hệt cái cũ". Kho dữ liệu nạp bất đồng bộ SAU lần dựng
            // đầu, nên bốn con số sẽ đứng nguyên ở 0 mãi mãi.
            //
            // Truyền kho vào làm tham số để chỗ phụ thuộc lộ ra ngay trong
            // chữ ký, thay vì nấp trong thân build().
            _Stats(me: _me, gamification: GamificationStore.instance),

            const SizedBox(height: Np.s6),
            _PortfolioCard(me: _me, onTap: () => _push(const PortfolioPage())),

            const SizedBox(height: Np.s3),
            Row(
              children: [
                Expanded(
                  child: _Tile(
                    icon: NpIcon.heartFill,
                    label: 'Tin đã lưu',
                    value: '${SavedStore.instance.count}',
                    onTap: () => _push(const SavedListPage()),
                  ),
                ),
                const SizedBox(width: Np.s3),
                Expanded(
                  child: _Tile(
                    icon: NpIcon.send,
                    label: 'Đơn đã nộp',
                    value: '${AppliedStore.instance.openCount}',
                    // Chỉ tô khi CÓ đơn đang chờ. Tô cả khi bằng 0 thì màu
                    // nhấn mất nghĩa: nó phải nói "có việc", không phải "có ô".
                    accent: AppliedStore.instance.openCount > 0,
                    hint: AppliedStore.instance.openCount > 0
                        ? 'đang chờ'
                        : 'chưa có đơn nào',
                    onTap: () => _push(const ApplicationsPage()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Np.s8),
            _SignOutRow(onSignOut: widget.onSignOut),
          ],
        ),
      ),
    );
  }
}

/// Khối danh tính: ảnh, tên, giới thiệu, trường, và chuông.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.me,
    required this.email,
    required this.unread,
    required this.onBell,
    required this.onEdit,
  });

  final MeStore me;
  final String email;
  final int unread;
  final VoidCallback onBell;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final name = me.name?.trim();
    // Chưa nạp xong thì lấy phần trước @ của email làm tên tạm, KHÔNG để
    // trống — một dòng rỗng ở chỗ tên trông như hồ sơ hỏng.
    final display = (name == null || name.isEmpty)
        ? (email.contains('@') ? email.split('@').first : 'Bạn')
        : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(name: display, url: me.avatarUrl, size: 62),
            const SizedBox(width: Np.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Np.s1),
                  Row(
                    children: [
                      Flexible(
                        child: Text(display,
                            style: NpType.h1.copyWith(color: c.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (me.openToWork) ...[
                        const SizedBox(width: Np.s2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Np.s2 + 2, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.acid.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(Np.rPill),
                          ),
                          child: Text('Đang tìm việc',
                              style: NpType.meta.copyWith(
                                fontSize: 10.5,
                                color: c.acidText,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ],
                  ),
                  if (me.headline != null) ...[
                    const SizedBox(height: 3),
                    Text(me.headline!,
                        style: NpType.meta.copyWith(color: c.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  if (me.school != null) ...[
                    const SizedBox(height: 2),
                    Text(me.school!,
                        style: NpType.meta
                            .copyWith(fontSize: 12, color: c.faint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            _Bell(unread: unread, onTap: onBell),
          ],
        ),

        const SizedBox(height: Np.s4),
        Row(
          children: [
            Expanded(
              child: _Ghost(label: 'Sửa hồ sơ', onTap: onEdit),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(width: Np.s3),
              Expanded(
                flex: 2,
                child: Text(email,
                    style: NpType.meta
                        .copyWith(fontSize: 12.5, color: c.faint),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Dải bốn con số. Tất cả đều là dữ liệu app ĐÃ tính sẵn mà trước đây không
/// hiện ra ở đâu cả.
class _Stats extends StatelessWidget {
  const _Stats({required this.me, required this.gamification});

  final MeStore me;
  final GamificationStore gamification;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final g = gamification;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Np.s4, vertical: Np.s4 + 2),
      decoration: Np.card(c, radius: Np.rLg),
      child: Column(
        children: [
          Row(
            children: [
              _Stat(value: '${me.reputationScore}', label: 'Uy tín'),
              _Divider(),
              _Stat(value: '${g.level > 0 ? g.level : me.currentLevel}',
                  label: 'Cấp'),
              _Divider(),
              _Stat(value: '${g.streak}', label: 'Ngày liên tiếp'),
              _Divider(),
              _Stat(value: '${me.npBalance}', label: 'NP'),
            ],
          ),

          // Vạch EXP chỉ vẽ khi biết mốc lên cấp. Không biết mà vẫn vẽ thì
          // chia cho 0 ra NaN và Flutter dựng một vạch rộng vô hạn.
          if (g.expForNextLevel > 0) ...[
            const SizedBox(height: Np.s4),
            ClipRRect(
              borderRadius: BorderRadius.circular(Np.rPill),
              child: LinearProgressIndicator(
                value: g.progress,
                minHeight: 5,
                backgroundColor: c.line,
                valueColor: AlwaysStoppedAnimation(c.acid),
              ),
            ),
            const SizedBox(height: Np.s2),
            Text('${g.expIntoLevel}/${g.expForNextLevel} EXP để lên cấp '
                '${(g.level > 0 ? g.level : me.currentLevel) + 1}',
                style: NpType.meta.copyWith(fontSize: 11.5, color: c.faint)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: NpType.h1.copyWith(fontSize: 20, color: c.ink)),
          const SizedBox(height: 2),
          Text(label,
              style: NpType.meta.copyWith(fontSize: 11, color: c.muted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: Np.of(context).line);
}

/// Hồ sơ năng lực — thẻ lớn, không phải một dòng menu.
class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.me, required this.onTap});
  final MeStore me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final pct = (me.completeness * 100).round();
    final skills = me.skillLabels.take(4).toList();
    final more = me.skillLabels.length - skills.length;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Np.s5),
        decoration: Np.card(c, radius: Np.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Hồ sơ năng lực',
                      style: NpType.title.copyWith(fontSize: 17, color: c.ink)),
                ),
                Text('$pct%',
                    style: NpType.meta.copyWith(
                      color: pct == 100 ? c.acidText : c.muted,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(width: Np.s2),
                NpIco(NpIcon.arrow, size: 16, color: c.faint),
              ],
            ),
            const SizedBox(height: Np.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(Np.rPill),
              child: LinearProgressIndicator(
                value: me.completeness.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: c.line,
                valueColor: AlwaysStoppedAnimation(c.acid),
              ),
            ),

            if (skills.isEmpty) ...[
              const SizedBox(height: Np.s3),
              Text('Chưa có kỹ năng nào — app dùng kỹ năng để tìm việc hợp '
                  'với bạn.',
                  style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
            ] else ...[
              const SizedBox(height: Np.s4),
              Wrap(
                spacing: Np.s2,
                runSpacing: Np.s2,
                children: [
                  for (final s in skills)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Np.s3, vertical: Np.s1 + 2),
                      decoration: BoxDecoration(
                        color: c.acid.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(Np.rPill),
                      ),
                      child: Text(s,
                          style: NpType.meta.copyWith(
                            fontSize: 12.5,
                            color: c.acidText,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  if (more > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Np.s3, vertical: Np.s1 + 2),
                      decoration: BoxDecoration(
                        color: c.surfaceHi,
                        borderRadius: BorderRadius.circular(Np.rPill),
                        border: Border.all(color: c.line),
                      ),
                      child: Text('+$more',
                          style: NpType.meta
                              .copyWith(fontSize: 12.5, color: c.muted)),
                    ),
                ],
              ),
            ],

            if (me.experiences > 0 || me.credentials > 0) ...[
              const SizedBox(height: Np.s3),
              Text(
                [
                  if (me.experiences > 0) '${me.experiences} kinh nghiệm',
                  if (me.credentials > 0) '${me.credentials} chứng chỉ',
                ].join(' · '),
                style: NpType.meta.copyWith(fontSize: 12, color: c.faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ô vuông cho Tin đã lưu / Đơn đã nộp.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.accent = false,
  });

  final NpIcon icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final String? hint;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Np.s4),
        decoration: Np.card(c, radius: Np.rMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NpIco(icon, size: 18, color: accent ? c.acidText : c.muted),
            const SizedBox(height: Np.s3),
            Text(value,
                style: NpType.h1.copyWith(
                    fontSize: 22, color: accent ? c.acidText : c.ink)),
            const SizedBox(height: 1),
            Text(label,
                style: NpType.meta.copyWith(
                  fontSize: 13,
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                )),
            if (hint != null) ...[
              const SizedBox(height: 1),
              Text(hint!,
                  style: NpType.meta.copyWith(fontSize: 11.5, color: c.faint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nút viền, dùng cho hành động phụ. Không dùng AcidButton: màu nhấn dành cho
/// một hành động chính mỗi màn, rải ra thì không còn chính nào.
class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(color: c.line),
        ),
        child: Text(label,
            style: NpType.meta.copyWith(
              fontSize: 13.5,
              color: c.ink,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            NpIco(NpIcon.bell, size: 21, color: c.ink),
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
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onSignIn});
  final VoidCallback onSignIn;

  static const _perks = [
    (NpIcon.heartFill, 'Lưu tin để xem lại sau'),
    (NpIcon.send, 'Nộp đơn ngay trong app'),
    (NpIcon.bolt, 'Minh chứng được xác thực cho mỗi việc hoàn thành'),
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
                NpIco(icon, size: 17, color: c.acidText),
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

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onSignOut});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Center(
      child: GestureDetector(
        onTap: onSignOut,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Np.s3),
          child: Text('Đăng xuất',
              style: NpType.button.copyWith(fontSize: 15, color: c.danger)),
        ),
      ),
    );
  }
}
