import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/opportunities_repository.dart';
import '../jobs/opportunity.dart';
import '../jobs/opportunity_card.dart';
import '../jobs/opportunity_detail_page.dart';
import '../jobs/saved_store.dart';
import '../profile/gamification_store.dart';

/// Trang chủ — bảng điều khiển của RIÊNG người dùng, không phải danh sách thứ hai.
///
/// Bản trước hỏng ở chỗ nó là một bản thu nhỏ của tab Cơ hội, cộng hai con số
/// hư danh ("10 doanh nghiệp / 4 CLB") vốn đã có sẵn trên tab bên cạnh. Người
/// dùng mở app không hỏi "hệ thống có bao nhiêu tin" — họ hỏi "tôi đang ở đâu,
/// và có gì mới cho tôi".
///
/// Nên trang này trả lời theo đúng thứ tự đó:
///   1. Bạn đang ở đâu   — cấp, EXP, chuỗi ngày
///   2. Bạn đang theo gì — tin đã lưu, đơn đã nộp
///   3. Có gì mới        — vài cơ hội gần nhất
///
/// Với khách thì mục 1 và 2 vô nghĩa, nên chúng nhường chỗ cho một lời mời có
/// lý do.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isGuest,
    required this.onSignIn,
    required this.onSeeAll,
  });

  final bool isGuest;
  final VoidCallback onSignIn;
  final VoidCallback onSeeAll;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiClient();
  late final _repo = OpportunitiesRepository(_api);

  List<Opportunity> _items = const [];
  int _applications = 0;
  String? _email;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    // IndexedStack dựng cả bốn tab từ đầu nên initState KHÔNG chạy lại khi
    // người dùng đăng nhập. Không nạp lại ở đây thì trang chủ vẫn hiện bản
    // dành cho khách dù đã có phiên.
    if (old.isGuest != widget.isGuest) _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchAll();
      if (mounted) setState(() => _items = data);
    } on ApiException {
      // Danh sách rỗng đã tự nói lên vấn đề.
    }

    if (!widget.isGuest) {
      // Hai lệnh gọi này CHỈ dành cho người đã đăng nhập; gọi khi là khách sẽ
      // nhận 401 và không mang lại gì.
      final me = await _get('/me');
      final apps = await _get('/me/applications');
      if (mounted) {
        setState(() {
          _email = me is Map ? '${me['email'] ?? ''}' : null;
          _applications = apps is List ? apps.length : 0;
        });
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<dynamic> _get(String path) async {
    try {
      return await _api.get(path);
    } on ApiException {
      return null;
    }
  }

  /// Chào theo giờ trong ngày. Chi tiết nhỏ nhưng nó là khác biệt giữa "một
  /// màn hình" và "một màn hình biết bạn vừa mở nó lúc nào".
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Chào buổi sáng';
    if (h < 14) return 'Chào buổi trưa';
    if (h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    // Mới nhất trước. Tin thiếu createdAt xuống cuối chứ không nhảy lên đầu:
    // thiếu dữ liệu không phải lý do để được ưu tiên.
    final recent = [..._items]..sort((a, b) {
        final x = a.createdAt, y = b.createdAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    final top = recent.take(3).toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Np.gutter, Np.s6, Np.gutter, Np.navInset),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(_greeting, style: NpType.meta.copyWith(color: c.muted)),
            const SizedBox(height: Np.s1),
            Text(
              widget.isGuest ? 'Bạn ơi 👋' : _shortName(),
              style: NpType.display.copyWith(fontSize: 32, color: c.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: Np.s6),

            if (widget.isGuest)
              _GuestInvite(onSignIn: widget.onSignIn)
            else ...[
              const _ProgressCard(),
              const SizedBox(height: Np.s3),
              _TrackingRow(applications: _applications),
            ],

            const SizedBox(height: Np.s8),
            Row(
              children: [
                SectionLabel(widget.isGuest ? 'Mới nhất' : 'Mới cho bạn'),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onSeeAll,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text('Xem tất cả',
                          style: NpType.meta.copyWith(
                            color: c.acidText,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: c.acidText),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Np.s4),

            if (_loading && top.isEmpty)
              const _Skeleton(count: 2)
            else if (top.isEmpty)
              Container(
                padding: const EdgeInsets.all(Np.s5),
                decoration: Np.card(c),
                child: Text('Chưa có cơ hội nào.',
                    style: NpType.meta.copyWith(color: c.muted)),
              )
            else
              for (final item in top) ...[
                OpportunityCard(
                  item: item,
                  isGuest: widget.isGuest,
                  onNeedSignIn: widget.onSignIn,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OpportunityDetailPage(
                        summary: item,
                        isGuest: widget.isGuest,
                        onSignIn: widget.onSignIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Np.s3),
              ],
          ],
        ),
      ),
    );
  }

  /// Phần trước dấu @ của email. Backend chưa trả tên hiển thị ở /me, và
  /// "phat280405" vẫn thân thiện hơn cả địa chỉ email đầy đủ.
  String _shortName() {
    final e = _email;
    if (e == null || e.isEmpty) return 'Bạn ơi 👋';
    final at = e.indexOf('@');
    return '${at > 0 ? e.substring(0, at) : e} 👋';
  }
}

/// Thẻ tiến trình: cấp, vạch EXP, chuỗi ngày.
///
/// Đây là thứ trang chủ cũ thiếu hẳn. Dữ liệu đã có sẵn ở /me/gamification và
/// đang được thanh điều hướng dùng cho vạch mảnh 3px — ở đây nó được nói đầy
/// đủ, đúng chỗ người dùng dừng lại để đọc.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return ListenableBuilder(
      listenable: GamificationStore.instance,
      builder: (context, _) {
        final g = GamificationStore.instance;
        return Container(
          padding: const EdgeInsets.all(Np.s5),
          decoration: Np.card(c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Cấp ${g.level}',
                      style: NpType.h1.copyWith(fontSize: 26, color: c.ink)),
                  const Spacer(),
                  if (g.streak > 0)
                    MetaChip(label: '🔥 ${g.streak} ngày', accent: true),
                ],
              ),
              const SizedBox(height: Np.s4),
              ClipRRect(
                borderRadius: BorderRadius.circular(Np.rPill),
                child: Container(
                  height: 8,
                  color: c.acidText.withValues(alpha: 0.15),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: g.progress,
                    child: Container(color: c.acidText),
                  ),
                ),
              ),
              const SizedBox(height: Np.s2),
              Text(
                g.expForNextLevel > 0
                    ? '${g.expIntoLevel}/${g.expForNextLevel} EXP tới cấp ${g.level + 1}'
                    : 'Hoàn thành công việc để nhận EXP',
                style: NpType.meta.copyWith(color: c.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Hai ô: tin đã lưu và đơn đã nộp.
///
/// Không phải con số trang trí — đây là hai thứ người dùng đang THEO DÕI, và
/// là lý do chính họ mở lại app.
class _TrackingRow extends StatelessWidget {
  const _TrackingRow({required this.applications});
  final int applications;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: SavedStore.instance,
              builder: (context, _) => _Tile(
                icon: Icons.favorite_rounded,
                value: '${SavedStore.instance.count}',
                label: 'Tin đã lưu',
              ),
            ),
          ),
          const SizedBox(width: Np.s3),
          Expanded(
            child: _Tile(
              icon: Icons.send_rounded,
              value: '$applications',
              label: 'Đơn đã nộp',
            ),
          ),
        ],
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.acidText),
          const SizedBox(width: Np.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: NpType.title.copyWith(fontSize: 19, color: c.ink)),
                Text(label, style: NpType.meta.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestInvite extends StatelessWidget {
  const _GuestInvite({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cơ hội thật, minh chứng thật',
              style: NpType.title.copyWith(fontSize: 19, color: c.ink)),
          const SizedBox(height: Np.s2),
          Text(
            'Đăng nhập để lưu tin, nộp đơn và tích EXP cho mỗi việc hoàn thành.',
            style: NpType.meta.copyWith(color: c.muted),
          ),
          const SizedBox(height: Np.s5),
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

/// Khung xám thay cho vòng quay tải.
///
/// Giữ đúng chiều cao thẻ thật nên lúc dữ liệu về thì bố cục không nhảy —
/// thứ khó chịu nhất khi mở một trang nhiều khối.
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(height: 190, decoration: Np.card(c)),
          const SizedBox(height: Np.s3),
        ],
      ],
    );
  }
}
